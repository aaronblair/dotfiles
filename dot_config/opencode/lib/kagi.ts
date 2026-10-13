import { execFile } from "node:child_process"
import { promisify } from "node:util"

const execFileAsync = promisify(execFile)

export const MAX_TEXT_BYTES = 32 * 1024
const MAX_ARGUMENT_BYTES = 64 * 1024

export type RunOptions = {
  signal?: AbortSignal
  timeout?: number
  maxBuffer?: number
}

export function failure(category: string, message: string, retryable = false): string {
  return JSON.stringify({ error: { category, message, retryable } })
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

export function searchArguments(input: unknown): string[] | string {
  if (!isRecord(input) || typeof input.query !== "string" || !input.query.trim() || input.query.includes("\0")) {
    return failure("invalid_input", "Provide a nonblank search query without NUL characters.")
  }
  const limit = input.limit === undefined ? 10 : input.limit
  if (typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 20) {
    return failure("invalid_input", "Search limit must be an integer from 1 to 20.")
  }
  // The separator prevents a query beginning with '-' from becoming a CLI option.
  return ["search", "--limit", String(limit), "--", input.query.trim()]
}

export function summarizeArguments(input: unknown): string[] | string {
  if (!isRecord(input) || (input.url !== undefined) === (input.text !== undefined)) {
    return failure("invalid_input", "Provide exactly one of 'url' or 'text'.")
  }
  const value = input.url ?? input.text
  if (typeof value !== "string" || !value.trim() || value.includes("\0")) {
    return failure("invalid_input", "Provide nonblank content without NUL characters.")
  }
  if (input.url !== undefined) {
    try {
      const url = new URL(value)
      if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) throw new Error()
    } catch {
      return failure("invalid_input", "Provide an HTTP or HTTPS URL without embedded credentials.")
    }
  } else if (Buffer.byteLength(value, "utf8") > MAX_TEXT_BYTES) {
    return failure("input_too_large", `Text is limited to ${MAX_TEXT_BYTES} UTF-8 bytes; use a public URL or smaller excerpts.`)
  }
  const type = input.type === undefined ? "summary" : input.type
  const language = input.language === undefined ? "EN" : input.language
  if (type !== "summary" && type !== "takeaway") {
    return failure("invalid_input", "Summary type must be 'summary' or 'takeaway'.")
  }
  if (typeof language !== "string" || !/^[a-z]{2}$/i.test(language)) {
    return failure("invalid_input", "Language must be a two-letter code supported by Kagi.")
  }
  return ["summarize", input.url !== undefined ? "--url" : "--text", value, "--type", type, "--language", language.toUpperCase()]
}

export async function run(args: string[], options: RunOptions = {}): Promise<string> {
  if (args.some((arg) => arg.includes("\0")) || args.reduce((size, arg) => size + Buffer.byteLength(arg) + 1, 0) > MAX_ARGUMENT_BYTES) {
    return failure("input_too_large", "CLI arguments exceed the safe size limit or contain NUL characters.")
  }
  try {
    const { stdout } = await execFileAsync("kagi-ken-cli", args, {
      encoding: "utf-8",
      timeout: options.timeout ?? 30_000,
      maxBuffer: options.maxBuffer ?? 1024 * 1024,
      signal: options.signal,
    })
    return stdout.trim() || failure("empty_output", "Kagi returned no output.", true)
  } catch (err: unknown) {
    const error = isRecord(err) ? err : {}
    const diagnostic = typeof error.stderr === "string" ? error.stderr : ""
    // Never return raw subprocess messages: they may echo arguments, text, or credentials.
    if (error.code === "ENOENT") return failure("cli_missing", "The kagi-ken-cli executable was not found.")
    if (error.code === "ABORT_ERR" || options.signal?.aborted) return failure("cancelled", "Kagi execution was cancelled.")
    if (error.code === "ERR_CHILD_PROCESS_STDIO_MAXBUFFER") return failure("output_too_large", "Kagi output exceeded the configured buffer limit.")
    if (error.code === "E2BIG") return failure("input_too_large", "CLI arguments exceed the operating-system limit.")
    if (error.killed) return failure("timeout", "Kagi exceeded the configured execution timeout.", true)
    if (/\b429\b|rate.?limit|too many requests/i.test(diagnostic)) return failure("rate_limit", "Kagi rate-limited this request; wait before retrying.", true)
    if (/\b(401|403)\b|unauthori[sz]ed|forbidden|authentication|invalid.*token|session.*expired/i.test(diagnostic)) return failure("authentication", "Kagi authentication failed; check your local CLI credentials.")
    if (/\b5\d\d\b|ECONNRESET|ETIMEDOUT|EAI_AGAIN|ENOTFOUND|fetch failed/i.test(diagnostic)) return failure("service_unavailable", "Kagi could not be reached or returned a server error.", true)
    return failure("cli_failed", "Kagi CLI execution failed; inspect local diagnostics without sharing credentials.")
  }
}

export const SUMMARY_OUTPUT_CHARS = 12_000

export function outputBudget(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) && value >= 512 && value <= 200_000 ? value : fallback
}

export function searchOutputBudget(requestedResults = 10, override?: unknown): number {
  const count = Number.isInteger(requestedResults) && requestedResults >= 1 && requestedResults <= 20 ? requestedResults : 10
  return outputBudget(override, 1_000 + 1_000 * count)
}

function clip(text: string, limit: number): string {
  if (text.length <= limit) return text
  const marker = " [truncated]"
  // Do not leave a dangling UTF-16 surrogate when shortening Unicode text.
  const excerpt = text.slice(0, Math.max(0, limit - marker.length)).replace(/[\uD800-\uDBFF]$/, "")
  return excerpt + marker
}

function diagnostics(parsed: unknown, limit: number): string {
  if (!isRecord(parsed)) return ""
  const parts: string[] = []
  for (const key of ["error", "errors", "warning", "warnings", "message"]) {
    if (parsed[key] !== undefined) parts.push(`${key}: ${clip(typeof parsed[key] === "string" ? parsed[key] : JSON.stringify(parsed[key]), 300)}`)
  }
  return clip(parts.join("\n"), limit)
}

function responseError(parsed: unknown): string | undefined {
  if (!isRecord(parsed) || parsed.error === undefined) return undefined
  const error = parsed.error
  let result: string
  if (isRecord(error) && typeof error.category === "string") {
    result = failure(clip(error.category, 64), clip(typeof error.message === "string" ? error.message : "Kagi returned an error.", 240), error.retryable === true)
  } else {
    result = failure("service_error", clip(typeof error === "string" ? error : JSON.stringify(error), 240))
  }
  // JSON escaping can expand even short error strings beyond the smallest budget.
  return result.length <= 512 ? result : failure("service_error", "Kagi returned oversized error details; omitted.", isRecord(error) && error.retryable === true)
}

function fitSections(parts: string[], limit: number): string {
  if (parts.join("\n\n").length <= limit) return parts.join("\n\n")
  // Keep source URLs intact by omitting whole sections rather than slicing results.
  const kept: string[] = []
  let length = 0
  let omitted = 0
  for (const part of parts) {
    const size = part.length + (kept.length ? 2 : 0)
    if (length + size <= limit - 100) {
      kept.push(part)
      length += size
    } else {
      omitted++
    }
  }
  kept.push(`[${omitted} sections omitted by output budget; request fewer results or increase the budget.]`)
  return kept.join("\n\n")
}

/** Return bounded evidence, not transport metadata or arbitrary fallback payloads. */
export function compactSearchResults(raw: string, maxChars = searchOutputBudget()): string {
  const limit = outputBudget(maxChars, searchOutputBudget())
  try {
    const parsed: unknown = JSON.parse(raw)
    const data = Array.isArray(parsed) ? parsed : isRecord(parsed) ? parsed.data : undefined
    if (!Array.isArray(data)) return responseError(parsed) ?? failure("unexpected_output", "Kagi returned an unsupported search response; raw payload omitted.")

    const results: string[] = []
    const notice = diagnostics(parsed, Math.min(1024, Math.floor(limit / 4)))
    if (notice) results.push(notice)
    const seen = new Set<string>()
    const related = new Set<string>()
    let unsupported = 0
    let duplicates = 0
    for (const item of data) {
      if (isRecord(item) && item.t === 0 && typeof item.url === "string" && item.url.trim()) {
        const itemNotice = diagnostics(item, 300)
        if (itemNotice) results.push(itemNotice)
        if (seen.has(item.url)) { duplicates++; continue }
        seen.add(item.url)
        const title = typeof item.title === "string" ? item.title : "Untitled result"
        const snippet = typeof item.snippet === "string" ? item.snippet : ""
        const published = typeof item.published === "string" || typeof item.published === "number" ? `Published: ${item.published}` : ""
        results.push([title, item.url, published, snippet].filter(Boolean).join("\n"))
      } else if (isRecord(item) && item.t === 1 && Array.isArray(item.list) && item.list.every((value) => typeof value === "string")) {
        for (const value of item.list) {
          if (related.size < 3 && value.trim()) related.add(clip(value.trim(), 100))
        }
      } else {
        unsupported++
      }
    }
    if (related.size) results.push(`Related searches: ${[...related].join("; ")}`)
    if (unsupported) results.push(`[${unsupported} unsupported entries omitted.]`)
    if (duplicates) results.push(`[${duplicates} duplicate URLs omitted.]`)
    return fitSections(results, limit) || "No search results returned."
  } catch {
    return failure("unexpected_output", "Kagi returned invalid search JSON; raw payload omitted.")
  }
}

export function compactSummaryResult(raw: string, maxChars = SUMMARY_OUTPUT_CHARS, sourceURL?: string): string {
  const limit = outputBudget(maxChars, SUMMARY_OUTPUT_CHARS)
  let text: string
  let notice = ""
  try {
    const parsed: unknown = JSON.parse(raw)
    const data = isRecord(parsed) && isRecord(parsed.data) ? parsed.data : parsed
    if (isRecord(data) && typeof data.output === "string" && data.output.trim()) {
      text = data.output.trim()
      notice = diagnostics(parsed, Math.min(1024, Math.floor(limit / 4)))
      if (data !== parsed) notice = clip([notice, diagnostics(data, 300)].filter(Boolean).join("\n"), Math.min(1024, Math.floor(limit / 4)))
    } else {
      return responseError(parsed) ?? responseError(data) ?? failure("unexpected_output", "Kagi returned an unsupported summary response; raw payload omitted.")
    }
  } catch {
    // Some integrations return plain summary text rather than JSON.
    if (/^[\s]*[\[{<]/.test(raw)) return failure("unexpected_output", "Kagi returned malformed summary data; raw payload omitted.")
    text = raw.trim()
  }
  if (!text) return failure("empty_output", "Kagi returned no summary.", true)
  const prefix = [sourceURL ? `Source: ${sourceURL}` : "", notice].filter(Boolean).join("\n")
  if (prefix.length > limit - 100) return failure("output_too_large", "Source URL or diagnostics exceed the output budget; increase the budget.")
  return (prefix ? `${prefix}\n\n` : "") + clip(text, limit - (prefix ? prefix.length + 2 : 0))
}

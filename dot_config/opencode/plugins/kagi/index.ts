import { Plugin } from "@opencode/plugin"
import { realpathSync, statSync } from "node:fs"
import { fileURLToPath, pathToFileURL } from "node:url"
import { dirname, resolve } from "node:path"

// Resolve the helper relative to this portable plugin directory.
const sourceDirectory = dirname(realpathSync(fileURLToPath(import.meta.url)))
const helperPath = resolve(sourceDirectory, "../../lib/kagi.ts")
const helperURL = pathToFileURL(helperPath)
// Entry-point reloads must not reuse a stale helper module from the process cache.
helperURL.searchParams.set("mtime", String(statSync(helperPath).mtimeMs))
const { compactSearchResults, compactSummaryResult, outputBudget, searchOutputBudget, SUMMARY_OUTPUT_CHARS, run, searchArguments, summarizeArguments, MAX_TEXT_BYTES } = await import(
  helperURL.href
)

function positiveInteger(value: unknown, fallback: number, maximum: number): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0 && value <= maximum ? value : fallback
}

export default Plugin.define({
  id: "kagi",
  async setup(ctx) {
    // Preserve existing defaults until real workload measurements justify changing them.
    const limits = {
      search: {
        timeout: positiveInteger(ctx.options.searchTimeoutMs, 30_000, 600_000),
        maxBuffer: positiveInteger(ctx.options.searchMaxBufferBytes, 1024 * 1024, 16 * 1024 * 1024),
      },
      summarize: {
        timeout: positiveInteger(ctx.options.summarizeTimeoutMs, 30_000, 600_000),
        maxBuffer: positiveInteger(ctx.options.summarizeMaxBufferBytes, 1024 * 1024, 16 * 1024 * 1024),
        maxChars: outputBudget(ctx.options.summarizeOutputChars, SUMMARY_OUTPUT_CHARS),
      },
    }
    await ctx.tool.transform((editor) => {
      editor.add({
        name: "kagi_search",
        description:
          "Search the web with Kagi. Returns bounded titles, URLs, snippets, and notices of omitted content.",
        input: {
          type: "object",
          properties: {
            query: { type: "string", minLength: 1, pattern: "\\S", description: "The nonblank search query" },
            limit: {
              type: "integer",
              minimum: 1,
              maximum: 20,
              description: "Max results to return (1-20). Defaults to 10. Use fewer for simple lookups.",
            },
          },
          required: ["query"],
          additionalProperties: false,
        },
        async execute(input, context) {
          const parts = searchArguments(input)
          if (typeof parts === "string") return { content: parts }
          const maxChars = searchOutputBudget(Number(parts[2]), ctx.options.searchOutputChars)
          return { content: compactSearchResults(await run(parts, { ...limits.search, signal: context.signal }), maxChars) }
        },
      })

      editor.add({
        name: "kagi_summarize",
        description:
          "Summarize an article, video, podcast, or text with Kagi. Provide exactly one of url or text. Returns bounded plain text, with truncation marked.",
        input: {
          type: "object",
          properties: {
            url: { type: "string", minLength: 1, pattern: "^[Hh][Tt][Tt][Pp][Ss]?://", description: "HTTP(S) URL to summarize, without embedded credentials" },
            text: {
              type: "string", minLength: 1, pattern: "\\S",
              description: `Raw text to summarize, at most ${MAX_TEXT_BYTES} UTF-8 bytes. Passed via local CLI arguments; do not include sensitive content.`,
            },
            type: {
              type: "string",
              enum: ["summary", "takeaway"],
              description: "Output type: 'summary' (paragraph) or 'takeaway' (bullet points). Defaults to 'summary'.",
            },
            language: {
              type: "string",
              pattern: "^[A-Za-z]{2}$",
              description: "Two-letter language code for the summary output (e.g. EN, DE, FR). Defaults to 'EN'.",
            },
          },
          // Root oneOf loses the input signature in OpenCode Code Mode; enforce exclusivity at runtime.
          additionalProperties: false,
        },
        async execute(input, context) {
          const parts = summarizeArguments(input)
          if (typeof parts === "string") return { content: parts }
          const sourceURL = parts[1] === "--url" ? parts[2] : undefined
          return { content: compactSummaryResult(await run(parts, { ...limits.summarize, signal: context.signal }), limits.summarize.maxChars, sourceURL) }
        },
      })
    })
  },
})

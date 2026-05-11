import { tool } from "@opencode-ai/plugin"
import { execSync } from "node:child_process"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function run(cmd: string): string {
  try {
    return execSync(cmd, {
      encoding: "utf-8",
      timeout: 30_000,
      maxBuffer: 1024 * 1024,
    }).trim()
  } catch (err: any) {
    const msg = err.stderr?.trim() || err.message
    return JSON.stringify({ error: msg })
  }
}

/** Strip noise from search results so the LLM sees fewer tokens. */
function compactSearchResults(raw: string): string {
  try {
    const data = JSON.parse(raw)
    if (!Array.isArray(data)) return raw

    const results: string[] = []
    for (const item of data) {
      if (item.t === 0) {
        results.push(
          [
            `## ${item.title}`,
            item.url,
            item.snippet ?? "",
          ].join("\n"),
        )
      } else if (item.t === 1 && item.list) {
        results.push(`**Related searches:** ${item.list.join(", ")}`)
      }
    }
    return results.join("\n\n") || raw
  } catch {
    return raw
  }
}

function escapeShellArg(s: string | undefined): string {
  if (s == null) return "''"
  return `'${s.replace(/'/g, "'\\''")}'`
}

// ---------------------------------------------------------------------------
// Tools
// ---------------------------------------------------------------------------

export const search = tool({
  description:
    "Search the web using Kagi and return structured results. " +
    "Use this for up-to-date information, fact-checking, or research. " +
    "Returns titles, URLs, and snippets.",
  args: {
    query: tool.schema.string().describe("The search query"),
    limit: tool.schema
      .number()
      .int()
      .min(1)
      .max(20)
      .optional()
      .describe("Max results to return (1-20). Defaults to 10. Use fewer for simple lookups."),
  },
  async execute(args) {
    const parts = [`kagi-ken-cli search ${escapeShellArg(args.query)}`]
    if (args.limit && args.limit !== 10) {
      parts.push(`--limit ${args.limit}`)
    }
    const raw = run(parts.join(" "))
    return compactSearchResults(raw)
  },
})

export const summarize = tool({
  description:
    "Summarize a URL or text using Kagi's Summarizer. " +
    "Provide EITHER a url OR text, not both. " +
    "Useful for digesting long articles, videos, or podcasts.",
  args: {
    url: tool.schema.string().optional().describe("URL to summarize (webpage, video, podcast, etc.)"),
    text: tool.schema.string().optional().describe("Raw text to summarize (use url instead when possible)"),
    type: tool.schema.string().optional().describe("Output type: 'summary' (paragraph) or 'takeaway' (bullet points). Defaults to 'summary'."),
    language: tool.schema.string().optional().describe("Two-letter language code for the summary output (e.g. EN, DE, FR). Defaults to 'EN'."),
  },
  async execute(args) {
    const url = args.url || args.text
    if (!url) {
      return "Error: provide either 'url' or 'text'."
    }

    const type = args.type ?? "summary"
    const language = args.language ?? "EN"

    const parts = ["kagi-ken-cli summarize"]

    if (args.url) {
      parts.push(`--url ${escapeShellArg(args.url)}`)
    } else if (args.text) {
      parts.push(`--text ${escapeShellArg(args.text)}`)
    }

    parts.push(`--type ${escapeShellArg(type)}`)
    parts.push(`--language ${escapeShellArg(language)}`)

    return run(parts.join(" "))
  },
})

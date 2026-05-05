---
name: kagi-search
description: >
  Guidance for using Kagi web search and summarization tools
  (kagi_search, kagi_summarize). Load this skill when you need to:
  search the web for current information, look something up online,
  fact-check a claim, research a topic, summarize a webpage or
  article, digest a YouTube video or podcast, or when the user
  asks about recent events or real-time data.
---

# Kagi Search & Summarize

## Choosing the right tool

- **Need to discover information?** → `kagi_search`
- **Have a URL to digest?** → `kagi_summarize`
- **Need full page content (not a summary)?** → `webfetch`
- **Research workflow:** `kagi_search` to find URLs → `kagi_summarize` on promising results → `webfetch` only if full content is needed

## Search tips

- Keep queries short and keyword-focused (1-6 words work best).
- Use `limit` to reduce results for simple lookups (e.g., 3-5).
- Results may include **related searches** — use these to refine follow-up queries.

## Summarize tips

- Prefer `takeaway` type when you only need key facts (saves context).
- Summarize long pages with `kagi_summarize` before pulling full content with `webfetch`.
- If summarization fails on a URL, fall back to `webfetch`.

# Local Kagi integration

These details apply to the OpenCode CLI wrapper, not every Kagi integration. Read only for troubleshooting or configuration; supplied tool schemas describe ordinary inputs.

## Limits and output

- Search accepts 1–20 results, defaulting to 10. Use an explicit smaller limit for simple lookups.
- Summarization requires exactly one of `url` or `text`. Text is limited to 32,768 UTF-8 bytes; total CLI arguments to 65,536 bytes. There is no documented stdin support in the installed CLI.
- Search uses an emergency output budget of 1,000 characters overhead plus 1,000 per requested result: 4,000 for 3 results, 6,000 for 5, 11,000 for 10, and 21,000 for 20. Summary output defaults to 12,000. These are character budgets, not exact token limits or subprocess buffer sizes.
- Control routine search volume through the requested result count, not snippet truncation. Search preserves complete titles, URLs, dates, and snippets within its total budget, deduplicates exact URLs, keeps up to three related searches, and reports unsupported entries without dumping their payloads.
- Sections exceeding the total search budget are omitted with a notice. Raw or malformed search responses become short errors.
- Summary output unwraps the summary text and includes its source URL when supplied. It preserves bounded warnings/errors, marks shortened text, and omits unrelated transport metadata. Unsupported JSON is not dumped into context.
- Errors have an `error` object with `category`, `message`, and `retryable`. Partial-result warnings are plain text notices. Check them before relying on returned content.

## OpenCode plugin options

Set these in the Kagi plugin's `options` using the host's documented plugin configuration. Invalid values fall back to defaults.

| Option | Default | Accepted values |
| --- | --- | --- |
| `searchOutputChars` | 1,000 + 1,000 × requested results | Optional fixed override; integer, 512–200,000 |
| `summarizeOutputChars` | 12,000 | Integer, 512–200,000 |
| `searchTimeoutMs` | 30,000 | Integer, 1–600,000 |
| `summarizeTimeoutMs` | 30,000 | Integer, 1–600,000 |
| `searchMaxBufferBytes` | 1,048,576 | Integer, 1–16,777,216 |
| `summarizeMaxBufferBytes` | 1,048,576 | Integer, 1–16,777,216 |

Increase an output budget only when omitted evidence is needed. Preserve search-count and timeout defaults until representative workload measurements justify changing them. Configuration/source updates may require an OpenCode service restart; ask before interrupting active work.

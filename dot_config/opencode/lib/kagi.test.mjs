import assert from "node:assert/strict"
import { after, before, test } from "node:test"
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { compactSearchResults, compactSummaryResult, outputBudget, searchOutputBudget, MAX_TEXT_BYTES, run, searchArguments, summarizeArguments } from "./kagi.ts"

const category = (result) => JSON.parse(result).error.category
let directory
const originalPath = process.env.PATH

before(async () => {
  directory = await mkdtemp(join(tmpdir(), "kagi-tests-"))
  await mkdir(join(directory, "bin"))
  await writeFile(join(directory, "bin", "kagi-ken-cli"), `#!${process.execPath}
const mode = process.argv[2]
if (mode === "success") console.log("  result  ")
else if (mode === "slow") setTimeout(() => console.log("late"), 5000)
else if (mode === "large") process.stdout.write("x".repeat(4096))
else if (mode !== "empty") {
  console.error(mode === "auth" ? "401 authentication failed token=SECRET" : mode === "rate" ? "429 too many requests" : mode === "network" ? "503 fetch failed" : "failure SECRET")
  process.exit(1)
}
`, { mode: 0o700 })
  process.env.PATH = `${join(directory, "bin")}:${originalPath}`
})

after(async () => {
  process.env.PATH = originalPath
  await rm(directory, { recursive: true, force: true })
})

test("search validates input and separates option-like queries", () => {
  assert.deepEqual(searchArguments({ query: " -news " }), ["search", "--limit", "10", "--", "-news"])
  for (const query of ["", "  ", 12, "nul\0query"]) assert.equal(category(searchArguments({ query })), "invalid_input")
  for (const limit of [0, 21, 1.5, "3", null]) assert.equal(category(searchArguments({ query: "news", limit })), "invalid_input")
  assert.deepEqual(searchArguments({ query: "news", limit: 3 }), ["search", "--limit", "3", "--", "news"])
})

test("summarizer validates exclusivity, URL, type and language", () => {
  for (const input of [{}, { url: "https://example.com", text: "text" }, { text: "  " }, { url: "file:///private/file" }, { url: "https://user:pass@example.com" }, { url: "not a URL" }, { text: "text", type: "invalid" }, { text: "text", type: null }, { text: "text", language: "ENG" }]) {
    assert.equal(category(summarizeArguments(input)), "invalid_input")
  }
  assert.deepEqual(summarizeArguments({ text: "text", type: "takeaway", language: "de" }), ["summarize", "--text", "text", "--type", "takeaway", "--language", "DE"])
  assert.deepEqual(summarizeArguments({ url: "https://example.com" }), ["summarize", "--url", "https://example.com", "--type", "summary", "--language", "EN"])
})

test("text size is measured in UTF-8 bytes and is not silently truncated", () => {
  assert.ok(Array.isArray(summarizeArguments({ text: "x".repeat(MAX_TEXT_BYTES) })))
  assert.equal(category(summarizeArguments({ text: "x".repeat(MAX_TEXT_BYTES + 1) })), "input_too_large")
  assert.equal(category(summarizeArguments({ text: "é".repeat(MAX_TEXT_BYTES) })), "input_too_large")
})

test("search compaction preserves diagnostics and handles malformed entries individually", () => {
  const output = compactSearchResults(JSON.stringify({ warnings: ["partial results"], error: "one source failed", data: [null, { t: 0, title: "Source", url: "https://example.com", snippet: "Evidence", published: "2026-10-13" }, { t: 1, list: ["follow-up"] }, { t: 1, list: "bad" }, { t: 9, message: "new format" }] }))
  for (const text of ["partial results", "one source failed", "Source", "https://example.com", "Evidence", "Published: 2026-10-13", "Related searches", "follow-up"]) assert.ok(output.includes(text), text)
  assert.ok(output.includes("3 unsupported entries omitted"))
  assert.ok(!output.includes("new format"))
})

test("compaction supports arrays, empty results and bounded errors instead of raw fallback", () => {
  assert.equal(compactSearchResults("[]"), "No search results returned.")
  const error = '{"error":{"category":"authentication","message":"Sign in","retryable":false}}'
  assert.equal(compactSearchResults(error), error)
  for (const raw of ["not JSON", "null", '{"unexpected":true}']) assert.equal(category(compactSearchResults(raw)), "unexpected_output")
  assert.ok(compactSearchResults('[{"t":0,"url":"https://example.com"}]').includes("Untitled result"))
})

test("search emergency budgets omit whole results without cutting URLs or snippets", () => {
  const raw = JSON.stringify({ data: Array.from({ length: 20 }, (_, i) => ({ t: 0, title: `Source ${i}`, url: `https://example.com/${i}`, snippet: "evidence ".repeat(2000) })) })
  for (const budget of [512, 1000, 8000]) {
    const output = compactSearchResults(raw, budget)
    assert.ok(output.length <= budget)
    assert.ok(output.includes("omitted by output budget"))
    for (const line of output.split("\n").filter((line) => line.startsWith("https://"))) assert.match(line, /^https:\/\/example\.com\/\d+$/)
  }
  const hugeURL = `https://example.com/${"x".repeat(22000)}`
  const output = compactSearchResults(JSON.stringify([{ t: 0, url: hugeURL }, { t: 0, url: "https://example.com/small" }]))
  assert.ok(!output.includes("https://example.com/xxx"))
  assert.ok(output.includes("https://example.com/small"))
})

test("search budgets scale with requested result count and preserve fixed overrides", () => {
  for (const [count, budget] of [[1, 2000], [3, 4000], [5, 6000], [10, 11000], [20, 21000]]) {
    assert.equal(searchOutputBudget(count), budget)
    assert.equal(searchOutputBudget(count, 8000), 8000)
    assert.equal(searchOutputBudget(count, -1), budget)
  }
  assert.equal(searchOutputBudget(), 11000)
  for (const count of [0, 21, 1.5, NaN]) assert.equal(searchOutputBudget(count), 11000)
})

test("long titles, dates and snippets remain complete when within the total budget", () => {
  const title = "Long title ".repeat(30)
  const snippet = "Full evidence ".repeat(100)
  const published = "date context ".repeat(10)
  const output = compactSearchResults(JSON.stringify([{ t: 0, title, url: "https://example.com", snippet, published }]), searchOutputBudget(3))
  for (const text of [title, snippet, published]) assert.ok(output.includes(text))
  assert.ok(!output.includes("[truncated]") && !output.includes("omitted by output budget"))
})

test("search deduplicates exact URLs and limits related searches across entries", () => {
  const output = compactSearchResults(JSON.stringify([{ t: 0, title: "First", url: "https://example.com" }, { t: 0, title: "Duplicate", url: "https://example.com", warning: "source warning" }, { t: 1, list: ["one", "two", "one"] }, { t: 1, list: ["three", "four"] }]))
  assert.equal(output.split("https://example.com").length - 1, 1)
  assert.ok(output.includes("1 duplicate URLs omitted"))
  assert.ok(output.includes("source warning"))
  assert.ok(output.includes("Related searches: one; two; three"))
  assert.ok(!output.includes("four"))
})

test("summary unwraps text, preserves source and warnings, and drops transport metadata", () => {
  const output = compactSummaryResult(JSON.stringify({ warnings: ["partial summary"], meta: { tokens: 4000 }, data: { output: "- First fact\n- Second fact", warning: "source warning" } }), 12000, "https://example.com/article")
  for (const text of ["Source: https://example.com/article", "partial summary", "source warning", "- First fact\n- Second fact"]) assert.ok(output.includes(text))
  assert.ok(!output.includes("tokens") && !output.includes('"output"'))
  assert.equal(compactSummaryResult('{"output":"Summary text"}'), "Summary text")
})

test("summary clips Unicode safely and preserves structured failures", () => {
  const output = compactSummaryResult(JSON.stringify({ data: { output: "😀".repeat(12000) } }), 512, "https://example.com")
  assert.ok(output.length <= 512)
  assert.ok(output.includes("[truncated]"))
  assert.ok(output.startsWith("Source: https://example.com"))
  assert.ok(output.isWellFormed())
  const error = '{"error":{"category":"timeout","message":"Timed out","retryable":true}}'
  assert.equal(compactSummaryResult(error), error)
  assert.equal(category(compactSummaryResult('{"data":{"error":"upstream failed"}}')), "service_error")
  assert.equal(category(compactSummaryResult('{"error":"' + "x".repeat(20000) + '"}')), "service_error")
  for (const raw of ['{"data":{}}', '{"output":', "<html>error</html>"]) assert.equal(category(compactSummaryResult(raw)), "unexpected_output")
  const escapedError = JSON.stringify({ error: { category: "timeout", message: "\0".repeat(2000), retryable: true } })
  for (const compact of [compactSearchResults, compactSummaryResult]) {
    const bounded = compact(escapedError, 512)
    assert.ok(bounded.length <= 512)
    assert.equal(JSON.parse(bounded).error.retryable, true)
  }
  assert.equal(compactSummaryResult("Plain summary"), "Plain summary")
  assert.equal(category(compactSummaryResult(" ")), "empty_output")
})

test("output budgets validate overrides and bound diagnostics and unknown payloads", () => {
  for (const value of [0, -1, 511, 200001, 1.5, "8000", null]) assert.equal(outputBudget(value, 8000), 8000)
  assert.equal(outputBudget(512, 8000), 512)
  const raw = JSON.stringify({ warnings: ["x".repeat(20000)], data: [{ t: 9, payload: "HUGE".repeat(20000) }] })
  const output = compactSearchResults(raw, 512)
  assert.ok(output.length <= 512 && !output.includes("HUGE"))
  assert.ok(output.includes("[truncated]") && output.includes("unsupported entries omitted"))
})

test("runner returns output and classifies subprocess failures without leaking arguments or stderr", async () => {
  assert.equal(await run(["success"]), "result")
  for (const [mode, expected, retryable] of [["auth", "authentication", false], ["rate", "rate_limit", true], ["network", "service_unavailable", true], ["fail", "cli_failed", false], ["empty", "empty_output", true]]) {
    const result = await run([mode, "PRIVATE TEXT 429"])
    assert.equal(category(result), expected)
    assert.equal(JSON.parse(result).error.retryable, retryable)
    assert.ok(!result.includes("SECRET") && !result.includes("PRIVATE TEXT"))
  }
})

test("runner bounds execution and output and supports cancellation", async () => {
  assert.equal(category(await run(["slow"], { timeout: 20 })), "timeout")
  assert.equal(category(await run(["large"], { maxBuffer: 32 })), "output_too_large")
  const controller = new AbortController()
  const pending = run(["slow"], { signal: controller.signal })
  controller.abort()
  assert.equal(category(await pending), "cancelled")
  assert.equal(category(await run(["x".repeat(65536)])), "input_too_large")
})

test("missing CLI is actionable and not retryable", async () => {
  const path = process.env.PATH
  process.env.PATH = directory
  try {
    const result = await run(["success"])
    assert.equal(category(result), "cli_missing")
    assert.equal(JSON.parse(result).error.retryable, false)
  } finally {
    process.env.PATH = path
  }
})

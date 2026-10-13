import assert from "node:assert/strict"
import { test } from "node:test"
import { mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import plugin from "./index.ts"

async function definitions(options = {}) {
  const tools = []
  await plugin.setup({ options, tool: { transform: async (callback) => callback({ add: (tool) => tools.push(tool) }) } })
  return tools
}

test("plugin registers discoverable schemas and validates input before execution", async () => {
  const tools = await definitions()
  assert.deepEqual(tools.map((tool) => tool.name), ["kagi_search", "kagi_summarize"])
  assert.deepEqual(tools[1].input.properties.type.enum, ["summary", "takeaway"])
  assert.equal(tools[1].input.oneOf, undefined)
  assert.ok(tools[1].input.properties.text.description.includes("32768"))
  for (const [tool, input] of [[tools[0], { query: " " }], [tools[1], {}], [tools[1], { url: "https://example.com", text: "text" }]]) {
    const result = await tool.execute(input, {})
    assert.equal(JSON.parse(result.content).error.category, "invalid_input")
  }
})

test("per-operation buffer limits are applied independently, with invalid options falling back", async () => {
  const directory = await mkdtemp(join(tmpdir(), "kagi-plugin-tests-"))
  const path = process.env.PATH
  await writeFile(join(directory, "kagi-ken-cli"), `#!${process.execPath}\nconst text = "x".repeat(512); console.log(JSON.stringify({data:process.argv[2] === "search" ? [{t:0,url:"https://example.com",snippet:text}] : {output:text}}))\n`, { mode: 0o700 })
  process.env.PATH = directory
  try {
    const tools = await definitions({ searchMaxBufferBytes: 128, summarizeMaxBufferBytes: 1024 })
    const search = await tools[0].execute({ query: "public query" }, {})
    const summary = await tools[1].execute({ text: "public text" }, {})
    assert.equal(JSON.parse(search.content).error.category, "output_too_large")
    assert.equal(summary.content.length, 512)
    const defaults = await definitions({ searchMaxBufferBytes: -1, searchTimeoutMs: 0 })
    assert.ok((await defaults[0].execute({ query: "public query" }, {})).content.includes("x".repeat(512)))
    const bounded = await definitions({ searchOutputChars: 512, summarizeOutputChars: 512 })
    const boundedSearch = await bounded[0].execute({ query: "public query" }, {})
    const boundedSummary = await bounded[1].execute({ text: "public text" }, {})
    assert.ok(boundedSearch.content.length <= 512 && boundedSearch.content.includes("omitted by output budget"))
    assert.equal(boundedSummary.content.length, 512)
  } finally {
    process.env.PATH = path
    await rm(directory, { recursive: true, force: true })
  }
})

test("plugin forwards cancellation and accepts bounded per-operation options", async () => {
  const tools = await definitions({ searchTimeoutMs: 1000, summarizeTimeoutMs: 2000, searchMaxBufferBytes: 1024, summarizeMaxBufferBytes: 2048 })
  const controller = new AbortController()
  controller.abort()
  for (const [tool, input] of [[tools[0], { query: "public query" }], [tools[1], { text: "public test text" }]]) {
    const result = await tool.execute(input, { signal: controller.signal })
    assert.equal(JSON.parse(result.content).error.category, "cancelled")
  }
})

test("search execution uses requested-count budgets rather than actual-result counts", async () => {
  const directory = await mkdtemp(join(tmpdir(), "kagi-scaled-tests-"))
  const path = process.env.PATH
  await writeFile(join(directory, "kagi-ken-cli"), `#!${process.execPath}\nconsole.log(JSON.stringify({data:Array.from({length:3},(_,i)=>({t:0,url:"https://example.com/"+i,snippet:"x".repeat(1400)}))}))\n`, { mode: 0o700 })
  process.env.PATH = directory
  try {
    const tools = await definitions()
    const small = (await tools[0].execute({ query: "public query", limit: 3 }, {})).content
    const larger = (await tools[0].execute({ query: "public query", limit: 5 }, {})).content
    assert.ok(small.length <= 4000 && small.includes("omitted by output budget"))
    assert.ok(larger.length > 4000 && larger.length <= 6000 && !larger.includes("omitted by output budget"))
    assert.ok(larger.includes("x".repeat(1400)))
    const override = await definitions({ searchOutputChars: 6000 })
    assert.equal((await override[0].execute({ query: "public query", limit: 3 }, {})).content, larger)
  } finally {
    process.env.PATH = path
    await rm(directory, { recursive: true, force: true })
  }
})

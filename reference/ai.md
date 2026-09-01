# The AI surface

`ai` is a keyword. Everything here works offline with no API key.

## Forms

```ecko
type Mood = Happy | Sad

untyped = ai "What is the capital of France?"        # -> string
typed   = ai[Int] "How many words: hello there"      # -> Int, coerced
mood    = ai[Mood] "Classify: what a lovely day"     # -> a variant
listed  = ai[json<List<Int>>] "List three primes"    # -> List
voted   = ai[Mood] 5 "classify this review"          # 5 samples, majority wins

print(type_of(untyped) + " " + type_of(typed) + " " + type_of(listed))
```

Modifier clauses, and what they refuse to combine with:

| clause | meaning | cannot combine with |
|---|---|---|
| `[T]` | typed output | (composes with everything) |
| `n` (before the prompt) | majority vote of n samples, 1-25 | `-> stream` |
| `using [tools]` | tool-call loop | voting, `-> stream` |
| `with session` | conversation history | `using`, voting, `-> stream` |
| `on image` | vision input | `using`, `with`, voting, `-> stream` |
| `-> stream` | background + incremental | voting, `using`, `with` |

## Typed output and coercion

`ai[T]` sends a JSON schema derived from `T` and coerces the response back
through it. A record's **declared field types are real**, not just its names:

```ecko
type User = User { name: String, age: Int, tags: List<String> }
u = ai[User] "invent a user"
print(type_of(u.age))    # int    - not "int as a string"
print(type_of(u.tags))   # list
```

`Int`, `Float`, `Bool`, `String`, `List<T>`, `Map<K,V>`, `Option<T>` and nested
records all recurse. `Result<T, E>` does **not** - it falls back to the
permissive `json` schema.

When coercion fails, the field name is threaded back to the model as a retry
reason, up to `ECKO_AI_MAX_RETRIES` (default 3). If it still fails, the field
lands `null` rather than throwing.

## Mock mode is the testing story

With no `ECKO_API_KEY`:

- untyped → `[AI Mock] <prompt>`
- `ai[Int]` → `42`, `ai[Bool]` → `true`
- an enum → its first variant
- a record → a schema-valid value per declared field type
- `json<List<T>>` → a one-element list
- a vision call → the prompt plus each image's real dimensions
- a tool loop → invokes every tool named in the prompt, feeds the prompt as the
  argument, returns the last tool's result

`ecko test` **strips API keys**, so tests are deterministic, offline and free by
construction. Design programs so their AI paths are exercised in mock mode.

String contracts always pass in mock mode - they cannot catch anything offline.

## Tools

```ecko
@tool("look up the current weather for a city")
fn weather(city) = "sunny in {city}"

@tool("count indexed documents")
fn doc_count(_) = 3

print(ai "What is the weather in Oslo?" using [weather, doc_count])
```

Each function needs a `@tool("description")`. Names resolve in the lexical scope
of the `ai` expression. Live, the tools a model requests in one round run
**concurrently**, each bounded by `ECKO_AI_TOOL_TIMEOUT_MS` (default 30000); the
loop is capped at `ECKO_AI_MAX_TOOL_ROUNDS` (default 8). A failing tool yields
an error string back to the model, so one bad tool never stalls the loop.

**Runtime-discovered tools** use a spec map instead of a bare identifier, which
is how an MCP server or plugin registry offers tools that have no source-level
annotation:

```
{ name: "search", description: "Search the docs", params: ["query"], call: fn(args) ... }
```

`name`, `description` and `call` are required; `params` defaults to `[]`. Bare
identifiers and spec maps mix in one list.

## Conversations

```ecko
chat = session()
ai "My name is Ada." with chat
who = ai "What is my name?" with chat
print(len(cell_get(chat)))     # 4 - two prompts, two replies
```

A session is a `cell` of `{ role, content }` messages, sent as a native
role-separated array. Read it with `cell_get`. Conversational turns bypass the
prompt cache.

## Retrieval (`std.rag`)

```ecko
import std.rag

kb = [
    { id: "ai", text: "Ecko treats ai as a language keyword." },
    { id: "pkg", text: "Packages vendor into ./vendor with sha256 pinning." },
]
index = rag.index(kb)
hits = rag.retrieve(index, "what is ai in ecko", k: 1)
print(map(hits, fn(h) h.id))
print(len(rag.answer(index, "what is ai in ecko", k: 1)) > 0)
```

`rag.index` embeds a corpus, `rag.retrieve` ranks hybrid (dense cosine blended
with lexical overlap, so it stays sensible offline), and `rag.answer` grounds an
`ai` answer in the retrieved context. `rag.chunk` splits long documents into
overlapping passages.

## Budgets and cost

```ecko
n = tokens("some prompt text")
print(n)
print(cost("gpt-4o-mini", n, 500) >= 0.0)
print(retry(2, fn() 7))
```

- `tokens(text)` counts with cl100k_base.
- `cost(model, in, out)` prices from a built-in table and **errors on an unknown
  model**, so a typo cannot silently price at zero. Pass explicit prices for
  models not in the table.
- `retry(n, f)` re-runs `f` on error with exponential backoff.
- `ECKO_AI_MAX_CALLS` is the hard stop across every vote, retry and tool round.

**The dials multiply.** A typed call retries up to 3 times; each voting sample
runs its own retry loop; each tool round is a call. `ai[T] 5 "..."` can spend 20
provider calls. A string `@ensures` on a typed `ai` body compounds to a worst
case of 16. **Set `ECKO_AI_MAX_CALLS` in production** so a failing contract on a
hot path fails fast instead of spending.

## Tracing

`ECKO_TRACE=1` (or `stderr`) traces every call to stderr; a file path appends
JSONL. Each record carries call id, source line/col, provider, model, mock flag,
prompt with a content hash, response, latency, retry count, token usage and cost.

The trace records prompts and responses **verbatim**. An unrevealed `secret`
renders redacted, but a `reveal()`ed value interpolated into a prompt lands in
the trace file. Treat trace output like any log.

## Caching

`ECKO_AI_CACHE=<dir>` (or `--cache`) enables a content-addressed prompt cache.
Identical calls - same provider, model, prompt and schema - replay through the
normal coercion path: no API call, no budget consumption, traced as
`cached: true`. Votes and conversational turns bypass it. Mock mode bypasses it.

## Vision

```
import std.image
img = image.load("chart.png")
ai "what does this chart show?" on img
ai[Kind] "classify this image" on img
ai "spot the differences" on [before, after]
```

Serializes to OpenAI `image_url` data-URLs or Ollama base64 arrays from the same
source. Mock mode echoes the prompt plus real image dimensions.

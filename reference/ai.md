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

With no `ECKO_AI_API_KEY`:

- untyped → `[AI Mock] <prompt>`
- `ai[Int]` → `42`, `ai[Bool]` → `true`
- an enum → its first variant
- a record → a schema-valid value per declared field type
- `json<List<T>>` → a one-element list
- a vision call → the prompt plus each image's real dimensions
- a tool loop → invokes every tool named in the prompt, passing the prompt for
  each parameter a model would have to supply (one with a default keeps it);
  untyped returns the last tool's result, typed `ai[T]` returns the mock value
  for `T`

`ecko test` **strips API keys**, so tests are deterministic, offline and free by
construction. Design programs so their AI paths are exercised in mock mode.

String contracts cannot be judged offline, since there is no model to judge
them. They pass, and stderr names each one that went unchecked; `ecko test` adds
`N string contracts not checked offline` to its summary. Do not count them as
tested.

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
an error string back to the model, so one bad tool never stalls the loop. Each
result is capped at `ECKO_AI_TOOL_MAX_RESULT` bytes (default 32768) with the cut
marked, because a tool result stays in the conversation for every later round.

**What an untyped call returns.** The last invoked tool's return value, not the
model's prose - the same offline and against a real provider. If no tool runs,
you get the model's answer instead.

```ecko
@tool("look it up")
fn lookup(q) = { answer: "42", sources: ["a", "b"] }

r = ai "lookup the answer" using [lookup]
print(get(r, "answer"))      # 42
```

So when you want the model's own answer with tools available, **type the call**
and it coerces the final answer instead:

```ecko
@tool("look it up")
fn lookup(q) = "42"

type Evidence = Evidence { answer: String }
print(type_of(ai[Evidence] "lookup the answer" using [lookup]))
```

**Arguments are checked.** A named argument your function does not declare comes
back to the model as an error rather than being dropped, one it left out takes
your declared default, and only parameters without a default are advertised as
required.

**Runtime-discovered tools** use a spec map instead of a bare identifier, which
is how an MCP server or plugin registry offers tools that have no source-level
annotation:

```ecko
search = {
    name: "search",
    description: "Search the docs",
    params: ["query", "limit"],
    call: fn(query, limit) "results for {query}",
}
print(ai "search the docs for tokens" using [search])
```

`name`, `description` and `call` are required; `params` defaults to `[]`.
`call` takes **one positional value per entry in `params`**, in order - not a
single map of arguments. Bare identifiers and spec maps mix in one list.

## Choosing the model per call (`via`)

```ecko
judge = model("openrouter", "anthropic/claude-sonnet-5", reasoning: "low")
verdict = ai[Bool] "Is this argument sound?" via judge
quick = ai "One-word answer: sky colour" via "gpt-4o-mini"
print(verdict)
```

`via m` gives one call its own provider and model, and composes with every
other clause. `m` is a `model(provider, name)` map - provider `openai`,
`openrouter` or `ollama`, with optional `base_url:`, `key:` and `reasoning:` -
or a string naming a model on the configured provider. `reasoning:` (`none`,
`minimal`, `low`, `medium`, `high`, `xhigh`, `max`) sets how hard a reasoning
model thinks; less is faster and cheaper. `ECKO_AI_REASONING` sets it for calls
that do not.

Switching provider never borrows `ECKO_AI_API_KEY`: the key comes from `key:`, else
`OPENROUTER_API_KEY` or `OPENAI_API_KEY`, and a call with no key for its
provider runs in mock mode. A request fails when nothing arrives for
`ECKO_AI_READ_TIMEOUT_MS` (default 120000) - a limit on silence, so a long
reply that keeps streaming is not cut off.

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

## Retrieval

```ecko
kb = [
    { id: "ai", text: "Ecko treats ai as a language keyword." },
    { id: "pkg", text: "Packages vendor into ./vendor with sha256 pinning." },
]
index = map(kb, fn(d) merge(d, { vec: embed(d.text) }))

fn retrieve(query, k) {
    q = embed(query)
    ranked = sort_by(index, fn(d) 0.0 - cosine(q, d.vec))
    take(ranked, k)
}

hits = retrieve("what is ai in ecko", 1)
print(len(hits))                    # 1
context = join(map(hits, fn(h) h.text), "\n")
print(len(ai "Answer from this context only:\n{context}\n\nQ: what is ai?") > 0)
```

Retrieval is two builtins: `embed(text)` turns text into a vector and
`cosine(a, b)` compares two, so an index is a list of maps with a `vec` and a
search is a sort. Offline, `embed` returns a deterministic hash vector rather
than a semantic one, so a mock-mode ranking is stable but not meaningful; blend
in a lexical score (shared words) when an offline test needs a sensible order.
`std.rag` and `std.db` packaged this, are deprecated since 0.59, and go in the
next breaking release - do not import them in new code.

## Budgets and cost

```ecko
n = tokens("some prompt text")
print(n)
print(cost(n, 500, 0.15, 0.6))     # USD at $0.15 / $0.60 per 1M tokens
print(retry(2, fn() 7))
```

- `tokens(text)` counts with cl100k_base.
- `cost(in_tokens, out_tokens, in_per_1m_usd, out_per_1m_usd)` prices a call
  at the rates **you** pass. There is no built-in price table since 0.59 -
  providers reprice, so it went stale - and `cost(model, in, out)` is an error
  saying so.
- `retry(n, f)` re-runs `f` on error with exponential backoff.
- `ECKO_AI_MAX_CALLS` is the hard stop across every vote, retry and tool round.

**The dials multiply.** A typed call retries up to 3 times; each voting sample
runs its own retry loop; each tool round is a call. `ai[T] 5 "..."` can spend 20
provider calls. A string `@ensures` on a typed `ai` body compounds to a worst
case of 16. **Set `ECKO_AI_MAX_CALLS` in production** so a failing contract on a
hot path fails fast instead of spending.

## Tracing

`ECKO_AI_TRACE=1` (or `stderr`) traces every call to stderr; a file path appends
JSONL. Each record carries call id, source line/col, provider, model, mock flag,
prompt with a content hash, response, latency, retry count and token usage.
`cost_usd` is `null`: Ecko no longer guesses prices, so price the token counts
with `cost(...)` at your provider's rates.

The trace records prompts and responses **verbatim**. An unrevealed `secret`
renders redacted, but a `reveal()`ed value interpolated into a prompt lands in
the trace file. Treat trace output like any log.

## Caching

`ECKO_AI_CACHE=<dir>` (or `ecko --cache app.ecko`, which uses `.ecko-cache/` -
Ecko's own flags go before the file) enables a content-addressed prompt cache.
Identical calls - same provider, model, prompt and schema - replay through the
normal coercion path: no API call, no budget consumption, traced as
`cached: true`. Votes and conversational turns bypass it. Mock mode bypasses it.

## Vision

```
import std.image
img = image.load("chart.png")
ai "what does this chart show?" on img
ai[Kind] "classify this image" on image.resize(img, 1024, 1024)
ai "spot the differences" on [before, after]
```

An image is a **value** since 0.59: a map `{ format, width, height, bytes }`, so
`img.width` works, a transform returns a new image, and nothing needs freeing
(`image.free` is a deprecated no-op). Passing an integer to `on` - the old
handle - is an error. Resize before sending: images cost tokens, and a
4000-pixel photo rarely answers better than a 1000-pixel one.

Serializes to OpenAI `image_url` data-URLs or Ollama base64 arrays from the same
source. Mock mode echoes the prompt plus real image dimensions.

---
name: ecko
description: Write, review and debug Ecko programs. Use for any .ecko file, ecko.json manifest, or ecko CLI command. Ecko is a language where `ai` is a keyword rather than a library - typed LLM output, tool calling, contracts, and a deterministic offline mock mode.
---

# Writing Ecko

Ecko is a general-purpose scripting language whose distinguishing feature is
that **`ai` is a keyword**. There is no SDK to wire up, no client to construct,
no API-key plumbing in code. `ai "prompt"` is an expression.

Its centre of gravity is **AI orchestration**: prompt pipelines, typed model
output, tool loops, retrieval, agents. It is competent at general scripting
(web, data, CLI) and deliberately weak at tight numeric loops, which is what
`py()` exists for.

## Before you write anything

Three habits, in order. They catch most of what an LLM gets wrong about Ecko:

```bash
ecko check file.ecko     # static analysis - undefined names, arity, types, exhaustiveness
ecko fmt file.ecko       # canonical formatting, rewrites deprecated syntax
ecko file.ecko           # run it
ecko test                # discovers tests/*.ecko and *_test.ecko
```

`ecko check` runs automatically before every `ecko file.ecko`, and an
error-severity finding **stops the program before it starts**. Treat a clean
`ecko check` as the bar for "I finished."

`ecko --help` is authoritative and current. Prefer it over memory.

## The mental model in six points

1. **Immutable by default.** `let x = 1` cannot be reassigned. `mut x = 1` can.
   A bare `x = 1` defines a mutable binding.
2. **A newline ends a statement.** No semicolons. Lines continue only after a
   trailing binary operator, before a leading `|>` or `.`, or inside `(...)`/`[...]`.
3. **Access is strict.** `m.missing` and `xs[99]` are errors. `get(m, k)` is the
   nullable lookup that returns `null`.
4. **Everything runs offline.** With no `ECKO_API_KEY`, `ai` returns
   deterministic, schema-valid mock values. Never write a program that needs a
   key to be testable.
5. **One error dialect.** Absence returns `null`; operational failures throw
   `{ kind, message }` maps; programmer mistakes throw prose strings.
6. **Blocks are expressions.** The trailing expression is the value; `return` is
   optional.

## Syntax essentials

```ecko
# Bindings
let PI = 3.14159            # immutable
mut count = 0               # mutable
name = "Ecko"               # bare assignment: also mutable
let (a, b) = [1, 2]         # destructuring; strict on length

# Functions - `fn(x)` is the canonical lambda. `|x|` is DEPRECATED.
fn add(a, b) = a + b                 # expression body
fn describe(n) {                     # block body; last expression is the value
    if n > 0 { "positive" } else { "other" }
}
double = fn(x) x * 2                 # anonymous
fn box(w, h, fill = "-") = fill * (w * h)    # default parameter
box(2, h: 3)                                  # named argument

# Control flow - all of these are expressions
status = if count > 0 { "some" } else { "none" }
unless count > 0 { print("empty") }          # negated if; good as a guard
for i in 0..3 { print(i) }                   # 0..3 exclusive, 0..=3 inclusive
for (k, v) in { a: 1, b: 2 } { print(k) }    # maps iterate sorted, as [k, v]
for (i, x) in enumerate(["a", "b"]) { print(string(i) + x) }

# Pipelines - the idiomatic way to express a transformation
result = [3, 1, 2]
    |> map(fn(x) x * 2)
    |> sort

# Pattern matching
fn classify(n) = match n {
    0 => "zero"
    n when n > 0 => "positive"
    _ => "negative"
}

# String interpolation
who = "world"
print("hello {who}")
print("hello {upper(who)}")
```

That block runs as-is and prints `empty`, `0`, `1`, `2`, `a`, `b`, `0a`, `1b`,
`hello world`, `hello WORLD`. Every `ecko` block in this skill and its reference
files is executed by `verify.sh` - if one does not run, it is a bug.

## The AI primitives

This is why Ecko exists. Read `reference/ai.md` for depth.

```ecko
# Untyped - returns a string
answer = ai "What is the capital of France?"

# Typed - the model's output is coerced into the type, with retries
count = ai[Int] "How many words are in: hello there world"
type Mood = Happy | Sad
mood = ai[Mood] "Classify the sentiment of: what a lovely day"

# Voting - n independent samples, majority wins. A quality dial.
best = ai[Mood] 5 "classify this review"

# Tools - the runtime drives the call loop
@tool("look up the current weather for a city")
fn weather(city) = "sunny in {city}"
report = ai "What is the weather in Oslo?" using [weather]

# Conversations
chat = session()
ai "My name is Ada." with chat
who = ai "What is my name?" with chat

# Streaming
story = ai "Write a short story" -> stream
for chunk in story { print_no_newline(chunk) }
```

**Offline behaviour is a feature, not a fallback.** With no key: untyped calls
return `[AI Mock] <prompt>`; `ai[Int]` returns `42`; an enum returns its first
variant; a record returns a schema-valid value per declared field type. This is
what makes AI pipelines unit-testable, and `ecko test` **forces** mock mode by
stripping API keys.

**Configuration is environment, never code:**
`ECKO_API_KEY`, `ECKO_AI_PROVIDER` (`openai` | `openrouter` | `ollama`),
`ECKO_AI_MODEL`, `ECKO_AI_MAX_CALLS` (hard budget), `ECKO_TRACE`.

## Types and records

```ecko
type Shape = Circle { r: Int } | Square { side: Int }
type User = User { name: String, age: Int }

u = User("Ada", 36)
print(u.name)

area = match Circle(3) {
    Circle(r) => 3 * r * r
    Square(s) => s * s
}
```

**Declared field types are enforced.** `User("Bob", "x")` throws
``field `age` of `User` expects Int, got string`` - and `ecko check` catches it
statically when the value is a literal. Assignment is checked by the same
matcher. A `Float` field accepts an `Int`; an `Int` field rejects a `Float`.

Plain maps have no declared types and stay permissive.

## Errors

```ecko
import std.json

try {
    data = json.decode(r"{malformed")
} catch (e) {
    match get(e, "kind") {
        "parse" => print("bad payload: " + get(e, "message"))
        "net"   => print("offline")
        _       => error(e)          # re-throw what you do not handle
    }
}
```

Use `get(e, "kind")`, never `e.kind` - `get` is total, so the same match also
handles plain-string errors (their `kind` is `null`).

Stdlib kinds: `parse`, `fs`, `net`, `sql`, `closed`, `budget`, `capability`,
`cancelled`, `assert`.

For your own recoverable failures, throw the same shape:
`error({ kind: "not_found", message: "no user 0" })`.

`Ok`/`Err` and `Some`/`None` exist as ordinary data types for your own
modelling. **They are not the error channel** - nothing in the stdlib returns
them.

## Money and secrets

```ecko
price = 19.99m                      # decimal literal - exact base-10
print(price * 3)                    # 59.97, exactly
print(0.1m + 0.2m)                  # 0.3
print(0.1 + 0.2)                    # 0.30000000000000004  (float)

key = secret("hunter2")
print(key)                          # [secret]
print("key={key}")                  # key=[secret]
print(reveal(key))                  # hunter2 - the only way out
```

Use `decimal` for money, always. Mixing `decimal` with `float` is a hard error
by design. `secret()` redacts through every stringifying sink, so `grep reveal`
audits every exposure point.

## Concurrency

```ecko
async fn fetch_one(n) { n * 2 }

tasks = map([1, 2, 3], fn(n) fetch_one(n))   # calling an async fn spawns it
results = map(tasks, fn(t) await t)          # then join

print(pmap([1, 2, 3], fn(n) n + 1))          # data-parallel map

counter = cell(0)                            # thread-safe shared state
cell_update(counter, fn(v) v + 1)            # atomic; do NOT use cell_set for this
```

Workers are **share-nothing**: each snapshots captured variables. Mutating an
ordinary outer `mut` from a parallel closure changes only that worker's copy.
`cell` is the one intentional exception.

## Testing

```ecko
import std.test

fn slug(s) = replace(lower(s), " ", "-")

test.case("slugify", fn() {
    test.eq(slug("Hello World"), "hello-world")
    test.ok(contains("ecko", "ck"), "substring")
})
test.case("errors", fn() {
    test.err(fn() error("boom"), "boom")
})
```

`ecko test` discovers `tests/*.ecko` and `*_test.ecko`, exits non-zero on
failure, and forces mock mode. Put tests in `tests/` - a root-level
`*_test.ecko` ships inside `ecko pack` archives.

## The seven mistakes an LLM makes first

1. **Every regex must be a raw string.** `re.test("^[A-Z]{3}$", x)` returns
   **false** with no error, because `{3}` was interpolated away. Write
   `r"^[A-Z]{3}$"`. `ecko check` warns (`regex-interpolation`), which is another
   reason to run it.
2. **Nested double quotes inside interpolation.** `"{upper("x")}"` is a parse
   error. Bind first: `u = upper("x")` then `"{u}"`.
3. **A literal `{` in a string starts interpolation.** Escape it `\{`, or use a
   raw string. For JSON literals use `r"""{"a": 1}"""`.
4. **The string module is `std.str`, not `std.string`.** A module binds the last
   segment of its path, and one called `string` would displace the `string()`
   converter for the whole file. `import std.string` is an error naming the fix.
5. **Writing `|x| ...` for a lambda.** Deprecated since 0.9.4. Use `fn(x) ...`.
6. **Reaching for `e.kind` on a caught error.** Use `get(e, "kind")` - a caught
   error is sometimes a plain string, and `get` is total.
7. **Assuming `m.missing` returns null.** It raises. Use `get(m, "missing")`.

**Do not guess builtin names.** There is no `min_by`, `fold`, `append`, `merge`,
`eprint` or `hash`. `reference/builtins.md` is the probed list of all 102, with
replacements for the names that feel like they should exist.

`reference/gotchas.md` has 28 traps with the exact error each produces.

## Reference files

- `reference/builtins.md` - all 102 globals, probed against the runtime, plus
  the names that do not exist and what to use instead
- `reference/language.md` - complete syntax: strings, bytes, slicing, modules,
  packages, channels, templates, contracts
- `reference/ai.md` - the AI surface in depth: typed coercion, retries, tool
  specs, sessions, vision, budgets, tracing
- `reference/stdlib.md` - all 40 `std.*` modules and every builtin, indexed
- `reference/gotchas.md` - 28 traps, with the error each produces
- `reference/recipes.md` - complete, verified programs for common tasks

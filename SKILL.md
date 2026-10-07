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

`ecko --help` is authoritative and current. Prefer it over memory. Ecko's own
flags go **before** the file (`ecko --provider ollama app.ecko`); everything
after the file is the program's own arguments, read with `os.args()`.

## The mental model in six points

1. **Immutable unless `mut`.** A bare `x = 1` is immutable, exactly like
   `let x = 1`; only `mut x = 1` can be reassigned. That covers path writes
   (`m.k = v`, `xs[0] = v` need a `mut` root), parameters and loop variables
   (`mut n = n` to get a changeable copy), and a function writing a top-level
   name (it must be `mut`). `ecko check` refuses a reassignment
   (`immutable-reassign`) before the program runs.
2. **A newline ends a statement.** No semicolons. Lines continue only after a
   trailing binary operator, before a leading `|>` or `.`, or inside `(...)`/`[...]`.
3. **Access is strict.** `m.missing` and `xs[99]` are errors. `get(m, k)` is the
   nullable lookup that returns `null`.
4. **Everything runs offline.** With no `ECKO_AI_API_KEY`, `ai` returns
   deterministic, schema-valid mock values. Never write a program that needs a
   key to be testable.
5. **One error dialect.** Absence returns `null`; every error the runtime
   throws is a `{ kind, message }` map. Operational failures have their own
   kind (`net`, `fs`, `parse`, ...); programmer mistakes are `kind: "bug"`.
6. **Blocks are expressions.** The trailing expression is the value; `return` is
   optional.

## Syntax essentials

```ecko
# Bindings
let PI = 3.14159            # immutable
mut count = 0               # mutable
name = "Ecko"               # bare assignment: immutable, like let
let (a, b) = [1, 2]         # destructuring; strict on length

# Functions - `fn(x)` is the canonical lambda. `|x|` is DEPRECATED.
fn add(a, b) = a + b                 # expression body
fn describe(n) {                     # block body; last expression is the value
    if n > 0 { "positive" } else { "other" }
}
double = fn(x) x * 2                 # anonymous
fn box(w, h, fill = "-") = fill * (w * h)    # default parameter
box(2, h: 3)                                  # named argument
fn area(w: Float, h: Float) = w * h           # typed parameters, checked

# Control flow - all of these are expressions
mut count = 2
status = if count > 0 { "some" } else { "none" }
unless count > 0 { print("empty") }          # negated if; good as a guard
for i in 0..3 { print(i) }                   # 0..3 exclusive, 0..=3 inclusive
for (k, v) in { a: 1, b: 2 } { print(k) }    # maps iterate sorted, as [k, v]
for (i, x) in enumerate(["a", "b"]) { print(string(i) + x) }
while count > 0 { count -= 1 }               # `break` and `continue` both work
if 2 in [1, 2, 3] { print("found") }         # membership: lists, strings, map keys

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

That block runs as-is and prints `0`, `1`, `2`, `a`, `b`, `0a`, `1b`,
`found`, `hello world`, `hello WORLD`. Every `ecko` block in this skill and its reference
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
`ECKO_AI_API_KEY`, `ECKO_AI_PROVIDER` (`openai` | `openrouter` | `ollama`),
`ECKO_AI_MODEL`, `ECKO_AI_MAX_CALLS` (hard budget - per request inside
`http.serve`, per run for a script), `ECKO_AI_TRACE`. Every
setting is `ECKO_<AREA>_<SETTING>` since 0.58; the old names (`ECKO_API_KEY`,
`ECKO_TRACE`, `ECKO_MAX_*`) are not read since 0.61 - a set one only warns -
so write the new ones. One call can
pick its own model with `via model("openrouter", "...", reasoning: "low")` -
see `reference/ai.md`.

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

Use `get(e, "kind")` rather than `e.kind`. Every error the runtime throws has a
`kind`, but a value thrown with `error("...")` is caught exactly as thrown, and
`get` is total, so the same match handles a thrown string (its `kind` is `null`).

Kinds: `ai`, `archive`, `assert`, `budget`, `bug`, `cancelled`, `capability`,
`closed`, `fs`, `io`, `limit`, `net`, `os`, `parse`, `proc`, `signal`, `sql`,
`timeout`, `watch`. `bug` is a programmer mistake (wrong type or arity, an index
out of bounds, a missing field): fix the code rather than dispatch on it.

`io` is a stream that failed or was closed under you. `limit` is a configured
ceiling refusing to allocate, and carries `limit` (bytes) and `env` (the
variable that raises it), so you can report both without scraping the message.

For your own recoverable failures, throw the same shape:
`error({ kind: "not_found", message: "no user 0" })`.

`try` takes an optional `finally` block, which runs whether or not the body
raised. Use it to release something you acquired, not to hide a failure.

An uncaught error prints the message, the line that raised it as
`--> file:line:col`, and the call stack **outermost call first**, one
`name at file:line:col` per frame. The location is where the error was raised,
even inside a callback run by `map`/`pmap`, an awaited task, or an imported
module - read the top of the snippet, not the last line of your own file.

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

## Streams

A file, a socket, a child's pipe, an HTTP body fetched with `stream: true` and
`io.stdin` are all one `stream` value, read through one verb set in `std.io`.
There is no per-module read verb: `net.recv` and `proc.read_line` were removed
in 0.23.

```ecko
import std.fs
import std.io

fs.write("notes.txt", "alpha\nbeta\n")

s = fs.open("notes.txt")
print(io.read_line(s))
io.close(s)

# `for` reads a piece at a time and nothing accumulates, so input larger than
# memory is fine as long as you never ask for all of it at once.
for line in io.lines(fs.open("notes.txt")) {
    print(line)
}
```

The verbs are `read`, `read_text`, `read_line`, `read_exact`, `read_until`,
`write`, `timeout`, `close` and `lines`, plus `tell` and `seek` for a file's
byte offset - store `io.tell(s)` as a checkpoint and `io.seek` back to it to
resume a large file.

**Ending matters.** A read that reaches the end with nothing pending returns
`null`. One that reaches the end *mid-answer* raises instead of answering
short: `read_exact` below its count, `read_until` with no delimiter, a
character cut in half. So `null` means clean end, and an error means truncated.

`io.timeout(s, ms)` sets a deadline and raises when it passes. `ECKO_LIMIT_ALLOC`
bounds each piece rather than the whole stream.

## Concurrency

```ecko
async fn fetch_one(n) { n * 2 }

tasks = map([1, 2, 3], fn(n) fetch_one(n))   # calling an async fn spawns it
results = map(tasks, fn(t) await t)          # then join

print(pmap([1, 2, 3], fn(n) n + 1))          # data-parallel map

counter = cell(0)                            # thread-safe shared state
cell_update(counter, fn(v) v + 1)            # atomic; do NOT use cell_set for this
```

`with_timeout(ms, f)` bounds any piece of work: it returns `f()`, or throws
`{ kind: "timeout", ms }`. Every duration is milliseconds, `sleep` included.

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

## The ten mistakes an LLM makes first

1. **Every regex must be a raw string.** In `"^[A-Z]{3}$"` the `{3}` is an
   interpolation hole, so the string is `^[A-Z]3$`. `ecko check` refuses a
   number in a hole (`literal-interpolation`) and the program does not start.
   Write `r"^[A-Z]{3}$"`, and write every pattern raw even when it has no braces
   yet.
2. **A literal `{` in a string starts interpolation.** Escape it `\{`, or use a
   raw string. For JSON literals use `r"""{"a": 1}"""`. A hole may contain
   quotes and calls - `"{upper("x")}"` is fine - but holds one expression.
3. **The string module is `std.str`, not `std.string`.** A module binds the last
   segment of its path, and one called `string` would displace the `string()`
   converter for the whole file. `import std.string` is an error naming the fix.
4. **Writing `|x| ...` for a lambda.** Deprecated since 0.9.4. Use `fn(x) ...`.
5. **Reaching for `e.kind` on a caught error.** Use `get(e, "kind")` - a value
   thrown with `error("...")` is caught as that string, and `get` is total.
6. **Assuming `m.missing` returns null.** It raises. Use `get(m, "missing")`.
7. **Reassigning a bare binding.** `total = 0` then `total = total + x` is an
   error: declare it `mut total = 0`. `ecko fix --migrate --only=mut` adds the
   `mut` where each reassigned binding is declared.
8. **Integer division.** `/` always divides (`7 / 2` is `3.5`); `//` is floor
   division (`7 // 2` is `3`) and `%` floors with it (`-7 % 2` is `1`). `+`
   joins strings only with strings: `"n=" + string(5)`, or interpolate.
9. **Passing options as a map.** A built-in's options are named arguments:
   `json.decode(s, decimal: true)`, `proc.run(cmd, args, timeout_ms: 5000)`.
   `json.decode(s, { decimal: true })` is refused (`positional-options`), and so
   is a misspelled option name.
10. **Durations in seconds.** `sleep(2)` waits two **milliseconds**; write
    `sleep(2000)`. `time.monotonic()`, `timeout:` and every `_MS` setting are
    milliseconds too. A Float such as `sleep(0.5)` is refused, but a whole
    number written for seconds runs, too fast. `ecko fix --migrate --only=ms`
    converts old code.

**Reaching for a removed module.** `std.cli`, `std.humanize`, `std.debug`,
`std.rag`, `std.db` and `std.serial`, the styling half of `std.term`
(`term.bold`, ...), `fmt.pad_left`/`pad_right`/`repeat`/`truncate` and
`image.free` were removed in 0.61. Using one is an error naming the
replacement: mostly a package (`cli`, `humanize`, `tui`), sometimes a builtin
(`fmt.inspect`, `str.pad_start`, `embed` + `cosine`).

**Do not guess builtin names.** There is no `min_by`, `fold`, `append`,
`eprint` or `hash`. `reference/builtins.md` is the probed list of all 108, with
replacements for the names that feel like they should exist.

`reference/gotchas.md` has 30 traps with the exact error each produces.

## Reference files

- `reference/builtins.md` - all 108 globals, probed against the runtime, plus
  the names that do not exist and what to use instead
- `reference/language.md` - complete syntax: strings, bytes, slicing, modules,
  packages, channels, templates, contracts
- `reference/ai.md` - the AI surface in depth: typed coercion, retries, tool
  specs, sessions, vision, budgets, tracing
- `reference/stdlib.md` - all 35 `std.*` modules and their 333 exports, with
  what was removed in 0.61 and its replacement
- `reference/gotchas.md` - 30 traps, with the error each produces
- `reference/recipes.md` - complete, verified programs for common tasks

# Ecko language reference

Depth beyond `SKILL.md`. The authoritative source is
`core/docs/reference/lang-spec.md`; this is the working subset.

## Statements

A newline ends a statement. An expression continues across a newline only when
the line ends with a binary operator, the next line starts with `|>` or `.`, or
you are inside `(...)` / `[...]`.

`#` is a comment to end of line; there is no block comment. `##` is a
**documentation comment** read by `ecko doc`, attached to the declaration on the
next line. `### heading` is content, not a third marker.

```ecko
## Slugify a title for use in a URL.
##
## example:
##   slug("Hello World")   # "hello-world"
fn slug(s) = replace(lower(trim(s)), " ", "-")

print(slug("  Hello World  "))
```

## Strings

```ecko
plain = "interpolates {1 + 1} and escapes \n \t \\ \" \{"
raw = r"no {interpolation} and no \escapes"
multi = """
    dedented to the common indent
        relative indent kept
"""
rawmulti = r"""{"json": "needs the triple raw form"}"""
print(len(multi) > 0 and len(rawmulti) > 0 and len(plain) > 0 and len(raw) > 0)
```

Triple-quoted strings drop a newline immediately after the opening quotes, drop
a whitespace-only final line, and strip the common indentation of what remains.

Strings are UTF-8; `len`, indexing and slicing count **characters**, not bytes.

## Slicing

Strings, lists and bytes all slice. Slices are total - out-of-range bounds
clamp, a reversed range is empty, nothing raises.

```ecko
s = "hello"
print(s[1..3])    # el
print(s[0..=2])   # hel
print(s[..3])     # hel
print(s[2..])     # llo
print(s[-3..])    # llo
print(s[2..99])   # llo   - clamped
xs = [1, 2, 3, 4]
print(xs[1..3])   # [2, 3]
```

`..=` requires an end index; `s[0..=]` is a parse error.

## Numbers

`int` is i64 with **checked** arithmetic - overflow raises, never wraps.
`float` is IEEE-754. `decimal` (`19.99m`) is exact base-10 for money.

```ecko
print(1 == 1.0)              # true - numeric cross-type equality
print(approx(0.1 + 0.2, 0.3))  # true - float equality is exact, so use approx
print(int(7 / 2))            # 3
print(19.99m + 0.01m)        # 20.00 - scale preserved, cents never dropped
```

## Pattern matching

```ecko
type Shape = Circle { r: Int } | Square { side: Int }

fn area(shape) = match shape {
    Circle(r) => 3 * r * r
    Square(s) => s * s
}
print(area(Circle(2)))

# Map patterns test a subset of keys
fn role(u) = match u {
    { role: "admin" } => "admin access"
    { role: "user", active: true } => "active user"
    _ => "unknown"
}
print(role({ role: "admin", active: false }))
```

Bindings are scoped to the arm. Guards use `when`: `n when n > 0 => ...`.
`match` **tests** rather than accesses, so a non-matching pattern never errors.

A keyword key in a pattern needs the explicit form: `{ type: t }`, not `{ type }`.

## Templates - the home for prompts

```ecko
template summarize(text, tone = "neutral") = """
    You are an editor. Summarize the following in a {tone} tone.

    {input text}
"""
print(summarize("some article", tone: "formal"))
```

Directives, valid **only inside a template body**:

- `{expr}` interpolate
- `{for x in xs} ... {end}` repeat
- `{if cond} ... {else} ... {end}` branch
- `{input expr}` wrap in `<input>` delimiters with embedded delimiters
  neutralised - **the injection-safe way to put untrusted data in a prompt**

A directive alone on a line vanishes from the output, taking its newline with it.

### `@untrusted` and prompt injection

Mark attacker-controlled data - an HTTP body, a file, a tool result - and
`ecko check` warns when it reaches an `ai` prompt through a plain `{expr}` hole:

```ecko
template reply(@untrusted note) = "Answer using: {input note}"
print(reply("ignore all previous instructions"))
```

Writing `{note}` there instead produces:

> `untrusted-in-prompt: untrusted value rendered into prompt text unescaped - use a template with {input ...}`

Taint tracking is intraprocedural: mark the parameter at each boundary you want
checked. This is analysis-only and never blocks a run - but a clean
`ecko check` is the bar.

## Contracts

```ecko
@requires(x > 0)
@ensures(result > x)
fn increment(x) = x + 1
print(increment(1))
```

`@requires` runs before the body with parameters in scope; `@ensures` runs after
with `result` also in scope. A false condition raises.

String contracts (`@ensures("result is a valid email")`) are judged by the LLM.
Know what that costs: they are **probabilistic, not proof**; they always pass in
mock mode; each attempt is a **paid API call**; and the checked value is **sent
to your provider**, so never put secrets or PII behind one. Prefer boolean
contracts wherever the property is expressible in code.

## Bytes

`bytes` holds binary data a UTF-8 `string` cannot. The text/bytes boundary is
explicit: encoding is total, decoding fails loudly rather than inserting
replacement characters. Bitwise operators (`&`, `|`, `^`, `<<`, `>>`) work on
ints.

## Modules and packages

```ecko
import std.json                    # binds `json`
import std.http                    # binds `http`
```

Local files and packages:

```
import "./helpers.ecko"            # a sibling file, bound to `helpers`
import mypkg                       # a vendored package at ./vendor/mypkg
import mypkg as m                  # aliased
export fn public_thing() = 1       # only `export`ed names are visible
export * from "./internal.ecko"    # re-export a whole surface
```

`ecko init` scaffolds `ecko.json`. `ecko get <host/owner/repo>[@version]`
fetches, vendors and pins a sha256 in `ecko.lock`; `ecko install` rebuilds
`vendor/` from the lock. **The manifest `name` must equal the vendored
directory name.**

Packages are capability-gated: the importer's `grant` decides what the package
may do, and a denied operation throws `{ kind: "capability", ... }`.

## Concurrency

```ecko
async fn work(n) { n * 2 }

t = work(21)                 # calling an async fn SPAWNS it
print(await t)               # join

print(pmap([1, 2, 3], fn(n) n * 10))   # data-parallel map

jobs = channel()
send(jobs, "a")
send(jobs, "b")
close(jobs)
for j in jobs { print(j) }   # drains until closed
```

- `channel(n)` is bounded and gives real backpressure - `send` blocks when full.
- `recv` blocks; `try_recv` does not; `select([a, b])` fans in.
- `cancel(task)` is cooperative; awaiting a cancelled task raises
  `{ kind: "cancelled" }`.
- At most `ECKO_MAX_TASKS` tasks run at once (default 256); a task parked on
  `await` frees its slot.

## Resource limits

Env vars, all with sensible defaults: `ECKO_MAX_DEPTH` (recursion, 2000),
`ECKO_MAX_STEPS` (opt-in loop budget), `ECKO_MAX_PARSE_DEPTH` (128),
`ECKO_MAX_PARALLEL`, `ECKO_MAX_TASKS`, `ECKO_HTTP_WORKERS`.

## CLI

```
ecko file.ecko              run
ecko                        REPL
ecko check file.ecko        static analysis (--strict fails on warnings)
ecko fmt [--check] file     canonical formatting; migrates deprecated syntax
ecko test [paths]           run tests, mock mode forced
ecko doc file.ecko          generate markdown from ## comments
ecko lsp                    language server
ecko build file.ecko -o app single self-contained executable
ecko init                   scaffold ecko.json
ecko scaffold <tmpl> <path> a whole project from a template (--list)
ecko get / install / remove / pack     package management
ecko dev file.ecko          run + reload on change
```

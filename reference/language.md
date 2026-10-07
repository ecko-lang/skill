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

## Parameters, assignment and membership (since 0.58)

```ecko
fn fee(amount: Decimal, rate: Decimal = 0.03m) = amount * rate
print(fee(100.00m))                 # 3.0000 - the scales add

mut total = 0
for n in [3, 4, 5] {
    total += n                      # also -=, *=, /=, //=, %=
}
print(total)                        # 12

print(2 in [1, 2, 3])               # true - same answer as contains(xs, x)
print("ck" in "ecko")               # true - substring
print("a" in { a: 1 })              # true - a map key
print(not 9 in 0..5)                # true - `not x in xs` is `not (x in xs)`
```

- **A parameter type is checked**, by the same rules as a record field: `Int`
  widens to `Float` and `Decimal`, `Float` never narrows to `Int`, `Option<T>`
  also takes `null`, `List<T>` checks each element. `ecko check` refuses a
  literal that can never fit (`fee("5")`) before the program runs; any other
  value is checked on entry and throws ``parameter `amount` of `fee` expects
  Decimal, got string`` (`kind: "bug"`). Unannotated parameters take anything.
  On an `@tool` function the annotations are the schema the model sees.
- **A return type is checked too (since 0.60)**: `fn label(n) -> String`
  holds on every value the function returns - its last value and each
  `return` - by the same rules, and throws `` `label` is declared to return
  String, but returned int `` (`kind: "bug"`) before any `@ensures` runs. A
  function that can end without a value returns `null`, so it needs
  `-> Option<T>`. Only write `-> T` when it is true; leaving it off is fine.
- **Each `for` iteration has its own loop variable (since 0.60)**, so a
  closure made in the loop keeps its item: pushing `fn() i * 10` for `i` in
  `[1, 2, 3]` gives `[10, 20, 30]`. A `mut` declared outside the loop is still
  shared by every closure.
- **`x += e` is `x = x + e`**: the binding still has to be `mut`, and it works
  through fields and indexes (`m.n += 1`, `xs[0] += 1`). A target with a side
  effect, `xs[next()] += 1`, is refused - bind the index first.
- **`in` works on lists, strings, bytes, map keys and Int ranges.** A pair it
  cannot answer, such as `1 in 5`, is an error rather than `false`.

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

`\u{...}` is a Unicode escape taking 1-6 hex digits: `"caf\u{e9}"` is `café`.
An escape that is not a character is an error.

A hole holds **one** expression: `"{a b}"` is a parse error. A hole holding only
a number (`"{3}"`) is refused by `ecko check`, since it is almost always a regex
quantifier or a literal brace that wanted a raw string.

```ecko
print("caf\u{e9}")        # café
print(r"^[A-Z]{3}$")      # a raw string keeps the braces
print("\{3}")             # {3} - or escape the brace
```

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

Indices count characters, not bytes, and a UTF-8 string cannot jump to the
i-th character - `s[i]` counts up to `i` each time, quickly for ASCII text. **To
visit every character, loop: `for c in s` walks the string once**, where
`while i < len(s) { s[i] }` costs more the longer the string gets.

## Numbers

`int` is i64 with **checked** arithmetic - overflow raises, never wraps.
`float` is IEEE-754. `decimal` (`19.99m`) is exact base-10 for money.

A float literal may carry an exponent: `1e3`, `2.5e-9`, `6.022e23`. An exponent
always produces a `float`, so `1e3` is `1000.0` and not the integer `1000`. At
least one digit must follow the `e` and its optional sign, which is what keeps
`e` usable as an ordinary name.

```ecko
print(1 == 1.0)              # true - numeric cross-type equality
print(approx(0.1 + 0.2, 0.3))  # true - float equality is exact, so use approx
print(7 / 2)                 # 3.5 - `/` always divides
print(7 // 2)                # 3 - floor division
print(-7 % 2)                # 1 - `%` floors, like `//`
print("n=" + string(5))      # `+` joins strings only with strings
print(19.99m + 0.01m)        # 20.00 - scale preserved, cents never dropped
print(round(12.345m, 2))     # 12.35 - a decimal stays a decimal at that scale
print(round(12.5, 0, "half_even"))   # 12
```

`round(x, places, mode?)` rounds halves away from zero unless `mode` says
otherwise: `half_up`, `half_even`, `half_down`, `up`, `down`, `ceiling`,
`floor`. One-argument `round` is unchanged.

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
When **no** arm matches, the error names the value -
`Non-exhaustive match: no pattern matched "io"` - and inside a `catch (e)`
block it also names the error being handled, `(while handling: disk full)`.
End a `match` on `get(e, "kind")` with `_ => error(e)` so nothing is lost.

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
Know what that costs: they are **probabilistic, not proof**; offline they pass
unchecked (stderr names each one); each attempt is a **paid API call**; and the checked value is **sent
to your provider**, so never put secrets or PII behind one. Prefer boolean
contracts wherever the property is expressible in code.

## Bitwise

Bitwise operators are **words**, not symbols: `band`, `bor`, `bxor`, `bnot`,
`shl`, `shr`. Writing `a & b` or `a << 1` is a parse error.

```ecko
print(6 band 3)        # 2
print(6 bor 3)         # 7
print(1 shl 4)         # 16
```

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

The manifest is found by walking **up** from the importing file, so a bare
`import mypkg` works anywhere in the project - from `app/`, from `tests/`, at
any depth - and `vendor/` is read from the same place. The nearest `ecko.json`
wins, so a nested project is its own root rather than borrowing its parent's
dependencies.

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
  `{ kind: "cancelled" }`. It ends a `sleep` or a channel wait at once.
- `with_timeout(ms, f)` returns `f()`, or throws `{ kind: "timeout", ms }` once
  `f` has run `ms` **milliseconds**. `f` is stopped, not abandoned; a call
  blocked inside a library (a slow query) finishes first.

```ecko
slow = fn() {
    sleep(5000)
    "done"
}
r = try {
    with_timeout(50, slow)
} catch (e) {
    get(e, "kind")
}
print(r)                     # timeout
```
- At most `ECKO_LIMIT_TASKS` tasks run at once (default 256); a task parked on
  `await` frees its slot.

## Resource limits

Env vars, all with sensible defaults: `ECKO_LIMIT_DEPTH` (recursion, 2000),
`ECKO_LIMIT_STEPS` (opt-in loop budget), `ECKO_LIMIT_PARSE_DEPTH` (128),
`ECKO_LIMIT_ALLOC` (256 MiB), `ECKO_LIMIT_PARALLEL`, `ECKO_LIMIT_TASKS`,
`ECKO_HTTP_WORKERS`.

Every setting is named `ECKO_<AREA>_<SETTING>` since 0.58 (`AI_`, `LIMIT_`,
`HTTP_`, `NET_`, `PKG_`, ...). The pre-0.58 names (`ECKO_API_KEY`,
`ECKO_MAX_DEPTH`, `ECKO_TRACE`, ...) are not read since 0.61; one that is set
only prints a warning naming the new one - write the new ones. An invalid value (`ECKO_LIMIT_DEPTH=lots`) stops the run before it
starts. An `ecko.json` `environment` block only fills in what the shell has not
set.

## CLI

Ecko's own flags go **before** the file; everything after it is the program's
(`os.args()`). `ecko --provider ollama --model llama3.2 app.ecko --port 8080`.
There is no `--key` flag: set `ECKO_AI_API_KEY`.

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
ecko profile file.ecko      run and report where the time went
ecko fix --migrate <path>   rewrite deprecated forms (--list; --only=ms, --only=mut)
```

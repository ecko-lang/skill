# Ecko gotchas

Every trap below is real, with the exact message it produces. Ordered by how
often an LLM hits it.

## 1. A hole may contain a string (since 0.22.0)

```ecko
print("hi {upper("bob")}")     # hi BOB
print("brace {"}"} inside")    # brace } inside
```

This used to fail with `Unclosed interpolation brace in string`, and the advice
was to bind the value first. **That workaround is no longer needed** - if you
learned it, unlearn it. A `{` opens a hole only when it actually balances, and
the hole's own quotes and braces belong to it.

Escaping still works and raw strings still opt out entirely, both below.

## 2. A literal `{` in a string starts interpolation

```
print("a{b")                       # Unclosed interpolation brace in string
print("css: body { color: red }")  # Parse error: Unexpected token: ':'
```

The rule is **balance**. A `{` with no matching `}` is an unterminated hole. A
`{...}` that *does* balance is read as a hole and parsed as Ecko - which is why
CSS fails with a parse error rather than an unclosed one.

Escape it, or go raw:

```ecko
print("a\{b")          # a{b
print(r"a{b")          # a{b
print(r"""{"a": 1}""")  # the JSON idiom - r"..." ends at the first quote
```

`fmt.format` templates must be raw strings for the same reason:
`fmt.format(r"{} of {}", a, b)`.

This is the trap that catches people writing CSS or HTML in a string. When it
happens in a file you `import`, `ecko check` names it for what it is:

```
unparsable-import: import './style.ecko' resolves but does not parse:
  In string interpolation: Parse error: Unexpected token: ':'
```

so a `does not resolve`-looking message is about a genuinely missing file, not
a brace.

## 3. `|x| ...` lambdas are deprecated

They still parse, but `ecko check` warns:

> ``deprecated-syntax: the `|params| body` lambda form is deprecated - write it as `fn(params) body` (run `ecko fmt` to migrate)``

Write `fn(x) x * 2`. `ecko fmt` rewrites it for you. Same story for `const`,
which is an alias for `let`:

> ``deprecated-syntax: `const` is deprecated - it is identical to `let` (both are immutable); use `let` (run `ecko fmt` to migrate)``

Since 0.64 the same goes for `Option<T>`, which is now written `T?`, and for
a vote count before the prompt, `ai[T] 5 "..."`, which is now
`ai[T] "..." votes 5`. `ecko fmt` and `ecko fix --migrate` rewrite both.

## 4. Access is strict; `get` is the nullable one

```
xs = [1, 2, 3]
xs[99]        # error: index 99 is out of bounds (len 3)
m = { a: 1 }
m.missing     # error: map has no key 'missing'
```

```ecko
xs = [1, 2, 3]
m = { a: 1 }
print(string(get(xs, 99)))      # null
print(string(get(m, "missing")))  # null
```

Slices are the exception: they clamp rather than raise. `"hello"[2..99]` is
`"llo"`.

## 5. Caught errors: use `get(e, "kind")`, never `e.kind`

Every error the runtime throws is a `{ kind, message }` map; a programmer
mistake is `kind: "bug"`. But `error(v)` throws `v` exactly as given, so a caught
value can still be a plain string, and `e.kind` raises on that. `get` is total
and returns `null`, so one `match` handles both:

```ecko
try { error("a thrown string") } catch (e) {
    print(match get(e, "kind") {
        "parse" => "a parse failure"
        _       => "something else"
    })
}
```

## 6. `decimal` and `float` never mix

```
1.5m + 0.5
```
→ `error: Can't add decimal and float - try converting one with int(), float(), string(), or decimal().`

Both conversions that lose precision are refused outright:

```
decimal(0.1)  # error: decimal(float) is lossy; pass a string, e.g. decimal("0.1"), to keep the exact value
float(1.5m)   # error: Can't convert decimal to float
```

This is deliberate. Use `decimal` for money end to end. `decimal` mixes freely
with `int`, because `int` is exact.

## 7. Secrets do not concatenate

```
secret("x") + "y"
```
→ `error: Can't add string and secret - use reveal(s) to use the value deliberately`

Interpolation is allowed and redacts: `"key={s}"` gives `key=[secret]`. Only
`reveal(s)` produces the real value, which makes `grep reveal` a complete audit.

## 8. Empty-collection behaviour follows the kind of operation

```ecko
print(string(first([])))     # null   - retrieval yields null
print(sum([]))               # 0      - identity value
print(len(filter([], fn(x) true)))  # 0
```

But reductions with no identity raise:

```
min([])   # error: min of an empty list
```

`index_of([], x)` returns `-1`, its documented not-found sentinel.

## 9. `sort` refuses incomparable elements

```
sort([1, "a"])
```
→ `error: sort: can't compare string and int`

Deterministic output is the point. Use `sort_by(xs, key)` or
`sort_with(xs, fn(a, b) ...)` when order needs a rule.

## 10. Ranges are lazy; materialising one is capped

```
list(0..30000000)
```
→ `error: range 0..30000000 is too large to turn into a list (30000000 elements, max 10000000) - iterate it instead: a `for` loop or a range-aware builtin like `sum` or `count` streams it without building the list`

`for i in 0..30000000` is free. Only building a real list allocates.

## 11. `set` replaces, `insert` splices

`set(list, i, v)` replaces position `i` and refuses an index past the end.
`insert(list, i, v)` grows the list. Reaching for `insert` when you meant `set`
silently lengthens your data.

Building a map with `m = set(m, k, v)` in a loop is linear since 0.66: `set`,
`pop`, `take`, `drop` and `remove` update in place when nothing else holds the
collection, as `push` always did. Before 0.66 each call copied, so 100,000 keys
took minutes; you no longer need `group_by` or a cursor to avoid that.

## 12. `cell_set` on a counter races

```ecko
c = cell(0)
cell_update(c, fn(v) v + 1)     # correct: atomic read-modify-write
print(cell_get(c))
```

`cell_set(c, cell_get(c) + 1)` is a read and a write with a gap between them.
Also: never touch the same cell inside its own `cell_update` - the lock is not
reentrant and deadlocks.

## 13. A `fn(x) { ... }` body is a block, except when it is a map

```ecko
f = fn(c) { value: c }        # returns a map - no statement starts with `name :`
g = fn(x) { x * 2 }           # a block whose value is x * 2
print(f(1))
print(g(5))
```

When ambiguous, `fn(x) ({ ... })` is always a map.

## 14. Arity and argument names are checked at the call site, by `ecko check`

```
fn f(a, b) = a
f(1)
```
→ `arity-mismatch: 'f' needs at least 2 argument(s), got 1` - before the program runs.

A named argument the function does not declare is caught the same way, with a
suggestion:

```
fn serve(a, b, host) = a
serve(1, 2, hots: "x")
```
→ `unknown-named-argument: 'serve' has no parameter 'hots' - did you mean 'host'?`

## 15. Async callbacks are rejected where a result is needed immediately

`map(items, async fn(x) ...)` is fine and returns tasks. Predicates, key
functions, folds, `retry` and `cell_update` reject async callbacks - map to
tasks and `await` them explicitly.

## 16. Put tests in `tests/`, not the package root

`ecko test` discovers both `tests/*.ecko` and `*_test.ecko`. But `ecko pack`
archives `*.ecko` non-recursively, so a root-level `foo_test.ecko` **ships to
users** while `tests/foo_test.ecko` does not.

## 17. Parallel workers see a snapshot

`pmap`, `async` tasks and `http.serve` handlers each snapshot captured
variables. Mutating an ordinary outer `mut` changes only that call's copy and
is silently lost. Share through `cell`, deliberately.

```ecko
fn tally() {
    mut count = 0
    pmap(range(0, 100), fn(i) { count = count + 1 })
    count
}
print(tally())                       # 0 - every call had its own copy

hits = cell(0)
pmap(range(0, 100), fn(i) cell_update(hits, fn(n) n + 1))
print(cell_get(hits))                # 100
```

Before 0.65 `pmap` callbacks and `http.serve` handlers wrote the caller's
variable from every worker at once, so code that counted that way got a
different wrong number each run. If older code relied on it, move it to a
`cell`, or collect what `pmap` returns.

---

# Found while building a real app

The traps above are the ones a model hits in the first ten minutes. These came
out of someone actually shipping something, and several are worse because they
fail quietly.

## 18. The string module is `std.str`, not `std.string`

```ecko
import std.str
print(string(42))              # 42     - the converter
print(str.title("a b c"))      # A B C  - the module
```

Writing `import std.string` is an error, and the program does not start
(`unresolved-import: import 'std.string' does not resolve`).
It is `str` for a reason worth knowing, because it explains a rule: **a module
binds the last segment of its path**, so a module called `string` would bind
`string` and displace the `string()` converter for the whole file. It used to,
and every conversion in an importing file failed with `Can't call module`.

The same rule means no other std module can shadow a builtin either - that is
now enforced by a test in the compiler, so this is the only one that ever bit.

## 19. Regex quantifiers need raw strings

`{3}` is an interpolation hole in a normal string, so `"^[A-Z]{3}$"` is the
string `^[A-Z]3$` - a pattern that never matches a currency code. Before 0.57
that ran and silently returned `false`. Now a hole holding only a number is an
error, and the program does not start:

```
print(re.test("^[A-Z]{3}$", "ABC"))
```
→ ``error[literal-interpolation]: `{3}` in an ordinary string is an interpolation hole, so the string holds `3` rather than `{3}` - for a regex quantifier or a literal brace use a raw string r"..." or escape it as `\{3}` ``

```ecko
import std.re
print(re.test(r"^[A-Z]{3}$", "ABC"))  # true - raw string, pattern intact
```

**Write every regex as a raw string**, whether or not it currently contains
braces. The check catches a number in a hole, not every brace a pattern might
grow later, and `"^{prefix}$"` is still a legitimate dynamic pattern.

## 20. Every duration is milliseconds (since 0.58)

`sleep(1000)` sleeps one second. `sleep`, `time.monotonic()`, an HTTP client's
`timeout:`, `with_timeout`, `io.timeout`, the `std.bg` schedulers and every
`ECKO_*_MS` variable all count whole milliseconds, as an Int:

```ecko
import std.time
before = time.monotonic()
sleep(250)
print(time.monotonic() - before >= 250)   # true - both sides are ms
print(time.now() > 1000000000000)         # true - ms since the epoch
```

**Code written for seconds still runs, a thousand times too fast.** Before 0.58
`sleep`, `monotonic` and `timeout:` used seconds, so `sleep(2)` from an older
program or a model's memory now waits two milliseconds, without an error. A
Float is refused, which catches the fractional cases:

```
sleep(0.25)
# error: sleep takes whole milliseconds (an Int) - it took seconds before 0.58,
#        so sleep(0.25) is probably sleep(250) now
```

`ecko fix --migrate --only=ms src/` converts a codebase written for seconds.
For finer timing, `time.monotonic_ns()` reads the same clock in nanoseconds.

## 21. A `Decimal` field refuses a float literal

`Decimal` fields are enforced now. The surprise is which values pass: an `Int`
widens, a `String` is refused, and so is a **float literal**, which is exactly
what a price looks like when you type it.

```ecko
type Offer { price: Decimal }
print(Offer(19).price)                   # 19 - an Int widens
print(Offer(decimal("19.99")).price)     # 19.99 - the way to write a price
```

`Offer(19.99)` is ``field `price` of `Offer` expects Decimal, got float``, and
`Offer("19.99")` is the same with `string`. Admitting binary floating point
through a declared `Decimal` would defeat the point of the type, so build the
value with `decimal(...)` from a string.

## 22. `json.encode` adds `__type__` to records

```ecko
import std.json
type U { a: Int }
print(json.encode(U(1)))        # {"__type__":"U","a":1}
```

Fine for round-tripping inside Ecko, wrong for an API payload. Build a plain map
when the JSON crosses a boundary.

## 23. A positional pattern needs a type it can see

A type from another module matches positionally or by field name, qualified or
not, all four spellings alike:

```
import "./deals.ecko"
o = deals.Offer(1, 2)
match o {
    deals.Offer(a, b) => a + b      # 3 - also Offer(a, b), deals.Offer { a, b }
    _ => 0
}
```

A positional pattern binds by the field order the module declared, so it needs
a type it can see. Two cases fail, with the same error:

```
match lib.ghost() { Ghost(x) => x  _ => "none" }
# error: Pattern Ghost(..) binds 1 field(s) by position, but no type this file
#        can see declares `Ghost`'s fields - if a module declares it, export the
#        type and qualify the pattern with the module (`mod.Ghost(..)`), or match
#        by field name with `Ghost { .. }`
```

- **The module builds the value but does not export its type.** Export it, or
  match by field name: `Ghost { name }` needs no field order.
- **Two imports export an `Offer` with different fields.** A bare `Offer(a, b)`
  is refused rather than guessed. Qualify it as `deals.Offer(a, b)`.

Before 0.59.2 a qualified positional pattern parsed and never matched, silently
falling through to `_`, so older code may use the brace form for this reason
alone.

## 24. The credential lint flags reading a credential, not checking for one

```ecko
import std.os
if os.env("MY_API_KEY") != null { print("configured") }   # fine - a presence check
```

Comparing against `null` or `""` never touches the value, so it is not flagged.
Anything that reads it is:

```
key = os.env("MY_API_KEY")
# unwrapped-credential: os.env("MY_API_KEY") reads a credential but is not
#   wrapped - use secret(os.env("MY_API_KEY")) so it can't leak into logs,
#   prompts, or output
```

Any env name containing `KEY` or `TOKEN` counts. Wrap the read in `secret(...)`
and `reveal()` it only at the call that needs the real value.

## 25. `std.*` functions reject extra arguments

Passing a module function more arguments than it takes is an error, the same as
for a builtin or one of your own functions. It used to be ignored silently.

```
math.gcd(12, 18, "nonsense")   # math.gcd takes at most 2 arguments, got 3
str.upper("ab", "junk")        # str.upper takes at most 1 argument, got 2
```

Functions with genuinely optional trailing arguments still take them -
`str.trim(s, chars)`, `sql.query(db, sql, params)`, `zlib.gzip(data, level)` -
and `fs.join`, `fmt.format` and `bg.spawn` are variadic.

## 26. `re.captures` returns `null` on a miss, `captures_all` returns `[]`

Singular answers "no match" with `null`; plural answers it with an empty list.

```ecko
import std.re
print(re.captures(r"(\d+)", "none here") == null)     # true
print(len(re.captures_all(r"(\d+)", "none here")))    # 0
```

So guard a singular result with `== null`, and a plural one with `len(...) == 0`.
`re.find` and `find_all` split the same way.

## 27. An untyped `ai ... using [tools]` returns the tool's value

Not the model's prose. This is the same offline and against a real provider.

```ecko
@tool("look it up")
fn lookup(q) = { answer: "42", sources: ["a"] }

r = ai "lookup the answer" using [lookup]
print(get(r, "answer"))          # 42 - the tool's return value
```

When you want the model's own answer with tools available, **type the call**:
`ai[Summary] "..." using [lookup]` coerces the final answer instead.

## 28. `http.serve` binds every interface

The default host is `0.0.0.0`, so a dev server is reachable from the network you
are on. Pass `host:` for loopback only:

```ecko-check
import std.http
http.serve(8080, fn(req) http.text("hi"), host: "127.0.0.1")
```

## 29. A WebSocket upgrade must be same-origin

An upgrade whose `Origin` header does not match the request's `Host` is refused
with 403, which stops another site opening your socket with a visitor's cookies.
Name a legitimate cross-origin caller:

```ecko-check
import std.http
import std.ws
http.serve(8080, fn(req) http.text("hi"),
    on_ws: fn(c) ws.recv(c),
    origins: ["https://app.example"])
```

Clients that send no `Origin` at all - everything that is not a browser - are
unaffected.

## 30. A spawned process dies with your program (since 0.22.0)

`proc.spawn` children are signalled when the program ends - including when it is
stopped with Ctrl-C or `SIGTERM` rather than returning normally. A script cannot
leave strays behind by forgetting to `kill`.

```ecko-check
import std.proc
p = proc.spawn("some-server", [])           # dies with the program
q = proc.spawn("daemon", [], detach: true)  # deliberately survives it
```

If you actually want a survivor, say `detach: true` - then it is yours to
manage. This changed in 0.22.0; before it, every spawned child outlived the
program by default.

## 31. A condition should be a Bool (since 0.64)

`if`, `while` and `unless` still test truthiness - `false`, `null`, `0`, `0.0`,
`0m`, `""`, `b""`, `[]`, `{}` and an empty range are false - but a condition
that is plainly an Int, String, List or Map does not say which test was meant,
so `ecko check` warns:

```
xs = [1]
if xs { print("some") }
# non-bool-condition: `xs` is a List, which is false only when it is empty -
#   write `len(xs) > 0` to say which you mean
```

Write the comparison: `if len(xs) > 0`, `if count != 0`, `if name != ""`.
`if x = 2` is a parse error that says to write `==`.

## 32. `fs.walk` stops at a directory it cannot read (since 0.66)

Before 0.66 an unreadable directory came back as an empty one, silently. Now
`fs.walk` throws `kind: "fs"` with the `path`, and the whole walk stops, so a
`chmod 000` directory deep in a tree means no listing at all:

```ecko
import std.fs
fs.mkdir("tree/ok")
fs.write("tree/ok/a.txt", "hi")
for e in fs.walk("tree") { print(e.kind + " " + e.path) }
```

When you want to report an unreadable directory and carry on (a backup, an
indexer), pass `on_error:` (unreleased, after 0.66). Each unreadable directory
goes to the function as the `{ kind: "fs", message, path }` the walk would have
thrown, its contents are left out, and the walk continues:

```ecko
import std.fs
fs.mkdir("tree2/ok")
mut skipped = []
entries = fs.walk("tree2", on_error: fn(e) { skipped = push(skipped, e.path) })
print([len(entries), skipped])   # [1, []]
```

On 0.66 itself, walk it yourself: `fs.list_dir` on each directory inside a
`try`, with a queue of directories still to visit. Each `walk` entry is
`{ path, is_dir, kind, size, mtime }`, `kind` one of `"file"`, `"dir"`,
`"symlink"`, `"other"`, and symlinks are not followed.

## 33. `fs.match` is `(path, pattern)`

```ecko
import std.fs
print(fs.match("notes.txt", "*.txt"))   # true
```

`fs.match("*.txt", "notes.txt")` used to answer `false` for everything. Since
0.66 it throws, saying the arguments look swapped.

## 34. `io.read(s, n)` can return fewer than `n` bytes

`io.read` is one read. It returns at most `n` bytes and may return fewer before
the end - on a socket or a pipe, whatever has arrived; on a file, at most 1 MiB
per read. So `io.read(s, 16 * 1024 * 1024)` on a large file returns 1 MiB, and
code that cuts a file into fixed-size parts must not assume each read fills:

```ecko
import std.fs
import std.io

fn read_up_to(s, n) {
    mut buf = bytes("")
    while len(buf) < n {
        piece = io.read(s, n - len(buf))
        if piece == null { break }
        buf = buf + piece
    }
    if len(buf) == 0 { null } else { buf }
}

fs.write("ten.txt", "abcdefghij")
s = fs.open("ten.txt")
print(len(read_up_to(s, 4)))   # 4
```

`io.read_exact(s, n)` gives exactly `n` or raises when the stream ends first.
To send or hash a part without holding it at all, use `io.limit(s, n)`
(unreleased, after 0.66), a stream of just those bytes.

## 35. Assigning to an imported name hides the module

```ecko
import std.json

fn build() {
    json = "text"  # a new binding: `json` is a string for the rest of build()
    json
}
print(build())  # text
print(json.encode([1]))  # [1] - outside build() the module is untouched
```

The trap is the next line inside `build()`: `json.encode(...)` there fails with
`Can't access field 'encode' of string`. Use another name for the local.

**Version matters for imported files.** On 0.66, the same function in a file
you `import` did not make a local: it replaced that file's `json` for the whole
program, so one call broke `json.encode` in every later call into the module,
far from the cause, and `ecko check` said nothing. After 0.66 (unreleased) both
cases make a local, and `ecko check` warns with `shadows-import` (`let json =
...` silences it when the shadow is deliberate). Until then, never reuse an
import's name for a local in a module.

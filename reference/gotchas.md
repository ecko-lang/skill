# Ecko gotchas

Every trap below is real, with the exact message it produces. Ordered by how
often an LLM hits it.

## 1. Nested double quotes inside interpolation

```
print("hi {upper("bob")}")
```
→ `error: Unclosed interpolation brace in string`

The interpolation is scanned before the expression is parsed, so the inner `"`
closes the string. **Bind the value first:**

```ecko
u = upper("bob")
print("hi {u}")
```

Single-argument calls on a name are fine - `"hi {upper(name)}"` works. It is
only a nested *string literal* that breaks.

## 2. A literal `{` in a string starts interpolation

```
print("a{b")
```
→ `error: Unclosed interpolation brace in string`

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

> `deprecated-syntax: the |params| body lambda form is deprecated - write it as fn(params) body`

Write `fn(x) x * 2`. `ecko fmt` rewrites it for you. Same story for `const`,
which is an alias for `let`:

> `deprecated-syntax: const is deprecated - it is identical to let`

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

A caught error may be a `{ kind, message }` map **or** a plain string (a
panic). `e.kind` raises on the string case. `get` is total and returns `null`,
so one `match` handles both:

```ecko
try { error("plain string panic") } catch (e) {
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
decimal(0.1)  # error: decimal(float) is lossy; pass a string, e.g. decimal("0.1")
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
→ `error: range 0..30000000 is too large to turn into a list (30000000 elements, max 10000000) - iterate it instead`

`for i in 0..30000000` is free. Only building a real list allocates.

## 11. `set` replaces, `insert` splices

`set(list, i, v)` replaces position `i` and refuses an index past the end.
`insert(list, i, v)` grows the list. Reaching for `insert` when you meant `set`
silently lengthens your data.

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
variables. Mutating an ordinary outer `mut` changes only that worker's copy and
is silently lost. Share through `cell`, deliberately.

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

Writing `import std.string` is an error that names the fix
(`No module called 'std.string' - check the name`).
It is `str` for a reason worth knowing, because it explains a rule: **a module
binds the last segment of its path**, so a module called `string` would bind
`string` and displace the `string()` converter for the whole file. It used to,
and every conversion in an importing file failed with `Can't call module`.

The same rule means no other std module can shadow a builtin either - that is
now enforced by a test in the compiler, so this is the only one that ever bit.

## 19. Regex quantifiers need raw strings

This is the worst one on the page, because nothing errors:

```ecko
import std.re
print(re.test("^[A-Z]{3}$", "ABC"))   # false  - the {3} was interpolated away
print(re.test(r"^[A-Z]{3}$", "ABC"))  # true   - raw string, pattern intact
```

`{3}` is an interpolation hole in a normal string, so the pattern that reaches
the regex engine is not the one you wrote. You get a silently wrong answer, not
a parse error. **Write every regex as a raw string**, whether or not it
currently contains braces.

`ecko check` catches this (`regex-interpolation`) and names the fix. It flags
only an integer hole, since `"^{prefix}$"` is a legitimate dynamic pattern.

## 20. Units are seconds

`sleep(1)` sleeps one second. HTTP timeouts are seconds too. Neither is
documented, and milliseconds is the more common convention elsewhere, so this is
worth pinning:

```ecko
import std.time
before = time.monotonic()
sleep(1)
print(time.monotonic() - before > 0.9)   # true
```

The exceptions are the `std.bg` schedulers, which take milliseconds
(`bg.after(1000, ...)`), and the `ECKO_*_MS` environment variables.

**`time.now()` is the other exception, and it is the one that bites.** It
returns milliseconds since the epoch, while `time.monotonic()` returns seconds.
Two clocks in one module, two units:

```ecko
import std.time
print(time.now() > 1000000000000)        # true - milliseconds
before = time.monotonic()
sleep(0.25)
print(time.monotonic() - before < 1)     # true - seconds
```

Timing a request with `monotonic` and labelling the result `ms` is wrong by a
factor of a thousand, and it looks perfectly plausible in a log. Multiply by
1000 before you call it milliseconds.

## 21. A `Decimal` field refuses a float literal

`Decimal` fields are enforced now. The surprise is which values pass: an `Int`
widens, a `String` is refused, and so is a **float literal**, which is exactly
what a price looks like when you type it.

```ecko
type Offer = Offer { price: Decimal }
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
type U = U { a: Int }
print(json.encode(U(1)))        # {"__type__":"U","a":1}
```

Fine for round-tripping inside Ecko, wrong for an API payload. Build a plain map
when the JSON crosses a boundary.

## 23. Qualified constructors do not work in patterns

`mod.Offer(1, 2)` constructs. The same name in a pattern does not:

```
match o { mod.Offer(a, b) => a + b }
```
→ `error: Expected '=>' here, but found '.'`

Match on the shape instead, or import the type unqualified.

## 24. The credential lint fires on an existence check

```
import std.os
if os.env("MY_API_KEY") != null { print("configured") }
```
→ `unwrapped-credential: os.env("MY_API_KEY") reads a credential but is not wrapped`

Any env name containing `KEY` or `TOKEN` trips it, even when you are only asking
whether it is set. `os.env_or(name, "")` avoids the warning and reads better
than wrapping a presence check in `reveal(secret(...))`.

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

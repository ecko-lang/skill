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

## 14. Arity is checked at the call site, by `ecko check`

```
fn f(a, b) = a
f(1)
```
→ `arity-mismatch: 'f' needs at least 2 argument(s), got 1` - before the program runs.

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

## 21. `Decimal` record fields are not enforced

`Int` fields are checked. `Decimal` fields are not:

```ecko
type Offer = Offer { price: Decimal }
loose = get({ v: "notanumber" }, "v")
print(Offer(loose).price)      # notanumber - straight through
```

An `Int` field in the same position throws
``field `n` of `U` expects Int, got string``. Until that gap closes, coerce in a
constructor function rather than trusting the annotation:

```ecko
type Offer = Offer { price: Decimal }
fn offer(price_text) = Offer(decimal(price_text))
print(offer("19.99").price)
```

## 22. `json.encode` adds `__type__` to records

```ecko
import std.json
type U = U { a: Int }
print(json.encode(U(1)))        # {"__type__":"U","a":1}
```

Fine for round-tripping inside Ecko, wrong for an API payload. Build a plain map
when the JSON crosses a boundary.

## 23. `sum` rejects decimals

```
sum([1.5m, 2.5m])
```
→ `error: sum needs numbers, got decimal`

Even though `1.5m + 2.5m` is fine. Fold instead:

```ecko
print(reduce([1.5m, 2.5m], fn(a, b) a + b, 0m))
```

## 24. There are two padding functions and only one takes a fill character

```ecko
import std.fmt
import std.str
print(fmt.pad_left("7", 3, "0"))    # "  7"  - the fill argument is ignored
print(str.pad_start("7", 3, "0"))   # "007"  - this is the one that works
```

Worse, `fmt.pad_left` accepts **any** number of extra arguments and silently
drops them: two, three and four arguments all return `"  7"`, with no arity
error. Every other function in the language raises on a bad arity, so this is
the one place a wrong call is invisible.

Use `std.str`'s `pad_start` / `pad_end` when the fill matters. Note the
different naming: `std.fmt` says left/right, `std.str` says start/end.

## 25. Qualified constructors do not work in patterns

`mod.Offer(1, 2)` constructs. The same name in a pattern does not:

```
match o { mod.Offer(a, b) => a + b }
```
→ `error: Expected '=>' here, but found '.'`

Match on the shape instead, or import the type unqualified.

## 26. `cli.help(spec, "subcommand")` ignores the second argument

It prints the top-level help every time, so a subcommand's own options never
appear. Build a spec map for the subcommand and pass that to `cli.help` on its
own.

Related: global options must come **before** the subcommand on the command line,
or they are rejected as unknown.

## 27. The credential lint fires on an existence check

```
import std.os
if os.env("MY_API_KEY") != null { print("configured") }
```
→ `unwrapped-credential: os.env("MY_API_KEY") reads a credential but is not wrapped`

Any env name containing `KEY` or `TOKEN` trips it, even when you are only asking
whether it is set. `os.env_or(name, "")` avoids the warning and reads better
than wrapping a presence check in `reveal(secret(...))`.

## 28. Piping output into `head` exits 101

`ecko prog.ecko | head -1` exits 101 with a broken-pipe panic from the runtime,
even though the output is correct. It affects any truncated pipe, not just
`head`. Nothing is wrong with your program. Redirect to a file if an exit code
matters, until the runtime handles EPIPE.

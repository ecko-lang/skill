# Builtins

Global functions. No import needed. **This list was produced by probing each
name against the runtime**, not by reading the reference, so it is what exists.

102 builtins, plus two special forms.

**Collections** (43) - `all`, `any`, `chunk`, `contains`, `count`, `drop`, `empty_map`, `enumerate`, `filter`, `find`, `first`, `flatten`, `frequencies`, `get`, `group_by`, `has`, `index_of`, `insert`, `keys`, `last`, `len`, `map`, `max`, `min`, `partition`, `pmap`, `pop`, `push`, `range`, `reduce`, `remove`, `reverse`, `set`, `slice`, `sort`, `sort_by`, `sort_with`, `sum`, `take`, `unique`, `values`, `window`, `zip`

**Strings** (11) - `chars`, `ends_with`, `escape_html`, `join`, `lines`, `lower`, `replace`, `split`, `starts_with`, `trim`, `upper`

**Numbers and math** (7) - `abs`, `approx`, `ceil`, `floor`, `pow`, `round`, `sqrt`

**Types and conversion** (11) - `bool`, `decimal`, `float`, `int`, `is_list`, `is_map`, `is_null`, `is_number`, `is_string`, `string`, `type_of`

**JSON** (2) - `json_decode`, `json_encode`

**AI** (7) - `cosine`, `cost`, `embed`, `embed_all`, `retry`, `session`, `tokens`

**Secrets** (3) - `is_secret`, `reveal`, `secret`

**Errors** (2) - `assert`, `error`

**Shared state** (4) - `cell`, `cell_get`, `cell_set`, `cell_update`

**Async and channels** (7) - `cancel`, `channel`, `close`, `recv`, `select`, `send`, `try_recv`

**I/O and timing** (5) - `print`, `print_no_newline`, `read_file`, `sleep`, `write_file`

## Two special forms

`await expr` and `py("module.func", args...)` are keywords, not values. You can
call them but not pass them around: `type_of(py)` is a parse error, while
`py("math.sqrt", 16)` returns `4` and `await 7` returns `7`.

`null` is a literal, not a function.

## Things that are not builtins

These are the names a model reaches for first. None of them exist. `ecko check`
catches every one before the program runs, but knowing the replacement saves the
round trip.

| you wanted | it does not exist | use instead |
|---|---|---|
| `min_by(xs, key)` | | `first(sort_by(xs, key))` |
| `fold(xs, f, init)` | | `reduce(xs, f, init)` |
| `append(xs, v)` | | `push(xs, v)` |
| `merge(a, b)` | | `for (k, v) in b { m = insert(m, k, v) }` |
| `hash(s)` | | `import std.hash`, then `hash.sha256(s)` |
| `eprint(s)` | | `import std.log`, then `log.error(s)` - that writes to stderr |
| `map_get` / `dict` / `list_append` | | `get`, `{}` literals, `push` |

The pattern behind the misses: Ecko keeps one name per job. There is no `_by`
family, no `fold`/`reduce` pair, no separate map and list vocabulary. If a name
feels like a synonym for one already in the list above, it is not there.

## Where the rest lives

Anything not in this list is in a `std.*` module and needs an import. See
`reference/stdlib.md` for all 40 of them. The split is roughly: if it works on
plain data you already have, it is a builtin; if it touches the outside world
(files, network, time, randomness, crypto, terminals) it is a module.
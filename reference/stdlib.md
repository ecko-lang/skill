# Standard library index

40 modules with fixed exports, 410 functions, plus `std.defaults` (below).
Six modules and the string-building half of `std.term` are **deprecated since
0.59** and go in the next breaking release; each is marked with its
replacement. `ecko check` warns at every use (`deprecated-module`,
`deprecated-member`).
`import std.x` binds `x`.

Everything here is in the single binary - there is nothing to install, and no
package manager step to reach any of it. `ecko doc <file>` generates the same
kind of reference for your own code from its `##` comments.

## `std.defaults` - the 41st module

It has no fixed exports because its members come from the `ecko.json` sitting
next to the file being run, which is loaded automatically before the program
starts:

```json
{ "app": "billing", "api_url": "https://api.example.com",
  "environment": { "ECKO_AI_PROVIDER": "ollama" } }
```

```
import std.defaults
defaults.app        # "billing"
defaults[name]      # same lookup for a key decided at runtime
```

The optional `environment` object fills in process environment variables the
shell has **not** already set (since 0.58 the shell wins); every other
top-level key becomes a member, keeping its JSON type.

| module | what it is | exports |
|---|---|---|
| `std.archive` | tar/zip create, extract, list | 6 |
| `std.bg` | fire-and-forget background tasks with lifecycle | 7 |
| `std.cli` | *deprecated* - use the `cli` package | 2 |
| `std.config` | load config from file with env overlay | 1 |
| `std.csv` | CSV parse/stringify, streaming read/write | 5 |
| `std.db` | *deprecated* - an index is `embed` + `cosine` (see `ai.md`) | 7 |
| `std.debug` | *deprecated* - `type_of`, `time.monotonic()`, `fmt.inspect` | 4 |
| `std.dns` | DNS lookups | 3 |
| `std.encoding` | base64, hex, url encoding | 8 |
| `std.fmt` | `format` templates, `fixed` decimals, `inspect` for any value | 7 |
| `std.fs` | filesystem: read, write, glob, walk, temp files | 29 |
| `std.hash` | sha1/sha256, HMAC, Argon2id passwords, constant-time compare | 9 |
| `std.http` | HTTP client (all verbs) + server (serve/stop) + responses | 13 |
| `std.humanize` | *deprecated* - use the `humanize` package | 5 |
| `std.image` | PNG/JPEG as values: load, resize, crop - feeds `ai ... on img` | 10 |
| `std.io` | streams: read_line, read_all, lines, tell/seek, print | 16 |
| `std.json` | encode/decode, read/write files | 4 |
| `std.llm` | low-level chat access under the `ai` keyword | 2 |
| `std.log` | levelled logging, sinks, rotation, JSON format | 8 |
| `std.math` | trig, log, statistics, constants | 41 |
| `std.net` | TCP/UDP sockets, TLS | 14 |
| `std.os` | env, args, exec, platform, cwd | 15 |
| `std.proc` | child processes with pipes | 8 |
| `std.rag` | *deprecated* - retrieval is `embed` + `cosine` (see `ai.md`) | 4 |
| `std.random` | seeded RNG, choice, shuffle, secure bytes | 7 |
| `std.re` | regex: test, find, captures, replace, split | 8 |
| `std.serial` | *deprecated* - no replacement in std | 6 |
| `std.signal` | OS signal handlers | 5 |
| `std.sql` | embedded SQLite with transactions (Postgres/MySQL are the `postgres`/`mysql` packages) | 9 |
| `std.str` | the full string surface | 52 |
| `std.term` | TTY state, size, raw mode, keys; the styling moved to the `tui` package | 50 |
| `std.test` | test cases and assertions for `ecko test` | 6 |
| `std.time` | clock (ms), format, parse, monotonic / monotonic_ns | 8 |
| `std.toml` | TOML parse/stringify | 4 |
| `std.uuid` | v4 (random) and v7 (time-ordered) ids | 2 |
| `std.watch` | filesystem change events | 4 |
| `std.web` | router: get/post/put/delete/static | 8 |
| `std.ws` | WebSocket client and server | 5 |
| `std.yaml` | YAML parse/stringify | 4 |
| `std.zlib` | gzip/deflate compress and decompress | 4 |

## Full export list

**`std.archive`** (6) - `tar_create`, `tar_extract`, `tar_list`, `zip_create`, `zip_extract`, `zip_list`

**`std.bg`** (7) - `after`, `cancel`, `every`, `join_all`, `result`, `spawn`, `status`

**`std.cli`** (2) - *deprecated since 0.59, use the `cli` package (same `parse`/`help`)* - `help`, `parse`

**`std.config`** (1) - `load`

**`std.csv`** (5) - `each`, `parse`, `read`, `stringify`, `write`

**`std.db`** (7) - *deprecated since 0.59, use nothing in std; `embed` + `cosine` (see `ai.md`)* - `add`, `clear`, `count`, `load`, `remove`, `save`, `search`

**`std.debug`** (4) - *deprecated since 0.59, use `type_of`, `time.monotonic()`, `fmt.inspect`* - `elapsed`, `inspect`, `timer`, `type`

**`std.dns`** (3) - `lookup`, `resolve`, `reverse`

**`std.encoding`** (8) - `base64_decode`, `base64_decode_text`, `base64_encode`, `hex_decode`, `hex_decode_text`, `hex_encode`, `url_decode`, `url_encode`

**`std.fmt`** (7) - `fixed`, `format`, `inspect`. *Deprecated since 0.59:* `pad_left`/`pad_right`/`repeat` → `str.pad_start`/`str.pad_end`/`str.repeat`, `truncate` → `s[..n]`

**`std.fs`** (29) - `append`, `basename`, `canonical`, `chmod`, `copy`, `dirname`, `exists`, `extension`, `glob`, `is_dir`, `is_file`, `is_symlink`, `join`, `list_dir`, `match`, `mkdir`, `mode`, `modified`, `open`, `read`, `read_bytes`, `remove`, `rename`, `size`, `symlink`, `temp_dir`, `temp_file`, `walk`, `write`

**`std.hash`** (9) - `constant_eq`, `hmac_sha256`, `hmac_sha256_bytes`, `password`, `sha1`, `sha1_bytes`, `sha256`, `sha256_bytes`, `verify`

**`std.http`** (13) - `delete`, `get`, `html`, `json`, `not_found`, `patch`, `port`, `post`, `put`, `response`, `serve`, `stop`, `text`

**`std.humanize`** (5) - *deprecated since 0.59, use the `humanize` package (same names)* - `duration`, `ordinal`, `plural`, `relative`, `size`

**`std.image`** (10) - `crop`, `decode`, `dimensions`, `encode`, `height`, `load`, `resize`, `save`, `width`. *Deprecated since 0.59:* `free` (a no-op - an image is a value)

**`std.io`** (16) - `close`, `lines`, `print`, `read`, `read_all`, `read_exact`, `read_line`, `read_text`, `read_until`, `seek`, `stderr`, `stdin`, `stdout`, `tell`, `timeout`, `write`

**`std.json`** (4) - `decode`, `encode`, `read`, `write`

**`std.llm`** (2) - `chat`, `is_mock`

**`std.log`** (8) - `configure`, `debug`, `error`, `info`, `reset`, `to_file`, `to_stderr`, `warn`

**`std.math`** (41) - `acos`, `acosh`, `asin`, `asinh`, `atan`, `atan2`, `atanh`, `cbrt`, `clamp`, `copysign`, `cos`, `cosh`, `degrees`, `e`, `exp`, `factorial`, `fmod`, `gcd`, `hypot`, `inf`, `isclose`, `isfinite`, `isinf`, `isnan`, `lcm`, `ln`, `log`, `log10`, `log2`, `nan`, `pi`, `pow`, `radians`, `sign`, `sin`, `sinh`, `sqrt`, `tan`, `tanh`, `tau`, `trunc`

**`std.net`** (14) - `accept`, `broadcast`, `connect`, `connect_tls`, `listen`, `lookup`, `port`, `recv_from`, `send_to`, `starttls`, `stop`, `timeout`, `udp_bind`, `udp_close`

**`std.os`** (15) - `arch`, `args`, `cpu_count`, `cwd`, `env`, `env_or`, `exec`, `exit`, `family`, `hostname`, `pid`, `platform`, `script`, `set_env`, `unset_env`

**`std.proc`** (8) - `kill`, `pid`, `run`, `spawn`, `stderr`, `stdin`, `stdout`, `wait`

**`std.rag`** (4) - *deprecated since 0.59, use nothing in std; `embed` + `cosine` (see `ai.md`)* - `answer`, `chunk`, `index`, `retrieve`

**`std.random`** (7) - `bytes`, `choice`, `float`, `int`, `seed`, `shuffle`, `token`

**`std.re`** (8) - `captures`, `captures_all`, `find`, `find_all`, `replace`, `replace_first`, `split`, `test`

**`std.serial`** (6) - *deprecated since 0.59, use nothing in std* - `drain`, `dtr`, `flush`, `open`, `ports`, `rts`

**`std.signal`** (5) - `close`, `names`, `next`, `on`, `raise`

**`std.sql`** (9) - `begin`, `close`, `commit`, `exec`, `open`, `query`, `query_one`, `rollback`, `transaction`

**`std.str`** (52) - `capitalize`, `category`, `center`, `char_at`, `chars`, `chr`, `contains`, `count`, `ends_with`, `eq_ignore_case`, `from`, `from_utf8`, `from_utf8_lossy`, `index_of`, `is_alnum`, `is_alpha`, `is_ascii`, `is_blank`, `is_digit`, `is_empty`, `is_lower`, `is_space`, `is_upper`, `join`, `last_index_of`, `len`, `lines`, `lower`, `normalize`, `ord`, `pad_end`, `pad_start`, `partition`, `repeat`, `replace`, `replace_first`, `reverse`, `rpartition`, `rsplit`, `split`, `split_whitespace`, `starts_with`, `substring`, `swapcase`, `title`, `trim`, `trim_end`, `trim_prefix`, `trim_start`, `trim_suffix`, `upper`, `zfill`

**`std.term`** (50) - `color_enabled`, `is_tty`, `poll`, `raw_mode`, `read_key`, `size`. *Deprecated since 0.59, the same names in the `tui` package:* `alt_screen`, `black`, `blink`, `blue`, `bold`, `bright_black`, `bright_blue`, `bright_cyan`, `bright_green`, `bright_magenta`, `bright_red`, `bright_white`, `bright_yellow`, `clear`, `clear_down`, `clear_line`, `color`, `cyan`, `dim`, `down`, `goto`, `gray`, `green`, `grey`, `hide_cursor`, `italic`, `left`, `link`, `magenta`, `red`, `restore_cursor`, `reverse`, `rgb`, `right`, `save_cursor`, `show_cursor`, `strikethrough`, `strip`, `style`, `underline`, `up`, `white`, `width`, `yellow`

**`std.test`** (6) - `case`, `eq`, `err`, `fail`, `group`, `ok`

**`std.time`** (8) - `format`, `format_local`, `monotonic`, `monotonic_ns`, `now`, `now_iso`, `parse`, `parse_format`

**`std.toml`** (4) - `parse`, `read`, `stringify`, `write`

**`std.uuid`** (2) - `v4`, `v7`

**`std.watch`** (4) - `close`, `kinds`, `next`, `open`

**`std.web`** (8) - `delete`, `get`, `head`, `patch`, `post`, `put`, `router`, `static`

**`std.ws`** (5) - `close`, `connect`, `recv`, `request`, `send`

**`std.yaml`** (4) - `parse`, `read`, `stringify`, `write`

**`std.zlib`** (4) - `deflate`, `gunzip`, `gzip`, `inflate`

## Behaviour worth knowing

The export list above is complete; these are the places where the shape of a
result surprises people.

```ecko
import std.json
import std.csv
import std.fs
import std.io

print(json.decode(r"""{"fee": 0.30}""", decimal: true).fee)   # 0.30

fs.write("rows.csv", "id,qty\n1,5\n2\n3,7\n")
res = csv.each("rows.csv", fn(row) row.qty, on_error: fn(e) e.line)
print([res.rows, res.errors])                  # [2, 1]

fs.write("log.txt", "a\nbb\nccc\n")
s = fs.open("log.txt")
first = io.read_line(s)
mark = io.tell(s)                              # 2 - just past "a\n"
io.seek(s, mark)
print(io.read_line(s))                         # bb
```

- **`std.re`** - `find` and `captures` answer a miss with `null`; `find_all` and
  `captures_all` answer it with an empty list. Guard the singular with
  `== null`.
- **Options are named arguments** (since 0.58): `json.decode(s, decimal:
  true)`, `proc.run(cmd, args, timeout_ms: 5000)`, `http.get(url, timeout:
  2000)`. A map in their place is refused (`positional-options`), as is an
  option the function does not have. Maps that are data - `http.response`
  headers, log fields - stay maps.
- **`std.time`** - `now()` is milliseconds since the epoch and `monotonic()` is
  milliseconds on a steady clock, both Int; `monotonic_ns()` is the steady
  clock in nanoseconds. Every duration in Ecko is milliseconds since 0.58.
- **`std.http`** - `serve` binds `0.0.0.0` unless you pass `host:`. `serve(0,
  handler)` asks the operating system for a free port, and `http.port()` reads
  back which one it chose, from a handler or a task spawned before `serve`. A streaming
  response no longer occupies a handler slot, and is bounded separately by
  `max_streams:` / `ECKO_HTTP_MAX_STREAMS` (default 1024). Server limits are
  `http.serve` options - `workers:`, `max_body:`, `max_conns:`,
  `read_timeout_ms:`, `request_timeout_ms:`, `drain_ms:` - and the matching
  `ECKO_HTTP_*` variable overrides the option when set.
- **`std.net`** - client *and* server. `listen` answers a listener, and
  `accept` answers a connection stream, or `null` when nothing arrived before
  its deadline. A listener is not a stream: reading it yields connections, not
  bytes. `starttls` returns the upgraded stream (`c = net.starttls(c)`) and
  refuses an accepted connection, since the accepting side presents a
  certificate where `starttls` verifies one.
- **`std.ws`** - a server-side upgrade must be same-origin unless you list
  `origins:` on `http.serve`.
- **`std.sql`** - `exec`, `query` and `query_one` take an optional third
  argument of bind parameters. `transaction` rolls back if the function raises
  **and** if the commit itself fails, so a failed commit does not leave the
  connection inside the transaction.
- **`std.proc`** - a spawned child is signalled when your program ends, unless
  you pass `detach: true`. Nothing you spawn outlives you by accident.
- **`std.signal`** - closing the last subscription gives the signal back to the
  OS, so Ctrl-C works again afterwards. Delivery is asynchronous by a few
  milliseconds; `signal.next` waits, so you will not notice.
- **`std.term`** - colours and cursor moves (`term.bold`, `term.red`, ...) are
  deprecated: use the same names in the `tui` package (`ecko get
  github.com/ecko-lang/tui`), which honours `NO_COLOR`/`CLICOLOR_FORCE` via
  `term.color_enabled()`. `raw_mode(true)` is undone on exit, on error, **and** when a
  signal kills the program, so a TUI cannot strand your shell without echo.
- **`std.json`** - numbers that are not integers decode as floats unless you
  pass `decimal: true`, which reads each one as an exact decimal - what a
  money field needs. Encoding a value with no JSON form (a function, task,
  stream, range) throws `bug`; a record gains a `__type__` key, so build a
  plain map for an API payload.
- **`std.csv`** - `read` loads the whole file (at most 256 MiB). `each(path or
  stream, fn(row), on_error: fn(e) ...)` hands over one row map at a time with flat
  memory; a bad row goes to `on_error` as `{ kind: "parse", line, raw, message }`
  and the run carries on. It returns `{ rows, errors }`.
- **`std.io`** - `tell(s)` is the byte offset of the next byte you will read,
  not counting what was read ahead; `seek(s, offset)` moves there. Store the
  offset as a checkpoint to resume a large file. Only a file stream has a
  position.
- **`std.web`** - `web.static(dir)` needs the `fs:read` capability on `dir`,
  like reading the files yourself would.
- **Every module** rejects extra arguments now, so a stray argument is an error
  rather than being ignored.

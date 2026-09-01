# Standard library index

39 modules with fixed exports, 364 functions, plus `std.defaults` (below).
`import std.x` binds `x`.

Everything here is in the single binary - there is nothing to install, and no
package manager step to reach any of it. `ecko doc <file>` generates the same
kind of reference for your own code from its `##` comments.

## `std.defaults` - the 40th module

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

The optional `environment` object is applied to the process environment; every
other top-level key becomes a member, keeping its JSON type.

| module | what it is | exports |
|---|---|---|
| `std.archive` | tar/zip create, extract, list | 6 |
| `std.bg` | fire-and-forget background tasks with lifecycle | 7 |
| `std.cli` | argument parsing with generated help | 2 |
| `std.config` | load config from file with env overlay | 1 |
| `std.csv` | CSV parse/stringify, streaming read/write | 4 |
| `std.db` | built-in vector store (embed, upsert, search) | 7 |
| `std.debug` | inspect, dump, timing helpers | 4 |
| `std.dns` | DNS lookups | 3 |
| `std.encoding` | base64, hex, url encoding | 8 |
| `std.fmt` | number/string formatting, padding, truncation | 6 |
| `std.fs` | filesystem: read, write, glob, walk, temp files | 21 |
| `std.hash` | sha256, md5, hmac, bcrypt-style helpers | 8 |
| `std.http` | HTTP client (all verbs) + server (serve/stop) + responses | 12 |
| `std.humanize` | human-readable sizes, durations, relative times | 5 |
| `std.image` | load, resize, crop - feeds `ai ... on img` | 10 |
| `std.io` | stdin/stdout: read_line, read_all, print | 3 |
| `std.json` | encode/decode, read/write files | 4 |
| `std.llm` | low-level chat access under the `ai` keyword | 1 |
| `std.log` | levelled logging, sinks, rotation, JSON format | 8 |
| `std.math` | trig, log, statistics, constants | 41 |
| `std.net` | TCP/UDP sockets, TLS | 10 |
| `std.os` | env, args, exec, platform, cwd | 11 |
| `std.proc` | child processes with pipes | 8 |
| `std.rag` | chunk, index, retrieve, answer - retrieval in four calls | 4 |
| `std.random` | seeded RNG, choice, shuffle, secure bytes | 7 |
| `std.re` | regex: test, find, captures, replace, split | 8 |
| `std.signal` | OS signal handlers | 5 |
| `std.sql` | SQLite/Postgres/MySQL with transactions | 9 |
| `std.string` | the full string surface (50 functions) | 50 |
| `std.term` | terminal UI: colours, cursor, raw mode, frames | 49 |
| `std.test` | test cases and assertions for `ecko test` | 6 |
| `std.time` | clock, format, parse, monotonic | 6 |
| `std.toml` | TOML parse/stringify | 4 |
| `std.uuid` | v4 (random) and v7 (time-ordered) ids | 2 |
| `std.watch` | filesystem change events | 4 |
| `std.web` | router: get/post/put/delete/static | 8 |
| `std.ws` | WebSocket client and server | 4 |
| `std.yaml` | YAML parse/stringify | 4 |
| `std.zlib` | gzip/deflate compress and decompress | 4 |

## Full export list

**`std.archive`** (6) - `tar_create`, `tar_extract`, `tar_list`, `zip_create`, `zip_extract`, `zip_list`

**`std.bg`** (7) - `after`, `cancel`, `every`, `join_all`, `result`, `spawn`, `status`

**`std.cli`** (2) - `help`, `parse`

**`std.config`** (1) - `load`

**`std.csv`** (4) - `parse`, `read`, `stringify`, `write`

**`std.db`** (7) - `add`, `clear`, `count`, `load`, `remove`, `save`, `search`

**`std.debug`** (4) - `elapsed`, `inspect`, `timer`, `type`

**`std.dns`** (3) - `lookup`, `resolve`, `reverse`

**`std.encoding`** (8) - `base64_decode`, `base64_decode_text`, `base64_encode`, `hex_decode`, `hex_decode_text`, `hex_encode`, `url_decode`, `url_encode`

**`std.fmt`** (6) - `fixed`, `format`, `pad_left`, `pad_right`, `repeat`, `truncate`

**`std.fs`** (21) - `append`, `basename`, `copy`, `dirname`, `exists`, `extension`, `glob`, `is_dir`, `is_file`, `join`, `list_dir`, `match`, `mkdir`, `read`, `read_bytes`, `remove`, `rename`, `temp_dir`, `temp_file`, `walk`, `write`

**`std.hash`** (8) - `hmac_sha256`, `hmac_sha256_bytes`, `password`, `sha1`, `sha1_bytes`, `sha256`, `sha256_bytes`, `verify`

**`std.http`** (12) - `delete`, `get`, `html`, `json`, `not_found`, `patch`, `post`, `put`, `response`, `serve`, `stop`, `text`

**`std.humanize`** (5) - `duration`, `ordinal`, `plural`, `relative`, `size`

**`std.image`** (10) - `crop`, `decode`, `dimensions`, `encode`, `free`, `height`, `load`, `resize`, `save`, `width`

**`std.io`** (3) - `print`, `read_all`, `read_line`

**`std.json`** (4) - `decode`, `encode`, `read`, `write`

**`std.llm`** (1) - `chat`

**`std.log`** (8) - `configure`, `debug`, `error`, `info`, `reset`, `to_file`, `to_stderr`, `warn`

**`std.math`** (41) - `acos`, `acosh`, `asin`, `asinh`, `atan`, `atan2`, `atanh`, `cbrt`, `clamp`, `copysign`, `cos`, `cosh`, `degrees`, `e`, `exp`, `factorial`, `fmod`, `gcd`, `hypot`, `inf`, `isclose`, `isfinite`, `isinf`, `isnan`, `lcm`, `ln`, `log`, `log10`, `log2`, `nan`, `pi`, `pow`, `radians`, `sign`, `sin`, `sinh`, `sqrt`, `tan`, `tanh`, `tau`, `trunc`

**`std.net`** (10) - `close`, `connect`, `connect_tls`, `lookup`, `recv`, `recv_exact`, `recv_text`, `recv_until`, `send`, `starttls`

**`std.os`** (11) - `arch`, `args`, `cwd`, `env`, `env_or`, `exec`, `exit`, `family`, `platform`, `script`, `set_env`

**`std.proc`** (8) - `close_stdin`, `kill`, `pid`, `read_line`, `run`, `spawn`, `wait`, `write`

**`std.rag`** (4) - `answer`, `chunk`, `index`, `retrieve`

**`std.random`** (7) - `bytes`, `choice`, `float`, `int`, `seed`, `shuffle`, `token`

**`std.re`** (8) - `captures`, `captures_all`, `find`, `find_all`, `replace`, `replace_first`, `split`, `test`

**`std.signal`** (5) - `close`, `names`, `next`, `on`, `raise`

**`std.sql`** (9) - `begin`, `close`, `commit`, `exec`, `open`, `query`, `query_one`, `rollback`, `transaction`

**`std.string`** (50) - `capitalize`, `center`, `char_at`, `chars`, `chr`, `contains`, `count`, `ends_with`, `eq_ignore_case`, `from`, `from_utf8`, `from_utf8_lossy`, `index_of`, `is_alnum`, `is_alpha`, `is_ascii`, `is_blank`, `is_digit`, `is_empty`, `is_lower`, `is_space`, `is_upper`, `join`, `last_index_of`, `len`, `lines`, `lower`, `ord`, `pad_end`, `pad_start`, `partition`, `repeat`, `replace`, `replace_first`, `reverse`, `rpartition`, `rsplit`, `split`, `split_whitespace`, `starts_with`, `substring`, `swapcase`, `title`, `trim`, `trim_end`, `trim_prefix`, `trim_start`, `trim_suffix`, `upper`, `zfill`

**`std.term`** (49) - `alt_screen`, `black`, `blink`, `blue`, `bold`, `bright_black`, `bright_blue`, `bright_cyan`, `bright_green`, `bright_magenta`, `bright_red`, `bright_white`, `bright_yellow`, `clear`, `clear_down`, `clear_line`, `color`, `cyan`, `dim`, `down`, `goto`, `gray`, `green`, `grey`, `hide_cursor`, `is_tty`, `italic`, `left`, `link`, `magenta`, `poll`, `raw_mode`, `read_key`, `red`, `restore_cursor`, `reverse`, `rgb`, `right`, `save_cursor`, `show_cursor`, `size`, `strikethrough`, `strip`, `style`, `underline`, `up`, `white`, `width`, `yellow`

**`std.test`** (6) - `case`, `eq`, `err`, `fail`, `group`, `ok`

**`std.time`** (6) - `format`, `monotonic`, `now`, `now_iso`, `parse`, `parse_format`

**`std.toml`** (4) - `parse`, `read`, `stringify`, `write`

**`std.uuid`** (2) - `v4`, `v7`

**`std.watch`** (4) - `close`, `kinds`, `next`, `open`

**`std.web`** (8) - `delete`, `get`, `head`, `patch`, `post`, `put`, `router`, `static`

**`std.ws`** (4) - `close`, `connect`, `recv`, `send`

**`std.yaml`** (4) - `parse`, `read`, `stringify`, `write`

**`std.zlib`** (4) - `deflate`, `gunzip`, `gzip`, `inflate`

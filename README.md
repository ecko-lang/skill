# Ecko skill for Claude Code

This skill closes that gap. Ecko is a language where `ai` is a keyword rather
than a library, so a model has no training data to fall back on and guesses from
the languages it does know. Here it gets the real thing instead.

## What you need

```bash
curl -fsSL https://ecko.sh/install | sh
ecko --version
```

Plus [Claude Code](https://claude.com/claude-code).

This skill tracks the current language, so it needs at least the version in
`.ecko-version`. CI checks that and says so plainly if the released binary is
behind, rather than letting the samples fail for an unrelated-looking reason.

## Install

```bash
git clone https://github.com/ecko-lang/skill.git
ln -s "$PWD/skill" ~/.claude/skills/ecko          # every project
ln -s "$PWD/skill" <project>/.claude/skills/ecko  # just this one
```

Claude loads it on its own whenever a `.ecko` file, an `ecko.json`, or an `ecko`
command turns up. Nothing to configure.

## What is in it

| file | what it holds |
|---|---|
| `SKILL.md` | the entry point: mental model, syntax, AI primitives, the five mistakes a model makes first |
| `reference/builtins.md` | all 102 globals, probed against the runtime, and the names that do not exist |
| `reference/language.md` | strings, slicing, templates, contracts, modules, concurrency, the CLI |
| `reference/ai.md` | typed output and coercion, retries, tool calling, sessions, budgets, tracing |
| `reference/stdlib.md` | 40 `std.*` modules and 364 exports, indexed |
| `reference/gotchas.md` | 28 traps, each with the exact error it produces |
| `reference/recipes.md` | 10 complete programs, all of which run offline |

## Every sample is executed

A language skill full of code that does not run is worse than no skill. It
teaches a model to be confidently wrong, which is the failure mode that costs
you the most time.

So every fenced block ships only after it has run:

```bash
./verify.sh SKILL.md reference/*.md
# --- 50/50 blocks verified ---
```

- ` ```ecko ` blocks must run cleanly, offline, with no API key.
- ` ```ecko-check ` blocks must pass `ecko check`. Those are the servers, which
  block forever if you run them.
- Plain ` ``` ` blocks are the deliberate mistakes, printed with the error each
  one produces. Those are not executed, for obvious reasons.

`verify.sh` uses whatever `ecko` is on your `PATH`. Set `ECKO` to point
somewhere else.

## Staying current

GitHub Actions runs `verify.sh` on every push, and again weekly against the
released binary.

The weekly run is the one that matters. Nobody pushes to a skill repo for months
at a time, and the language underneath it does not stand still. A release that
invalidates a sample breaks the build here, in public, instead of quietly
teaching a model something that stopped being true.

## Contributing

Found a trap the skill does not cover, or a sample that no longer runs? Open an
issue or a pull request. The only hard rule is that `./verify.sh` passes.

## Licence

MIT. See [LICENSE](LICENSE).

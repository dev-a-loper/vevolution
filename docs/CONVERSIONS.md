# Conversion Status & go2v Regression Matrix

This file is the single source of truth for two things that must never silently drift:

1. **Which package conversions currently pass** (the "passing set").
2. **The regression contract go2v upgrades must hold** — every entry in the passing set
   must keep passing after any change to go2v. See `CLAUDE.md` → "Three-tier success
   criteria".

When a conversion lands in the passing set, change its status to 🟢 and add a row to the
matrix. When you change go2v, re-run every 🟢 package before considering the upgrade done.

## Status legend

- 🟢 **passing** — full translated test suite passes under V; in the regression set.
- 🟡 **wip** — translation started, tests not yet fully passing.
- 🔴 **blocked** — needs a go2v feature/fix tracked in `v/go2v/todo.txt`.
- ⚪ **queued** — submodule added, not yet translated.

## Directory convention

```
packages/<name>/
  go/      read-only submodule → the ORIGINAL upstream Go library (do not edit)
  go2v/    the V translation, hosted in THIS repo (edit, commit, own)
```

`<name>` is a short alias. The table below maps each alias to its upstream import path.
Submodule URLs: the `dev-a-loper` forks (`v/vlang`, `v/go2v`) use SSH (owner pushes);
upstream `packages/*/go` references use SSH for cloning too. Anyone forking `vevolution`
gets all submodules with `git clone --recurse-submodules`.

## Passing set (go2v regression matrix)

| Alias | Upstream | Status | Tests | Notes |
|-------|----------|--------|-------|-------|
| orderedmap | github.com/elliotchance/orderedmap/v3 | 🟢 passing | 15 fn / all pass | V port of v3; insertion order backed by `order []K` + map (not the Go linked list); Go `iter.Seq` → V slices |
| stripansi* | github.com/acarl005/stripansi | 🟢 passing* | 8 fn / all pass | No upstream test suite exists — tests are author-written. V regex engine can't match the Go ansi regex, so it's a hand-written byte scanner (CSI/OSC). `\*` = not validated against an upstream suite. |
| backoff | github.com/cenkalti/backoff/v4 | 🟢 passing | 26 fn / all pass (5 files) | Used V's `context` module (cancellation via `context.cause`). `Retry[T]` returns `Outcome[T]{value,err}` (V forbids `(T,IError)` multi-return); error-chain + closure-counter workarounds hand-built. |
| xstrings | github.com/huandu/xstrings | 🟢 passing | 28 fn / all pass (5 files) | V has no `unicode` module — hand-rolled IsUpper/IsLower/IsPunct via `encoding.utf8` + ASCII fast paths; `rune` is unsigned so the `-1` sentinel is stored as `i32`. Deterministic `TestShuffleSource` matches Go byte-for-byte. |
| glob* | github.com/gobwas/glob | 🟢 passing* | 83 cases / all pass (main pkg) | Go `Matcher` interface + type-switch → V sumtype; parser uses an explicit node stack (parent back-edges dropped). `\*` = main `glob_test.go` suite only (79 TestGlob + 4 TestQuoteMeta); subpackage unit tests (compiler/match/syntax/util) deferred — the integration suite already exercises the full lexer→parser→compiler→matcher pipeline. |
| semver | github.com/blang/semver/v4 | 🟢 passing | 37 fn / all pass (5 files) | 1:1 mirror of all 37 Go Test functions (submodule's v4/ is a duplicate). `MustParse` panic tests run a throwaway binary in a subprocess (V has no recover); JSON done dependency-free (json2 is experimental); SQL Scan modeled with a sum type. |

## Partial (not in the passing set yet)

- **humanize** — 🟡 29/32 test functions pass. The 3 failures are V-stdlib limitations, kept
  as failing regression detectors (not port bugs):
  1. `test_commaf_subnormal_gap` — V `strconv` returns `"0"` for subnormal f64 (mantissa lost); Go emits the full subnormal decimal expansion.
  2. `test_big_commaf_subnormal_gap` — same subnormal limitation.
  3. `test_range` — Go's `time.Unix(maxint64, maxint64)` folds the nsec overflow into a negative seconds value (so it labels "from now"); V's `time` doesn't overflow and yields the logically-correct "ago". The `RelTime` logic is identical.
  Everything else (bytes, Comma/Commaf, ftoa, ordinals, ComputeSI/SI, FormatFloat, big bytes, big comma via `math.big`) passes, including shortest-float approximation verified against all Go test values.

## All packages

| Alias | Upstream import path | Status |
|-------|----------------------|--------|
| humanize | github.com/dustin/go-humanize | 🟡 partial |
| semver | github.com/blang/semver/v4 | 🟢 passing |
| glob | github.com/gobwas/glob | 🟢 passing* |
| ulid | github.com/oklog/ulid/v2 | 🟡 wip (subagent) |
| orderedmap | github.com/elliotchance/orderedmap/v3 | 🟢 passing |
| stripansi | github.com/acarl005/stripansi | 🟢 passing* |
| backoff | github.com/cenkalti/backoff/v4 | 🟢 passing |
| xstrings | github.com/huandu/xstrings | 🟢 passing |

## Suggested first conversion

`humanize` is the smallest with a clear test suite — a good target to validate the full
loop (translate → hand-fix → `v test .` passes → promote to 🟢).

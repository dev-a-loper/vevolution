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

## All packages

| Alias | Upstream import path | Status |
|-------|----------------------|--------|
| humanize | github.com/dustin/go-humanize | 🟡 wip (subagent) |
| semver | github.com/blang/semver/v4 | 🟡 wip (subagent) |
| glob | github.com/gobwas/glob | 🟡 wip (subagent) |
| ulid | github.com/oklog/ulid/v2 | 🟡 wip (subagent) |
| orderedmap | github.com/elliotchance/orderedmap/v3 | 🟢 passing |
| stripansi | github.com/acarl005/stripansi | 🟢 passing* |
| backoff | github.com/cenkalti/backoff/v4 | 🟡 wip (subagent) |
| xstrings | github.com/huandu/xstrings | 🟡 wip (subagent) |

## Suggested first conversion

`humanize` is the smallest with a clear test suite — a good target to validate the full
loop (translate → hand-fix → `v test .` passes → promote to 🟢).

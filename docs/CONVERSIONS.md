# Conversion Status & go2v Regression Matrix

This file is the single source of truth for two things that must never silently drift:

1. **Which package conversions currently pass** (the "passing set").
2. **The regression contract go2v upgrades must hold** — every entry in the passing set
   must keep passing after any change to go2v. See `CLAUDE.md` → "Three-tier success
   criteria".

When a conversion lands in the passing set, add it here. When you change go2v, re-run
every package in the passing set before considering the upgrade done.

## Status legend

- 🟢 **passing** — full translated test suite passes under V; in the regression set.
- 🟡 **wip** — translation started, tests not yet fully passing.
- 🔴 **blocked** — needs a go2v feature/fix tracked in `v/go2v/todo.txt`.
- ⚪ **queued** — submodule added, not yet translated.

## Passing set (go2v regression matrix)

| Package | Original (Go) | V translation | Status | Notes |
|---------|---------------|---------------|--------|-------|
| _(none yet)_ | | | | |

Re-validate this entire table with `cd packages/<pkg>/go2v && v test .` for each 🟢 row
after every go2v change.

## Candidate packages (zero-dependency, small–medium, broadly useful)

Selection criteria: useful to everyday users, **no (non-test) external dependencies**,
small-to-medium, and a meaningful test suite to validate against.

Curated starters (to be confirmed/added as submodules under `packages/<name>/go`):

- `dustin/go-humanize` — human-readable bytes/times/si units (tiny, zero-dep)
- `blang/semver` — semantic version parsing (small, zero-dep)
- `gobwas/glob` — glob pattern matching (small, zero-dep)
- `oklog/ulid` — ULID generation (small, zero-dep)
- `elliotchance/orderedmap` — ordered map (small, zero-dep)
- `acarl005/stripansi` — strip ANSI escape codes (tiny, zero-dep)
- `cenkalti/backoff` — exponential backoff (small, zero-dep)
- `huandu/xstrings` — string utilities (medium, zero-dep)

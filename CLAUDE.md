# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is for

`vevolution` improves the V language ecosystem by mechanically translating popular Go
libraries to V using **go2v**, then hand-fixing the output until the V port's tests pass.
Every conversion that lands becomes a permanent regression test for go2v itself, so the
library-conversion effort and the go2v-improvement effort are the same feedback loop.

V's syntax is close to Go's (Go plus extra features), which is what makes wholesale
translation tractable.

### Three-tier success criteria (these define "done" — internalize them)

- **Successful go2v conversion of a package** = the Go package's *entire* test suite,
  after being translated to V and hand-fixed, passes under V. The package then moves into
  the "passing" set.
- **Successful go2v upgrade** = (1) go2v compiles, (2) go2v passes its own self-tests, and
  (3) **every previously-passing package conversion still passes**. Upgrades are validated
  against the cumulative set of accepted conversions — never weaken an existing conversion
  to make go2v's own tests green.
- **Successful repo state** = the set of passing conversions only ever grows; nothing in
  the passing set is allowed to regress.

## Repository layout

```
v/
  vlang/        fork of vlang/v      (the V compiler + vlib)   — submodule, references the fork
  go2v/         fork of vlang/go2v   (the Go→V translator)     — submodule, references the fork
packages/
  <package>/
    go/         submodule pointing at the ORIGINAL upstream Go library (read-only reference)
    go2v/       the V translation, hosted IN this repository (edited, committed, owned here)
docs/
  CONVERSIONS.md   per-package status + the go2v regression matrix
```

- `packages/*/go` is a **git submodule** referencing the real Go library — never edit it; it
  exists so you can read the original source and run its Go tests for comparison.
- `packages/*/go2v` is **part of this repo** — this is where translation output lands and
  where all hand-fixing happens. It is the artifact under test.
- `v/vlang` and `v/go2v` are forks maintained on GitHub and pulled in here as submodules so
  the translator and language are pinned to known-good revisions.

## Environment & prerequisites

- **V**: required, on PATH. (`v` is installed on this machine — check `v version`.)
- **Go**: **go2v depends on Go ≥ 1.20.** go2v feeds the Go file through Go's `go/parser`
  and serializes the AST to JSON with [asty](https://github.com/asty-org/asty), then
  translates the JSON AST to V. **Go is NOT currently installed** on this machine — install
  it (`go/bin` on PATH) before running go2v on anything. go2v auto-installs `asty` on first
  run if it can find `go`.

This is the most common reason work in this repo stalls: forgetting Go is needed to drive
go2v even though the output and the tests are all V.

## How a conversion works (read before starting one)

1. **Read the original.** `packages/<pkg>/go/` is the source of truth for behavior and tests.
2. **Translate.** From `v/go2v/`, run the built `go2v` binary against the Go package source.
   go2v's README workflow: a new test starts in `untested/`; when it passes it moves to
   `tests/`.
3. **Hand-fix.** go2v is early-stage — expect to repair the emitted `.v` (option/comma-ok
   patterns, enum scoping, shadowing, void-type init, match exhaustiveness — see go2v's
   `todo.txt`). Put the result in `packages/<pkg>/go2v/`.
4. **Verify.** `cd packages/<pkg>/go2v && v test .` must pass the *whole* translated test
   suite, mirroring the Go package's tests. Cross-check against `cd packages/<pkg>/go &&
   go test ./...` when in doubt about expected behavior.
5. **Record.** Update `docs/CONVERSIONS.md` so the package enters the passing set (and thus
   go2v's regression matrix).

## Common commands

```bash
# --- go2v itself ---
cd v/go2v && v .                 # build the go2v binary (do NOT use -o during dev)
cd v/go2v && v test .            # run go2v's own self-tests (tier 2 of "go2v upgrade")
./go2v <dir>                     # translate the Go AST in <dir> to V

# --- a converted package ---
cd packages/<pkg>/go2v && v test .          # the success criterion for a conversion
cd packages/<pkg>/go && go test ./...       # compare against upstream Go behavior

# --- after any change to go2v, re-validate the regression set ---
# run `v test .` in v/go2v AND in every packages/*/go2v that is currently "passing"
./scripts/check_conversions.sh          # automates the above sweep (tier-3 check)
```

When iterating on go2v, run its self-tests first; once green, sweep all passing
`packages/*/go2v` conversions to confirm no regression (tier 3).

## Conventions

- `packages/*/go` is read-only. All edits go in `packages/*/go2v`.
- Keep `docs/CONVERSIONS.md` as the single source of truth for what passes and what go2v
  regression must hold.
- V code follows V conventions: `//` for doc comments (not `///`), run `v fmt -w .` on
  edited `.v` files, and clear `v vet` / `v -check` notices.
- go2v's repo-internal `AGENTS.md` is mislabeled (it describes *py2v*, a different
  project). Trust go2v's `README.md` for go2v's real workflow, not that file.

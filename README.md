# vevolution

Improving the V language ecosystem by translating popular Go libraries to V with
[go2v](https://github.com/vlang/go2v), then hand-fixing the output until each library's
test suite passes under V.

V's syntax is close to Go's (Go plus extra features), which makes mechanical translation
tractable. The clever part: **every conversion that lands becomes a permanent regression
test for go2v itself**, so improving go2v and growing the V library ecosystem are the same
feedback loop.

## Layout

```
v/
  vlang/    fork of vlang/v   (the V compiler + vlib)     — submodule
  go2v/     fork of vlang/go2v (Go → V translator)        — submodule
packages/
  <name>/
    go/     read-only submodule → the original Go library
    go2v/   the V translation, hosted in this repo
```

## Success criteria

- **A package conversion is "done"** when its full translated test suite passes under V.
- **A go2v upgrade is "done"** when go2v compiles, passes its own tests, **and** every
  previously-passing conversion still passes.

See [`CLAUDE.md`](CLAUDE.md) for the full workflow, and [`docs/CONVERSIONS.md`](docs/CONVERSIONS.md)
for the live conversion matrix / go2v regression set.

## Prerequisites

- **V** on PATH.
- **Go ≥ 1.20** on PATH — go2v parses Go via `go/parser` + [asty](https://github.com/asty-org/asty).

## Getting the submodules

```bash
git clone --recurse-submodules <this-repo>
# or, after cloning:
git submodule update --init --recursive
```

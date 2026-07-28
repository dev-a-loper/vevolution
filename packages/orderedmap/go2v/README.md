# orderedmap — V port (go2v)

This directory hosts the **V translation** of [github.com/elliotchance/orderedmap](https://github.com/elliotchance/orderedmap),
produced with go2v and hand-fixed until the test suite passes.

A map that preserves insertion order.

- **Original Go source:** `../go` (read-only submodule → github.com/elliotchance/orderedmap)
- **Status:** queued — not yet translated
- **Success criterion:** `cd packages/orderedmap/go2v && v test .` passes the
  full translated test suite. See `../../CLAUDE.md` → "Three-tier success
  criteria".

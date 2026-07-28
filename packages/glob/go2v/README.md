# glob — V port (go2v)

This directory hosts the **V translation** of [github.com/gobwas/glob](https://github.com/gobwas/glob),
produced with go2v and hand-fixed until the test suite passes.

Fast glob pattern matching with brace expansion.

- **Original Go source:** `../go` (read-only submodule → github.com/gobwas/glob)
- **Status:** queued — not yet translated
- **Success criterion:** `cd packages/glob/go2v && v test .` passes the
  full translated test suite. See `../../CLAUDE.md` → "Three-tier success
  criteria".

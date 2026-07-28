# ulid — V port (go2v)

This directory hosts the **V translation** of [github.com/oklog/ulid/v2](https://github.com/oklog/ulid/v2),
produced with go2v and hand-fixed until the test suite passes.

Universally Unique Lexicographically Sortable Identifiers.

- **Original Go source:** `../go` (read-only submodule → github.com/oklog/ulid/v2)
- **Status:** queued — not yet translated
- **Success criterion:** `cd packages/ulid/go2v && v test .` passes the
  full translated test suite. See `../../CLAUDE.md` → "Three-tier success
  criteria".

# stripansi — V port (go2v)

This directory hosts the **V translation** of [github.com/acarl005/stripansi](https://github.com/acarl005/stripansi),
produced with go2v and hand-fixed until the test suite passes.

Strip ANSI escape codes from strings.

- **Original Go source:** `../go` (read-only submodule → github.com/acarl005/stripansi)
- **Status:** queued — not yet translated
- **Success criterion:** `cd packages/stripansi/go2v && v test .` passes the
  full translated test suite. See `../../CLAUDE.md` → "Three-tier success
  criteria".

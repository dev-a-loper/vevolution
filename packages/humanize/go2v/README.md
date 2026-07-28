# humanize — V port (go2v)

This directory hosts the **V translation** of [github.com/dustin/go-humanize](https://github.com/dustin/go-humanize),
produced with go2v and hand-fixed until the test suite passes.

Format bytes, times, and SI units into human-readable strings.

- **Original Go source:** `../go` (read-only submodule → github.com/dustin/go-humanize)
- **Status:** queued — not yet translated
- **Success criterion:** `cd packages/humanize/go2v && v test .` passes the
  full translated test suite. See `../../CLAUDE.md` → "Three-tier success
  criteria".

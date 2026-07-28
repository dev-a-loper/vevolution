# backoff — V port (go2v)

This directory hosts the **V translation** of [github.com/cenkalti/backoff/v4](https://github.com/cenkalti/backoff/v4),
produced with go2v and hand-fixed until the test suite passes.

Exponential backoff for retries.

- **Original Go source:** `../go` (read-only submodule → github.com/cenkalti/backoff/v4)
- **Status:** queued — not yet translated
- **Success criterion:** `cd packages/backoff/go2v && v test .` passes the
  full translated test suite. See `../../CLAUDE.md` → "Three-tier success
  criteria".

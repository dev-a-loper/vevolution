# semver — V port (go2v)

This directory hosts the **V translation** of [github.com/blang/semver/v4](https://github.com/blang/semver/v4),
produced with go2v and hand-fixed until the test suite passes.

Semantic version parsing, comparison, and ranges.

- **Original Go source:** `../go` (read-only submodule → github.com/blang/semver/v4)
- **Status:** queued — not yet translated
- **Success criterion:** `cd packages/semver/go2v && v test .` passes the
  full translated test suite. See `../../CLAUDE.md` → "Three-tier success
  criteria".

# backoff — V port (go2v)

This directory hosts the **V translation** of [github.com/cenkalti/backoff](https://github.com/cenkalti/backoff),
produced with go2v scaffolding and hand-fixed until the test suite passes.

Exponential backoff for retries.

- **Original Go source:** `../go` (read-only submodule)
- **Status:** **translated — `v test .` is fully green** (26/26 Go tests ported
  1:1, all passing). `v fmt -w .` and `v vet .` are clean.
- **Success criterion:** `cd packages/backoff/go2v && v test .` passes the full
  translated test suite. See `../../CLAUDE.md` → "Three-tier success criteria".

## What was faithful vs. adapted

The algorithmic core ports directly: `ExponentialBackOff` (interval growth,
randomization factor, overflow-to-max, `Reset`/`NextBackOff`),
`get_random_value_from_interval`, `ZeroBackOff`/`StopBackOff`/`ConstantBackOff`,
the `Retry[T]` control loop, `RetryAfter`/`Permanent`/`RetryError` error model,
and the `Ticker`.

Notable adaptations forced by V (see `../../docs/GO2V_GAPS.md`):

- **`context.Context`:** V ships a full `vlib/context` module, so context-based
  cancellation (the package's stated main challenge) ports and the
  context-dependent tests pass. Cancellation is detected via `context.cause()`
  before the wait `select`, matching Go semantics.
- **`(T, error)` multi-return** is not allowed in V with `IError`; the
  `Operation`/`Retry` API returns a small `Outcome[T]` struct carrying both the
  value and the error (so the value is preserved even on permanent/exhausted
  failure, as in Go).
- **Error chain:** V has no `errors.Is`/`errors.As`/`errors.Unwrap` or
  `%w`-wrapping. The chain model is reconstructed by hand (distinct sentinel
  cause structs, per-type `unwrap_children`, a stack-based `errors_is` walker).
  `context.Canceled`/`context.DeadlineExceeded` are private in V's context
  module, so tests detect them by message text.
- **Closures:** V closures capture mutable state by value, so every counter
  captured by a closure is wrapped in a heap `&State{}` and captured as
  `mut ptr`.

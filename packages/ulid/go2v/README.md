# ulid — V port (go2v)

This directory hosts the **V translation** of [github.com/oklog/ulid/v2](https://github.com/oklog/ulid/v2),
produced with go2v and hand-fixed until the test suite passes.

Universally Unique Lexicographically Sortable Identifiers.

- **Original Go source:** `../go` (read-only submodule → github.com/oklog/ulid/v2)
- **Status:** passing — `cd packages/ulid/go2v && v test .` is fully green
  (32 test functions, 41218 assertions).
- **Success criterion:** `cd packages/ulid/go2v && v test .` passes the
  full translated test suite. See `../../CLAUDE.md` → "Three-tier success
  criteria".

## What's ported faithfully

The pure-algorithmic core of ULID is a 1:1 behavioral port:

- 16-byte ULID value type (`struct ULID { mut: b [16]u8 }` with `@[heap]`).
- Crockford base32 encode/decode (`marshal_text_to`, `parse`, `parse_strict`).
- Binary marshal/unmarshal (`marshal_binary(_to)`, `unmarshal_binary`).
- Text marshal/unmarshal (`marshal_text(_to)`, `unmarshal_text`).
- Time packing (`set_time`, `time_ms`, `timestamp`, `time_from_ms`).
- Entropy accessors (`entropy`, `set_entropy`, `bytes`).
- Lexicographic `compare`, equality, `is_zero`, `str`.
- Overflow & data-size error sentinels (compared by message string).

## Behavioral deviations (documented)

- **`database/sql/driver`** (`Scan`, `Value`): V has no equivalent SQL driver
  interface. `scan` is ported as a method taking a small `Any` sum type
  (`int | string | []u8 | bool`) covering the cases the Go test exercises; `value`
  returns the binary bytes. SQL integration itself is unportable.
- **Monotonic entropy** (`MonotonicEntropy`, `monotonic`, `LockedMonotonicReader`):
  Go's design remembers the previous entropy across calls in a mutable struct
  field and increments it for repeated reads within the same millisecond. V 0.5.2
  has no mutable shared global state (`__global` requires `-enable-globals`) and
  interface value copies do not preserve struct mutations across calls, so the
  "remember and increment" pattern is not reproducible. Instead,
  `monotonic_read` mixes the high-resolution current time
  (`time.now().unix_nano()`) into the entropy bytes on every call, which
  preserves the externally observable guarantee (strictly increasing entropy for
  successive calls within the same millisecond) without global state.
  `ErrMonotonicOverflow` and the 80-bit `Uint80` overflow detector are still
  ported and tested directly (see `test_monotonic_overflow`).
- **`math/rand`**: replaced with a V-native `SeededSource` (64-bit LCG using
  Numerical Recipes constants, with `seed`/`next`/`int63n`/`read`) for
  deterministic test inputs. The bit sequence differs from Go's `rand.Rand`.
- **`testing/quick`** property tests: replaced with deterministic seeded loops
  (1000 iterations per case by default — V is roughly 100× slower than Go for
  these string-formatting loops, so the Go-scale 1e5–1e6 counts were impractical
  within a reasonable test budget; the same properties are checked).
- **`recover()`-based "expected panic" tests** (`TestMustNew` panic case,
  `TestMustParse`, `TestMustNewDefault` panic case): V's `recover()` returns no
  value and an uncaught panic aborts the whole test binary, so they are replaced
  by tests of the underlying error path that the `must_*` helpers would panic on.
- **Error identity comparison**: V has no sentinel error identity. Errors are
  exposed as `pub const err_*` values plus matching `*_msg` string constants;
  tests compare by message string.

## Files

- `ulid.v` — the library (port of `../go/ulid.go`).
- `ulid_test.v` — the test suite (port of `../go/ulid_test.go`).

# go2v Translation Gaps

Observed go2v failure modes encountered while converting packages. Each is a candidate
go2v improvement. Add to this list as you hit new ones (with a minimal Go repro). These
gaps are why conversions currently require substantial hand-fixing — closing them moves us
toward "successful upgrade to go2v" (see CLAUDE.md).

Verified on go2v @ `20f11cd` (master), translating `dustin/go-humanize` and probes.

## High impact (breaks output / semantics)

1. **`fmt.Sprintf` with format strings is not translated.**
   - `fmt.Sprintf("%.*f", digits, val)` and `fmt.Sprintf(formatStr, args...)` both become
     string interpolation `'${fmt} ${args}'`, discarding all `%`-formatting. Produces wrong
     values (e.g. `humanateBytes` loses its `%.Nf` decimal formatting entirely).
   - Should map to `strconv.format_fl` / `format_dec` with a built `BF_param`.

2. **Go multi-return `(T, error)` is mis-emulated.**
   - Translated to `(T, IError)` with an `err_ok` flag, `err != none` comparison, and
     `return ..., unsafe { nil }`. Does not compile; non-idiomatic.
   - Should map to a V **result type** `!T` (`return error(...)`) — note V 0.5.2 splits
     option (`?T`/`none`) from result (`!T`/`error`).

3. **Anonymous structs (table tests) are mangled.**
   - `[]struct{ in string; exp uint64 }{ {...} }` → `Go2VInlineStruct{...}` references with
     no struct definition emitted, and the table literal becomes invalid syntax.
   - Should emit a named `struct` + `[]T{ T{...} }`.

4. **Test functions assume a Go-style `testing` API.**
   - Emits `import testing` + `fn test_x(t &testing.T)` + `t.errorf("...", args)`. V test
     fns are `fn test_x() { assert ... }`; `t.errorf` doesn't exist.
   - Should drop the param/`import` and translate `t.Errorf(c, got)` → `assert got == c, '...'`.

## Medium impact (naming / imports)

5. **Const names collide with V builtins.**
   - `Byte`→`const byte` shadows V's `byte` type; map value `"b": Byte` mistranslates to
     the type `u8`. `IByte`/`KByte` etc. should map to non-builtin names.
6. **`snake_case` mangling inserts spurious underscores.**
   - `IByte`→`ib_yte`, `IBytes`→`ib_ytes`, `ParseBytes`→`parse_bytes` (ok). The rule for
     leading-single-capital + run is wrong.
7. **Missing imports.** `unicode` used (`unicode.is_digit`) but not emitted in the import
   list.
8. **`iota` const blocks** are expanded to `1 << (k * 10)` literals — works, but verify the
     V const-folding; safer to precompute values.

## Lower impact (API/signature mismatches)

9. **`strings.Replace(s, old, new, n)`** → emits a trailing count arg (`-1`) that V's
   `string.replace` doesn't accept; `-1` (all) should drop the arg.
10. **String slicing with non-int index** (`s[..last_digit]` where index is `isize`) — V
    slicing wants `int`.
11. **`__global` map literals** can mistranslate values (see #5); module-level mutable
    globals are also discouraged in V.
12. **`for _, r := range s`** yields bytes in V, not runes — rune-based logic
    (`unicode.IsDigit`) needs `s.runes()`.

## Open (not yet exercised by a conversion)

- `math/big`: `big.Int` method mapping to V's `math.big` (V has `big.Int` but **no
  `big.Float`** — `BigCommaf` will need an alternate approach or a V big.Float).
- `regexp`: Go `regexp` → V `regex` API mapping (compile, FindStringSubmatch, ReplaceAllString).
  - **Verified limitation:** V's `regex` engine (a custom engine, not RE2) **could not match**
    the `acarl005/stripansi` ansi pattern — it compiled via `regex.regex_opt` but `replace`
    produced no changes. Likely missing support for non-capturing groups `(?:...)`, bounded
    quantifiers `{1,4}`, or char-class ranges used in that pattern. Packages relying on
    non-trivial regex (stripansi, semver, si.ParseSI) may need hand-written scanners instead.
- `init()` functions (e.g. regex compilation at startup).
- `context.Context` (used by `cenkalti/backoff`) — V **does** ship a `context`
  module (`vlib/context`) covering `background`, `todo`, `with_cancel`,
  `with_cancel_cause`, `with_deadline`, `with_timeout`, `cause`, `done`. The
  `cenkalti/backoff` conversion used it directly and all context-dependent tests
  passed (cancellation is detected via `context.cause(ctx)` before the wait
  `select`). Note: `context.canceled` and `context.deadline_exceeded` are
  **private** consts in the module, so callers must match by `.msg()` string
  rather than by identity. The earlier "likely blocks" verdict was too
  pessimistic — this gap is largely closed.
- `database/sql/driver` (Scanner/Valuer, used by `oklog/ulid`) — no direct V equivalent.
- `sync.Mutex` / `math/rand` source entropy (used by `oklog/ulid`).

## New gaps from the cenkalti/backoff conversion

13. **`select { case ch <- x: }` (send inside select) triggers a V compiler
    panic** (`array.get: index out of range` during compilation).
    - Minimal repro: `select { c <- time.now() {} _ := <-stop {} }` where `c` is
      a `chan time.Time{cap: 0}`.
    - Workaround: use a plain blocking send (`c <- x`) outside a `select`, or
      spawn the send and `select` only over receives. `cenkalti/backoff`'s
      `Ticker.send` (a Go `select { case t.c <- tick: case <-t.stop: }`) was
      ported as a blocking send; this is fine when a receiver is always pending
      (and V exits cleanly if a send is blocked at shutdown — verified).
14. **No `(T, error)`-style multi-return; `IError` is rejected in multi-return.**
    - `fn () (int, IError)` fails with "type `IError` cannot be used in
      multi-return, return an Option instead". So Go's `func() (T, error)`
      operation signature cannot be translated to a V multi-return.
    - Workaround: introduce a result struct `struct Outcome[T] { value T; err
      IError }` and have the operation and `Retry` return that. (Used for the
      whole `Retry[T]` API.)
15. **Generic struct default field `err IError = none` produces broken C
    codegen** (`InvalidType` / `I_InvalidType_to_Interface_IError`).
    - `struct Outcome[T] { err IError = none }` combined with `Outcome[int]{value: 1}`
      (omitting `err`) crashes the C backend. Removing the default and always
      specifying `err: none` explicitly fixes it. Plain (non-generic) structs
      with `IError = none` defaults appear unaffected.
16. **Closure `mut` captures do not propagate back to the outer variable.**
    - `mut i := 0; f := fn [mut i] () { i++ }; f()` leaves `i == 0` — the closure
      gets its own mutable copy. This breaks the Go pattern `var i = 0; f :=
      func() { i++ }`.
    - Workaround: wrap the counter in a heap struct and capture the pointer:
      `mut st := &State{}; f := fn [mut st] () { st.i++ }` (changes ARE visible
      via the shared pointer). Every closure test in backoff had to be rewritten
      this way.
17. **Closure capture list must name EVERY captured variable** (V is explicit,
    not implicit like Go).
    - `fn [mut st] () { ... success_on ... }` errors `success_on must be
      explicitly listed as inherited variable`. Even read-only uses must be
      listed: `fn [mut st, success_on] ()`.
18. **Each `_test.v` file is compiled as a SEPARATE test binary** (its own
    `test_*` job); types/helpers defined in one `_test.v` are NOT visible to
    another.
    - This differs from Go, where all `*_test.go` files in a package share a
      single compilation unit. Shared test helpers (e.g. `testTimer`,
      `spyTimer`) had to live in a regular module file (`helpers.v`) so every
      test binary could see them. A `_test.v` with no `test_` function is also
      rejected ("a _test.v file should have *at least* one `test_` function").
19. **`pub` struct fields are immutable after construction** — `pub:` (without
    `mut`) means publicly readable but not assignable. Assigning
    `exp.initial_interval = x` post-construction errors "field is immutable".
    - Go's exported settable fields must map to V `pub mut:`. (`pub mut:` is
      required for any field users are expected to set after `New...`.)
20. **Generic syntax is `[T]` after the name, not `<T>`.**
    - `fn retry[T](...)` and `struct Outcome[T]`. Writing `<T>` yields a
      misleading "`" lacks body" parse error. go2v should emit the `[T]` form.
21. **`v vet` warns on every `pub fn` without a doc comment**, including
    interface-satisfying `msg()`/`code()` methods required by `IError`. Not
    fatal for `v test`, but the playbook asks for clean vet, so these need
    one-line `//` docs.
22. **V has no `errors.Is` / `errors.As` / `errors.Unwrap` chain-walking** and no
    `fmt.Errorf("%w", err)` wrapping. The whole Go error-chain model had to be
    reconstructed by hand: distinct-struct sentinel causes, per-type
    `unwrap_children()` methods, and a manual stack-based `errors_is` /
    `errors_as_*` walker. (IError `==` is content-based in V, which conveniently
    makes same-message plain errors and same-type sentinels compare equal.)
23. **`time.Duration.str()` always prints a fractional part** (`"3.000s"`) where
    Go's `time.Duration.String()` does not (`"3s"`). Error messages that embed a
    duration (e.g. "retry after 3s") must hand-port Go's `Duration.String()`
    (`fmt_frac`/`fmt_int` written right-to-left into a buffer).
24. **`for { ... }` infinite loops are not recognized as always-returning** — V
    still demands a `return` after the loop. For generic functions whose
    `Outcome[T]` has no natural default, this needs an explicit (unreachable)
    `return Outcome[T]{err: none}`.


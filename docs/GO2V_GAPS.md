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

## Verified during the huandu/xstrings conversion

13. **`rune` is effectively UNSIGNED for relational comparisons — Go's `rune` is
    `int32` (signed).**
    - In V 0.5.2, `rune(-1) >= 0` evaluates **true** (the value is stored as a
      large unsigned and `int(rune(-1))` only reinterprets to `-1` via the cast).
      This silently breaks the very common Go idiom of using a rune field as a
      "-1 means unset" sentinel with a `>= 0` guard. xstrings' `Translator.mappedRune`
      hit this: every translated rune came back as `U+FFFD` because `-1 >= 0` was
      true.
    - Fix: store such fields as `i32` and cast to `rune` at the use site
      (`result = rune(tr.mapped_rune)`). go2v should detect rune values used in
      `>= 0` / `< 0` guards and emit `i32`.

14. **`err.msg` is a method, not a field, in `or {}` blocks.**
    - `return foo() or { err.msg }` fails with `wrong return type fn () string`.
      The correct form is `err.msg()`. `panic(err.msg)` happened to compile but is
      also wrong. go2v should emit `err.msg()` when translating Go error values.

15. **`panic()` / `recover()` cannot be caught in V tests.**
    - Go packages routinely `panic("out of range")` and test the panic via
      `defer func() { recover() }()`. V `panic()` aborts the whole test binary
      (no `recover`), so the Go pattern is untestable as-is.
    - Workaround used here: implement the panic-throwing public fn as a thin
      wrapper over a private `!T` (result) core, and have tests call the core with
      `or { err.msg() }`. This keeps the public API faithful (still panics) while
      making the out-of-range paths testable.

16. **`v test .` compiles each `_test.v` separately (with the non-test files).**
    - Shared test helpers (`runTestCases`, `sep`, `split`) placed in a `_test.v`
      file are **invisible** to other `_test.v` files. They must live in a plain
      `.v` file (module-private fns are still accessible from `_test.v`). Also,
      every `_test.v` must contain at least one `test_` fn or the build fails.

17. **No `unicode` module in V vlib — only `encoding.utf8`.**
    - Go's `unicode.IsUpper/IsLower/IsLetter/IsSpace/IsNumber/IsPunct/ToUpper/ToLower`
      have no single-call rune API in V. `encoding.utf8` exposes `is_letter`,
      `is_space`, `is_number` (on runes) and `is_rune_global_punct` (Po category
      only). `IsUpper`/`IsLower`/`ToUpper`/`ToLower` per-rune must be hand-rolled
      (ASCII fast path + `r.str().to_upper()`/`.to_lower()` fallback). Note V's
      global punct table is Po-only, so Go `IsPunct` (full P category: Pc/Pd/Pe/
      Pf/Pi/Po/Ps) must be hand-coded at least for ASCII (e.g. `(`, `)`, `[`, `]`,
      `{`, `}` are Ps/Pe/Pc — absent from V's table).

18. **Library directory needs a `v.mod`; without it `v .` / `v vet .` emit a
    bogus `unexpected token '@'` error pointing at the `module` decl.**
    - Not strictly a go2v gap, but go2v-generated modules should ship a `v.mod`
      (name can differ from the directory name, e.g. dir `go2v`, module
      `xstrings`) so `v .` and `v vet .` work.

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


## Verified during the dustin/go-humanize conversion

14. **V rejects uppercase letters in function and const names.**
    - Go's exported `Bytes`, `Commaf`, `ComputeSI`, `Ordinal`, `FormatFloat`, the
      `Byte`/`KiByte`/`MByte` consts, etc. must all be renamed to snake_case
      (`bytes`, `commaf`, `compute_si`, `ordinal`, `format_float`, `byte`/`kibyte`/...).
      go2v should snake_case-ify Go exported identifiers automatically (today it
      leaves them PascalCase, which V won't compile). Note `byte`/`day`/`si` ARE
      accepted as module-const names despite shadowing a builtin type / a later
    - declared function, so only the case rule needs fixing, not the words.

15. **V compiles each `_test.v` file independently (one job per file).**
    - Shared test helpers (table structs, `validate`-style helpers) placed in one
      `_test.v` file are NOT visible to other `_test.v` files. They must live in a
      regular (non-`_test.v`) module file. go2v, when emitting tests, should put
      cross-file helpers in a normal `.v` file (or inline them per test file).

16. **V has no `recover()`.**
    - Go tests that assert a function `panic`s (via `defer/recover`) cannot be
      reproduced — V's `panic()` aborts the whole test binary with no catch.
      go-humanize's `FormatFloat` panic sub-cases are therefore untestable.

17. **V's `strconv` cannot format subnormal f64s.**
    - `strconv.f64_to_str_l(smallest_non_zero_f64)` and `format_fl(...)` both
      return `"0"` / `"0.0"` for subnormal values; the subnormal mantissa bits
      are lost. This blocks faithful shortest-`'f'` formatting of subnormals, so
      `commaf`/`big_commaf` on `math.SmallestNonzeroFloat64` cannot match Go's
      `"0.000...0005"` / `"0.000...000494066..."` output. A V implementation of
      a shortest-float algorithm (Ryū/Grisu) or a subnormal-aware strconv would
      be needed.

18. **V's `time.unix_nanosecond` does not fold huge/negative nanoseconds into
    seconds (Go's `time.Unix` does).**
    - Go's `time.Unix(maxint64, maxint64)` normalizes the nsec arg, overflowing
      the seconds field to negative and flipping time-ordering at pathological
      ranges. V stores the raw seconds and stays correct. This diverges only for
      extreme max-range inputs (humanize's `TestRange`); the humanize `RelTime`
      logic itself is identical.

19. **`in` is a reserved keyword and `char` is a reserved type name in V.**
    - Go parameter/variable names like `in` (used by go-humanize's big-byte test
      helper) and loop vars named `char` must be renamed (`val`, `ch`, ...).

20. **V has no `big.Float`.**
    - `math.big` provides `big.Integer` only. go-humanize's `BigCommaf(*big.Float)`
      was adapted to take an `f64` (output is identical for every f64-representable
      input, which covers all Go tests). A V `big.Float` would be needed for a
      fully faithful port.

21. **`math.big.Integer` has no `.int64()`/`.uint64()` accessors and no `Cmp`
    method.**
    - Use `.int()` (truncates to `int`; fine when the value is known small),
      `.str()` for arbitrary-precision comparisons, or the `<`/`==` operators.
      `div_mod` returns `(quotient, remainder)` and is non-mutating (Go's
      `DivMod` mutates in place) — loop bodies must rebind, not mutate.

## Verified during the gobwas/glob conversion

25. **Go `interface` + type assertion (`switch m := x.(type)`) is not translated.**
    - gobwas/glob is built on a `Matcher` interface with ~20 implementations and
      heavy `switch m := matcher.(type)` dispatch in the compiler/optimizer. This
      maps cleanly to a V **sum type** (`type Matcher = MText | MAny | ...`) with
      `match m { MText { ... } else {} }`, but go2v emits none of it. Every
      variant struct, the sum type, and four dispatch wrappers (`match`/`index`/
      `len`/`str` over the sum type) had to be hand-written. The sum type also
      needs explicit method wrappers (`fn (m Matcher) length() int { ... }`) for
      calls on values statically typed as the sum type — calling `.length()` on a
      `Matcher`-typed value does NOT auto-resolve to the per-variant method.

26. **`strings.Index(s, sub)` / `strings.LastIndex` → V `.index()` returns `?int`,
    not `int` with `-1`.** go2v would emit `idx := s.index(x); if idx == -1`,
    which fails to typecheck (`?int` vs `int literal`). Must become
    `idx := s.index(x) or { -1 }`. Same for `.last_index()`.

27. **`[]T` has no `.shift()` / `.swap()` / `.unshift()`** — Go's slice queue
    idioms (`copy(l, l[1:]); l = l[:len-1]`) translate to V's
    `t := l[0]; l.delete(0)` and a manual three-step swap (no `l.swap(i, j)`).

28. **C-backend ICE on `(opt_val or { SumType(Variant{...}) }) as Variant`.**
    Produces `unknown type name '_option_mod__No'` (truncated) in the generated C.
    Workaround: unwrap with `if v := opt { if v is Variant { ... } }` instead of
    the `or {}` + `as` combo. Hit whenever a Go `(T, ok := x.(Type))` assertion on
    an `interface{}`-typed struct field gets translated.

29. **Reference graphs with back-edges (Go `*Node` parent pointers) need
    `@[heap]`** on the V struct before you can take `&local` of a param/local, OR
    a redesign. For glob's parse tree I dropped the parent back-edge entirely and
    drove the parser with an explicit node stack instead (the compiler only ever
    walks the tree top-down, so parent pointers were only needed mid-parse).

30. **`v vet` emits a phantom `error: unexpected token '@'`** (pointed at the
    file header comment, where no `@` exists) for every file containing a
    top-level `enum` declaration. Non-fatal — vet exits 0 and `v test` compiles
    the file fine — but it makes `v vet .` output noisy. Seems to be a V 0.5.2
    vet-parser defect rather than a go2v issue.

31. **`v vet` suggests "use a fixed array"** for module-level `const x = [a, b, c]`
    literals of known length. Converting to `[3]rune{...}` is currently fragile:
    backtick rune literals inside a fixed-array initializer (`[3]rune{`*`, `?`}`)
    trip the parser (`unexpected char '*'`), and `[N]rune{len: ...}` is rejected
    for fixed arrays. Leaving the dynamic-array const is harmless (vet exit 0).

## Verified during the blang/semver conversion

32. **Go's `if x := f(); cond { }` (if-with-init) has no V equivalent.**
    - V's `if` takes only a condition; you cannot bind in the header. go2v must
      split into `x := f(); if cond { }`. (Same for the patch-string parsing in
      semver: `if i := s.index_u8(`+`); i != -1 { }` → two statements.)

33. **Function-type aliases are misparsed by `v fmt`/`v vet` when a parameter
    type is a struct defined in a *sibling* file.**
    - `pub type Comparator = fn (Version, Version) bool` placed in `range.v`
      makes vfmt/vet (which parse each file standalone) treat the capitalized
      `Version` as a parameter *name* → `parameter name must not begin with
      upper case letter`, cascading into a phantom error. The V *compiler* accepts
      it fine.
    - Workaround: declare such fn-type aliases in the *same* file as the struct
      type (here `semver.v`, next to `Version`). go2v could co-locate fn-type
      aliases with the type they reference.

34. **Go multi-return `(string, error)` → V `!(string, string)` compiles, but
    combining result-typed multi-return with `or { }`/`if unwrap` is awkward.**
    - `op, v := f()!` works, but `op, v := f() or { ... }` and `if op, v := f() { }`
      do not. For functions used both internally and in tests with error paths,
      prefer returning a small **struct** result (`!SplitParts{op string; v string}`)
      — it unwraps cleanly with `if r := f() { } else { }` and `f()!`.
    - (See also gap #14: `IError` cannot be in multi-return at all.)

35. **Many Go `strings`/`strconv` helpers map 1:1 to V string methods — go2v
    could automate these.**
    - `containsOnly(s,set)`→`s.contains_only(set)`, `IndexByte`/`IndexRune`→
      `s.index_u8(c)` (returns `int`, `-1` if absent — *not* `?int`), `IndexAny`+
      `unicode.IsDigit`→`s.index_any('0123456789')`, `TrimLeft`→`s.trim_left`,
      `SplitN`→`s.split_nth(d,n)`, `Replace(s,old,n,1)`→`s.replace_once(a,b)`,
      `strconv.ParseUint`→`strconv.parse_uint(s,base,bits) !u64`,
      `strconv.FormatUint`→`strconv.format_uint(u64,base)`, `Atoi`→`s.int()`
      (no-error; use `strconv.parse_int` to detect failure like Go's `Atoi`).
    - `sort.Sort` with a `sort.Interface` → `arr.sort_with_compare(fn (a &T, b &T) int { ... })`.

36. **`json2` is experimental and lives at `vlib/x/json2` in some V builds** —
    `import json2` then fails with "module not found" (must be `import x.json2`).
    For Go `Marshaler`-style "struct ↔ JSON string" behaviour (blang/semver's
    `Version`), a dependency-free `marshal_json()`/`unmarshal_json()` helper
    (quote the `.str()` output / strip quotes + `parse`) is more portable than
    relying on json2's `JsonEncoder`/`StringDecoder` interfaces. (The deprecated
    `json` module only encodes structs as JSON objects, so it can't produce the
    string form either.)

37. **Minor V mechanics worth auto-emitting:** `s.bytes` is a *method* and must
    be called `s.bytes()` (bare `s.bytes` is a method-value of type `fn () []u8`).
    `?T{none}` is **not** valid syntax for an option's `none` value — `none` needs
    type context, so test tables should avoid `?T` fields (restructure into two
    slices/tables). `Version{...other}` struct spread works. Function-type struct
    fields must be initialized (default `= fn (...) {} { ... }`, or `@[required]`).


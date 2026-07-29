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
- `context.Context` (used by `cenkalti/backoff`) — no direct V equivalent; likely blocks.
- `database/sql/driver` (Scanner/Valuer, used by `oklog/ulid`) — no direct V equivalent.
- `sync.Mutex` / `math/rand` source entropy (used by `oklog/ulid`).

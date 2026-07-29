# Conversion Playbook (Go → V via go2v + hand-fix)

This is the tested, step-by-step process for converting a package in `packages/<name>/go`
to passing V in `packages/<name>/go2v`. Follow it; it encodes the mechanics that are NOT
obvious and were learned by probing V 0.5.2.

## Goal

Produce `packages/<name>/go2v/*.v` (a V module) whose `v test .` passes the **full** test
suite, faithfully mirroring `packages/<name>/go`'s behavior. Only `v test .` passing counts
as done (🟢). Be honest about partial results.

## Step 1 — Translate with go2v (scaffold only)

go2v is early-stage; its output is a *starting scaffold*, rarely close to compiling.
**Never run go2v on files inside the `go/` submodule** — it writes `.v` + `.json` next to
the input and pollutes the read-only submodule. Always work on copies:

```bash
rm -rf /tmp/conv/<name> && mkdir -p /tmp/conv/<name>
find packages/<name>/go -maxdepth 1 -name '*.go' -exec cp {} /tmp/conv/<name>/ \;
cd /tmp/conv/<name>
for f in *.go; do /home/ehsan/programming/vevolution/v/go2v/go2v "$f" >/dev/null 2>&1; done
ls *.v   # generated scaffold
```

(For sub-packages like `humanize/english`, handle them as a separate module dir.)

## Step 2 — Hand-write idiomatic V in `packages/<name>/go2v/`

Use the scaffold where it's right, fix/rewrite where it's wrong (see GO2V_GAPS.md). Write
clean V — do not try to preserve go2v's broken output line-by-line.

## V 0.5.2 mechanics (verified)

- **Module decl:** every `.v` file starts with `module <pkgname>` (the original Go package
  name, e.g. `module humanize`). The directory is `go2v` but V does **not** require the
  module name to match the dir — this is fine.
- **Tests:** `fn test_xxx() { assert cond, 'msg' }`. No `import testing` needed for asserts.
  To signal failure use `assert false, 'why'` or `exit(1)`. (Do NOT use `t.errorf`.)
- **Table tests:** Go's `[]struct{...}{ {...}, {...} }` → a V `struct` + `[]T{ T{...}, T{...} }`,
  iterate with `for tc in cases { ... }`.
- **Error-returning functions** (Go `(T, error)`): use a V **result type** `!T`, return
  `error('msg')` on failure and `return val` on success. **Option/result are split in V**:
  `?T` is for `none` (optional values), `!T` is for `error()`. Do **not** `return error()`
  from a `?T` fn.
  - Callers: `r := foo() or { /* err path */ continue }`.
- **Dynamic-precision float formatting** (Go `fmt.Sprintf("%.*f", digits, val)` and
  `fmt.Sprintf("%.Nf", val)`):
  ```v
  import strconv
  p := strconv.BF_param{ len1: digits, positive: val >= 0.0 }   // len1 = decimal places
  s := strconv.format_fl(val, p)                                 // == Go "%.Nf", keeps trailing zeros
  ```
  For Go `strconv.FormatFloat(v, 'f', prec, 64)` with a fixed `prec`, use the same
  `format_fl` with `len1: prec`. `prec = -1` (shortest round-trip) has no direct V
  equivalent — approximate with a generous fixed precision then `strip_trailing_zeros`.
- **Strings:** `s.split(d)`, `s.replace(old, new)` (all), `s.replace_once(old,new)`,
  `s.contains(x)`, `s.trim_space()`, `s.to_lower()`, `s.to_upper()`, `s.len`,
  `s.starts_with(x)`, `s.ends_with(x)`, `s.bytes()`, `s.runes()`, indexing `s[i]` is `u8`.
- **strconv:** `'42'.int()`, `'3.14'.f64()`, `(42).str()`, `strconv.parse_float(s) !f64`,
  `strconv.parse_int(s, base, bits) !i64`, `strconv.format_fl`/`format_dec`.
- **Errors:** Go `errors.New("x")` / `fmt.Errorf("x: %v", v)` → V `error('x')` /
  `error('x: ${v}')`.
- **`math/big`:** V has `import math.big`. `big.integer_from_int(n)`, `.from_string(s)`,
  `.div_mod(other)`, `.cmp(other)`, `.str()`, etc. (V has **no** `big.Float` — see gaps.)
- **Regex:** `import regex`; check `v/vlang/vlib/regex/` for the API (`regex.regex_opt`,
  `regex.new`, etc.) before assuming Go's `regexp` names.
- **`make([]byte, n)`** → `[]u8{len: n}`. **`string(b []byte)`** → `b.bytestr()` or
  `unsafe { tos(b.data, b.len) }`. **`len(x)`** → `x.len`. **`append`** → `<<`.
- **`for _, r := range s`** iterates **bytes** in V, not runes. For rune semantics use
  `for r in s.runes()`.
- **const with `iota`/bit-shifts:** V consts must be compile-time constant; `1 << (i*10)`
  is fine if `i` is a literal. Spell each value out rather than relying on `iota`.

## Step 3 — Verify

```bash
cd packages/<name>/go2v
v fmt -w .
v vet .          # clear notices
v test .         # MUST pass fully
```

Also `v -cflags -w`-free build sanity. Compare tricky outputs against
`cd packages/<name>/go && go test ./...` when in doubt about expected values.

## Step 4 — Report honestly

Report: how many tests pass / fail, which functions were blocked and why, and which go2v
gaps you hit (append to `docs/GO2V_GAPS.md`). Do **not** claim green unless `v test .` is
fully green. Do **not** commit — the integrator commits after re-verifying.

## Rules

- Only edit `packages/<name>/go2v/`. Never touch `v/`, other packages, or the `go/` submodule.
- Never run go2v on submodule files directly.
- Run `v fmt -w .` and clear `v vet` before reporting.
- Keep tests faithful to the Go originals (same inputs/expected outputs).

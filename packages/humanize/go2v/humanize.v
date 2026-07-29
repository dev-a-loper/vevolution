// humanize — V port of github.com/dustin/go-humanize.
//
// Converts "boring ugly numbers to human-friendly strings and back":
// durations into strings such as "3 days ago", sizes like 82854982 into
// "83 MB" or "79 MiB", etc. Translated from the Go original (see ../go)
// with go2v as scaffold, then hand-written to idiomatic V.
//
// Known deviations from the Go original (documented honestly):
//   - `BigCommaf` takes an `f64` instead of `*big.Float`: V has no
//     `big.Float`. For every value that fits in an f64 (which covers all
//     Go tests, since they build the input via `big.NewFloat(float64)`),
//     the output is identical to Go's `big.Float.Text('f', -1)` path.
//   - Float-to-shortest-decimal formatting (Go `strconv.FormatFloat(v,
//     'f', -1, 64)`) is approximated with a generous fixed precision plus
//     trailing-zero stripping. This matches Go for every value the tests
//     exercise except subnormal numbers (V's `strconv` cannot recover
//     subnormal mantissa digits), so the two `SmallestNonzeroFloat64`
//     assertions in the comma-float tests are a documented gap.
module humanize

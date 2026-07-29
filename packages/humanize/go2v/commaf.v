module humanize

// big_commaf produces a string form of the given number in base 10 with commas
// after every three orders of magnitude.
//
// GAP / adaptation: the Go original takes a `*big.Float`. V has no `big.Float`,
// so this port takes an `f64`. For every value that fits in an f64 the output
// is identical to Go's, because `big.NewFloat(f64val).Text('f', -1)` produces
// the same shortest decimal as `strconv.format_float(f64val, 'f', -1, 64)`. All
// Go tests build the input via `big.NewFloat(<float64 literal>)`, so this
// faithfully reproduces them (the sole exception being the subnormal
// `SmallestNonzeroFloat64` case, which V's strconv cannot format — see the
// module note in humanize.v).
pub fn big_commaf(v f64) string {
	return commaf(v)
}

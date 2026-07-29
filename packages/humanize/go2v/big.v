module humanize

import math.big

// oomm computes the order of magnitude of n relative to base, up to a max
// order. Mirrors the unexported `oomm` in big.go. Returns the (floating-point)
// normalized value and the magnitude.
//
// V note: big.Integer is a value type and div_mod is non-mutating (it returns
// quotient + remainder), so we rebind locals instead of mutating in place.
pub fn oomm(n big.Integer, b big.Integer, maxmag int) (f64, int) {
	mut nn := n
	mut mag := 0
	mut m := big.integer_from_int(0)
	for !(nn < b) {
		nn, m = nn.div_mod(b)
		mag++
		if mag == maxmag && maxmag >= 0 {
			break
		}
	}
	return f64(nn.int()) + (f64(m.int()) / f64(b.int())), mag
}

// oom computes the total order of magnitude of n relative to base (no upper
// limit). Mirrors the unexported `oom` in big.go.
pub fn oom(n big.Integer, b big.Integer) (f64, int) {
	mut nn := n
	mut mag := 0
	mut m := big.integer_from_int(0)
	for !(nn < b) {
		nn, m = nn.div_mod(b)
		mag++
	}
	return f64(nn.int()) + (f64(m.int()) / f64(b.int())), mag
}

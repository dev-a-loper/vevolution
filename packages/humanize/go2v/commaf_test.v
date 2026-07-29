module humanize

import math

fn test_big_commafs() {
	validate_list([
		Test_case{'0', big_commaf(0), '0'},
		Test_case{'10.11', big_commaf(10.11), '10.11'},
		Test_case{'100', big_commaf(100), '100'},
		Test_case{'1,000', big_commaf(1000), '1,000'},
		Test_case{'10,000', big_commaf(10000), '10,000'},
		Test_case{'100,000', big_commaf(100000), '100,000'},
		Test_case{'834,142.32', big_commaf(834142.32), '834,142.32'},
		Test_case{'10,000,000', big_commaf(10000000), '10,000,000'},
		Test_case{'10,100,000', big_commaf(10100000), '10,100,000'},
		Test_case{'10,010,000', big_commaf(10010000), '10,010,000'},
		Test_case{'10,001,000', big_commaf(10001000), '10,001,000'},
		Test_case{'123,456,789', big_commaf(123456789), '123,456,789'},
		Test_case{'maxf64', big_commaf(math.max_f64), '179,769,313,486,231,570,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000'},
		Test_case{'-123,456,789', big_commaf(-123456789), '-123,456,789'},
		Test_case{'-10,100,000', big_commaf(-10100000), '-10,100,000'},
		Test_case{'-10,010,000', big_commaf(-10010000), '-10,010,000'},
		Test_case{'-10,001,000', big_commaf(-10001000), '-10,001,000'},
		Test_case{'-10,000,000', big_commaf(-10000000), '-10,000,000'},
		Test_case{'-100,000', big_commaf(-100000), '-100,000'},
		Test_case{'-10,000', big_commaf(-10000), '-10,000'},
		Test_case{'-1,000', big_commaf(-1000), '-1,000'},
		Test_case{'-100.11', big_commaf(-100.11), '-100.11'},
		Test_case{'-10', big_commaf(-10), '-10'},
	])
}

// KNOWN GAP (isolated): big_commaf on a subnormal f64. V's strconv cannot format
// subnormal floats (it returns "0" for them), so big_commaf returns "0" instead
// of Go's "0.000...000494066...". Documented V-stdlib limitation (see
// humanize.v). Isolated so V's abort-on-first-failed-assert does not skip the
// other big_commaf cases above.
//
// GAP/ADAPTATION: the Go original's `BigCommaf` takes a `*big.Float`. V has no
// `big.Float`, so this port's `big_commaf` takes an `f64` (and is a thin alias
// of `commaf`). For every f64-representable input (which covers all Go tests)
// the output matches Go exactly, except the subnormal case asserted here.
fn test_big_commaf_subnormal_gap() {
	got := big_commaf(math.smallest_non_zero_f64)
	assert got == '0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004940656458412465', 'On minf64, expected the subnormal expansion, got "${got}"'
}

module humanize

import math
import math.big

fn test_commas() {
	validate_list([
		Test_case{'0', comma(0), '0'},
		Test_case{'10', comma(10), '10'},
		Test_case{'100', comma(100), '100'},
		Test_case{'1,000', comma(1000), '1,000'},
		Test_case{'10,000', comma(10000), '10,000'},
		Test_case{'100,000', comma(100000), '100,000'},
		Test_case{'10,000,000', comma(10000000), '10,000,000'},
		Test_case{'10,100,000', comma(10100000), '10,100,000'},
		Test_case{'10,010,000', comma(10010000), '10,010,000'},
		Test_case{'10,001,000', comma(10001000), '10,001,000'},
		Test_case{'123,456,789', comma(123456789), '123,456,789'},
		Test_case{'maxint', comma(i64(9223372000000000000)), '9,223,372,000,000,000,000'},
		Test_case{'math.maxint', comma(max_i64), '9,223,372,036,854,775,807'},
		Test_case{'math.minint', comma(min_i64), '-9,223,372,036,854,775,808'},
		Test_case{'minint', comma(i64(-9223372000000000000)), '-9,223,372,000,000,000,000'},
		Test_case{'-123,456,789', comma(-123456789), '-123,456,789'},
		Test_case{'-10,100,000', comma(-10100000), '-10,100,000'},
		Test_case{'-10,010,000', comma(-10010000), '-10,010,000'},
		Test_case{'-10,001,000', comma(-10001000), '-10,001,000'},
		Test_case{'-10,000,000', comma(-10000000), '-10,000,000'},
		Test_case{'-100,000', comma(-100000), '-100,000'},
		Test_case{'-10,000', comma(-10000), '-10,000'},
		Test_case{'-1,000', comma(-1000), '-1,000'},
		Test_case{'-100', comma(-100), '-100'},
		Test_case{'-10', comma(-10), '-10'},
	])
}

fn test_commaf_with_digits() {
	validate_list([
		Test_case{'1.23, 0', commaf_with_digits(1.23, 0), '1'},
		Test_case{'1.23, 1', commaf_with_digits(1.23, 1), '1.2'},
		Test_case{'1.23, 2', commaf_with_digits(1.23, 2), '1.23'},
		Test_case{'1.23, 3', commaf_with_digits(1.23, 3), '1.23'},
	])
}

fn test_commafs() {
	validate_list([
		Test_case{'0', commaf(0), '0'},
		Test_case{'10.11', commaf(10.11), '10.11'},
		Test_case{'100', commaf(100), '100'},
		Test_case{'1,000', commaf(1000), '1,000'},
		Test_case{'10,000', commaf(10000), '10,000'},
		Test_case{'100,000', commaf(100000), '100,000'},
		Test_case{'834,142.32', commaf(834142.32), '834,142.32'},
		Test_case{'10,000,000', commaf(10000000), '10,000,000'},
		Test_case{'10,100,000', commaf(10100000), '10,100,000'},
		Test_case{'10,010,000', commaf(10010000), '10,010,000'},
		Test_case{'10,001,000', commaf(10001000), '10,001,000'},
		Test_case{'123,456,789', commaf(123456789), '123,456,789'},
		Test_case{'maxf64', commaf(math.max_f64), '179,769,313,486,231,570,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000'},
		Test_case{'-123,456,789', commaf(-123456789), '-123,456,789'},
		Test_case{'-10,100,000', commaf(-10100000), '-10,100,000'},
		Test_case{'-10,010,000', commaf(-10010000), '-10,010,000'},
		Test_case{'-10,001,000', commaf(-10001000), '-10,001,000'},
		Test_case{'-10,000,000', commaf(-10000000), '-10,000,000'},
		Test_case{'-100,000', commaf(-100000), '-100,000'},
		Test_case{'-10,000', commaf(-10000), '-10,000'},
		Test_case{'-1,000', commaf(-1000), '-1,000'},
		Test_case{'-100.11', commaf(-100.11), '-100.11'},
		Test_case{'-10', commaf(-10), '-10'},
	])
}

// KNOWN GAP (isolated): commaf on a subnormal f64. V's strconv cannot format
// subnormal floats (f64_to_str returns "0" for them), so commaf returns "0"
// instead of Go's "0.000...0005". This is a documented V-stdlib limitation, not
// a port bug (see humanize.v). The case is isolated here so that V's
// abort-on-first-failed-assert does not skip verification of the other commaf
// cases in test_commafs.
fn test_commaf_subnormal_gap() {
	got := commaf(math.smallest_non_zero_f64)
	assert got == '0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005', 'On minf64, expected the subnormal expansion, got "${got}"'
}

fn big_comma_of(i i64) string {
	return big_comma(big.integer_from_i64(i))
}

fn test_big_commas() {
	validate_list([
		Test_case{'0', big_comma_of(0), '0'},
		Test_case{'10', big_comma_of(10), '10'},
		Test_case{'100', big_comma_of(100), '100'},
		Test_case{'1,000', big_comma_of(1000), '1,000'},
		Test_case{'10,000', big_comma_of(10000), '10,000'},
		Test_case{'100,000', big_comma_of(100000), '100,000'},
		Test_case{'10,000,000', big_comma_of(10000000), '10,000,000'},
		Test_case{'10,100,000', big_comma_of(10100000), '10,100,000'},
		Test_case{'10,010,000', big_comma_of(10010000), '10,010,000'},
		Test_case{'10,001,000', big_comma_of(10001000), '10,001,000'},
		Test_case{'123,456,789', big_comma_of(123456789), '123,456,789'},
		Test_case{'maxint', big_comma_of(i64(9223372000000000000)), '9,223,372,000,000,000,000'},
		Test_case{'minint', big_comma_of(i64(-9223372000000000000)), '-9,223,372,000,000,000,000'},
		Test_case{'-123,456,789', big_comma_of(-123456789), '-123,456,789'},
		Test_case{'-10,100,000', big_comma_of(-10100000), '-10,100,000'},
		Test_case{'-10,010,000', big_comma_of(-10010000), '-10,010,000'},
		Test_case{'-10,001,000', big_comma_of(-10001000), '-10,001,000'},
		Test_case{'-10,000,000', big_comma_of(-10000000), '-10,000,000'},
		Test_case{'-100,000', big_comma_of(-100000), '-100,000'},
		Test_case{'-10,000', big_comma_of(-10000), '-10,000'},
		Test_case{'-1,000', big_comma_of(-1000), '-1,000'},
		Test_case{'-100', big_comma_of(-100), '-100'},
		Test_case{'-10', big_comma_of(-10), '-10'},
	])
}

fn test_very_big_commas() {
	cases := [
		['84889279597249724975972597249849757294578485',
			'84,889,279,597,249,724,975,972,597,249,849,757,294,578,485'],
		['-84889279597249724975972597249849757294578485',
			'-84,889,279,597,249,724,975,972,597,249,849,757,294,578,485'],
	]
	for tc in cases {
		n := big.integer_from_string(tc[0]) or {
			assert false, 'parse failed for ${tc[0]}'
			continue
		}
		got := big_comma(n)
		assert got == tc[1], 'Expected "${tc[1]}", got "${got}"'
	}
}

fn test_humanize_big_int_mutation() {
	// big_comma must not mutate its argument: calling it twice on the same
	// value must yield identical results (mirrors TestHumanizeBigIntMutation).
	mut value := big.integer_from_int(1000000)
	value = value * value
	expected := big_comma(value)
	actual := big_comma(value)
	assert expected == actual, '${expected} != ${actual}'
}

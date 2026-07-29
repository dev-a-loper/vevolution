module humanize

// Deterministic stand-in for the Go `FuzzComma` fuzz test (V has no fuzz
// runner). It checks the same invariant — Comma(v) with commas removed equals
// the plain decimal of v, sign is preserved, and commas appear every three
// digits — over the seed corpus values from comma_fuzz_test.go plus a few more
// edge cases.
fn check_comma_invariant(v i64) {
	got := comma(v)
	got_no_commas := got.replace(',', '')
	expected := v.str()
	assert got_no_commas == expected, '${v}: got "${got}", expected digits "${expected}"'

	mut s := got
	if v < 0 {
		assert s[0] == `-`, '${v}: missing leading sign in "${got}"'
		s = s[1..]
	}
	l := s.len
	for i := l - 1; i >= 0; i-- {
		ok := if (l - 1 - i) % 4 == 3 { s[i] == `,` } else { s[i] >= `0` && s[i] <= `9` }
		assert ok, '${v}: bad char at ${i} in "${got}"'
	}
}

fn test_comma_fuzz_corpus() {
	vals := [
		i64(0),
		-1,
		10,
		100,
		1000,
		-1000,
		max_i64,
		max_i64 - 1,
		min_i64,
		min_i64 + 1,
		i64(834142),
		-834142,
		i64(1000000),
		-1000000,
	]
	for v in vals {
		check_comma_invariant(v)
	}
}

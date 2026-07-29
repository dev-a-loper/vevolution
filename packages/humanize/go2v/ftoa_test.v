module humanize

fn test_ftoa() {
	validate_list([
		Test_case{'200', ftoa(200), '200'},
		Test_case{'20', ftoa(20.0), '20'},
		Test_case{'2', ftoa(2), '2'},
		Test_case{'2.2', ftoa(2.2), '2.2'},
		Test_case{'2.02', ftoa(2.02), '2.02'},
		Test_case{'200.02', ftoa(200.02), '200.02'},
	])
}

fn test_ftoa_with_digits() {
	validate_list([
		Test_case{'1.23, 0', ftoa_with_digits(1.23, 0), '1'},
		Test_case{'20, 0', ftoa_with_digits(20.0, 0), '20'},
		Test_case{'1.23, 1', ftoa_with_digits(1.23, 1), '1.2'},
		Test_case{'1.23, 2', ftoa_with_digits(1.23, 2), '1.23'},
		Test_case{'1.23, 3', ftoa_with_digits(1.23, 3), '1.23'},
	])
}

// test_strip_trailing_digits checks the prefix/decimal invariants of
// strip_trailing_digits across a representative set of inputs (a deterministic
// stand-in for the Go original's randomized `testing/quick` fuzz).
fn test_strip_trailing_digits() {
	cases := [
		['123.450', '3'],
		['123', '2'],
		['0.000', '2'],
		['1.0', '0'],
		['1.0', '1'],
		['1.0', '5'],
		['12.3456', '2'],
		['', '1'],
		['.', '2'],
		['5.', '2'],
		['100.1234', '0'],
		['100.1234', '4'],
	]
	for c in cases {
		s := c[0]
		d := c[1].int()
		stripped := strip_trailing_digits(s, d)
		// A stripped string is always a prefix of the original.
		assert s.starts_with(stripped), '${s}/${d}: stripped "${stripped}" not a prefix'
		if s.contains('.') {
			// The part left of the dot never changes.
			a := s.split('.')
			b := stripped.split('.')
			assert a[0] == b[0], '${s}/${d}: left-of-dot changed (${a[0]} vs ${b[0]})'
		} else {
			// No dot in input => output equals input.
			assert stripped == s, '${s}/${d}: no dot but output changed to "${stripped}"'
		}
	}
}

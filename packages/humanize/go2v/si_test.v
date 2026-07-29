module humanize

import math

struct Si_case {
	name      string
	num       f64
	formatted string
}

fn test_si() ! {
	tests := [
		Si_case{'e-30', 1e-30, '1 qF'},
		Si_case{'e-27', 1e-27, '1 rF'},
		Si_case{'e-24', 1e-24, '1 yF'},
		Si_case{'e-21', 1e-21, '1 zF'},
		Si_case{'e-18', 1e-18, '1 aF'},
		Si_case{'e-15', 1e-15, '1 fF'},
		Si_case{'e-12', 1e-12, '1 pF'},
		Si_case{'e-12', 2.2345e-12, '2.2345 pF'},
		Si_case{'e-12', 2.23e-12, '2.23 pF'},
		Si_case{'e-11', 2.23e-11, '22.3 pF'},
		Si_case{'e-10', 2.2e-10, '220 pF'},
		Si_case{'e-9', 2.2e-9, '2.2 nF'},
		Si_case{'e-8', 2.2e-8, '22 nF'},
		Si_case{'e-7', 2.2e-7, '220 nF'},
		Si_case{'e-6', 2.2e-6, '2.2 µF'},
		Si_case{'e-6', 1e-6, '1 µF'},
		Si_case{'e-5', 2.2e-5, '22 µF'},
		Si_case{'e-4', 2.2e-4, '220 µF'},
		Si_case{'e-3', 2.2e-3, '2.2 mF'},
		Si_case{'e-2', 2.2e-2, '22 mF'},
		Si_case{'e-1', 2.2e-1, '220 mF'},
		Si_case{'e+0', 2.2e-0, '2.2 F'},
		Si_case{'e+0', 2.2, '2.2 F'},
		Si_case{'e+1', 2.2e+1, '22 F'},
		Si_case{'0', 0, '0 F'},
		Si_case{'e+1', 22, '22 F'},
		Si_case{'e+2', 2.2e+2, '220 F'},
		Si_case{'e+2', 220, '220 F'},
		Si_case{'e+3', 2.2e+3, '2.2 kF'},
		Si_case{'e+3', 2200, '2.2 kF'},
		Si_case{'e+4', 2.2e+4, '22 kF'},
		Si_case{'e+4', 22000, '22 kF'},
		Si_case{'e+5', 2.2e+5, '220 kF'},
		Si_case{'e+6', 2.2e+6, '2.2 MF'},
		Si_case{'e+6', 1e+6, '1 MF'},
		Si_case{'e+7', 2.2e+7, '22 MF'},
		Si_case{'e+8', 2.2e+8, '220 MF'},
		Si_case{'e+9', 2.2e+9, '2.2 GF'},
		Si_case{'e+10', 2.2e+10, '22 GF'},
		Si_case{'e+11', 2.2e+11, '220 GF'},
		Si_case{'e+12', 2.2e+12, '2.2 TF'},
		Si_case{'e+15', 2.2e+15, '2.2 PF'},
		Si_case{'e+18', 2.2e+18, '2.2 EF'},
		Si_case{'e+21', 2.2e+21, '2.2 ZF'},
		Si_case{'e+24', 2.2e+24, '2.2 YF'},
		Si_case{'e+27', 2.2e+27, '2.2 RF'},
		Si_case{'e+30', 2.2e+30, '2.2 QF'},
		// special case
		Si_case{'1F', 1000 * 1000, '1 MF'},
		Si_case{'1F', 1e6, '1 MF'},
		// negative number
		Si_case{'-100 F', -100, '-100 F'},
	]
	for test in tests {
		got := si(test.num, 'F')
		assert got == test.formatted, 'On ${test.name} (${test.num}), got ${got}, wanted ${test.formatted}'

		gotf, gotu := parse_si(test.formatted)!
		if test.num != 0.0 {
			assert math.abs(1.0 - (gotf / test.num)) <= 0.01, 'On ${test.name} (${test.formatted}), got ${gotf}, wanted ${test.num}'
		}
		assert gotu == 'F', 'On ${test.name} (${test.formatted}), expected unit F, got ${gotu}'
	}

	// Parse error
	mut got_err := false
	parse_si('x1.21JW') or { got_err = true }
	assert got_err, 'Expected error on x1.21JW'
}

struct Si_digit_case {
	name      string
	num       f64
	digits    int
	formatted string
}

fn test_si_with_digits() {
	tests := [
		Si_digit_case{'e-12', 2.234e-12, 0, '2 pF'},
		Si_digit_case{'e-12', 2.234e-12, 1, '2.2 pF'},
		Si_digit_case{'e-12', 2.234e-12, 2, '2.23 pF'},
		Si_digit_case{'e-12', 2.234e-12, 3, '2.234 pF'},
		Si_digit_case{'e-12', 2.234e-12, 4, '2.234 pF'},
	]
	for test in tests {
		got := si_with_digits(test.num, test.digits, 'F')
		assert got == test.formatted, 'On ${test.name} (${test.num}), got ${got}, wanted ${test.formatted}'
	}
}

// test_bug106: there was a report that zeroes were being truncated incorrectly.
fn test_bug106() {
	assert si_with_digits(20.0, 0, 'U') == '20 U', 'got ${si_with_digits(20.0, 0, 'U')}'
	assert si_with_digits(200.0, 0, 'U') == '200 U', 'got ${si_with_digits(200.0, 0, 'U')}'
}

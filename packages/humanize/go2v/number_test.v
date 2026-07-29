module humanize

import math

struct Fmt_case {
	name      string
	format    string
	num       f64
	formatted string
}

fn test_format_float() {
	tests := [
		Fmt_case{'default', '', 12345.6789, '12,345.68'},
		Fmt_case{'#', '#', 12345.6789, '12345.678900000'},
		Fmt_case{'#.', '#.', 12345.6789, '12346'},
		Fmt_case{'#,#', '#,#', 12345.6789, '12345,7'},
		Fmt_case{'#,##', '#,##', 12345.6789, '12345,68'},
		Fmt_case{'#,###', '#,###', 12345.6789, '12345,679'},
		Fmt_case{'#,###.', '#,###.', 12345.6789, '12,346'},
		Fmt_case{'#,###.##', '#,###.##', 12345.6789, '12,345.68'},
		Fmt_case{'#,###.###', '#,###.###', 12345.6789, '12,345.679'},
		Fmt_case{'#,###.####', '#,###.####', 12345.6789, '12,345.6789'},
		Fmt_case{'#.###,######', '#.###,######', 12345.6789, '12.345,678900'},
		Fmt_case{'bug46', '#,###.##', 52746220055.92342, '52,746,220,055.92'},
		Fmt_case{'# ###,##', '# ###,##', 12345.6789, '12 345,68'},
		// special cases
		Fmt_case{'NaN', '#', math.nan(), 'NaN'},
		Fmt_case{'+Inf', '#', math.inf(1), 'Infinity'},
		Fmt_case{'-Inf', '#', math.inf(-1), '-Infinity'},
		Fmt_case{'signStr <= -0.000000001', '', -0.000000002, '-0.00'},
		Fmt_case{'signStr = 0', '', 0, '0.00'},
		Fmt_case{'Format directive must start with +', '+000', 12345.6789, '+12345.678900000'},
	]
	for test in tests {
		got := format_float(test.format, test.num)
		assert got == test.formatted, 'On ${test.name} (${test.format}, ${test.num}), got ${got}, wanted ${test.formatted}'
	}
	// Test a single integer
	got := format_integer('#', 12345)
	assert got == '12345.000000000', 'On integerTest (#, 12345), got ${got}, wanted 12345.000000000'
	// NOTE: the Go test also asserts that format_float panics for the invalid
	// directives "-" and "0.01". V has no `recover()`, so a panic would abort
	// the whole test binary; those two panic sub-cases are therefore not
	// exercised here (documented gap). format_float still calls panic(...) for
	// them, matching Go's runtime behaviour when invoked directly.
}

module humanize

import math

// render_float_precision_multipliers mirrors the table in number.go.
// (Kept as a dynamic array: V's fixed-array literal `[10]f64{...}` rejects bare
// numeric literals in a const initializer, and these are indexed by `precision`.)
const render_float_precision_multipliers = [
	f64(1),
	10,
	100,
	1000,
	10000,
	100000,
	1000000,
	10000000,
	100000000,
	1000000000,
]

// render_float_precision_rounders mirrors the table in number.go.
const render_float_precision_rounders = [
	f64(0.5),
	0.05,
	0.005,
	0.0005,
	0.00005,
	0.000005,
	0.0000005,
	0.00000005,
	0.000000005,
	0.0000000005,
]

// zero_pad returns a string of `n` '0' characters (for fractional padding).
fn zero_pad(n int) string {
	mut sb := []u8{len: n, init: `0`}
	return sb.bytestr()
}

// format_float produces a formatted number as string based on the following
// user-specified criteria: thousands separator, decimal separator, decimal
// precision.
//
// Examples of format strings, given n = 12345.6789:
//   "#,###.##"   => "12,345.68"
//   "#,###."     => "12,346"
//   "#,###"      => "12345,679"
//   "# ###,##" => "12 345,68"
//   "" (default) => "12,345.67"
//
// The highest precision allowed is 9 digits after the decimal symbol.
pub fn format_float(format string, n f64) string {
	// Special cases:
	//   NaN = "NaN", +Inf = "Infinity", -Inf = "-Infinity"
	if math.is_nan(n) {
		return 'NaN'
	}
	if n > math.max_f64 {
		return 'Infinity'
	}
	if n < (0.0 - math.max_f64) {
		return '-Infinity'
	}

	// default format
	mut precision := 2
	mut decimal_str := '.'
	mut thousand_str := ','
	mut positive_str := ''
	negative_str := '-'

	if format != '' {
		f := format.runes()

		// If there is an explicit format directive, the defaults change:
		precision = 9
		thousand_str = ''

		// collect indices of meaningful formatting directives
		mut format_indx := []int{}
		for i, ch in f {
			if ch != `#` && ch != `0` {
				format_indx << i
			}
		}

		if format_indx.len > 0 {
			// Directive at index 0: must be a '+'.
			if format_indx[0] == 0 {
				if f[format_indx[0]] != `+` {
					panic('format_float(): invalid positive sign directive')
				}
				positive_str = '+'
				format_indx = format_indx[1..].clone()
			}

			// Two directives: first is the thousands separator, which must be
			// followed by exactly 3 digit-specifiers.
			if format_indx.len == 2 {
				if (format_indx[1] - format_indx[0]) != 4 {
					panic('format_float(): thousands separator directive must be followed by 3 digit-specifiers')
				}
				thousand_str = f[format_indx[0]].str()
				format_indx = format_indx[1..].clone()
			}

			// One directive: it is the decimal separator; the number of
			// digit-specifiers after it is the wanted precision.
			if format_indx.len == 1 {
				decimal_str = f[format_indx[0]].str()
				precision = f.len - format_indx[0] - 1
			}
		}
	}

	// generate sign part
	mut sign_str := ''
	mut val := n
	if n >= 0.000000001 {
		sign_str = positive_str
	} else if n <= -0.000000001 {
		sign_str = negative_str
		val = -n
	} else {
		sign_str = ''
		val = 0.0
	}

	// split number into integer and fractional parts
	intf, fracf := math.modf(val + render_float_precision_rounders[precision])

	// generate integer part string
	mut int_str := i64(intf).str()

	// add thousand separator if required
	if thousand_str != '' {
		mut i := int_str.len
		for i > 3 {
			i -= 3
			int_str = int_str[..i] + thousand_str + int_str[i..]
		}
	}

	// no fractional part, we can leave now
	if precision == 0 {
		return sign_str + int_str
	}

	// generate fractional part
	mut frac_str := i64(fracf * render_float_precision_multipliers[precision]).str()
	// may need padding
	if frac_str.len < precision {
		frac_str = zero_pad(precision - frac_str.len) + frac_str
	}

	return sign_str + int_str + decimal_str + frac_str
}

// format_integer produces a formatted number as string. See format_float.
pub fn format_integer(format string, n int) string {
	return format_float(format, f64(n))
}

module humanize

import math.big
import strconv

// insert_commas inserts a comma every three digits (counting from the right)
// into `digits`, a base-10 digit string. Used by comma and friends.
fn insert_commas(digits string) string {
	n := digits.len
	if n <= 3 {
		return digits
	}
	first := n % 3
	mut parts := []string{}
	if first > 0 {
		parts << digits[..first]
	}
	mut i := first
	for i < n {
		parts << digits[i..i + 3]
		i += 3
	}
	return parts.join(',')
}

// format_float_shortest approximates Go's `strconv.format_float(v, 'f', -1, 64)`
// (shortest round-trip in decimal notation). V has no direct equivalent, so we
// format with a generous fixed precision and strip trailing zeros. This is
// exact for every normal (non-subnormal) f64 value.
fn format_float_shortest(v f64) string {
	mut s := strconv.format_fl(v, strconv.BF_param{
		len1:     18
		positive: v >= 0.0
	})
	return strip_trailing_zeros(s)
}

// comma produces a string form of the given number in base 10 with commas
// after every three orders of magnitude.
//
// e.g. comma(834142) -> "834,142"
pub fn comma(v i64) string {
	// Shortcut for [0, 7]: Go's `v & ^0b111 == 0`.
	if v >= 0 && v <= 7 {
		return v.str()
	}
	// Min int64 can't be negated, so it has to be special-cased.
	if v == min_i64 {
		return '-9,223,372,036,854,775,808'
	}
	mut sign := ''
	mut n := v
	if n < 0 {
		sign = '-'
		n = -n
	}
	return sign + insert_commas(n.str())
}

// commaf produces a string form of the given number in base 10 with commas
// after every three orders of magnitude.
//
// e.g. commaf(834142.32) -> "834,142.32"
pub fn commaf(v f64) string {
	mut neg := false
	mut x := v
	if x < 0 {
		neg = true
		x = -x
	}
	parts := format_float_shortest(x).split('.')
	int_part := parts[0]
	// Build comma'd integer part with a trailing comma, then drop the comma.
	mut out := ''
	mut pos := 0
	if int_part.len % 3 != 0 {
		pos += int_part.len % 3
		out += int_part[..pos]
		out += ','
	}
	for pos < int_part.len {
		out += int_part[pos..pos + 3]
		out += ','
		pos += 3
	}
	// Drop the trailing comma added by the loop above.
	out = out[..out.len - 1]
	if parts.len > 1 {
		out += '.' + parts[1]
	}
	if neg {
		out = '-' + out
	}
	return out
}

// commaf_with_digits works like commaf but limits the resulting string to the
// given number of decimal places.
//
// e.g. commaf_with_digits(834142.32, 1) -> "834,142.3"
pub fn commaf_with_digits(f f64, decimals int) string {
	return strip_trailing_digits(commaf(f), decimals)
}

// big_comma produces a string form of the given big.Integer in base 10 with
// commas after every three orders of magnitude.
pub fn big_comma(bin big.Integer) string {
	mut b := bin
	mut sign := ''
	if b.signum < 0 {
		sign = '-'
		b = b.abs()
	}
	athousand := big.integer_from_int(1000)
	mut parts := []string{}
	mut mod := big.integer_from_int(0)
	for !(b < athousand) {
		b, mod = b.div_mod(athousand)
		mut ms := mod.str()
		match ms.len {
			2 { ms = '0' + ms }
			1 { ms = '00' + ms }
			else {}
		}

		parts << ms
	}
	parts << b.str()
	// parts was built least-significant first; reverse and join.
	mut reversed := []string{}
	for i := parts.len - 1; i >= 0; i-- {
		reversed << parts[i]
	}
	return sign + reversed.join(',')
}

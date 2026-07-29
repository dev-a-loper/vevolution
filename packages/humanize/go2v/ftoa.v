module humanize

import strconv

// strip_trailing_zeros removes trailing zeros (and a trailing '.') from a
// decimal string. Mirrors the unexported `stripTrailingZeros` in ftoa.go.
pub fn strip_trailing_zeros(s string) string {
	if !s.contains('.') {
		return s
	}
	mut offset := s.len - 1
	for offset > 0 {
		if s[offset] == `.` {
			offset--
			break
		}
		if s[offset] != `0` {
			break
		}
		offset--
	}
	return s[..offset + 1]
}

// strip_trailing_digits truncates the fractional part of `s` to `digits`
// places. Mirrors the unexported `stripTrailingDigits` in ftoa.go.
pub fn strip_trailing_digits(s string, digits int) string {
	i := s.index('.') or { return s }
	if digits <= 0 {
		return s[..i]
	}
	end := i + 1 + digits
	if end >= s.len {
		return s
	}
	return s[..end]
}

// format_float_f mirrors Go's `strconv.format_float(num, 'f', prec, 64)` for a
// fixed precision. `positive` must reflect the sign of `num` (V's formatter
// needs the sign passed out-of-band).
pub fn format_float_f(num f64, prec int) string {
	return strconv.format_fl(num, strconv.BF_param{
		len1:     prec
		positive: num >= 0.0
	})
}

// ftoa converts a float to a string with no trailing zeros.
//
// e.g. ftoa(200.02) -> "200.02"
pub fn ftoa(num f64) string {
	return strip_trailing_zeros(format_float_f(num, 6))
}

// ftoa_with_digits converts a float to a string but limits the resulting string
// to the given number of decimal places, and no trailing zeros.
pub fn ftoa_with_digits(num f64, digits int) string {
	return strip_trailing_zeros(strip_trailing_digits(format_float_f(num, 6), digits))
}

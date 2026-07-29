module humanize

import math

// si_prefix_table maps a power-of-10 exponent (multiple of 3) to its SI prefix
// symbol. Mirrors `siPrefixTable` in si.go.
const si_prefix_table = {
	-30: 'q' // quecto
	-27: 'r' // ronto
	-24: 'y' // yocto
	-21: 'z' // zepto
	-18: 'a' // atto
	-15: 'f' // femto
	-12: 'p' // pico
	-9:  'n' // nano
	-6:  'µ' // micro
	-3:  'm' // milli
	0:   ''
	3:   'k' // kilo
	6:   'M' // mega
	9:   'G' // giga
	12:  'T' // tera
	15:  'P' // peta
	18:  'E' // exa
	21:  'Z' // zetta
	24:  'Y' // yotta
	27:  'R' // ronna
	30:  'Q' // quetta
}

// rev_si_prefix_table maps an SI prefix symbol back to its power-of-10
// multiplier. Mirrors `revSIPrefixTable` (= revfmap(siPrefixTable)) in si.go.
const rev_si_prefix_table = {
	'q': 1e-30
	'r': 1e-27
	'y': 1e-24
	'z': 1e-21
	'a': 1e-18
	'f': 1e-15
	'p': 1e-12
	'n': 1e-9
	'µ': 1e-6
	'm': 1e-3
	'':  1.0
	'k': 1e3
	'M': 1e6
	'G': 1e9
	'T': 1e12
	'P': 1e15
	'E': 1e18
	'Z': 1e21
	'Y': 1e24
	'R': 1e27
	'Q': 1e30
}

// is_si_prefix_byte reports whether the ASCII byte c is a single-byte SI prefix
// symbol. (The micro sign `µ` is multi-byte and handled separately.)
fn is_si_prefix_byte(c u8) bool {
	return c in [`q`, `r`, `y`, `z`, `a`, `f`, `p`, `n`, `m`, `k`, `M`, `G`, `T`, `P`, `E`, `Z`,
		`Y`, `R`, `Q`]
}

// err_invalid is the error returned for malformed SI input.
const err_invalid = 'invalid input'

// compute_si finds the most appropriate SI prefix for the given number and
// returns the prefix along with the value adjusted to be within that prefix.
//
// e.g. compute_si(2.2345e-12) -> (2.2345, "p")
pub fn compute_si(input f64) (f64, string) {
	if input == 0 {
		return 0.0, ''
	}
	mag := math.abs(input)
	mut exponent := math.floor(logn(mag, 10))
	exponent = math.floor(exponent / 3) * 3

	mut value := mag / math.pow(10, exponent)

	// Handle special case where value is exactly 1000.0: return 1 M instead of
	// 1000 k.
	if value == 1000.0 {
		exponent += 3
		value = mag / math.pow(10, exponent)
	}

	value = math.copysign(value, input)

	prefix := si_prefix_table[int(exponent)] or { '' }
	return value, prefix
}

// si returns a string with default formatting.
//
// si uses ftoa to format the float value, removing trailing zeros.
//
// e.g. si(1000000, "B") -> "1 MB"
// e.g. si(2.2345e-12, "F") -> "2.2345 pF"
pub fn si(input f64, unit string) string {
	value, prefix := compute_si(input)
	return ftoa(value) + ' ' + prefix + unit
}

// si_with_digits works like SI but limits the resulting string to the given
// number of decimal places.
//
// e.g. si_with_digits(1000000, 0, "B") -> "1 MB"
// e.g. si_with_digits(2.2345e-12, 2, "F") -> "2.23 pF"
pub fn si_with_digits(input f64, decimals int, unit string) string {
	value, prefix := compute_si(input)
	return ftoa_with_digits(value, decimals) + ' ' + prefix + unit
}

// parse_si parses an SI string back into the number and unit.
//
// This is a hand translation of the Go regex
// `^([\-0-9.]+)\s?([prefixes]?)(.*)` (built dynamically in si.go's `init`),
// done manually because V's regex engine is not a drop-in for Go's `regexp`.
// The semantics are identical: a leading number, an optional single
// whitespace, an optional single SI prefix symbol, and the rest as the unit.
//
// e.g. parse_si("2.2345 pF") -> (2.2345e-12, "F", nil)
pub fn parse_si(input string) !(f64, string) {
	n := input.len
	if n == 0 {
		return error(err_invalid)
	}
	c0 := input[0]
	if !(c0 == `-` || (c0 >= `0` && c0 <= `9`) || c0 == `.`) {
		return error(err_invalid)
	}
	// consume leading number ([\-0-9.]+)
	mut pos := 1
	for pos < n {
		c := input[pos]
		if (c >= `0` && c <= `9`) || c == `-` || c == `.` {
			pos++
		} else {
			break
		}
	}
	num := input[..pos]
	// optional single whitespace (\s?)
	if pos < n && (input[pos] == ` ` || input[pos] == `\t`) {
		pos++
	}
	// optional single SI prefix symbol ([prefixes]?)
	mut prefix := ''
	if pos < n {
		// `µ` (U+00B5) is the only multi-byte prefix; UTF-8 bytes 0xC2 0xB5.
		if pos + 1 < n && input[pos] == 0xc2 && input[pos + 1] == 0xb5 {
			prefix = 'µ'
			pos += 2
		} else if is_si_prefix_byte(input[pos]) {
			prefix = input[pos..pos + 1]
			pos++
		}
	}
	unit := input[pos..]
	mag := rev_si_prefix_table[prefix] or { return error(err_invalid) }
	base := num.f64()
	return base * mag, unit
}

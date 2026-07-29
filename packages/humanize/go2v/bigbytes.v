module humanize

import math.big
import strconv

// ten is the big integer 10, used by humanate_big_bytes.
pub const ten = big.integer_from_int(10)

// big_iec_size_table and big_si_size_table are the big.Integer multipliers for
// parse_big_bytes. V has no module-init-time mutable globals comparable to Go's
// `var bigBytesSizeTable = ...`, and `big.Integer` products are not always
// const-evaluable, so the table is built on demand by parse_big_bytes.
fn build_big_bytes_size_table() map[string]big.Integer {
	iec := big.integer_from_int(1024)
	si_base := big.integer_from_int(1000)

	big_byte := big.integer_from_int(1)

	// IEC
	big_kibyte := iec
	big_mibyte := iec.pow(2)
	big_gibyte := iec.pow(3)
	big_tibyte := iec.pow(4)
	big_pibyte := iec.pow(5)
	big_eibyte := iec.pow(6)
	big_zibyte := iec.pow(7)
	big_yibyte := iec.pow(8)
	big_ribyte := iec.pow(9)
	big_qibyte := iec.pow(10)

	// SI
	big_kbyte := si_base
	big_mbyte := si_base.pow(2)
	big_gbyte := si_base.pow(3)
	big_tbyte := si_base.pow(4)
	big_pbyte := si_base.pow(5)
	big_ebyte := si_base.pow(6)
	big_zbyte := si_base.pow(7)
	big_ybyte := si_base.pow(8)
	big_rbyte := si_base.pow(9)
	big_qbyte := si_base.pow(10)

	mut t := map[string]big.Integer{}
	t['b'] = big_byte
	t['kib'] = big_kibyte
	t['kb'] = big_kbyte
	t['mib'] = big_mibyte
	t['mb'] = big_mbyte
	t['gib'] = big_gibyte
	t['gb'] = big_gbyte
	t['tib'] = big_tibyte
	t['tb'] = big_tbyte
	t['pib'] = big_pibyte
	t['pb'] = big_pbyte
	t['eib'] = big_eibyte
	t['eb'] = big_ebyte
	t['zib'] = big_zibyte
	t['zb'] = big_zbyte
	t['yib'] = big_yibyte
	t['yb'] = big_ybyte
	t['rib'] = big_ribyte
	t['rb'] = big_rbyte
	t['qib'] = big_qibyte
	t['qb'] = big_qbyte
	// Without suffix
	t[''] = big_byte
	t['ki'] = big_kibyte
	t['k'] = big_kbyte
	t['mi'] = big_mibyte
	t['m'] = big_mbyte
	t['gi'] = big_gibyte
	t['g'] = big_gbyte
	t['ti'] = big_tibyte
	t['t'] = big_tbyte
	t['pi'] = big_pibyte
	t['p'] = big_pbyte
	t['ei'] = big_eibyte
	t['e'] = big_ebyte
	t['z'] = big_zbyte
	t['zi'] = big_zibyte
	t['y'] = big_ybyte
	t['yi'] = big_yibyte
	t['r'] = big_rbyte
	t['ri'] = big_ribyte
	t['q'] = big_qbyte
	t['qi'] = big_qibyte
	return t
}

// humanate_big_bytes is the shared engine behind big_bytes/big_ibytes.
fn humanate_big_bytes(s big.Integer, base big.Integer, sizes []string) string {
	if s < ten {
		return s.str() + ' B'
	}
	val, mag := oomm(s, base, sizes.len - 1)
	suffix := sizes[mag]
	// Go: f := "%.0f %s"; if val < 10 { f = "%.1f %s" }.
	mut digits := 0
	if val < 10 {
		digits = 1
	}
	formatted := strconv.format_fl(val, strconv.BF_param{
		len1:     digits
		positive: true
	})
	return formatted + ' ' + suffix
}

// big_bytes produces a human-readable representation of an SI size.
//
// e.g. big_bytes(82854982) -> "83 MB"
pub fn big_bytes(s big.Integer) string {
	sizes := ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB', 'RB', 'QB']
	return humanate_big_bytes(s, big.integer_from_int(1000), sizes)
}

// big_ibytes produces a human-readable representation of an IEC size.
//
// e.g. big_ibytes(82854982) -> "79 MiB"
pub fn big_ibytes(s big.Integer) string {
	sizes := ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB', 'RiB', 'QiB']
	return humanate_big_bytes(s, big.integer_from_int(1024), sizes)
}

// is_all_digits reports whether s is non-empty and entirely ASCII digits.
fn is_all_digits(s string) bool {
	if s == '' {
		return false
	}
	for c in s {
		if c < `0` || c > `9` {
			return false
		}
	}
	return true
}

// parse_decimal_to_big parses a decimal string like "16.5" or "1005.03" into a
// (numerator, scale) pair representing numerator / 10^scale, with arbitrary
// precision. Used by parse_big_bytes to avoid f64 rounding (the Go original uses
// big.Rat for the same reason).
fn parse_decimal_to_big(num string) !(big.Integer, int) {
	if num == '' {
		return error('empty number')
	}
	mut neg := false
	mut s := num
	if s[0] == `-` {
		neg = true
		s = s[1..]
	} else if s[0] == `+` {
		s = s[1..]
	}
	parts := s.split('.')
	if parts.len > 2 {
		return error('multiple decimal points')
	}
	int_part := parts[0]
	frac_part := if parts.len > 1 { parts[1] } else { '' }
	if int_part.len > 0 && !is_all_digits(int_part) {
		return error('invalid integer part')
	}
	if frac_part.len > 0 && !is_all_digits(frac_part) {
		return error('invalid fractional part')
	}
	if int_part.len == 0 && frac_part.len == 0 {
		return error('no digits')
	}
	digits := int_part + frac_part
	scale := frac_part.len
	signed := if neg { '-' + digits } else { digits }
	numerator := big.integer_from_string(signed) or { return error('bad number: ${signed}') }
	return numerator, scale
}

// parse_big_bytes parses a string representation of bytes into the number of
// bytes it represents.
//
// e.g. parse_big_bytes("42 MB") -> 42000000, nil
// e.g. parse_big_bytes("42 mib") -> 44040192, nil
pub fn parse_big_bytes(s string) !big.Integer {
	mut last_digit := 0
	mut has_comma := false
	for c in s {
		if !((c >= `0` && c <= `9`) || c == `.` || c == `,`) {
			break
		}
		if c == `,` {
			has_comma = true
		}
		last_digit++
	}

	mut num := s[..last_digit]
	if num == '' {
		return error('strconv.ParseFloat: parsing "${s}": invalid syntax')
	}
	if has_comma {
		num = num.replace(',', '')
	}

	numerator, scale := parse_decimal_to_big(num)!

	extra := s[last_digit..].to_lower().trim_space()
	table := build_big_bytes_size_table()
	m := table[extra] or { return error('unhandled size name: ${extra}') }

	// result = (numerator * m) / 10^scale, truncated toward zero. Both operands
	// are non-negative here, so big `/` (floor) matches Go's big.Int.Div.
	product := numerator * m
	if scale == 0 {
		return product
	}
	divisor := big.integer_from_int(10).pow(u32(scale))
	return product / divisor
}

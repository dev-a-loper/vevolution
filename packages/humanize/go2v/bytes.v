module humanize

import math
import strconv

// IEC sizes (kibis of bits). Mirrors the `byte`..`eibyte` const block in
// bytes.go. Spelled out as explicit u64 values rather than `1 << (i*10)` so
// they are unambiguous compile-time constants of the right type.
pub const byte = u64(1)
pub const kibyte = u64(1024)
pub const mibyte = u64(1048576)
pub const gibyte = u64(1073741824)
pub const tibyte = u64(1099511627776)
pub const pibyte = u64(1125899906842624)
pub const eibyte = u64(1152921504606846976)

// SI sizes. Mirrors `ibyte`..`ebyte` in bytes.go.
pub const ibyte = u64(1)
pub const kbyte = u64(1000)
pub const mbyte = u64(1000000)
pub const gbyte = u64(1000000000)
pub const tbyte = u64(1000000000000)
pub const pbyte = u64(1000000000000000)
pub const ebyte = u64(1000000000000000000)

// bytes_size_table maps a lowercased suffix to its byte multiplier. Mirrors
// `bytesSizeTable` in bytes.go.
const bytes_size_table = {
	'b':   byte
	'kib': kibyte
	'kb':  kbyte
	'mib': mibyte
	'mb':  mbyte
	'gib': gibyte
	'gb':  gbyte
	'tib': tibyte
	'tb':  tbyte
	'pib': pibyte
	'pb':  pbyte
	'eib': eibyte
	'eb':  ebyte
	// Without suffix
	'':    byte
	'ki':  kibyte
	'k':   kbyte
	'mi':  mibyte
	'm':   mbyte
	'gi':  gibyte
	'g':   gbyte
	'ti':  tibyte
	't':   tbyte
	'pi':  pibyte
	'p':   pbyte
	'ei':  eibyte
	'e':   ebyte
}

// logn is log_b(n).
fn logn(n f64, b f64) f64 {
	return math.log(n) / math.log(b)
}

// count_digits returns the number of base-10 digits in n (0 if n == 0).
fn count_digits(n i64) int {
	mut digits := 0
	mut x := n
	for x != 0 {
		x /= 10
		digits++
	}
	return digits
}

// humanate_bytes is the shared engine behind bytes/ibytes/bytes_n/ibytes_n.
fn humanate_bytes(s u64, base f64, min_digits int, sizes []string) string {
	if s < 10 {
		return '${s} B'
	}
	e := math.floor(logn(f64(s), base))
	suffix := sizes[int(e)]
	rounding := math.pow10(min_digits - 1)
	val := math.floor(f64(s) / math.pow(base, e) * rounding + 0.5) / rounding
	mut digits := min_digits - count_digits(i64(val))
	if digits < 0 {
		digits = 0
	}
	// Equivalent to Go's `fmt.Sprintf("%.*f %s", digits, val, suffix)`.
	formatted := strconv.format_fl(val, strconv.BF_param{
		len1:     digits
		positive: true
	})
	return formatted + ' ' + suffix
}

// bytes produces a human-readable representation of an SI size.
//
// e.g. bytes(82854982) -> "83 MB"
pub fn bytes(s u64) string {
	sizes := ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB']
	return humanate_bytes(s, 1000, 2, sizes)
}

// bytes_n produces a human-readable representation of an SI size. `n` specifies
// the total number of digits to output (including the decimal part).
//
// e.g. bytes_n(82854982, 3) -> "82.9 MB"
pub fn bytes_n(s u64, n int) string {
	sizes := ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB']
	return humanate_bytes(s, 1000, n, sizes)
}

// ibytes produces a human-readable representation of an IEC size.
//
// e.g. ibytes(82854982) -> "79 MiB"
pub fn ibytes(s u64) string {
	sizes := ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB']
	return humanate_bytes(s, 1024, 2, sizes)
}

// ibytes_n produces a human-readable representation of an IEC size. `n` specifies
// the total number of digits to output (including the decimal part).
//
// e.g. ibytes_n(123456789, 6) -> "117.738 MiB"
pub fn ibytes_n(s u64, n int) string {
	sizes := ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB']
	return humanate_bytes(s, 1024, n, sizes)
}

// parse_bytes parses a string representation of bytes into the number of bytes
// it represents.
//
// e.g. parse_bytes("42 MB") -> 42000000, nil
// e.g. parse_bytes("42 mib") -> 44040192, nil
pub fn parse_bytes(s string) !u64 {
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
	if num.len == 0 {
		return error('strconv.ParseFloat: parsing "${s}": invalid syntax')
	}
	if has_comma {
		num = num.replace(',', '')
	}

	mut f := num.f64()

	extra := s[last_digit..].to_lower().trim_space()
	m := bytes_size_table[extra] or { return error('unhandled size name: ${extra}') }
	f *= f64(m)
	if f >= f64(max_u64) {
		return error('too large: ${s}')
	}
	return u64(f)
}

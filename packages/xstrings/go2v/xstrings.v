// V port of github.com/huandu/xstrings.
// Original: Copyright 2015 Huan Du. Licensed under the MIT license.
module xstrings

import encoding.utf8
import rand as rand_mod
import strings

// rune_error mirrors Go's utf8.RuneError (U+FFFD), the value returned by
// the decoder for an invalid UTF-8 byte.
const rune_error = rune(0xfffd)

// max_ascii mirrors Go's unicode.MaxASCII.
const max_ascii = rune(0x7f)

// buffer_max_init_grow_size caps the initial buffer reservation in alloc_buffer.
const buffer_max_init_grow_size = 2048

// --- rune / unicode helpers -----------------------------------------------

// is_punct mirrors Go's unicode.IsPunct (unicode category P).
fn is_punct(r rune) bool {
	if r < 0x80 {
		// ASCII P-category set per Go's unicode.IsPunct.
		match u8(r) {
			0x21, 0x22, 0x23, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2c, 0x2d, 0x2e, 0x2f, 0x3a,
			0x3b, 0x3f, 0x40, 0x5b, 0x5c, 0x5d, 0x5f, 0x7b, 0x7d {
				return true
			}
			else {
				return false
			}
		}
	}
	return utf8.is_rune_global_punct(r)
}

// to_upper_rune returns the uppercase equivalent of a rune.
fn to_upper_rune(r rune) rune {
	if r >= `A` && r <= `Z` {
		return r
	}
	if r >= `a` && r <= `z` {
		return r - 32
	}
	rs := r.str().to_upper().runes()
	if rs.len == 1 {
		return rs[0]
	}
	return r
}

// to_lower_rune returns the lowercase equivalent of a rune.
fn to_lower_rune(r rune) rune {
	if r >= `a` && r <= `z` {
		return r
	}
	if r >= `A` && r <= `Z` {
		return r + 32
	}
	rs := r.str().to_lower().runes()
	if rs.len == 1 {
		return rs[0]
	}
	return r
}

// is_upper_rune mirrors Go's unicode.IsUpper.
fn is_upper_rune(r rune) bool {
	if r >= `A` && r <= `Z` {
		return true
	}
	if r >= `a` && r <= `z` {
		return false
	}
	s := r.str()
	return s.to_upper() == s && s.to_lower() != s
}

// is_lower_rune mirrors Go's unicode.IsLower.
fn is_lower_rune(r rune) bool {
	if r >= `a` && r <= `z` {
		return true
	}
	if r >= `A` && r <= `Z` {
		return false
	}
	s := r.str()
	return s.to_lower() == s && s.to_upper() != s
}

// is_space_rune mirrors Go's unicode.IsSpace.
fn is_space_rune(r rune) bool {
	return utf8.is_space(r)
}

// is_number_rune mirrors Go's unicode.IsNumber.
fn is_number_rune(r rune) bool {
	return utf8.is_number(r)
}

// decode_rune_in_string mirrors Go's utf8.DecodeRuneInString.
// Returns (rune, byte_size); for an empty string returns (RuneError, 0),
// and for an invalid byte returns (RuneError, 1).
fn decode_rune_in_string(s string) (rune, int) {
	if s == '' {
		return rune_error, 0
	}
	b0 := s[0]
	if b0 < 0x80 {
		return rune(b0), 1
	}
	if b0 < 0xc2 {
		return rune_error, 1
	}
	ch_len := if b0 < 0xe0 {
		2
	} else if b0 < 0xf0 {
		3
	} else if b0 < 0xf5 {
		4
	} else {
		return rune_error, 1
	}
	if ch_len > s.len {
		return rune_error, 1
	}
	b1 := s[1]
	if (b1 & 0xc0) != 0x80 {
		return rune_error, 1
	}
	if ch_len == 2 {
		return (rune(b0 & 0x1f) << 6) | rune(b1 & 0x3f), 2
	}
	if b0 == 0xe0 && b1 < 0xa0 {
		return rune_error, 1
	}
	if b0 == 0xed && b1 >= 0xa0 {
		return rune_error, 1
	}
	b2 := s[2]
	if (b2 & 0xc0) != 0x80 {
		return rune_error, 1
	}
	if ch_len == 3 {
		return (rune(b0 & 0x0f) << 12) | (rune(b1 & 0x3f) << 6) | rune(b2 & 0x3f), 3
	}
	if b0 == 0xf0 && b1 < 0x90 {
		return rune_error, 1
	}
	if b0 == 0xf4 && b1 > 0x8f {
		return rune_error, 1
	}
	b3 := s[3]
	if (b3 & 0xc0) != 0x80 {
		return rune_error, 1
	}
	return (rune(b0 & 0x07) << 18) | (rune(b1 & 0x3f) << 12) | (rune(b2 & 0x3f) << 6) | rune(b3 & 0x3f), 4
}

// --- stringBuilder / allocBuffer ------------------------------------------

// alloc_buffer lazily initializes a builder and writes the already-consumed
// prefix (orig without the trailing `cur` suffix).
fn alloc_buffer(orig string, cur string) strings.Builder {
	mut output := strings.new_builder(0)
	mut max_size := orig.len * 4
	if max_size > buffer_max_init_grow_size {
		max_size = buffer_max_init_grow_size
	}
	output.ensure_cap(max_size)
	output.write_string(orig[..orig.len - cur.len])
	return output
}

// --- count.go -------------------------------------------------------------

// rune_len returns str's utf8 rune length (Go: Len).
pub fn rune_len(str string) int {
	return utf8.len(str)
}

// min_cjk_character mirrors Go's minCJKCharacter.
const min_cjk_character = rune(0x3400)

// word_count returns the number of words in a string.
pub fn word_count(str string) int {
	mut n := 0
	mut in_word := false
	mut s := str
	for s.len > 0 {
		r, size := decode_rune_in_string(s)
		if is_alphabet(r) {
			if !in_word {
				in_word = true
				n++
			}
		} else if in_word && (r == `'` || r == `-`) {
			// Still in word.
		} else {
			in_word = false
		}
		s = s[size..]
	}
	return n
}

// is_alphabet checks that r is a letter but not a CJK character.
fn is_alphabet(r rune) bool {
	if !utf8.is_letter(r) {
		return false
	}
	if r < min_cjk_character {
		return true
	}
	// Common CJK characters.
	if r >= rune(0x4e00) && r <= rune(0x9fcc) {
		return false
	}
	// Rare CJK characters.
	if r >= rune(0x3400) && r <= rune(0x4d85) {
		return false
	}
	// Rare and historic CJK characters.
	if r >= rune(0x20000) && r <= rune(0x2b81d) {
		return false
	}
	return true
}

// width returns the string width in a monotype font (Go: Width).
pub fn width(str string) int {
	mut n := 0
	mut s := str
	for s.len > 0 {
		r, size := decode_rune_in_string(s)
		n += rune_width(r)
		s = s[size..]
	}
	return n
}

// rune_width returns the character width in a monotype font (Go: RuneWidth).
pub fn rune_width(r rune) int {
	if r == rune_error || r < rune(0x20) {
		return 0
	}
	if r >= rune(0x20) && r < rune(0x2000) {
		return 1
	}
	if r >= rune(0x2000) && r < rune(0xff61) {
		return 2
	}
	if r >= rune(0xff61) && r < rune(0xffa0) {
		return 1
	}
	if r >= rune(0xffa0) {
		return 2
	}
	return 0
}

// --- convert.go -----------------------------------------------------------

// is_connector mirrors Go's isConnector.
fn is_connector(r rune) bool {
	return r == `-` || r == `_` || is_space_rune(r)
}

// to_camel_case converts words separated by space, underscore and hyphen to camel case.
pub fn to_camel_case(str string) string {
	return to_camel_case_impl(str, false)
}

// to_pascal_case converts words separated by space, underscore and hyphen to pascal case.
pub fn to_pascal_case(str string) string {
	return to_camel_case_impl(str, true)
}

fn to_camel_case_impl(str string, is_big bool) string {
	if str == '' {
		return ''
	}
	mut buf := strings.new_builder(0)
	mut is_first_rune_upper := false
	mut r0 := rune(0)
	mut r1 := rune(0)
	mut size := 0
	mut s := str

	for s.len > 0 {
		r0, size = decode_rune_in_string(s)
		s = s[size..]
		if !is_connector(r0) {
			is_first_rune_upper = is_upper_rune(r0)
			if is_big {
				r0 = to_upper_rune(r0)
			} else {
				r0 = to_lower_rune(r0)
			}
			break
		}
		buf.write_rune(r0)
	}

	if s.len == 0 {
		// A special case for a string contains only 1 rune.
		if size != 0 {
			buf.write_rune(r0)
		}
		return buf.str()
	}

	for s.len > 0 {
		r1 = r0
		r0, size = decode_rune_in_string(s)
		s = s[size..]
		if is_connector(r0) && is_connector(r1) {
			buf.write_rune(r1)
			continue
		}
		if is_connector(r1) {
			is_first_rune_upper = is_upper_rune(r0)
			r0 = to_upper_rune(r0)
		} else {
			if is_first_rune_upper {
				if is_upper_rune(r0) {
					r0 = to_lower_rune(r0)
				} else {
					is_first_rune_upper = false
				}
			}
			buf.write_rune(r1)
		}
	}

	if is_first_rune_upper && !is_big {
		r0 = to_lower_rune(r0)
	}

	buf.write_rune(r0)
	return buf.str()
}

// to_snake_case converts all upper case characters to snake case.
pub fn to_snake_case(str string) string {
	return camel_case_to_lower_case(str, `_`)
}

// to_kebab_case converts all upper case characters to kebab case.
pub fn to_kebab_case(str string) string {
	return camel_case_to_lower_case(str, `-`)
}

// word_type mirrors Go's wordType iota constants.
enum WordType {
	invalid    = 0 // invalidWord
	number     = 1 // numberWord
	upper_case = 2 // upperCaseWord
	alphabet   = 3 // alphabetWord
	connector  = 4 // connectorWord
	punct      = 5 // punctWord
	other      = 6 // otherWord
}

fn camel_case_to_lower_case(str string, connector rune) string {
	if str == '' {
		return ''
	}
	mut buf := strings.new_builder(0)
	mut res := next_word(str)
	mut wt := res.t
	mut word := res.word
	mut remaining := res.remaining

	for remaining.len > 0 {
		if wt != .connector {
			to_lower(mut buf, wt, word, connector)
		}
		prev := wt
		mut last := word
		res = next_word(remaining)
		wt = res.t
		word = res.word
		remaining = res.remaining

		match prev {
			.number {
				for wt == .alphabet || wt == .number {
					to_lower(mut buf, wt, word, connector)
					res = next_word(remaining)
					wt = res.t
					word = res.word
					remaining = res.remaining
				}
				if wt != .invalid && wt != .punct && wt != .connector {
					buf.write_rune(connector)
				}
			}
			.connector {
				to_lower(mut buf, prev, last, connector)
			}
			.punct {
				// nothing.
			}
			else {
				if wt != .number {
					if wt != .connector && wt != .punct {
						buf.write_rune(connector)
					}
					continue
				}
				if remaining.len == 0 {
					continue
				}
				last = word
				res = next_word(remaining)
				wt = res.t
				word = res.word
				remaining = res.remaining
				// Consider number as a part of previous word, e.g. "Bld4Floor".
				if wt != .alphabet {
					to_lower(mut buf, .number, last, connector)
					if wt != .connector && wt != .punct {
						buf.write_rune(connector)
					}
					continue
				}
				// Lower case letters following a number: add connector before the number.
				// e.g. "HTTP2xx" => "http_2xx".
				buf.write_rune(connector)
				to_lower(mut buf, .number, last, connector)
				for wt == .alphabet || wt == .number {
					to_lower(mut buf, wt, word, connector)
					res = next_word(remaining)
					wt = res.t
					word = res.word
					remaining = res.remaining
				}
				if wt != .invalid && wt != .connector && wt != .punct {
					buf.write_rune(connector)
				}
			}
		}
	}

	to_lower(mut buf, wt, word, connector)
	return buf.str()
}

struct WordResult {
	t         WordType
	word      string
	remaining string
}

// next_word mirrors Go's nextWord.
fn next_word(str_arg string) WordResult {
	if str_arg == '' {
		return WordResult{.invalid, '', ''}
	}
	mut offset := 0
	remaining := str_arg
	r, size := next_valid_rune(remaining, rune_error)
	offset += size
	if r == rune_error {
		return WordResult{.invalid, str_arg[..offset], str_arg[offset..]}
	}
	mut wt := WordType.invalid
	mut rem := remaining
	if is_connector(r) {
		wt = .connector
		rem = remaining[size..]
		for rem.len > 0 {
			r2, size2 := next_valid_rune(rem, r)
			if !is_connector(r2) {
				break
			}
			offset += size2
			rem = rem[size2..]
		}
	} else if is_punct(r) {
		wt = .punct
		rem = remaining[size..]
		for rem.len > 0 {
			r2, size2 := next_valid_rune(rem, r)
			if !is_punct(r2) {
				break
			}
			offset += size2
			rem = rem[size2..]
		}
	} else if is_upper_rune(r) {
		wt = .upper_case
		rem = remaining[size..]
		if rem.len == 0 {
			return WordResult{wt, str_arg[..offset], str_arg[offset..]}
		}
		r2, size2 := next_valid_rune(rem, r)
		if is_upper_rune(r2) {
			mut prev_size := size2
			offset += size2
			rem = rem[size2..]
			mut r3 := r2
			mut size3 := 0
			for rem.len > 0 {
				r3, size3 = next_valid_rune(rem, r2)
				if !is_upper_rune(r3) {
					break
				}
				prev_size = size3
				offset += size3
				rem = rem[size3..]
			}
			// Case like "HTTPStatus" should split into "HTTP" and "Status".
			if rem.len > 0 && is_alphabet(r3) {
				offset -= prev_size
				rem = str_arg[offset..]
			}
		} else if is_alphabet(r2) {
			offset += size2
			rem = rem[size2..]
			for rem.len > 0 {
				r3, size3 := next_valid_rune(rem, r2)
				if !is_alphabet(r3) || is_upper_rune(r3) {
					break
				}
				offset += size3
				rem = rem[size3..]
			}
		}
		wt = .upper_case
	} else if is_alphabet(r) {
		wt = .alphabet
		rem = remaining[size..]
		for rem.len > 0 {
			r2, size2 := next_valid_rune(rem, r)
			if !is_alphabet(r2) || is_upper_rune(r2) {
				break
			}
			offset += size2
			rem = rem[size2..]
		}
	} else if is_number_rune(r) {
		wt = .number
		rem = remaining[size..]
		for rem.len > 0 {
			r2, size2 := next_valid_rune(rem, r)
			if !is_number_rune(r2) {
				break
			}
			offset += size2
			rem = rem[size2..]
		}
	} else {
		wt = .other
		rem = remaining[size..]
		for rem.len > 0 {
			r2, size2 := next_valid_rune(rem, r)
			if size2 == 0 || is_connector(r2) || is_alphabet(r2) || is_number_rune(r2)
				|| is_punct(r2) {
				break
			}
			offset += size2
			rem = rem[size2..]
		}
	}
	return WordResult{wt, str_arg[..offset], str_arg[offset..]}
}

// next_valid_rune mirrors Go's nextValidRune. It skips invalid utf8 runes.
fn next_valid_rune(str_arg string, prev rune) (rune, int) {
	mut s := str_arg
	mut p := prev
	mut total := 0
	for s.len > 0 {
		r, sz := decode_rune_in_string(s)
		total += sz
		if r != rune_error {
			return r, total
		}
		s = s[sz..]
	}
	return p, total
}

// to_lower mirrors Go's toLower helper.
fn to_lower(mut buf strings.Builder, wt WordType, str_arg string, connector rune) {
	mut s := str_arg
	buf.ensure_cap(buf.len + s.len)
	if wt != .upper_case && wt != .connector {
		buf.write_string(s)
		return
	}
	for s.len > 0 {
		r, size := decode_rune_in_string(s)
		s = s[size..]
		if is_connector(r) {
			buf.write_rune(connector)
		} else if is_upper_rune(r) {
			buf.write_rune(to_lower_rune(r))
		} else {
			buf.write_rune(r)
		}
	}
}

// swap_case swaps character case from upper to lower or lower to upper.
pub fn swap_case(str string) string {
	mut buf := strings.new_builder(0)
	mut s := str
	for s.len > 0 {
		r, size := decode_rune_in_string(s)
		if is_upper_rune(r) {
			buf.write_rune(to_lower_rune(r))
		} else if is_lower_rune(r) {
			buf.write_rune(to_upper_rune(r))
		} else {
			buf.write_rune(r)
		}
		s = s[size..]
	}
	return buf.str()
}

// first_rune_to_upper converts the first rune to upper case if necessary.
pub fn first_rune_to_upper(str string) string {
	if str == '' {
		return str
	}
	r, size := decode_rune_in_string(str)
	if !is_lower_rune(r) {
		return str
	}
	mut buf := strings.new_builder(0)
	buf.write_rune(to_upper_rune(r))
	buf.write_string(str[size..])
	return buf.str()
}

// first_rune_to_lower converts the first rune to lower case if necessary.
pub fn first_rune_to_lower(str string) string {
	if str == '' {
		return str
	}
	r, size := decode_rune_in_string(str)
	if !is_upper_rune(r) {
		return str
	}
	mut buf := strings.new_builder(0)
	buf.write_rune(to_lower_rune(r))
	buf.write_string(str[size..])
	return buf.str()
}

// shuffle randomizes runes in a string and returns the result.
pub fn shuffle(str string) string {
	if str == '' {
		return str
	}
	mut runes := str.runes()
	for i := runes.len - 1; i > 0; i-- {
		index := rand_mod.intn(i + 1) or { 0 }
		if i != index {
			tmp := runes[i]
			runes[i] = runes[index]
			runes[index] = tmp
		}
	}
	return runes.map(it.str()).join('')
}

// rand_source mirrors the subset of math/rand.Source used by shuffle_source.
interface RandSource {
mut:
	int63() i64
}

// shuffle_source randomizes runes in a string with a given random source.
pub fn shuffle_source(str string, mut src RandSource) string {
	if str == '' {
		return str
	}
	mut runes := str.runes()
	for i := runes.len - 1; i > 0; i-- {
		index := rand_intn(mut src, i + 1)
		if i != index {
			tmp := runes[i]
			runes[i] = runes[index]
			runes[index] = tmp
		}
	}
	return runes.map(it.str()).join('')
}

// rand_int31 mirrors Go's (*Rand).Int31 built on a Source.
fn rand_int31(mut src RandSource) i32 {
	return i32(src.int63() >> 32)
}

// rand_int31n mirrors Go's (*Rand).Int31n built on a Source.
fn rand_int31n(mut src RandSource, n i32) i32 {
	if n <= 0 {
		panic('invalid argument to int31n')
	}
	if n & (n - 1) == 0 {
		return rand_int31(mut src) & (n - 1)
	}
	maxv := i32(u32(0x7fffffff) - (u32(0x80000000) % u32(n)))
	mut v := rand_int31(mut src)
	for v > maxv {
		v = rand_int31(mut src)
	}
	return v % n
}

// rand_intn mirrors Go's (*Rand).Intn built on a Source.
fn rand_intn(mut src RandSource, n int) int {
	if n <= 0 {
		panic('invalid argument to intn')
	}
	if n <= 1 << 31 - 1 {
		return int(rand_int31n(mut src, i32(n)))
	}
	return int(i64(src.int63() % i64(n)))
}

// successor returns the successor to a string.
pub fn successor(str string) string {
	if str == '' {
		return str
	}
	mut carry := ` `
	mut runes := str.runes()
	l := runes.len
	mut last_alphanumeric := l
	mut i := l - 1
	for i = l - 1; i >= 0; i-- {
		r := runes[i]
		if (r >= `a` && r <= `y`) || (r >= `A` && r <= `Y`) || (r >= `0` && r <= `8`) {
			runes[i] = r + 1
			carry = ` `
			last_alphanumeric = i
			break
		}
		match r {
			`z` {
				runes[i] = `a`
				carry = `a`
				last_alphanumeric = i
			}
			`Z` {
				runes[i] = `A`
				carry = `A`
				last_alphanumeric = i
			}
			`9` {
				runes[i] = `0`
				carry = `0`
				last_alphanumeric = i
			}
			else {}
		}
	}

	// Needs to add one character for carry.
	if i < 0 && carry != ` ` {
		mut buf := strings.new_builder(0)
		buf.ensure_cap(l + 4)
		if last_alphanumeric != 0 {
			buf.write_string(runes_to_string(runes[..last_alphanumeric]))
		}
		buf.write_rune(carry)
		for r in runes[last_alphanumeric..] {
			buf.write_rune(r)
		}
		return buf.str()
	}

	// No alphanumeric character. Simply increase last rune's value.
	if last_alphanumeric == l {
		runes[l - 1] = runes[l - 1] + 1
	}
	return runes_to_string(runes)
}

// runes_to_string concatenates a slice of runes into a UTF-8 string.
fn runes_to_string(runes []rune) string {
	return runes.map(it.str()).join('')
}

// --- manipulate.go --------------------------------------------------------

// reverse reverses a utf8 encoded string by rune order.
pub fn reverse(str string) string {
	if str == '' {
		return ''
	}
	mut tail := str.len
	mut buf := []u8{len: str.len}
	mut s := str
	for s.len > 0 {
		_, size := decode_rune_in_string(s)
		tail -= size
		for i in 0 .. size {
			buf[tail + i] = s[i]
		}
		s = s[size..]
	}
	return buf.bytestr()
}

// slice_impl is the result-returning core of slice. Returns an error on out of
// range instead of panicking, so tests can exercise the out-of-range paths.
fn slice_impl(str string, start int, end int) !string {
	mut size := 0
	mut start_pos := 0
	mut end_pos := 0
	origin := str
	if start < 0 || end > str.len || (end >= 0 && start > end) {
		return error('out of range')
	}
	mut e := end
	if e >= 0 {
		e -= start
	}
	mut st := start
	mut s := str
	for st > 0 && s.len > 0 {
		_, size = decode_rune_in_string(s)
		st--
		start_pos += size
		s = s[size..]
	}
	if e < 0 {
		return origin[start_pos..]
	}
	end_pos = start_pos
	for e > 0 && s.len > 0 {
		_, size = decode_rune_in_string(s)
		e--
		end_pos += size
		s = s[size..]
	}
	if s.len == 0 && (st > 0 || e > 0) {
		return error('out of range')
	}
	return origin[start_pos..end_pos]
}

// slice slices a string by rune index. Panics on out of range (Go: Slice).
pub fn slice(str string, start int, end int) string {
	return slice_impl(str, start, end) or { panic(err.msg()) }
}

// insert_safe is the result-returning core of insert_str.
fn insert_safe(dst string, src string, index int) !string {
	head := slice_impl(dst, 0, index)!
	tail := slice_impl(dst, index, -1)!
	return head + src + tail
}

// insert_str inserts src into dst at the given rune index (Go: Insert).
pub fn insert_str(dst string, src string, index int) string {
	return insert_safe(dst, src, index) or { panic(err.msg()) }
}

// partition splits str by sep into head, match and tail.
pub fn partition(str string, sep string) (string, string, string) {
	index := str.index(sep) or { return str, '', '' }
	head := str[..index]
	m := str[index..index + sep.len]
	tail := str[index + sep.len..]
	return head, m, tail
}

// last_partition splits str by the last instance of sep.
pub fn last_partition(str string, sep string) (string, string, string) {
	index := str.last_index(sep) or { return '', '', str }
	head := str[..index]
	m := str[index..index + sep.len]
	tail := str[index + sep.len..]
	return head, m, tail
}

// scrub scrubs invalid utf8 bytes in str with repl. Adjacent invalid bytes are
// replaced only once.
pub fn scrub(str string, repl string) string {
	mut output := strings.new_builder(0)
	mut has_output := false
	mut r := rune(0)
	mut size := 0
	mut pos := 0
	mut has_error := false
	mut origin := str
	mut s := str
	for s.len > 0 {
		r, size = decode_rune_in_string(s)
		if r == rune_error {
			if !has_error {
				if !has_output {
					output = strings.new_builder(0)
					has_output = true
				}
				output.write_string(origin[..pos])
				has_error = true
			}
		} else if has_error {
			has_error = false
			output.write_string(repl)
			origin = origin[pos..]
			pos = 0
		}
		pos += size
		s = s[size..]
	}
	if has_output {
		output.write_string(origin)
		return output.str()
	}
	return origin
}

// word_split splits a string into words. Returns an empty array if no word.
pub fn word_split(str string) []string {
	mut word := ''
	mut words := []string{}
	mut r := rune(0)
	mut size := 0
	mut pos := 0
	mut in_word := false
	mut s := str
	for s.len > 0 {
		r, size = decode_rune_in_string(s)
		if is_alphabet(r) {
			if !in_word {
				in_word = true
				word = s
				pos = 0
			}
		} else if in_word && (r == `'` || r == `-`) {
			// Still in word.
		} else {
			if in_word {
				in_word = false
				words << word[..pos]
			}
		}
		pos += size
		s = s[size..]
	}
	if in_word {
		words << word[..pos]
	}
	return words
}

// --- format.go ------------------------------------------------------------

// expand_tabs_impl is the result-returning core of expand_tabs.
fn expand_tabs_impl(str string, tab_size int) !string {
	if tab_size <= 0 {
		return error('tab size must be positive')
	}
	mut r := rune(0)
	mut size := 0
	mut column := 0
	mut expand := 0
	mut has_output := false
	mut output := strings.new_builder(0)
	orig := str
	mut s := str
	for s.len > 0 {
		r, size = decode_rune_in_string(s)
		if r == `\t` {
			expand = tab_size - column % tab_size
			if !has_output {
				output = alloc_buffer(orig, s)
				has_output = true
			}
			for _ in 0 .. expand {
				output.write_rune(` `)
			}
			column += expand
		} else {
			if r == `\n` {
				column = 0
			} else {
				column += rune_width(r)
			}
			if has_output {
				output.write_rune(r)
			}
		}
		s = s[size..]
	}
	if !has_output {
		return orig
	}
	return output.str()
}

// expand_tabs expands tabs to spaces. Panics if tab_size <= 0 (Go: ExpandTabs).
pub fn expand_tabs(str string, tab_size int) string {
	return expand_tabs_impl(str, tab_size) or { panic(err.msg()) }
}

// write_pad_string writes `remains` width of padding using `pad` rune string.
fn write_pad_string(mut output strings.Builder, pad string, pad_len int, remains int) {
	mut p := pad
	repeats := remains / pad_len
	for _ in 0 .. repeats {
		output.write_string(p)
	}
	rem := remains % pad_len
	if rem != 0 {
		for _ in 0 .. rem {
			r, size := decode_rune_in_string(p)
			output.write_rune(r)
			p = p[size..]
		}
	}
}

// left_justify pads str on the right.
pub fn left_justify(str string, length int, pad string) string {
	l := rune_len(str)
	if l >= length || pad == '' {
		return str
	}
	remains := length - l
	pad_len := rune_len(pad)
	mut output := strings.new_builder(0)
	output.ensure_cap(str.len + (remains / pad_len + 1) * pad.len)
	output.write_string(str)
	write_pad_string(mut output, pad, pad_len, remains)
	return output.str()
}

// right_justify pads str on the left.
pub fn right_justify(str string, length int, pad string) string {
	l := rune_len(str)
	if l >= length || pad == '' {
		return str
	}
	remains := length - l
	pad_len := rune_len(pad)
	mut output := strings.new_builder(0)
	output.ensure_cap(str.len + (remains / pad_len + 1) * pad.len)
	write_pad_string(mut output, pad, pad_len, remains)
	output.write_string(str)
	return output.str()
}

// center pads str on both sides.
pub fn center(str string, length int, pad string) string {
	l := rune_len(str)
	if l >= length || pad == '' {
		return str
	}
	remains := length - l
	pad_len := rune_len(pad)
	mut output := strings.new_builder(0)
	output.ensure_cap(str.len + (remains / pad_len + 1) * pad.len)
	write_pad_string(mut output, pad, pad_len, remains / 2)
	output.write_string(str)
	write_pad_string(mut output, pad, pad_len, (remains + 1) / 2)
	return output.str()
}

// --- translate.go ---------------------------------------------------------

struct RuneRangeMap {
mut:
	from_lo rune
	from_hi rune
	to_lo   rune
	to_hi   rune
}

struct Translator {
mut:
	quick_dict  [128]rune
	has_quick   bool
	rune_map    map[rune]rune
	ranges      []RuneRangeMap
	mapped_rune i32
	reverted    bool
	has_pattern bool
}

// new_translator creates a new Translator through a from/to pattern pair.
pub fn new_translator(from_arg string, to_arg string) Translator {
	mut tr := Translator{
		mapped_rune: -1
	}
	if from_arg == '' {
		return tr
	}
	reverted := from_arg[0] == `^`
	deletion := to_arg == ''
	mut from := from_arg
	if reverted {
		from = from[1..]
	}
	mut ts := ToState{
		to: to_arg
	}
	if deletion {
		ts.to_start = rune_error
		ts.to_end = rune_error
	} else if reverted {
		// If from pattern is reverted, only the last rune in to is used.
		mut last := rune_error
		mut t := to_arg
		for t.len > 0 {
			r, size := decode_rune_in_string(t)
			last = r
			_ = size
			t = t[size..]
		}
		ts.to_start = last
		ts.to_end = rune_error
	} else {
		rem, st, e, rs := next_rune_range(to_arg, rune_error)
		ts.to = rem
		ts.to_start = st
		ts.to_end = e
		ts.to_range_step = rs
	}

	mut from_start := rune(0)
	mut from_end := rune_error
	mut from_range_step := rune(0)
	mut single_runes := []rune{}
	from_end = rune_error

	for from.len > 0 {
		rem, fs, fe, frs := next_rune_range(from, from_end)
		from = rem
		from_start = fs
		from_end = fe
		from_range_step = frs

		// fromStart is a single character. Map it with a rune in the to pattern.
		if from_range_step == 0 {
			tr.add_rune(from_start, ts.to_start, mut single_runes)
			ts.update()
			continue
		}

		for ts.to_end != rune_error && from_start != from_end {
			// If mapped rune is a single character instead of a range, shift the
			// first rune in the range.
			if ts.to_range_step == 0 {
				tr.add_rune(from_start, ts.to_start, mut single_runes)
				ts.update()
				from_start += from_range_step
				continue
			}

			from_range_size := (from_end - from_start) * from_range_step
			to_range_size := (ts.to_end - ts.to_start) * ts.to_range_step

			// Not enough runes in the to pattern. Need to read more.
			if from_range_size > to_range_size {
				fs2, ts2 := tr.add_rune_range(from_start, from_start +
					to_range_size * from_range_step, ts.to_start, ts.to_end, mut single_runes)
				from_start = fs2
				ts.to_start = ts2
				from_start += from_range_step
				ts.update()

				// Edge case: If fromRangeSize == toRangeSize + 1, the last fromStart
				// value needs be considered as a single rune.
				if from_start == from_end {
					tr.add_rune(from_start, ts.to_start, mut single_runes)
					ts.update()
				}
				continue
			}

			fs2, ts2 := tr.add_rune_range(from_start, from_end, ts.to_start, ts.to_start +
				from_range_size * ts.to_range_step, mut single_runes)
			from_start = fs2
			ts.to_start = ts2
			ts.update()
			break
		}

		if from_start == from_end {
			from_end = rune_error
			continue
		}

		_, ts2 := tr.add_rune_range(from_start, from_end, ts.to_start, ts.to_start, mut
			single_runes)
		ts.to_start = ts2
		from_end = rune_error
	}

	if from_end != rune_error {
		tr.add_rune(from_end, ts.to_start, mut single_runes)
	}

	tr.reverted = reverted
	tr.mapped_rune = -1
	tr.has_pattern = true

	// Translate RuneError only if in deletion or reverted mode.
	if deletion || reverted {
		tr.mapped_rune = i32(ts.to_start)
	}

	return tr
}

// ToState carries the mutable "to" pattern position used by new_translator.
struct ToState {
mut:
	to            string
	to_start      rune
	to_end        rune
	to_range_step rune
}

fn (mut ts ToState) update() {
	if ts.to_end == rune_error {
		return
	}
	if ts.to_range_step == 0 {
		rem, st, e, rs := next_rune_range(ts.to, ts.to_end)
		ts.to = rem
		ts.to_start = st
		ts.to_end = e
		ts.to_range_step = rs
		return
	}
	if ts.to_start != ts.to_end {
		ts.to_start += ts.to_range_step
		return
	}
	if ts.to == '' {
		ts.to_end = rune_error
		return
	}
	rem, st, e, rs := next_rune_range(ts.to, rune_error)
	ts.to = rem
	ts.to_start = st
	ts.to_end = e
	ts.to_range_step = rs
}

fn (mut tr Translator) add_rune(from rune, to rune, mut single_runes []rune) {
	if from <= max_ascii {
		tr.quick_dict[int(from)] = to
		tr.has_quick = true
	} else {
		tr.rune_map[from] = to
	}
	single_runes << from
}

fn (mut tr Translator) add_rune_range(from_lo rune, from_hi rune, to_lo rune, to_hi rune, mut single_runes []rune) (rune, rune) {
	mut rrm := RuneRangeMap{}
	if from_lo < from_hi {
		rrm.from_lo = from_lo
		rrm.from_hi = from_hi
		rrm.to_lo = to_lo
		rrm.to_hi = to_hi
	} else {
		rrm.from_lo = from_hi
		rrm.from_hi = from_lo
		rrm.to_lo = to_hi
		rrm.to_hi = to_lo
	}
	// Clear any single rune conflicting with this range.
	for r in single_runes {
		if rrm.from_lo <= r && r <= rrm.from_hi {
			if r <= max_ascii {
				tr.quick_dict[int(r)] = 0
			} else {
				tr.rune_map.delete(r)
			}
		}
	}
	tr.ranges << rrm
	return from_hi, to_hi
}

// next_rune_range mirrors Go's nextRuneRange.
fn next_rune_range(str_arg string, last_in rune) (string, rune, rune, rune) {
	mut remaining := str_arg
	mut last := last_in
	mut start := rune(0)
	mut end := rune(0)
	mut range_step := rune(0)
	mut escaping := false
	mut is_range := false
	for remaining.len > 0 {
		r, size := decode_rune_in_string(remaining)
		remaining = remaining[size..]
		if !escaping {
			if r == `\\` {
				escaping = true
				continue
			}
			if r == `-` {
				// Ignore dash at beginning of string.
				if last == rune_error {
					continue
				}
				start = last
				is_range = true
				continue
			}
		}
		escaping = false
		if last != rune_error {
			// A range whose start and end are the same is a normal character.
			if is_range && last == r {
				is_range = false
				continue
			}
			start = last
			end = r
			if is_range {
				if start < end {
					range_step = 1
				} else {
					range_step = -1
				}
			}
			return remaining, start, end, range_step
		}
		last = r
	}
	start = last
	end = rune_error
	return remaining, start, end, range_step
}

fn (tr &Translator) translate_rune(r rune) (rune, bool) {
	mut result := rune(0)
	mut translated := false
	mut hit := false
	if tr.has_quick && r <= max_ascii {
		result = tr.quick_dict[int(r)]
		if result != 0 {
			translated = true
			if tr.mapped_rune >= 0 {
				result = rune(tr.mapped_rune)
			}
			hit = true
		}
	}
	if !hit {
		if r in tr.rune_map {
			result = tr.rune_map[r]
			translated = true
			if tr.mapped_rune >= 0 {
				result = rune(tr.mapped_rune)
			}
			hit = true
		}
	}
	if !hit {
		mut i := tr.ranges.len - 1
		for i >= 0 {
			rrm := tr.ranges[i]
			if rrm.from_lo <= r && r <= rrm.from_hi {
				translated = true
				if tr.mapped_rune >= 0 {
					result = rune(tr.mapped_rune)
				} else if rrm.to_lo < rrm.to_hi {
					result = rrm.to_lo + r - rrm.from_lo
				} else if rrm.to_lo > rrm.to_hi {
					result = rrm.to_lo - r + rrm.from_lo
				} else {
					result = rrm.to_lo
				}
				break
			}
			i--
		}
	}
	if tr.reverted {
		if !translated {
			result = rune(tr.mapped_rune)
		}
		translated = !translated
	}
	if !translated {
		result = r
	}
	return result, translated
}

fn (tr &Translator) translate(str string) string {
	if !tr.has_pattern || str == '' {
		return str
	}
	orig := str
	mut output := strings.new_builder(0)
	mut has_output := false
	mut s := str
	for s.len > 0 {
		r, size := decode_rune_in_string(s)
		nr, need_tr := tr.translate_rune(r)
		if need_tr && !has_output {
			output = alloc_buffer(orig, s)
			has_output = true
		}
		if nr != rune_error && has_output {
			output.write_rune(nr)
		}
		s = s[size..]
	}
	if !has_output {
		return orig
	}
	return output.str()
}

// has_pattern_fn returns true if the Translator has at least one pattern.
pub fn (tr &Translator) has_pattern_fn() bool {
	return tr.has_pattern
}

// translate_str translates str with a from/to pattern pair (Go: Translate).
pub fn translate_str(str string, from string, to string) string {
	mut tr := new_translator(from, to)
	return tr.translate(str)
}

// delete_runes deletes runes in str matching the pattern (Go: Delete).
pub fn delete_runes(str string, pattern string) string {
	mut tr := new_translator(pattern, '')
	return tr.translate(str)
}

// count_match counts how many runes in str match the pattern (Go: Count).
pub fn count_match(str string, pattern string) int {
	if pattern == '' || str == '' {
		return 0
	}
	mut tr := new_translator(pattern, '')
	mut cnt := 0
	mut s := str
	for s.len > 0 {
		r, size := decode_rune_in_string(s)
		s = s[size..]
		_, matched := tr.translate_rune(r)
		if matched {
			cnt++
		}
	}
	return cnt
}

// squeeze deletes adjacent repeated runes in str (Go: Squeeze).
pub fn squeeze(str string, pattern string) string {
	mut has_tr := false
	mut tr := new_translator('', '')
	if pattern != '' {
		tr = new_translator(pattern, '')
		has_tr = true
	}
	orig := str
	mut last := rune(-1)
	mut output := strings.new_builder(0)
	mut has_output := false
	mut skip_squeeze := false
	mut s := str
	for s.len > 0 {
		r, size := decode_rune_in_string(s)
		if last == r && !skip_squeeze {
			if has_tr {
				_, matched := tr.translate_rune(r)
				if !matched {
					skip_squeeze = true
				}
			}
			if !has_output {
				output = alloc_buffer(orig, s)
				has_output = true
			}
			if skip_squeeze {
				output.write_rune(r)
			}
		} else {
			if has_output {
				output.write_rune(r)
			}
			last = r
			skip_squeeze = false
		}
		s = s[size..]
	}
	if !has_output {
		return orig
	}
	return output.str()
}

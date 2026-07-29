module glob

// Port of gobwas/glob/util/strings -- byte-index helpers for matching.
// All return values are BYTE indices into the source string (matching Go semantics).

// strings_index_any_runes returns the byte index of the first instance of any
// rune from rs in s, or -1.
fn strings_index_any_runes(s string, rs []rune) int {
	mut bpos := 0
	for r in s.runes() {
		if runes_index_rune(rs, r) != -1 {
			return bpos
		}
		bpos += r.bytes().len
	}
	return -1
}

// strings_last_index_any_runes returns the byte index of the last instance of
// any rune from rs in s, or -1.
fn strings_last_index_any_runes(s string, rs []rune) int {
	mut last := -1
	mut bpos := 0
	for r in s.runes() {
		if runes_index_rune(rs, r) != -1 {
			last = bpos
		}
		bpos += r.bytes().len
	}
	return last
}

// runes_to_string concatenates a list of runes into a UTF-8 string. (Go: string([]rune).)
fn runes_to_string(rs []rune) string {
	mut b := []u8{cap: rs.len}
	for r in rs {
		b << r.bytes()
	}
	return b.bytestr()
}

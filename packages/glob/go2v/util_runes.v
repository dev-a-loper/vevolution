module glob

// Port of gobwas/glob/util/runes -- rune-slice helpers used by the compiler
// and matchers. Operates on []rune (V `[]rune`).

// runes_index returns the index of the first instance of needle in s, or -1.
fn runes_index(s []rune, needle []rune) int {
	ls, ln := s.len, needle.len
	if ln == 0 {
		return 0
	}
	if ln == 1 {
		return runes_index_rune(s, needle[0])
	}
	if ln == ls {
		if runes_equal(s, needle) {
			return 0
		}
		return -1
	}
	if ln > ls {
		return -1
	}
	mut i := 0
	for i < ls && ls - i >= ln {
		mut matched := true
		mut y := 0
		for y < ln {
			if s[i + y] != needle[y] {
				matched = false
				break
			}
			y++
		}
		if matched {
			return i
		}
		i++
	}
	return -1
}

// runes_last_index returns the index of the last instance of needle in s, or -1.
fn runes_last_index(s []rune, needle []rune) int {
	ls, ln := s.len, needle.len
	if ln == 0 {
		if ls == 0 {
			return 0
		}
		return ls
	}
	if ln == 1 {
		return runes_index_last_rune(s, needle[0])
	}
	if ln == ls {
		if runes_equal(s, needle) {
			return 0
		}
		return -1
	}
	if ln > ls {
		return -1
	}
	mut i := ls - 1
	for i >= ln {
		mut matched := true
		mut y := ln - 1
		for y >= 0 {
			if s[i - (ln - y - 1)] != needle[y] {
				matched = false
				break
			}
			y--
		}
		if matched {
			return i - ln + 1
		}
		i--
	}
	return -1
}

// runes_index_any returns the index of the first instance of any rune from
// chars in s, or -1.
fn runes_index_any(s []rune, chars []rune) int {
	if chars.len > 0 {
		mut i := 0
		for c in s {
			_ = i
			for m in chars {
				if c == m {
					return i
				}
			}
			i++
		}
	}
	return -1
}

// runes_contains reports whether needle is present in s.
fn runes_contains(s []rune, needle []rune) bool {
	return runes_index(s, needle) >= 0
}

// runes_max returns the highest rune in s.
fn runes_max(s []rune) rune {
	mut max := rune(0)
	for r in s {
		if r > max {
			max = r
		}
	}
	return max
}

// runes_min returns the lowest rune in s.
fn runes_min(s []rune) rune {
	mut min := rune(-1)
	for r in s {
		if min == -1 {
			min = r
			continue
		}
		if r < min {
			min = r
		}
	}
	return min
}

// runes_index_rune returns the index of the first instance of r in s, or -1.
fn runes_index_rune(s []rune, r rune) int {
	mut i := 0
	for c in s {
		if c == r {
			return i
		}
		i++
	}
	return -1
}

// runes_index_last_rune returns the index of the last instance of r in s, or -1.
fn runes_index_last_rune(s []rune, r rune) int {
	mut i := s.len - 1
	for i >= 0 {
		if s[i] == r {
			return i
		}
		i--
	}
	return -1
}

// runes_equal reports whether a and b are the same rune sequence.
fn runes_equal(a []rune, b []rune) bool {
	if a.len != b.len {
		return false
	}
	mut i := 0
	for i < a.len {
		if a[i] != b[i] {
			return false
		}
		i++
	}
	return true
}

// runes_has_prefix reports whether s begins with prefix.
fn runes_has_prefix(s []rune, prefix []rune) bool {
	return s.len >= prefix.len && runes_equal(s[0..prefix.len], prefix)
}

// runes_has_suffix reports whether s ends with suffix.
fn runes_has_suffix(s []rune, suffix []rune) bool {
	return s.len >= suffix.len && runes_equal(s[s.len - suffix.len..], suffix)
}

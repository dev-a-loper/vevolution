module glob

// Port of gobwas/glob/match -- the matcher types compiled from a glob AST.
//
// Each matcher implements four operations:
//   matches(s string) bool          -- does this matcher match the whole string s?
//   index_in(s string) (int, []int) -- leftmost position+acceptable segment lengths
//   length() int                    -- fixed rune length, or -1 if variable
//   str() string                    -- debug rendering (mirrors Go String())
//
// All matchers are aggregated in the `Matcher` sum type so the compiler can
// type-switch over them (mirroring Go's interface + type assertion).

// --- segment-buffer helpers (Go uses a sync.Pool; we just allocate) ---

const len_one = 1
const len_zero = 0
const len_no = -1

fn acquire_segments(c int) []int {
	mut r := []int{cap: c}
	return r
}

fn release_segments(_ []int) {
}

// seg_for_rune returns the single-segment list containing a rune's byte length.
fn seg_for_rune(r rune) []int {
	return [r.bytes().len]
}

// append_merge merges two already-sorted, unique segment lists into a single
// sorted-unique list (mutates and returns target).
fn append_merge(mut target []int, sub []int) []int {
	lt, ls := target.len, sub.len
	mut out := []int{cap: lt + ls}
	mut x := 0
	mut y := 0
	for x < lt || y < ls {
		if x >= lt {
			out << sub[y..]
			break
		}
		if y >= ls {
			out << target[x..]
			break
		}
		xv := target[x]
		yv := sub[y]
		if xv == yv {
			out << xv
			x++
			y++
		} else if xv < yv {
			out << xv
			x++
		} else {
			out << yv
			y++
		}
	}
	target.clear()
	target << out
	return target
}

fn reverse_segments(mut input []int) {
	l := input.len
	m := l / 2
	mut i := 0
	for i < m {
		tmp := input[i]
		other := l - i - 1
		input[i] = input[other]
		input[other] = tmp
		i++
	}
}

// ---------------------------------------------------------------------------
// Matcher variants
// ---------------------------------------------------------------------------

struct MText {
pub:
	str          string
	runes_length int
	bytes_length int
	segments     []int
}

fn new_text(s string) MText {
	return MText{
		str:          s
		runes_length: s.runes().len
		bytes_length: s.len
		segments:     [s.len]
	}
}

fn (self MText) matches(s string) bool {
	return self.str == s
}

fn (self MText) length() int {
	return self.runes_length
}

fn (self MText) index_in(s string) (int, []int) {
	idx := s.index(self.str) or { -1 }
	if idx == -1 {
		return -1, []int{}
	}
	return idx, self.segments
}

fn (self MText) str() string {
	return '<text:`${self.str}`>'
}

// ---------------------------------------------------------------------------

struct MAny {
pub:
	separators []rune
}

fn new_any(s []rune) MAny {
	return MAny{s}
}

fn (self MAny) matches(s string) bool {
	return strings_index_any_runes(s, self.separators) == -1
}

fn (self MAny) index_in(s string) (int, []int) {
	found := strings_index_any_runes(s, self.separators)
	mut sub := s
	if found == -1 {
		sub = s
	} else if found == 0 {
		return 0, [0]
	} else {
		sub = s[..found]
	}
	mut segments := acquire_segments(sub.len)
	mut bpos := 0
	for _ in sub.runes() {
		segments << bpos
		bpos += 1 // byte index; the Go code uses byte indices via range over bytes
	}
	segments << sub.len
	return 0, segments
}

fn (self MAny) length() int {
	return len_no
}

fn (self MAny) str() string {
	return '<any:![${runes_to_string(self.separators)}]>'
}

// ---------------------------------------------------------------------------

struct MSuper {}

fn new_super() MSuper {
	return MSuper{}
}

fn (self MSuper) matches(_ string) bool {
	return true
}

fn (self MSuper) length() int {
	return len_no
}

fn (self MSuper) index_in(s string) (int, []int) {
	mut segments := acquire_segments(s.len + 1)
	mut i := 0
	for _ in s.runes() {
		_ = i
		segments << i
		i += 1
	}
	segments << s.runes().len
	// Go appends byte indices; use byte positions instead for downstream slicing.
	mut bseg := []int{cap: s.len + 1}
	mut bpos := 0
	for r in s.runes() {
		bseg << bpos
		bpos += r.bytes().len
	}
	bseg << s.len
	return 0, bseg
}

fn (self MSuper) str() string {
	return '<super>'
}

// ---------------------------------------------------------------------------

struct MSingle {
pub:
	separators []rune
}

fn new_single(s []rune) MSingle {
	return MSingle{s}
}

fn (self MSingle) matches(s string) bool {
	rs := s.runes()
	if rs.len > 1 {
		return false
	}
	if rs.len == 0 {
		// Go: DecodeRuneInString("") returns (RuneError,0); len(s)>w is false,
		// IndexRune(seps, RuneError)==-1 unless separators contains RuneError.
		// Empty input never matches a single.
		return false
	}
	return runes_index_rune(self.separators, rs[0]) == -1
}

fn (self MSingle) length() int {
	return len_one
}

fn (self MSingle) index_in(s string) (int, []int) {
	mut bpos := 0
	for r in s.runes() {
		if runes_index_rune(self.separators, r) == -1 {
			return bpos, [r.bytes().len]
		}
		bpos += r.bytes().len
	}
	return -1, []int{}
}

fn (self MSingle) str() string {
	return '<single:![${runes_to_string(self.separators)}]>'
}

// ---------------------------------------------------------------------------

struct MList {
pub:
	list []rune
	not_ bool
}

fn new_list(list []rune, not_ bool) MList {
	return MList{list, not_}
}

fn (self MList) matches(s string) bool {
	rs := s.runes()
	if rs.len > 1 {
		return false
	}
	if rs.len == 0 {
		return false
	}
	in_list := runes_index_rune(self.list, rs[0]) != -1
	return in_list == !self.not_
}

fn (self MList) length() int {
	return len_one
}

fn (self MList) index_in(s string) (int, []int) {
	mut bpos := 0
	for r in s.runes() {
		if self.not_ == (runes_index_rune(self.list, r) == -1) {
			return bpos, [r.bytes().len]
		}
		bpos += r.bytes().len
	}
	return -1, []int{}
}

fn (self MList) str() string {
	mut not := ''
	if self.not_ {
		not = '!'
	}
	return '<list:${not}[${runes_to_string(self.list)}]>'
}

// ---------------------------------------------------------------------------

struct MRange {
pub:
	lo   rune
	hi   rune
	not_ bool
}

fn new_range(lo rune, hi rune, not_ bool) MRange {
	return MRange{lo, hi, not_}
}

fn (self MRange) length() int {
	return len_one
}

fn (self MRange) matches(s string) bool {
	rs := s.runes()
	if rs.len > 1 {
		return false
	}
	if rs.len == 0 {
		return false
	}
	in_range := rs[0] >= self.lo && rs[0] <= self.hi
	return in_range == !self.not_
}

fn (self MRange) index_in(s string) (int, []int) {
	mut bpos := 0
	for r in s.runes() {
		if self.not_ != (r >= self.lo && r <= self.hi) {
			return bpos, [r.bytes().len]
		}
		bpos += r.bytes().len
	}
	return -1, []int{}
}

fn (self MRange) str() string {
	mut not := ''
	if self.not_ {
		not = '!'
	}
	return '<range:${not}[${runes_to_string([self.lo])},${runes_to_string([self.hi])}]>'
}

// ---------------------------------------------------------------------------

struct MPrefix {
pub:
	prefix string
}

fn new_prefix(p string) MPrefix {
	return MPrefix{p}
}

fn (self MPrefix) index_in(s string) (int, []int) {
	idx := s.index(self.prefix) or { -1 }
	if idx == -1 {
		return -1, []int{}
	}
	length := self.prefix.len
	mut sub := ''
	if s.len > idx + length {
		sub = s[idx + length..]
	} else {
		sub = ''
	}
	mut segments := acquire_segments(sub.len + 1)
	segments << length
	mut bpos := 0
	for r in sub.runes() {
		segments << length + bpos + r.bytes().len
		bpos += r.bytes().len
	}
	return idx, segments
}

fn (self MPrefix) length() int {
	return len_no
}

fn (self MPrefix) matches(s string) bool {
	return s.starts_with(self.prefix)
}

fn (self MPrefix) str() string {
	return '<prefix:${self.prefix}>'
}

// ---------------------------------------------------------------------------

struct MSuffix {
pub:
	suffix string
}

fn new_suffix(s string) MSuffix {
	return MSuffix{s}
}

fn (self MSuffix) length() int {
	return len_no
}

fn (self MSuffix) matches(s string) bool {
	return s.ends_with(self.suffix)
}

fn (self MSuffix) index_in(s string) (int, []int) {
	idx := s.index(self.suffix) or { -1 }
	if idx == -1 {
		return -1, []int{}
	}
	return 0, [idx + self.suffix.len]
}

fn (self MSuffix) str() string {
	return '<suffix:${self.suffix}>'
}

// ---------------------------------------------------------------------------

struct MPrefixSuffix {
pub:
	prefix string
	suffix string
}

fn new_prefix_suffix(p string, s string) MPrefixSuffix {
	return MPrefixSuffix{p, s}
}

fn (self MPrefixSuffix) index_in(s string) (int, []int) {
	prefix_idx := s.index(self.prefix) or { -1 }
	if prefix_idx == -1 {
		return -1, []int{}
	}
	suffix_len := self.suffix.len
	if suffix_len <= 0 {
		return prefix_idx, [s.len - prefix_idx]
	}
	if (s.len - prefix_idx) <= 0 {
		return -1, []int{}
	}
	mut segments := acquire_segments(s.len - prefix_idx)
	mut sub := s[prefix_idx..]
	for {
		suffix_idx := sub.last_index(self.suffix) or { -1 }
		if suffix_idx == -1 {
			break
		}
		segments << suffix_idx + suffix_len
		sub = sub[..suffix_idx]
	}
	if segments.len == 0 {
		return -1, []int{}
	}
	reverse_segments(mut segments)
	return prefix_idx, segments
}

fn (self MPrefixSuffix) length() int {
	return len_no
}

fn (self MPrefixSuffix) matches(s string) bool {
	return s.starts_with(self.prefix) && s.ends_with(self.suffix)
}

fn (self MPrefixSuffix) str() string {
	return '<prefix_suffix:[${self.prefix},${self.suffix}]>'
}

// ---------------------------------------------------------------------------

struct MPrefixAny {
pub:
	prefix     string
	separators []rune
}

fn new_prefix_any(s string, sep []rune) MPrefixAny {
	return MPrefixAny{s, sep}
}

fn (self MPrefixAny) index_in(s string) (int, []int) {
	idx := s.index(self.prefix) or { -1 }
	if idx == -1 {
		return -1, []int{}
	}
	n := self.prefix.len
	mut sub := s[idx + n..]
	i := strings_index_any_runes(sub, self.separators)
	if i > -1 {
		sub = sub[..i]
	}
	mut seg := acquire_segments(sub.len + 1)
	seg << n
	mut bpos := 0
	for r in sub.runes() {
		seg << n + bpos + r.bytes().len
		bpos += r.bytes().len
	}
	return idx, seg
}

fn (self MPrefixAny) length() int {
	return len_no
}

fn (self MPrefixAny) matches(s string) bool {
	if !s.starts_with(self.prefix) {
		return false
	}
	return strings_index_any_runes(s[self.prefix.len..], self.separators) == -1
}

fn (self MPrefixAny) str() string {
	return '<prefix_any:${self.prefix}![${runes_to_string(self.separators)}]>'
}

// ---------------------------------------------------------------------------

struct MSuffixAny {
pub:
	suffix     string
	separators []rune
}

fn new_suffix_any(s string, sep []rune) MSuffixAny {
	return MSuffixAny{s, sep}
}

fn (self MSuffixAny) index_in(s string) (int, []int) {
	idx := s.index(self.suffix) or { -1 }
	if idx == -1 {
		return -1, []int{}
	}
	i := strings_last_index_any_runes(s[..idx], self.separators) + 1
	return i, [idx + self.suffix.len - i]
}

fn (self MSuffixAny) length() int {
	return len_no
}

fn (self MSuffixAny) matches(s string) bool {
	if !s.ends_with(self.suffix) {
		return false
	}
	return strings_index_any_runes(s[..s.len - self.suffix.len], self.separators) == -1
}

fn (self MSuffixAny) str() string {
	return '<suffix_any:![${runes_to_string(self.separators)}]${self.suffix}>'
}

// ---------------------------------------------------------------------------

struct MContains {
pub:
	needle string
	not_   bool
}

fn new_contains(needle string, not_ bool) MContains {
	return MContains{needle, not_}
}

fn (self MContains) matches(s string) bool {
	return s.contains(self.needle) != self.not_
}

fn (self MContains) index_in(s string) (int, []int) {
	mut offset := 0
	mut work := s
	idx := work.index(self.needle) or { -1 }
	if !self.not_ {
		if idx == -1 {
			return -1, []int{}
		}
		offset = idx + self.needle.len
		if work.len <= offset {
			return 0, [offset]
		}
		work = work[offset..]
	} else if idx != -1 {
		work = work[..idx]
	}
	mut segments := acquire_segments(work.len + 1)
	mut i := 0
	for _ in work.runes() {
		_ = i
		segments << offset + i
		i += 1
	}
	segments << offset + work.len
	return 0, segments
}

fn (self MContains) length() int {
	return len_no
}

fn (self MContains) str() string {
	mut not := ''
	if self.not_ {
		not = '!'
	}
	return '<contains:${not}[${self.needle}]>'
}

// ---------------------------------------------------------------------------

struct MBTree {
pub mut:
	value        Matcher
	left         ?Matcher
	right        ?Matcher
	value_length int
	left_length  int
	right_length int
	length_runes int
}

fn new_btree(value Matcher, left ?Matcher, right ?Matcher) MBTree {
	mut tree := MBTree{
		value: value
		left:  left
		right: right
	}
	mut len_ok := true
	tree.value_length = value.length()
	if tree.value_length == -1 {
		len_ok = false
	}
	if l := left {
		tree.left_length = l.length()
		if tree.left_length == -1 {
			len_ok = false
		}
	}
	if r := right {
		tree.right_length = r.length()
		if tree.right_length == -1 {
			len_ok = false
		}
	}
	if len_ok {
		tree.length_runes = tree.left_length + tree.value_length + tree.right_length
	} else {
		tree.length_runes = -1
	}
	return tree
}

fn (self MBTree) length() int {
	return self.length_runes
}

fn (self MBTree) index_in(_ string) (int, []int) {
	return -1, []int{}
}

fn (self MBTree) matches(s string) bool {
	input_len := s.len
	offset, limit := self.offset_limit(input_len)
	mut off := offset
	for off < limit {
		index, segments := btree_value_index(self.value, s[off..limit])
		if index == -1 {
			release_segments(segments)
			return false
		}
		l := s[..off + index]
		mut left_match := false
		if lm := self.left {
			left_match = btree_match(lm, l)
		} else {
			left_match = l == ''
		}
		if left_match {
			mut i := segments.len - 1
			for i >= 0 {
				length := segments[i]
				mut right_match := false
				mut r := ''
				if input_len <= off + index + length {
					r = ''
				} else {
					r = s[off + index + length..]
				}
				if rm := self.right {
					right_match = btree_match(rm, r)
				} else {
					right_match = r == ''
				}
				if right_match {
					release_segments(segments)
					return true
				}
				i--
			}
		}
		// advance past the matched rune at s[off+index..]
		rest := s[off + index..]
		step := if rest.len > 0 { rest.runes()[0].bytes().len } else { 0 }
		off += index + step
		release_segments(segments)
	}
	return false
}

fn (self MBTree) offset_limit(input_len int) (int, int) {
	if self.length_runes != -1 && self.length_runes > input_len {
		return 0, 0
	}
	mut offset := 0
	mut limit := input_len
	if self.left_length >= 0 {
		offset = self.left_length
	}
	if self.right_length >= 0 {
		limit = input_len - self.right_length
	} else {
		limit = input_len
	}
	return offset, limit
}

fn (self MBTree) str() string {
	l := if lm := self.left { matcher_str(lm) } else { '<nil>' }
	r := if rm := self.right { matcher_str(rm) } else { '<nil>' }
	return '<btree:[${l}<-${matcher_str(self.value)}->${r}]>'
}

// ---------------------------------------------------------------------------

struct MAnyOf {
pub mut:
	matchers []Matcher
}

fn new_any_of(m []Matcher) MAnyOf {
	return MAnyOf{m}
}

fn (mut self MAnyOf) add(m Matcher) {
	self.matchers << m
}

fn (self MAnyOf) matches(s string) bool {
	for m in self.matchers {
		if btree_match(m, s) {
			return true
		}
	}
	return false
}

fn (self MAnyOf) index_in(s string) (int, []int) {
	mut index := -1
	mut segments := acquire_segments(s.len)
	for m in self.matchers {
		idx, seg := btree_value_index(m, s)
		if idx == -1 {
			continue
		}
		if index == -1 || idx < index {
			index = idx
			segments.clear()
			segments << seg
			continue
		}
		if idx > index {
			continue
		}
		// idx == index
		append_merge(mut segments, seg)
	}
	if index == -1 {
		return -1, []int{}
	}
	return index, segments
}

fn (self MAnyOf) length() int {
	mut l := -1
	for m in self.matchers {
		ml := m.length()
		if l == -1 {
			l = ml
			continue
		}
		if ml == -1 {
			return -1
		}
		if l != ml {
			return -1
		}
	}
	return l
}

fn (self MAnyOf) str() string {
	return '<any_of:[${matchers_join(self.matchers)}]>'
}

// ---------------------------------------------------------------------------

struct MEveryOf {
pub mut:
	matchers []Matcher
}

fn new_every_of(m []Matcher) MEveryOf {
	return MEveryOf{m}
}

fn (mut self MEveryOf) add(m Matcher) {
	self.matchers << m
}

fn (self MEveryOf) length() int {
	mut l := 0
	for m in self.matchers {
		ml := m.length()
		if ml > 0 {
			l += ml
		} else {
			return -1
		}
	}
	return l
}

fn (self MEveryOf) index_in(s string) (int, []int) {
	mut index := 0
	mut offset := 0
	mut next := acquire_segments(s.len)
	mut current := acquire_segments(s.len)
	mut sub := s
	mut i := 0
	for m in self.matchers {
		idx, seg := btree_value_index(m, sub)
		if idx == -1 {
			return -1, []int{}
		}
		if i == 0 {
			current << seg
		} else {
			next.clear()
			delta := index - (idx + offset)
			for ex in current {
				for n in seg {
					if ex + delta == n {
						next << n
					}
				}
			}
			if next.len == 0 {
				return -1, []int{}
			}
			current.clear()
			current << next
		}
		index = idx + offset
		sub = s[index..]
		offset += idx
		i++
	}
	return index, current
}

fn (self MEveryOf) matches(s string) bool {
	for m in self.matchers {
		if !btree_match(m, s) {
			return false
		}
	}
	return true
}

fn (self MEveryOf) str() string {
	return '<every_of:[${matchers_join(self.matchers)}]>'
}

// ---------------------------------------------------------------------------

struct MRow {
pub:
	matchers     []Matcher
	runes_length int
	segments     []int
}

fn new_row(length int, m []Matcher) MRow {
	return MRow{
		matchers:     m
		runes_length: length
		segments:     [length]
	}
}

fn (self MRow) match_all(s string) bool {
	mut idx := 0
	for m in self.matchers {
		length := m.length()
		// advance `length` runes within s[idx..]
		rs := s[idx..].runes()
		if rs.len < length {
			return false
		}
		mut next := 0 // byte length consumed by `length` runes
		mut count := 0
		mut bpos := 0
		mut got := false
		for r in rs {
			count++
			if count == length {
				next = bpos + r.bytes().len
				got = true
				break
			}
			bpos += r.bytes().len
		}
		if !got {
			return false
		}
		_ = next
		// match s[idx..idx+next]
		if !btree_match(m, s[idx..idx + next]) {
			return false
		}
		idx += next
	}
	return true
}

fn (self MRow) len_ok(s string) bool {
	i := s.runes().len
	return self.runes_length == i
}

fn (self MRow) matches(s string) bool {
	return self.len_ok(s) && self.match_all(s)
}

fn (self MRow) length() int {
	return self.runes_length
}

fn (self MRow) index_in(s string) (int, []int) {
	// iterate over rune start byte-offsets
	mut bpos := 0
	for r in s.runes() {
		_ = r
		if s[bpos..].runes().len < self.runes_length {
			break
		}
		if self.match_all(s[bpos..]) {
			return bpos, self.segments
		}
		bpos += r.bytes().len
	}
	return -1, []int{}
}

fn (self MRow) str() string {
	return '<row_${self.runes_length}:[${matchers_join(self.matchers)}]>'
}

// ---------------------------------------------------------------------------

struct MMin {
pub:
	limit int
}

fn new_min(l int) MMin {
	return MMin{l}
}

fn (self MMin) matches(s string) bool {
	return s.runes().len >= self.limit
}

fn (self MMin) index_in(s string) (int, []int) {
	count_runes := s.runes().len
	c := count_runes - self.limit + 1
	if c <= 0 {
		return -1, []int{}
	}
	mut segments := acquire_segments(c)
	mut bpos := 0
	mut count := 0
	for r in s.runes() {
		count++
		if count >= self.limit {
			segments << bpos + r.bytes().len
		}
		bpos += r.bytes().len
	}
	if segments.len == 0 {
		return -1, []int{}
	}
	return 0, segments
}

fn (self MMin) length() int {
	return len_no
}

fn (self MMin) str() string {
	return '<min:${self.limit}>'
}

// ---------------------------------------------------------------------------

struct MMax {
pub:
	limit int
}

fn new_max(l int) MMax {
	return MMax{l}
}

fn (self MMax) matches(s string) bool {
	return s.runes().len <= self.limit
}

fn (self MMax) index_in(s string) (int, []int) {
	mut segments := acquire_segments(self.limit + 1)
	segments << 0
	mut count := 0
	mut bpos := 0
	for r in s.runes() {
		count++
		if count > self.limit {
			break
		}
		segments << bpos + r.bytes().len
		bpos += r.bytes().len
	}
	return 0, segments
}

fn (self MMax) length() int {
	return len_no
}

fn (self MMax) str() string {
	return '<max:${self.limit}>'
}

// ---------------------------------------------------------------------------

struct MNothing {}

fn new_nothing() MNothing {
	return MNothing{}
}

fn (self MNothing) matches(s string) bool {
	return s == ''
}

fn (self MNothing) index_in(_ string) (int, []int) {
	return 0, [0]
}

fn (self MNothing) length() int {
	return len_zero
}

fn (self MNothing) str() string {
	return '<nothing>'
}

// ---------------------------------------------------------------------------
// Matcher sum type + dispatch shims
// ---------------------------------------------------------------------------

type Matcher = MText
	| MAny
	| MSuper
	| MSingle
	| MList
	| MRange
	| MPrefix
	| MSuffix
	| MPrefixSuffix
	| MPrefixAny
	| MSuffixAny
	| MContains
	| MBTree
	| MAnyOf
	| MEveryOf
	| MRow
	| MMin
	| MMax
	| MNothing

// Sum-type method wrappers so `.length()`, `.matches()`, etc. work on a value
// statically typed as `Matcher` (not just on the concrete struct variants).
fn (m Matcher) length() int {
	return matcher_length(m)
}

fn (m Matcher) matches(s string) bool {
	return matcher_match(m, s)
}

fn (m Matcher) index_in(s string) (int, []int) {
	return matcher_index(m, s)
}

fn (m Matcher) str() string {
	return matcher_str(m)
}

// matcher_match dispatches matches() over the sum type.
fn matcher_match(m Matcher, s string) bool {
	return match m {
		MText { m.matches(s) }
		MAny { m.matches(s) }
		MSuper { m.matches(s) }
		MSingle { m.matches(s) }
		MList { m.matches(s) }
		MRange { m.matches(s) }
		MPrefix { m.matches(s) }
		MSuffix { m.matches(s) }
		MPrefixSuffix { m.matches(s) }
		MPrefixAny { m.matches(s) }
		MSuffixAny { m.matches(s) }
		MContains { m.matches(s) }
		MBTree { m.matches(s) }
		MAnyOf { m.matches(s) }
		MEveryOf { m.matches(s) }
		MRow { m.matches(s) }
		MMin { m.matches(s) }
		MMax { m.matches(s) }
		MNothing { m.matches(s) }
	}
}

// btree_match is the recursive match used inside BTree/AnyOf/EveryOf/Row.
fn btree_match(m Matcher, s string) bool {
	return matcher_match(m, s)
}

// matcher_index dispatches index_in() over the sum type.
fn matcher_index(m Matcher, s string) (int, []int) {
	return match m {
		MText { m.index_in(s) }
		MAny { m.index_in(s) }
		MSuper { m.index_in(s) }
		MSingle { m.index_in(s) }
		MList { m.index_in(s) }
		MRange { m.index_in(s) }
		MPrefix { m.index_in(s) }
		MSuffix { m.index_in(s) }
		MPrefixSuffix { m.index_in(s) }
		MPrefixAny { m.index_in(s) }
		MSuffixAny { m.index_in(s) }
		MContains { m.index_in(s) }
		MBTree { m.index_in(s) }
		MAnyOf { m.index_in(s) }
		MEveryOf { m.index_in(s) }
		MRow { m.index_in(s) }
		MMin { m.index_in(s) }
		MMax { m.index_in(s) }
		MNothing { m.index_in(s) }
	}
}

fn btree_value_index(m Matcher, s string) (int, []int) {
	return matcher_index(m, s)
}

// matcher_length dispatches length() over the sum type.
fn matcher_length(m Matcher) int {
	return match m {
		MText { m.length() }
		MAny { m.length() }
		MSuper { m.length() }
		MSingle { m.length() }
		MList { m.length() }
		MRange { m.length() }
		MPrefix { m.length() }
		MSuffix { m.length() }
		MPrefixSuffix { m.length() }
		MPrefixAny { m.length() }
		MSuffixAny { m.length() }
		MContains { m.length() }
		MBTree { m.length() }
		MAnyOf { m.length() }
		MEveryOf { m.length() }
		MRow { m.length() }
		MMin { m.length() }
		MMax { m.length() }
		MNothing { m.length() }
	}
}

// matcher_str dispatches str() over the sum type.
fn matcher_str(m Matcher) string {
	return match m {
		MText { m.str() }
		MAny { m.str() }
		MSuper { m.str() }
		MSingle { m.str() }
		MList { m.str() }
		MRange { m.str() }
		MPrefix { m.str() }
		MSuffix { m.str() }
		MPrefixSuffix { m.str() }
		MPrefixAny { m.str() }
		MSuffixAny { m.str() }
		MContains { m.str() }
		MBTree { m.str() }
		MAnyOf { m.str() }
		MEveryOf { m.str() }
		MRow { m.str() }
		MMin { m.str() }
		MMax { m.str() }
		MNothing { m.str() }
	}
}

// matchers_join renders a slice of matchers comma-separated (mirrors Go Matchers.String()).
fn matchers_join(ms []Matcher) string {
	mut parts := []string{cap: ms.len}
	for m in ms {
		parts << matcher_str(m)
	}
	return parts.join(',')
}

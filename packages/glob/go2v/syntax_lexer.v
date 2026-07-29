module glob

// Port of gobwas/glob/syntax/lexer -- tokenizes a glob pattern.
//
// The Go lexer is byte-position based with utf8 rune decoding. Here we work
// directly on a []rune view of the source (patterns are short); Token.Raw is
// reconstructed via runes_to_string where Go did string([]rune)/string(r).

enum TokenKind {
	eof
	terror
	text
	tchar
	any_
	super
	single
	not_
	separator
	range_open
	range_close
	range_lo
	range_hi
	range_between
	terms_open
	terms_close
}

fn (tt TokenKind) str() string {
	return match tt {
		.eof { 'eof' }
		.terror { 'error' }
		.text { 'text' }
		.tchar { 'char' }
		.any_ { 'any' }
		.super { 'super' }
		.single { 'single' }
		.not_ { 'not' }
		.separator { 'separator' }
		.range_open { 'range_open' }
		.range_close { 'range_close' }
		.range_lo { 'range_lo' }
		.range_hi { 'range_hi' }
		.range_between { 'range_between' }
		.terms_open { 'terms_open' }
		.terms_close { 'terms_close' }
	}
}

struct Token {
pub:
	kind TokenKind
	raw  string
}

fn (t Token) str() string {
	return '${t.kind}<`${t.raw}`>'
}

// Character constants (mirror Go's char_* consts).
const char_any = `*`
const char_comma = `,`
const char_single = `?`
const char_escape = `\\`
const char_range_open = `[`
const char_range_close = `]`
const char_terms_open = `{`
const char_terms_close = `}`
const char_range_not = `!`
const char_range_between = `-`

const specials = [char_any, char_single, char_escape, char_range_open, char_range_close,
	char_terms_open, char_terms_close]

// special reports whether b is a glob meta character.
fn special(b u8) bool {
	return specials.index(byte(b)) != -1
}

const eof_rune = rune(0)

struct Lexer {
pub:
	data []rune
mut:
	pos         int
	err         ?string
	tokens      []Token
	terms_level int
	last_rune   rune
	has_rune    bool
}

fn new_lexer(source string) &Lexer {
	mut l := &Lexer{
		data:   source.runes()
		tokens: []Token{cap: 4}
	}
	return l
}

fn (mut l Lexer) next() Token {
	if l.err != none {
		// preserve original error message token
		return Token{.terror, l.err or { '' }}
	}
	if l.tokens.len > 0 {
		mut t := l.tokens[0]
		l.tokens.delete(0)
		return t
	}
	l.fetch_item()
	return l.next()
}

fn (l Lexer) peek() (rune, int) {
	if l.pos == l.data.len {
		return eof_rune, 0
	}
	return l.data[l.pos], 1
}

fn (mut l Lexer) read() rune {
	if l.has_rune {
		l.has_rune = false
		l.pos++
		return l.last_rune
	}
	r, s := l.peek()
	l.pos += s
	l.last_rune = r
	return r
}

fn (mut l Lexer) unread() {
	if l.has_rune {
		l.errorf('could not unread rune')
		return
	}
	l.pos--
	l.has_rune = true
}

fn (mut l Lexer) errorf(msg string) {
	l.err = msg
}

fn (l Lexer) in_terms() bool {
	return l.terms_level > 0
}

fn (mut l Lexer) terms_enter() {
	l.terms_level++
}

fn (mut l Lexer) terms_leave() {
	l.terms_level--
}

const in_text_breakers = [char_single, char_any, char_range_open, char_terms_open]
const in_terms_breakers = [char_single, char_any, char_range_open, char_terms_open, char_terms_close,
	char_comma]

fn (mut l Lexer) fetch_item() {
	r := l.read()
	if r == eof_rune {
		l.tokens << Token{.eof, ''}
		return
	}
	if r == char_terms_open {
		l.terms_enter()
		l.tokens << Token{.terms_open, runes_to_string([r])}
		return
	}
	if r == char_comma && l.in_terms() {
		l.tokens << Token{.separator, runes_to_string([r])}
		return
	}
	if r == char_terms_close && l.in_terms() {
		l.tokens << Token{.terms_close, runes_to_string([r])}
		l.terms_leave()
		return
	}
	if r == char_range_open {
		l.tokens << Token{.range_open, runes_to_string([r])}
		l.fetch_range()
		return
	}
	if r == char_single {
		l.tokens << Token{.single, runes_to_string([r])}
		return
	}
	if r == char_any {
		if l.read() == char_any {
			l.tokens << Token{.super, runes_to_string([r, r])}
		} else {
			l.unread()
			l.tokens << Token{.any_, runes_to_string([r])}
		}
		return
	}
	// default
	l.unread()
	mut breakers := []rune{}
	if l.in_terms() {
		breakers = in_terms_breakers.clone()
	} else {
		breakers = in_text_breakers.clone()
	}
	l.fetch_text(breakers)
}

fn (mut l Lexer) fetch_range() {
	mut want_hi := false
	mut want_close := false
	mut seen_not := false
	for {
		r := l.read()
		if r == eof_rune {
			l.errorf('unexpected end of input')
			return
		}
		if want_close {
			if r != char_range_close {
				l.errorf('expected close range character')
			} else {
				l.tokens << Token{.range_close, runes_to_string([r])}
			}
			return
		}
		if want_hi {
			l.tokens << Token{.range_hi, runes_to_string([r])}
			want_close = true
			continue
		}
		if !seen_not && r == char_range_not {
			l.tokens << Token{.not_, runes_to_string([r])}
			seen_not = true
			continue
		}
		n, w := l.peek()
		if n == char_range_between {
			l.pos += w
			l.tokens << Token{.range_lo, runes_to_string([r])}
			l.tokens << Token{.range_between, runes_to_string([n])}
			want_hi = true
			continue
		}
		l.unread()
		l.fetch_text([char_range_close])
		want_close = true
	}
}

fn (mut l Lexer) fetch_text(breakers []rune) {
	mut data := []rune{}
	mut escaped := false
	for {
		r := l.read()
		if r == eof_rune {
			break
		}
		if !escaped {
			if r == char_escape {
				escaped = true
				continue
			}
			if runes_index_rune(breakers, r) != -1 {
				l.unread()
				break
			}
		}
		escaped = false
		data << r
	}
	if data.len > 0 {
		l.tokens << Token{.text, runes_to_string(data)}
	}
}

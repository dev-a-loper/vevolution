module glob

// Port of gobwas/glob/glob.go -- the public Compile/MustCompile/QuoteMeta API.

// Glob is the public interface of a compiled glob pattern.
pub interface Glob {
	matches(s string) bool
}

// compiled_glob wraps a Matcher tree and exposes the Glob API.
pub struct CompiledGlob {
	matcher Matcher
}

// matches reports whether the compiled pattern matches the given string.
pub fn (g CompiledGlob) matches(s string) bool {
	return matcher_match(g.matcher, s)
}

// str renders the compiled matcher tree (mirrors Go String()).
pub fn (g CompiledGlob) str() string {
	return matcher_str(g.matcher)
}

// compile creates a Glob for the given pattern and optional separators.
pub fn compile(pattern string, separators ...rune) !CompiledGlob {
	ast := syntax_parse_pattern(pattern)!
	m := compile_ast(ast, separators)!
	return CompiledGlob{m}
}

// must_compile is like compile but panics on error.
pub fn must_compile(pattern string, separators ...rune) CompiledGlob {
	g := compile(pattern, ...separators) or { panic(err.str()) }
	return g
}

// quote_meta returns a string that quotes all glob pattern meta characters
// inside the argument text.
pub fn quote_meta(s string) string {
	mut b := []u8{cap: 2 * s.len}
	mut i := 0
	for i < s.len {
		if special(s[i]) {
			b << byte(`\\`)
		}
		b << s[i]
		i++
	}
	return b.bytestr()
}

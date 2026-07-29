module glob

// Port of gobwas/glob/syntax/syntax.go -- Parse/Special entry points wiring
// the lexer to the AST parser.

// syntax_parse_pattern parses a glob pattern into an AST root node.
fn syntax_parse_pattern(s string) !&Node {
	mut l := new_lexer(s)
	return syntax_parse(mut l)
}

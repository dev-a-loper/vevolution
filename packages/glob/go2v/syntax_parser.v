module glob

// Port of gobwas/glob/syntax/ast/parser.go -- turns a token stream from the
// lexer into an AST.
//
// Go threads a `parseFn` and uses `Node.Parent` back-edges. We instead parse
// in a single function with a node stack (no parent pointers) and an explicit
// "are we inside a [...] range" mode bit.

fn syntax_parse(mut lex Lexer) !&Node {
	mut root := new_node(.kind_pattern, none, [])
	mut current := root
	// outer_stack: the Pattern node active when entering a `{...}` group.
	// anyof_stack: the AnyOf node that owns the current alternative Pattern.
	mut outer_stack := []&Node{}
	mut anyof_stack := []&Node{}

	mut in_range := false
	mut r_not := false
	mut r_lo := rune(0)
	mut r_hi := rune(0)
	mut r_chars := ''

	for {
		tok := lex.next()
		if in_range {
			match tok.kind {
				.eof {
					return error('unexpected end')
				}
				.terror {
					return error(tok.raw)
				}
				.not_ {
					r_not = true
				}
				.range_lo {
					rs := tok.raw.runes()
					if rs.len != 1 {
						return error('unexpected length of lo character')
					}
					r_lo = rs[0]
				}
				.range_between {}
				.range_hi {
					rs := tok.raw.runes()
					if rs.len != 1 {
						return error('unexpected length of lo character')
					}
					r_hi = rs[0]
					if r_hi < r_lo {
						return error("hi character '${r_hi}' should be greater than lo '${r_lo}'")
					}
				}
				.text {
					r_chars = tok.raw
				}
				.range_close {
					is_range := r_lo != 0 && r_hi != 0
					is_chars := r_chars != ''
					if is_chars == is_range {
						return error('could not parse range')
					}
					if is_range {
						mut n := new_node(.kind_range, NRange{r_not, r_lo, r_hi}, [])
						current.children << n
					} else {
						mut n := new_node(.kind_list, NList{r_not, r_chars}, [])
						current.children << n
					}
					in_range = false
					r_not = false
					r_lo = rune(0)
					r_hi = rune(0)
					r_chars = ''
				}
				else {}
			}

			continue
		}
		match tok.kind {
			.eof {
				return root
			}
			.terror {
				return error(tok.raw)
			}
			.text {
				mut n := new_node(.kind_text, NText{tok.raw}, [])
				current.children << n
			}
			.any_ {
				mut n := new_node(.kind_any, none, [])
				current.children << n
			}
			.super {
				mut n := new_node(.kind_super, none, [])
				current.children << n
			}
			.single {
				mut n := new_node(.kind_single, none, [])
				current.children << n
			}
			.range_open {
				in_range = true
				r_not = false
				r_lo = rune(0)
				r_hi = rune(0)
				r_chars = ''
			}
			.terms_open {
				mut a := new_node(.kind_any_of, none, [])
				current.children << a
				mut p := new_node(.kind_pattern, none, [])
				a.children << p
				outer_stack << current
				anyof_stack << a
				current = p
			}
			.separator {
				if anyof_stack.len == 0 {
					return error('separator without terms parent')
				}
				mut anyof := anyof_stack[anyof_stack.len - 1]
				mut p := new_node(.kind_pattern, none, [])
				anyof.children << p
				current = p
			}
			.terms_close {
				if outer_stack.len == 0 {
					return error('terms close without parent')
				}
				anyof_stack.delete(anyof_stack.len - 1)
				current = outer_stack[outer_stack.len - 1]
				outer_stack.delete(outer_stack.len - 1)
			}
			else {
				return error('unexpected token: ${tok.str()}')
			}
		}
	}
	return root
}

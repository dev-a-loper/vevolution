module glob

// Port of gobwas/glob/syntax/ast -- the AST node tree built by the parser and
// consumed by the compiler.
//
// The Go code uses `*Node` parent back-edges during parsing; here we drive the
// parser with an explicit node stack instead (see syntax_parser.v), so Node is
// a plain tree of children. The heap attribute is not required since we never
// take the address of a stack-local Node.

enum Kind {
	kind_nothing
	kind_pattern
	kind_list
	kind_range
	kind_text
	kind_any
	kind_super
	kind_single
	kind_any_of
}

fn (k Kind) str() string {
	return match k {
		.kind_nothing { 'Nothing' }
		.kind_pattern { 'Pattern' }
		.kind_list { 'List' }
		.kind_range { 'Range' }
		.kind_text { 'Text' }
		.kind_any { 'Any' }
		.kind_super { 'Super' }
		.kind_single { 'Single' }
		.kind_any_of { 'AnyOf' }
	}
}

struct NList {
pub:
	not_  bool
	chars string
}

struct NRange {
pub:
	not_ bool
	lo   rune
	hi   rune
}

struct NText {
pub:
	text string
}

type NodeValue = NList | NRange | NText

struct Node {
pub mut:
	kind     Kind
	value    ?NodeValue
	children []&Node
}

// new_node creates a heap node with the given kind/value and optional children.
fn new_node(k Kind, v ?NodeValue, children []&Node) &Node {
	mut n := &Node{
		kind:  k
		value: v
	}
	for c in children {
		n.children << c
	}
	return n
}

fn node_equal(a &Node, b &Node) bool {
	if a.kind != b.kind {
		return false
	}
	a_none := a.value == none
	b_none := b.value == none
	if a_none != b_none {
		return false
	}
	if !a_none {
		av := a.value or { NText{''} }
		bv := b.value or { NText{''} }
		if !node_value_equal(av, bv) {
			return false
		}
	}
	if a.children.len != b.children.len {
		return false
	}
	mut i := 0
	for i < a.children.len {
		if !node_equal(a.children[i], b.children[i]) {
			return false
		}
		i++
	}
	return true
}

fn node_value_equal(a NodeValue, b NodeValue) bool {
	if a is NList && b is NList {
		la := a as NList
		lb := b as NList
		return la.not_ == lb.not_ && la.chars == lb.chars
	}
	if a is NRange && b is NRange {
		ra := a as NRange
		rb := b as NRange
		return ra.not_ == rb.not_ && ra.lo == rb.lo && ra.hi == rb.hi
	}
	if a is NText && b is NText {
		ta := a as NText
		tb := b as NText
		return ta.text == tb.text
	}
	return false
}

fn (n &Node) str() string {
	mut out := n.kind.str()
	if n.value != none {
		v := n.value or { NText{''} }
		out += ' =${node_value_str(v)}'
	}
	if n.children.len > 0 {
		out += ' ['
		mut i := 0
		for i < n.children.len {
			if i > 0 {
				out += ', '
			}
			out += n.children[i].str()
			i++
		}
		out += ']'
	}
	return out
}

fn node_value_str(v NodeValue) string {
	return match v {
		NList { '${v.not_} ${v.chars}' }
		NRange { '${v.not_} ${v.lo} ${v.hi}' }
		NText { v.text }
	}
}

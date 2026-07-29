module glob

// Port of gobwas/glob/compiler -- lowers the AST into a Matcher tree and applies
// a set of optimizations (matcher collapsing, common-subexpression factoring on
// AnyOf, etc.). Type switches over Matcher variants mirror Go's interface type
// assertions.

// optimize_matcher applies local simplifications to a single matcher node.
fn optimize_matcher(matcher Matcher) Matcher {
	return match matcher {
		MAny {
			if matcher.separators.len == 0 {
				return Matcher(new_super())
			}
			matcher
		}
		MAnyOf {
			if matcher.matchers.len == 1 {
				return matcher.matchers[0]
			}
			matcher
		}
		MList {
			if !matcher.not_ && matcher.list.len == 1 {
				return Matcher(new_text(runes_to_string(matcher.list)))
			}
			matcher
		}
		MBTree {
			optimize_btree(matcher)
		}
		else {
			matcher
		}
	}
}

fn optimize_btree(m_in MBTree) Matcher {
	mut m := m_in
	if l := m.left {
		m.left = optimize_matcher(l)
	}
	if r := m.right {
		m.right = optimize_matcher(r)
	}
	if m.value !is MText {
		return Matcher(m)
	}
	rstr := (m.value as MText).str
	left_nil := m.left == none
	right_nil := m.right == none
	if left_nil && right_nil {
		return Matcher(new_text(rstr))
	}
	mut left_super := false
	mut left_prefix := false
	mut lp := MPrefix{''}
	mut left_any := false
	mut la := MAny{[]}
	if lv := m.left {
		if lv is MSuper {
			left_super = true
		} else if lv is MPrefix {
			left_prefix = true
			lp = lv
		} else if lv is MAny {
			left_any = true
			la = lv
		}
	}
	mut right_super := false
	mut right_suffix := false
	mut rs := MSuffix{''}
	mut right_any := false
	mut ra := MAny{[]}
	if rv := m.right {
		if rv is MSuper {
			right_super = true
		} else if rv is MSuffix {
			right_suffix = true
			rs = rv
		} else if rv is MAny {
			right_any = true
			ra = rv
		}
	}
	if left_super && right_super {
		return Matcher(new_contains(rstr, false))
	}
	if left_super && right_nil {
		return Matcher(new_suffix(rstr))
	}
	if right_super && left_nil {
		return Matcher(new_prefix(rstr))
	}
	if left_nil && right_suffix {
		return Matcher(new_prefix_suffix(rstr, rs.suffix))
	}
	if right_nil && left_prefix {
		return Matcher(new_prefix_suffix(lp.prefix, rstr))
	}
	if right_nil && left_any {
		return Matcher(new_suffix_any(rstr, la.separators))
	}
	if left_nil && right_any {
		return Matcher(new_prefix_any(rstr, ra.separators))
	}
	return Matcher(m)
}

// compile_matchers combines a sequence of matchers into a single matcher,
// building a BTree around the longest fixed-length node.
fn compile_matchers(matchers []Matcher) !Matcher {
	if matchers.len == 0 {
		return error('compile error: need at least one matcher')
	}
	if matchers.len == 1 {
		return matchers[0]
	}
	if glued := glue_matchers(matchers) {
		return glued
	}
	mut idx := -1
	mut max_len := -1
	mut found := false
	mut val_matcher := Matcher(MNothing{})
	mut i := 0
	for matcher in matchers {
		l := matcher_length(matcher)
		if l != -1 && l >= max_len {
			max_len = l
			idx = i
			val_matcher = matcher
			found = true
		}
		i++
	}
	if !found {
		r := compile_matchers(matchers[1..])!
		return Matcher(new_btree(matchers[0], none, r))
	}
	left := matchers[..idx]
	mut right := []Matcher{}
	if matchers.len > idx + 1 {
		right = matchers[idx + 1..].clone()
	}
	mut l_ := ?Matcher(none)
	mut r_ := ?Matcher(none)
	if left.len > 0 {
		l_ = compile_matchers(left.clone())!
	}
	if right.len > 0 {
		r_ = compile_matchers(right)!
	}
	return Matcher(new_btree(val_matcher, l_, r_))
}

// glue_matchers attempts to fold a matcher run into a single specialized node.
fn glue_matchers(matchers []Matcher) ?Matcher {
	if m := glue_matchers_as_every(matchers) {
		return m
	}
	if m := glue_matchers_as_row(matchers) {
		return m
	}
	return none
}

fn glue_matchers_as_row(matchers []Matcher) ?Matcher {
	if matchers.len <= 1 {
		return none
	}
	mut c := []Matcher{}
	mut l := 0
	for matcher in matchers {
		ml := matcher_length(matcher)
		if ml == -1 {
			return none
		}
		c << matcher
		l += ml
	}
	return Matcher(new_row(l, c))
}

fn glue_matchers_as_every(matchers []Matcher) ?Matcher {
	if matchers.len <= 1 {
		return none
	}
	mut has_any := false
	mut has_super := false
	mut has_single := false
	mut min_ := 0
	mut separator := []rune{}
	for i, matcher in matchers {
		mut sep := []rune{}
		if matcher is MSuper {
			sep = []rune{}
			has_super = true
		} else if matcher is MAny {
			sep = matcher.separators.clone()
			has_any = true
		} else if matcher is MSingle {
			sep = matcher.separators.clone()
			has_single = true
			min_++
		} else if matcher is MList {
			if !matcher.not_ {
				return none
			}
			sep = matcher.list.clone()
			has_single = true
			min_++
		} else {
			return none
		}
		if i == 0 {
			separator = sep.clone()
		}
		if runes_equal(sep, separator) {
			continue
		}
		return none
	}
	if has_super && !has_any && !has_single {
		return Matcher(new_super())
	}
	if has_any && !has_super && !has_single {
		return Matcher(new_any(separator))
	}
	if (has_any || has_super) && min_ > 0 && separator.len == 0 {
		return Matcher(new_min(min_))
	}
	mut every := []Matcher{}
	if min_ > 0 {
		every << Matcher(new_min(min_))
		if !has_any && !has_super {
			every << Matcher(new_max(min_))
		}
	}
	if separator.len > 0 {
		every << Matcher(new_contains(runes_to_string(separator), true))
	}
	return Matcher(new_every_of(every))
}

// minimize_matchers greedily replaces the largest glueable subrange with its
// folded form, then recurses.
fn minimize_matchers(matchers []Matcher) []Matcher {
	mut done_found := false
	mut done_val := Matcher(MNothing{})
	mut left := 0
	mut right := 0
	mut count := 0
	mut l := 0
	for l < matchers.len {
		mut r := matchers.len
		for r > l {
			if glued := glue_matchers(matchers[l..r]) {
				mut swap_ := false
				if !done_found {
					swap_ = true
				} else {
					cl := matcher_length(done_val)
					gl := matcher_length(glued)
					swap_ = (cl > -1 && gl > -1 && gl > cl) || count < r - l
				}
				if swap_ {
					done_found = true
					done_val = glued
					left = l
					right = r
					count = r - l
				}
			}
			r--
		}
		l++
	}
	if !done_found {
		return matchers
	}
	mut next := []Matcher{}
	next << matchers[..left]
	next << done_val
	if right < matchers.len {
		next << matchers[right..]
	}
	if next.len == matchers.len {
		return next
	}
	return minimize_matchers(next)
}

// minimize_tree applies tree-level optimization to an AnyOf node.
fn minimize_tree(tree &Node) ?&Node {
	if tree.kind == .kind_any_of {
		return minimize_tree_any_of(tree)
	}
	return none
}

fn minimize_tree_any_of(tree &Node) ?&Node {
	if !are_of_same_kind(tree.children, .kind_pattern) {
		return none
	}
	common_left, common_right := common_children(tree.children)
	common_left_count := common_left.len
	common_right_count := common_right.len
	if common_left_count == 0 && common_right_count == 0 {
		return none
	}
	mut result := []&Node{}
	if common_left_count > 0 {
		result << new_node(.kind_pattern, none, common_left)
	}
	mut any_of := []&Node{}
	for child in tree.children {
		reuse := child.children[common_left_count..child.children.len - common_right_count]
		mut node := if reuse.len == 0 {
			new_node(.kind_nothing, none, [])
		} else {
			new_node(.kind_pattern, none, reuse)
		}
		any_of = append_if_unique(any_of, node)
	}
	if any_of.len == 1 && any_of[0].kind != .kind_nothing {
		result << any_of[0]
	} else if any_of.len > 1 {
		result << new_node(.kind_any_of, none, any_of)
	}
	if common_right_count > 0 {
		result << new_node(.kind_pattern, none, common_right)
	}
	return new_node(.kind_pattern, none, result)
}

fn common_children(nodes []&Node) ([]&Node, []&Node) {
	mut common_left := []&Node{}
	mut common_right := []&Node{}
	if nodes.len <= 1 {
		return common_left, common_right
	}
	idx := least_children(nodes)
	if idx == -1 {
		return common_left, common_right
	}
	tree := nodes[idx]
	tree_length := tree.children.len
	mut cr_template := []?&Node{len: tree_length, init: none}
	mut last_right := tree_length
	mut break_left := false
	mut break_right := false
	mut common_total := 0
	mut i := 0
	mut j := tree_length - 1
	for common_total < tree_length && j >= 0 && !(break_left && break_right) {
		tree_left := tree.children[i]
		tree_right := tree.children[j]
		mut k := 0
		for k < nodes.len && !(break_left && break_right) {
			if k == idx {
				k++
				continue
			}
			rest_left := nodes[k].children[i]
			rest_right := nodes[k].children[j + nodes[k].children.len - tree_length]
			if !break_left && !node_equal(tree_left, rest_left) {
				break_left = true
			}
			if !break_right && !break_left && j <= i {
				break_right = true
			}
			if !break_right && !node_equal(tree_right, rest_right) {
				break_right = true
			}
			k++
		}
		if !break_left {
			common_total++
			common_left << tree_left
		}
		if !break_right {
			common_total++
			last_right = j
			cr_template[j] = tree_right
		}
		i++
		j--
	}
	// cr_template positions [last_right..tree_length) were filled in decreasing
	// index order; collect them in forward order.
	for x := last_right; x < tree_length; x++ {
		if v := cr_template[x] {
			common_right << v
		}
	}
	return common_left, common_right
}

fn append_if_unique(target []&Node, val &Node) []&Node {
	mut out := target.clone()
	for n in target {
		if node_equal(n, val) {
			return out
		}
	}
	out << val
	return out
}

fn are_of_same_kind(nodes []&Node, kind Kind) bool {
	for n in nodes {
		if n.kind != kind {
			return false
		}
	}
	return true
}

fn least_children(nodes []&Node) int {
	mut min_ := -1
	mut idx := -1
	for i, n in nodes {
		if idx == -1 || n.children.len < min_ {
			min_ = n.children.len
			idx = i
		}
	}
	return idx
}

fn compile_tree_children(tree &Node, sep []rune) ![]Matcher {
	mut matchers := []Matcher{}
	for desc in tree.children {
		m := compile_node(desc, sep)!
		matchers << optimize_matcher(m)
	}
	return matchers
}

fn compile_node(tree &Node, sep []rune) !Matcher {
	if tree.kind == .kind_any_of {
		n := minimize_tree(tree)
		if nn := n {
			return compile_node(nn, sep)
		}
		matchers := compile_tree_children(tree, sep)!
		return Matcher(new_any_of(matchers))
	}
	mut m := Matcher(MNothing{})
	match tree.kind {
		.kind_pattern {
			if tree.children.len == 0 {
				return Matcher(new_nothing())
			}
			matchers := compile_tree_children(tree, sep)!
			m = compile_matchers(minimize_matchers(matchers))!
		}
		.kind_any {
			m = Matcher(new_any(sep))
		}
		.kind_super {
			m = Matcher(new_super())
		}
		.kind_single {
			m = Matcher(new_single(sep))
		}
		.kind_nothing {
			m = Matcher(new_nothing())
		}
		.kind_list {
			l := node_list_value(tree)
			m = Matcher(new_list(l.chars.runes(), l.not_))
		}
		.kind_range {
			r := node_range_value(tree)
			m = Matcher(new_range(r.lo, r.hi, r.not_))
		}
		.kind_text {
			t := node_text_value(tree)
			m = Matcher(new_text(t.text))
		}
		else {
			return error('could not compile tree: unknown node type')
		}
	}

	return optimize_matcher(m)
}

// compile_ast is the public entry point mirroring compiler.Compile.
fn compile_ast(tree &Node, sep []rune) !Matcher {
	return compile_node(tree, sep)
}

fn node_list_value(n &Node) NList {
	if v := n.value {
		if v is NList {
			return v
		}
	}
	return NList{false, ''}
}

fn node_range_value(n &Node) NRange {
	if v := n.value {
		if v is NRange {
			return v
		}
	}
	return NRange{false, rune(0), rune(0)}
}

fn node_text_value(n &Node) NText {
	if v := n.value {
		if v is NText {
			return v
		}
	}
	return NText{''}
}

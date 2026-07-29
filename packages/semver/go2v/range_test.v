module semver

import os
import rand

// assert_main_panics: see semver_test.v for rationale. Duplicated because V
// compiles each `*_test.v` independently. The temp dir is randomized so the
// test is safe under `v test`'s parallel per-file execution.
fn assert_main_panics(probe_body string) ! {
	vexe := @VEXE
	tmp := os.join_path(os.vtmp_dir(), 'semver_panic_probe_${rand.intn(1_000_000) or { 0 }}')
	os.rmdir_all(tmp) or {}
	os.mkdir_all(tmp)!
	defer {
		os.rmdir_all(tmp) or {}
	}
	mod_src_dir := os.join_path(tmp, 'semver')
	os.mkdir_all(mod_src_dir)!
	mod_dir := os.dir(@FILE)
	files := os.ls(mod_dir)!
	for f in files {
		if f.ends_with('.v') && !f.ends_with('_test.v') {
			os.cp(os.join_path(mod_dir, f), os.join_path(mod_src_dir, f))!
		}
	}
	os.write_file(os.join_path(tmp, 'v.mod'),
		"Module {\n\tname: 'probeproj'\n\tversion: '0.0.0'\n}\n")!
	main_src := 'module main\n\nimport semver\n\nfn main() {\n\t${probe_body}\n}\n'
	os.write_file(os.join_path(tmp, 'main.v'), main_src)!
	exe := os.join_path(tmp, 'probe_exe')
	comp := os.execute('${os.quoted_path(vexe)} -o ${os.quoted_path(exe)} ${os.quoted_path(tmp)}')
	assert comp.exit_code == 0, 'probe compilation failed: ${comp.output}'
	res := os.execute(os.quoted_path(exe))
	assert res.exit_code != 0, 'expected a panic, but the probe exited cleanly'
	assert res.output.contains('V panic'), 'expected a V panic in output, got: ${res.output}'
}

fn slice_eq(a []string, b []string) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

fn matrix_eq(a [][]string, b [][]string) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		if !slice_eq(a[i], b[i]) {
			return false
		}
	}
	return true
}

fn test_parse_comparator() {
	v1 := must_parse('1.2.2')
	v2 := must_parse('1.2.3')
	v3 := must_parse('1.2.4')

	// ">" -> GT
	if c := parse_comparator('>') {
		assert c(v2, v1) && c(v3, v2) && !c(v1, v2) && !c(v1, v1), 'invalid >'
	} else {
		assert false, 'Comparator nil for ">"'
	}
	// ">=" -> GE
	if c := parse_comparator('>=') {
		assert c(v2, v1) && c(v3, v2) && !c(v1, v2), 'invalid >='
	} else {
		assert false
	}
	// "<" -> LT
	if c := parse_comparator('<') {
		assert c(v1, v2) && c(v2, v3) && !c(v2, v1) && !c(v1, v1), 'invalid <'
	} else {
		assert false
	}
	// "<=" -> LE
	if c := parse_comparator('<=') {
		assert c(v1, v2) && c(v2, v3) && !c(v2, v1), 'invalid <='
	} else {
		assert false
	}
	// "" / "=" / "==" -> EQ
	for s in ['', '=', '=='] {
		if c := parse_comparator(s) {
			assert c(v1, v1) && !c(v1, v2), 'invalid ${s}'
		} else {
			assert false, 'Comparator nil for "${s}"'
		}
	}
	// "!=" / "!" -> NE
	for s in ['!=', '!'] {
		if c := parse_comparator(s) {
			assert !c(v1, v1) && c(v1, v2), 'invalid ${s}'
		} else {
			assert false
		}
	}
	// None cases
	for s in ['-', '<==', '<<', '>>'] {
		if _ := parse_comparator(s) {
			assert false, 'expected none comparator for "${s}"'
		}
	}
}

fn test_split_and_trim() {
	cases := [
		TupleSS{
			input: '1.2.3 1.2.3'
			out:   ['1.2.3', '1.2.3']
		},
		TupleSS{
			input: '     1.2.3     1.2.3     '
			out:   ['1.2.3', '1.2.3']
		},
		TupleSS{
			input: '  >=   1.2.3   <=  1.2.3   '
			out:   ['>=1.2.3', '<=1.2.3']
		},
		TupleSS{
			input: '1.2.3 || >=1.2.3 <1.2.3'
			out:   ['1.2.3', '||', '>=1.2.3', '<1.2.3']
		},
		TupleSS{
			input: '      1.2.3      ||     >=1.2.3     <1.2.3    '
			out:   ['1.2.3', '||', '>=1.2.3', '<1.2.3']
		},
	]
	for tc in cases {
		p := split_and_trim(tc.input)
		assert slice_eq(p, tc.out), 'Invalid for case "${tc.input}": Expected ${tc.out}, got: ${p}'
	}
}

struct TupleSS {
	input string
	out   []string
}

fn test_split_comparator_version() {
	cases := [
		TupleScv{
			input: '>1.2.3'
			parts: ['>', '1.2.3']
		},
		TupleScv{
			input: '>=1.2.3'
			parts: ['>=', '1.2.3']
		},
		TupleScv{
			input: '<1.2.3'
			parts: ['<', '1.2.3']
		},
		TupleScv{
			input: '<=1.2.3'
			parts: ['<=', '1.2.3']
		},
		TupleScv{
			input: '1.2.3'
			parts: ['', '1.2.3']
		},
		TupleScv{
			input: '=1.2.3'
			parts: ['=', '1.2.3']
		},
		TupleScv{
			input: '==1.2.3'
			parts: ['==', '1.2.3']
		},
		TupleScv{
			input: '!=1.2.3'
			parts: ['!=', '1.2.3']
		},
		TupleScv{
			input: '!1.2.3'
			parts: ['!', '1.2.3']
		},
		TupleScv{
			input: 'error'
			parts: []
		},
	]
	for tc in cases {
		if tc.parts.len == 0 {
			if _ := split_comparator_version(tc.input) {
				assert false, 'expected error for "${tc.input}"'
			}
		} else {
			sp := split_comparator_version(tc.input)!
			assert sp.op == tc.parts[0], 'op for "${tc.input}": expected "${tc.parts[0]}", got "${sp.op}"'
			assert sp.v == tc.parts[1], 'version for "${tc.input}": expected "${tc.parts[1]}", got "${sp.v}"'
		}
	}
}

struct TupleScv {
	input string
	parts []string
}

fn test_build_version_range() {
	v1 := must_parse('1.2.2')
	v2 := must_parse('1.2.3')
	v3 := must_parse('1.2.4')

	// Each case: (op, version, expected-version, expected-comparator-behaviour or none)
	cases := [
		BvrCase{'>', '1.2.3', '1.2.3', .gt},
		BvrCase{'>=', '1.2.3', '1.2.3', .ge},
		BvrCase{'<', '1.2.3', '1.2.3', .lt},
		BvrCase{'<=', '1.2.3', '1.2.3', .le},
		BvrCase{'', '1.2.3', '1.2.3', .eq},
		BvrCase{'=', '1.2.3', '1.2.3', .eq},
		BvrCase{'==', '1.2.3', '1.2.3', .eq},
		BvrCase{'!=', '1.2.3', '1.2.3', .ne},
		BvrCase{'!', '1.2.3', '1.2.3', .ne},
		BvrCase{'>>', '1.2.3', '', .none_kind},
		BvrCase{'=', 'invalid', '', .none_kind},
	]
	for tc in cases {
		r := build_version_range(tc.op, tc.version) or {
			assert tc.kind == .none_kind, 'unexpected error for "${tc.op}${tc.version}": ${err}'
			continue
		}
		tv := must_parse(tc.version_str)
		assert r.v.eq(tv), 'version for "${tc.op}${tc.version}": expected "${tv}", got "${r.v}"'
		match tc.kind {
			.eq { assert r.c(v1, v1) && !r.c(v1, v2), 'EQ bad for "${tc.op}"' }
			.ne { assert !r.c(v1, v1) && r.c(v1, v2), 'NE bad for "${tc.op}"' }
			.gt { assert r.c(v2, v1) && r.c(v3, v2) && !r.c(v1, v2) && !r.c(v1, v1), 'GT bad' }
			.ge { assert r.c(v2, v1) && r.c(v3, v2) && !r.c(v1, v2), 'GE bad' }
			.lt { assert r.c(v1, v2) && r.c(v2, v3) && !r.c(v2, v1) && !r.c(v1, v1), 'LT bad' }
			.le { assert r.c(v1, v2) && r.c(v2, v3) && !r.c(v2, v1), 'LE bad' }
			.none_kind { assert false, 'expected error for "${tc.op}${tc.version}"' }
		}
	}
}

enum BvrKind {
	eq
	ne
	gt
	ge
	lt
	le
	none_kind
}

struct BvrCase {
	op          string
	version     string
	version_str string
	kind        BvrKind
}

fn test_split_or_parts() {
	cases := [
		SopCase{
			input: ['>1.2.3', '||', '<1.2.3', '||', '=1.2.3']
			out:   [['>1.2.3'], ['<1.2.3'], ['=1.2.3']]
		},
		SopCase{
			input: ['>1.2.3', '<1.2.3', '||', '=1.2.3']
			out:   [['>1.2.3', '<1.2.3'], ['=1.2.3']]
		},
		SopCase{
			input: ['>1.2.3', '||']
			out:   []
		},
		SopCase{
			input: ['||', '>1.2.3']
			out:   []
		},
	]
	for tc in cases {
		o := split_or_parts(tc.input) or {
			assert tc.out.len == 0, 'unexpected error for ${tc.input}: ${err}'
			continue
		}
		assert matrix_eq(o, tc.out), 'invalid for ${tc.input}: expected ${tc.out}, got ${o}'
	}
}

struct SopCase {
	input []string
	out   [][]string
}

fn test_get_wildcard_type() {
	cases := [
		GwtCase{'x', .major_wildcard},
		GwtCase{'1.x', .minor_wildcard},
		GwtCase{'1.2.x', .patch_wildcard},
		GwtCase{'fo.o.b.ar', .none_wildcard},
	]
	for tc in cases {
		o := get_wildcard_type(tc.input)
		assert o == tc.expected, 'invalid for "${tc.input}": expected ${tc.expected}, got ${o}'
	}
}

struct GwtCase {
	input    string
	expected WildcardType
}

fn test_create_version_from_wildcard() {
	cases := [
		Tuple2{'1.2.x', '1.2.0'},
		Tuple2{'1.x', '1.0.0'},
	]
	for tc in cases {
		p := create_version_from_wildcard(tc.a)
		assert p == tc.b, 'invalid for "${tc.a}": expected "${tc.b}", got "${p}"'
	}
}

struct Tuple2 {
	a string
	b string
}

fn test_increment_major_version() {
	cases := [
		Tuple2{'1.2.3', '2.2.3'},
		Tuple2{'1.2', '2.2'},
		Tuple2{'foo.bar', ''},
	]
	for tc in cases {
		p := increment_major_version_str(tc.a) or { '' }
		assert p == tc.b, 'invalid for "${tc.a}": expected "${tc.b}", got "${p}"'
	}
}

fn test_increment_minor_version() {
	cases := [
		Tuple2{'1.2.3', '1.3.3'},
		Tuple2{'1.2', '1.3'},
		Tuple2{'foo.bar', ''},
	]
	for tc in cases {
		p := increment_minor_version_str(tc.a) or { '' }
		assert p == tc.b, 'invalid for "${tc.a}": expected "${tc.b}", got "${p}"'
	}
}

fn test_expand_wildcard_version() {
	cases := [
		EwcCase{
			input: [['foox']]
			out:   []
		},
		EwcCase{
			input: [['>=1.2.x']]
			out:   [['>=1.2.0']]
		},
		EwcCase{
			input: [['<=1.2.x']]
			out:   [['<1.3.0']]
		},
		EwcCase{
			input: [['>1.2.x']]
			out:   [['>=1.3.0']]
		},
		EwcCase{
			input: [['<1.2.x']]
			out:   [['<1.2.0']]
		},
		EwcCase{
			input: [['!=1.2.x']]
			out:   [['<1.2.0', '>=1.3.0']]
		},
		EwcCase{
			input: [['>=1.x']]
			out:   [['>=1.0.0']]
		},
		EwcCase{
			input: [['<=1.x']]
			out:   [['<2.0.0']]
		},
		EwcCase{
			input: [['>1.x']]
			out:   [['>=2.0.0']]
		},
		EwcCase{
			input: [['<1.x']]
			out:   [['<1.0.0']]
		},
		EwcCase{
			input: [['!=1.x']]
			out:   [['<1.0.0', '>=2.0.0']]
		},
		EwcCase{
			input: [['1.2.x']]
			out:   [['>=1.2.0', '<1.3.0']]
		},
		EwcCase{
			input: [['1.x']]
			out:   [['>=1.0.0', '<2.0.0']]
		},
	]
	for tc in cases {
		o := expand_wildcard_version(tc.input) or {
			assert tc.out.len == 0, 'unexpected error for ${tc.input}: ${err}'
			continue
		}
		assert matrix_eq(o, tc.out), 'invalid for ${tc.input}: expected ${tc.out}, got ${o}'
	}
}

struct EwcCase {
	input [][]string
	out   [][]string
}

fn test_version_range_to_range() {
	vr := VersionRange{
		v: must_parse('1.2.3')
		c: comp_lt
	}
	rf := vr.range_func()
	assert rf(must_parse('1.2.2'))
	assert !rf(must_parse('1.2.3'))
}

fn test_range_and() {
	v := must_parse('1.2.2')
	v1 := must_parse('1.2.1')
	v2 := must_parse('1.2.3')
	rf1 := Range(fn [v1] (x Version) bool {
		return x.gt(v1)
	})
	rf2 := Range(fn [v2] (x Version) bool {
		return x.lt(v2)
	})
	rf := rf1.and_(rf2)
	assert !rf(v1)
	assert !rf(v2)
	assert rf(v)
}

fn test_range_or() {
	v1 := must_parse('1.2.1')
	v2 := must_parse('1.2.3')
	rf1 := Range(fn [v1] (x Version) bool {
		return x.lt(v1)
	})
	rf2 := Range(fn [v2] (x Version) bool {
		return x.gt(v2)
	})
	rf := rf1.or_(rf2)
	cases := [
		TupleV{must_parse('1.2.0'), true},
		TupleV{must_parse('1.2.2'), false},
		TupleV{must_parse('1.2.4'), true},
	]
	for tc in cases {
		assert rf(tc.v) == tc.b, 'invalid for "${tc.v}": expected ${tc.b}'
	}
}

struct TupleV {
	v Version
	b bool
}

struct Tv {
	v string
	b bool
}

struct ParseRangeCase {
	i string
	t []Tv
}

fn parse_range_cases() []ParseRangeCase {
	return [
		// Simple expressions
		ParseRangeCase{
			i: '>1.2.3'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', false}, Tv{'1.2.4', true}]
		},
		ParseRangeCase{
			i: '>=1.2.3'
			t: [Tv{'1.2.3', true}, Tv{'1.2.4', true}, Tv{'1.2.2', false}]
		},
		ParseRangeCase{
			i: '<1.2.3'
			t: [Tv{'1.2.2', true}, Tv{'1.2.3', false}, Tv{'1.2.4', false}]
		},
		ParseRangeCase{
			i: '<=1.2.3'
			t: [Tv{'1.2.2', true}, Tv{'1.2.3', true}, Tv{'1.2.4', false}]
		},
		ParseRangeCase{
			i: '1.2.3'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', true}, Tv{'1.2.4', false}]
		},
		ParseRangeCase{
			i: '=1.2.3'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', true}, Tv{'1.2.4', false}]
		},
		ParseRangeCase{
			i: '==1.2.3'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', true}, Tv{'1.2.4', false}]
		},
		ParseRangeCase{
			i: '!=1.2.3'
			t: [Tv{'1.2.2', true}, Tv{'1.2.3', false}, Tv{'1.2.4', true}]
		},
		ParseRangeCase{
			i: '!1.2.3'
			t: [Tv{'1.2.2', true}, Tv{'1.2.3', false}, Tv{'1.2.4', true}]
		},
		// Simple Expression errors (Go test lists these with nil t; only asserted
		// when t is non-empty, matching the upstream semantics).
		ParseRangeCase{
			i: '>>1.2.3'
			t: []
		},
		ParseRangeCase{
			i: '!1.2.3'
			t: []
		},
		ParseRangeCase{
			i: '1.0'
			t: []
		},
		ParseRangeCase{
			i: 'string'
			t: []
		},
		ParseRangeCase{
			i: ''
			t: []
		},
		ParseRangeCase{
			i: 'fo.ob.ar.x'
			t: []
		},
		// AND Expressions
		ParseRangeCase{
			i: '>1.2.2 <1.2.4'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', true}, Tv{'1.2.4', false}]
		},
		ParseRangeCase{
			i: '<1.2.2 <1.2.4'
			t: [Tv{'1.2.1', true}, Tv{'1.2.2', false}, Tv{'1.2.3', false},
				Tv{'1.2.4', false}]
		},
		ParseRangeCase{
			i: '>1.2.2 <1.2.5 !=1.2.4'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', true}, Tv{'1.2.4', false},
				Tv{'1.2.5', false}]
		},
		ParseRangeCase{
			i: '>1.2.2 <1.2.5 !1.2.4'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', true}, Tv{'1.2.4', false},
				Tv{'1.2.5', false}]
		},
		// OR Expressions
		ParseRangeCase{
			i: '>1.2.2 || <1.2.4'
			t: [Tv{'1.2.2', true}, Tv{'1.2.3', true}, Tv{'1.2.4', true}]
		},
		ParseRangeCase{
			i: '<1.2.2 || >1.2.4'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', false}, Tv{'1.2.4', false}]
		},
		// Wildcard expressions
		ParseRangeCase{
			i: '>1.x'
			t: [Tv{'0.1.9', false}, Tv{'1.2.6', false}, Tv{'1.9.0', false},
				Tv{'2.0.0', true}]
		},
		ParseRangeCase{
			i: '>1.2.x'
			t: [Tv{'1.1.9', false}, Tv{'1.2.6', false}, Tv{'1.3.0', true}]
		},
		// Combined Expressions
		ParseRangeCase{
			i: '>1.2.2 <1.2.4 || >=2.0.0'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', true}, Tv{'1.2.4', false},
				Tv{'2.0.0', true}, Tv{'2.0.1', true}]
		},
		ParseRangeCase{
			i: '1.x || >=2.0.x <2.2.x'
			t: [Tv{'0.9.2', false}, Tv{'1.2.2', true}, Tv{'2.0.0', true},
				Tv{'2.1.8', true}, Tv{'2.2.0', false}]
		},
		ParseRangeCase{
			i: '>1.2.2 <1.2.4 || >=2.0.0 <3.0.0'
			t: [Tv{'1.2.2', false}, Tv{'1.2.3', true}, Tv{'1.2.4', false},
				Tv{'2.0.0', true}, Tv{'2.0.1', true}, Tv{'2.9.9', true},
				Tv{'3.0.0', false}]
		},
	]
}

fn test_parse_range() {
	for tc in parse_range_cases() {
		r := parse_range(tc.i) or {
			// Only an error is a failure when the case provides expected matches.
			assert tc.t.len == 0, 'Error parsing range "${tc.i}": ${err}'
			continue
		}
		for tvc in tc.t {
			v := must_parse(tvc.v)
			assert r(v) == tvc.b, 'Invalid for case "${tc.i}" matching "${tvc.v}": expected ${tvc.b}'
		}
	}
}

fn test_must_parse_range() {
	test_case := '>1.2.2 <1.2.4 || >=2.0.0 <3.0.0'
	r := must_parse_range(test_case)
	assert r(must_parse('1.2.3'))
}

fn test_must_parse_range_panic() {
	assert_main_panics('semver.must_parse_range("invalid version")')!
}

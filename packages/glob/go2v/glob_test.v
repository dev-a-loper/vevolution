module glob

// Faithful port of gobwas/glob/glob_test.go (TestGlob + TestQuoteMeta).
// Benchmarks are omitted (V `v test` does not run them).

const pattern_all = '[a-z][!a-x]*cat*[h][!b]*eyes*'
const fixture_all_match = 'my cat has very bright eyes'
const fixture_all_mismatch = 'my dog has very bright eyes'

const pattern_plain = 'google.com'
const fixture_plain_match = 'google.com'
const fixture_plain_mismatch = 'gobwas.com'

const pattern_multiple = 'https://*.google.*'
const fixture_multiple_match = 'https://account.google.com'
const fixture_multiple_mismatch = 'https://google.com'

const pattern_alternatives = '{https://*.google.*,*yandex.*,*yahoo.*,*mail.ru}'
const fixture_alternatives_match = 'http://yahoo.com'
const fixture_alternatives_mismatch = 'http://google.com'

const pattern_alternatives_suffix = '{https://*gobwas.com,http://exclude.gobwas.com}'
const fixture_alternatives_suffix_first_match = 'https://safe.gobwas.com'
const fixture_alternatives_suffix_first_mismatch = 'http://safe.gobwas.com'
const fixture_alternatives_suffix_second = 'http://exclude.gobwas.com'

const pattern_prefix = 'abc*'
const pattern_suffix = '*def'
const pattern_prefix_suffix = 'ab*ef'
const fixture_prefix_suffix_match = 'abcdef'
const fixture_prefix_suffix_mismatch = 'af'

const pattern_alternatives_combine_lite = '{abc*def,abc?def,abc[zte]def}'
const fixture_alternatives_combine_lite = 'abczdef'

const pattern_alternatives_combine_hard = '{abc*[a-c]def,abc?[d-g]def,abc[zte]?def}'
const fixture_alternatives_combine_hard = 'abczqdef'

struct GtCase {
	pattern string
	match   string
	should  bool
	delims  []rune
}

fn gcase(s bool, p string, m string, d ...rune) GtCase {
	return GtCase{
		should:  s
		pattern: p
		match:   m
		delims:  d
	}
}

fn test_glob() {
	cases := [
		gcase(true, '* ?at * eyes', 'my cat has very bright eyes'),
		gcase(true, '', ''),
		gcase(false, '', 'b'),
		gcase(true, '*ä', 'åä'),
		gcase(true, 'abc', 'abc'),
		gcase(true, 'a*c', 'abc'),
		gcase(true, 'a*c', 'a12345c'),
		gcase(true, 'a?c', 'a1c'),
		gcase(true, 'a.b', 'a.b', `.`),
		gcase(true, 'a.*', 'a.b', `.`),
		gcase(true, 'a.**', 'a.b.c', `.`),
		gcase(true, 'a.?.c', 'a.b.c', `.`),
		gcase(true, 'a.?.?', 'a.b.c', `.`),
		gcase(true, '?at', 'cat'),
		gcase(true, '?at', 'fat'),
		gcase(true, '*', 'abc'),
		gcase(true, r'\*', '*'),
		gcase(true, '**', 'a.b.c', `.`),
		gcase(false, '?at', 'at'),
		gcase(false, '?at', 'fat', `f`),
		gcase(false, 'a.*', 'a.b.c', `.`),
		gcase(false, 'a.?.c', 'a.bb.c', `.`),
		gcase(false, '*', 'a.b.c', `.`),
		gcase(true, '*test', 'this is a test'),
		gcase(true, 'this*', 'this is a test'),
		gcase(true, '*is *', 'this is a test'),
		gcase(true, '*is*a*', 'this is a test'),
		gcase(true, '**test**', 'this is a test'),
		gcase(true, '**is**a***test*', 'this is a test'),
		gcase(false, '*is', 'this is a test'),
		gcase(false, '*no*', 'this is a test'),
		gcase(true, '[!a]*', 'this is a test3'),
		gcase(true, '*abc', 'abcabc'),
		gcase(true, '**abc', 'abcabc'),
		gcase(true, '???', 'abc'),
		gcase(true, '?*?', 'abc'),
		gcase(true, '?*?', 'ac'),
		gcase(false, 'sta', 'stagnation'),
		gcase(true, 'sta*', 'stagnation'),
		gcase(false, 'sta?', 'stagnation'),
		gcase(false, 'sta?n', 'stagnation'),
		gcase(true, '{abc,def}ghi', 'defghi'),
		gcase(true, '{abc,abcd}a', 'abcda'),
		gcase(true, '{a,ab}{bc,f}', 'abc'),
		gcase(true, '{*,**}{a,b}', 'ab'),
		gcase(false, '{*,**}{a,b}', 'ac'),
		gcase(true, '/{rate,[a-z][a-z][a-z]}*', '/rate'),
		gcase(true, '/{rate,[0-9][0-9][0-9]}*', '/rate'),
		gcase(true, '/{rate,[a-z][a-z][a-z]}*', '/usd'),
		gcase(true, '{*.google.*,*.yandex.*}', 'www.google.com', `.`),
		gcase(true, '{*.google.*,*.yandex.*}', 'www.yandex.com', `.`),
		gcase(false, '{*.google.*,*.yandex.*}', 'yandex.com', `.`),
		gcase(false, '{*.google.*,*.yandex.*}', 'google.com', `.`),
		gcase(true, '{*.google.*,yandex.*}', 'www.google.com', `.`),
		gcase(true, '{*.google.*,yandex.*}', 'yandex.com', `.`),
		gcase(false, '{*.google.*,yandex.*}', 'www.yandex.com', `.`),
		gcase(false, '{*.google.*,yandex.*}', 'google.com', `.`),
		gcase(true, '*//{,*.}example.com', 'https://www.example.com'),
		gcase(true, '*//{,*.}example.com', 'http://example.com'),
		gcase(false, '*//{,*.}example.com', 'http://example.com.net'),
		gcase(true, pattern_all, fixture_all_match),
		gcase(false, pattern_all, fixture_all_mismatch),
		gcase(true, pattern_plain, fixture_plain_match),
		gcase(false, pattern_plain, fixture_plain_mismatch),
		gcase(true, pattern_multiple, fixture_multiple_match),
		gcase(false, pattern_multiple, fixture_multiple_mismatch),
		gcase(true, pattern_alternatives, fixture_alternatives_match),
		gcase(false, pattern_alternatives, fixture_alternatives_mismatch),
		gcase(true, pattern_alternatives_suffix, fixture_alternatives_suffix_first_match),
		gcase(false, pattern_alternatives_suffix, fixture_alternatives_suffix_first_mismatch),
		gcase(true, pattern_alternatives_suffix, fixture_alternatives_suffix_second),
		gcase(true, pattern_alternatives_combine_hard, fixture_alternatives_combine_hard),
		gcase(true, pattern_alternatives_combine_lite, fixture_alternatives_combine_lite),
		gcase(true, pattern_prefix, fixture_prefix_suffix_match),
		gcase(false, pattern_prefix, fixture_prefix_suffix_mismatch),
		gcase(true, pattern_suffix, fixture_prefix_suffix_match),
		gcase(false, pattern_suffix, fixture_prefix_suffix_mismatch),
		gcase(true, pattern_prefix_suffix, fixture_prefix_suffix_match),
		gcase(false, pattern_prefix_suffix, fixture_prefix_suffix_mismatch),
	]
	for tc in cases {
		g := must_compile(tc.pattern, ...tc.delims)
		result := g.matches(tc.match)
		assert result == tc.should, 'pattern `${tc.pattern}` matching `${tc.match}` should be ${tc.should} but got ${result}; matcher=${g.str()}'
	}
}

fn test_quote_meta() {
	cases := [
		GtCase2{
			in:  r'[foo*]'
			out: r'\[foo\*\]'
		},
		GtCase2{
			in:  r'{foo*}'
			out: r'\{foo\*\}'
		},
		GtCase2{
			in:  r'*?\[]{}'
			out: r'\*\?\\\[\]\{\}'
		},
		GtCase2{
			in:  r'some text and *?\[]{}'
			out: r'some text and \*\?\\\[\]\{\}'
		},
	]
	for id, tc in cases {
		act := quote_meta(tc.in)
		assert act == tc.out, '#${id} quote_meta(`${tc.in}`) = `${act}`; want `${tc.out}`'
		compile(act) or {
			assert false, '#${id} compile(quote_meta(`${tc.in}`)) err: ${err.str()}'
			continue
		}
	}
}

struct GtCase2 {
	in  string
	out string
}

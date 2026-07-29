// Port of convert_test.go.
module xstrings

fn test_to_snake_case_and_to_kebab_case() {
	mut cases := {
		'HTTPServer':                                           'http_server'
		'_camelCase':                                           '_camel_case'
		'NoHTTPS':                                              'no_https'
		'Wi_thF':                                               'wi_th_f'
		'_AnotherTES_TCaseP':                                   '_another_tes_t_case_p'
		'ALL':                                                  'all'
		'_HELLO_WORLD_':                                        '_hello_world_'
		'HELLO_WORLD':                                          'hello_world'
		'HELLO____WORLD':                                       'hello____world'
		'TW':                                                   'tw'
		'_C':                                                   '_c'
		'http2xx':                                              'http_2xx'
		'HTTP2XX':                                              'http2_xx'
		'HTTP20xOK':                                            'http_20x_ok'
		'HTTP20xStatus':                                        'http_20x_status'
		'HTTP-20xStatus':                                       'http_20x_status'
		'a':                                                    'a'
		'Duration2m3s':                                         'duration_2m3s'
		'Bld4Floor3rd':                                         'bld4_floor_3rd'
		' _-_ ':                                                '_____'
		'a1b2c3d':                                              'a_1b2c3d'
		'A//B%%2c':                                             'a//b%%2c'
		'HTTP状态码404/502Error':                               'http_状态码404/502_error'
		'中文(字符)':                                           '中文(字符)'
		'混合ABCWords与123数字456':                             '混合_abc_words_与123_数字456'
		'  sentence case  ':                                    '__sentence_case__'
		' Mixed-hyphen case _and SENTENCE_case and UPPER-case': '_mixed_hyphen_case__and_sentence_case_and_upper_case'
		'FROM CamelCase to snake/kebab-case':                   'from_camel_case_to_snake/kebab_case'
		'':                                                     ''
		'Abc�E�f�d�2�00z�ZZ�ZZ':                                'abc_�e�f�d_�2�00z_�zz�zz'
		'�����':                                                '�����'
		'abc_123_def':                                          'abc_123_def'
	}
	// snake case
	snake_cases := cases.clone()
	run_test_cases(to_snake_case, snake_cases)

	// kebab case: replace underscores with hyphens in the expected values.
	mut kebab_cases := map[string]string{}
	for k, v in cases {
		kebab_cases[k] = v.replace('_', '-')
	}
	run_test_cases(to_kebab_case, kebab_cases)
}

fn test_to_camel_case() {
	run_test_cases(to_camel_case, {
		'http_server':                        'httpServer'
		'_camel_case':                        '_camelCase'
		'no_https':                           'noHttps'
		'_complex__case_':                    '_complex_Case_'
		' complex -case ':                    ' complex Case '
		'all':                                'all'
		'GOLANG_IS_GREAT':                    'golangIsGreat'
		'GOLANG':                             'golang'
		'a':                                  'a'
		'好':                                 '好'
		'FROM CamelCase to snake/kebab-case': 'fromCamelCaseToSnake/kebabCase'
		'':                                   ''
	})
}

fn test_to_pascal_case() {
	run_test_cases(to_pascal_case, {
		'http_server':                        'HttpServer'
		'_camel_case':                        '_CamelCase'
		'no_https':                           'NoHttps'
		'_complex__case_':                    '_Complex_Case_'
		' complex -case ':                    ' Complex Case '
		'all':                                'All'
		'GOLANG_IS_GREAT':                    'GolangIsGreat'
		'GOLANG':                             'Golang'
		'a':                                  'A'
		'好':                                 '好'
		'FROM CamelCase to snake/kebab-case': 'FromCamelCaseToSnake/kebabCase'
		'':                                   ''
	})
}

fn test_swap_case() {
	run_test_cases(swap_case, {
		'swapCase': 'SWAPcASE'
		'Θ~λa云Ξπ': 'θ~ΛA云ξΠ'
		'a':        'A'
		'':         ''
	})
}

fn test_first_rune_to_upper() {
	run_test_cases(first_rune_to_upper, {
		'hello, world!': 'Hello, world!'
		'Hello, world!': 'Hello, world!'
		'你好，世界！':  '你好，世界！'
		'a':             'A'
		'':              ''
	})
}

fn test_first_rune_to_lower() {
	run_test_cases(first_rune_to_lower, {
		'hello, world!': 'hello, world!'
		'Hello, world!': 'hello, world!'
		'你好，世界！':  '你好，世界！'
		'a':             'a'
		'A':             'a'
		'':              ''
	})
}

// sort_runes returns the runes of s sorted by codepoint, joined back to a
// string. Mirrors Go's sort on the rune slice of the shuffled result.
fn sort_runes(s string) string {
	mut rs := s.runes().clone()
	rs.sort(a < b)
	return rs.map(it.str()).join('')
}

fn test_shuffle() {
	// Shuffle is non-deterministic; the runner checks the shuffled string has
	// the same runes (sorted) as the original.
	run_test_cases(fn (str string) string {
		s := shuffle(str)
		return sort_runes(s)
	}, {
		'':            ''
		'facgbheidjk': 'abcdefghijk'
		'尝试中文':    '中尝文试'
		'zh英文hun排': 'hhnuz排文英'
	})
}

// test_shuffle_source mirrors Go's testShuffleSource rand.Source.
struct TestShuffleSource {
mut:
	n int
}

// A generated random number sequence just for testing.
const test_shuffle_table = [
	i64(1874068156324778273),
	3328451335138149956,
	5263531936693774911,
	7955079406183515637,
	2703501726821866378,
	2740103009342231109,
	6941261091797652072,
	1905388747193831650,
	7981306761429961588,
	6426100070888298971,
	4831389563158288344,
	261049867304784443,
	1460320609597786623,
	5600924393587988459,
	8995016276575641803,
	732830328053361739,
	5486140987150761883,
	545291762129038907,
	6382800227808658932,
	2781055864473387780,
	1598098976185383115,
	4990765271833742716,
	5018949295715050020,
	2568779411109623071,
	3902890183311134652,
	4893789450120281907,
	2338498362660772719,
	2601737961087659062,
	7273596521315663110,
	3337066551442961397,
	8121576815539813105,
	2740376916591569721,
	8249030965139585917,
	898860202204764712,
	9010467728050264449,
	685213522303989579,
	2050257992909156333,
	6281838661429879825,
	2227583514184312746,
	2873287401706343734,
]!

fn (mut src TestShuffleSource) int63() i64 {
	v := test_shuffle_table[src.n % test_shuffle_table.len]
	src.n++
	return v
}

fn test_shuffle_source() {
	run_test_cases(fn (str string) string {
		mut src := TestShuffleSource{}
		return shuffle_source(str, mut src)
	}, {
		'':               ''
		'facgbheidjk':    'bkgfijached'
		'尝试中文怎么样': '怎试么中样尝文'
		'zh英文hun排':    'zuhh文n英排'
	})
}

fn test_successor() {
	run_test_cases(successor, {
		'':                            ''
		'abcd':                        'abce'
		'THX1138':                     'THX1139'
		'<<koala>>':                   '<<koalb>>'
		'1999zzz':                     '2000aaa'
		'ZZZ9999':                     'AAAA0000'
		'***':                         '**+'
		'来点中文试试':                '来点中文试诖'
		'中cZ英ZZ文zZ混9zZ9杂99进z位': '中dA英AA文aA混0aA0杂00进a位'
	})
}

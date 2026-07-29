// Port of format_test.go.
module xstrings

fn test_expand_tabs() {
	run_test_cases(fn (str string) string {
		input := split_helper(str)
		n := input[1].int()
		return expand_tabs_impl(input[0], n) or { err.msg() }
	}, {
		sep('a\tbc\tdef\tghij\tk', '4'):    'a   bc  def ghij    k'
		sep('abcdefg\thij\nk\tl', '4'):     'abcdefg hij\nk   l'
		sep('z中\t文\tw', '4'):             'z中 文  w'
		sep('abcdef', '4'):                 'abcdef'
		sep('abc\td\tef\tghij\nk\tl', '3'): 'abc   d  ef ghij\nk  l'
		sep('abc\td\tef\tghij\nk\tl', '1'): 'abc d ef ghij\nk l'
		sep('abc', '0'):                    'tab size must be positive'
		sep('abc', '-1'):                   'tab size must be positive'
	})
}

fn test_left_justify() {
	run_test_cases(fn (str string) string {
		input := split_helper(str)
		n := input[1].int()
		return left_justify(input[0], n, input[2])
	}, {
		sep('hello', '4', ' '):               'hello'
		sep('hello', '10', ' '):              'hello     '
		sep('hello', '10', '123'):            'hello12312'
		sep('hello中文test', '4', ' '):       'hello中文test'
		sep('hello中文test', '12', ' '):      'hello中文test '
		sep('hello中文test', '18', '测试！'): 'hello中文test测试！测试！测'
		sep('hello中文test', '0', '123'):     'hello中文test'
		sep('hello中文test', '18', ''):       'hello中文test'
	})
}

fn test_right_justify() {
	run_test_cases(fn (str string) string {
		input := split_helper(str)
		n := input[1].int()
		return right_justify(input[0], n, input[2])
	}, {
		sep('hello', '4', ' '):               'hello'
		sep('hello', '10', ' '):              '     hello'
		sep('hello', '10', '123'):            '12312hello'
		sep('hello中文test', '4', ' '):       'hello中文test'
		sep('hello中文test', '12', ' '):      ' hello中文test'
		sep('hello中文test', '18', '测试！'): '测试！测试！测hello中文test'
		sep('hello中文test', '0', '123'):     'hello中文test'
		sep('hello中文test', '18', ''):       'hello中文test'
	})
}

fn test_center() {
	run_test_cases(fn (str string) string {
		input := split_helper(str)
		n := input[1].int()
		return center(input[0], n, input[2])
	}, {
		sep('hello', '4', ' '):               'hello'
		sep('hello', '10', ' '):              '  hello   '
		sep('hello', '10', '123'):            '12hello123'
		sep('hello中文test', '4', ' '):       'hello中文test'
		sep('hello中文test', '12', ' '):      'hello中文test '
		sep('hello中文test', '18', '测试！'): '测试！hello中文test测试！测'
		sep('hello中文test', '0', '123'):     'hello中文test'
		sep('hello中文test', '18', ''):       'hello中文test'
	})
}

// Port of manipulate_test.go.
module xstrings

fn test_reverse() {
	run_test_cases(reverse, {
		'reverse string':     'gnirts esrever'
		'中文如何？':         '？何如文中'
		'中en文混~排怎样？a': 'a？样怎排~混文ne中'
	})
}

fn test_slice() {
	run_test_cases(fn (str string) string {
		strs := split_helper(str)
		start := strs[1].int()
		end := strs[2].int()
		return slice_impl(strs[0], start, end) or { err.msg() }
	}, {
		sep('abcdefghijk', '3', '8'):                'defgh'
		sep('来点中文如何？', '2', '7'):             '中文如何？'
		sep('中en文混~排总是少不了的a', '2', '8'):   'n文混~排总'
		sep('中en文混~排总是少不了的a', '0', '0'):   ''
		sep('中en文混~排总是少不了的a', '14', '14'): ''
		sep('中en文混~排总是少不了的a', '5', '-1'):  '~排总是少不了的a'
		sep('中en文混~排总是少不了的a', '14', '-1'): ''
		sep('let us slice out of range', '-3', '3'): 'out of range'
		sep('超出范围哦', '2', '6'):                 'out of range'
		sep("don't do this", '3', '2'):              'out of range'
		sep('千gan万de不piao要liang', '19', '19'):   'out of range'
	})
}

fn test_partition() {
	run_test_cases(fn (str string) string {
		input := split_helper(str)
		head, m, tail := partition(input[0], input[1])
		return sep(head, m, tail)
	}, {
		sep('hello', 'l'):                    sep('he', 'l', 'lo')
		sep('中文总少不了', '少'):            sep('中文总', '少', '不了')
		sep('z这个zh英文混排hao不', 'h英文'): sep('z这个z', 'h英文', '混排hao不')
		sep('边界tiao件zen能忘', '边界'):     sep('', '边界', 'tiao件zen能忘')
		sep('尾巴ye别忘le', '忘le'):          sep('尾巴ye别', '忘le', '')
		sep('hello', 'x'):                    sep('hello', '', '')
		sep('不是晩香玉', '晚'):              sep('不是晩香玉', '', '')
		sep('来ge混排ba', 'e 混'):            sep('来ge混排ba', '', '')
	})
}

fn test_last_partition() {
	run_test_cases(fn (str string) string {
		input := split_helper(str)
		head, m, tail := last_partition(input[0], input[1])
		return sep(head, m, tail)
	}, {
		sep('hello', 'l'):                          sep('hel', 'l', 'o')
		sep('少量中文总少不了', '少'):              sep('少量中文总', '少', '不了')
		sep('z这个zh英文ch英文混排hao不', 'h英文'): sep('z这个zh英文c', 'h英文',
			'混排hao不')
		sep('边界tiao件zen能忘边界', '边界'):       sep('边界tiao件zen能忘',
			'边界', '')
		sep('尾巴ye别忘le', '尾巴'):                sep('', '尾巴', 'ye别忘le')
		sep('hello', 'x'):                          sep('', '', 'hello')
		sep('不是晩香玉', '晚'):                    sep('', '', '不是晩香玉')
		sep('来ge混排ba', 'e 混'):                  sep('', '', '来ge混排ba')
	})
}

fn test_insert() {
	run_test_cases(fn (str string) string {
		strs := split_helper(str)
		index := strs[2].int()
		return insert_safe(strs[0], strs[1], index) or { err.msg() }
	}, {
		sep('abcdefg', 'hi', '3'):                'abchidefg'
		sep('少量中文是必须的', '混pai', '4'):    '少量中文混pai是必须的'
		sep('zh英文hun排', '~！', '5'):           'zh英文h~！un排'
		sep('插在beginning', '我', '0'):          '我插在beginning'
		sep('插在ending', '我', '8'):             '插在ending我'
		sep('超tian出yuan边tu界po', 'foo', '-1'): 'out of range'
		sep('超tian出yuan边tu界po', 'foo', '17'): 'out of range'
	})
}

fn test_scrub() {
	run_test_cases(fn (str string) string {
		strs := split_helper(str)
		return scrub(strs[0], strs[1])
	}, {
		sep('ab�cd\xFF\xCEefg\xFF\xFC\xFD\xFAhijk', '*'): 'ab*cd*efg*hijk'
		sep('no错误です', '*'):                           'no错误です'
		sep('', '*'):                                     ''
	})
}

fn test_word_split() {
	run_test_cases(fn (str string) string {
		return sep(...word_split(str))
	}, {
		'one word':                   sep('one', 'word')
		'一个字：把他给我拿下！':     ''
		"it's a super-fancy one!!!a": sep("it's", 'a', 'super-fancy', 'one', 'a')
		"a -b-c' 'd'e":               sep('a', "b-c'", "d'e")
	})
}

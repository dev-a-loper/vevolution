// Port of count_test.go.
module xstrings

fn test_len() {
	run_test_cases(fn (str string) string {
		return rune_len(str).str()
	}, {
		'abcdef':       '6'
		'中文':         '2'
		'中yin文hun排': '9'
		'':             '0'
	})
}

fn test_word_count() {
	run_test_cases(fn (str string) string {
		return word_count(str).str()
	}, {
		'one word: λ':             '3'
		'中文':                    '0'
		'你好，sekai！':           '1'
		"oh, it's super-fancy!!a": '4'
		'':                        '0'
		'-':                       '0'
		"it's-'s":                 '1'
	})
}

fn test_width() {
	run_test_cases(fn (str string) string {
		return width(str).str()
	}, {
		'abcd\t0123\n7890': '12'
		'中zh英eng文混排':  '15'
		'':                 '0'
	})
}

fn test_rune_width() {
	run_test_cases(fn (str string) string {
		return rune_width(str.runes()[0]).str()
	}, {
		'a':    '1'
		'中':   '2'
		'\x11': '0'
	})
}

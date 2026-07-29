// stripansi_test — author-written tests (there is no upstream test suite).
// Cases derived from standard ANSI escape behaviour the original regex targets.
module stripansi

fn test_strips_sgr_color() {
	// ESC[31m ... ESC[0m
	assert strip('\x1b[31mred\x1b[0m') == 'red'
}

fn test_strips_sgr_with_params() {
	assert strip('\x1b[1;32mgreen\x1b[0m') == 'green'
}

fn test_keeps_plain() {
	assert strip('plain text') == 'plain text'
	assert strip('') == ''
}

fn test_strips_osc_bel() {
	// OSC setting window title, terminated by BEL
	assert strip('\x1b]0;the title\x07after') == 'after'
}

fn test_strips_osc_st() {
	// OSC terminated by ST (ESC '\')
	assert strip('\x1b]2;win\x1b\\done') == 'done'
}

fn test_strips_multiple() {
	assert strip('\x1b[1mbold\x1b[22m and \x1b[4munder\x1b[24m') == 'bold and under'
}

fn test_empty_sequence_body() {
	// ESC[m with no params (reset)
	assert strip('\x1b[mreset') == 'reset'
}

fn test_strips_cursor_moves() {
	// cursor up: ESC[A
	assert strip('a\x1b[2Ab') == 'ab'
}

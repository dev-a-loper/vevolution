// stripansi — V port of github.com/acarl005/stripansi.
//
// The Go original strips ANSI escape sequences with one big regexp. V's `regex`
// engine cannot match that pattern (it compiles but never matches — see
// docs/GO2V_GAPS.md), so this port uses a byte-level scanner that recognises the
// standard ANSI/ECMA-48 escape forms (CSI and OSC) the regex was built to catch.
// There is no upstream test suite, so tests here are authored from the documented
// behaviour of ANSI escapes.
module stripansi

import strings

// strip removes ANSI escape sequences from `str` and returns the visible text.
pub fn strip(str string) string {
	b := str.bytes()
	n := b.len
	if n == 0 {
		return ''
	}
	mut out := strings.new_builder(n)
	mut i := 0
	for i < n {
		c := b[i]
		if c == 0x1b {
			// ESC: start of an escape sequence
			if i + 1 < n {
				next := b[i + 1]
				if next == `[` {
					// CSI: ESC [ <params 0x30-0x3f> <intermediates 0x20-0x2f> <final 0x40-0x7e>
					i += 2
					for i < n && ((b[i] >= 0x30 && b[i] <= 0x3f) || (b[i] >= 0x20 && b[i] <= 0x2f)) {
						i++
					}
					if i < n && b[i] >= 0x40 && b[i] <= 0x7e {
						i++
					}
					continue
				} else if next == `]` {
					// OSC: ESC ] ... terminated by BEL (0x07) or ST (ESC '\')
					i += 2
					mut done := false
					for i < n && b[i] != 0x07 {
						if b[i] == 0x1b && i + 1 < n && b[i + 1] == `\\` {
							i += 2
							done = true
							break
						}
						i++
					}
					if !done && i < n && b[i] == 0x07 {
						i++
					}
					continue
				}
			}
			// Lone ESC not followed by a recognised introducer is kept.
			out.write_u8(c)
			i++
		} else if c == 0x9b {
			// 8-bit CSI single-byte form.
			i++
			for i < n && ((b[i] >= 0x30 && b[i] <= 0x3f) || (b[i] >= 0x20 && b[i] <= 0x2f)) {
				i++
			}
			if i < n && b[i] >= 0x40 && b[i] <= 0x7e {
				i++
			}
		} else {
			out.write_u8(c)
			i++
		}
	}
	return out.str()
}

module humanize

// ordinal gives the input number in a rank/ordinal form.
//
// e.g. ordinal(3) -> "3rd"
pub fn ordinal(x int) string {
	mut suffix := 'th'
	match x % 10 {
		1 {
			if x % 100 != 11 {
				suffix = 'st'
			}
		}
		2 {
			if x % 100 != 12 {
				suffix = 'nd'
			}
		}
		3 {
			if x % 100 != 13 {
				suffix = 'rd'
			}
		}
		else {}
	}

	return x.str() + suffix
}

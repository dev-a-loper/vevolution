module humanize

import strings
import time

// Seconds-based time units. Mirrors the const block in times.go. Spelled as
// explicit Duration (i64 nanoseconds) values so they are unambiguous
// compile-time constants.
pub const day = time.Duration(86_400_000_000_000)
pub const week = time.Duration(604_800_000_000_000)
pub const month = time.Duration(2_592_000_000_000_000)
pub const year = time.Duration(31_104_000_000_000_000)
pub const long_time = time.Duration(1_150_848_000_000_000_000)

// RelTimeMagnitude contains a relative time point at which the relative format
// of time switches to a new format string. Mirrors `RelTimeMagnitude` in
// times.go.
pub struct RelTimeMagnitude {
pub:
	d      time.Duration
	format string
	div_by time.Duration
}

// default_magnitudes mirrors `defaultMagnitudes` in times.go.
const default_magnitudes = [
	RelTimeMagnitude{time.second, 'now', time.second},
	RelTimeMagnitude{2 * time.second, '1 second %s', 1},
	RelTimeMagnitude{time.minute, '%d seconds %s', time.second},
	RelTimeMagnitude{2 * time.minute, '1 minute %s', 1},
	RelTimeMagnitude{time.hour, '%d minutes %s', time.minute},
	RelTimeMagnitude{2 * time.hour, '1 hour %s', 1},
	RelTimeMagnitude{day, '%d hours %s', time.hour},
	RelTimeMagnitude{2 * day, '1 day %s', 1},
	RelTimeMagnitude{week, '%d days %s', day},
	RelTimeMagnitude{2 * week, '1 week %s', 1},
	RelTimeMagnitude{month, '%d weeks %s', week},
	RelTimeMagnitude{2 * month, '1 month %s', 1},
	RelTimeMagnitude{year, '%d months %s', month},
	RelTimeMagnitude{18 * month, '1 year %s', 1},
	RelTimeMagnitude{2 * year, '2 years %s', 1},
	RelTimeMagnitude{long_time, '%d years %s', year},
	RelTimeMagnitude{max_i64, 'a long while %s', 1},
]

// time_relative formats a time into a relative string.
//
// e.g. time_relative(someT) -> "3 weeks ago"
pub fn time_relative(then time.Time) string {
	return rel_time(then, time.now(), 'ago', 'from now')
}

// rel_time formats a time into a relative string.
//
// e.g. rel_time(timeInPast, timeInFuture, "earlier", "later") -> "3 weeks earlier"
pub fn rel_time(a time.Time, b time.Time, albl string, blbl string) string {
	return custom_rel_time(a, b, albl, blbl, default_magnitudes)
}

// apply_rel_format substitutes %s with lbl and %d with num in the format string
// (mirroring `fmt.Sprintf(mag.Format, args...)` from times.go, which only ever
// uses %s and %d in that order).
fn apply_rel_format(format string, lbl string, num i64) string {
	mut sb := strings.new_builder(format.len + 16)
	bs := format.bytes()
	mut i := 0
	for i < bs.len {
		if bs[i] == `%` && i + 1 < bs.len {
			match bs[i + 1] {
				`s` {
					sb.write_string(lbl)
				}
				`d` {
					sb.write_string(num.str())
				}
				else {
					sb.write_u8(bs[i])
					sb.write_u8(bs[i + 1])
				}
			}

			i += 2
		} else {
			sb.write_u8(bs[i])
			i++
		}
	}
	return sb.str()
}

// custom_rel_time formats a time into a relative string using the supplied
// magnitudes table.
pub fn custom_rel_time(a time.Time, b time.Time, albl string, blbl string, magnitudes []RelTimeMagnitude) string {
	mut lbl := albl
	mut diff := b - a
	// a.After(b) == (b < a)
	if b < a {
		lbl = blbl
		diff = a - b
	}

	// Find smallest n with magnitudes[n].d > diff (equivalent to sort.Search).
	mut n := 0
	for n < magnitudes.len {
		if magnitudes[n].d > diff {
			break
		}
		n++
	}
	if n >= magnitudes.len {
		n = magnitudes.len - 1
	}
	mag := magnitudes[n]

	num := i64(diff) / i64(mag.div_by)
	return apply_rel_format(mag.format, lbl, num)
}

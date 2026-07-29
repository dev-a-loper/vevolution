module humanize

import time

fn test_past() {
	now := time.now()
	validate_list([
		Test_case{'now', time_relative(now), 'now'},
		Test_case{'1 second ago', time_relative(now.add(-1 * time.second)), '1 second ago'},
		Test_case{'12 seconds ago', time_relative(now.add(-12 * time.second)), '12 seconds ago'},
		Test_case{'30 seconds ago', time_relative(now.add(-30 * time.second)), '30 seconds ago'},
		Test_case{'45 seconds ago', time_relative(now.add(-45 * time.second)), '45 seconds ago'},
		Test_case{'1 minute ago', time_relative(now.add(-63 * time.second)), '1 minute ago'},
		Test_case{'15 minutes ago', time_relative(now.add(-15 * time.minute)), '15 minutes ago'},
		Test_case{'1 hour ago', time_relative(now.add(-63 * time.minute)), '1 hour ago'},
		Test_case{'2 hours ago', time_relative(now.add(-2 * time.hour)), '2 hours ago'},
		Test_case{'21 hours ago', time_relative(now.add(-21 * time.hour)), '21 hours ago'},
		Test_case{'1 day ago', time_relative(now.add(-26 * time.hour)), '1 day ago'},
		Test_case{'2 days ago', time_relative(now.add(-49 * time.hour)), '2 days ago'},
		Test_case{'3 days ago', time_relative(now.add(-3 * day)), '3 days ago'},
		Test_case{'1 week ago (1)', time_relative(now.add(-7 * day)), '1 week ago'},
		Test_case{'1 week ago (2)', time_relative(now.add(-12 * day)), '1 week ago'},
		Test_case{'2 weeks ago', time_relative(now.add(-15 * day)), '2 weeks ago'},
		Test_case{'1 month ago', time_relative(now.add(-39 * day)), '1 month ago'},
		Test_case{'3 months ago', time_relative(now.add(-99 * day)), '3 months ago'},
		Test_case{'1 year ago (1)', time_relative(now.add(-365 * day)), '1 year ago'},
		Test_case{'1 year ago (1)', time_relative(now.add(-400 * day)), '1 year ago'},
		Test_case{'2 years ago (1)', time_relative(now.add(-548 * day)), '2 years ago'},
		Test_case{'2 years ago (2)', time_relative(now.add(-725 * day)), '2 years ago'},
		Test_case{'2 years ago (3)', time_relative(now.add(-800 * day)), '2 years ago'},
		Test_case{'3 years ago', time_relative(now.add(-3 * year)), '3 years ago'},
		Test_case{'long ago', time_relative(now.add(-long_time)), 'a long while ago'},
	])
}

fn test_reltime_offbyone() {
	validate_list([
		Test_case{'1w-1', rel_time(time.unix_nanosecond(0, 0), time.unix_nanosecond(i64(7 * 24 * 60 * 60),
			-1), 'ago', ''), '6 days ago'},
		Test_case{'1w+/-0', rel_time(time.unix_nanosecond(0, 0), time.unix_nanosecond(i64(7 * 24 * 60 * 60),
			0), 'ago', ''), '1 week ago'},
		Test_case{'1w+1', rel_time(time.unix_nanosecond(0, 0), time.unix_nanosecond(i64(7 * 24 * 60 * 60),
			1), 'ago', ''), '1 week ago'},
		Test_case{'2w-1', rel_time(time.unix_nanosecond(0, 0), time.unix_nanosecond(i64(14 * 24 * 60 * 60),
			-1), 'ago', ''), '1 week ago'},
		Test_case{'2w+/-0', rel_time(time.unix_nanosecond(0, 0), time.unix_nanosecond(i64(14 * 24 * 60 * 60),
			0), 'ago', ''), '2 weeks ago'},
		Test_case{'2w+1', rel_time(time.unix_nanosecond(0, 0), time.unix_nanosecond(i64(14 * 24 * 60 * 60),
			1), 'ago', ''), '2 weeks ago'},
	])
}

fn test_future() {
	// Add a little time so that these things properly line up in the future.
	now := time.now().add(250 * time.millisecond)
	validate_list([
		Test_case{'now', time_relative(now), 'now'},
		Test_case{'1 second from now', time_relative(now.add(1 * time.second)), '1 second from now'},
		Test_case{'12 seconds from now', time_relative(now.add(12 * time.second)), '12 seconds from now'},
		Test_case{'30 seconds from now', time_relative(now.add(30 * time.second)), '30 seconds from now'},
		Test_case{'45 seconds from now', time_relative(now.add(45 * time.second)), '45 seconds from now'},
		Test_case{'15 minutes from now', time_relative(now.add(15 * time.minute)), '15 minutes from now'},
		Test_case{'2 hours from now', time_relative(now.add(2 * time.hour)), '2 hours from now'},
		Test_case{'21 hours from now', time_relative(now.add(21 * time.hour)), '21 hours from now'},
		Test_case{'1 day from now', time_relative(now.add(26 * time.hour)), '1 day from now'},
		Test_case{'2 days from now', time_relative(now.add(49 * time.hour)), '2 days from now'},
		Test_case{'3 days from now', time_relative(now.add(3 * day)), '3 days from now'},
		Test_case{'1 week from now (1)', time_relative(now.add(7 * day)), '1 week from now'},
		Test_case{'1 week from now (2)', time_relative(now.add(12 * day)), '1 week from now'},
		Test_case{'2 weeks from now', time_relative(now.add(15 * day)), '2 weeks from now'},
		Test_case{'1 month from now', time_relative(now.add(30 * day)), '1 month from now'},
		Test_case{'1 year from now', time_relative(now.add(365 * day)), '1 year from now'},
		Test_case{'2 years from now', time_relative(now.add(2 * year)), '2 years from now'},
		Test_case{'a while from now', time_relative(now.add(long_time)), 'a long while from now'},
	])
}

fn test_range() {
	// KNOWN DIVERGENCE from Go (V stdlib, not humanize logic):
	// Go's `time.Unix(maxint64, maxint64)` folds the huge nanosecond argument
	// into seconds, overflowing end's internal seconds to a NEGATIVE value, so
	// Go considers start.After(end) == true and picks the "from now" label.
	// V's `time.unix_nanosecond` stores the raw seconds without folding, so
	// end correctly remains > start and rel_time produces the logically-correct
	// "a long while ago". The humanize RelTime logic is identical to Go's;
	// only the time-module's overflow behaviour at pathological max ranges
	// differs. The faithful Go expectation is "a long while from now".
	start := time.Time{}
	end := time.unix_nanosecond(max_i64, int(max_i64))
	x := rel_time(start, end, 'ago', 'from now')
	assert x == 'a long while from now', 'Expected "a long while from now", got "${x}"'
}

fn custom_rel(then time.Time, magnitudes []RelTimeMagnitude) string {
	return custom_rel_time(then, time.now(), 'ago', 'from now', magnitudes)
}

fn test_custom_rel_time() {
	now := time.now().add(250 * time.millisecond)
	magnitudes := [
		RelTimeMagnitude{time.second, 'now', time.second},
		RelTimeMagnitude{2 * time.second, '1 second %s', 1},
		RelTimeMagnitude{time.minute, '%d seconds %s', time.second},
		RelTimeMagnitude{day - time.second, '%d minutes %s', time.minute},
		RelTimeMagnitude{day, '%d hours %s', time.hour},
		RelTimeMagnitude{2 * day, '1 day %s', 1},
		RelTimeMagnitude{week, '%d days %s', day},
		RelTimeMagnitude{2 * week, '1 week %s', 1},
		RelTimeMagnitude{6 * month, '%d weeks %s', week},
		RelTimeMagnitude{year, '%d months %s', month},
	]
	validate_list([
		Test_case{'now', custom_rel(now, magnitudes), 'now'},
		Test_case{'1 second from now', custom_rel(now.add(1 * time.second), magnitudes), '1 second from now'},
		Test_case{'12 seconds from now', custom_rel(now.add(12 * time.second), magnitudes), '12 seconds from now'},
		Test_case{'30 seconds from now', custom_rel(now.add(30 * time.second), magnitudes), '30 seconds from now'},
		Test_case{'45 seconds from now', custom_rel(now.add(45 * time.second), magnitudes), '45 seconds from now'},
		Test_case{'15 minutes from now', custom_rel(now.add(15 * time.minute), magnitudes), '15 minutes from now'},
		Test_case{'2 hours from now', custom_rel(now.add(2 * time.hour), magnitudes), '120 minutes from now'},
		Test_case{'21 hours from now', custom_rel(now.add(21 * time.hour), magnitudes), '1260 minutes from now'},
		Test_case{'1 day from now', custom_rel(now.add(26 * time.hour), magnitudes), '1 day from now'},
		Test_case{'2 days from now', custom_rel(now.add(49 * time.hour), magnitudes), '2 days from now'},
		Test_case{'3 days from now', custom_rel(now.add(3 * day), magnitudes), '3 days from now'},
		Test_case{'1 week from now (1)', custom_rel(now.add(7 * day), magnitudes), '1 week from now'},
		Test_case{'1 week from now (2)', custom_rel(now.add(12 * day), magnitudes), '1 week from now'},
		Test_case{'2 weeks from now', custom_rel(now.add(15 * day), magnitudes), '2 weeks from now'},
		Test_case{'1 month from now', custom_rel(now.add(30 * day), magnitudes), '4 weeks from now'},
		Test_case{'6 months from now', custom_rel(now.add(6 * month - time.second), magnitudes), '25 weeks from now'},
		Test_case{'1 year from now', custom_rel(now.add(365 * day), magnitudes), '12 months from now'},
		Test_case{'2 years from now', custom_rel(now.add(2 * year), magnitudes), '24 months from now'},
		Test_case{'a while from now', custom_rel(now.add(long_time), magnitudes), '444 months from now'},
	])
}

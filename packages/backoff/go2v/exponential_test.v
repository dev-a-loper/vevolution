module backoff

import time

fn assert_eq_duration(expected time.Duration, value time.Duration) string {
	if expected != value {
		return 'got: ${value}, expected: ${expected}'
	}
	return ''
}

fn test_back_off() {
	test_initial_interval := 500 * time.millisecond
	test_randomization_factor := 0.1
	test_multiplier := 2.0
	test_max_interval := 5 * time.second

	mut exp := new_exponential_back_off()
	exp.initial_interval = test_initial_interval
	exp.randomization_factor = test_randomization_factor
	exp.multiplier = test_multiplier
	exp.max_interval = test_max_interval
	exp.reset()

	expected_results := [
		time.Duration(500 * time.millisecond),
		time.Duration(1000 * time.millisecond),
		time.Duration(2000 * time.millisecond),
		time.Duration(4000 * time.millisecond),
		time.Duration(5000 * time.millisecond),
		time.Duration(5000 * time.millisecond),
		time.Duration(5000 * time.millisecond),
		time.Duration(5000 * time.millisecond),
		time.Duration(5000 * time.millisecond),
		time.Duration(5000 * time.millisecond),
	]

	for expected in expected_results {
		assert exp.current_interval == expected, assert_eq_duration(expected, exp.current_interval)
		// Assert that the next backoff falls in the expected range.
		min_interval := expected - time.Duration(test_randomization_factor * f64(expected))
		max_interval := expected + time.Duration(test_randomization_factor * f64(expected))
		actual_interval := exp.next_back_off()
		assert min_interval <= actual_interval && actual_interval <= max_interval, 'out of range: ${actual_interval} not in [${min_interval}, ${max_interval}]'
	}
}

fn test_get_randomized_interval() {
	// 33% chance of being 1.
	assert get_random_value_from_interval(0.5, 0, 2) == 1, '1a'
	assert get_random_value_from_interval(0.5, 0.33, 2) == 1, '1b'
	// 33% chance of being 2.
	assert get_random_value_from_interval(0.5, 0.34, 2) == 2, '2a'
	assert get_random_value_from_interval(0.5, 0.66, 2) == 2, '2b'
	// 33% chance of being 3.
	assert get_random_value_from_interval(0.5, 0.67, 2) == 3, '3a'
	assert get_random_value_from_interval(0.5, 0.99, 2) == 3, '3b'
}

fn test_back_off_overflow() {
	test_initial_interval := time.Duration(max_i64 / 2)
	test_max_interval := time.Duration(max_i64)
	test_multiplier := 2.1

	mut exp := new_exponential_back_off()
	exp.initial_interval = test_initial_interval
	exp.multiplier = test_multiplier
	exp.max_interval = test_max_interval
	exp.reset()

	exp.next_back_off()
	// Assert that when an overflow is possible, the current interval is set to
	// the max interval.
	assert exp.current_interval == test_max_interval, assert_eq_duration(test_max_interval,
		exp.current_interval)
}

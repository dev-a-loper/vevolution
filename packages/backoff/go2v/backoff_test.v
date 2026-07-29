module backoff

import time

fn subtest_next_back_off(expected_value time.Duration, mut policy BackOff) {
	for _ in 0 .. 10 {
		next := policy.next_back_off()
		assert next == expected_value, 'got: ${next} expected: ${expected_value}'
	}
}

fn test_next_back_off_millis() {
	mut z := &ZeroBackOff{}
	subtest_next_back_off(time.Duration(0), mut z)
	mut s := &StopBackOff{}
	subtest_next_back_off(stop, mut s)
}

fn test_constant_back_off() {
	mut bo := new_constant_back_off(time.second)
	assert bo.next_back_off() == time.second, 'invalid interval'
}

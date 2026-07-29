module backoff

import context

// WithMaxTries(n) runs the operation exactly n times (total attempts, not
// retries) and then stops with Cause ErrExhausted.
fn test_retry_max_tries_count() {
	for n in [u32(1), u32(2), u32(5)] {
		mut st := &CallsState{}
		f := fn [mut st] () Outcome[int] {
			st.calls++
			return Outcome[int]{
				value: 0
				err:   error('boom')
			}
		}
		res := retry(context.background(), f, with_max_tries(n), with_back_off(&ZeroBackOff{}),
			with_max_elapsed_time(0), with_timer(&TestTimer{}))
		assert st.calls == int(n), 'WithMaxTries(${n}): operation called ${st.calls} times, want ${n}'
		assert errors_is(res.err, err_exhausted), 'WithMaxTries(${n}): Cause not ErrExhausted'
	}
}

// The default, WithMaxTries(0), imposes no attempt limit: Retry keeps trying
// until the operation succeeds.
fn test_retry_max_tries_unlimited() {
	success_on := 6
	mut st := &CallsState{}
	f := fn [mut st, success_on] () Outcome[int] {
		st.calls++
		if st.calls == success_on {
			return Outcome[int]{
				value: 42
				err:   none
			}
		}
		return Outcome[int]{
			value: 0
			err:   error('boom')
		}
	}
	res := retry(context.background(), f, with_max_tries(0), with_back_off(&ZeroBackOff{}),
		with_max_elapsed_time(0), with_timer(&TestTimer{}))
	assert res.err is none, 'unexpected error: ${res.err}'
	assert st.calls == success_on, 'operation called ${st.calls} times, want ${success_on}'
	assert res.value == 42, 'res = ${res.value}, want 42'
}

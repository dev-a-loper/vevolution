module backoff

import context
import time

fn test_retry() {
	success_on := 3
	mut st := &IState{}

	// This function is successful on "successOn" calls.
	f := fn [mut st, success_on] () Outcome[bool] {
		st.i++
		if st.i == success_on {
			return Outcome[bool]{
				value: true
				err:   none
			}
		}
		return Outcome[bool]{
			value: false
			err:   error('error')
		}
	}

	res := retry(context.background(), f, with_back_off(new_exponential_back_off()),
		with_timer(&TestTimer{}))
	assert res.err is none, 'unexpected error: ${res.err}'
	assert st.i == success_on, 'invalid number of retries: ${st.i}'
}

fn test_retry_with_data() {
	success_on := 3
	mut st := &IState{}

	f := fn [mut st, success_on] () Outcome[int] {
		st.i++
		if st.i == success_on {
			return Outcome[int]{
				value: 42
				err:   none
			}
		}
		return Outcome[int]{
			value: 1
			err:   error('error')
		}
	}

	res := retry(context.background(), f, with_back_off(new_exponential_back_off()),
		with_timer(&TestTimer{}))
	assert res.err is none, 'unexpected error: ${res.err}'
	assert st.i == success_on, 'invalid number of retries: ${st.i}'
	assert res.value == 42, 'invalid data in response: ${res.value}, expected 42'
}

fn test_retry_context() {
	cancel_on := 3
	mut st := &IState{}

	mut bg := context.background()
	mut ctx, cancel := context.with_cancel_cause(mut bg)
	expected_err := error('custom error')

	// This function cancels context on "cancelOn" calls.
	f := fn [mut st, cancel_on, cancel, expected_err] () Outcome[bool] {
		st.i++
		if st.i == cancel_on {
			cancel(expected_err)
		}
		return Outcome[bool]{
			value: false
			err:   error('error (${st.i})')
		}
	}

	defer {
		cancel(context.canceled)
	}

	res := retry(ctx, f, with_back_off(new_constant_back_off(1 * time.millisecond)),
		with_timer(&TestTimer{}))
	assert res.err !is none, 'error is unexpectedly none'
	assert errors_is(res.err, expected_err), 'unexpected error: ${res.err}'
	assert st.i == cancel_on, 'invalid number of retries: ${st.i}'
}

// https://github.com/cenkalti/backoff/issues/181
fn test_retry_context_error_includes_operation_error() {
	op_err := error('operation error')
	ctx_err := error('context error')

	mut bg := context.background()
	mut ctx, cancel := context.with_cancel_cause(mut bg)
	mut st := &IState{}
	f := fn [mut st, cancel, ctx_err, op_err] () Outcome[bool] {
		st.i++
		if st.i == 2 {
			cancel(ctx_err)
		}
		return Outcome[bool]{
			value: false
			err:   op_err
		}
	}
	defer {
		cancel(none)
	}

	res := retry(ctx, f, with_back_off(new_constant_back_off(1 * time.millisecond)),
		with_timer(&TestTimer{}))
	assert errors_is(res.err, ctx_err), 'context error not in result: ${res.err}'
	assert errors_is(res.err, op_err), 'operation error not in result: ${res.err}'
}

// https://github.com/cenkalti/backoff/issues/181
fn test_retry_max_elapsed_time_error_includes_operation_error() {
	op_err := error('operation error')

	f := fn [op_err] () Outcome[bool] {
		return Outcome[bool]{
			value: false
			err:   op_err
		}
	}
	res := retry(context.background(), f, with_max_elapsed_time(1 * time.millisecond),
		with_timer(&TestTimer{}))
	assert errors_is(res.err, err_max_elapsed_time), 'ErrMaxElapsedTime not in result: ${res.err}'
	assert errors_is(res.err, op_err), 'operation error not in result: ${res.err}'
}

fn test_retry_error() {
	op_err := error('operation error')

	// MaxTries reached: Cause is ErrExhausted, LastErr is the operation error.
	f1 := fn [op_err] () Outcome[bool] {
		return Outcome[bool]{
			value: false
			err:   op_err
		}
	}
	res := retry(context.background(), f1, with_max_tries(1), with_timer(&TestTimer{}))
	assert errors_is(res.err, err_exhausted), 'ErrExhausted not in result: ${res.err}'
	assert errors_is(res.err, op_err), 'operation error not in result: ${res.err}'

	// errors.As exposes the structured fields.
	re := as_retry_error(res.err) or {
		assert false, 'result is not a &RetryError: ${res.err}'
		return
	}
	assert re.last_err == op_err, 'LastErr = ${re.last_err}, want ${op_err}'
	assert re.cause == err_exhausted, 'Cause = ${re.cause}, want ${err_exhausted}'

	// Backoff policy returning Stop also reports ErrExhausted.
	f2 := fn [op_err] () Outcome[bool] {
		return Outcome[bool]{
			value: false
			err:   op_err
		}
	}
	res2 := retry(context.background(), f2, with_back_off(&StopBackOff{}), with_timer(&TestTimer{}))
	assert errors_is(res2.err, err_exhausted), 'ErrExhausted not in result on Stop: ${res2.err}'
	assert errors_is(res2.err, op_err), 'operation error not in result on Stop: ${res2.err}'
}

fn test_retry_permanent() {
	// "nil test": succeeds on first call; no retry.
	a, ra := run_perm_case(fn () Outcome[int] {
		return Outcome[int]{ value: 1, err: none }
	})
	assert ra == 1, 'nil test: res ${ra}, want 1'
	assert a == 1, 'nil test: attempts ${a}, want 1 (no retry)'

	// "io.EOF": non-permanent error -> retry once, then forced permanent.
	b, rb := run_perm_case(fn () Outcome[int] {
		return Outcome[int]{ value: 2, err: io_eof }
	})
	assert rb == -1, 'io.EOF: res ${rb}, want -1'
	assert b == 2, 'io.EOF: attempts ${b}, want 2 (retried)'

	// "Permanent(io.EOF)": permanent on first call -> no retry.
	c, rc := run_perm_case(fn () Outcome[int] {
		return Outcome[int]{ value: 3, err: permanent(io_eof) }
	})
	assert rc == 3, 'Permanent(io.EOF): res ${rc}, want 3'
	assert c == 1, 'Permanent(io.EOF): attempts ${c}, want 1 (no retry)'

	// "Wrapped: Permanent(io.EOF)": wrapped permanent -> detected, no retry.
	d, rd := run_perm_case(fn () Outcome[int] {
		return Outcome[int]{ value: 4, err: wrap_error('Wrapped error: ', permanent(io_eof)) }
	})
	assert rd == 4, 'Wrapped Permanent: res ${rd}, want 4'
	assert d == 1, 'Wrapped Permanent: attempts ${d}, want 1 (no retry)'
}

fn test_permanent() {
	want := error('foo')
	other := error('bar')
	err := permanent(want)

	assert errors_unwrap(err) == want, 'unwrap got ${errors_unwrap(err)}, want ${want}'
	assert errors_is(err, want), 'err is not want'
	assert !errors_is(err, other), 'err is other'
	assert errors_is(err, err_permanent), 'err is not ErrPermanent'

	// A Permanent error stays detectable through wrapping.
	wrapped := wrap_error('wrapped: ', err)
	assert errors_is(wrapped, err_permanent), 'wrapped is not ErrPermanent'
	assert errors_is(wrapped, want), 'wrapped is not want'

	assert permanent(none) is none, 'permanent(none) should be none'
}

fn test_retry_permanent_error() {
	op_err := error('operation error')

	f := fn [op_err] () Outcome[bool] {
		return Outcome[bool]{
			value: false
			err:   permanent(op_err)
		}
	}
	res := retry(context.background(), f, with_timer(&TestTimer{}))
	assert errors_is(res.err, err_permanent), 'ErrPermanent not in result: ${res.err}'
	assert errors_is(res.err, op_err), 'operation error not in result: ${res.err}'

	re := as_retry_error(res.err) or {
		assert false, 'result is not a &RetryError: ${res.err}'
		return
	}
	assert re.cause == err_permanent, 'Cause = ${re.cause}, want ErrPermanent'
	assert re.last_err == op_err, 'LastErr = ${re.last_err}, want ${op_err}'
}

// Permanent error bubbles up when WithMaxTries(1)
// https://github.com/cenkalti/backoff/issues/177
fn test_issue_177() {
	dummy_err := error('dummy')
	operation := fn [dummy_err] () Outcome[int] {
		return Outcome[int]{
			value: 0
			err:   permanent(dummy_err)
		}
	}
	for i in [u32(0), u32(1), u32(2)] {
		res := retry(context.todo(), operation, with_max_tries(i))
		assert errors_is(res.err, dummy_err), 'unexpected error: ${res.err}'
		assert errors_is(res.err, err_permanent), 'error is not ErrPermanent: ${res.err}'
	}
}

fn test_retry_context_deadline() {
	// A context deadline surfaces as Cause context.DeadlineExceeded, with
	// LastErr preserved.
	op_err := error('operation error')
	mut bg := context.background()
	mut ctx, cancel := context.with_deadline(mut bg, time.now().add(-1 * time.minute))
	defer {
		cancel()
	}

	f := fn [op_err] () Outcome[int] {
		return Outcome[int]{
			value: 0
			err:   op_err
		}
	}
	res := retry(ctx, f, with_timer(&TestTimer{}))

	assert errors_is_msg(res.err, context_deadline_exceeded_msg), 'Cause is not context.DeadlineExceeded: ${res.err}'
	assert errors_is(res.err, op_err), 'operation error not in result: ${res.err}'
	re := as_retry_error(res.err) or {
		assert false, 'not a RetryError: ${res.err}'
		return
	}
	assert errors_is_msg(re.cause, context_deadline_exceeded_msg), 'RetryError.Cause not DeadlineExceeded: ${re.cause}'
}

fn test_retry_notify() {
	// fires between attempts with the failing error, not on success
	success_on := 3
	mut st := &CallsState{}
	mut got := &NotifyCollector{}
	mut notify_fn := Notify(fn [mut got] (e IError, d time.Duration) {
		got.msgs << e.msg()
	})
	op1 := fn [mut st, success_on] () Outcome[int] {
		st.calls++
		if st.calls == success_on {
			return Outcome[int]{
				value: 1
				err:   none
			}
		}
		return Outcome[int]{
			value: 0
			err:   error('attempt ${st.calls}')
		}
	}
	res := retry(context.background(), op1, with_back_off(&ZeroBackOff{}),
		with_timer(&TestTimer{}), with_notify(notify_fn))
	assert res.err is none, 'unexpected error: ${res.err}'
	assert got.msgs.len == 2, 'Notify errors len = ${got.msgs.len}, want 2'
	assert got.msgs[0] == 'attempt 1', 'Notify[0] = ${got.msgs[0]}'
	assert got.msgs[1] == 'attempt 2', 'Notify[1] = ${got.msgs[1]}'

	// not called for the terminal, exhausting error
	mut n2 := &NState{}
	notify2 := Notify(fn [mut n2] (e IError, d time.Duration) {
		n2.n++
	})
	op2 := fn () Outcome[int] {
		return Outcome[int]{
			value: 0
			err:   error('boom')
		}
	}
	res2 := retry(context.background(), op2, with_max_tries(2), with_back_off(&ZeroBackOff{}),
		with_timer(&TestTimer{}), with_notify(notify2))
	assert errors_is(res2.err, err_exhausted), 'Cause = ${res2.err}, want ErrExhausted'
	assert n2.n == 1, 'Notify called ${n2.n} times, want 1'

	// not called on a permanent error
	mut n3 := &NState{}
	notify3 := Notify(fn [mut n3] (e IError, d time.Duration) {
		n3.n++
	})
	op3 := fn () Outcome[int] {
		return Outcome[int]{
			value: 0
			err:   permanent(error('nope'))
		}
	}
	res3 := retry(context.background(), op3, with_timer(&TestTimer{}), with_notify(notify3))
	_ = res3
	assert n3.n == 0, 'Notify called ${n3.n} times on a permanent error, want 0'

	// not called on context cancellation
	mut n4 := &NState{}
	mut bg := context.background()
	mut ctx, cancel := context.with_cancel(mut bg)
	notify4 := Notify(fn [mut n4] (e IError, d time.Duration) {
		n4.n++
	})
	op4 := fn [cancel] () Outcome[int] {
		cancel()
		return Outcome[int]{
			value: 0
			err:   error('boom')
		}
	}
	res4 := retry(ctx, op4, with_back_off(&ZeroBackOff{}), with_timer(&TestTimer{}),
		with_notify(notify4))
	_ = res4
	assert n4.n == 0, 'Notify called ${n4.n} times on cancellation, want 0'
}

struct NotifyCollector {
mut:
	msgs []string
}

struct NState {
mut:
	n int
}

fn test_retry_after() {
	// A RetryAfterError overrides the next wait with its own duration and
	// resets the backoff policy.
	retry_after_dur := 42 * time.second
	mut bo := &CountingBackOff{}
	mut tm := &SpyTimer{}
	mut st := &CallsState{}

	f := fn [mut st, retry_after_dur] () Outcome[int] {
		st.calls++
		if st.calls == 1 {
			return Outcome[int]{
				value: 0
				err:   &RetryAfterError{
					duration: retry_after_dur
					err:      none
				}
			}
		}
		return Outcome[int]{
			value: 1
			err:   none
		}
	}
	res := retry(context.background(), f, with_back_off(bo), with_max_elapsed_time(0),
		with_timer(tm))
	assert res.err is none, 'unexpected error: ${res.err}'
	assert tm.starts.len == 1, 'timer waits len = ${tm.starts.len}, want 1'
	assert tm.starts[0] == retry_after_dur, 'timer wait = ${tm.starts[0]}, want ${retry_after_dur}'
	// Reset is called once at the start of retry and again because of RetryAfter.
	assert bo.resets == 2, 'BackOff.Reset called ${bo.resets} times, want 2'
}

fn test_retry_after_error() {
	// nil cause: behaves like a bare retry-after, Unwrap is none.
	err := retry_after(3 * time.second, none)
	ra := errors_as_retry_after(err) or {
		assert false, 'RetryAfter did not return a &RetryAfterError: ${err}'
		return
	}
	assert ra.duration == 3 * time.second, 'Duration = ${ra.duration}, want 3s'
	assert ra.msg() == 'retry after 3s', 'Error() = ${ra.msg()}, want "retry after 3s"'
	assert errors_unwrap(err) is none, 'Unwrap() not none'

	// With a cause: it is wrapped (Is sees it) and shown in the message.
	cause := error('rate limited')
	werr := retry_after(3 * time.second, cause)
	assert errors_is(werr, cause), 'RetryAfter(_, cause) does not wrap cause: ${werr}'
	assert werr.msg() == 'rate limited (retry after 3s)', 'Error() = ${werr.msg()}, want "rate limited (retry after 3s)"'
}

// https://github.com/cenkalti/backoff/issues/184
fn test_retry_after_carries_error() {
	// When an operation returns RetryAfter with a cause and retrying then stops
	// (here via WithMaxTries), the cause — not the RetryAfterError — is reported
	// as LastErr.
	cause := error('rate limited')
	f1 := fn [cause] () Outcome[int] {
		return Outcome[int]{
			value: 0
			err:   retry_after(1 * time.second, cause)
		}
	}
	res := retry(context.background(), f1, with_max_tries(1), with_timer(&TestTimer{}))
	assert errors_is(res.err, err_exhausted), 'Cause = ${res.err}, want ErrExhausted'
	assert errors_is(res.err, cause), 'cause not in result: ${res.err}'
	re := as_retry_error(res.err) or {
		assert false, 'not a RetryError'
		return
	}
	assert re.last_err == cause, 'LastErr = ${re.last_err}, want ${cause}'

	// A nil cause keeps the previous behavior: LastErr is the RetryAfterError
	// itself.
	f2 := fn () Outcome[int] {
		return Outcome[int]{
			value: 0
			err:   retry_after(1 * time.second, none)
		}
	}
	res2 := retry(context.background(), f2, with_max_tries(1), with_timer(&TestTimer{}))
	re2 := as_retry_error(res2.err) or {
		assert false, 'result is not a &RetryError: ${res2.err}'
		return
	}
	assert re2.last_err is RetryAfterError, 'LastErr is not a &RetryAfterError: ${typeof(re2.last_err).name}'
}

fn test_retry_error_string() {
	mut re := &RetryError{
		last_err: error('last')
		cause:    err_exhausted
	}
	assert re.msg() == 'backoff: retries exhausted (last error: last)', 'Error() = ${re.msg()}'
	// RetryError implements Unwrap() []error, so the single-value errors.Unwrap
	// returns none; callers must use errors.Is/As.
	assert errors_unwrap(re) is none, 'errors_unwrap(RetryError) not none'
	if _ := as_retry_error(none) {
		assert false, 'as_retry_error(none) should be none'
	}
}

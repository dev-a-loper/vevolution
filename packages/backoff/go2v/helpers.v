module backoff

import context
import time

// Internal test helpers shared across the _test.v files. V compiles each
// `_test.v` file as a separate test binary, so helpers cannot live in a
// `_test.v` file; they are kept here as private module types instead. (With
// `-skip-unused`, these are elided from non-test builds.)

// TestTimer fires immediately (ignoring the requested duration), matching Go's
// testTimer which does `time.NewTimer(0)`.
struct TestTimer {
mut:
	ch chan time.Time
}

fn (mut t TestTimer) start(_ time.Duration) {
	t.ch = chan time.Time{cap: 1}
	spawn fn (mut t TestTimer) {
		t.ch <- time.now()
	}(mut t)
}

fn (mut t TestTimer) stop() {
}

fn (mut t TestTimer) channel() chan time.Time {
	return t.ch
}

// SpyTimer records every duration it is asked to wait, then fires immediately.
struct SpyTimer {
mut:
	starts []time.Duration
	ch     chan time.Time
}

fn (mut t SpyTimer) start(d time.Duration) {
	t.starts << d
	t.ch = chan time.Time{cap: 1}
	spawn fn (mut t SpyTimer) {
		t.ch <- time.now()
	}(mut t)
}

fn (mut t SpyTimer) stop() {
}

fn (mut t SpyTimer) channel() chan time.Time {
	return t.ch
}

// CountingBackOff records how many times it is reset and queried.
struct CountingBackOff {
mut:
	resets int
	nexts  int
}

fn (mut b CountingBackOff) reset() {
	b.resets++
}

fn (mut b CountingBackOff) next_back_off() time.Duration {
	b.nexts++
	return time.second
}

// Mutable counters shared with operation closures (V closures capture by value,
// so state is shared through a heap pointer).
struct IState {
mut:
	i int
}

struct CallsState {
mut:
	calls int
}

// io_eof is a stand-in for Go's io.EOF (V's io module has no exported EOF
// sentinel); the tests use it only as a plain non-permanent error value.
const io_eof = error('EOF')

// context_canceled_msg / context_deadline_exceeded_msg are the message texts of
// V's private context error sentinels. Tests detect context errors by message.
const context_canceled_msg = 'context canceled'

const context_deadline_exceeded_msg = 'context deadline exceeded'

// errors_is_msg reports whether any error in err's chain has a message matching
// target_msg (used for the private context error sentinels and plain errors
// whose identity is their text).
fn errors_is_msg(err IError, target_msg string) bool {
	if err is none {
		return false
	}
	mut stack := [err]
	for stack.len > 0 {
		node := stack.pop()
		if node.msg() == target_msg {
			return true
		}
		stack << unwrap_children(node)
	}
	return false
}

// run_perm_case mirrors the `ensureRetries` helper in the Go test_retry_test.go:
// it wraps `f` so that the SECOND attempt returns a Permanent("forced") error,
// runs it through retry, and returns the number of operation attempts together
// with the final result value. (attempts==1 means retry never retried.)
fn run_perm_case(f fn () Outcome[int]) (int, int) {
	mut st := &IState{}
	wrapped := fn [mut st, f] () Outcome[int] {
		st.i++
		if st.i >= 2 {
			return Outcome[int]{
				value: -1
				err:   permanent(error('forced'))
			}
		}
		return f()
	}
	res := retry(context.background(), wrapped, with_back_off(new_exponential_back_off()),
		with_timer(&TestTimer{}))
	return st.i, res.value
}

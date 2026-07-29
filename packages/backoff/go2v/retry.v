module backoff

import context
import time

// DefaultMaxElapsedTime sets a default limit for the total retry duration.
pub const default_max_elapsed_time = 15 * time.minute

// Outcome[T] carries an operation's value together with an optional error. V
// has no `(T, IError)` multi-return, so this struct is the faithful carrier for
// both pieces (Go returns `(T, error)` and Retry preserves the value even when
// it stops on a permanent/exhausted error).
pub struct Outcome[T] {
pub:
	value T
	err   IError
}

// Operation is the function retry calls. It is invoked at least once and may be
// retried on error. Return a `Permanent` error to stop retrying immediately, or
// a `RetryAfterError` to control the delay before the next attempt.
pub type Operation[T] = fn () Outcome[T]

// Notify is called after a failed attempt that will be retried, with the
// operation error and the backoff duration before the next attempt.
pub type Notify = fn (err IError, d time.Duration)

// retry_options holds configuration settings for the retry mechanism.
struct RetryOptions {
mut:
	back_off    BackOff
	timer_      Timer
	notify_     ?Notify
	max_tries   u32
	max_elapsed time.Duration
}

// RetryOption configures the behavior of retry.
pub type RetryOption = fn (mut opts RetryOptions)

// with_back_off configures the backoff policy used between attempts. The
// default is `new_exponential_back_off`.
pub fn with_back_off(b BackOff) RetryOption {
	return fn [b] (mut opts RetryOptions) {
		opts.back_off = b
	}
}

// with_timer sets a custom timer for managing delays between retries
// (unexported in the Go original; used only by tests).
pub fn with_timer(t Timer) RetryOption {
	return fn [t] (mut opts RetryOptions) {
		opts.timer_ = t
	}
}

// with_notify sets a function called after each failed attempt that will be
// retried.
pub fn with_notify(n Notify) RetryOption {
	return fn [n] (mut opts RetryOptions) {
		opts.notify_ = n
	}
}

// with_max_tries limits the total number of attempts (not retries):
// `with_max_tries(1)` runs the operation once and does not retry. The default,
// 0, means no limit.
pub fn with_max_tries(n u32) RetryOption {
	return fn [n] (mut opts RetryOptions) {
		opts.max_tries = n
	}
}

// with_max_elapsed_time limits the total wall-clock time spent retrying,
// measured from when retry is called. Pass 0 to disable.
pub fn with_max_elapsed_time(d time.Duration) RetryOption {
	return fn [d] (mut opts RetryOptions) {
		opts.max_elapsed = d
	}
}

// retry attempts the operation until it succeeds, returns a Permanent error, or
// backoff completes. It ensures the operation is executed at least once.
//
// On success it returns an `Outcome` whose `err` is `none`. On any failure the
// `Outcome` carries the last value together with a `&RetryError` whose `cause`
// reports why it stopped and whose `last_err` holds the last operation error.
//
// `ctx` bounds the retry loop: its cancellation or deadline stops further
// attempts and interrupts the wait between them.
pub fn retry[T](ctx context.Context, operation Operation[T], opts ...RetryOption) Outcome[T] {
	mut args := &RetryOptions{
		back_off:    new_exponential_back_off()
		timer_:      &DefaultTimer{}
		max_elapsed: default_max_elapsed_time
	}

	for opt in opts {
		opt(mut args)
	}

	defer {
		args.timer_.stop()
	}

	started_at := time.now()
	args.back_off.reset()
	mut num_tries := u32(1)
	for {
		// Execute the operation.
		res := operation()
		if res.err is none {
			return res
		}
		err := res.err

		// Stop immediately on a permanent error; surface it as a RetryError.
		if perr := errors_as_permanent(err) {
			return Outcome[T]{
				value: res.value
				err:   &RetryError{
					last_err: perr.err
					cause:    err_permanent
				}
			}
		}

		// A RetryAfterError carries the delay before the next attempt; if it also
		// carries an underlying error, that is the meaningful error to report as
		// last_err should retrying stop.
		mut last_err := err
		ra_opt := errors_as_retry_after(err)
		if ra := ra_opt {
			if ra.err !is none {
				last_err = ra.err
			}
		}

		// Stop retrying if maximum tries exceeded.
		if args.max_tries > 0 && num_tries >= args.max_tries {
			return Outcome[T]{
				value: res.value
				err:   &RetryError{
					last_err: last_err
					cause:    err_exhausted
				}
			}
		}

		// Stop retrying if context is cancelled.
		cerr := context.cause(ctx)
		if cerr !is none {
			return Outcome[T]{
				value: res.value
				err:   &RetryError{
					last_err: last_err
					cause:    cerr
				}
			}
		}

		// Calculate next backoff duration.
		mut next := args.back_off.next_back_off()
		if next == stop {
			return Outcome[T]{
				value: res.value
				err:   &RetryError{
					last_err: last_err
					cause:    err_exhausted
				}
			}
		}

		// Reset backoff if a RetryAfterError requested a specific delay.
		if ra := ra_opt {
			next = ra.duration
			args.back_off.reset()
		}

		// Stop retrying if maximum elapsed time exceeded.
		if args.max_elapsed > 0 && (time.now() - started_at) + next > args.max_elapsed {
			return Outcome[T]{
				value: res.value
				err:   &RetryError{
					last_err: last_err
					cause:    err_max_elapsed_time
				}
			}
		}

		// Notify on error if a notifier function is provided.
		if n := args.notify_ {
			n(err, next)
		}

		// Wait for the next backoff period or context cancellation.
		args.timer_.start(next)
		tch := args.timer_.channel()
		mut mctx := ctx
		done_ch := mctx.done()
		mut cancelled := false
		select {
			_ := <-tch {}
			_ := <-done_ch {
				cancelled = true
			}
		}
		if cancelled {
			return Outcome[T]{
				value: res.value
				err:   &RetryError{
					last_err: last_err
					cause:    context.cause(ctx)
				}
			}
		}

		num_tries++
	}
	// Unreachable: the loop above only exits via `return`.
	return Outcome[T]{
		err: none
	}
}

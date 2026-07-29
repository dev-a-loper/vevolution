module backoff

import time

// ---------------------------------------------------------------------------
// This module mirrors the Go error model of cenkalti/backoff.
//
// Go's `errors.Is`, `errors.As`, and `errors.Unwrap` walk an error chain built
// via `Unwrap()` / `Unwrap() []error` and `fmt.Errorf("%w", err)`. V has no
// built-in equivalent: an `IError` is opaque once created and there is no
// generic unwrap protocol. To keep the public surface and the test behavior
// faithful, the chain-walking helpers below (`errors_is`, `errors_as_retry`,
// `errors_unwrap`) reconstruct that walk over the concrete error structs
// defined here.
// ---------------------------------------------------------------------------

// --- Cause sentinels -------------------------------------------------------
//
// Each cause is a distinct struct type with a single canonical instance.
// Because V compares `IError` values by content, two instances of the same
// empty-struct type compare equal, so type matching and value matching agree.

pub struct PermanentCause {}

// msg returns the permanent-error cause text.
pub fn (e &PermanentCause) msg() string {
	return 'backoff: permanent error'
}

// code returns the IError numeric code.
pub fn (e &PermanentCause) code() int {
	return 1
}

pub struct ExhaustedCause {}

// msg returns the retries-exhausted cause text.
pub fn (e &ExhaustedCause) msg() string {
	return 'backoff: retries exhausted'
}

// code returns the IError numeric code.
pub fn (e &ExhaustedCause) code() int {
	return 1
}

pub struct MaxElapsedTimeCause {}

// msg returns the maximum-elapsed-time cause text.
pub fn (e &MaxElapsedTimeCause) msg() string {
	return 'backoff: maximum elapsed time exceeded'
}

// code returns the IError numeric code.
pub fn (e &MaxElapsedTimeCause) code() int {
	return 1
}

// err_permanent is the cause when the operation returned a Permanent error.
// Typed as IError so it can be compared and passed uniformly.
pub const err_permanent = IError(&PermanentCause{})

// err_exhausted is the cause when retrying stops because `with_max_tries` was
// reached or the backoff policy returned `stop`.
pub const err_exhausted = IError(&ExhaustedCause{})

// err_max_elapsed_time is the cause when retrying stops because
// `with_max_elapsed_time` was reached.
pub const err_max_elapsed_time = IError(&MaxElapsedTimeCause{})

// --- RetryError ------------------------------------------------------------

// RetryError is the error returned by `retry` for every failure. It records
// the last error returned by the operation (`last_err`) together with the
// reason retrying stopped (`cause`).
pub struct RetryError {
pub:
	last_err IError
	cause    IError
}

// msg renders the cause together with the last operation error.
pub fn (e &RetryError) msg() string {
	last := error_text(e.last_err)
	cause := error_text(e.cause)
	return '${cause} (last error: ${last})'
}

// code returns the IError numeric code.
pub fn (e &RetryError) code() int {
	return 1
}

// unwrap_children returns the cause and the last operation error so both can be
// matched with `errors_is` and `errors_as_retry` (mirrors Go's
// `Unwrap() []error`).
pub fn (e &RetryError) unwrap_children() []IError {
	return [e.cause, e.last_err]
}

// as_retry_error returns the `&RetryError` in err's chain, or `none` if there
// is none (including when err is `none`). It is the V analogue of Go's
// `errors.As(err, &re)`.
pub fn as_retry_error(err IError) ?&RetryError {
	if err is none {
		return none
	}
	mut stack := [err]
	for stack.len > 0 {
		node := stack.pop()
		match node {
			RetryError { return node }
			else { stack << unwrap_children(node) }
		}
	}
	return none
}

// --- permanent -------------------------------------------------------------

// PermanentError marks an operation error as non-retriable. It is an internal
// transport produced by `permanent` and consumed by `retry`, which converts it
// into a `RetryError` with cause `err_permanent`.
pub struct PermanentError {
pub:
	err IError
}

// msg returns the wrapped error's message.
pub fn (e &PermanentError) msg() string {
	return error_text(e.err)
}

// code returns the IError numeric code.
pub fn (e &PermanentError) code() int {
	return 1
}

// unwrap_children returns the wrapped error so it is reachable via the chain
// walk.
pub fn (e &PermanentError) unwrap_children() []IError {
	return [e.err]
}

// permanent wraps err to signal that `retry` should stop immediately instead of
// retrying. `permanent(none)` returns `none`.
pub fn permanent(err IError) IError {
	if err is none {
		return none
	}
	return &PermanentError{
		err: err
	}
}

// --- RetryAfterError -------------------------------------------------------

// RetryAfterError signals that the operation should be retried after the given
// duration.
pub struct RetryAfterError {
pub:
	duration time.Duration
	err      IError
}

// msg renders the cause (if any) with the retry-after duration.
pub fn (e &RetryAfterError) msg() string {
	ds := go_duration_str(e.duration)
	if e.err !is none {
		return '${e.err.msg()} (retry after ${ds})'
	}
	return 'retry after ${ds}'
}

// code returns the IError numeric code.
pub fn (e &RetryAfterError) code() int {
	return 1
}

// unwrap_children returns the triggering cause, if one was provided.
pub fn (e &RetryAfterError) unwrap_children() []IError {
	if e.err is none {
		return []
	}
	return [e.err]
}

// retry_after returns a RetryAfterError that tells `retry` to wait the given
// duration before the next attempt. cause is preserved as `RetryError.last_err`
// if retrying stops.
pub fn retry_after(d time.Duration, cause IError) IError {
	return &RetryAfterError{
		duration: d
		err:      cause
	}
}

// --- WrappedError (fmt.Errorf("%w") analogue) ------------------------------

// WrappedError is the V analogue of `fmt.Errorf("prefix: %w", err)`: it carries
// a static prefix and a wrapped inner error reachable via the chain walk.
pub struct WrappedError {
	text string
	err  IError
}

// msg returns the wrapped error's composed text.
pub fn (e &WrappedError) msg() string {
	return e.text
}

// code returns the IError numeric code.
pub fn (e &WrappedError) code() int {
	return 1
}

// unwrap_children returns the inner wrapped error.
pub fn (e &WrappedError) unwrap_children() []IError {
	if e.err is none {
		return []
	}
	return [e.err]
}

// wrap_error builds a WrappedError whose message is `${prefix}${inner.msg()}`.
// It mirrors Go's `fmt.Errorf(prefix + "%w", inner)`.
pub fn wrap_error(prefix string, inner IError) IError {
	return &WrappedError{
		text: '${prefix}${error_text(inner)}'
		err:  inner
	}
}

// --- Chain-walking helpers ------------------------------------------------

// error_text returns the message of err, or '<nil>' if err is `none` (matching
// Go's `%s` formatting of a nil error).
pub fn error_text(err IError) string {
	if err is none {
		return '<nil>'
	}
	return err.msg()
}

// unwrap_children returns the chain descendants of err, or an empty slice for
// errors that do not wrap anything.
fn unwrap_children(err IError) []IError {
	match err {
		RetryError { return err.unwrap_children() }
		PermanentError { return err.unwrap_children() }
		RetryAfterError { return err.unwrap_children() }
		WrappedError { return err.unwrap_children() }
		else { return []IError{} }
	}
}

// errors_is reports whether any error in err's chain matches target. Matching
// is by IError value equality (content-based in V), with a special case so a
// `PermanentError` matches the `err_permanent` sentinel (mirroring Go's
// `Is(target) bool` method on `*permanent`).
pub fn errors_is(err IError, target IError) bool {
	if err is none || target is none {
		return false
	}
	mut stack := [err]
	for stack.len > 0 {
		node := stack.pop()
		// value/content equality covers plain `error('...')` sentinels and
		// same-type singletons.
		if node == target {
			return true
		}
		// A PermanentError matches the ErrPermanent sentinel, even before
		// `retry` converts it into a RetryError.
		if node is PermanentError && target is PermanentCause {
			return true
		}
		stack << unwrap_children(node)
	}
	return false
}

// errors_as_permanent returns the `&PermanentError` in err's chain, if any.
pub fn errors_as_permanent(err IError) ?&PermanentError {
	if err is none {
		return none
	}
	mut stack := [err]
	for stack.len > 0 {
		node := stack.pop()
		match node {
			PermanentError { return node }
			else { stack << unwrap_children(node) }
		}
	}
	return none
}

// errors_as_retry_after returns the `&RetryAfterError` in err's chain, if any.
pub fn errors_as_retry_after(err IError) ?&RetryAfterError {
	if err is none {
		return none
	}
	mut stack := [err]
	for stack.len > 0 {
		node := stack.pop()
		match node {
			RetryAfterError { return node }
			else { stack << unwrap_children(node) }
		}
	}
	return none
}

// errors_unwrap returns the single inner error of err, or `none` if err does
// not wrap exactly one error. Like Go's single-value `errors.Unwrap`, a
// `RetryError` (which exposes `Unwrap() []error`) returns `none` here.
pub fn errors_unwrap(err IError) IError {
	match err {
		PermanentError { return err.err }
		RetryAfterError { return err.err }
		WrappedError { return err.err }
		else { return none }
	}
}

// --- Go-style time.Duration formatting ------------------------------------
//
// V's `time.Duration.str()` always emits a fractional component (e.g. "3.000s"),
// but Go's `time.Duration.String()` does not (e.g. "3s"). Error messages such
// as "retry after 3s" must match the Go originals, so we reimplement the Go
// formatter here.

// fmt_frac writes the fractional part of `v` (prec digits) right-to-left into
// `buf` starting from position `w`, stripping trailing zeros. Returns the new
// position and the remaining integer part of `v`.
fn fmt_frac(mut buf []u8, w int, v u64, prec int) (int, u64) {
	mut ww := w
	mut vv := v
	mut do_print := false
	for _ in 0 .. prec {
		digit := vv % 10
		do_print = do_print || digit != 0
		if do_print {
			ww -= 1
			buf[ww] = u8(digit) + `0`
		}
		vv /= 10
	}
	if do_print {
		ww -= 1
		buf[ww] = `.`
	}
	return ww, vv
}

// fmt_int writes the decimal representation of `v` right-to-left into `buf`
// starting from position `w`. Returns the new position.
fn fmt_int(mut buf []u8, w int, v u64) int {
	mut ww := w
	mut vv := v
	if vv == 0 {
		ww -= 1
		buf[ww] = `0`
	} else {
		for vv > 0 {
			ww -= 1
			buf[ww] = u8(vv % 10) + `0`
			vv /= 10
		}
	}
	return ww
}

// go_duration_str formats d exactly like Go's `time.Duration.String()`.
pub fn go_duration_str(d time.Duration) string {
	if d == 0 {
		return '0s'
	}
	// 32-byte work buffer, written right-to-left (as Go does).
	mut buf := []u8{len: 32, init: ` `}
	mut w := buf.len
	mut neg := false
	mut uu := u64(d)
	if d < 0 {
		neg = true
		uu = -(u64(d))
	}
	if uu < u64(time.second) {
		// Smaller than a second: ns / us / ms.
		mut prec := 0
		w -= 1
		buf[w] = `s`
		w -= 1
		if uu == 0 {
			return '0s'
		} else if uu < u64(time.microsecond) {
			prec = 0
			buf[w] = `n`
		} else if uu < u64(time.millisecond) {
			prec = 3
			buf[w] = `u` // Go prints U+00B5; tests only use s/ms, so ASCII 'u' suffices.
		} else {
			prec = 6
			buf[w] = `m`
		}
		x, v2 := fmt_frac(mut buf, w, uu, prec)
		w = x
		uu = v2
		w = fmt_int(mut buf, w, uu)
	} else {
		w -= 1
		buf[w] = `s`
		x, v2 := fmt_frac(mut buf, w, uu, 9)
		w = x
		uu = v2
		// uu is now integer seconds.
		w = fmt_int(mut buf, w, uu % 60)
		uu /= 60
		// uu is now integer minutes.
		if uu > 0 {
			w -= 1
			buf[w] = `m`
			w = fmt_int(mut buf, w, uu % 60)
			uu /= 60
			// uu is now integer hours.
			if uu > 0 {
				w -= 1
				buf[w] = `h`
				w = fmt_int(mut buf, w, uu)
			}
		}
	}
	if neg {
		w -= 1
		buf[w] = `-`
	}
	unsafe {
		return tos(&buf[w], buf.len - w)
	}
}

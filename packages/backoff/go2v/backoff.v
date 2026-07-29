module backoff

import time

// BackOff is a backoff policy for retrying an operation.
//
// `reset` restores the policy to its initial state, and `next_back_off` returns
// the duration to wait before the next retry. A return value of `backoff.stop`
// (== -1) signals that no more retries should be made.
//
// Methods are declared `mut` because the primary implementation,
// `ExponentialBackOff`, mutates internal state on every `next_back_off` call.
pub interface BackOff {
mut:
	reset()
	next_back_off() time.Duration
}

// stop indicates that no more retries should be made; returned from
// `next_back_off` to signal "give up".
pub const stop = time.Duration(-1)

// ZeroBackOff is a fixed backoff policy whose backoff time is always zero,
// meaning that the operation is retried immediately without waiting,
// indefinitely.
pub struct ZeroBackOff {}

// reset is a no-op for ZeroBackOff.
pub fn (mut b ZeroBackOff) reset() {}

// next_back_off always returns zero (retry immediately).
pub fn (mut b ZeroBackOff) next_back_off() time.Duration {
	return time.Duration(0)
}

// StopBackOff is a fixed backoff policy that always returns `backoff.stop` for
// `next_back_off`, meaning that the operation should never be retried.
pub struct StopBackOff {}

// reset is a no-op for StopBackOff.
pub fn (mut b StopBackOff) reset() {}

// next_back_off always returns `stop` (never retry).
pub fn (mut b StopBackOff) next_back_off() time.Duration {
	return stop
}

// ConstantBackOff is a backoff policy that always returns the same backoff
// delay. This is in contrast to an exponential backoff policy, which returns a
// delay that grows longer as you call `next_back_off` over and over again.
pub struct ConstantBackOff {
pub:
	interval time.Duration
}

// reset is a no-op for ConstantBackOff.
pub fn (mut b ConstantBackOff) reset() {}

// next_back_off always returns the configured interval.
pub fn (mut b ConstantBackOff) next_back_off() time.Duration {
	return b.interval
}

// new_constant_back_off returns a ConstantBackOff that always waits `d`.
pub fn new_constant_back_off(d time.Duration) &ConstantBackOff {
	return &ConstantBackOff{
		interval: d
	}
}

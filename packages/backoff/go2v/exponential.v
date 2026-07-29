module backoff

import rand
import time

// ExponentialBackOff is a backoff implementation that increases the backoff
// period for each retry attempt using a randomization function that grows
// exponentially.
//
// `next_back_off` is calculated using:
//
//	randomized interval =
//	    RetryInterval * (random value in range [1 - RandomizationFactor, 1 + RandomizationFactor])
//
// Implementation is not thread-safe.
pub struct ExponentialBackOff {
pub mut:
	initial_interval     time.Duration
	randomization_factor f64
	multiplier           f64
	max_interval         time.Duration
	current_interval     time.Duration
}

// Default values for ExponentialBackOff.
pub const default_initial_interval = 500 * time.millisecond

pub const default_randomization_factor = 0.5

pub const default_multiplier = 1.5

pub const default_max_interval = 60 * time.second

// new_exponential_back_off creates an instance of ExponentialBackOff using
// default values.
pub fn new_exponential_back_off() &ExponentialBackOff {
	return &ExponentialBackOff{
		initial_interval:     default_initial_interval
		randomization_factor: default_randomization_factor
		multiplier:           default_multiplier
		max_interval:         default_max_interval
	}
}

// reset restores the interval to the initial retry interval. reset must be
// called before using `b`.
pub fn (mut b ExponentialBackOff) reset() {
	b.current_interval = b.initial_interval
}

// next_back_off calculates the next backoff interval using:
//
//	Randomized interval = RetryInterval * (1 +/- RandomizationFactor)
pub fn (mut b ExponentialBackOff) next_back_off() time.Duration {
	if b.current_interval == 0 {
		b.current_interval = b.initial_interval
	}

	next := get_random_value_from_interval(b.randomization_factor, rand.f64(), b.current_interval)
	b.increment_current_interval()
	return next
}

// increment_current_interval increments the current interval by multiplying it
// with the multiplier. On overflow it caps the current interval to the max.
pub fn (mut b ExponentialBackOff) increment_current_interval() {
	// Check for overflow, if overflow is detected set the current interval to
	// the max interval.
	if f64(b.current_interval) >= f64(b.max_interval) / b.multiplier {
		b.current_interval = b.max_interval
	} else {
		b.current_interval = time.Duration(f64(b.current_interval) * b.multiplier)
	}
}

// get_random_value_from_interval returns a random value from:
//
//	[currentInterval - rf*currentInterval, currentInterval + rf*currentInterval]
//
// The `+ 1` below mirrors the Go original: it gives an even chance across the
// integer span when currentInterval is small.
pub fn get_random_value_from_interval(rf f64, random f64, current_interval time.Duration) time.Duration {
	if rf == 0 {
		return current_interval // make sure no randomness is used when rf is 0.
	}
	delta := rf * f64(current_interval)
	min_interval := f64(current_interval) - delta
	max_interval := f64(current_interval) + delta

	// Get a random value from the range [minInterval, maxInterval].
	// The formula used below has a +1 because if the minInterval is 1 and the
	// maxInterval is 3 then we want a 33% chance for selecting either 1, 2 or 3.
	return time.Duration(min_interval + (random * (max_interval - min_interval + 1)))
}

// max_i64 is the largest value representable by i64, matching Go's
// math.MaxInt64. V has no exported constant for this.
pub const max_i64 = i64(9223372036854775807)

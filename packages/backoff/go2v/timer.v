module backoff

import time

// Timer abstracts the wait between retry attempts so tests can substitute one
// that fires immediately. It mirrors the (unexported) `timer` interface in the
// Go original.
pub interface Timer {
mut:
	start(d time.Duration)
	stop()
	channel() chan time.Time
}

// DefaultTimer implements Timer using a goroutine that sleeps for the requested
// duration then signals a channel, approximating Go's `time.Timer`.
pub struct DefaultTimer {
mut:
	ch chan time.Time
}

// channel returns the channel that receives the current time when the timer
// fires.
pub fn (mut t DefaultTimer) channel() chan time.Time {
	return t.ch
}

// start arms the timer to fire after the given duration.
pub fn (mut t DefaultTimer) start(d time.Duration) {
	t.ch = chan time.Time{cap: 1}
	spawn fn (mut t DefaultTimer, d time.Duration) {
		if d > 0 {
			time.sleep(d)
		}
		t.ch <- time.now()
	}(mut t, d)
}

// stop releases resources; safe to call on a never-started timer.
pub fn (mut t DefaultTimer) stop() {
}

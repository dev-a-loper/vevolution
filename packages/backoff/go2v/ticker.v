module backoff

import sync
import time

// Ticker holds a channel that delivers "ticks" of a clock at times reported by a
// BackOff.
//
// Ticks will continue to arrive when the previous operation is still running,
// so operations that take a while to fail could run in quick succession.
pub struct Ticker {
pub mut:
	c chan time.Time
mut:
	back_off BackOff
	timer_   Timer
	stop_ch  chan int
	stopped  &StopFlag
}

// StopFlag is a heap-allocated one-shot flag shared between the Ticker and its
// run coroutine (V closures capture by value, so the flag is shared via a
// pointer).
struct StopFlag {
mut:
	v  bool
	mu sync.Mutex
}

// new_ticker returns a new Ticker whose channel `c` will send the time at
// instants specified by the BackOff argument. The ticker is guaranteed to tick
// at least once. The channel is closed when `stop` is called or the BackOff
// stops.
pub fn new_ticker(b BackOff) &Ticker {
	mut t := &Ticker{
		c:        chan time.Time{cap: 0}
		back_off: b
		timer_:   &DefaultTimer{}
		stop_ch:  chan int{cap: 0}
		stopped:  &StopFlag{}
	}
	t.back_off.reset()
	spawn t.run()
	return t
}

// stop turns off a ticker. After stop, no more ticks will be sent. Safe to call
// more than once (mirrors Go's sync.Once guard).
pub fn (mut t Ticker) stop() {
	t.stopped.mu.lock()
	already := t.stopped.v
	t.stopped.v = true
	t.stopped.mu.unlock()
	if !already {
		t.stop_ch.close()
	}
}

// run is the ticker loop, run in its own coroutine.
fn (mut t Ticker) run() {
	defer {
		t.c.close()
	}
	// Ticker is guaranteed to tick at least once.
	if !t.send(time.now()) {
		return
	}
	for {
		// Wait for the armed timer to fire, or for a stop request.
		tch := t.timer_.channel()
		select {
			_ := <-tch {
				if !t.send(time.now()) {
					return
				}
			}
			_ := <-t.stop_ch {
				return
			}
		}
	}
}

// send emits a tick and arms the next timer. Returns false if the ticker should
// stop (because the BackOff returned Stop, or stop was requested).
//
// Note: Go's original uses a `select { case t.c <- tick: case <-t.stop: }` to
// abort a blocked send on stop. V 0.5.2 has a compiler bug on select-with-send,
// so we use a blocking send here. This is faithful for the tests (a receiver is
// always pending while the ticker is active), and V exits cleanly if a send is
// still blocked at shutdown.
fn (mut t Ticker) send(tick time.Time) bool {
	t.c <- tick
	// If stop was requested while blocked on the send, stop now.
	t.stopped.mu.lock()
	s := t.stopped.v
	t.stopped.mu.unlock()
	if s {
		return false
	}
	next := t.back_off.next_back_off()
	if next == stop {
		t.stop()
		return false
	}
	t.timer_.start(next)
	return true
}

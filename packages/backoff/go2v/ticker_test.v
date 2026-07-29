module backoff

import time

fn test_ticker() {
	success_on := 3
	mut st := &IState{}

	b := new_exponential_back_off()
	mut ticker := new_ticker(b)
	ticker.timer_ = &TestTimer{}

	mut had_err := false
	for {
		_ := <-ticker.c or { break }
		st.i++
		if st.i == success_on {
			had_err = false
			break
		}
		had_err = true
	}
	assert !had_err, 'unexpected error from operation'
	assert st.i == success_on, 'invalid number of retries: ${st.i}'
	ticker.stop()
}

fn test_ticker_stop() {
	// Stop closes the channel and is safe to call more than once.
	mut ticker := new_ticker(new_constant_back_off(1 * time.hour))
	_ = <-ticker.c or {
		assert false, 'expected first tick'
		return
	}
	ticker.stop()
	ticker.stop() // must not panic (sync.Once equivalent)
	// After stop, the channel must be closed (receive yields none).
	mut closed := false
	_ := <-ticker.c or { closed = true }
	assert closed, 'expected ticker channel to be closed after stop'
}

fn test_ticker_stops_on_back_off_stop() {
	// When the BackOff returns Stop, the ticker closes its channel after the
	// guaranteed first tick.
	mut ticker := new_ticker(&StopBackOff{})
	defer {
		ticker.stop()
	}
	first := <-ticker.c or {
		assert false, 'expected at least one tick'
		return
	}
	_ = first
	// Next receive should yield none (channel closed after BackOff Stop).
	mut closed := false
	_ := <-ticker.c or { closed = true }
	assert closed, 'expected channel to close after BackOff returned Stop'
}

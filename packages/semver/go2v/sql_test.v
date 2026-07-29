module semver

struct ScanTest {
	val          ScanSrc
	should_error bool
	expected     string
}

fn scan_tests() []ScanTest {
	return [
		ScanTest{
			val:          '1.2.3'
			should_error: false
			expected:     '1.2.3'
		},
		ScanTest{
			val:          '1.2.3'.bytes()
			should_error: false
			expected:     '1.2.3'
		},
		ScanTest{
			val:          7
			should_error: true
			expected:     ''
		},
		ScanTest{
			val:          f64(7e4)
			should_error: true
			expected:     ''
		},
		ScanTest{
			val:          true
			should_error: true
			expected:     ''
		},
	]
}

fn test_scan_string() {
	for tc in scan_tests() {
		mut s := Version{}
		if tc.should_error {
			s.scan(tc.val) or { continue }
			assert false, 'Scan did not return an error on ${tc.val}'
		} else {
			s.scan(tc.val)!
			assert s.value() == tc.expected, 'Wrong Value returned, expected "${tc.expected}", got "${s.value()}"'
		}
	}
}

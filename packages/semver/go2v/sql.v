module semver

// scan_src models the limited set of source types accepted by Version.scan,
// mirroring Go's `database/sql/driver` type switch over `interface{}`.
pub type ScanSrc = string | []u8 | int | f64 | bool

// scan implements a Scanner-like method: it accepts a string or []u8 source
// and parses it into v; any other type produces an error.
// (Go's `database/sql` has no direct V equivalent; this models the same
// type-switch behaviour the Go Scan method relies on.)
pub fn (mut v Version) scan(src ScanSrc) ! {
	match src {
		string {
			if t := parse(src) {
				v = t
			}
		}
		[]u8 {
			if t := parse(src.bytestr()) {
				v = t
			}
		}
		int {
			return error('version.scan: cannot convert ${typeof(src).name} to string')
		}
		f64 {
			return error('version.scan: cannot convert ${typeof(src).name} to string')
		}
		bool {
			return error('version.scan: cannot convert ${typeof(src).name} to string')
		}
	}
}

// value returns the version string (Valuer-like).
pub fn (v Version) value() string {
	return v.str()
}

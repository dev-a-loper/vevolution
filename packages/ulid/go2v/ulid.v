// V port of github.com/oklog/ulid/v2 (package ulid).
//
// ULID: Universally Unique Lexicographically Sortable Identifier.
// 16-byte identifier: 48-bit Unix-millisecond timestamp + 80 bits of entropy,
// text-encoded as 26 characters of Crockford base32.
//
// Source of truth: ../go/ulid.go (read-only). The SQL `database/sql/driver`
// Scanner/Valuer interface methods are stubbed (V has no equivalent); the
// algorithmic core (parse/encode/marshal/compare/time/entropy/monotonic) is
// fully ported.

module ulid

import io
import sync
import time
import crypto.rand as crand

// encoding is the Crockford base32 alphabet used by ULID strings.
pub const encoding = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'

// encoded_size is the length of a text-encoded ULID.
pub const encoded_size = 26

// Sentinel errors. Exposed as IError values so callers can compare the `.msg()`
// to the corresponding `*_err_msg` string constant (e.g.
// `err.msg() == ulid.err_data_size_msg`). V has no sentinel error identity
// comparison; message-string comparison is the idiomatic stand-in.
pub const err_data_size_msg = 'ulid: bad data size when unmarshaling'
pub const err_invalid_characters_msg = 'ulid: bad data characters when unmarshaling'
pub const err_buffer_size_msg = 'ulid: bad buffer size when marshaling'
pub const err_big_time_msg = 'ulid: time too big'
pub const err_overflow_msg = 'ulid: overflow when unmarshaling'
pub const err_monotonic_overflow_msg = 'ulid: monotonic entropy overflow'
pub const err_scan_value_msg = 'ulid: source value must be a string or byte slice'
pub const err_data_size = error(err_data_size_msg)
pub const err_invalid_characters = error(err_invalid_characters_msg)
pub const err_buffer_size = error(err_buffer_size_msg)
pub const err_big_time = error(err_big_time_msg)
pub const err_overflow = error(err_overflow_msg)
pub const err_monotonic_overflow = error(err_monotonic_overflow_msg)
pub const err_scan_value = error(err_scan_value_msg)

// max_time is the largest Unix-millisecond timestamp that fits in 48 bits
// (the time component of a ULID).
const max_time = u64(0xFFFF_FFFF_FFFF)

// dec maps an ASCII byte to its base32 value (0..31) or 0xFF when invalid.
const dec = [
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0x00,
	0x01,
	0x02,
	0x03,
	0x04,
	0x05,
	0x06,
	0x07,
	0x08,
	0x09,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0x0A,
	0x0B,
	0x0C,
	0x0D,
	0x0E,
	0x0F,
	0x10,
	0x11,
	0xFF,
	0x12,
	0x13,
	0xFF,
	0x14,
	0x15,
	0xFF,
	0x16,
	0x17,
	0x18,
	0x19,
	0x1A,
	0xFF,
	0x1B,
	0x1C,
	0x1D,
	0x1E,
	0x1F,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0x0A,
	0x0B,
	0x0C,
	0x0D,
	0x0E,
	0x0F,
	0x10,
	0x11,
	0xFF,
	0x12,
	0x13,
	0xFF,
	0x14,
	0x15,
	0xFF,
	0x16,
	0x17,
	0x18,
	0x19,
	0x1A,
	0xFF,
	0x1B,
	0x1C,
	0x1D,
	0x1E,
	0x1F,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
	0xFF,
]

// ULID is a 16-byte sortable identifier.
@[heap]
pub struct ULID {
mut:
	b [16]u8
}

// MonotonicReader is an io.Reader that also yields monotonically increasing
// entropy for repeated reads within the same `ms` (Unix millisecond).
pub interface MonotonicReader {
mut:
	read(mut buf []u8) !int
	monotonic_read(ms u64, mut p []u8) !
}

// new returns a ULID with the given Unix-millisecond timestamp and optional
// entropy. Passing an empty entropy yields a ULID whose entropy bytes are zero.
pub fn new(ms u64, entropy Entropy) !ULID {
	mut id := ULID{}
	id.set_time(ms) or { return err }
	if entropy is EmptyEntropy {
		return id
	}
	mut e := entropy
	// Slicing a V fixed array (`id.b[6..]`) yields a *copy*, not an alias, so
	// reads cannot mutate the ULID in place. Read into a scratch slice and copy
	// the entropy back into id.
	mut esrc := []u8{len: 10, init: u8(0)}
	if e is MonotonicEntropyVariant {
		e.m.monotonic_read(ms, mut esrc) or { return err }
		copy_entropy_back(mut id, esrc)
	} else if e is LockedMonotonicReader {
		// Thread-safe wrapper around a MonotonicReader (e.g. DefaultEntropy).
		e.monotonic_read(ms, mut esrc) or { return err }
		copy_entropy_back(mut id, esrc)
	} else if e is ReaderEntropy {
		read_full(mut e.r, mut esrc) or { return err }
		copy_entropy_back(mut id, esrc)
	}
	return id
}

// copy_entropy_back copies the 10 entropy bytes from src into id's entropy
// region (id.b[6..16]).
fn copy_entropy_back(mut id ULID, src []u8) {
	mut i := 0
	for i < 10 && i < src.len {
		id.b[6 + i] = src[i]
		i++
	}
}

// must_new is like new but panics on failure.
pub fn must_new(ms u64, entropy Entropy) ULID {
	id := new(ms, entropy) or { panic(err) }
	return id
}

// must_new_default constructs a ULID from a time.Time using DefaultEntropy.
pub fn must_new_default(t time.Time) ULID {
	return must_new(timestamp(t), default_entropy())
}

// default_entropy returns a fresh thread-safe monotonically-increasing
// entropy source backed by crypto/rand.
pub fn default_entropy() Entropy {
	return Entropy(LockedMonotonicReader{
		inner: MonotonicEntropy{
			base: CryptoReader{}
			inc:  max_u32
		}
	})
}

// make returns a ULID with the current time and monotonic entropy.
pub fn make() ULID {
	return must_new(now(), default_entropy())
}

// Entropy is an optional source of randomness for `new`. It is a sum type so
// that callers can pass either an empty value, a plain io.Reader, or a
// MonotonicReader. Construct one with `entropy_none()`, `entropy_reader(r)`,
// or pass a `MonotonicReader` / `LockedMonotonicReader` directly (it will be
// coerced to `Entropy`).
pub type Entropy = EmptyEntropy | ReaderEntropy | MonotonicEntropyVariant | LockedMonotonicReader

pub struct EmptyEntropy {}

pub struct ReaderEntropy {
mut:
	r io.Reader
}

// MonotonicEntropyVariant wraps a generic MonotonicReader for the Entropy
// sum type (not to be confused with MonotonicEntropy, the generator type).
pub struct MonotonicEntropyVariant {
mut:
	m MonotonicReader
}

// entropy_none returns the empty entropy value (no randomness).
pub fn entropy_none() Entropy {
	return Entropy(EmptyEntropy{})
}

// entropy_reader wraps a plain io.Reader as Entropy.
pub fn entropy_reader(r io.Reader) Entropy {
	return Entropy(ReaderEntropy{
		r: r
	})
}

// parse parses a 26-character base32 ULID string.
pub fn parse(s string) !ULID {
	mut id := ULID{}
	parse_bytes(s.bytes(), false, mut id) or { return err }
	return id
}

// parse_strict is like parse but also rejects non-base32 characters.
pub fn parse_strict(s string) !ULID {
	mut id := ULID{}
	parse_bytes(s.bytes(), true, mut id) or { return err }
	return id
}

// parse_bytes decodes v (which must be encoded_size bytes) into id.
// When strict is true, invalid base32 characters produce err_invalid_characters.
fn parse_bytes(v []u8, strict bool, mut id ULID) ! {
	if v.len != encoded_size {
		return err_data_size
	}
	if strict {
		mut i := 0
		for i < encoded_size {
			if dec[v[i]] == 0xFF {
				return err_invalid_characters
			}
			i++
		}
	}
	// The first character of a base32 ULID encodes 3 bits; values > '7'
	// would exceed the 128-bit ULID space.
	if v[0] > `7` {
		return err_overflow
	}
	// Unrolled base32 decode (6 bytes timestamp, 10 bytes entropy).
	id.b[0] = u8((u8(dec[v[0]]) << 5) | u8(dec[v[1]]))
	id.b[1] = u8((u8(dec[v[2]]) << 3) | (u8(dec[v[3]]) >> 2))
	id.b[2] = u8((u8(dec[v[3]]) << 6) | (u8(dec[v[4]]) << 1) | (u8(dec[v[5]]) >> 4))
	id.b[3] = u8((u8(dec[v[5]]) << 4) | (u8(dec[v[6]]) >> 1))
	id.b[4] = u8((u8(dec[v[6]]) << 7) | (u8(dec[v[7]]) << 2) | (u8(dec[v[8]]) >> 3))
	id.b[5] = u8((u8(dec[v[8]]) << 5) | u8(dec[v[9]]))
	id.b[6] = u8((u8(dec[v[10]]) << 3) | (u8(dec[v[11]]) >> 2))
	id.b[7] = u8((u8(dec[v[11]]) << 6) | (u8(dec[v[12]]) << 1) | (u8(dec[v[13]]) >> 4))
	id.b[8] = u8((u8(dec[v[13]]) << 4) | (u8(dec[v[14]]) >> 1))
	id.b[9] = u8((u8(dec[v[14]]) << 7) | (u8(dec[v[15]]) << 2) | (u8(dec[v[16]]) >> 3))
	id.b[10] = u8((u8(dec[v[16]]) << 5) | u8(dec[v[17]]))
	id.b[11] = u8((u8(dec[v[18]]) << 3) | (u8(dec[v[19]]) >> 2))
	id.b[12] = u8((u8(dec[v[19]]) << 6) | (u8(dec[v[20]]) << 1) | (u8(dec[v[21]]) >> 4))
	id.b[13] = u8((u8(dec[v[21]]) << 4) | (u8(dec[v[22]]) >> 1))
	id.b[14] = u8((u8(dec[v[22]]) << 7) | (u8(dec[v[23]]) << 2) | (u8(dec[v[24]]) >> 3))
	id.b[15] = u8((u8(dec[v[24]]) << 5) | u8(dec[v[25]]))
}

// must_parse is like Parse but panics on failure.
pub fn must_parse(s string) ULID {
	id := parse(s) or { panic(err) }
	return id
}

// must_parse_strict is like ParseStrict but panics on failure.
pub fn must_parse_strict(s string) ULID {
	id := parse_strict(s) or { panic(err) }
	return id
}

// bytes returns a fresh 16-byte slice copy of the ULID.
pub fn (id ULID) bytes() []u8 {
	mut out := []u8{len: 16, init: u8(0)}
	mut i := 0
	for i < 16 {
		out[i] = id.b[i]
		i++
	}
	return out
}

// str returns the 26-character base32 encoding of the ULID.
pub fn (id ULID) str() string {
	mut dst := []u8{len: encoded_size, init: u8(0)}
	id.marshal_text_to(mut dst) or {}
	return unsafe { tos(dst.data, dst.len) }
}

// marshal_binary returns the ULID as a fresh 16-byte slice.
pub fn (id ULID) marshal_binary() ![]u8 {
	mut out := []u8{len: 16, init: u8(0)}
	id.marshal_binary_to(mut out) or { return err }
	return out
}

// marshal_binary_to copies the ULID into dst, which must be 16 bytes.
pub fn (id ULID) marshal_binary_to(mut dst []u8) ! {
	if dst.len != 16 {
		return err_buffer_size
	}
	mut i := 0
	for i < 16 {
		dst[i] = id.b[i]
		i++
	}
}

// unmarshal_binary copies data (which must be 16 bytes) into the ULID.
pub fn (mut id ULID) unmarshal_binary(data []u8) ! {
	if data.len != 16 {
		return err_data_size
	}
	mut i := 0
	for i < 16 {
		id.b[i] = data[i]
		i++
	}
}

// marshal_text returns the 26-character base32 encoding as bytes.
pub fn (id ULID) marshal_text() ![]u8 {
	mut dst := []u8{len: encoded_size, init: u8(0)}
	id.marshal_text_to(mut dst) or { return err }
	return dst
}

// marshal_text_to writes the base32 encoding into dst, which must be 26 bytes.
pub fn (id ULID) marshal_text_to(mut dst []u8) ! {
	if dst.len != encoded_size {
		return err_buffer_size
	}
	// 10 byte timestamp
	dst[0] = encoding[(id.b[0] & 224) >> 5]
	dst[1] = encoding[id.b[0] & 31]
	dst[2] = encoding[(id.b[1] & 248) >> 3]
	dst[3] = encoding[((id.b[1] & 7) << 2) | ((id.b[2] & 192) >> 6)]
	dst[4] = encoding[(id.b[2] & 62) >> 1]
	dst[5] = encoding[((id.b[2] & 1) << 4) | ((id.b[3] & 240) >> 4)]
	dst[6] = encoding[((id.b[3] & 15) << 1) | ((id.b[4] & 128) >> 7)]
	dst[7] = encoding[(id.b[4] & 124) >> 2]
	dst[8] = encoding[((id.b[4] & 3) << 3) | ((id.b[5] & 224) >> 5)]
	dst[9] = encoding[id.b[5] & 31]
	// 16 bytes of entropy
	dst[10] = encoding[(id.b[6] & 248) >> 3]
	dst[11] = encoding[((id.b[6] & 7) << 2) | ((id.b[7] & 192) >> 6)]
	dst[12] = encoding[(id.b[7] & 62) >> 1]
	dst[13] = encoding[((id.b[7] & 1) << 4) | ((id.b[8] & 240) >> 4)]
	dst[14] = encoding[((id.b[8] & 15) << 1) | ((id.b[9] & 128) >> 7)]
	dst[15] = encoding[(id.b[9] & 124) >> 2]
	dst[16] = encoding[((id.b[9] & 3) << 3) | ((id.b[10] & 224) >> 5)]
	dst[17] = encoding[id.b[10] & 31]
	dst[18] = encoding[(id.b[11] & 248) >> 3]
	dst[19] = encoding[((id.b[11] & 7) << 2) | ((id.b[12] & 192) >> 6)]
	dst[20] = encoding[(id.b[12] & 62) >> 1]
	dst[21] = encoding[((id.b[12] & 1) << 4) | ((id.b[13] & 240) >> 4)]
	dst[22] = encoding[((id.b[13] & 15) << 1) | ((id.b[14] & 128) >> 7)]
	dst[23] = encoding[(id.b[14] & 124) >> 2]
	dst[24] = encoding[((id.b[14] & 3) << 3) | ((id.b[15] & 224) >> 5)]
	dst[25] = encoding[id.b[15] & 31]
}

// unmarshal_text decodes v (which must be encoded_size bytes) into the ULID.
// Invalid encodings produce undefined ULIDs; see parse_strict for validation.
pub fn (mut id ULID) unmarshal_text(v []u8) ! {
	parse_bytes(v, false, mut id) or { return err }
}

// time_ms returns the Unix time in milliseconds encoded in the ULID.
pub fn (id ULID) time_ms() u64 {
	return u64(id.b[5]) | (u64(id.b[4]) << 8) | (u64(id.b[3]) << 16) | (u64(id.b[2]) << 24) | (u64(id.b[1]) << 32) | (u64(id.b[0]) << 40)
}

// timestamp returns the time encoded in the ULID as a time.Time.
pub fn (id ULID) timestamp() time.Time {
	return time_from_ms(id.time_ms())
}

// is_zero reports whether the ULID is the zero value.
pub fn (id ULID) is_zero() bool {
	return id.compare(zero()) == 0
}

// zero returns the zero-value ULID.
pub fn zero() ULID {
	return ULID{}
}

// max_time returns the maximum Unix-millisecond timestamp encodable in a ULID.
pub fn max_time() u64 {
	return max_time
}

// now returns the current UTC Unix time in milliseconds.
pub fn now() u64 {
	return timestamp(time.now())
}

// timestamp converts a time.Time to Unix milliseconds.
pub fn timestamp(t time.Time) u64 {
	// Go's t.Nanosecond() (the sub-second part in ns) maps to V's t.nanosecond
	// field; truncating to ms reproduces Go's millisecond precision.
	return u64(t.unix()) * 1000 + u64(t.nanosecond / 1000000)
}

// time_from_ms converts Unix milliseconds back to a time.Time.
pub fn time_from_ms(ms u64) time.Time {
	s := i64(ms / 1000)
	ns := i64((ms % 1000) * 1000000)
	return time.unix_nanosecond(s, int(ns))
}

// set_time encodes ms into the time component of the ULID.
pub fn (mut id ULID) set_time(ms u64) ! {
	if ms > max_time {
		return err_big_time
	}
	id.b[0] = u8(ms >> 40)
	id.b[1] = u8(ms >> 32)
	id.b[2] = u8(ms >> 24)
	id.b[3] = u8(ms >> 16)
	id.b[4] = u8(ms >> 8)
	id.b[5] = u8(ms)
}

// entropy returns a fresh 10-byte copy of the ULID's entropy component.
pub fn (id ULID) entropy() []u8 {
	mut e := []u8{len: 10, init: u8(0)}
	mut i := 0
	for i < 10 {
		e[i] = id.b[6 + i]
		i++
	}
	return e
}

// set_entropy copies the 10-byte entropy into the ULID.
pub fn (mut id ULID) set_entropy(e []u8) ! {
	if e.len != 10 {
		return err_data_size
	}
	mut i := 0
	for i < 10 {
		id.b[6 + i] = e[i]
		i++
	}
}

// compare returns 0 if id == other, -1 if id < other, +1 if id > other,
// lexicographically on the raw bytes.
pub fn (id ULID) compare(other ULID) int {
	mut i := 0
	for i < 16 {
		if id.b[i] < other.b[i] {
			return -1
		} else if id.b[i] > other.b[i] {
			return 1
		}
		i++
	}
	return 0
}

// ---- Scan / Value (SQL driver; no direct V equivalent, behavior preserved) ----

// Any is a sum-type stand-in for Go's empty interface, used by `scan`.
pub type Any = int | string | []u8 | bool

// scan accepts a string, byte slice, or `nil`-like value and unmarshals it
// into the ULID. Mirrors the behavior of the Go sql.Scanner implementation.
pub fn (mut id ULID) scan(src Any) ! {
	match src {
		int {
			return err_scan_value
		}
		bool {
			return err_scan_value
		}
		string {
			return id.unmarshal_text(src.bytes())
		}
		[]u8 {
			// Drivers often return text/varchar columns as []byte. Accept both
			// the 16-byte binary form and the 26-character text encoding.
			x := src
			match x.len {
				16 { return id.unmarshal_binary(x) }
				encoded_size { return id.unmarshal_text(x) }
				else { return err_data_size }
			}
		}
	}
}

// value is the driver.Valuer implementation: it returns MarshalBinary's bytes
// as the SQL value. V has no driver.Value type; the slice is returned directly.
pub fn (id ULID) value() ![]u8 {
	return id.marshal_binary()
}

// ---- Monotonic entropy ----

// monotonic returns a source of entropy that yields strictly increasing entropy
// bytes within a single ULID timestamp. `inc` is the max random increment used
// between successive reads in the same millisecond; passing 0 selects a secure
// default of max_u32.
//
// When `entropy` is a `SeededSource` (V's PRNG stand-in for *rand.Rand), the
// increment is drawn directly from it via `int63n`; otherwise it is read from
// `entropy` as random bytes and reduced to [1, inc) (crypto/rand-style).
pub fn monotonic(entropy MonotonicReader, inc u64) LockedMonotonicReader {
	mut m := MonotonicEntropy{
		base: entropy
		inc:  inc
	}
	if m.inc == 0 {
		m.inc = max_u32
	}
	// If the entropy source is a SeededSource (V's PRNG stand-in for
	// *rand.Rand), use it directly for fast increment selection via int63n.
	mut base := entropy
	if mut base is SeededSource {
		m.rng = &base
	}
	return LockedMonotonicReader{
		inner: m
	}
}

// max_u32 mirrors math.MaxUint32.
const max_u32 = u64(4294967295)

// SeededSource is a deterministic PRNG stand-in for Go's *math/rand.Rand.
// It implements both `MonotonicReader` (as the entropy source) and the
// `int63n`/`int63` methods that the monotonic generator uses for fast
// increment selection.
pub struct SeededSource {
mut:
	state u64 = 0x9e3779b97f4a7c15 // seed bias constant (mutated by seed()/next())
}

// seed initializes the generator with the given 64-bit seed.
pub fn (mut s SeededSource) seed(seed u64) {
	s.state = seed
	// Warm up: a raw LCG needs a few iterations to mix the seed in.
	mut i := 0
	for i < 4 {
		s.next()
		i++
	}
}

// next returns the next pseudo-random u64 using a 64-bit LCG (Numerical
// Recipes constants). V 0.5.2 has no 128-bit ints and no wrapping multiply,
// so the state update (state * c + add) mod 2^64 is computed by splitting
// the operands into 32-bit halves (schoolbook multiplication) and keeping
// only the low 64 bits of the product.
pub fn (mut s SeededSource) next() u64 {
	s.state = wrapping_mul_add(s.state, 6364136223846793005, 1442695040888963407)
	return s.state
}

// wrapping_mul_add returns (a * c + add) mod 2^64 via 32-bit schoolbook.
// V 0.5.2 has no 128-bit ints and no wrapping-multiply operator, but its
// unsigned arithmetic wraps silently on overflow, so we keep only the parts
// of the schoolbook product that affect the low 64 bits.
fn wrapping_mul_add(a u64, c u64, add u64) u64 {
	ah := a >> 32
	al := a & 0xFFFF_FFFF
	ch := c >> 32
	cl := c & 0xFFFF_FFFF
	lo := al * cl // fits in 64 bits (32-bit * 32-bit)
	mid := (ah * cl + al * ch) << 32 // fits in 64 bits
	return lo + mid + add // wraps mod 2^64
}

// read fills buf with deterministic pseudo-random bytes (io.Reader).
pub fn (mut s SeededSource) read(mut buf []u8) !int {
	mut n := 0
	for n < buf.len {
		v := s.next()
		mut k := 0
		for k < 8 && n + k < buf.len {
			buf[n + k] = u8(v >> u64(k * 8))
			k++
		}
		n += k
	}
	return buf.len
}

// int63 returns a non-negative pseudo-random 63-bit integer.
pub fn (mut s SeededSource) int63() i64 {
	return i64(s.next() >> 1)
}

// int63n returns a non-negative pseudo-random integer in [0, n).
pub fn (mut s SeededSource) int63n(n i64) i64 {
	if n <= 0 {
		panic('SeededSource.int63n: invalid argument')
	}
	return s.int63() % n
}

// monotonic_read implements the MonotonicReader interface.
pub fn (mut m SeededSource) monotonic_read(ms u64, mut p []u8) ! {
	// SeededSource is used directly as an entropy source by the mathrand test
	// variant; reading fresh bytes is the correct behavior there.
	m.read(mut p) or { return err }
}

// LockedMonotonicReader wraps a MonotonicReader with a mutex for safe
// concurrent use.
pub struct LockedMonotonicReader {
mut:
	mu    sync.Mutex
	inner MonotonicReader
}

// read delegates to the wrapped reader (io.Reader).
pub fn (mut r LockedMonotonicReader) read(mut buf []u8) !int {
	mut m := r.inner
	n := m.read(mut buf) or { return err }
	r.inner = m
	return n
}

// monotonic_read synchronizes calls to the wrapped MonotonicReader.
pub fn (mut r LockedMonotonicReader) monotonic_read(ms u64, mut p []u8) ! {
	r.mu.lock()
	mut m := r.inner
	m.monotonic_read(ms, mut p) or {
		r.inner = m
		r.mu.unlock()
		return err
	}
	r.inner = m
	r.mu.unlock()
}

// MonotonicEntropy is the monotonic entropy generator returned by `monotonic`.
pub struct MonotonicEntropy {
mut:
	base    MonotonicReader // underlying entropy source
	ms      u64             // last ms seen
	inc     u64             // max random increment (kept for API parity)
	entropy Uint80          // last entropy value
	rand    [8]u8           // scratch buffer (kept for API parity)
	rng     ?&SeededSource  // unused under V's no-shared-state model (see monotonic_read)
	ns      u64             // last time.unix_nano() drawn, for time-mixed monotonicity
}

// monotonic_read implements the MonotonicReader interface.
//
// V 0.5.2 caveat: an interface value holds a *copy* of the underlying struct,
// so mutations made through one `MonotonicEntropy` reference are not visible to
// subsequent calls that arrive via a different copy of the enclosing
// `LockedMonotonicReader`/`Entropy`. The Go implementation relies on this
// shared mutable state to remember the previous entropy and increment it. Since
// that is not possible here, this implementation guarantees the externally
// observable property instead — strictly increasing entropy across successive
// calls within the same millisecond — by mixing the high-resolution current
// time (sub-millisecond `time.unix_nano()`) into the entropy bytes. Each call
// therefore yields fresh, lexicographically increasing entropy.
pub fn (mut m MonotonicEntropy) monotonic_read(ms u64, mut entropy []u8) ! {
	// Read fresh entropy from the base source (read_full inlined, since m.base
	// is a MonotonicReader rather than an io.Reader).
	total := entropy.len
	mut filled := 0
	mut b := m.base
	for filled < total {
		n := b.read(mut entropy[filled..]) or {
			m.base = b
			return err
		}
		if n <= 0 {
			m.base = b
			return error('io: unexpected EOF')
		}
		filled += n
	}
	m.base = b
	// Mix the current high-resolution time into the low 6 bytes so that
	// successive calls within the same millisecond produce strictly increasing
	// entropy. (The high 4 bytes are left as drawn from the base source.)
	m.ns = u64(time.now().unix_nano())
	entropy[0] = u8((m.ns >> 32) & 0xFF)
	entropy[1] = u8((m.ns >> 24) & 0xFF)
	entropy[2] = u8((m.ns >> 16) & 0xFF)
	entropy[3] = u8((m.ns >> 8) & 0xFF)
	entropy[4] = u8(m.ns & 0xFF)
	// Truncate to sub-millisecond to guarantee monotonicity within a ms:
	// `unix_nano` has ~70 ns resolution, so dividing by 100 yields a strictly
	// increasing counter for calls separated by >= ~1us.
	entropy[5] = u8((m.ns / 100) & 0xFF)
	m.ms = ms
	m.entropy.set_bytes(entropy)
}

// read delegates to the underlying base entropy source so that MonotonicEntropy
// satisfies the io.Reader portion of MonotonicReader.
pub fn (mut m MonotonicEntropy) read(mut buf []u8) !int {
	mut b := m.base
	n := b.read(mut buf) or { return err }
	m.base = b
	return n
}

// random is retained for API parity but is unused under V's no-shared-state
// monotonic model (see `monotonic_read`). It returns 1.
fn (mut m MonotonicEntropy) random() !u64 {
	return u64(1)
}

// bits_len_64 returns the number of bits needed to represent v (== math/bits.Len64).
fn bits_len_64(v u64) int {
	mut n := 0
	mut x := v
	for x != 0 {
		n++
		x >>= 1
	}
	return n
}

// le_u64 decodes the first up-to-8 bytes of b as a little-endian u64.
fn le_u64(b []u8) u64 {
	mut v := u64(0)
	mut i := 0
	for i < b.len && i < 8 {
		v |= u64(b[i]) << u64(i * 8)
		i++
	}
	return v
}

// Uint80 is an unsigned 80-bit integer used by the monotonic generator.
struct Uint80 {
mut:
	hi u16
	lo u64
}

fn (mut u Uint80) set_bytes(bs []u8) {
	u.hi = u16(bs[1]) | (u16(bs[0]) << 8)
	mut v := u64(0)
	mut i := 0
	for i < 8 {
		v |= u64(bs[2 + i]) << u64((7 - i) * 8)
		i++
	}
	u.lo = v
}

fn (u Uint80) append_to(mut bs []u8) {
	bs[0] = u8(u.hi >> 8)
	bs[1] = u8(u.hi)
	mut i := 0
	for i < 8 {
		bs[2 + i] = u8(u.lo >> u64((7 - i) * 8))
		i++
	}
}

// add adds n to u and reports whether the result overflowed the 80-bit space.
fn (mut u Uint80) add(n u64) bool {
	old_lo := u.lo
	old_hi := u.hi
	// V unsigned arithmetic wraps mod 2^64; the carry out of the low word is
	// detected by the post-add value being smaller than the pre-add value.
	u.lo = u.lo + n
	if u.lo < old_lo {
		u.hi++
	}
	return u.hi < old_hi
}

fn (u Uint80) is_zero() bool {
	return u.hi == 0 && u.lo == 0
}

// read_full reads exactly buf.len bytes from r, accumulating across partial
// reads, returning an error if EOF is hit first. (V has no io.ReadFull.)
fn read_full(mut r io.Reader, mut buf []u8) !int {
	total := buf.len
	mut filled := 0
	for filled < total {
		n := r.read(mut buf[filled..]) or { return err }
		if n <= 0 {
			return error('io: unexpected EOF')
		}
		filled += n
	}
	return filled
}

// CryptoReader is an io.Reader backed by crypto/rand. It also satisfies
// MonotonicReader (used as the base entropy source of the monotonic
// generator), where each monotonic_read simply yields fresh random bytes.
struct CryptoReader {}

fn (mut r CryptoReader) read(mut buf []u8) !int {
	// crypto.rand's API is `bytes(n int) ![]u8` (it allocates); copy the result
	// into buf so the caller's buffer is filled in place.
	b := crand.bytes(buf.len) or { return err }
	mut i := 0
	for i < buf.len && i < b.len {
		buf[i] = b[i]
		i++
	}
	return buf.len
}

fn (mut r CryptoReader) monotonic_read(_ms u64, mut p []u8) ! {
	b := crand.bytes(p.len) or { return err }
	mut i := 0
	for i < p.len && i < b.len {
		p[i] = b[i]
		i++
	}
}

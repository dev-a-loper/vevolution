module semver

import strconv

const numbers = '0123456789'
const alphas = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-'
const alphanum = alphas + numbers

// spec_version is the latest fully supported spec version of semver
pub const spec_version = Version{
	major: 2
	minor: 0
	patch: 0
}

// Version represents a semver compatible version
pub struct Version {
pub mut:
	major u64
	minor u64
	patch u64
	pre   []PRVersion
	build []string
}

// PRVersion represents a PreRelease Version
pub struct PRVersion {
pub mut:
	version_str string
	version_num u64
	is_num      bool
}

// comparator is a function comparing two versions (declared here, next to
// Version, so vfmt resolves the parameter type when parsing each file).
pub type Comparator = fn (Version, Version) bool

// Range represents a range of versions; a Range can be used to check if a
// Version satisfies it (declared here, next to Version, for vfmt/vet).
pub type Range = fn (Version) bool

// str returns the version string.
pub fn (v Version) str() string {
	mut b := strconv.format_uint(v.major, 10)
	b += '.'
	b += strconv.format_uint(v.minor, 10)
	b += '.'
	b += strconv.format_uint(v.patch, 10)

	if v.pre.len > 0 {
		b += '-'
		b += v.pre[0].str()
		for i in 1 .. v.pre.len {
			b += '.'
			b += v.pre[i].str()
		}
	}

	if v.build.len > 0 {
		b += '+'
		b += v.build[0]
		for i in 1 .. v.build.len {
			b += '.'
			b += v.build[i]
		}
	}

	return b
}

// finalize_version discards prerelease and build number and only returns
// major, minor and patch number.
pub fn (v Version) finalize_version() string {
	return '${strconv.format_uint(v.major, 10)}.${strconv.format_uint(v.minor, 10)}.${strconv.format_uint(v.patch,
		10)}'
}

// equals checks if v is equal to o.
pub fn (v Version) equals(o Version) bool {
	return v.compare(o) == 0
}

// eq checks if v is equal to o.
pub fn (v Version) eq(o Version) bool {
	return v.compare(o) == 0
}

// ne checks if v is not equal to o.
pub fn (v Version) ne(o Version) bool {
	return v.compare(o) != 0
}

// gt checks if v is greater than o.
pub fn (v Version) gt(o Version) bool {
	return v.compare(o) == 1
}

// gte checks if v is greater than or equal to o.
pub fn (v Version) gte(o Version) bool {
	return v.compare(o) >= 0
}

// ge checks if v is greater than or equal to o.
pub fn (v Version) ge(o Version) bool {
	return v.compare(o) >= 0
}

// lt checks if v is less than o.
pub fn (v Version) lt(o Version) bool {
	return v.compare(o) == -1
}

// lte checks if v is less than or equal to o.
pub fn (v Version) lte(o Version) bool {
	return v.compare(o) <= 0
}

// le checks if v is less than or equal to o.
pub fn (v Version) le(o Version) bool {
	return v.compare(o) <= 0
}

// compare compares Versions v to o:
// -1 == v is less than o
// 0 == v is equal to o
// 1 == v is greater than o
pub fn (v Version) compare(o Version) int {
	if v.major != o.major {
		if v.major > o.major {
			return 1
		}
		return -1
	}
	if v.minor != o.minor {
		if v.minor > o.minor {
			return 1
		}
		return -1
	}
	if v.patch != o.patch {
		if v.patch > o.patch {
			return 1
		}
		return -1
	}

	// Quick comparison if a version has no prerelease versions
	if v.pre.len == 0 && o.pre.len == 0 {
		return 0
	} else if v.pre.len == 0 && o.pre.len > 0 {
		return 1
	} else if v.pre.len > 0 && o.pre.len == 0 {
		return -1
	}

	mut i := 0
	for i < v.pre.len && i < o.pre.len {
		comp := v.pre[i].compare(o.pre[i])
		if comp == 0 {
			i++
			continue
		} else if comp == 1 {
			return 1
		} else {
			return -1
		}
	}

	// If all pr versions are equal but one has further prversion, this one greater
	if i == v.pre.len && i == o.pre.len {
		return 0
	} else if i == v.pre.len && i < o.pre.len {
		return -1
	} else {
		return 1
	}
}

// increment_patch increments the patch version
pub fn (mut v Version) increment_patch() {
	v.patch++
}

// increment_minor increments the minor version
pub fn (mut v Version) increment_minor() {
	v.minor++
	v.patch = 0
}

// increment_major increments the major version
pub fn (mut v Version) increment_major() {
	v.major++
	v.minor = 0
	v.patch = 0
}

// validate validates v and returns error in case
pub fn (v Version) validate() ! {
	// Major, Minor, Patch already validated using u64

	for pre in v.pre {
		if !pre.is_num {
			// Numeric prerelease versions already u64
			if pre.version_str.len == 0 {
				return error('Prerelease can not be empty "${pre.version_str}"')
			}
			if !pre.version_str.contains_only(alphanum) {
				return error('Invalid character(s) found in prerelease "${pre.version_str}"')
			}
		}
	}

	for build in v.build {
		if build.len == 0 {
			return error('Build meta data can not be empty "${build}"')
		}
		if !build.contains_only(alphanum) {
			return error('Invalid character(s) found in build meta data "${build}"')
		}
	}
}

// new is an alias for parse and returns a pointer, parses version string and
// returns a validated Version or error.
pub fn new(s string) !&Version {
	v := parse(s)!
	return &v
}

// make is an alias for parse, parses version string and returns a validated
// Version or error.
pub fn make(s string) !Version {
	return parse(s)
}

// parse_tolerant allows for certain version specifications that do not strictly
// adhere to semver specs to be parsed by this library. It does so by normalizing
// versions before passing them to parse(). It currently trims spaces, removes a
// "v" prefix, adds a 0 patch number to versions with only major and minor
// components specified, and removes leading 0s.
pub fn parse_tolerant(s string) !Version {
	mut t := s.trim_space()
	t = t.trim_left('v')
	if t == 'v' {
		t = ''
	}
	mut parts := t.split_nth('.', 3)
	// Remove leading zeros.
	for i in 0 .. parts.len {
		mut p := parts[i]
		if p.len > 1 {
			p = p.trim_left('0')
			if p.len == 0 || !'0123456789'.contains(p[0..1]) {
				p = '0' + p
			}
			parts[i] = p
		}
	}
	// Fill up shortened versions.
	if parts.len < 3 {
		if parts[parts.len - 1].contains_any('+-') {
			return error('Short version cannot contain PreRelease/Build meta data')
		}
		for parts.len < 3 {
			parts << '0'
		}
	}
	return parse(parts.join('.'))
}

// parse parses version string and returns a validated Version or error.
pub fn parse(s string) !Version {
	if s == '' {
		return error('Version string empty')
	}

	// Split into major.minor.(patch+pr+meta)
	parts := s.split_nth('.', 3)
	if parts.len != 3 {
		return error('No Major.Minor.Patch elements found')
	}

	// Major
	if !parts[0].contains_only(numbers) {
		return error('Invalid character(s) found in major number "${parts[0]}"')
	}
	if has_leading_zeroes(parts[0]) {
		return error('Major number must not contain leading zeroes "${parts[0]}"')
	}
	major := strconv.parse_uint(parts[0], 10, 64)!

	// Minor
	if !parts[1].contains_only(numbers) {
		return error('Invalid character(s) found in minor number "${parts[1]}"')
	}
	if has_leading_zeroes(parts[1]) {
		return error('Minor number must not contain leading zeroes "${parts[1]}"')
	}
	minor := strconv.parse_uint(parts[1], 10, 64)!

	mut v := Version{}
	v.major = major
	v.minor = minor

	mut build := []string{}
	mut prerelease := []string{}
	mut patch_str := parts[2]

	bi := patch_str.index_u8(`+`)
	if bi != -1 {
		build = patch_str[bi + 1..].split('.')
		patch_str = patch_str[..bi]
	}

	pi := patch_str.index_u8(`-`)
	if pi != -1 {
		prerelease = patch_str[pi + 1..].split('.')
		patch_str = patch_str[..pi]
	}

	if !patch_str.contains_only(numbers) {
		return error('Invalid character(s) found in patch number "${patch_str}"')
	}
	if has_leading_zeroes(patch_str) {
		return error('Patch number must not contain leading zeroes "${patch_str}"')
	}
	patch := strconv.parse_uint(patch_str, 10, 64)!

	v.patch = patch

	// Prerelease
	for prstr in prerelease {
		parsed_pr := new_pr_version(prstr)!
		v.pre << parsed_pr
	}

	// Build meta data
	for str in build {
		if str.len == 0 {
			return error('Build meta data is empty')
		}
		if !str.contains_only(alphanum) {
			return error('Invalid character(s) found in build meta data "${str}"')
		}
		v.build << str
	}

	return v
}

// must_parse is like parse but panics if the version cannot be parsed.
pub fn must_parse(s string) Version {
	v := parse(s) or { panic('semver: Parse(${s}): ${err}') }
	return v
}

// new_pr_version creates a new valid prerelease version.
pub fn new_pr_version(s string) !PRVersion {
	if s == '' {
		return error('Prerelease is empty')
	}
	mut v := PRVersion{}
	if s.contains_only(numbers) {
		if has_leading_zeroes(s) {
			return error('Numeric PreRelease version must not contain leading zeroes "${s}"')
		}
		v.version_num = strconv.parse_uint(s, 10, 64)!
		v.is_num = true
	} else if s.contains_only(alphanum) {
		v.version_str = s
		v.is_num = false
	} else {
		return error('Invalid character(s) found in prerelease "${s}"')
	}
	return v
}

// is_numeric checks if prerelease-version is numeric.
pub fn (v PRVersion) is_numeric() bool {
	return v.is_num
}

// compare compares two PreRelease Versions v and o:
// -1 == v is less than o
// 0 == v is equal to o
// 1 == v is greater than o
pub fn (v PRVersion) compare(o PRVersion) int {
	if v.is_num && !o.is_num {
		return -1
	} else if !v.is_num && o.is_num {
		return 1
	} else if v.is_num && o.is_num {
		if v.version_num == o.version_num {
			return 0
		} else if v.version_num > o.version_num {
			return 1
		} else {
			return -1
		}
	} else {
		// both are Alphas
		if v.version_str == o.version_str {
			return 0
		} else if v.version_str > o.version_str {
			return 1
		} else {
			return -1
		}
	}
}

// str returns the prerelease version string.
pub fn (v PRVersion) str() string {
	if v.is_num {
		return strconv.format_uint(v.version_num, 10)
	}
	return v.version_str
}

fn has_leading_zeroes(s string) bool {
	return s.len > 1 && s[0] == `0`
}

// new_build_version creates a new valid build version.
pub fn new_build_version(s string) !string {
	if s == '' {
		return error('Buildversion is empty')
	}
	if !s.contains_only(alphanum) {
		return error('Invalid character(s) found in build meta data "${s}"')
	}
	return s
}

// finalize_version_str returns the major, minor and patch number only and
// discards prerelease and build number.
pub fn finalize_version_str(s string) !string {
	mut v := parse(s)!
	v.pre = []
	v.build = []
	return v.str()
}

module semver

import strconv

enum WildcardType {
	none_wildcard  = 0
	major_wildcard = 1
	minor_wildcard = 2
	patch_wildcard = 3
}

fn wildcard_type_from_int(i int) WildcardType {
	return match i {
		1 { .major_wildcard }
		2 { .minor_wildcard }
		3 { .patch_wildcard }
		else { .none_wildcard }
	}
}

// comparator is a function comparing two versions. (The type alias itself
// lives in semver.v, next to Version, so vfmt can resolve the parameter type.)
fn comp_eq(v1 Version, v2 Version) bool {
	return v1.compare(v2) == 0
}

fn comp_ne(v1 Version, v2 Version) bool {
	return v1.compare(v2) != 0
}

fn comp_gt(v1 Version, v2 Version) bool {
	return v1.compare(v2) == 1
}

fn comp_ge(v1 Version, v2 Version) bool {
	return v1.compare(v2) >= 0
}

fn comp_lt(v1 Version, v2 Version) bool {
	return v1.compare(v2) == -1
}

fn comp_le(v1 Version, v2 Version) bool {
	return v1.compare(v2) <= 0
}

struct VersionRange {
	v Version
	c Comparator = fn (_ Version, _ Version) bool {
		return false
	}
}

// range_func creates a Range from the given VersionRange.
fn (vr VersionRange) range_func() Range {
	return Range(fn [vr] (v Version) bool {
		return vr.c(v, vr.v)
	})
}

// Range represents a range of versions. (The type alias itself lives in
// semver.v, next to Version, so vfmt/vet can resolve the parameter type.)
// A Range can be used to check if a Version satisfies it.

// or_ combines the existing Range with another Range using logical OR.
pub fn (rf Range) or_(f Range) Range {
	return Range(fn [rf, f] (v Version) bool {
		return rf(v) || f(v)
	})
}

// and_ combines the existing Range with another Range using logical AND.
pub fn (rf Range) and_(f Range) Range {
	return Range(fn [rf, f] (v Version) bool {
		return rf(v) && f(v)
	})
}

// parse_range parses a range and returns a Range.
// If the range could not be parsed an error is returned.
pub fn parse_range(s string) !Range {
	parts := split_and_trim(s)
	or_parts := split_or_parts(parts)!
	expanded_parts := expand_wildcard_version(or_parts)!

	mut or_fn := Range(fn (_ Version) bool {
		return false
	})
	mut have_or := false

	for p in expanded_parts {
		mut and_fn := Range(fn (_ Version) bool {
			return false
		})
		mut have_and := false
		for ap in p {
			sp := split_comparator_version(ap)!
			vr := build_version_range(sp.op, sp.v)!
			rf := vr.range_func()

			// Set function
			if !have_and {
				and_fn = rf
				have_and = true
			} else {
				// Combine with existing function
				and_fn = and_fn.and_(rf)
			}
		}
		if !have_or {
			or_fn = and_fn
			have_or = true
		} else {
			or_fn = or_fn.or_(and_fn)
		}
	}
	return or_fn
}

// split_or_parts splits the already cleaned parts by '||'.
// Checks for invalid positions of the operator and returns an error if found.
fn split_or_parts(parts []string) ![][]string {
	mut or_parts := [][]string{}
	mut last := 0
	for i, p in parts {
		if p == '||' {
			if i == 0 {
				return error("First element in range is '||'")
			}
			or_parts << parts[last..i]
			last = i + 1
		}
	}
	if last == parts.len {
		return error("Last element in range is '||'")
	}
	or_parts << parts[last..]
	return or_parts
}

// build_version_range takes an operator and version and builds a VersionRange,
// otherwise an error.
fn build_version_range(op_str string, v_str string) !VersionRange {
	c := parse_comparator(op_str) or {
		return error('Could not parse comparator "${op_str}" in "${op_str}${v_str}"')
	}
	v := parse(v_str) or {
		return error('Could not parse version "${v_str}" in "${op_str}${v_str}": ${err}')
	}

	return VersionRange{
		v: v
		c: c
	}
}

// in_array checks if a byte is contained in an array of bytes.
fn in_array(s u8, list []u8) bool {
	for el in list {
		if el == s {
			return true
		}
	}
	return false
}

// split_and_trim splits a range string by spaces and cleans whitespaces.
fn split_and_trim(s string) []string {
	mut result := []string{}
	mut last := 0
	mut last_char := u8(0)
	exclude_from_split := [u8(`>`), u8(`<`), u8(`=`)]
	for i := 0; i < s.len; i++ {
		if s[i] == ` ` && !in_array(last_char, exclude_from_split) {
			if last < i - 1 {
				result << s[last..i]
			}
			last = i + 1
		} else if s[i] != ` ` {
			last_char = s[i]
		}
	}
	if last < s.len - 1 {
		result << s[last..]
	}

	for i := 0; i < result.len; i++ {
		result[i] = result[i].replace(' ', '')
	}

	return result
}

// split_parts holds the operator and version parts of a comparator+version
// string (e.g. `>=1.2.3` -> op `>=`, v `1.2.3`).
struct SplitParts {
	op string
	v  string
}

// split_comparator_version splits the comparator from the version.
// Input must be free of leading or trailing spaces.
fn split_comparator_version(s string) !SplitParts {
	i := s.index_any('0123456789')
	if i == -1 {
		return error('Could not get version from string: "${s}"')
	}
	return SplitParts{
		op: s[..i].trim_space()
		v:  s[i..]
	}
}

// get_wildcard_type will return the type of wildcard that the passed version
// contains.
fn get_wildcard_type(v_str string) WildcardType {
	parts := v_str.split('.')
	nparts := parts.len
	wildcard := parts[nparts - 1]

	possible_wildcard_type := wildcard_type_from_int(nparts)
	if wildcard == 'x' {
		return possible_wildcard_type
	}

	return .none_wildcard
}

// create_version_from_wildcard will convert a wildcard version into a regular
// version, replacing 'x's with '0's, handling special cases like '1.x.x' and
// '1.x'.
fn create_version_from_wildcard(v_str string) string {
	mut v_str2 := v_str.replace_once('.x.x', '.x')
	v_str2 = v_str2.replace_once('.x', '.0')
	parts := v_str2.split('.')

	// handle 1.x
	if parts.len == 2 {
		return v_str2 + '.0'
	}

	return v_str2
}

// increment_major_version_str increments the major version of the passed
// version string.
fn increment_major_version_str(v_str string) !string {
	mut parts := v_str.split('.')
	i := strconv.parse_int(parts[0], 10, 64) or { return error('invalid number') }
	parts[0] = (i + 1).str()
	return parts.join('.')
}

// increment_minor_version_str increments the minor version of the passed
// version string.
fn increment_minor_version_str(v_str string) !string {
	mut parts := v_str.split('.')
	i := strconv.parse_int(parts[1], 10, 64) or { return error('invalid number') }
	parts[1] = (i + 1).str()
	return parts.join('.')
}

// expand_wildcard_version expands wildcards inside versions.
fn expand_wildcard_version(parts [][]string) ![][]string {
	mut expanded_parts := [][]string{}
	for p in parts {
		mut new_parts := []string{}
		for ap0 in p {
			mut ap := ap0
			if ap.contains('x') {
				sp := split_comparator_version(ap)!
				op_str := sp.op
				v_str := sp.v
				version_wildcard_type := get_wildcard_type(v_str)
				flat_version := create_version_from_wildcard(v_str)

				mut result_operator := ''
				mut should_increment_version := false
				match op_str {
					'>' {
						result_operator = '>='
						should_increment_version = true
					}
					'>=' {
						result_operator = '>='
					}
					'<' {
						result_operator = '<'
					}
					'<=' {
						result_operator = '<'
						should_increment_version = true
					}
					'', '=', '==' {
						new_parts << '>=' + flat_version
						result_operator = '<'
						should_increment_version = true
					}
					'!=', '!' {
						new_parts << '<' + flat_version
						result_operator = '>='
						should_increment_version = true
					}
					else {}
				}

				mut result_version := ''
				if should_increment_version {
					match version_wildcard_type {
						.patch_wildcard {
							result_version = increment_minor_version_str(flat_version) or { '' }
						}
						.minor_wildcard {
							result_version = increment_major_version_str(flat_version) or { '' }
						}
						else {}
					}
				} else {
					result_version = flat_version
				}

				ap = result_operator + result_version
			}
			new_parts << ap
		}
		expanded_parts << new_parts
	}
	return expanded_parts
}

fn parse_comparator(s string) ?Comparator {
	match s {
		'==', '', '=' { return comp_eq }
		'>' { return comp_gt }
		'>=' { return comp_ge }
		'<' { return comp_lt }
		'<=' { return comp_le }
		'!', '!=' { return comp_ne }
		else { return none }
	}
}

// must_parse_range is like parse_range but panics if the range cannot be parsed.
pub fn must_parse_range(s string) Range {
	r := parse_range(s) or { panic('semver: ParseRange(${s}): ${err}') }
	return r
}

module semver

// In Go, Version implements encoding/json.Marshaler and Unmarshaler so that it
// is represented as a JSON string (e.g. `"1.2.3-alpha+build"`). V's JSON
// story differs between builds (the `json2` module is experimental and lives
// under `x/json2` here), so these helpers implement the identical behaviour
// directly: a Version marshals to its double-quoted version string and
// unmarshals by parsing the string contents.

// marshal_json returns the JSON string representation of v (with surrounding
// double quotes), mirroring Go's `json.Marshal(version)`.
pub fn (v Version) marshal_json() string {
	return '"' + v.str() + '"'
}

// unmarshal_json parses a JSON-encoded version string (a double-quoted string)
// into a Version, mirroring Go's `json.Unmarshal(data, &version)`.
pub fn unmarshal_json(data string) !Version {
	s := data.trim_space()
	if s.len < 2 || s[0] != `"` || s[s.len - 1] != `"` {
		return error('json: cannot unmarshal non-string into semver.Version')
	}
	inner := s[1..s.len - 1]
	return parse(inner)!
}

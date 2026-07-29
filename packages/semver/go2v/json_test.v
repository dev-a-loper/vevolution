module semver

fn test_json_marshal() {
	version_string := '3.1.4-alpha.1.5.9+build.2.6.5'
	v := parse(version_string)!

	version_json := v.marshal_json()
	quoted_version_string := '"' + version_string + '"'

	assert version_json == quoted_version_string, 'JSON marshaled semantic version not equal: expected "${quoted_version_string}", got "${version_json}"'
}

fn test_json_unmarshal() {
	version_string := '3.1.4-alpha.1.5.9+build.2.6.5'
	quoted_version_string := '"' + version_string + '"'

	v := unmarshal_json(quoted_version_string)!
	assert v.str() == version_string, 'JSON unmarshaled semantic version not equal: expected "${version_string}", got "${v.str()}"'

	// Bad version string (too many components) must error.
	bad_version_string := '"3.1.4.1.5.9.2.6.5-other-digits-of-pi"'
	if _ := unmarshal_json(bad_version_string) {
		assert false, 'expected JSON unmarshal error, got none'
	}

	// A bare JSON number (not a string) must error.
	if _ := unmarshal_json('3.1') {
		assert false, 'expected JSON unmarshal error, got none'
	}
}

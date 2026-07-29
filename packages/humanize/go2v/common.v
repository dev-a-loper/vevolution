module humanize

// Test_case and validate_list are shared helpers used by the package's _test.v
// files. V compiles each _test.v file independently (alongside the module's
// regular .v files, but NOT the other _test.v files), so cross-file test
// helpers cannot live in a _test.v file. They are kept here as internal
// (non-public) symbols; they mirror the unexported `testList`/`validate` helper
// in the Go original's common_test.go.
struct Test_case {
	name string
	got  string
	exp  string
}

fn validate_list(cases []Test_case) {
	for tc in cases {
		assert tc.got == tc.exp, 'On ${tc.name}, expected "${tc.exp}", but got "${tc.got}"'
	}
}

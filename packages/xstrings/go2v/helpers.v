// Shared helpers used by the _test.v files (kept in a non-test file so that
// each _test.v, which V compiles separately, can see them).
module xstrings

// separator mirrors Go's util_test.go separator constant.
const separator = ' ¶ '

// sep joins several strings with the separator.
fn sep(strs ...string) string {
	return strs.join(separator)
}

// split splits a string by the separator.
fn split_helper(str string) []string {
	return str.split(separator)
}

// run_test_cases runs converter against each case and asserts equality.
fn run_test_cases(converter fn (string) string, cases map[string]string) {
	for k, v in cases {
		s := converter(k)
		assert s == v, 'case fails. [case: ${k}]\nshould => ${v}\nactual => ${s}'
	}
}

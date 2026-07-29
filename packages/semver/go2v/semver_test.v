module semver

import os
import rand

// assert_main_panics compiles a tiny `module main` program (against a temporary
// copy of this module) that runs `probe_body`, then asserts it panicked.
//
// V has no equivalent of Go's `recover`, and a `panic()` aborts the whole test
// process, so panic behaviour is verified the same way V's own test suite does
// it (see vlib/v/tests/division_by_zero_runtime_test.v): build a throwaway
// program, run it, and check the output. Defined per test-file because V
// compiles each `*_test.v` independently. The temp dir is randomized so the
// test is safe under `v test`'s parallel per-file execution.
fn assert_main_panics(probe_body string) ! {
	vexe := @VEXE
	tmp := os.join_path(os.vtmp_dir(), 'semver_panic_probe_${rand.intn(1_000_000) or { 0 }}')
	os.rmdir_all(tmp) or {}
	os.mkdir_all(tmp)!
	defer {
		os.rmdir_all(tmp) or {}
	}

	mod_src_dir := os.join_path(tmp, 'semver')
	os.mkdir_all(mod_src_dir)!

	// Copy this module's non-test .v sources into <tmp>/semver/.
	mod_dir := os.dir(@FILE)
	files := os.ls(mod_dir)!
	for f in files {
		if f.ends_with('.v') && !f.ends_with('_test.v') {
			os.cp(os.join_path(mod_dir, f), os.join_path(mod_src_dir, f))!
		}
	}

	os.write_file(os.join_path(tmp, 'v.mod'),
		"Module {\n\tname: 'probeproj'\n\tversion: '0.0.0'\n}\n")!
	main_src := 'module main\n\nimport semver\n\nfn main() {\n\t${probe_body}\n}\n'
	os.write_file(os.join_path(tmp, 'main.v'), main_src)!

	exe := os.join_path(tmp, 'probe_exe')
	comp := os.execute('${os.quoted_path(vexe)} -o ${os.quoted_path(exe)} ${os.quoted_path(tmp)}')
	assert comp.exit_code == 0, 'probe compilation failed: ${comp.output}'

	res := os.execute(os.quoted_path(exe))
	assert res.exit_code != 0, 'expected a panic, but the probe exited cleanly'
	assert res.output.contains('V panic'), 'expected a V panic in output, got: ${res.output}'
}

fn prstr(s string) PRVersion {
	return PRVersion{
		version_str: s
	}
}

fn prnum(i u64) PRVersion {
	return PRVersion{
		version_num: i
		is_num:      true
	}
}

struct FormatTest {
	v      Version
	result string
}

fn format_tests() []FormatTest {
	return [
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
			}
			result: '1.2.3'
		},
		FormatTest{
			v:      Version{
				major: 0
				minor: 0
				patch: 1
			}
			result: '0.0.1'
		},
		FormatTest{
			v:      Version{
				major: 0
				minor: 0
				patch: 1
				pre:   [prstr('alpha'), prstr('preview')]
				build: ['123', '456']
			}
			result: '0.0.1-alpha.preview+123.456'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				pre:   [prstr('alpha'), prnum(1)]
				build: ['123', '456']
			}
			result: '1.2.3-alpha.1+123.456'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				pre:   [prstr('alpha'), prnum(1)]
			}
			result: '1.2.3-alpha.1'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				build: ['123', '456']
			}
			result: '1.2.3+123.456'
		},
		// Prereleases and build metadata hyphens
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				pre:   [prstr('alpha'), prstr('b-eta')]
				build: ['123', 'b-uild']
			}
			result: '1.2.3-alpha.b-eta+123.b-uild'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				build: ['123', 'b-uild']
			}
			result: '1.2.3+123.b-uild'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				pre:   [prstr('alpha'), prstr('b-eta')]
			}
			result: '1.2.3-alpha.b-eta'
		},
	]
}

fn tolerant_format_tests() []FormatTest {
	return [
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
			}
			result: 'v1.2.3'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 0
				pre:   [prstr('alpha')]
			}
			result: '1.2.0-alpha'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 0
			}
			result: '1.2.00'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
			}
			result: '\t1.2.3 '
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
			}
			result: '01.02.03'
		},
		FormatTest{
			v:      Version{
				major: 0
				minor: 0
				patch: 3
			}
			result: '00.0.03'
		},
		FormatTest{
			v:      Version{
				major: 0
				minor: 0
				patch: 3
			}
			result: '000.0.03'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 0
			}
			result: '1.2'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 0
				patch: 0
			}
			result: '1'
		},
	]
}

fn test_stringer() {
	for test in format_tests() {
		res := test.v.str()
		assert res == test.result, 'Stringer, expected "${test.result}" but got "${res}"'
	}
}

fn test_parse() {
	for test in format_tests() {
		v := parse(test.result) or {
			assert false, 'Error parsing "${test.result}": ${err}'
			continue
		}
		comp := v.compare(test.v)
		assert comp == 0, 'Parsing, expected "${test.v}" but got "${v}", comp: ${comp}'
		v.validate() or {
			assert false, 'Error validating parsed version "${test.v}": ${err}'
			continue
		}
	}
}

fn test_parse_tolerant() {
	for test in tolerant_format_tests() {
		v := parse_tolerant(test.result) or {
			assert false, 'Error parsing "${test.result}": ${err}'
			continue
		}
		comp := v.compare(test.v)
		assert comp == 0, 'Parsing, expected "${test.v}" but got "${v}", comp: ${comp}'
		v.validate() or {
			assert false, 'Error validating parsed version "${test.v}": ${err}'
			continue
		}
	}
}

fn test_must_parse() {
	_ = must_parse('32.2.1-alpha')
}

// V has no recover(); must_parse panics (aborts the process), so the panic is
// verified by compiling and running a tiny probe program in a subprocess, the
// same technique used by V's own test suite (see vlib/v/tests).
fn test_must_parse_panic() {
	assert_main_panics('semver.must_parse("invalid version")')!
}

fn test_validate() {
	for test in format_tests() {
		test.v.validate() or {
			assert false, 'Error validating "${test.v}": ${err}'
			continue
		}
	}
}

fn finalize_version_method_tests() []FormatTest {
	return [
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
			}
			result: '1.2.3'
		},
		FormatTest{
			v:      Version{
				major: 0
				minor: 0
				patch: 1
			}
			result: '0.0.1'
		},
		FormatTest{
			v:      Version{
				major: 0
				minor: 0
				patch: 1
				pre:   [prstr('alpha'), prstr('preview')]
				build: ['123', '456']
			}
			result: '0.0.1'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				pre:   [prstr('alpha'), prnum(1)]
				build: ['123', '456']
			}
			result: '1.2.3'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				pre:   [prstr('alpha'), prnum(1)]
			}
			result: '1.2.3'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				build: ['123', '456']
			}
			result: '1.2.3'
		},
		// Prereleases and build metadata hyphens
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				pre:   [prstr('alpha'), prstr('b-eta')]
				build: ['123', 'b-uild']
			}
			result: '1.2.3'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				build: ['123', 'b-uild']
			}
			result: '1.2.3'
		},
		FormatTest{
			v:      Version{
				major: 1
				minor: 2
				patch: 3
				pre:   [prstr('alpha'), prstr('b-eta')]
			}
			result: '1.2.3'
		},
	]
}

fn test_finalize_version_method() {
	for test in finalize_version_method_tests() {
		out := test.v.finalize_version()
		assert out == test.result, 'Finalized version error, expected "${test.result}" but got "${out}"'
	}
}

struct CompareTest {
	v1     Version
	v2     Version
	result int
}

fn compare_tests() []CompareTest {
	return [
		CompareTest{
			v1:     Version{
				major: 1
			}
			v2:     Version{
				major: 1
			}
			result: 0
		},
		CompareTest{
			v1:     Version{
				major: 2
			}
			v2:     Version{
				major: 1
			}
			result: 1
		},
		CompareTest{
			v1:     Version{
				major: 0
				minor: 1
			}
			v2:     Version{
				major: 0
				minor: 1
			}
			result: 0
		},
		CompareTest{
			v1:     Version{
				major: 0
				minor: 2
			}
			v2:     Version{
				major: 0
				minor: 1
			}
			result: 1
		},
		CompareTest{
			v1:     Version{
				major: 0
				minor: 0
				patch: 1
			}
			v2:     Version{
				major: 0
				minor: 0
				patch: 1
			}
			result: 0
		},
		CompareTest{
			v1:     Version{
				major: 0
				minor: 0
				patch: 2
			}
			v2:     Version{
				major: 0
				minor: 0
				patch: 1
			}
			result: 1
		},
		CompareTest{
			v1:     Version{
				major: 1
				minor: 2
				patch: 3
			}
			v2:     Version{
				major: 1
				minor: 2
				patch: 3
			}
			result: 0
		},
		CompareTest{
			v1:     Version{
				major: 2
				minor: 2
				patch: 4
			}
			v2:     Version{
				major: 1
				minor: 2
				patch: 4
			}
			result: 1
		},
		CompareTest{
			v1:     Version{
				major: 1
				minor: 3
				patch: 3
			}
			v2:     Version{
				major: 1
				minor: 2
				patch: 3
			}
			result: 1
		},
		CompareTest{
			v1:     Version{
				major: 1
				minor: 2
				patch: 4
			}
			v2:     Version{
				major: 1
				minor: 2
				patch: 3
			}
			result: 1
		},
		// Spec Examples #11
		CompareTest{
			v1:     Version{
				major: 1
			}
			v2:     Version{
				major: 2
			}
			result: -1
		},
		CompareTest{
			v1:     Version{
				major: 2
			}
			v2:     Version{
				major: 2
				minor: 1
			}
			result: -1
		},
		CompareTest{
			v1:     Version{
				major: 2
				minor: 1
			}
			v2:     Version{
				major: 2
				minor: 1
				patch: 1
			}
			result: -1
		},
		// Spec Examples #9
		CompareTest{
			v1:     Version{
				major: 1
			}
			v2:     Version{
				major: 1
				pre:   [prstr('alpha')]
			}
			result: 1
		},
		CompareTest{
			v1:     Version{
				major: 1
				pre:   [prstr('alpha')]
			}
			v2:     Version{
				major: 1
				pre:   [prstr('alpha'), prnum(1)]
			}
			result: -1
		},
		CompareTest{
			v1:     Version{
				major: 1
				pre:   [prstr('alpha'), prnum(1)]
			}
			v2:     Version{
				major: 1
				pre:   [prstr('alpha'), prstr('beta')]
			}
			result: -1
		},
		CompareTest{
			v1:     Version{
				major: 1
				pre:   [prstr('alpha'), prstr('beta')]
			}
			v2:     Version{
				major: 1
				pre:   [prstr('beta')]
			}
			result: -1
		},
		CompareTest{
			v1:     Version{
				major: 1
				pre:   [prstr('beta')]
			}
			v2:     Version{
				major: 1
				pre:   [prstr('beta'), prnum(2)]
			}
			result: -1
		},
		CompareTest{
			v1:     Version{
				major: 1
				pre:   [prstr('beta'), prnum(2)]
			}
			v2:     Version{
				major: 1
				pre:   [prstr('beta'), prnum(11)]
			}
			result: -1
		},
		CompareTest{
			v1:     Version{
				major: 1
				pre:   [prstr('beta'), prnum(11)]
			}
			v2:     Version{
				major: 1
				pre:   [prstr('rc'), prnum(1)]
			}
			result: -1
		},
		CompareTest{
			v1:     Version{
				major: 1
				pre:   [prstr('rc'), prnum(1)]
			}
			v2:     Version{
				major: 1
			}
			result: -1
		},
		// Ignore Build metadata
		CompareTest{
			v1:     Version{
				major: 1
				build: ['1', '2', '3']
			}
			v2:     Version{
				major: 1
			}
			result: 0
		},
	]
}

fn test_compare() {
	for test in compare_tests() {
		res := test.v1.compare(test.v2)
		assert res == test.result, 'Comparing "${test.v1}" : "${test.v2}", expected ${test.result} but got ${res}'
		// Test counterpart
		res2 := test.v2.compare(test.v1)
		assert res2 == -test.result, 'Comparing "${test.v2}" : "${test.v1}", expected ${-test.result} but got ${res2}'
	}
}

struct WrongFormatTest {
	v   Version
	str string
}

// wrong_format_parse_strs are the inputs whose Parse must fail and which carry
// no separately-constructed Version to Validate.
fn wrong_format_parse_strs() []string {
	return [
		'',
		'.',
		'1.',
		'.1',
		'a.b.c',
		'1.a.b',
		'1.1.a',
		'1.a.1',
		'a.1.1',
		'..',
		'1..',
		'1.1.',
		'1..1',
		'1.1.+123',
		'1.1.-beta',
		'-1.1.1',
		'1.-1.1',
		'1.1.-1',
		// giant numbers
		'20000000000000000000.1.1',
		'1.20000000000000000000.1',
		'1.1.20000000000000000000',
		'1.1.1-20000000000000000000',
		// Leading zeroes
		'01.1.1',
		'001.1.1',
		'1.01.1',
		'1.001.1',
		'1.1.01',
		'1.1.001',
		'1.1.1-01',
		'1.1.1-001',
		'1.1.1-beta.01',
		'1.1.1-beta.001',
	]
}

// wrong_format_validate_cases carry a hand-built Version (mirroring Go's
// non-nil `*Version`) that must itself fail Validate; their string form must
// also fail Parse.
fn wrong_format_validate_cases() []WrongFormatTest {
	return [
		WrongFormatTest{
			v:   Version{
				major: 0
				minor: 0
				patch: 0
				pre:   [prstr('!')]
			}
			str: '0.0.0-!'
		},
		WrongFormatTest{
			v:   Version{
				major: 0
				minor: 0
				patch: 0
				build: ['!']
			}
			str: '0.0.0+!'
		},
		// empty prversion
		WrongFormatTest{
			v:   Version{
				major: 0
				minor: 0
				patch: 0
				pre:   [prstr(''), prstr('alpha')]
			}
			str: '0.0.0-.alpha'
		},
		// empty build meta data
		WrongFormatTest{
			v:   Version{
				major: 0
				minor: 0
				patch: 0
				pre:   [prstr('alpha')]
				build: ['']
			}
			str: '0.0.0-alpha+'
		},
		WrongFormatTest{
			v:   Version{
				major: 0
				minor: 0
				patch: 0
				pre:   [prstr('alpha')]
				build: ['test', '']
			}
			str: '0.0.0-alpha+test.'
		},
	]
}

fn test_wrong_format() {
	for str in wrong_format_parse_strs() {
		if _ := parse(str) {
			assert false, 'Parsing wrong format version "${str}", expected error but got a value'
		}
	}
	for test in wrong_format_validate_cases() {
		if _ := parse(test.str) {
			assert false, 'Parsing wrong format version "${test.str}", expected error but got a value'
		}
		if _ := test.v.validate() {
			assert false, 'Validating wrong format version "${test.v}" ("${test.str}"), expected error'
		}
	}
}

fn test_wrong_tolerant_format() {
	for str in ['1.0+abc', '1.0-rc.1'] {
		if _ := parse_tolerant(str) {
			assert false, 'Parsing wrong format version "${str}", expected error but got a value'
		}
	}
}

fn test_compare_helper() {
	v := Version{
		major: 1
		pre:   [prstr('alpha')]
	}
	v1 := Version{
		major: 1
	}
	assert v.eq(v), '"${v}" should be equal to "${v}"'
	assert v.equals(v), '"${v}" should be equal to "${v}"'
	assert v1.ne(v), '"${v1}" should not be equal to "${v}"'
	assert v.gte(v), '"${v}" should be greater than or equal to "${v}"'
	assert v.lte(v), '"${v}" should be less than or equal to "${v}"'
	assert v.lt(v1), '"${v}" should be less than "${v1}"'
	assert v.lte(v1), '"${v}" should be less than or equal "${v1}"'
	assert v.le(v1), '"${v}" should be less than or equal "${v1}"'
	assert v1.gt(v), '"${v1}" should be greater than "${v}"'
	assert v1.gte(v), '"${v1}" should be greater than or equal "${v}"'
	assert v1.ge(v), '"${v1}" should be greater than or equal "${v}"'
}

const major_inc = 0
const minor_inc = 1
const patch_inc = 2

struct IncrementTest {
	version          Version
	increment_type   int
	expecting_error  bool
	expected_version Version
}

fn increment_tests() []IncrementTest {
	return [
		IncrementTest{
			version:          Version{
				major: 1
				minor: 2
				patch: 3
			}
			increment_type:   patch_inc
			expecting_error:  false
			expected_version: Version{
				major: 1
				minor: 2
				patch: 4
			}
		},
		IncrementTest{
			version:          Version{
				major: 1
				minor: 2
				patch: 3
			}
			increment_type:   minor_inc
			expecting_error:  false
			expected_version: Version{
				major: 1
				minor: 3
				patch: 0
			}
		},
		IncrementTest{
			version:          Version{
				major: 1
				minor: 2
				patch: 3
			}
			increment_type:   major_inc
			expecting_error:  false
			expected_version: Version{
				major: 2
				minor: 0
				patch: 0
			}
		},
		IncrementTest{
			version:          Version{
				major: 0
				minor: 1
				patch: 2
			}
			increment_type:   patch_inc
			expecting_error:  false
			expected_version: Version{
				major: 0
				minor: 1
				patch: 3
			}
		},
		IncrementTest{
			version:          Version{
				major: 0
				minor: 1
				patch: 2
			}
			increment_type:   minor_inc
			expecting_error:  false
			expected_version: Version{
				major: 0
				minor: 2
				patch: 0
			}
		},
		IncrementTest{
			version:          Version{
				major: 0
				minor: 1
				patch: 2
			}
			increment_type:   major_inc
			expecting_error:  false
			expected_version: Version{
				major: 1
				minor: 0
				patch: 0
			}
		},
	]
}

fn test_increments() {
	for test in increment_tests() {
		mut v := test.version
		original_version := Version{
			...v
		}
		match test.increment_type {
			patch_inc { v.increment_patch() }
			minor_inc { v.increment_minor() }
			major_inc { v.increment_major() }
			else {}
		}

		// In Go the increment methods return an error that is always nil; in V
		// they never error, so only the resulting version is asserted.
		assert v.ne(test.expected_version) == false, 'Increment version, expecting "${test.expected_version}", got "${v}"'
		_ = original_version
	}
}

fn test_pre_release_versions() {
	p1 := new_pr_version('123')!
	assert p1.is_numeric(), 'Expected numeric prversion, got "${p1}"'
	assert p1.version_num == 123, 'Wrong prversion number'
	p2 := new_pr_version('alpha')!
	assert p2.is_numeric() == false, 'Expected non-numeric prversion, got "${p2}"'
	assert p2.version_str == 'alpha', 'Wrong prversion string'
}

fn test_build_meta_data_versions() {
	new_build_version('123') or {
		assert false, 'Unexpected error ${err}'
		return
	}
	new_build_version('build') or {
		assert false, 'Unexpected error ${err}'
		return
	}
	if _ := new_build_version('test?') {
		assert false, 'Expected error, got none'
	}
	if _ := new_build_version('') {
		assert false, 'Expected error, got none'
	}
}

fn test_new_helper() {
	v := new('1.2.3')!
	assert v.compare(Version{ major: 1, minor: 2, patch: 3 }) == 0, 'Unexpected comparison problem'
}

fn test_make_helper() {
	v := make('1.2.3')!
	assert v.compare(Version{ major: 1, minor: 2, patch: 3 }) == 0, 'Unexpected comparison problem'
}

struct FinalizeTest {
	input  string
	output string
}

fn finalize_tests() []FinalizeTest {
	return [
		FinalizeTest{
			input:  ''
			output: ''
		},
		FinalizeTest{
			input:  '1.2.3'
			output: '1.2.3'
		},
		FinalizeTest{
			input:  '0.0.1'
			output: '0.0.1'
		},
		FinalizeTest{
			input:  '0.0.1-alpha.preview+123.456'
			output: '0.0.1'
		},
		FinalizeTest{
			input:  '1.2.3-alpha.1+123.456'
			output: '1.2.3'
		},
		FinalizeTest{
			input:  '1.2.3-alpha.1'
			output: '1.2.3'
		},
		FinalizeTest{
			input:  '1.2.3+123.456'
			output: '1.2.3'
		},
		FinalizeTest{
			input:  '1.2.3-alpha.b-eta+123.b-uild'
			output: '1.2.3'
		},
		FinalizeTest{
			input:  '1.2.3+123.b-uild'
			output: '1.2.3'
		},
		FinalizeTest{
			input:  '1.2.3-alpha.b-eta'
			output: '1.2.3'
		},
		FinalizeTest{
			input:  '1.2-alpha'
			output: ''
		},
	]
}

fn test_finalize_version() {
	for test in finalize_tests() {
		final_ver, has_err := finalize_version_str_with_err(test.input)
		if final_ver == '' {
			assert has_err, 'Finalize Version error, expected error but got none ("${test.input}")'
		} else {
			assert final_ver == test.output, 'Finalize Version error expected "${test.output}" but got "${final_ver}"'
		}
	}
}

// finalize_version_str_with_err wraps finalize_version_str to expose the
// (value, had_error) pair the Go test reasons about.
fn finalize_version_str_with_err(s string) (string, bool) {
	res := finalize_version_str(s) or { return '', true }
	return res, false
}

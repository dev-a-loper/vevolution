module semver

fn test_sort() {
	v100 := parse('1.0.0')!
	v010 := parse('0.1.0')!
	v001 := parse('0.0.1')!
	mut versions := [v010, v100, v001]
	sort(mut versions)

	correct := [v001, v010, v100]
	assert versions.len == correct.len, 'Sort returned wrong length: ${versions}'
	for i in 0 .. correct.len {
		assert versions[i].eq(correct[i]), 'Sort returned wrong order at ${i}: ${versions}'
	}
}

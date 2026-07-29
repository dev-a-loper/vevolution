// orderedmap_test — V port of github.com/elliotchance/orderedmap/v3's test suite.
// Mirrors the 15 Test functions (benchmarks are excluded; they are not pass/fail tests).
// Comma-ok `(v, ok)` becomes V option `?V`; Go subtests are flattened to asserts.
module orderedmap

fn test_new_ordered_map() {
	mut m := new_ordered_map[int, string]()
	assert m.len() == 0
}

fn test_get() {
	// ReturnsNotOKIfStringKeyDoesntExist
	mut m := new_ordered_map[string, string]()
	if _ := m.get('foo') {
		assert false, 'get should be none for missing string key'
	} else {
		assert true
	}

	// ReturnsNotOKIfNonStringKeyDoesntExist
	mut m2 := new_ordered_map[int, string]()
	if _ := m2.get(123) {
		assert false, 'get should be none for missing int key'
	} else {
		assert true
	}

	// ReturnsOKIfKeyExists
	mut m3 := new_ordered_map[string, string]()
	m3.set('foo', 'bar')
	v3 := m3.get('foo') or {
		assert false, 'get should succeed for existing key'
		''
	}
	assert v3 == 'bar'

	// ReturnsDynamicValueForKey
	mut m4 := new_ordered_map[string, string]()
	m4.set('foo', 'baz')
	v4 := m4.get('foo') or { '' }
	assert v4 == 'baz'

	// KeyDoesntExistOnNonEmptyMap
	if _ := m4.get('bar') {
		assert false
	} else {
		assert true
	}

	// ValueForKeyDoesntExistOnNonEmptyMap
	vv := m4.get('bar') or { '' }
	assert vv == ''
}

fn test_set() {
	mut m := new_ordered_map[string, string]()
	assert m.set('foo', 'bar') == true

	mut m2 := new_ordered_map[int, string]()
	assert m2.set(123, 'bar') == true

	mut m3 := new_ordered_map[int, bool]()
	assert m3.set(123, true) == true

	mut m4 := new_ordered_map[string, string]()
	m4.set('foo', 'bar')
	assert m4.set('foo', 'bar') == false

	mut m5 := new_ordered_map[string, string]()
	m5.set('foo', 'bar')
	m5.set('baz', 'qux')
	assert m5.set('quux', 'corge') == true
}

fn test_replace_key() {
	// ReturnsFalseIfOriginalKeyDoesntExist
	mut m := new_ordered_map[string, string]()
	assert m.replace_key('foo', 'bar') == false

	// ReturnsFalseIfNewKeyAlreadyExists
	mut m2 := new_ordered_map[string, string]()
	m2.set('foo', 'bar')
	m2.set('baz', 'qux')
	assert m2.replace_key('foo', 'baz') == false
	assert m2.keys() == ['foo', 'baz']

	// ReturnsTrueIfOnlyOriginalKeyExists
	mut m3 := new_ordered_map[string, string]()
	m3.set('foo', 'bar')
	assert m3.replace_key('foo', 'baz') == true
	el := m3.get_element('baz') or {
		assert false, 'baz element should exist'
		&Element[string, string]{}
	}
	assert el.value == 'bar'
	assert el.key == 'baz'
	v := m3.get('baz') or { '' }
	assert v == 'bar'
	assert m3.keys() == ['baz']
	assert m3.len() == 1
	if _ := m3.get('foo') {
		assert false, 'original key should be gone'
	} else {
		assert true
	}

	// KeyMaintainsOrderWhenReplaced
	count := 100
	mut m4 := new_ordered_map[int, int]()
	for i in 0 .. count {
		m4.set(i, i)
	}
	for i in 50 .. 60 {
		assert m4.replace_key(i, i + 100)
	}
	assert m4.len() == count
	k := m4.keys()
	for i, key in k {
		if i >= 50 && i < 60 {
			assert key == i + 100
		} else {
			assert key == i
		}
	}
}

fn test_len() {
	mut m := new_ordered_map[string, string]()
	assert m.len() == 0

	mut m2 := new_ordered_map[int, bool]()
	m2.set(123, true)
	assert m2.len() == 1

	mut m3 := new_ordered_map[int, bool]()
	m3.set(1, true)
	m3.set(2, true)
	m3.set(3, true)
	assert m3.len() == 3
}

fn test_keys() {
	mut m := new_ordered_map[int, bool]()
	assert m.keys().len == 0

	mut m2 := new_ordered_map[int, bool]()
	m2.set(1, true)
	assert m2.keys() == [1]

	mut m3 := new_ordered_map[int, bool]()
	for i in 1 .. 10 {
		m3.set(i, true)
	}
	assert m3.keys() == [1, 2, 3, 4, 5, 6, 7, 8, 9]

	mut m4 := new_ordered_map[string, bool]()
	m4.set('foo', true)
	m4.set('bar', true)
	m4.set('foo', false)
	assert m4.keys() == ['foo', 'bar']

	mut m5 := new_ordered_map[string, bool]()
	m5.set('foo', true)
	m5.set('bar', true)
	m5.delete('foo')
	assert m5.keys() == ['bar']
}

fn test_delete() {
	mut m := new_ordered_map[string, int]()
	assert m.delete('foo') == false

	mut m2 := new_ordered_map[string, int]()
	m2.set('foo', 0)
	assert m2.delete('foo') == true

	mut m3 := new_ordered_map[string, int]()
	m3.set('foo', 0)
	m3.delete('foo')
	if _ := m3.get('foo') {
		assert false, 'deleted key should not exist'
	} else {
		assert true
	}

	mut m4 := new_ordered_map[string, int]()
	m4.set('foo', 0)
	m4.set('bar', 0)
	m4.delete('foo')
	if _ := m4.get('bar') {
		assert true
	} else {
		assert false, 'other key should still exist'
	}
}

fn test_front() {
	mut m := new_ordered_map[int, bool]()
	if _ := m.front() {
		assert false, 'front should be none on empty map'
	} else {
		assert true
	}

	mut m2 := new_ordered_map[int, bool]()
	m2.set(1, true)
	if _ := m2.front() {
		assert true
	} else {
		assert false, 'front should exist on non-empty map'
	}
}

fn test_back() {
	mut m := new_ordered_map[int, bool]()
	if _ := m.back() {
		assert false, 'back should be none on empty map'
	} else {
		assert true
	}

	mut m2 := new_ordered_map[int, bool]()
	m2.set(1, true)
	if _ := m2.back() {
		assert true
	} else {
		assert false, 'back should exist on non-empty map'
	}
}

fn test_copy() {
	key := 1
	value := 'a value'
	mut m := new_ordered_map[int, string]()
	m.set(key, value)

	mut m2 := m.copy()
	m2.set(key, 'a different value')

	assert m.len() == m2.len()
	el := m.get_element(key) or {
		assert false
		&Element[int, string]{}
	}
	assert el.value == value
}

fn test_get_element() {
	mut m := new_ordered_map[string, string]()
	m.set('foo', 'bar')
	mut results := []string{}
	el := m.get_element('foo') or {
		assert false
		&Element[string, string]{}
	}
	results << el.key
	results << el.value
	assert results == ['foo', 'bar']

	mut m2 := new_ordered_map[string, string]()
	m2.set('foo', 'baz')
	if _ := m2.get_element('bar') {
		assert false, 'get_element should be none for missing key'
	} else {
		assert true
	}
}

fn test_set_and_get() {
	mut m := new_ordered_map[int, bool]()
	mut expected := map[int]bool{}
	expected[1] = true
	expected[3] = false
	expected[5] = false
	expected[4] = true
	for k, v in expected {
		m.set(k, v)
	}
	for k, v in expected {
		w := m.get(k) or {
			assert false, 'key should exist'
			false
		}
		assert v == w
	}
}

// Exp mirrors the Go test's local Element type for expected iteration order.
struct Exp {
	key   int
	value bool
}

fn test_iterations() {
	mut m := new_ordered_map[int, bool]()
	expected := [Exp{5, true}, Exp{3, false}, Exp{1, false}, Exp{4, true}]
	for v in expected {
		m.set(v.key, v.value)
	}
	elems := m.all_from_front()
	assert elems.len == expected.len
	for i, e in elems {
		assert expected[i].key == e.key
		assert expected[i].value == e.value
	}
}

fn test_iterators() {
	mut m := new_ordered_map[int, bool]()
	expected := [Exp{5, true}, Exp{3, false}, Exp{1, false}, Exp{4, true}]
	for v in expected {
		m.set(v.key, v.value)
	}

	// Forward iterator
	mut i := 0
	for p in m.all_from_front() {
		assert expected[i].key == p.key
		assert expected[i].value == p.value
		i++
	}

	// Reverse iterator
	mut j := expected.len - 1
	for p in m.all_from_back() {
		assert expected[j].key == p.key
		assert expected[j].value == p.value
		j--
	}
}

fn test_has() {
	mut m := new_ordered_map[string, string]()
	assert m.has('foo') == false

	mut m2 := new_ordered_map[string, string]()
	m2.set('foo', 'bar')
	assert m2.has('foo') == true

	mut m3 := new_ordered_map[string, string]()
	m3.set('foo', 'bar')
	m3.delete('foo')
	assert m3.has('foo') == false
}

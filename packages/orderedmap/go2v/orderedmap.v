// orderedmap — V port of github.com/elliotchance/orderedmap/v3.
// A generic map that preserves insertion order. Translated from the Go original
// (see ../go/v3) with go2v as scaffold, then hand-written to idiomatic V.
//
// Design note: the Go original backs the map with an intrusive doubly-linked list
// of pointers for O(1) ordered Front/Back/Delete. V discourages manual pointer
// graphs, so this port preserves insertion order with an `order []K` slice plus a
// `kv map[K]&Element[K,V]` map. Observable behaviour (insertion order, position
// retention on replace, ordered iteration) matches the original.
module orderedmap

// Element holds one key/value entry. Fields are public to mirror the Go API.
pub struct Element[K, V] {
pub mut:
	key   K
	value V
}

// OrderedMap is a map whose keys are iterated in insertion order.
pub struct OrderedMap[K, V] {
mut:
	kv    map[K]&Element[K, V]
	order []K
}

// new_ordered_map creates an empty ordered map.
pub fn new_ordered_map[K, V]() &OrderedMap[K, V] {
	return &OrderedMap[K, V]{}
}

// new_ordered_map_with_capacity creates an empty ordered map with room preallocated
// for `capacity` entries (the capacity hint is advisory; V maps grow as needed).
pub fn new_ordered_map_with_capacity[K, V](capacity int) &OrderedMap[K, V] {
	_ = capacity
	return &OrderedMap[K, V]{}
}

// new_ordered_map_with_elements creates an ordered map pre-filled with the given elements.
pub fn new_ordered_map_with_elements[K, V](els ...&Element[K, V]) &OrderedMap[K, V] {
	mut m := new_ordered_map[K, V]()
	for el in els {
		m.set(el.key, el.value)
	}
	return m
}

// len returns the number of entries.
pub fn (m &OrderedMap[K, V]) len() int {
	return m.kv.len
}

// get returns the value for `key`, or none if the key does not exist.
// (Go's comma-ok `Get(key) (V, bool)` maps to V's option `?V`.)
pub fn (m &OrderedMap[K, V]) get(key K) ?V {
	el := m.kv[key] or { return none }
	return el.value
}

// get_or_default returns the value for `key`, or `default_value` if absent.
pub fn (m &OrderedMap[K, V]) get_or_default(key K, default_value V) V {
	el := m.kv[key] or { return default_value }
	return el.value
}

// get_element returns the element for `key`, or none.
pub fn (m &OrderedMap[K, V]) get_element(key K) ?&Element[K, V] {
	el := m.kv[key] or { return none }
	return el
}

// has reports whether `key` exists.
pub fn (m &OrderedMap[K, V]) has(key K) bool {
	return key in m.kv
}

// set inserts or replaces the value for `key`. Returns true if the key was new,
// false if an existing value was replaced (even with the same value). A replaced
// key keeps its original position in the iteration order.
pub fn (mut m OrderedMap[K, V]) set(key K, value V) bool {
	if key in m.kv {
		mut el := m.kv[key] or { return false }
		el.value = value
		return false
	}
	el := &Element[K, V]{
		key:   key
		value: value
	}
	m.kv[key] = el
	m.order << key
	return true
}

// replace_key renames `original_key` to `new_key`, preserving position and value.
// Returns false if `original_key` is absent or `new_key` already exists.
pub fn (mut m OrderedMap[K, V]) replace_key(original_key K, new_key K) bool {
	if original_key !in m.kv {
		return false
	}
	if new_key in m.kv {
		return false
	}
	mut el := m.kv[original_key] or { return false }
	m.kv.delete(original_key)
	el.key = new_key
	m.kv[new_key] = el
	idx := m.order.index(original_key)
	if idx == -1 {
		return false
	}
	m.order[idx] = new_key
	return true
}

// delete removes `key`. Returns true if the key existed.
pub fn (mut m OrderedMap[K, V]) delete(key K) bool {
	if key !in m.kv {
		return false
	}
	m.kv.delete(key)
	// Remove from the order slice while preserving the position of the rest.
	m.order = m.order.filter(it != key)
	return true
}

// keys returns all keys in insertion order.
pub fn (m &OrderedMap[K, V]) keys() []K {
	return m.order.clone()
}

// front returns the first (oldest) element, or none if empty.
pub fn (m &OrderedMap[K, V]) front() ?&Element[K, V] {
	if m.order.len == 0 {
		return none
	}
	return m.kv[m.order[0]] or { none }
}

// back returns the last (most recent) element, or none if empty.
pub fn (m &OrderedMap[K, V]) back() ?&Element[K, V] {
	if m.order.len == 0 {
		return none
	}
	return m.kv[m.order[m.order.len - 1]] or { none }
}

// all_from_front returns every element, oldest first.
pub fn (m &OrderedMap[K, V]) all_from_front() []Element[K, V] {
	mut res := []Element[K, V]{cap: m.order.len}
	for k in m.order {
		el := m.kv[k] or { continue }
		res << Element[K, V]{
			key:   k
			value: el.value
		}
	}
	return res
}

// all_from_back returns every element, most recent first.
pub fn (m &OrderedMap[K, V]) all_from_back() []Element[K, V] {
	mut res := []Element[K, V]{cap: m.order.len}
	mut i := m.order.len - 1
	for i >= 0 {
		k := m.order[i]
		el := m.kv[k] or {
			i--
			continue
		}
		res << Element[K, V]{
			key:   k
			value: el.value
		}
		i--
	}
	return res
}

// copy returns a shallow copy of the map.
pub fn (m &OrderedMap[K, V]) copy() &OrderedMap[K, V] {
	mut m2 := new_ordered_map[K, V]()
	for k in m.order {
		el := m.kv[k] or { continue }
		m2.set(k, el.value)
	}
	return m2
}

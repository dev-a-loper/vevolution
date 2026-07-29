module semver

// sort sorts a slice of versions in-place (ascending).
pub fn sort(mut versions []Version) {
	versions.sort_with_compare(fn (a &Version, b &Version) int {
		return a.compare(*b)
	})
}

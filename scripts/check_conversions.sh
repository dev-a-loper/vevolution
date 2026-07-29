#!/usr/bin/env bash
# check_conversions.sh — run the go2v regression matrix.
#
# For every converted package (packages/*/go2v containing .v files), run `v test .`
# and report pass/fail. This is the tier-3 check for a "successful go2v upgrade"
# (see CLAUDE.md): after changing go2v, every package in the passing set must still
# pass.
#
# Usage: ./scripts/check_conversions.sh [--verbose]
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
verbose=0
[ "${1:-}" = "--verbose" ] && verbose=1

pass=0
fail=0
failed_pkgs=()
printf "%-14s %-10s %s\n" "PACKAGE" "RESULT" "DETAILS"
printf "%-14s %-10s %s\n" "-------" "------" "-------"
for d in "$root"/packages/*/go2v; do
	[ -d "$d" ] || continue
	# only consider dirs that actually have V test files
	ls "$d"/*_test.v >/dev/null 2>&1 || continue
	name="$(basename "$(dirname "$d")")"
	if out=$(cd "$d" && v test . 2>&1); then
		summary=$(echo "$out" | grep -iE 'Summary' | tail -1)
		printf "%-14s %-10s %s\n" "$name" "PASS" "${summary//[^[:print:]]/}"
		pass=$((pass + 1))
	else
		err=$(echo "$out" | grep -iE 'error|FAIL' | head -1)
		printf "%-14s %-10s %s\n" "$name" "FAIL" "${err//[^[:print:]]/}"
		fail=$((fail + 1))
		failed_pkgs+=("$name")
		[ "$verbose" = 1 ] && echo "$out" | sed 's/^/      /'
	fi
done

echo "------------------------------------------------"
echo "PASS=$pass FAIL=$fail"
if [ "$fail" -gt 0 ]; then
	echo "FAILED: ${failed_pkgs[*]}"
	exit 1
fi

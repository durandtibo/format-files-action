#!/usr/bin/env bash
# Test that `check-tools` reports found and missing tools, lists all of them, and exits with 127 when one is missing.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() {
	echo "FAIL: $1" >&2
	exit 1
}

# Fake tools on a PATH that also keeps the system commands needed by make.
mkdir -p "$work/bin"
for t in fake-a fake-b; do
	printf '#!/bin/sh\n' >"$work/bin/$t"
	if [ "$t" = fake-a ]; then printf 'echo "fake-a 1.2.3"\n' >>"$work/bin/$t"; fi
	chmod +x "$work/bin/$t"
done

cat >"$work/Makefile" <<MK
include $repo_root/tools.mk
MK
cd "$work"

# All tools available: success.
out="$(PATH="$work/bin:$PATH" make check-tools TOOLS="fake-a fake-b" 2>&1)" || fail "should succeed when all tools are available"
grep -Eq "✅ fake-a +1\.2\.3 +$work/bin/fake-a" <<<"$out" || fail "fake-a should be reported with its version and path"
grep -Eq "✅ fake-b +\? +$work/bin/fake-b" <<<"$out" || fail "a tool without version output should be reported with ?"
grep -q "All the 2 tools are available" <<<"$out" || fail "missing success summary"

# One tool missing: all tools are still listed and make fails with 127.
rc=0
out="$(PATH="$work/bin:$PATH" make check-tools TOOLS="fake-a missing-tool fake-b" 2>&1)" || rc=$?
[ "$rc" -ne 0 ] || fail "should fail when a tool is missing"
grep -q "Error 127" <<<"$out" || fail "should exit with code 127"
grep -Eq "❌ missing-tool +not found" <<<"$out" || fail "missing tool should be reported"
grep -q "✅ fake-b" <<<"$out" || fail "tools after a missing one should still be listed"
grep -q "Missing: missing-tool" <<<"$out" || fail "missing summary should name the tool"

# The default TOOLS covers the tools used by the repo.
out="$(make -n check-tools)"
for t in actionlint bats checkmake gh markdownlint mbake prettier shellcheck shfmt taplo yamllint zizmor; do
	grep -qw "$t" <<<"$out" || fail "default TOOLS should include $t"
done
echo "PASS"

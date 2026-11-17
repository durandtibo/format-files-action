#!/usr/bin/env bash
# Check that the files shipped to the consumers of the action (git archive, which applies the
# export-ignore rules of .gitattributes) are exactly the files the action needs at runtime.
# `uses: ./` runs the whole checkout, so a file marked export-ignore by mistake would pass the
# tests and break the release. When the action starts using a new file, add it to EXPECTED_FILES
# here and un-ignore it in .gitattributes.
#
# The files of .make/ are not listed: that directory is synced from a shared repository
# (bot-sync-shared-makefile.yaml), so every tracked file under it is expected.
set -euo pipefail

EXPECTED_FILES="LICENSE
Makefile
action.yml"

if ! expected=$({
	printf '%s\n' "$EXPECTED_FILES"
	printf '%s\n' ".make/"
	git ls-files -- .make
} | LC_ALL=C sort); then
	echo "::error::Could not list the expected files (is this a git checkout?)"
	exit 1
fi

if ! actual=$(git archive --worktree-attributes HEAD | tar t | LC_ALL=C sort); then
	echo "::error::Could not list the exported files with git archive"
	exit 1
fi

if [ "$actual" != "$expected" ]; then
	echo "::error::The exported files differ from the files the action needs (see dev/check_export.sh)"
	diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
	exit 1
fi
echo "✅ The exported files are the expected ones:"
printf '%s\n' "$actual"

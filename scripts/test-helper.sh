#!/usr/bin/env bash
# Shared helpers for the test workflows.

print_success() {
  echo "✅ $1"
}

print_error() {
  echo "❌ $1" >&2
}

# assert_files_equal <actual> <expected>
assert_files_equal() {
  local actual="$1"
  local expected="$2"

  if ! diff -u "$expected" "$actual"; then
    print_error "File '$actual' does not match expected content '$expected'"
    exit 1
  fi

  print_success "'$actual' matches expected content"
}

# assert_files_differ <actual> <original>
assert_files_differ() {
  local actual="$1"
  local original="$2"

  if diff -q "$actual" "$original" >/dev/null; then
    print_error "File '$actual' was not modified but was expected to change"
    exit 1
  fi

  print_success "'$actual' was modified as expected"
}

# assert_equal <actual> <expected> <label>
assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [ "$actual" != "$expected" ]; then
    print_error "$label: expected '$expected' but got '$actual'"
    exit 1
  fi

  print_success "$label is '$expected'"
}

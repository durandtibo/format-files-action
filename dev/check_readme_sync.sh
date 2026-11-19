#!/usr/bin/env bash
# Check that the inputs and outputs documented in README.md (the "Inputs" and "Outputs" tables)
# are exactly the inputs and outputs of action.yml, and that the defaults agree. The README is
# what consumers read, so a renamed, removed or re-defaulted input must show up there.
set -euo pipefail

ACTION_FILE="action.yml"
README_FILE="README.md"

# Names declared under the top-level `inputs:` or `outputs:` key of action.yml.
action_names() {
	awk -v section="$1" '
		/^[a-z]/ { in_section = ($0 == section ":") ; next }
		in_section && /^  [a-z][a-z-]*:/ { sub(/^  /, ""); sub(/:.*/, ""); print }
	' "$ACTION_FILE"
}

# First column (backticked name) of the rows of the README table under the `## <heading>` title.
readme_names() {
	awk -v heading="## $1" '
		/^## / { in_section = ($0 == heading); next }
		in_section && /^\| `/ { split($0, cells, "|"); gsub(/[ `]/, "", cells[2]); print cells[2] }
	' "$README_FILE"
}

# Default of an input in action.yml (empty when there is none), without the quotes.
action_default() {
	awk -v name="$1" '
		/^[a-z]/ { in_inputs = ($0 == "inputs:"); next }
		in_inputs && /^  [a-z][a-z-]*:/ { current = $0; sub(/^  /, "", current); sub(/:.*/, "", current); next }
		in_inputs && current == name && /^    default:/ {
			value = $0; sub(/^    default: */, "", value); gsub(/^"|"$/, "", value); print value
		}
	' "$ACTION_FILE"
}

# Default cell (last column, without backticks) of an input in the README "Inputs" table.
readme_default() {
	awk -v name="$1" '
		/^## / { in_section = ($0 == "## Inputs"); next }
		in_section && /^\| `/ {
			n = split($0, cells, "|")
			key = cells[2]; gsub(/[ `]/, "", key)
			if (key == name) {
				value = cells[n - 1]; sub(/^ +/, "", value); sub(/ +$/, "", value)
				if (value != "(none)") { gsub(/^`|`$/, "", value); print value }
			}
		}
	' "$README_FILE"
}

status=0
for section in inputs outputs; do
	heading="$(printf '%s' "$section" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')"
	if ! from_action=$(action_names "$section" | LC_ALL=C sort); then
		echo "::error::Could not read the $section of $ACTION_FILE"
		exit 1
	fi
	if ! from_readme=$(readme_names "$heading" | LC_ALL=C sort); then
		echo "::error::Could not read the $heading table of $README_FILE"
		exit 1
	fi
	if [ -z "$from_action" ]; then
		echo "::error file=$ACTION_FILE::No $section found in $ACTION_FILE"
		exit 1
	fi
	if [ "$from_action" != "$from_readme" ]; then
		echo "::error file=$README_FILE::The $section of $README_FILE differ from $ACTION_FILE"
		diff <(printf '%s\n' "$from_action") <(printf '%s\n' "$from_readme") || true
		status=1
	fi
done

if [ "$status" -eq 0 ]; then
	while IFS= read -r name; do
		in_action=$(action_default "$name")
		in_readme=$(readme_default "$name")
		if [ "$in_action" != "$in_readme" ]; then
			echo "::error file=$README_FILE::Default of input '$name' differs: $ACTION_FILE has '$in_action', $README_FILE has '$in_readme'"
			status=1
		fi
	done < <(action_names inputs)
fi

if [ "$status" -ne 0 ]; then
	exit 1
fi
echo "✅ The inputs, outputs and defaults of $README_FILE match $ACTION_FILE"

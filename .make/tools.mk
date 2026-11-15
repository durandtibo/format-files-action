ifndef TOOLS_MK_INCLUDED
TOOLS_MK_INCLUDED := 1

# Target that reports which command-line tools are installed.
#
# Every tool of `TOOLS` is looked up on the `PATH`; one aligned line per tool gives its version
# (first version number printed by `<tool> --version`, `?` if none) and where it was found, or says
# it is missing. All tools are listed so one run shows everything that is missing. The target fails
# with exit code 127 if a tool is missing.
#
# Optional variables (set before including this file, or on the command line):
#   TOOLS ?= actionlint bats ...   # space-separated tools to check (default: tools used by this repo)

TOOLS ?= actionlint bats checkmake gh markdownlint mbake prettier shellcheck shfmt taplo yamllint zizmor

.PHONY: check-tools
check-tools: ## Show which tools are installed and which are missing
	@echo "🧰 Checking the tools..."
	@missing=""; total=0; width=0; \
	for tool in $(TOOLS); do \
		if [ $${#tool} -gt $$width ]; then width=$${#tool}; fi; \
		done; \
	for tool in $(TOOLS); do \
		total=$$((total + 1)); \
		if path=$$(command -v "$$tool"); then \
			version=$$("$$tool" --version </dev/null 2>&1 | grep -o -E '[0-9]+(\.[0-9]+)+' | head -n 1 || true); \
			printf '✅ %-*s  %-9s %s\n' "$$width" "$$tool" "$${version:-?}" "$$path"; \
		else \
			printf '❌ %-*s  not found\n' "$$width" "$$tool"; \
			missing="$$missing $$tool"; \
		fi; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "⚠️ Missing:$$missing"; \
		exit 127; \
	fi; \
	echo "✅ All the $$total tools are available"

endif

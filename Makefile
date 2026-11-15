SHELL = /bin/bash

# Directory of this Makefile. Includes are anchored on it (not on the current directory) so that
# the Makefile also works when the action runs it against another repository's checkout.
MAKEFILE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

include $(MAKEFILE_DIR).make/help.mk
include $(MAKEFILE_DIR).make/actions.mk
include $(MAKEFILE_DIR).make/git.mk
include $(MAKEFILE_DIR).make/github.mk
include $(MAKEFILE_DIR).make/makefile.mk
include $(MAKEFILE_DIR).make/markdown.mk
include $(MAKEFILE_DIR).make/self.mk
include $(MAKEFILE_DIR).make/shell.mk
include $(MAKEFILE_DIR).make/toml.mk
include $(MAKEFILE_DIR).make/tools.mk
include $(MAKEFILE_DIR).make/uv.mk
include $(MAKEFILE_DIR).make/yaml.mk

.DEFAULT_GOAL := help

.PHONY: install-tools
install-tools: install-prettier install-yamllint install-mbake install-checkmake install-shellcheck install-shfmt install-bats install-taplo install-markdownlint install-actionlint install-gh ## Install all formatting/linting tools

.PHONY: format
format: format-yaml format-makefile format-shell format-toml format-markdown ## Format all files

.PHONY: lint
lint: lint-yaml lint-makefile lint-shell lint-markdown lint-actions ## Lint all files

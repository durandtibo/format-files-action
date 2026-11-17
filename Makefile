SHELL = /bin/bash

# Directory of this Makefile. Includes are anchored on it (not on the current directory) so that
# the Makefile also works when the action runs it against another repository's checkout.
MAKEFILE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

include $(MAKEFILE_DIR).make/all.mk

.PHONY: check-export
check-export: ## Check that the exported files are the files the action needs
	./dev/check_export.sh

SHELL = /bin/bash

# Directory of this Makefile. Includes are anchored on it (not on the current directory) so that
# the Makefile also works when the action runs it against another repository's checkout.
MAKEFILE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

include $(MAKEFILE_DIR).make/all.mk

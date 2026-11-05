SPEC := aic8800d80-kmod.spec
VERSION := $(shell sed -nE 's/^Version:[[:space:]]*([^[:space:]]+).*/\1/p' $(SPEC) | head -n1)
DEBUG_DIR ?= $(if $(XDG_CACHE_HOME),$(XDG_CACHE_HOME),$(HOME)/.cache)/aic8800d80
DEBUG_RPM_TOPDIR ?= $(DEBUG_DIR)/rpmbuild
SOURCE_ARCHIVE := $(DEBUG_RPM_TOPDIR)/SOURCES/aic8800d80-$(VERSION).tar.gz

.PHONY: source-archive srpm rpm distrobox-setup distrobox-rpm local-repo-publish local-repo-setup local-repo-verify local-repo-install-dry-run local-repo-install installed-modules-verify clean

source-archive:
	./build-source-archive.sh $(SOURCE_ARCHIVE)

# Run this in an RPM build environment with kmodtool and rpmbuild installed.
srpm: source-archive
	install -Dpm 0644 $(SPEC) $(DEBUG_RPM_TOPDIR)/SPECS/$(SPEC)
	rpmbuild -bs --define "_topdir $(DEBUG_RPM_TOPDIR)" $(DEBUG_RPM_TOPDIR)/SPECS/$(SPEC)

# This stages the spec at a temporary path without spaces because kmodtool’s
# generated akmod_install macro invokes _specdir without shell quoting.
rpm:
	./build-rpms.sh $(DEBUG_RPM_TOPDIR)/RPMS/$(shell rpm -E '%{_arch}')

# Preferred Bazzite workflow: use a Fedora Distrobox matching the host by
# default; set AIC8800_FEDORA_VERSION to prepare another release.
distrobox-setup:
	./setup-fedora-distrobox.sh

distrobox-rpm:
	./build-in-fedora-distrobox.sh

# Publish only the kernel-independent akmod and common packages to the local
# filesystem repository. Metadata generation stays in the Fedora Distrobox.
local-repo-publish:
	./publish-local-repo.sh

# Install the local repository configuration on the Bazzite host.
local-repo-setup:
	./setup-local-repo.sh

# Confirm the enabled local repository exposes the expected two packages.
local-repo-verify:
	./verify-local-repo.sh

# Review a first-time installation from the local filesystem repository.
local-repo-install-dry-run:
	./install-from-local-repo.sh

# Stage a first-time installation from the local filesystem repository.
local-repo-install:
	./install-from-local-repo.sh --apply

# Confirm the active (or KERNEL_RELEASE-selected) kernel has properly matched
# AIC8800 kmod RPM content after booting an updated deployment.
installed-modules-verify:
	./verify-installed-modules.sh $(KERNEL_RELEASE)

clean:
	rm -rf -- $(DEBUG_DIR)

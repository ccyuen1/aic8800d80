# AIC8800D80 akmod packaging

This directory contains the packaging-only replacement for the legacy,
running-kernel-specific `bazzite/aic8800d80.spec`. It does not modify the
upstream driver, firmware, or `dkms.conf`.

## What it builds

`aic8800d80-kmod.spec` produces three RPMs:

- `akmod-aic8800d80` — kernel-module source and akmods metadata;
- `aic8800d80-kmod-common` — firmware, udev rule, and usb_modeswitch
  configuration;
- `kmod-aic8800d80` — a meta-package; it is not needed for a local-repository
  installation.

The source RPM is kernel-independent. Akmods builds a separate
`kmod-aic8800d80-<kernel-release>` package for each target kernel, with the
matching `kernel-uname-r` dependency. The source archive is created from the
reviewed `SourceCommit` in the spec, so local packaging changes are excluded.

Secure Boot signing is intentionally disabled and out of scope.

### Runtime dependencies

`akmod-aic8800d80` declares the dependencies needed on Bazzite when akmods
creates a module for a target kernel:

```text
akmods
elfutils-libelf-devel
gcc
kmodtool
make
```

`rpm-ostree` resolves these dependencies when it installs
`akmod-aic8800d80`. Do not manually layer them solely for AIC8800D80, and do
not bundle their files into either AIC8800D80 RPM. `rpm-build`, `rpmdevtools`,
`redhat-rpm-config`, and repository-generation tools belong only in the Fedora
Distrobox. A package can remain installed when another package independently
requires it.

## Local filesystem repository

The local repository is a root-owned `file://` repository on the same computer:

```text
/var/opt/rpm-repo/aic8800d80/fedora/<Fedora release>/<architecture>/
```

It publishes only the two kernel-independent packages:
`akmod-aic8800d80` and `aic8800d80-kmod-common`. It does not publish prebuilt
kernel-specific `kmod-aic8800d80-<kernel-release>` RPMs. Akmods must build the
exact-kernel package for the deployment's target kernel.

The Fedora Distrobox release normally follows the Bazzite host. Set
`AIC8800_FEDORA_VERSION` when preparing RPMs for a different target release,
for example before a Fedora major-version upgrade. Its build and
repository-generation tools are not layered onto Bazzite. Persistent RPM
artifacts for publication remain in `$HOME/rpmbuild`, not in the
disposable maintainer cache.

### 1. New installation

On a computer with no related AIC8800D80 packages, build the RPMs, publish them
to the local repository, install the repository configuration, and verify it:

```bash
make distrobox-setup
make distrobox-rpm
make local-repo-publish
sudo make local-repo-setup
sudo make local-repo-verify
```

Review and stage the first-time installation transaction:

```bash
sudo make local-repo-install-dry-run
sudo make local-repo-install
```

Reboot into the staged deployment. Confirm the two AIC8800D80 packages appear
as regular layered packages, then verify the running kernel's generated
modules:

```bash
rpm-ostree status
sudo make installed-modules-verify
```

Users should perform Wi-Fi and Bluetooth verification on the actual computer.
Package/build validation does not prove hardware functionality.

### 2. Existing repository installation

For a computer that already installs AIC8800D80 from this local repository,
rebuild and republish when the reviewed package source changes. The existing
repository configuration remains in place:

```bash
make distrobox-rpm
make local-repo-publish
sudo make local-repo-verify
```

Run the normal Bazzite update command to create a deployment using the updated
repository packages, then reboot:

```bash
sudo ujust update
```

After reboot, verify that the modules generated for the running kernel exist
and have matching `vermagic`:

```bash
sudo make installed-modules-verify
```

Do not install the legacy kernel-specific `aic8800d80` package alongside
`akmod-aic8800d80`.

### 3. Fedora major-version upgrade

Prepare the RPM repository for the target Fedora release **before** starting
the Bazzite major-version upgrade. The normal workflow detects the release
from the running host, which is still the old release at this point. Set
`AIC8800_FEDORA_VERSION` to select the target release for Distrobox setup,
RPM building, repository publication, and verification.

For example, to prepare Fedora 45 while the host is still on Fedora 44:

```bash
AIC8800_FEDORA_VERSION=45 make distrobox-setup
AIC8800_FEDORA_VERSION=45 make distrobox-rpm
AIC8800_FEDORA_VERSION=45 make local-repo-publish
sudo make AIC8800_FEDORA_VERSION=45 local-repo-verify
```

During Fedora Distrobox setup, `grub2-common` may print a
`grub2-probe: error: failed to get canonical path of 'overlay'` message from
its post-transaction scriptlet. This is caused by the container's overlay
filesystem, which `grub2-probe` cannot map to a block device. It is non-fatal
when package installation completes successfully (`Complete!`); it does not
indicate a problem with the AIC8800D80 build or require GRUB repair.

The example creates/uses a Fedora 45 Distrobox and publishes the packages under:

```text
/var/opt/rpm-repo/aic8800d80/fedora/45/<architecture>/
```

The Fedora host is not upgraded or modified by these build steps. The
existing repository configuration uses `$releasever`, so the Fedora
repository is selected by the upgrade transaction after the host upgrades to
newer Fedora version. Keep the existing Fedora repository.
Once the target repository has been verified, perform the
normal Bazzite major-version upgrade and reboot.

For ordinary updates within the current Fedora release, omit
`AIC8800_FEDORA_VERSION` and continue using the normal workflow.

### Update and rollback test

Before a Bazzite update, preserve a known-good deployment and verify the local
repository:

```bash
sudo make local-repo-verify
rpm-ostree status
```

The user then runs `sudo ujust update`, reboots into the new deployment, runs
`sudo make installed-modules-verify`, verifies Wi-Fi and Bluetooth, and, if
practical, boot-tests the known-good prior deployment as rollback validation.

### Trust policy

This initial local-only workflow uses a root-owned filesystem location and
does not implement RPM or repository-metadata GPG signatures:

```text
gpgcheck=0
repo_gpgcheck=0
```

This is an intentional limitation of the simple local-repository design, not
a Secure Boot decision. The publisher retains older complete sets under
`/var/opt/rpm-repo/aic8800d80/releases/` and atomically switches the active
Fedora-release/architecture path. Anyone able to alter the root-owned
repository or its enabled configuration can affect packages selected by an
rpm-ostree transaction. Add RPM/repository GPG signing before using this
design for network distribution or a stronger package-provenance policy.

## Optional maintainer diagnostics

Direct `make source-archive`, `make srpm`, and `make rpm` invocations are
development/debug operations, not supported computer workflows. Their generated
files are isolated under `${XDG_CACHE_HOME:-$HOME/.cache}/aic8800d80/rpmbuild`;
`make clean` removes the complete `${XDG_CACHE_HOME:-$HOME/.cache}/aic8800d80`
cache directory. Set `DEBUG_DIR` or `DEBUG_RPM_TOPDIR` on the `make` command
only when a different disposable location is needed. Do not put packages
intended for the local repository in this cache.

## Validation status

Completed:

- package/module builds, dependency checks, `vermagic`, and isolated
  `depmod` checks;
- initial laptop installation, Wi-Fi, and Bluetooth verification; and
- local-repository publication, setup, and active-kernel module verification.

Still required: test a normal Bazzite update to a newer kernel, then boot the
previous deployment as rollback validation if practical.

## Updating the upstream driver

When accepting a reviewed upstream revision:

1. update `SourceCommit` and `Release` in the spec;
2. rebuild the RPMs and a target-kernel kmod;
3. republish and verify the local repository;
4. verify that only intended packaging files changed; and
5. ask the user to perform the applicable hardware, update, and rollback
   tests.

Keep upstream driver updates and local packaging changes in separate commits.

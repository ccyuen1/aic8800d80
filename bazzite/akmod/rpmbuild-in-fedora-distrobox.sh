#!/usr/bin/env bash
# Build the akmod RPMs inside the prepared Fedora Distrobox for the selected
# target release, using the conventional rpmdevtools/rpmbuild tree. Do not run
# this on the Bazzite host.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/../.." && pwd)
spec_file="$script_dir/aic8800d80-kmod.spec"
rpm_topdir="$HOME/rpmbuild"

expected_fedora=${1:?missing expected Fedora release}
actual_fedora=$(rpm -E '%{fedora}')
if [[ "$actual_fedora" != "$expected_fedora" ]]; then
    printf 'Expected a Fedora %q build container; found Fedora release %q.\n' \
        "$expected_fedora" "$actual_fedora" >&2
    exit 2
fi

required_packages=(akmods cpio elfutils-libelf-devel gcc kmodtool make redhat-rpm-config rpm-build rpmdevtools)
missing_packages=()
for package in "${required_packages[@]}"; do
    rpm -q "$package" >/dev/null 2>&1 || missing_packages+=("$package")
done
if ((${#missing_packages[@]})); then
    printf 'Missing build dependencies: %s\nRun %s first.\n' \
        "${missing_packages[*]}" "$script_dir/setup-fedora-distrobox.sh" >&2
    exit 3
fi

# Packaging changes are expected, but never build if protected upstream paths
# have uncommitted modifications.
git -C "$repo_dir" diff --exit-code -- drivers/aic8800 fw dkms.conf

version=$(sed -nE 's/^Version:[[:space:]]*([^[:space:]]+).*/\1/p' "$spec_file" | head -n1)
if [[ -z "$version" ]]; then
    echo "Could not read Version from $spec_file" >&2
    exit 2
fi

mkdir -p "$rpm_topdir"
rpmdev-setuptree
mkdir -p "$rpm_topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# rpmdev-setuptree follows the standard $HOME/rpmbuild layout. This script
# keeps the spec in SPECS, a path without spaces, because kmodtool's nested
# source-RPM command does not shell-quote _specdir.
install -m 0644 "$spec_file" "$rpm_topdir/SPECS/aic8800d80-kmod.spec"
"$script_dir/build-source-archive.sh" \
    "$rpm_topdir/SOURCES/aic8800d80-${version}.tar.gz"

rpmbuild -bs "$rpm_topdir/SPECS/aic8800d80-kmod.spec"
rpmbuild -bb "$rpm_topdir/SPECS/aic8800d80-kmod.spec"

arch=$(rpm -E '%{_arch}')
printf 'Built RPMs:\n'
find "$rpm_topdir/RPMS/$arch" -maxdepth 1 -type f \
    \( -name 'akmod-aic8800d80-*.rpm' -o -name 'aic8800d80-kmod-common-*.rpm' -o -name 'kmod-aic8800d80-*.rpm' \) \
    -printf '  %p\n' | sort

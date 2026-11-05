#!/usr/bin/env bash
# Run inside the selected Fedora Distrobox, not on the Bazzite host.
set -euo pipefail

expected_fedora=${1:?missing expected Fedora release}
actual_fedora=$(rpm -E '%{fedora}')
if [[ "$actual_fedora" != "$expected_fedora" ]]; then
    printf 'Expected a Fedora %q build container; found Fedora release %q.\n' \
        "$expected_fedora" "$actual_fedora" >&2
    exit 2
fi

required_packages=(
    akmods
    cpio
    createrepo_c
    elfutils-libelf-devel
    gcc
    kmodtool
    make
    redhat-rpm-config
    rpm-build
    rpmdevtools
)

missing_packages=()
for package in "${required_packages[@]}"; do
    rpm -q "$package" >/dev/null 2>&1 || missing_packages+=("$package")
done

if ((${#missing_packages[@]} == 0)); then
    printf 'Fedora %s Distrobox build dependencies are already installed.\n' \
        "$actual_fedora"
    exit 0
fi

printf 'Installing Fedora %s Distrobox build dependencies: %s\n' \
    "$actual_fedora" "${missing_packages[*]}"
sudo dnf install -y "${missing_packages[@]}"

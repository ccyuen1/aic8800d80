#!/usr/bin/env bash
# Verify the local filesystem repository before using it in an rpm-ostree
# transaction or a normal Bazzite update.
set -euo pipefail

repo_id=aic8800d80-local
host_fedora=$(rpm -E '%{fedora}')
target_fedora=${AIC8800_FEDORA_VERSION:-$host_fedora}
host_arch=$(rpm -E '%{_arch}')
repo_path="/var/opt/rpm-repo/aic8800d80/fedora/$target_fedora/$host_arch"
expected_packages=(akmod-aic8800d80 aic8800d80-kmod-common)

if [[ ! "$target_fedora" =~ ^[0-9]+$ ]]; then
    printf 'Could not determine a valid target Fedora release: %q.\n' \
        "$target_fedora" >&2
    exit 2
fi

if ((EUID != 0)); then
    echo 'Run this with sudo: sudo make local-repo-verify' >&2
    exit 2
fi

if [[ ! -f "$repo_path/repodata/repomd.xml" ]]; then
    printf 'No local repository metadata exists at %s.\n' "$repo_path" >&2
    exit 3
fi

if [[ $(stat -c '%U:%G' /var/opt/rpm-repo/aic8800d80) != root:root ]]; then
    echo 'The local repository root must be owned by root:root.' >&2
    exit 4
fi

for package in "${expected_packages[@]}"; do
    package_path=$(find -L "$repo_path" -maxdepth 1 -type f -name "${package}-*.rpm" -print -quit)
    if [[ -z "$package_path" ]]; then
        printf 'Local repository is missing %s.\n' "$package" >&2
        exit 4
    fi

    package_name=$(rpm -qp --qf '%{NAME}' "$package_path")
    if [[ "$package_name" != "$package" ]]; then
        printf 'Unexpected package name in %s: %s\n' "$package_path" "$package_name" >&2
        exit 4
    fi
done

if find -L "$repo_path" -maxdepth 1 -type f -name 'kmod-aic8800d80-*.rpm' -print -quit | grep -q .; then
    echo 'The local source repository must not publish kmod-aic8800d80 RPMs.' >&2
    exit 4
fi

dnf5 --releasever="$target_fedora" --refresh repoquery \
    --repo "$repo_id" --latest-limit=1 \
    akmod-aic8800d80 aic8800d80-kmod-common

printf 'Verified local AIC8800D80 repository for Fedora %s, %s.\n' \
    "$target_fedora" "$host_arch"

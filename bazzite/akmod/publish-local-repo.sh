#!/usr/bin/env bash
# Publish the akmod source and common packages to the Bazzite host's local
# filesystem repository. Repository metadata is generated in Fedora Distrobox.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# `sudo make local-repo-publish` is supported, but Distrobox and the RPM
# output belong to the invoking user rather than root. Re-execute as that user
# while retaining the sudo credential acquired by the outer command.
if ((EUID == 0)); then
    if [[ -z ${SUDO_USER:-} || $SUDO_USER == root ]]; then
        echo 'Run this through sudo from a regular Bazzite user account.' >&2
        exit 2
    fi

    invoking_user=$SUDO_USER
    invoking_uid=$(id -u "$invoking_user")
    invoking_home=$(getent passwd "$invoking_user" | cut -d: -f6)
    if [[ -z "$invoking_home" ]]; then
        printf 'Could not determine the home directory for %q.\n' "$invoking_user" >&2
        exit 2
    fi

    export HOME=$invoking_home
    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$invoking_uid"}
    exec runuser -u "$invoking_user" --preserve-environment -- "$0" "$@"
fi

repo_dir=$(cd -- "$script_dir/../.." && pwd)
host_fedora=$(rpm -E '%{fedora}')
target_fedora=${AIC8800_FEDORA_VERSION:-$host_fedora}
host_arch=$(rpm -E '%{_arch}')
container_name=${AIC8800_DISTROBOX_NAME:-aic8800-rpmbuild-f${target_fedora}}
rpm_dir=${AIC8800_RPM_DIR:-"$HOME/rpmbuild/RPMS/$host_arch"}
repo_root=/var/opt/rpm-repo/aic8800d80
repo_path="$repo_root/fedora/$target_fedora/$host_arch"
repo_parent=$(dirname "$repo_path")
release_root="$repo_root/releases/fedora-${target_fedora}-${host_arch}"
staging_parent=${AIC8800_REPO_STAGING_DIR:-"$HOME/.cache/aic8800d80-rpm-repo"}

if [[ "$staging_parent" != "$HOME"/* ]]; then
    printf 'AIC8800_REPO_STAGING_DIR must be below %s: %s\n' \
        "$HOME" "$staging_parent" >&2
    exit 2
fi

if [[ ! "$target_fedora" =~ ^[0-9]+$ ]]; then
    printf 'Could not determine a valid target Fedora release: %q.\n' \
        "$target_fedora" >&2
    exit 2
fi

# Authenticate before the Distrobox work begins, so the only password prompt
# occurs at the start of the publication workflow.
sudo -v

if [[ ! -d "$rpm_dir" ]]; then
    printf 'RPM directory does not exist: %s\nRun make distrobox-rpm first.\n' \
        "$rpm_dir" >&2
    exit 2
fi

if ! command -v distrobox >/dev/null 2>&1; then
    echo 'distrobox is required on the Bazzite host.' >&2
    exit 2
fi

if ! distrobox list --no-color | awk -F '|' -v expected="$container_name" '
    NR > 1 {
        name = $2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        if (name == expected) {
            found = 1
        }
    }
    END { exit(found ? 0 : 1) }
'; then
    printf 'Fedora Distrobox %q does not exist. Run make distrobox-setup first.\n' \
        "$container_name" >&2
    exit 3
fi

git -C "$repo_dir" diff --exit-code -- drivers/aic8800 fw dkms.conf

mkdir -p -m 0700 "$staging_parent"
chmod 0700 "$staging_parent"
staging_dir=$(mktemp -d "$staging_parent/f${target_fedora}-${host_arch}.XXXXXX")
cleanup() {
    if ! rm -rf -- "$staging_dir" 2>/dev/null; then
        sudo rm -rf -- "$staging_dir"
    fi
    rmdir -- "$staging_parent" 2>/dev/null || true
}
trap cleanup EXIT

distrobox enter --name "$container_name" -- \
    bash "$script_dir/publish-in-fedora-distrobox.sh" \
    "$target_fedora" "$rpm_dir" "$staging_dir"

akmod_rpm=$(find "$staging_dir" -maxdepth 1 -type f -name 'akmod-aic8800d80-*.rpm' -print -quit)
if [[ -z "$akmod_rpm" ]]; then
    echo 'The staged repository does not contain akmod-aic8800d80.' >&2
    exit 4
fi

publication_evr=$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$akmod_rpm")
publication_id="$(date -u +%Y%m%dT%H%M%SZ)-${publication_evr}"
release_dir="$release_root/$publication_id"
temporary_link="$repo_parent/.${host_arch}.new.$$"
link_target="../../releases/fedora-${target_fedora}-${host_arch}/${publication_id}"

sudo install -d -m 0755 "$release_dir" "$repo_parent"
sudo cp -a --no-preserve=ownership "$staging_dir/." "$release_dir/"
sudo ln -s "$link_target" "$temporary_link"
sudo mv -Tf "$temporary_link" "$repo_path"

printf 'Published local repository at %s\n' "$repo_path"
printf 'Published RPM set: %s\n' "$publication_id"
printf 'Previous published sets are retained under %s\n' "$release_root"

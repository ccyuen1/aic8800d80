#!/usr/bin/env bash
# Enable the root-owned local filesystem repository on the Bazzite host.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
host_fedora=$(rpm -E '%{fedora}')
host_arch=$(rpm -E '%{_arch}')
repo_file="$script_dir/aic8800d80-local.repo"
repo_path="/var/opt/rpm-repo/aic8800d80/fedora/$host_fedora/$host_arch"

if [[ ! "$host_fedora" =~ ^[0-9]+$ ]]; then
    printf 'Could not determine the Bazzite host Fedora release: %q.\n' \
        "$host_fedora" >&2
    exit 2
fi

if [[ ! -f "$repo_path/repodata/repomd.xml" ]]; then
    printf 'No local repository metadata exists at %s. Run make local-repo-publish first.\n' \
        "$repo_path" >&2
    exit 3
fi

sudo install -Dpm 0644 "$repo_file" /etc/yum.repos.d/aic8800d80-local.repo
printf 'Installed local repository configuration: %s\n' \
    /etc/yum.repos.d/aic8800d80-local.repo

"$script_dir/verify-local-repo.sh"

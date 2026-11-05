#!/usr/bin/env bash
# Run the prepared Fedora Distrobox build for the selected target release. This
# intentionally keeps rpmbuild and its dependencies out of the immutable host.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
host_fedora=$(rpm -E '%{fedora}')
target_fedora=${AIC8800_FEDORA_VERSION:-$host_fedora}
container_name=${AIC8800_DISTROBOX_NAME:-aic8800-rpmbuild-f${target_fedora}}

if [[ ! "$target_fedora" =~ ^[0-9]+$ ]]; then
    printf 'Could not determine a valid target Fedora release: %q.\n' \
        "$target_fedora" >&2
    exit 2
fi

if ! command -v distrobox >/dev/null 2>&1; then
    echo "distrobox is required on the Bazzite host." >&2
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
    printf 'Distrobox %q does not exist. Run %s first.\n' \
        "$container_name" "$script_dir/setup-fedora-distrobox.sh" >&2
    exit 3
fi

distrobox enter --name "$container_name" -- \
    bash "$script_dir/rpmbuild-in-fedora-distrobox.sh" "$target_fedora"

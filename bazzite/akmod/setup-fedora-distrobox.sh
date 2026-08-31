#!/usr/bin/env bash
# Create a Fedora Distrobox matching the Bazzite host release, then install
# only the RPM build dependencies inside that container.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
host_fedora=$(rpm -E '%{fedora}')
container_name=${AIC8800_DISTROBOX_NAME:-aic8800-rpmbuild-f${host_fedora}}
container_image=registry.fedoraproject.org/fedora-toolbox:${host_fedora}

if [[ ! "$host_fedora" =~ ^[0-9]+$ ]]; then
    printf 'Could not determine the Bazzite host Fedora release: %q.\n' \
        "$host_fedora" >&2
    exit 2
fi

if ! command -v distrobox >/dev/null 2>&1; then
    echo "distrobox is required on the Bazzite host." >&2
    exit 2
fi

container_exists() {
    distrobox list --no-color | awk -F '|' -v expected="$container_name" '
        NR > 1 {
            name = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            if (name == expected) {
                found = 1
            }
        }
        END { exit(found ? 0 : 1) }
    '
}

if ! container_exists; then
    printf 'Creating Distrobox %q from %s\n' "$container_name" "$container_image"
    distrobox create --yes --name "$container_name" --image "$container_image"
fi

distrobox enter --name "$container_name" -- \
    bash "$script_dir/setup-fedora-build-environment.sh" "$host_fedora"

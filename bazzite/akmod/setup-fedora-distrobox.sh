#!/usr/bin/env bash
# Create a Fedora Distrobox for the host or selected target release, then
# install only the RPM build dependencies inside that container.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
host_fedora=$(rpm -E '%{fedora}')
target_fedora=${AIC8800_FEDORA_VERSION:-$host_fedora}
container_name=${AIC8800_DISTROBOX_NAME:-aic8800-rpmbuild-f${target_fedora}}
container_image=registry.fedoraproject.org/fedora-toolbox:${target_fedora}

if [[ ! "$target_fedora" =~ ^[0-9]+$ ]]; then
    printf 'Could not determine a valid target Fedora release: %q.\n' \
        "$target_fedora" >&2
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
    bash "$script_dir/setup-fedora-build-environment.sh" "$target_fedora"

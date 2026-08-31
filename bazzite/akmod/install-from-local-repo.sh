#!/usr/bin/env bash
# Install the two kernel-independent AIC8800D80 packages from the enabled
# local filesystem repository on a computer with no existing AIC8800 package.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
apply=0

usage() {
    cat <<'EOF'
Usage: install-from-local-repo.sh [--apply]

Without --apply, dry-runs the rpm-ostree installation. Review the output
before repeating the command with --apply on the Bazzite laptop.
EOF
}

if [[ ${1:-} == --apply ]]; then
    apply=1
    shift
fi

if (($# != 0)); then
    usage >&2
    exit 2
fi

sudo "$script_dir/verify-local-repo.sh"

command=(sudo rpm-ostree install akmod-aic8800d80)
if ((apply == 0)); then
    printf 'Dry-running installation from the local AIC8800D80 repository.\n'
    command=(sudo rpm-ostree install --dry-run akmod-aic8800d80)
fi

"${command[@]}"

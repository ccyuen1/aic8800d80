#!/usr/bin/env bash
# Generate RPM repository metadata inside the Fedora Distrobox. The staging
# directory must be under $HOME so Distrobox shares it with the Bazzite host.
set -euo pipefail

expected_fedora=${1:?missing expected Fedora release}
rpm_dir=${2:?missing RPM directory}
staging_dir=${3:?missing staging directory}

actual_fedora=$(rpm -E '%{fedora}')
if [[ "$actual_fedora" != "$expected_fedora" ]]; then
    printf 'Expected a Fedora %q build container; found Fedora release %q.\n' \
        "$expected_fedora" "$actual_fedora" >&2
    exit 2
fi

if ! command -v createrepo_c >/dev/null 2>&1; then
    echo 'createrepo_c is required in the Fedora Distrobox. Run make distrobox-setup first.' >&2
    exit 3
fi

if [[ ! -d "$rpm_dir" ]]; then
    printf 'RPM directory does not exist: %s\n' "$rpm_dir" >&2
    exit 2
fi

select_newest_rpm() {
    local pattern=$1
    local candidate
    local candidate_mtime
    local newest_rpm=
    local newest_mtime=-1
    local -a candidates

    shopt -s nullglob
    candidates=("$rpm_dir"/$pattern)
    shopt -u nullglob

    for candidate in "${candidates[@]}"; do
        candidate_mtime=$(stat -c '%Y' "$candidate")
        if ((candidate_mtime > newest_mtime)); then
            newest_rpm=$candidate
            newest_mtime=$candidate_mtime
        fi
    done

    if [[ -z "$newest_rpm" ]]; then
        printf 'No RPM matching %q was found in %s.\n' "$pattern" "$rpm_dir" >&2
        exit 4
    fi

    printf '%s\n' "$newest_rpm"
}

akmod_rpm=$(select_newest_rpm 'akmod-aic8800d80-*.rpm')
akmod_evr=$(rpm -qp --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$akmod_rpm")
akmod_arch=$(rpm -qp --qf '%{ARCH}' "$akmod_rpm")

common_rpm=
while IFS= read -r candidate; do
    candidate_evr=$(rpm -qp --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$candidate")
    candidate_arch=$(rpm -qp --qf '%{ARCH}' "$candidate")
    if [[ "$candidate_evr" == "$akmod_evr" && "$candidate_arch" == "$akmod_arch" ]]; then
        common_rpm=$candidate
        break
    fi
done < <(find "$rpm_dir" -maxdepth 1 -type f -name 'aic8800d80-kmod-common-*.rpm' -print | sort)

if [[ -z "$common_rpm" ]]; then
    printf 'No aic8800d80-kmod-common RPM matching %s and %s was found in %s.\n' \
        "$akmod_evr" "$akmod_arch" "$rpm_dir" >&2
    exit 4
fi

mkdir -p "$staging_dir"
if find "$staging_dir" -mindepth 1 -print -quit | grep -q .; then
    printf 'Staging directory must be empty: %s\n' "$staging_dir" >&2
    exit 2
fi

install -pm 0644 "$akmod_rpm" "$common_rpm" "$staging_dir/"
createrepo_c --unique-md-filenames "$staging_dir"

test -f "$staging_dir/repodata/repomd.xml"
printf 'Staged local RPM repository for Fedora %s, %s:\n' \
    "$expected_fedora" "$akmod_arch"
printf '  %s\n' "$akmod_rpm" "$common_rpm"

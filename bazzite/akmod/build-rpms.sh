#!/usr/bin/env bash
# Build installable RPMs without assuming the repository path has no spaces.
# kmodtool's generated akmod_install macro invokes the spec from _specdir
# without shell quoting, so this script stages the spec in a safe temp path.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
spec_file="$script_dir/aic8800d80-kmod.spec"
debug_dir=${AIC8800_DEBUG_DIR:-"${XDG_CACHE_HOME:-$HOME/.cache}/aic8800d80"}
debug_rpm_topdir=${AIC8800_DEBUG_RPM_TOPDIR:-"$debug_dir/rpmbuild"}
arch=$(rpm -E '%{_arch}')
output_dir=${1:-"$debug_rpm_topdir/RPMS/$arch"}
source_dir="$debug_rpm_topdir/SOURCES"
version=$(sed -nE 's/^Version:[[:space:]]*([^[:space:]]+).*/\1/p' "$spec_file" | head -n1)

if [[ -z "$version" ]]; then
    echo "Could not read Version from $spec_file" >&2
    exit 2
fi

"$script_dir/build-source-archive.sh" "$source_dir/aic8800d80-${version}.tar.gz"
mkdir -p -- "$output_dir"

build_topdir=$(mktemp -d /tmp/rpmbuild.XXXXXX)
trap 'rm -rf -- "$build_topdir"' EXIT
mkdir -p "$build_topdir/SPECS"
cp -- "$spec_file" "$build_topdir/SPECS/"

rpmbuild -bb \
    --define "_topdir $build_topdir" \
    --define "_sourcedir $source_dir" \
    --define "_specdir $build_topdir/SPECS" \
    --define "_rpmdir $output_dir" \
    --define "_srcrpmdir $output_dir" \
    "$build_topdir/SPECS/$(basename -- "$spec_file")"

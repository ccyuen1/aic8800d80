#!/usr/bin/env bash
# Create the source archive consumed by aic8800d80-kmod.spec.
# It intentionally archives the reviewed upstream SourceCommit, not local
# packaging changes or an arbitrary working tree state.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/../.." && pwd)
spec_file="$script_dir/aic8800d80-kmod.spec"

version=$(sed -nE 's/^Version:[[:space:]]*([^[:space:]]+).*/\1/p' "$spec_file" | head -n1)
source_commit=$(sed -nE 's/^#[[:space:]]*SourceCommit:[[:space:]]*([0-9a-fA-F]+).*/\1/p' "$spec_file" | head -n1)

if [[ -z "$version" || -z "$source_commit" ]]; then
    echo "Could not read Version or SourceCommit from $spec_file" >&2
    exit 2
fi

git -C "$repo_dir" cat-file -e "${source_commit}^{commit}"

output=${1:-"$script_dir/aic8800d80-${version}.tar.gz"}
output_dir=$(dirname -- "$output")
mkdir -p -- "$output_dir"
tmp_output=$(mktemp --tmpdir="$output_dir" ".aic8800d80-${version}.tar.gz.XXXXXX")
trap 'rm -f -- "$tmp_output"' EXIT

git -C "$repo_dir" archive --format=tar \
    --prefix="aic8800d80-${version}/" "$source_commit" | gzip -n > "$tmp_output"
mv -f -- "$tmp_output" "$output"
trap - EXIT

printf 'Created %s from reviewed upstream commit %s\n' "$output" "$source_commit"

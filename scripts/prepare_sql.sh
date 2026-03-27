#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <gcp-project-id>" >&2
  exit 1
fi

project_id="$1"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$repo_root/out/sql_rendered"

rm -rf "$output_dir"
mkdir -p "$output_dir"

for source_file in "$repo_root"/sql/*.sql; do
  target_file="$output_dir/$(basename "$source_file")"
  sed "s/{{PROJECT_ID}}/$project_id/g" "$source_file" > "$target_file"
done

echo "Rendered SQL files to $output_dir"
echo "Canonical files in sql/ were not modified."

#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/WinList.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/WinList" "$contents_dir/MacOS/WinList"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
codesign \
    --force \
    --sign - \
    --identifier "dev.winlist.app" \
    --requirements '=designated => identifier "dev.winlist.app"' \
    "$app_dir"

echo "$app_dir"

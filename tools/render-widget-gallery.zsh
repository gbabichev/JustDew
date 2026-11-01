#!/bin/zsh
# Render the real widget views without launching an app or a simulator.
set -euo pipefail
cd "${0:A:h}/.."
output="${1:-/tmp/JustDew-widget-gallery}"
mkdir -p "$output"
build_dir="$(mktemp -d /tmp/justdew-widget-gallery.XXXXXX)"
trap 'rm -rf "$build_dir"' EXIT
xcrun swiftc -target arm64-apple-macos27.0 \
  -module-cache-path "$build_dir/modules" \
  SharedCore/*.swift tools/WidgetLayoutGallery.swift \
  -o "$build_dir/render-widgets"
"$build_dir/render-widgets" "$output"
echo "Open: $output/index.html"

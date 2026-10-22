#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p bin
stage="$(mktemp -d /tmp/ed-psx-renderer.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
for arch in arm64 x86_64; do
  clang++ -std=c++17 -O3 -fvisibility=hidden -arch "$arch" -mmacosx-version-min=11.0 \
    -dynamiclib binding.cpp rasterizer.cpp -install_name @rpath/libed_psx_renderer.macos.universal.dylib \
    -o "$stage/libed_psx_renderer.$arch.dylib"
done
lipo -create "$stage/libed_psx_renderer.arm64.dylib" "$stage/libed_psx_renderer.x86_64.dylib" \
  -output "$stage/libed_psx_renderer.macos.universal.dylib"
codesign --force --sign - "$stage/libed_psx_renderer.macos.universal.dylib"
mv "$stage/libed_psx_renderer.macos.universal.dylib" bin/libed_psx_renderer.macos.universal.dylib
lipo -info bin/libed_psx_renderer.macos.universal.dylib

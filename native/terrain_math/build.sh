#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p bin
stage="$(mktemp -d /tmp/goemon-terrain-math.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
for arch in arm64 x86_64; do
  clang++ -std=c++17 -O3 -ffp-contract=off -fno-fast-math -fvisibility=hidden \
    -arch "$arch" -mmacosx-version-min=11.0 -dynamiclib terrain_math.cpp crowd_binding.cpp crowd/core.cpp crowd/terrain.cpp crowd/air.cpp crowd/kits.cpp crowd/combat.cpp crowd/bunker.cpp crowd/instance_buffers.cpp \
    -install_name @rpath/libgoemon_terrain_math.macos.universal.dylib \
    -o "$stage/libgoemon_terrain_math.$arch.dylib"
done
lipo -create "$stage/libgoemon_terrain_math.arm64.dylib" "$stage/libgoemon_terrain_math.x86_64.dylib" \
  -output "$stage/libgoemon_terrain_math.macos.universal.dylib"
codesign --force --sign - "$stage/libgoemon_terrain_math.macos.universal.dylib"
mv "$stage/libgoemon_terrain_math.macos.universal.dylib" bin/libgoemon_terrain_math.macos.universal.dylib
lipo -info bin/libgoemon_terrain_math.macos.universal.dylib

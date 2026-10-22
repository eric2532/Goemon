# Spirit Fortress effects provenance

Adapted from the exact standalone source asset in
[marc-prototypes-macos-2026-10-10](https://github.com/eric2532/Goemon/releases/tag/marc-prototypes-macos-2026-10-10):
`Goemon-Standalone-Prototypes-Source-0.1.0.zip`.

Verified source ZIP SHA-256:
`c8a5f276742d2ccb2ca97564d795bf2ad835b89368f903e988d346ecf12d9b31`.
All files also matched the package's `SOURCE-SHA256SUMS.txt` manifest.

`water.gdshader` is byte-identical to the demo shader. `banner.gdshader`
retains the wind and flower-crest functions and adds cloth/trim color
uniforms to fit the existing battlefield banners. Runtime adaptation is
in `scripts/spirit_fortress_effects.gd`: existing world lighting and
emission, 116 CPU particles, up to five distance-faded accent lights,
side pools, floating stones and a shrine rune pulse. Animation uses the
pausable game clock rather than shader `TIME`.

The standalone source archive remains separate from the game checkout;
its scene, camera, demonstration UI and input bindings are not imported
into the playable game. The package identifies its art as original
procedural sample art and includes `GODOT-LICENSES.txt` for Godot.

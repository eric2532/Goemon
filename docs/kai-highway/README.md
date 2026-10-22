# Kai Highway Castle

The default playable map adapts Kai Highway (ROM room `0x12c`, exit to Mt Fuji `0x12d`) around the existing four-gate fort and eight enemy portals. The original raised terraces, bridge areas and recovered grass, earth, wood and stone textures are retained. The central castle foundation is flattened and broad, gently graded approaches accommodate the fitted giant footprint.

This is a battle-map adaptation of recovered static scenery, not an exact reconstruction of the ROM collision or actor placements. Source triangles and UVs are retained in `assets/maps/kai_highway/source.json`; `provenance.json` records the ROM hash, source display list, scales, origin and texture crops. No ROM is distributed in the game.

The terrain is baked as a three-metre triangulated height field. Rendering, native collision, enemy navigation, formation bodies, portal placement and construction validation share that surface. Structures and trees may be placed on clear level patches; steep faces and source cutouts are excluded from AI routes and placement. Eight 30-metre-wide roads connect the fort to the portals.

The Map Editor includes **Kai Highway Castle**, **Four Gates**, **Twin Ramparts** and **Original Map**. Saving or renaming a Kai map preserves its `terrain_source` identity. Existing user maps without that field keep their original terrain.

## Rebuild the adapted terrain

Use Python with NumPy and Pillow. The generator defaults to the recovered source JSON and textures preserved in this repository. To regenerate from another recovery folder, pass `--source` pointing at its `kai-highway.json` and 21 `texture_*.png` files.

```sh
python tools/build_kai_highway.py --output /tmp/kai-bake.json
Godot --headless --editor --path . --quit
Godot --headless --path . --script res://tools/bake_kai_highway.gd -- --input=/tmp/kai-bake.json
```

The Python step derives the adapted preset, height field and source texture surfaces. The Godot step writes `terrain.res`, `collision.res` and `surface.res`. These native resources and the map JSON ship in the Painterly Preview macOS export; the resulting app is named Goemon.

Focused runtime checks are `scripts/kai_highway_terrain_tests.gd` and `scripts/kai_highway_gameplay_tests.gd`. They also run against the exported PCK. Map document/editor checks live in `tests/forest-shrine/kai_map_document_test.gd`.


Crowded waves now render one body per independent enemy. Each body has its own health, AI, attacks and native hitboxes. Legacy ordinary-group counts migrate to five individuals per old group once; subsequent Core Balance counts are individuals. Rare giant and portal-boss counts stay explicit. The director retains its 240-active cap and queues blocked arrivals, with three arrivals per 0.13-second interval instead of three five-body groups per 0.65 seconds.

At48 active enemies, the shared enemy/worker/tower world advances at30Hz; at128 it advances at20Hz. Elapsed time is conserved. Player input, abilities and native projectile sweeps retain the normal physics cadence. Rendering consumes the same prepared enemy contact snapshot as native physics; local hits invalidate it immediately. Kai terrain assets, hills, bridges and collision geometry are unchanged.

Regression entry points include `scripts/independent_enemy_tests.gd` (actual raised Kai road, independent damage/death, native coin/pipe/wall contacts and heavy-mode snapshots), `scripts/independent_population_tests.gd` (one-time saved-count conversion and persistence), and `scripts/crowd_update_rate_tests.gd` (cadence boundaries and elapsed time).

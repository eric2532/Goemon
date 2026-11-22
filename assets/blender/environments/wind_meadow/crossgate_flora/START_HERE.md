# Cross Gate solid tree variants

Falan and the 海洞–熊洞 road use these three solid tree variants instead of the
generic meadow tree appearances. They reuse the approved broadleaf trunk and
every existing leaf quad: 6,396 triangles, two meshes and two materials per tree.
The original meadow Blender master and GLB remain unchanged; their preparation
hashes and source counts are in `provenance.json`.

| Editable master | Original graphic | Runtime model |
| --- | --- | --- |
| `cg_evergreen.blend` | 10058 | `assets/models/environments/wind_meadow/crossgate_flora/cg_evergreen.glb` |
| `cg_woodland.blend` | 10085 | `assets/models/environments/wind_meadow/crossgate_flora/cg_woodland.glb` |
| `cg_silverleaf.blend` | 10088 | `assets/models/environments/wind_meadow/crossgate_flora/cg_silverleaf.glb` |

The paint crops, native crown samples, anchors and per-leaf shading are recovered
by `tools/recover_crossgate_foliage.py` into `assets/maps/falan/flora/`.
Run it with `--check` to verify the exact original source recipe. Paint pixels
are mirrored at tile seams without resampling. Crown samples exclude the trunk
and baked ground shadow; their original width at each height supplies a 3D
volume. This is a solid interpretation of three original 2D tree families, not
an exact reconstruction of every original graphic or a whole-tree billboard.

Edit the saved Blender masters and export each through `tools/export_blender.py`.
Keep the scene's `export_active_vertex_colors` flag: the exporter otherwise
prunes the per-leaf shading from the textured material. Keep `Body` and `Canopy`
separate for the shared wind/cutaway path, the root at ground level and the
original triangle counts. `tools/prepare_crossgate_trees.py` is initial
preparation only and refuses to overwrite these saved masters.

`forest_wind_meadow_assets.gd::crossgate_tree` selects the family. The existing
batcher shares immutable geometry, source paint and wind materials, with local
spatial bounds. Falan garden and southern-road native obstacles retain their
existing owners and positions. User-placed trees keep their saved asset IDs.

After exports, refresh Godot imports, run `test_crossgate_flora.py`, the native
source check, asset audit/preservation checks and `falan_road_scenery_test.gd`
through Play Goemon with `-- --venoa-undersea`. Inspect the office, garden,
road and both cave approach views independently of technical test results.
Evidence belongs under `build/Other Files/Asset Toolkit/Falan Road Recovery/`.

Kili and Sokia Coast now select these same native families for their archived
tree graphics (2026-11-17). Their existing scenery owner retains source anchors
and collision; the shared batcher still owns geometry, paint and wind. No master
or GLB was re-exported. Evidence for the reused appearances is under
`build/Other Files/Asset Toolkit/Kili Village Recovery/`.

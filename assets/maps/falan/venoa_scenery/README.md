# 海洞 to 熊洞 scenery

The original reference is the adjacent Magic Power archive: Freyja `100.dat`,
熊洞 `11000/11001/11002/11022.dat`, cliff graphic 12543 and the original
13324–13359 cave rock family. Original art, maps, navigation, stairs and bear
slots remain with their existing owners. No Blender master or GLB was replaced.

`cliff_stone.png` and `cliff_moss.png` are native opaque crops of graphic 12543,
mirrored at their edges without resampling or repainting. Exact record, crop
bounds and source RGBA hash are in `provenance.json`. Keep mipmaps enabled in
their import settings. `cave_rock_atlas.png` derives two stone-face samples from
13355. Baked dark crevices are replaced by the nearest solid stone pixel from
the same crop, retaining only original colors; the new geometry supplies the
actual crevices and shading. The original cave atlas stays intact. Rebuild or
check from the complete source:

```sh
python3 tools/recover_venoa_scenery.py
python3 tools/recover_venoa_scenery.py --check
```

Editable procedural geometry remains in
`scripts/forest/forest_freyja_destination_art.gd`: `crag_cluster` assembles nine
of the existing ridge pieces inside each southern cliff footprint; `cave_crags`
fits three narrower stones behind each original cave boundary segment. The
original backing wall is recessed and capped, then shaded as a dark crevice.
Shallow ridge pieces soften pool edges. These are visual surfaces; the existing
collision, native navigation, ceiling headroom, doors and stairs remain intact.

`forest_falan_frontier.gd` changes southern tree presentation to the existing
Wind Meadow cedar/pine/broadleaf family at original anchors. Its native scenery
plan and obstacle bounds remain unchanged. Do not move the collision owner into
these visual recipes. `forest_stone.gdshader` reuses its existing rock/face
texture slots for the new stone/moss blend on owned southern materials only.
`habaru_ceiling.gdshader` applies the darker backing/roof and denser stone paint
only to the Venoa cave family. Other caves retain their existing materials.

All geometry is built at area setup and indexed without changing its shape.
Keep the single extra cave stone surface rather than a node per stone. Preserve
the unmodified source pixels, original wall-face atlas and reusable model masters.
The added crags and unseen rock faces are source-informed 3D interpretations.

Run `tests/forest-shrine/venoa_scenery_review.gd -- --venoa-undersea` through
Play Goemon for matched road, entrance and cave views, complete road clearance,
geometry clearance, all cave floors, native bears, boss and shortcut returns.
Evidence and source references are in
`build/Other Files/Asset Toolkit/Venoa Scenery Recovery/`.

Kili continuation (2026-11-17) reuses the unchanged stone/moss crops and
`crag_cluster` geometry for the same cliff graphics on Sokia's coastal approach,
including its undersea recess. Kili's existing source banks remain separate.
This changes visual surfaces only; the original coast collision, source cells
and mouth profile stay with their current owners. Review evidence is under
`build/Other Files/Asset Toolkit/Kili Village Recovery/`.

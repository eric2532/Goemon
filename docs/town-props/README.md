# Tidefall street prop kit

Nine original low-poly Blender assets extend the existing town. Existing town and character masters are untouched. Geometry is original; packed textures come from this repository's original Edo pixel texture kit. No downloaded or ripped character/prop meshes are used.

The kit includes a broad vermilion town gate, noodle and dumpling counters with striped awnings and hanging food emblems, a ribbed paper lantern, five-panel indigo noren, a bowl-emblem shop sign, a small closed wayside shrine, a stone lantern, and a slatted offering box. Abstract emblems intentionally avoid pretending to be readable Japanese text.

`asset-catalog.json` gives stable IDs, source/export/thumbnail paths, triangles, material counts, sizes and export checksums. `contact-sheet.jpg` is the review sheet. All masters are in `assets/blender/town_props`; GLBs are in `assets/models/town_props`. Each prop exports as one opaque mesh with nearest-filtered packed texture materials and roughness 1. No rigs, animation controllers, dynamic lights, transparency or particles are added.

`TownProps.add_to()` is called only by `TidefallTown`. The gate spans the northern street, two counters face the street in frontage margins, and the shrine arrangement occupies the quiet western side. Small signs, curtains and lanterns attach to existing shop fronts. Filled primitive collision hulls protect large props; tiny attached accessories use the existing building hull. All previous collision owners, height generation, map bounds, seeded RNG and other areas remain unchanged. The street-prop layout does not alter enemy or player statistics.

These are static environment meshes rather than crowd assets. Each material surface can add a draw call; the kit reuses only 23 prop instances and adds no per-frame script work. Counts alone are not a measured frame-rate claim. Scene instancing and GLB resource caching reuse imported mesh resources. More extensive prop density would warrant material atlasing or MultiMesh batching.

To rebuild from the procedural authoring design, run `blender --background --python tools/build_town_props.py`. The tool refuses to overwrite existing masters by default. For hand edits, open the saved `.blend` and use `tools/export_blender.py`; do not regenerate approved masters blindly. `--replace` explicitly authorizes a complete regeneration of this new kit only.

Verification: `godot --headless --path . --script tests/town-props/checks.gd` checks all nine exports are integrated, no skeleton/light/particle nodes, and 366 player-capsule samples along six main paths including the gate opening. Existing `tests/tidefall-town/checks.gd` checks the original collision/height/RNG baseline, building hulls, route/court clearances, navigation and camera probes.

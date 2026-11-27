# 傑諾瓦 → 魔法大學 route presentation

The locked route uses original maps 4000 → 400 → 14000 → 14001 → 14002 →
402 → 4400, ending at the main building exterior. The complete source IDs,
coordinates, original-file hashes, ordered checklist and labeled comparisons
are under `build/Other Files/Asset Toolkit/Jenova University Route/`.

`scenery.json` records native object anchors, native image hashes/bounds and
the visible corridor. `walls.json` records sixteen original stone/arch
contours and the two native hedge facings. These are prepared data, not new maps, collision or exit tables.
The primary source is the adjacent read-only BlueCrossgate client archive.
The linked footage identifies itself as version 2.0 of the original game;
version-specific artwork and lighting differences remain explicitly unverified.

`scripts/forest/forest_university_route_art.gd` supplies setup-time visual
overrides only inside that corridor. It reuses the editable Cross Gate flora
under `assets/models/environments/wind_meadow/crossgate_flora/`, the measured
Falan fort parts, the matching civic guild model, and the editable
`travel_stones/travel_stone_kit.glb`. The existing coastal/shore builders
supply banks, native water backing, solid wall extrusion and small scenery.
Tree UV/material variants are owned by this route; shared masters and
materials remain unchanged. Keep the guild's node hierarchy so the existing
source material frames remain valid. Native wind and canopy hiding are retained.
The Falan fort kit uses centered stations. Convert both its axes and the native
graphic-origin difference when placing it at a compound map-tile anchor; most
three-by-three pieces differ by 48 projected vertical pixels. The gate header
has its own origin and must not receive a blanket offset.

Reproduce from the complete source:

```sh
python3 tools/review_jenova_university_route.py plan
python3 tools/prepare_university_route_scenery.py
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tools/prepare_university_route_walls.gd
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/university_route_preservation_test.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/jenova_university_route_review.gd -- --stage=After
python3 tools/review_jenova_university_route.py compare After
python3 tools/review_jenova_university_route.py handoff
```

Use `--check` on each preparer to verify its derivatives. The initial
`--stage=Before` captures must predate edits; do not overwrite them to make
a comparison pass. `--area=01` through `--area=07` retakes only the selected
stages while retaining other records. All captures jump to fixed source
coordinates through the normal game scene and desktop launcher.

No section is certified visually 1:1. Map spacing/planes and links are
checked independently of fitted 3D shapes. Original height fields, unseen
cliff/tunnel/crown geometry, exact lighting and uncached surroundings remain
limited by the available references. The route review records those limits
per section. No new walkable elevation or collision was inferred from art.

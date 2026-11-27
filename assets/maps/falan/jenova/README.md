# 傑諾瓦 outdoor village art

The editable, authoritative mesh recipes are in
`scripts/forest/forest_jenova_village_art.gd`. They assemble existing town-kit
meshes and geometry helpers; no shared house model is overwritten. Only source
map 4000 uses these variants. Original map cells, collision, doors, travel links,
NPCs, interiors, water, distant cliff scenery and other maps remain owned by the
existing Explore systems.

The street benchmark is the green-roof shop viewed from source cell (46,56).
Its wall height, solid roof seam, human-scale openings, native red door and
entrance terrace set the scale/material standard. Each other source house keeps
its own recipe and identifying silhouette:

| Source graphic | Source anchor | Form |
| --- | --- | --- |
| 11400 | (39,60) | Orange bell hip, blue arched door, entrance-side porch |
| 11402 | (46,35) | Round two-storey landmark with separate windowed cupola |
| 11403 | (48,52) | Wider green roof, red door, terrace, casks and sign |
| 11404 | (59,44) | Rear hall and projecting round bay, open fenced courtyard |
| 11405 | (42,22) | Taller stone lower storey, balcony, roof brows, native signs/banners |

The original sprites in `assets/maps/original_crossgate/atlas-4.png`, their
catalogue footprints and the reconstructed original 4000 map are the visual and
placement references. See also the original town map at
https://cg.skyey.tw/map/ma10.htm and the project's chosen art atlas,
https://gameartstyle.loopyhop.com/ . Unseen rear faces are authored
interpretations, not recovered original views.

`tools/prepare_jenova_village_art.py` prepares owned native surface derivatives,
a carved face from 11314, original road masks, and an inward-fading reachable
scope. Original pixels and map data are hash-checked and preserved. The shader
`forest_jenova_ground.gdshader` paints continuous grass and pavers in map space,
using the native road silhouette; it fades back to the original surface before
unreachable ground. It does not add terrain or physics. The 2,874 reachable cells
are derived from the unchanged walk bits starting at (46,29).

Nearby existing walls, carved gate posts, well, signs and fences use local
prepared variants. Signs and carvings are painted details on solid meshes;
brows, roofs, windows, railings, cupola and well supports have actual depth.
The crescent monuments, existing trees and all original placement anchors stay
in place. Meshes/materials are cached once and use the existing MultiMesh chunks;
there are no per-frame art updates or new gameplay owners.

Rebuild textures with `python3 tools/prepare_jenova_village_art.py` and launch
through `/Users/eric/Desktop/Play Goemon.command`. Run the focused checks with
`--headless --script res://tests/forest-shrine/jenova_village_art_test.gd`.
The rendered review is `--script res://tests/forest-shrine/jenova_village_art_review.gd`.
It jumps directly to fixed gameplay cameras, every sector containing reachable
ground, and both sides of all five house types. Three final gameplay views reuse
the archived before-camera transforms exactly. It uses temporary preferences.
Reports and comparisons live under
`build/Other Files/Asset Toolkit/Jenova Village Art/`.

# Falan survival arena

The 2026-11-11 user request replaces the four-spawn valley with the arena inside
Cross Gate's city, in pure survival mode. This uses the recovered main hall of
Falan room **1401**, with its original floor tiles, red carpets, five colored
inlays, gallery fittings and stone walls. It is not a new circular stadium.

Standard and Large remain the only bundled presets, at the existing
`assets/maps/forest_wind_meadow.json` and `forest_wind_meadow_large.json` paths.
They retain `terrain_source: wind_meadow` for terrain/native compatibility and
use `terrain_detail: arena`. The old names are resource aliases. No shrine or
enemy castle objectives are created. Play Goemon retains its existing slime
mode: 29 appearances per side, 116 arrivals every ten seconds, and the same
928-unit cap and queued arrivals. No combat balance or army owner was changed.

`scripts/forest/forest_arena.gd` is the editable composition/terrain source.
It selects rows 90–149 of the archived 70×150 room, centers the main platform,
opens four broad approaches, and fills missing entrance tiles from the same
recovered floor atlas. The prepared index image uses the existing city-paving
shader path. The archived tile/inlay PNGs and `room_art_data.gd` remain intact.
`forest_falan_arena_art.gd` accepts a main-hall-only call; its original city
visits retain the default full-room behavior.

The floor is enlarged horizontally by 4× in Standard and 6× in Large. Its
platform rises and furnishings use 20% of that vertical scale so the existing
large slime footprint can cross the original stair approaches. The native
height field, physical floor and painted ground share those heights. Static
walls/fittings reuse the existing builders and box batches. Resources and the
height field are prepared at map setup; there is no per-frame room rebuild,
per-enemy terrain work, new renderer or new effect pool. Arena bounds clamp
players and exclude native arrivals outside the hall. The valley's lawn-only
expansion controls are hidden; choose Standard/Large in Map Editor instead.

The current enclosure follows the user's **fully open roof with very tall
walls** choice. `WALL_HEIGHT` in `forest_arena.gd` gives **160 m in Standard**
and **240 m in Large**. Continuous perimeter panels and four raised entrance
headers replace the separate ceiling and isolated pillars. There is no ceiling
mesh or overhead collider, so the sky and upward travel are genuinely open.

The facade uses the original room's ordinary wall and pier panels, sampled
from authored cells (8,91) and (9,94) in room 1401. `arena_wall.gdshader` samples
their plain stone middle at a fixed 12×9 m scale. Decorative panels occupy
12×36 m near the top, preserving the original 32×96 aspect instead of enlarging
them across the entire 160/240 m wall. Nearest mipmapped anisotropic filtering
keeps the recovered pixels crisp. Broad bays retain alternating original piers;
headers share the same mapping. The original atlas and city-room builders are unchanged.
Existing gold coping finishes the upper edge. The procedural sky and sun stay
open above the arena, with a brown lower background matching its palette.

The five colored emblems now sit on real raised stone plinths. `PAD_RISE=6`
adds 4.8 m in Standard and 7.2 m in Large. A chamfered square top supports each
original inlay; 16/24 m wide bevels keep the slope at 0.3 so native slimes and
the player can walk onto them. The original terrace height is retained below
each plinth. Physical mesh, native height field and painted terrain share this
geometry; the existing stone shader shades the sloping sides. Only the arena
composition lifts its owned inlay mesh. Original city visits and PNGs are intact.
No extra terrain vertices, per-unit objects or per-frame terrain work are added.

The colored patterns themselves now use an engraved mesh. Run
`python3 tools/prepare_arena_carvings.py '../Magic Power'` to recover finer
detail from original sprites 11799–11803 and regenerate the depth map. The
existing `build_falan_room_art.arena_inlay_detail` projector samples those native
292×217 sprites bicubically into `assets/maps/falan/arena_inlays_detail.png`
(five 256×256 patches); full room-art recovery also produces this derivative.
The original `arena_inlays.png` and city-room art remain untouched. After detail
recovery, `python3 tools/prepare_arena_carvings.py` reproduces
`arena_carving_depth.png` using that bundled detail atlas, without requiring the
external library. Local contrast isolates the shared pale crest, lettering and
rings. A 0.65-pixel bevel filter smooths the fine contours, peak normalization
keeps the deepest cuts, and the outer edges remain sealed.
`forest_arena.gd::carved_inlay_mesh` prepares one cached, indexed mesh containing
five 256×256 patches (327,680 vertices / 650,250 triangles). Its UVs align to the
finer recovered pixels. It recesses the strokes by up to 1.2/1.8 m in Standard/Large
(`CARVE_DEPTH=1.5`), with actual beveled normals and sun shadows. The owned inlay
material uses vertex depth for stronger cavity shading so the deeper cuts remain
legible in sunlight. The visible ground is cut away only beneath these
five patches so it cannot cover the recessed triangles. The existing physical
and native support plane stays smooth across this shallow decorative detail;
there are no new navigation holes, micro-colliders or per-enemy carving queries.
The mesh is shared across sizes and editor reloads; depth-image reads and mesh
creation happen once at setup. Original city inlays retain their flat treatment.

Twelve shared AABBs describe the walls and headers for physical collision,
both native teams and native projectile cover. The four entrance gaps stay
wide and open. The existing static-room cover metadata is preserved when the
editor reuses the world. Owned wall materials use the existing above-height
cutaway pattern so overhead views and floor selection remain clear; original
city materials keep their default visibility. Meshes, atlas material and
collision are prepared only at map setup, with no new per-frame owner or army
scan. The shared graphics warmup now uses the existing Cave Bear sprite mesh
for its newly added role instead of asking the rigid-soldier loader for it.

The finer carved-pattern version passes 163 headless and 163 rendered checks
across both sizes and the current 80-check survival/rebirth replay on Standard.
Inspect
`standard-carved-pattern.png`, `standard-platform-close.png`, `standard-open-sky.png` and
`large-open-sky.png` under `build/Other Files/Arena/`; the earlier
`*-ceiling.png` captures are historical. No app export was requested.

Arena slimes now approach at up to **3× their configured base speed** beyond
120 m from their current target. A smooth distance curve returns them to
**1× base speed inside 40 m** (9→3 m/s at the original defaults). The existing
native combat owner reads the already selected target; no extra army search,
per-slime controller or resource load is added. Slows and freezes still apply,
and locomotion follows actual distance. The internal kit flag is enabled only
for slime waves on this arena. Other enemies, allied pets and the recovered
city/cave encounters retain their original movement. Damage, contact timing,
counts, ten-second wave cadence and active cap are unchanged.

Existing user saves are never rewritten. The previous valley JSON layouts now
live only in `tests/forest-shrine/reference/maps/*_valley.json`; their castle
regressions load those explicit fixtures. Original Falan city/interior assets
and door links are unchanged.

Verify through Play Goemon: Play → Start, run across the central platform, and
watch slimes enter from north/east/south/west. The five emblems and carpets
should match the city arena, with no castle health meter or objectives. Try
Map Editor → Large, save/reload a custom copy, and return to Standard. Evidence
and focused captures are in `build/Other Files/Arena/`.

## Entrance wall infill — 2026-11-13

The four broad entrance openings previously exposed the empty exterior below
their headers. `forest_arena.gd::build_gate_bays` now finishes each opening with
a recessed stone bay, floor, soffit, solid backing and dark iron-banded doors.
Both arena sizes reuse the existing stone materials and static box batches;
there are no new textures or editable model masters. Materials are owned copies
so the shared city scenery keeps its original appearance. The bays follow the
existing overhead wall cutaway and leave the roof open.

All added geometry stays beyond the playable edge. It is decorative scenery:
the existing twelve wall/header collision and native cover boxes, arrival
locations, movement limits and four slime routes keep their existing behavior.
The bays are prepared once at map setup. Close views of each side and validation
logs live under `build/Other Files/Arena/Wall Infill/`. The regression checks
all four bays, solid coverage across each opening, placement outside the floor,
and the absence of new colliders, alongside the existing path/physics checks.
The fresh desktop run passes 189 assertions across Standard and Large; all eight
close views were visually inspected. Asset preservation, toolkit Python (81),
imported assets (12,973), outfits (98), recovered motion (25) and structures (86)
also pass. These checks do not establish full-army performance. No app export
or long-session performance test was requested or performed.

## Reused wall architecture — 2026-11-13

The tall enclosure now has full-height tapered stone piers, three projecting
cornice courses, and red-and-gold banners in arched recesses. The authoritative
pieces remain `forest_falan_courtyard.gd::buttress` and
`forest_falan_keep_exterior.gd::lancet` / `banner`; the arena assembles them in
`forest_arena.gd::wall_detail_meshes`. No new model, texture or Blender master
was authored. These existing recipes are prepared into two cached static meshes,
grouped by their original materials, and repeated through twenty MultiMeshes
(76 placements in either size). Arena-owned material copies retain the overhead
cutaway without altering the shared city materials.

The wall panels sit five scale units deeper in their existing solid envelope,
so the piers and cornices have real relief while staying outside the playable
floor. Stone corner returns close the recessed panels. The existing twelve
collision/native cover boxes and four entrance routes are retained. Previously
unpainted terrain at the wall feet now uses the existing castle stone surface;
only its visibility changed, retaining the exact physical/native heights.
Floor emblems, original atlases, saved maps and the open sky are preserved.

Evidence and close views of every side in both sizes live in
`build/Other Files/Arena/Wall Decoration/`. The arena regression checks shared
meshes, placement outside the floor, cutaway materials and native/physical
entrance clearance. No app export is needed to inspect this through Play Goemon.

Fresh validation passes 201 rendered arena assertions across both sizes, 81
toolkit Python tests, 12,973 imported-asset checks, 98 outfit checks, 25 recovered
motion checks and 86 structure checks. All eight wall close views and the overhead
cutaway were visually inspected. Asset preservation passes. This is an appearance
change, not a measured performance improvement; no full-army or long-session
performance comparison was run.

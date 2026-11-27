# Tina Explorer

## Current live village update — 2026-11-23

The user explicitly requested activating the redesigned houses after the
re-audit. `forest_original_maps.gd` now uses `forest_tina_village_art.gd` for
all six village building families, including the shifted nighttime mayor
house. J travel reaches these same meshes. Street fences, the carved pillar,
containers and plants have local player-scale variants. Ground keeps the
existing native atlas and path/snow layout. Approach assets, source placements,
collision, entrances, NPCs, interiors and other maps remain unchanged.

See `street_art/README.md` for the active editable builders and reproduction
commands. Current evidence is in `Tina Recovery/Live Village Update/` under
Asset Toolkit. Earlier sections below describe historical reconstructions;
their statements that the redesigned house proposal is inactive are superseded.


Tina NPC gameplay was removed at the user's request on 2026-11-23: no Tina
NPC actors, dialogue, shops, paid teaching, nurses, rentals, message boards,
quest inventory/effects or scripted battles run in the game. Separate Falan
citizen conversations and shared pet/Bodyguard abilities remain intact.

J opens direct region travel. Recovered linked areas and former NPC-gated
rooms remain enterable without NPCs, quests, fees or rewards. Village scenery,
building entrances, original map data, the 24-minute outdoor clock and roaming
night/road encounters retain their existing owners.

Original server tables remain under assets/references/crossgate_tina/events.
The previous implementation, prepared NPC data/art and historical tests are
retained as excluded reference under tests/forest-shrine/reference/tina_npcs.
Existing saved NPC metadata is preserved but inactive. Removed teaching-slot
assignments are kept in the same inactive preference namespace before being
omitted from the live pet loadout; ordinary assignments keep their slots.
Native codes 12–21 are rejected, and shared Bodyguard retains code 22.

Verification: tina_npc_removal_test.gd, tina_explorer_review.gd, existing
Falan conversation, day/night, roaming-enemy, pet and Bodyguard regressions.
Evidence belongs under Asset Toolkit's Tina Recovery/NPC Removal/. No app
export is part of this change.

## Outdoor reconstruction audit — 2026-11-23

The full-village comparison is under `build/Other Files/Asset Toolkit/Tina
Recovery/Full Village Audit/`. `review.md` records the section checklist,
reference coverage and remaining limits. The comparison uses the complete
100×100 preserved maps and original RGBA artwork, plus the published 2003 map
and recovered gate gameplay screenshots. It does not establish a 1:1 original
3D reconstruction. Day and night retain their original source planes, walking
bits, entrance cells and instance anchors.

Outdoor variants remain in the existing `forest_tina_scenery.gd` mesh cache
and the original map's spatial batches. Six building families use measured
native silhouette bounds from `building-fits.json`; shared models elsewhere
retain their existing fit. Silverleaf trees reuse the existing complete tree
meshes with original leaf/bark samples and source-camera proportions. Reed
and flower contours retain shallow depth. Interior plant scale is unchanged.
Fences reuse the existing connector shapes with local post/beam proportions.
White boats use the source's open three-post shelter and two roof slopes,
with support feet constrained to the hull deck. The shared boat builder's
default and other maps remain unchanged. Hidden depth is inferred.

`forest_tina_ground.gd` supplies outdoor-only floor filtering gutters and
source-painted shoreline caps, descending faces and water. Three simple depth
bands carry each shoreline painting; its small details remain in the texture.
A batched water backing closes exposed beach-edge gaps. This adds no collision,
map cells, entrances, gameplay owner or per-frame asset work. `ground.png`
preserves every originally opaque floor pixel; only filtering gutters extend
its edge colors. Originals remain in `assets/maps/original_crossgate/`.

Prepare from the current source, then capture through the desktop launcher:

```sh
python3 tools/prepare_tina_ground.py
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tools/prepare_tina_scenery.gd
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tools/prepare_tina_building_fit.gd
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/tina_full_village_test.gd
/Users/eric/Desktop/Play\ Goemon.command --rendering-method gl_compatibility --script res://tests/forest-shrine/tina_full_village_review.gd
python3 tools/review_tina_village.py
```

The review uses temporary preferences, direct scene travel and fixed source
coordinates. It captures every 25×25 section in both day/night layouts,
matched landmark views, a true overhead view and lower gameplay cameras.
Compatibility rendering was used for final evidence because Metal capture
stalled with a GPU fence timeout; normal launcher renderer settings are
unchanged. Headless checks do not establish gameplay smoothness or appearance.

## Reconstruction re-audit — 2026-11-23

The new full-area evidence is under `Tina Recovery/Reconstruction Reaudit/` in
Asset Toolkit. Read its `review.md` and per-section checklist before treating
any earlier completion report as an original match. All 15 nonempty 25×25
sections were compared in day and night. The audit separates complete static
map/art coverage, recorded client cells, server-filled cells and independent
original gameplay images. The newly inspected 2015 BlueCG rental-house images
show a conflicting variant; their extra houses/mailboxes were not silently
merged into the pinned static map.

The unfinished `forest_tina_village_art.gd` house proposal is no longer called
by the live map loader. Its source and textures remain preserved offline.
`forest_tina_scenery.gd` continues to own the cached native variants. Its local
green-house main roof now calibrates three eaves and its apex to the original
image; this supersedes the previous whole-mesh-bounds-only fit for that roof.
Native logs 11462/11463 now retain their own snow, bark and end paint on cached
geometry, with two source-view fits in `building-fits.json`. Shared log and
house meshes outside Tina are unchanged. Prepare the fit data with
`tools/prepare_tina_building_fit.gd`; never edit source art or baseline hashes
to accommodate a failing preservation check.

`tools/review_tina_village.py --out PATH` and the full review's
`-- --audit-out=res://PATH` keep fresh evidence separate from historical runs.
The independent coverage flood starts on open cell (42,55); it reports 4,903 /
4,933 connected cells and separately includes every open cell in the visual
review. Source-aligned views, actual runtime anchors and a true overhead are
all retained. The report lists inferred hidden geometry, rental-variant and
original-gameplay coverage gaps, original night grading, protected gameplay
objects and renderer/camera limits. These results do not establish a 1:1
reconstruction or a current Metal performance result. No app export occurred.

The refreshed normal player-camera shots expose an unresolved map/player scale
mismatch: large doors/fences, cropped roofs and occasional visual occlusion.
Source-aligned agreement does not prove correct player-scale appearance.
The re-audit report records the conflicting footprint/silhouette versus
protected player/collision calibration, plus low-resolution close-up paint.
Do not describe this pass as resolving those problems or as a 1:1 match.

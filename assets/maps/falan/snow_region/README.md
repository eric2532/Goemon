# 阿巴尼斯・傑諾瓦 snowy region

This pass uses our adjacent read-only `Magic Power` BlueCrossgate client archive,
the preserved native maps/graphics in `assets/maps/original_crossgate/`, and the
current complete Explore source. The original town maps are corroborated by
[阿巴尼斯](https://cg.skyey.tw/map/ma12.htm),
[傑諾瓦](https://cg.skyey.tw/map/ma10.htm), and
[莎蓮娜](https://cg.skyey.tw/map/ma003.htm).
The project's [Game Art Style atlas](https://gameartstyle.loopyhop.com/) informs
the painted finish; original Cross Gate cells and art determine placement.

The boundary and every reachable sector are recorded under
`build/Other Files/Asset Toolkit/Snow Region/BOUNDARY.md` and `boundary.json`.
It includes both full villages, all three Jenova approaches, the local southern
road and first snow, all three western cave floors, every connected clearing in
the existing 402 crop, the snowy university exterior, both current generated
mountain floors, and the summit/cabin exterior. No optional interiors or new
destinations are added.

`scripts/forest/forest_abanis_village_art.gd` is the editable source for six
snow-town house/shelter recipes. It reuses the established town-kit shell,
window, arched-door, rounded roof, cylinder, rod, oval, and railing builders.
The square house, projecting round bay, round turret, layered-roof red-door
shop, and open shelter retain separate identifying forms. Snow collects on
eaves, sills, railings, foundations and roof surfaces; doorway approaches are
kept clear. The same owned recipe is used for a matching house visible on the
snowfield, campus or summit. Original source artwork and other towns' variants
are preserved. Native layouts and doorway triggers are unchanged. Hidden sides
and human-scale structural detail are authored interpretations of 2D art.

The existing `forest_university_route_art.gd` scenery owner consumes
`scenery.json` as a region supplement. It retains original anchors and prepares
shared meshes once at area entry. Snowy trees retain coherent editable-master
UVs, local snow materials and fitted crowns; the one-view native sprite is no
longer wrapped separately across every leaf. Small flora and fences retain
their established sizes. Plant colour and snow coverage are measured from the
original graphic, avoiding magnified facade-like paint on small leaves.
Jenova retains its plaster/orange/green palette and source roads. Matching
Jenova houses in the outer map use the same local recipes.

`prepare_snow_region_art.py` produces all files here except this guide. It checks
original RGBA hashes before preparing filtered native floor tiles, palette data,
scope spans and a softened native cliff atlas. Eight-pixel tile gutters and
mipmaps prevent texture seams/shimmer; retain `mipmaps/generate=true` on both
PNG import settings. `surfaces.json` records source and prepared-pixel hashes.
These are presentation derivatives, never replacement source map planes.
Ground vertices, walk masks, collision, exits, NPCs and native gameplay remain
with their existing owners. Do not edit the generated PNG/JSON files directly.

Reproduce from the complete project:

```sh
python3 tools/review_snow_region.py
python3 tools/prepare_snow_region_art.py
python3 tools/prepare_snow_region_art.py --check
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/snow_region_art_test.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/snow_region_review.gd -- --after
python3 tools/review_snow_region.py --package
```

The archived `Before` predates this pass; do not regenerate it to make a
comparison pass. The review jumps directly between fixed gameplay views and
reachable sector cameras with isolated preferences and a fixed seed/noon.
It records camera transforms, native map bytes, walk masks and travel metadata.
Generated floors are shown at seed 341; this is not a proof of the unavailable
original random-floor order. Native source maps do not supply authoritative
walkable slopes, unseen cliff surfaces, roof backs or original third-person
views. Preserve the existing terrain/collision heights instead of inventing
playable elevation from the isometric art. No app export is part of this pass.


## Readability cleanup — 2026-11-24

The cleanup uses a fresh capture of the current source under
`build/Other Files/Asset Toolkit/Snow Region Cleanup/Before/`, reusing all
260 previous fixed camera positions. Preserve that baseline. The three requested
village/route comparisons and the complete eleven-map checklist are in that
folder's gallery and review report.

House windows now stay within their wall spans and clear entrances; porch-rail
gaps follow the door instead of a separate center. The narrow bay/main-wall
gap is closed beneath the existing roof join. Eave/foundation snow uses fewer
overlapping broad lobes, preserving the main shells, roof forms and landmarks.

Regional trees use coherent master UVs, restrained wind and smoother crown
lighting. The `calm_scenery` shader option defaults off outside this owner.
Source tree/prop anchors are retained. Bare-tree cleanup separates bark and snow
materials; missing fine twigs connect otherwise detached snow caps. Original
branches and snow-clump positions are retained and checked independently.
Snow drifts use a coherent locally owned snow material instead of wrapping a
whole sprite around their volume. Native ground/paving masks remain unchanged.
Jenova's prepared native floor pixels are lightly filtered with mipmaps enabled;
its boundary fade is retained to avoid hard lawn/native-material edges.

Reproduce the current review with:

```sh
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/snow_region_review.gd -- --cleanup --after
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/snow_region_art_test.gd -- --cleanup
python3 tools/review_snow_cleanup.py
```

`--floor=ID` retakes selected maps and retains the other records. The cleanup
verifier checks every camera, native map plane, walk mask and exit against its
fresh baseline. Original Maps differs only in choosing the cleaned sapling
presentation; collision, NPC, travel and generation owners remain unchanged.

## Population and material follow-up — 2026-11-24

`tools/prepare_snow_region_population.py` owns `population.json` and
`npc-atlas.png`. It checks the pinned original-reference records and recovers
42 reachable NPC/sign interactions at their exact source cells. Talk uses the
existing Explore NPC owner and dialogue presentation; ordinary residents retain
source messages, while event NPCs receive a short explicit placeholder. Existing
shops/quests and interiors are unchanged. Signs reuse their existing solid art.
The native single-view NPC graphics retain their source pixels and offsets;
recorded directions remain in the provenance, without inventing missing 3D views.

Four documented farm placements in source 4400 are blocked by absent walkable
terrain: 菜園介紹板 (38,147), 學生阿葛里 (38,159), 農夫葛德里夫 (44,166),
學生哈斯帕 (34,167). They are listed explicitly in `population.json.skipped`;
no NPC was moved and no path was invented. The invisible grave event at (36,30)
and later event/private-server objects are also listed with their reasons.
NPCs beyond the preceding pass's road/crop boundary remain out of scope.

The same preparer retains original encounter rectangles, priorities, group/member
weights, levels and maxima. The existing Waves owner checks walked source tiles,
draws shuffle bags, and releases one complete local group into the native army.
There are no new ambient patrols in this corridor, western caves, snowfield,
mountain or summit. The other branches of shared map 400 retain their existing
patrol data. Villages and campus remain safe. Cave appearances are 惡魔貓 and
胖蝙蝠; the summit also restores the documented one 冰之人魔草 plus three
變種液態史萊姆 formation. No new quest rewards or special quest scripting is added.

Exact original probability ramp/count distributions and the mapping from the
original random mountain dungeon to the current two adapted floors are not
available. Min/max probability and group maxima are preserved where provided;
Goemon uses uniform shuffled values within those bounds. Mountain weights/counts
and the 1–3% movement-check range are explicit adaptations, not a claim of an
original server simulation. The two existing zombie/hound identities and
39–42 levels are retained. Special summit spell/escape/reward scripting remains
unrecovered; its restored actors use compatible native combat.

`--pack` reuses `recover_habaru_encounter.py` to prepare the shared sprite bank at
`assets/characters/crossgate/snow_region/`. It preserves original frames, native
contact cues and WAV bytes; `snow_region_sprites.gd` is a data adapter for the
existing army renderer, not another simulation. Prepare it only at area setup.

The follow-up art changes are scoped to existing regional material owners:
broader low-contrast cliff paint, continuous earth paint that suppresses enlarged
tile dither, and solid snow-house roof undersides. The generated `earth-mask.png`
protects authored paving from the earth finish. Original geometry, source floor
bytes, collision, exits and scenery anchors remain unchanged.

Verification and the eleven-map art/enemy/NPC ledger are under
`build/Other Files/Asset Toolkit/Snow Region Restoration/`. Reproduce with:

```sh
python3 tools/prepare_snow_region_population.py
python3 tools/prepare_snow_region_art.py --check
python3 -m unittest discover -s tests/forest-shrine -p test_snow_region_population_source.py
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/snow_region_population_test.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/snow_region_population_test.gd -- --visual
```

## Current-baseline follow-up — 2026-11-24

The next review preserves the already-restored population and starts from fresh
current-source captures in `build/Other Files/Asset Toolkit/Snow Region Followup/`.
Its eleven-map ledger distinguishes new changes from retained baseline work.
All resident/sign checks now send the normal F key through the game input owner.
Do not overwrite this folder's `Before` or the earlier comparison baselines.

The existing regional `calm_scenery` foliage override uses smoother crown
lighting, broad restrained colour and softer snow contrast. Its default remains
off outside this region. The existing cliff material uses a softer native sample
and less source contrast in the rock paint. Tree geometry, fitted transforms,
trunks, batches, house forms, collision and editable masters remain unchanged.
Review the first-snow bend (212,349), Abanis pub street (64,66), snowfield trees,
western-cave rock faces and university exterior from the fixed gameplay cameras.

The existing encounter owner now tracks the current group's IDs and uses a
bounded native query for nearby combat when a movement check is due. A patrol
left alive on another branch of shared source map 400 can no longer disable
this corridor's encounters. The current group and nearby combat still prevent
extra encounters. Stationary frames do not issue the new proximity query.
Encounter distributions, safe villages/campus, source NPC placements and route
connections are retained. The farm, random-floor and original server-behavior
gaps above remain explicit blockers, not guessed replacements.

Reproduce this follow-up with:

```sh
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/snow_region_art_test.gd -- --cleanup
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/snow_region_population_test.gd -- --visual '--review-root=res://build/Other Files/Asset Toolkit/Snow Region Followup/'
python3 tools/review_snow_region_followup.py
```

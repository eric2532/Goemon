# Recovered western exploration route

Open **Play Goemon → Falan**, choose a Cross Gate character and enter the map.
Walk out of Falan West Gate and follow the western road to the original
莎蓮娜海底洞窟 entrance. The existing exploration continues through the three
undersea floors, 莎蓮娜, 傑諾瓦/蒂娜, the three western cave floors and the
阿巴尼斯/魔法大學 snowfield. Snow Mountain, its summit/cabin and the sixty
詛咒的迷宮 floors use the same travel, player and native army systems.
There is no separate map browser or camera mode.

The road to 阿巴尼斯 crosses **莎蓮娜西方洞窟**, not a direct town transfer:
source 400 (235,338) → 14000 (8,41), then 1F (45,9) → 2F
(14,68), 2F (57,13) → 3F (30,44), and 3F (36,7) → snowfield
402 (258,180). The village entrance is 402 (182–184,161). All three
cave floors retain their complete client map planes; the walking corridor
through both road sections is covered by recorded client cells. The obsolete
southern-map town transfer stays excluded.

Native cliff graphics 12839 and 12834 now use open 3D entrance forms instead
of closed generic ridges. Their rim faces retain the original stone/snow paint;
separate tunnel walls, a floor and a recessed dark end leave the mouth visibly
open. `forest_original_cave_entrance.gd` reuses the shared coastal mesh and
painted-face builders, cached and instanced by the existing scenery owner.
Tunnel depth and hidden rock are reconstructed, not original 3D data.
`abanis_road_recovery_test.gd` follows the normal on-foot connections in both
directions and checks native navigation and normal-camera captures;
`test_abanis_road_source.py` independently checks the read-only client bytes,
recorded corridor cells and pinned original warp coordinates. Evidence lives
under `build/Other Files/Asset Toolkit/Abanis Road Recovery/`.

The cliff refinement replaces 120 generic ridge types used along that road
and inside the western cave with source-measured rounded lofts. The preparer
reads each native upper contour and silhouette, keeps the original footprint
and shared height units, and prepares shallow rock relief once. Repeated
placements still share cached meshes in the existing spatial MultiMeshes.
Each closed cliff mesh stays at or below 224 triangles. Native moss stairs
13270/13271 now use the existing ascending/descending stair geometry; the
descending stair retains its floor opening.

`tools/prepare_abanis_cliffs.py` owns `cliff-profiles.json` and `cliff-paint.png`.
Run it after changing source art, or use `--check` to verify the derivatives.
Whole native paintings replace small repeated stone samples on the visible
faces. Native image columns are rectified around the loft, so turning the normal
camera does not project a curved side onto one stretched pixel column.
Border-only flat shadow/transparent areas reuse compatible native
rock and snow texture patches, with mirrored edges and the existing stone
tone preparation; enclosed dark crevices and painted source RGB are retained.
The original RGBA atlases stay untouched. The entrance rims are rounded solid
bands with original rim paint and original dark interior paint, rather than
bright repeated stone inside the opening. Hidden rock, tunnel depth and the
conversion of one isometric view into volume remain inferred. Normal-camera
and source checks for this pass are under `Abanis Road Recovery/Cliff Refinement/`.

The catalog preserves the available client snapshots; current per-region counts
and verified source image comparisons are in the recovery report under
`build/Other Files/Asset Toolkit/Original Isometric Maps/recovery.json`.
`catalog.json` retains the complete original three map planes, dimensions,
file SHA-256, native graphic serial, origin, compound footprint, palette and
RGBA hash. Lossless atlases retain graphics at their native sizes.
The client files in the adjacent Magic Power archive are read only.
Separate solid/surface atlases extend native edge paint and extract stone tiles
for reconstructed faces; the original RGBA atlases remain unchanged.

The runtime keeps source coordinates at three metres per tile. The selected
western travel corridor of map 400 uses source bounds (110,240,510,240); map
402 uses (35,70,250,140). These windows include the linked towns and branches;
the complete uncropped source maps remain in the catalog. Campus, village,
interiors, summit and maze floors retain their full source bounds. Walk masks
use the existing original graphic-attribute/compound-footprint recovery.

Scenery is solid 3D: native floor cells, masonry, roofs, rounded houses,
cliffs, stairs and furnishings reuse the established source-paint projector
and compatible shared mesh builders. Native 10604 uses the recovered guild
facade; 10640–10654 reuse the existing castle pieces. The previous generic
building blocks have been replaced by the native curved hipped roofs, round
porches, open stalls and stable bays. Doors, windows, timber, roof colours and
snow paint use the rectified original crops in `building-surfaces.*`. Native tree placements use the existing
editable Cross Gate flora models. Source footprints/placements are retained;
heights and unseen faces are reconstructed from 2D artwork. The client does
not contain original 3D meshes, so this is not a claim of exact recovered 3D
geometry. Review the rendered scenery separately from data fidelity checks.

Courtyard parapets and bridge arches, interior capitals/columns, channel banks,
snow-covered crates/logs/tubs, snowmen, boulders, drifts, bare branches, stumps,
conifer/leafy shrubs, ferns, grass, ice formations and cave crags
now have dedicated solid forms. Household fixtures reuse the coastal, inn,
cellar, civic and palace builders and their separate material parts. Laboratory
display benches, glass cabinets, drawer units and the cabin stove use matching
solid forms. Fixture artwork is not stretched across shelves and contents.
Hanging decorations retain their elevated anchors. Height fitting removes the
isometric ground span and accounts for small props' visible widths. Gargoyles and bone
heaps use the existing sculpting primitives. Transparent client markers are
excluded from rendering. Channel bank axes are sampled from the original art.
Walkable shore caps remain at ground level, with rock faces descending to the
lower water plane. Bank depth follows the native sprite's extra vertical span;
it is an interpretation of the source, not original height-map data.

Fixed stairs and entrances use the pinned `linv2/Crossgate_Docker` reference
`dd8690ed3df11e4eb5a038a54079a8f40d8e93b3`, whose hash is stored in the catalog.
Reference endpoints are checked against the client layout. Outdated gates
outside the recovered land are excluded; a gate on a wall uses its adjacent
walkable approach. Tina's return endpoints supply the missing reverse edges.
The existing blade/guardian progression remains; NPC recovery is deferred.

The cursed maze preserves all sixty fixed client maps, including separate
chambers that require stairs through previous floors. Do not carve shortcuts
between these original chambers or assume every arrival can walk straight to
the next numbered floor. `maze_encounters.gd` is generated by
`tools/recover_cursed_maze_encounters.py` from the pinned encounter tables and
NPC index recorded in `maze-encounters.json`. It restores all ten ordinary
species, their six level bands, the seven named guardians, and source seal
positions (including 40F at 15,18 and 50F at 22,14). The first five guardians
reuse original 101934 white/green art; the Twin Kings retain 101932 red and
101933 gold art. Missing mini-gargoyle/baby-bomb frames use the existing cave
recovery pipeline under `assets/characters/crossgate/cursed_maze/`.

Each stair-connected chamber prepares local patrol placements once from the
unchanged source walking mask; tiny stair vestibules stay clear. Regular
sections use their two species, and 51–59F uses all ten. The first five boss
groups have a guardian plus four/five matching attendants; 60F has the two
kings. Stable boss death slots 7/8 retain prior run progress. Native combat,
death handling, art batches and seals keep their existing owners. Those
real-time placements/formations and combat balance are adaptations; the
pinned CGMSV reference is not verified BlueCG server data. NPC conversations
and exact original server AI are not recovered.

Snow Mountain generates connected layouts from the existing room/graph
builder. Shape choices, snow tiles and tree variants use shuffled bags. Saved
seeds replay the layout. The 408 cache snapshots are reference instances, not
a floor limit or a deck of gameplay layouts. The original server generation
probabilities and random-floor order are unavailable.

Geometry is prepared when entering an area. Floors are batched by atlas page;
repeated props share one mesh per native serial and use 48-metre spatial
MultiMesh batches, retaining their original cell anchors.
Trees use the existing spatial batches. The university's native 10609 blue-roofed
halls reuse `forest_falan_houses.gd`; snowy banks reuse the existing
`forest_frostpass_art.gd` builders. The recovery forms are maintained in
`forest_original_map_solids.gd`; the authoritative procedural source for the
additional furniture, signs, remains, displays, gates and stair forms is
`scripts/forest/forest_original_map_details.gd`. It assembles existing shared
parts before fitting them to each native graphic. The earlier 158-map review identified 1,665 object graphics. This classification is
coverage evidence, not proof that every reconstructed shape is visually exact.
Printed signs retain their original letters on extruded boards with solid
poles; the wide maze passage arch retains its three-cell span. Descending
stairs and pits cut their source footprint out of the floor and snow backing.
The 2026-11-21 source review separates broken snowy planks from stumps, flat
log decks from stacked firewood, open water troughs from tubs, and snowy benches
from troughs. The snowman has the original two-ball body, face and raised
mitten. Display 16278 is a tea service, 16277 is a card table and 17632 is an
armor stand. Upright pianos retain their two opposite source facings; 17506
uses a curved grand-piano body rather than an oval table form.

These refined forms preserve their authored horizontal proportions and fit
their projected horizontal extent and, except for the round snowman, highest
point to the original image. Snowballs retain their authored round volumes.
Vertical fitting reuses the existing native paint projector's scale. This fits the selected
profiles without forcing them to fill their rectangular collision footprints.
It does not reconstruct the exact outline or unseen depth. The fitting pass
deindexes input surfaces before joining and indexes the final material groups,
so raw profile triangles and indexed primitives retain all their faces.
Transient detail models bake box placements on the CPU before being fitted;
placed world scenery still uses the existing shared mesh/spatial batches.
Recovered areas supply source-aligned routing spacing and complete flat native
height fields to the existing army; other maps keep their original routing
spacing. No per-frame recovery or new army simulation was added. Keep native maps, atlas pages and source hashes intact.

## Verification

```sh
python3 tools/recover_original_crossgate_maps.py --check
python3 tools/recover_western_building_surfaces.py --check
python3 tools/recover_cursed_maze_encounters.py --check
python3 tests/forest-shrine/test_cursed_maze_source.py
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/original_maps_test.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/original_maps_test.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/original_maps_test.gd -- --completeness
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/original_map_assets_test.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/cursed_maze_recovery_test.gd
python3 tools/goemon_assets.py audit assets/maps/original_crossgate
python3 tools/goemon_assets.py check
```

Use `-- --data-only` for route/data checks, `-- --towns-only` for the four
recovered towns, or `-- --caves` for the secondary
caves/interiors. `-- --details-only` visits eleven exterior/interior areas and
checks shared detail geometry, transparent markers, channel axes and bank depth.
`-- --completeness` captures twelve representative rooms in the normal follow
camera and an elevated inspection camera; ceilings are hidden only for the
inspection capture. `original_map_assets_test.gd` builds all 158 fixed rooms
and two generated snow rooms, checks every object family, shared meshes,
source placements and floor openings. Run it with the desktop renderer to
verify actual MultiMesh transforms: Godot's headless Dummy renderer discards
instance-transform readback. Results are under `Shalena Recovery/Completeness/`.
Use `-- --refinement` for the nine-area source-detail review. Its current
source/solid comparisons, gameplay captures and verification logs are under
`Shalena Recovery/Source Refinement/`.
The old adapted Frostpass fixture is archived in the excluded
`tests/forest-shrine/reference/` directory. `frostpass_route_test.gd` now runs
the recovered route fixture. Logs/captures for the current 3D integration are
under `build/Other Files/Asset Toolkit/Shalena Recovery/`. Earlier isometric
browser captures are superseded evidence and do not describe current gameplay.
No app export or legacy character sweep is required for this change.


## 傑諾瓦 and the 神獸 route — 2026-11-21

The sea-cave exit and all three Jenova town gates retain their source cells.
All thirteen cached town/interior maps are reachable through the fixed warp
network. Shalena's playable bounds now include the castle at (135,333).
The six original castle rooms are 16510–16515: 入口, 靜謐之間 before and
after the beast, 咒縛之帳, and the two side rooms. Reference event transfers
retain the priest approach (26,67)→(26,65), the beast (26,25)→16512 (26,26),
the two side-room routes, and the return stone (14,6)→Shalena (136,336).
The stone is on a blocked pedestal; its walk-in interaction is at (14,8).
NPC conversations, job requirements and quest items remain deferred.

Jenova's 11400/11404/11405 buildings now use native roof paint on curved solid
shells, native facade pixels, raised entrance frames, steps and dormers through
`forest_jenova_building_details.gd` and the shared town builders. The house facade
crops exclude its foreground porch; the porch stays separate geometry. Generic
crossbars no longer cut through the original doors and windows. Existing town
anchors, footprints, floor cells, collisions and warp ownership are unchanged.
The shared Tina builder supplies the green-roof house and circular building.
The circular house and foreground bay fold only their hidden quadrants into the
native visible hemisphere, avoiding transparent-edge stretching in rear views.
The bay house's exposed left wall uses its own unobscured plaster/window strip;
the client does not supply the hidden portion behind the bay.
`tools/prepare_tina_roof_underlay.py --serial 11404` reconstructs only the roof
paint hidden behind the foreground bay, using the same building's visible paint;
its provenance is beside the derivative under `assets/maps/falan/tina/buildings/`.
The original graphic remains intact. Rear surfaces mirror the visible native
faces because the client supplies no rear views; these inferred depths and
hidden surfaces do not establish an exact 3D original. Normal gameplay-camera
captures use `jenova_beast_recovery_test.gd -- --jenova-only --normal-camera`.

The next normal-camera refinement excludes roof skirts from the house/pub wall
crops and fits the house and bay-house wall/roof proportions separately. The bay
fills its original footprint more closely. Native window and shutter outlines
now have solid depth; the house porch sits only along its entrance wall, with a
painted platform and supports. The pub has a raised balcony, separate cloth
banners with brackets and solid native-painted signs instead of the generic
duplicated plaque placements. The bay-house courtyard reuses the matching
`forest_tina_building_details.gd::bay_porch` fence, with Jenova's native timber
paint and the original-facing rail orientation. Its main hall is inset so the
courtyard stays open to the original ground; the generic full-footprint wooden
deck is removed. The bay position and offset roof peak follow the original
visible composition. These stay inside the existing cached mesh and
MultiMesh owner, using shared town geometry/materials, with no new runtime loop.
The original source graphics remain authoritative and unchanged. Camera review
now covers both close and approach views for all five building types, keeping
normal pitch, distance, FOV and camera collision. New evidence is under
`build/Other Files/Asset Toolkit/Jenova Beast Recovery/Normal Camera Refinement/`.

The town's 11393 well now reuses the native source-point and curved-surface
builders for an open stone basin, layered round shingle roof and three leaning
supports, replacing its generic gabled placeholder. It remains in the same
original-map mesh cache and source placement. Roof paint uses the existing
opaque solid atlas so the sprite's transparent outline cannot cut holes through
the solid roof. `recover_western_building_surfaces.py` also prepares
`jenova-well-stone.png/.json`: only timber that occluded the stone is infilled
from adjacent source paint. The original graphic and its alpha remain preserved;
the newly exposed paint is reconstructed, not an original unseen view.
The reference-camera reconstruction is converted to the existing gameplay
scenery height scale at the mesh boundary; the original ground anchors remain
unchanged. The roof also has a closed timber underside for street-level views.

The 11403 green-roof shop now has solid source-painted porch carvings, two
reused cask forms, an open pail and raised shutter/window outlines. Its railing
stays on the entrance side; generic crossbars no longer cross its windows.
The 11402 circular building has raised curved timber bands. Editable detail
geometry lives in `forest_jenova_building_details.gd`, sharing the original
town builders and materials. Review captures now include the well and all five
town building types from close, approach and side views with the normal game
camera; evidence is under `Jenova Beast Recovery/Town Props Refinement/`.

`catalog.json` keeps the untouched client bytes in `raw` with their original
SHA-256. Separate `restored_raw` data fills only unrecorded cells in Jenova,
Shalena and the castle using the pinned matching map reference. Every recorded
cell remains authoritative, including BlueCG's 24 Shalena and 13 town variations.
Each completion records its reference hash, compared-cell count and exceptions.
The reference is a corroborated reconstruction of uncached cells, not recovered
BlueCG server data. Other regions' raw caches remain unchanged.

`forest_beast_maps.gd` selects twelve distinct, intact client layouts from a
shuffle bag of 33 connected snapshots with the reference's 1191 floor, 17065
walls and 12000/12002 stairs. It never carves or rotates the snapshots. Cache
numbers do not establish floor order; another dungeon shares this palette,
so an individual cache's original dungeon membership is not proven.

The dungeon configuration points to encounter entry 16000, whose three groups
supply 大炸彈 and 大地翼龍. The level range is 35–37. Source row 260065 supplies
the level-50 神獸史雷普尼爾 appearance 101032. These identities and reference
hashes are recorded in `beast_encounters` in the catalog. All enemies, stable
death slots and the boss seal reuse the native army and current travel owner.
Real-time posts and combat scheduling are adaptations of the turn-based source.

The castle's original 70 floor fragments and upper graphic 10011 are preserved
as a verified 544×621 image. Its editable solid model is
`scripts/forest/forest_beast_castle.gd`; native stone, blue roof, banner and
window surfaces are prepared by `tools/recover_original_crossgate_maps.py`.
The detail pass adds the native stepped blue buttress bands, carved panels,
layered cornices, tower bands, keep frieze and clipped keep corners. The upper
keep uses measured native roof corners, with the two round turrets alongside
it. Entrance sculptures use winged robed figures; the side piers have four
curved claw ornaments. Their hidden shapes remain inferred. All seventy
foundation cells come directly from the source floor plane.
It reuses the shared native-paint mesh builder and arch geometry. Source cells,
entrance and scenery anchors are retained; the inferred depth and rear faces
are a 3D interpretation, not an original client mesh. Interior columns, mounted
statues reuse the existing builders. Passage pieces 10045/10046 and
16468/16467 now retain their exact source cells and alpha-derived carved
outlines, extruded through the shared polygon builder rather than replaced by
a generic semicircular arch. Their 1.5 m depth is inferred. Reliquary 17102
has an open upper railing. Armor 16193/16196 uses the original curled crests,
closed visors, overlapping plates, gauntlets, boots and lance silhouettes.
Room-wall caps exclude
the source's black hidden faces. Loot also checks the recovered walking mask,
preventing chests from appearing beyond these rooms.

`tools/recover_beast_sculptures.py` preserves all RGB bytes from native armor
16193–16196. Only the flat ground-shadow alpha is removed from the runtime
paint; `beast-sculptures-native.png` also preserves those original pixels.
The shared `forest_beast_sculptures.gd` prepares closed crest and gauntlet
relief, a round lance and a smoothed solid suit constrained by all four source silhouettes. The
body selects the matching archived facing in the shared scenery shader.
Front views 16193/16194 and rear views 16195/16196 retain their respective
quarter-turns. The solid owns the torso, helmet, limbs and boots; a flat torso
relief must not cover it when viewed from the normal game camera. Small boot
flecks are excluded from the separate shaft. Crest and grip depth are fitted
to the adjacent helmet/forearm voxels along the source viewing ray, preserving
their native image coordinates. The lance and gripping hand share that depth.
The shaft uses one continuous round primitive measured from its native line
and width, painted from that original shaft. Pixel-by-pixel shaft relief is
excluded from the separate relief. This
avoids doubled, beaded poles during camera orbit. Crest and gauntlet relief stay
in place.
Native views have different lance poses, so the selected lance and crest stay
with their own sculpture. These are inferred 3D meshes, not recovered original
models. Both original-map placement and palace furnishing reuse this owner;
fitted furnishings compose their paint transform rather than moving texture
coordinates. Meshes and immutable source textures are cached at setup.

The castle uses solid architecture and fitted original paint instead of
projecting the whole illustration over its walls. `beast-castle-carvings.gd`
and its atlas/depth/proof files are prepared by `recover_beast_sculptures.py`
from individual native faces. The existing Falan carving builder supplies
raised stone relief; its meshes are cached by the castle and merged into the
same static owner. Gothic window frames, ribs, cornices, curved buttress caps,
claws and four sides of the arched parapet have real geometry. Turrets use
stone and separate windows, without repeating window pictures over the shaft.
Wall and carving materials use private lit copies; other scenery retains its existing paint.
The sculptural stone shares the existing fort material with the pale tone
sampled from the original carving; it is not covered in the wall's brick grain.
Stone grain may repeat, while carved faces, brown plinths and cap artwork fit
their own pieces. The full source illustration and its original bytes remain
preserved. The depth mask is retained as a reproducible geometry regression
artifact; the castle's walls no longer use that projection at runtime.
The entrance canopy is a separate solid loft through the traced native eave,
blue slope and stone cornice corners in `CASTLE_CANOPY`. Its own full-resolution
UVs replace the old oversized roof and stacked blocks. Layer heights remain
inferred from the doorway; the source pixels do not establish hidden depth.
`CASTLE_HALL` similarly records the upper roof structure. Its supporting hall
has solid walls, fitted native carving relief and physical window surrounds.
The keep's raised blue base, clipped outline and stone ring remain solid.
The front arch uses the source jambs (344/442), aperture (373/402), and crown
near (388,422), rather than the old oversized slot. The arch and recessed leaf
now share the measured doorway footing at (387.5,512); the crown is about 9.02
game units above it. The two turned columns use their own source footings
(365,527)/(410,497), with 78 source pixels between base and capital. Their
profile is solid and their paint comes from the separate original column
strips in `beast-castle-columns.png`, so door paint cannot stretch across them.
The recessed door reuses paint unwarped from the original door leaf.
The two cloth banners use separate source-corner placements on the actual
front wings, with their coordinates and atlas tiles in `CASTLE_BANNERS`.
The restoration mask's red/blue channels retain the original silhouette;
green retains the earlier banner/column exclusions for regression comparisons.
Each unwarped banner belongs to its own wall-mounted quad, clear of the
projecting stone bands. Entrance tower positions follow those recovered cloth
coordinates, and geometry checks confirm there is solid stone behind them.
The shared shader's optional restoration features default off for other scenery.
Before regenerating the castle depth mask after a geometry change, run
`jenova_beast_recovery_test.gd -- --visibility-geometry --painterly-preview`
through the project Godot executable, then run the sculpture preparer and
refresh imports. The mask records the actual mesh hash; data checks reject
a stale mask. `--details-review --sculptures-only` captures isolated native
and rotated views; `--late-sculptures` starts Falan before loading the castle
and both armor poses, exercising real exploration placement and caches.
Add `--normal-camera` to that exploration check to capture the actual shared
player camera at its default 12-unit distance setting and .22 rig pitch, with
its normal Cross Gate framing, collision checks and field of view. It also
checks ordinary orbit angles. It does not hide ceilings or move the camera
to the reference-art angle. `normal-camera-captures.json` records the actual
camera state alongside the screenshots.
When changing a castle recipe, run the preparer once to update its generated
coordinates before exporting the visibility geometry, then prepare again and
refresh imports so the depth proof matches the new placements.
Use `python3 tools/recover_beast_sculptures.py --check` for reproducibility.
The archive supplies 2D artwork, so hidden geometry and all-angle 1:1 fidelity
remain unverified; matching source pixels alone is not visual approval.

Jenova's five house graphics use their own recovered facades, brown timber,
windows, doors, banners and signs in `building-surfaces.*`. The compound
ground span is removed once when fitting their native roof heights. The
round house has a separate dome, raised windowed cupola, base and steps;
square houses retain their hipped silhouettes and finials. Four crescent
monuments use four successive quarter turns. Full 3D silhouettes, sculpture,
unseen faces and roof depth still require visual interpretation; these
changes do not establish pixel-identical scenery from every camera angle.

The older coastal regression incorrectly expected two teleport exits from
Alyut. Its checks now physically walk both seamless North Coast gates in
both directions, preserving the world, camera and native army handles. The
shared walk helper is also used by `connected_villages_test.gd`.

Reproduce the source checks with `python3 tools/recover_original_crossgate_maps.py
--check` and `python3 tests/forest-shrine/test_jenova_beast_source.py`. Traverse
with `Play Goemon.command --script res://tests/forest-shrine/jenova_beast_recovery_test.gd`.
Screenshots and logs are under `build/Other Files/Asset Toolkit/Jenova Beast Recovery/`.

## Tina and the shared Explorer clock — 2026-11-21

Explorer now has one 24-minute day/night cycle: one real minute advances one
in-game hour. Dawn and dusk change the existing sun, ambient light, fog and
procedural sky gradually. Exposure adjustments also dim the native emissive
sprite/atlas artwork; the HUD retains its normal brightness. The minimap shows
the shared time. The clock advances during active exploration, pauses with
menus/dialogue, survives all area travel, and uses the existing atomic settings
writer every minute and when returning to the title or closing the game.
This is the requested local cycle, not a recovered BlueCG server clock.

All outdoor Explorer regions use the same clock, including Falan, Freyja,
coastal villages, Sokia and the western/snowy areas. Enclosed interiors and
caves retain their established lighting while time continues. Arena mode
keeps its established lighting. `forest_explorer_clock.gd` owns only time and
lighting; it does not add actor simulation, targeting, material creation or
asset decoding to combat. Ordinary lighting updates reuse the current scene.

Tina's original daytime/nighttime maps (4200/4201) and taverns (4208/4230)
change at 06:00/18:00. Normal door travel chooses the current phase. Full
100×100 village bounds now restore 5,703 daytime and 5,874 nighttime cells
absent from the client snapshots, using the pinned, overlap-checked layout
reference. All recorded BlueCG cells and the three native daytime sign
variations remain unchanged. Both native road approaches join the existing
Shalena route; the previously missing food shop has its recorded return
entrances. Reference-only layouts 4206/4232 are labelled explicitly. No
entrance is invented for the unproven night teleport room. See
`assets/references/crossgate_tina/README.md` and its hash manifest.

Solid village scenery uses the existing per-serial meshes and spatial
MultiMeshes. Wooden wall/trim paint, the tavern's red door/window/sign crops,
and thin snowy eaves replace the inherited white trim on Tina's building
families. Original images remain intact. The food shop reuses the shared
produce, basket, shelf and spinning-wheel forms. These are prepared 3D
reconstructions, not exact recovered 3D models. The NPC/quest extension below adds
recoverable gameplay; full BlueCG server parity remains unverified.

Focused checks and rendered captures are under
`build/Other Files/Asset Toolkit/Tina Recovery/`. Run:

```sh
python3 tests/forest-shrine/test_tina_source.py
python3 tools/recover_original_crossgate_maps.py --check
python3 tools/recover_western_building_surfaces.py --check
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/tina_day_night_test.gd
```

The source test verifies every recorded client cell, each filled cell, the
unchanged third plane, all sixteen map-reference hashes and the two explicitly
reference-only rooms. The runtime fixture checks phase boundaries, midnight,
pause, travel, saved time, source doors, native movement, outdoor lighting,
indoor/cave/arena restoration and repeated resource use. Review screenshots
separately from those contracts. No export, multiplayer clock synchronization
verification, long session or full-army timing benchmark is included.

## Tina NPCs and enterable quest areas — 2026-11-21

`tools/recover_tina_explorer.py` recovers 66 source NPC records, 40 bounded event
scripts, 86 message entries and 36 original sprite appearances. The pinned
server files and their Git/SHA-256 proofs are preserved under
`assets/references/crossgate_tina/events/`; they corroborate the client, rather
than establish BlueCG server parity. Original text, cells, facing and source
anchors are retained. Housing signs already in the map are not duplicated.

F uses the shared conversation UI; Space reveals/continues and left/right plus
Enter selects choices. J opens quest items, equips shackles/headband and offers
local travel to Tina, 亞斯提亞, 往山的礦路 and 四方記憶. These explicit local access
shortcuts implement the user's request to enter missing areas; they are not
claimed as original server route links. Existing source doors remain walk-in.

Pirate prison dialogue, shackle escape, disguise/wine/note exchanges, ivory
traps, timed captain-room access and wizard reward-room transfer run from the
retained instructions. The crystal quest includes the source letter/map/ten
crystals/guardian/document exchanges and sister's seed return. Mine patrols
and all four original flower encounter members use the existing native army,
shared atlas renderer, pooling, combat and audio. Quest inventory/progress
saves through the existing atomic preferences writer. No server code runs.

Missing scenery in maps 32181/32183/32193/32194 uses existing floor/wall assets.
Catalog `artwork_approximation`, `unavailable_graphics` and per-graphic
`fallback_serial` expose substitutions; raw/restored map planes remain intact.
32193/32194 are explicitly reference-only layouts. The absent pirate encounter
69087 uses one exact captain appearance with an existing real-time boss profile.
Real-time shackle wear and guaranteed one-crystal drops are local adaptations.
The remaining services are implemented in the service pass below. Six original
shop item IDs are still absent from the supplied item table; local metal stock
is explicitly recorded as an adaptation.
NPC portraits use original sprite art in the shared dialogue frame, pending
approved painted portraits. Unseen building faces/depth are reconstructions.

Run `python3 tools/recover_tina_explorer.py --check`,
`python3 tests/forest-shrine/test_tina_source.py` and
`Play Goemon.command --script res://tests/forest-shrine/tina_npcs_quests_test.gd`.
Recover the prepared five creature appearances with `--flowers`. The native
`tina_cues_test.cpp` checks tagged contact/audio support, damage and rejection
of unknown cues; historical non-tagged cave cues retain their behavior.
Evidence belongs under `build/Other Files/Asset Toolkit/Tina Recovery/`.

Latest desktop area review loaded Tina, 32181 and 32193 and captured the J
travel menu with coherent floor surfaces; inferred walls/hidden building faces
remain visibly reconstructed. Both default Metal review runs reported GPU
fence timeouts, so rendered captures are visual evidence rather than a clean
performance pass. Keep those diagnostics in the review logs.

## Tina services and closer 3D scenery — 2026-11-21

The two nurses offer free HP recovery and MP restoration priced by missing MP;
the senior nurse can clear existing status ailments. The traveling merchant
now has paged buy/sell menus, source 150%/80% rate arguments, ownership/stock
validation, capacity checks and atomic transaction rollback on save failure.
Its six unavailable original stock definitions are not invented: local stock
uses preserved metal items 9600–9605, with their source names/prices.

All seven pirate-route teachers teach/forget their exact source skills and
charge the skill table's 5,000/10,000 Gold fees once. Learned skills appear in
J → 已學技能. The local real-time adaptation costs 20 MP: matching elemental
player spells gain 20% for 20 seconds; physical/magical wards negate one
matching hit during 20 seconds; attribute reversal changes the active prayer
to its opposing element. Effects expire, respect magic seal and never affect
Arena combat or copied/AI fighters. These are single-rank Explorer adaptations,
not recovered server turn durations, complete elemental affinities or job rules.
The pet shop continues using the existing shared pet loadout service.

The original board supports Unicode text entry, ten saved local posts and
confirmed clearing. It is explicitly labelled 本機留言 and posts nothing online.
Housing notices are interactive without drawing duplicate source signs. One
rental at a time costs the source mini-house fee of 500 Gold for 14 real days,
with renewal capped at 70 days. All three original notice/door locations are
retained. House interiors reuse the hash-verified original apartment template
1850; 4803/4805/4808 are source lease identities, not recovered unique interiors.
A walk-out exit returns to the appropriate original village cell. Rental,
messages, skills and items use the existing atomic preferences file.

Explorer travel now retains Gold along with the existing runner progression.
A small-room respawn check first verifies the actual AStar region, preventing
out-of-bounds grid queries in the apartment. Existing source maps and saved
user maps are unchanged.

Tina's six building families use the native footprint-based height correction,
source-specific rectified facades, blue/red doors and windows, original wood,
larger roof-paint repeat scale, four-sided pointed roofs, a rounded front bay,
a low blue cupola and an unwarped source roof/snow panel on the open shelter. The existing solid
mesh builders and per-serial spatial batches remain authoritative. Original
images and raw placement planes remain untouched; inferred depth/rear faces
and fine curved profiles remain reconstructions. The editable source is
`forest_original_map_solids.gd` plus the crop recipes in
`tools/recover_western_building_surfaces.py`. New tile names are scoped to Tina.

Verify services through `Play Goemon.command --script
res://tests/forest-shrine/tina_services_test.gd`; the existing quest fixture
still covers the pirate/crystal branches. Compare all six buildings front/back
with `tina_buildings_review.gd`. Logs and captures are under
`build/Other Files/Asset Toolkit/Tina Recovery/`.

Final source comparison adds a per-building vertical presentation fit for these six Tina
families at the original isometric viewing angle, keeping footprints and
placement anchors unchanged. The shelter roof is one rectified native panel,
so its snow is no longer repeated across generic thatch. The second blue
house also uses its own two source facade crops. The front/back review
passes outward-face and finite-geometry checks without script errors or Metal
timeouts; the comparison still shows inferred fine shapes and rear faces.

## Tina roof, door and small-detail pass — 2026-11-21

The six native families (11407/11409/11410/11414/11416/11451) now separate
full-resolution original RGBA paint from the reusable tiled structural parts.
`forest_tina_building_details.gd` supplies gently curved roof shells, the round
bay/cupola, original painted facade UVs, raised arch frames and window gables,
solid stone steps, hinges, porch rail openings and a source-painted flowerbed
rim. The shelter uses its original full roof/snow panel. Hardware, snow edges,
window panes and signs retain native pixels rather than repeating small crops.
Roof surfaces use the original RGBA pages; RGB edge-filled pages introduce
colored streaks outside their silhouette and are unsuitable for these UVs.

The green house's foreground bay and finial obscure the main roof in the only
original view. `tools/prepare_tina_roof_underlay.py` makes one documented
same-plane paint continuation behind them; the bay itself still uses untouched
source pixels. This explicitly reconstructed underlay is reproducible with
`--check`; see `assets/maps/falan/tina/buildings/README.md`. All six meshes are
cached with the original source anchors/footprints and existing spatial batches.
No collision, entrance, NPC, quest, day/night or raw map data changed in this pass.
Unseen faces and depth remain inferred, and the original reference-view
height/width ratio does not establish exact 3D recovery.

The focused building review checks native facade-coordinate inversion, trim
orientation, original RGBA texture identity/UV bounds, finite geometry, source
proportions and outward roof faces. Before/after/source comparisons and fresh
logs belong under `build/Other Files/Asset Toolkit/Tina Recovery/Roof Door Detail/`.

Final review passed 21,116 checks and captures all six front/rear views. Round
roof UVs mirror the two visible source faces onto the back, avoiding empty sky,
stretched walls and alpha gaps seen in the initial rear-view comparison. The
Explorer desktop day/night walkthrough passed 197 checks. No script errors or
Metal timeouts appeared in those final runs; cached-resource/RID shutdown
warnings remain. Source/provenance checks and the 319-GLB audit also passed.

## Tina approach, shelters and small scenery — 2026-11-21

Green-roofed approach house 11403 now uses its own full-resolution roof and
facades, raised door arch/gable and an open porch entrance. Storage shelters
11450/11451 have source-painted end walls/contents, sloped post heights, ridge
slats and icicles; prepared wood shelter 11452 has its own snowy roof/hanging
hides over solid logs. All use the existing source placement and mesh cache;
preparing additional catalog variants does not extend the current road crop.

The fourteen timber-fence connector shapes and matching snowy shapes now keep
their original branch/stub directions. Loose logs 11462/11463 form five-log flat
rows with closed cut ends. Crates 11467/11468/11469 use native top/side paint and
raised corners instead of one projected image stretched around a generic box.
Original source planes, collision, routes, NPCs, quests, saves and the shared
24-minute day/night cycle are unchanged. The recipe now prepares 51 native
paint patches; tiny log/fence paint is tone-smoothed like existing modular
building crops. Hidden depth and mirrored backs remain inferred.

Editable paths, reproduction and the focused 16-piece review are documented
in `assets/maps/falan/tina/buildings/README.md`. Evidence lives under
`Tina Recovery/Remaining Details/` in the Asset Toolkit folder.

## Tina boats and signs — 2026-11-22

The original boats now use source-image landmarks rather than being fitted
into a one-cell anchor. Both have long solid hulls, colored rails, masts,
furled cloth, rigging and mooring poles. The white cargo boat retains its
cabin/net/two horizontal barrels; the red/blue open boat has benches and one
upright barrel. Decks clear the existing water plane, fixing visible flicker.

Five Tina-area signs now use explicit board regions/facings and their actual
native-alpha contours. Corrected vertical calibration prevents oval labels
and tree branches from flattening into slivers. Original lettering remains on
the front; solid wood backs and source-painted leaves work from behind. Leaf
masks exclude board pixels so no sign fragment appears in the foliage.
Original source art, placements, collision, quests, saves and day/night timing
remain intact. The western paint recipe reproduces 57 native crops. Hidden
faces and depth remain inferred. Editable sources and commands are in
`assets/maps/falan/tina/buildings/README.md`; evidence is in `Tina Recovery/Boats Signs/`.

## Tina ruined walls and street props — 2026-11-22

Native ruined walls 11333–11347 now use source contours and calibrated front
paint with closed stone backs/ends and snowy coping. Small contour steps are
smoothed and side UVs preserve two-dimensional texture area. Shared profile
extrusion closes either polygon winding. Barrel sources 10017/10032/10033 retain
one/three/seven solid casks with original lids and colored staves. Source 10055 is
an open plank box; its explicit dispatch fixes the broad tree-range collision.
The western paint recipe now reproduces 65 patches. Original art, native map
planes/placements and gameplay ownership remain intact; unseen depth is inferred.
See the Tina building guide and `Tina Recovery/Street Props/` evidence.

## Tina night encounters and Shalena wildlife — 2026-11-22

The original night village (4201) and road sources 400/402 now populate the
existing native world-patrol path. The pinned tables supply 56 encounter zones,
sixteen original appearances, weighted memberships and level ranges. Day Tina
stays peaceful; the roads have wildlife at both phases. Wild patrols replenish
through the existing bounded owner away from the player. Positions/counts and
combat scaling are adaptations of the original random battles. Source records,
reproduction and runtime ownership are documented in the Shalena enemy guide.

Timber troughs 11482/11483 now use rounded, open channels with native wood paint. The reusable catalog
also has the source laundry tub/washboard and handled water pail; these two
placements lie outside the current southern-road crop. The western paint recipe
now prepares 69 patches. Source map bytes, scenery anchors, collision, NPCs,
quests and the 24-minute shared clock remain intact. See Tina's building guide
and `Tina Recovery/Night Encounters/` for visual evidence and verification.

## Tina winter detail follow-up — 2026-11-22

Five source graphics now use the cached winter builder: 11460/11461 retain
rectangular log rows, cut ends, supports and upper snow; 11465 has its raised
mitten arm and native-facing red eyes/mouth; 11484/11485 are low charred campfires
instead of sharp rock heaps. The reusable timber helper preserves old defaults.
The new material is isolated from shared archive paint. Original art and map
planes/anchors, collision, NPCs, quests, enemies and the world clock are preserved.
The western atlas recipe now reproduces 75 crops. See Tina's building guide and
`Tina Recovery/Winter Details/` for reproduction and source/before/after evidence.

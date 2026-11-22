# Falan City and Castle test areas

The current main-city building surface repair is documented in
[`Falan painted architecture`](../../blender/environments/wind_meadow/falan/START_HERE.md).
All 40 archetypes / 89 placements use coherent building parts and separate
facade, slate and detail materials. Whole-building isometric picture projection
is retired for these houses and civic assemblies. Original archives, reference
pictures, source positions, native room links and saved-map records remain intact.

The recovered outdoor regions now use their matching reference wild creatures:
Freyja's goblin variants, mice, bees, plants, northern cold trees and birdmen;
Sokia's mice/demons, mantises, cacti, scorpions, bandits and coastal creatures.
Great Wind Cave contains red-eye mantises and water spiders. All four recovered
sea-cave passage floors now share the existing water-lizard/lizard-warrior owner.
Existing named encounters remain under their original owners. See
[`falan_encounters/README.md`](../../characters/crossgate/falan_encounters/README.md)
for source provenance, regeneration, adapted population rules and focused tests.

Choose **Freyja and Falan** on the Play Goemon title screen, select a fighter,
then choose **Explore** to start in Falan City near the employment office.
The **Freyja and Falan - Test** save contains the city, castle, and all three
crossings. Walk through any gate arch to travel between the approach and the
city. Press **F** at castle and building entrances. Original NPC sprites stay
in place without dialogue. Defeat occurs when the player dies.

The original Frostpass branch leaves the Western Lakes road at the signed
cave mouth and bypasses the mining dungeon. Its three connected floors have
level 36–44 patrols, followed by Snowpine Village, Ridgewatch, and 阿巴尼斯村.
Abanis has timber houses with snow-covered porches, an enterable hospital
by the village entrance, a village hall on the west side of the paved street
loop, and a
southwest exit to the rising snow trail and both procedurally generated 雪山
floors. Its northwest gate opens onto the walkable snowy 莎蓮娜 coast road.
Follow the lamps to 魔法大學. The courtyard has separate doors for the study hall,
workshop (技術室), glasshouse (溫室), and auditorium (禮堂). Each interior returns
to its own door. The auditorium uses the courtyard bench module around a new
lectern stage.
The courtyard paths run between raised beds and the fountain. The study hall
and auditorium each have a stair to the outdoor roof garden. The stone wells sit
behind the roof entrances, with flower beds to the west and rows of ribbed
melons and trailing vines to the east. Abanis reuses Falan's bench and supply
props beside the streets, and the same wall lanterns on its timber porches.
The [campus gathering guide](https://molibaike.cn/index/mission/757.html)
describes both stair approaches and the rooftop melon garden.
The road shares the Frostpass paving, snowy foliage, stone arch and lamp
modules. The original 3D layouts take their setting and route relationship from the
[Abanis](https://cg.skyey.tw/map/ma12.htm) and
[Magic University](https://cg.skyey.tw/map/ma13.htm) guides.

The archived BlueCrossgate maps `map/0/4310.dat` (醫院) and `map/0/4313.dat`
(村長之家) in the adjacent Magic Power project informed the Abanis interiors. The hospital
uses blue-grey board walls, a honey-colored floor, a U-shaped dispensary and
reused Falan ward beds. The hall is furnished as the village chief's home,
with golden timber, a dining table, a parlor stove, beds and a small cloth display.
[Abanis cloth seller](https://cg.skyey.tw/made/01/06.htm)

The workshop follows the archived `map/0/4411.dat` 技術室, using cream walls, dark
planks, lit masonry forges and a weapon rack. The glasshouse adapts the
university's cultivation grounds from map `4400`. Each of its two plots has
four straight soil furrows and low timber rails along the outer and back edges.
The original growing plots are visible in the campus map. [Archived map data](https://github.com/linv2/Crossgate_Docker/blob/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/data/map/04400_daigakuimo)
The four rooms use the existing Frostpass fixture grid and shared Falan furniture,
pottery, stone and prop builders. [University gathering and crafting guide](https://cg.skyey.tw/errand/macd02.htm)

Each snow floor has 18 zombie and 18 hellhound patrols at levels 39–42.
The roster follows the reported
[積雪的山路 encounters](https://cgsword.com/bm/osfh3-%E7%A9%8D%E9%9B%AA%E7%9A%84%E5%B1%B1%E8%B7%AF)
and uses the library's 喪屍 and 地獄妖犬 sprites and native attack timelines.
The snow patrols favor nearby targets with lower or higher current HP,
respectively. Both can guard, and 地獄妖犬 uses a slower, stronger 諸刃 bite
that exposes it to more damage during the attack. The companion atlas uses
喪屍's prepared eight-way guard and the hound's planted brace. 諸刃 plays the
first lunge and the authored landing over the existing native attack window.
Each gate and passage works in both directions. Cleared
patrols stay defeated for the rest of the adventure run.

Glacier Cavern and Ice Vault each generate their own wider chambers, corridors,
ice islands, and patrol posts from the adventure seed. Returning to a floor
uses that same seed. Start a new adventure for a new layout. The frosted passage
uses fixed landings at both ends. The map chart, navigation, scenery and
patrols all read the same generated floor.

Each generated floor has groves of snow-laden broadleaf trees along wide
paths and rock shoulders. The groves reuse the Wind Meadow
`crossgate_flora/cg_woodland.glb` and
`cg_silverleaf.glb` models. Ground-level trunks sit along the verges of
wide walkable areas and use the same obstacle list as the cavern walls.
Seeded saplings cluster around mature trees, with exposed roots in the
snow at their feet. The generated wall edges set
the powder depth on the floor and place rounded drifts at the foot of the
rock. Ice patches remain visible around the crystals. Shallow blue treads
mark the existing passage landings, inspired by the blue stairs in the
original snowy woodland. [積雪的山路 playthrough](https://www.mobile01.com/topicdetail.php?f=284&t=6440427)

Frostpass layouts and door positions live in
[`forest_frostpass.gd`](../../../scripts/forest/forest_frostpass.gd). Its 3D builder
[`forest_frostpass_art.gd`](../../../scripts/forest/forest_frostpass_art.gd)
shares cave wall profiles along all walkable edges. It reuses the Freyja ridge
mesh builder, Falan lamps, roof profile helper, and the existing
`crossgate_flora/cg_evergreen.glb` foliage. Recessed passages attach to the
existing door coordinates. The mountain trail's snow mesh and solid collision
sample the same authored grade as native movement. A compacted snow tread
follows the switchbacks, with snow-dusted groves in the lower slopes and a pair
of amber waymarkers at the cave mouth. The amber color recalls the original
entrance crystal. [積雪的山路 route reference](https://guide.rubycg.org/quests/side/abanis/%E7%A9%8D%E9%9B%AA%E7%9A%84%E5%B1%B1%E8%B7%AF/)
Its layered cliffs, snow shelves, and icicle rim use setup-time meshes. Glacier Cavern and Ice
Vault use cyan and violet crystal fans fitted inside the rock islands. Each
cluster has a short-range light that also anchors the sheen on the floor.
Their floor meshes follow the open cells and use world-space fracture patterns.
Ice shelves project from the glazed rock walls with frosted lips and hanging
icicles. Both sides of the passage between
floors share a recessed ice arch, beveled molding, caged lanterns, and a low
stone threshold with staggered joints. Two stone bands and a recessed light
define the inside of the passage, with frost over the staggered beveled masonry.
Snowpine's market and
Ridgewatch's hall reuse Falan crates, barrels, and benches within their existing building lots. Walk up to
the main market or hall door to visit its interior. Their furnishings use the
same floor grid for movement and charts. In `forest_frostpass_interiors.gd`,
the market counter and hall seating share a trestle mesh builder. The rooms
reuse Falan's lantern, ledger, cabinet, and pottery builders for the mounted
lamps and tabletop pieces. Path and canopy shader variants apply frost only
in the snow towns. Run
`Play Goemon.command --script res://tests/forest-shrine/frostpass_route_test.gd`
to verify the route and capture the current scenery. The room overviews and
close-ups are written to `build/Other Files/Asset Toolkit/Frostpass/Snow Mountain Woodland/`.

**聖詔 · 詛咒的迷宮**

In 阿巴尼斯村, enter the historian's house and go down to the time stone.
Walk up to the blade fragment in the past cellar, then return to the village
and take the west gate. The pulsing stone disc on the snowy road opens the
maze while the fragment is held during the current adventure.

The maze has sixty playable floors, with passages generated from the
adventure seed and floor number. Revisiting a floor preserves its layout
and patrol posts. The six existing guardian arenas, bosses, and doors
stay on 10F, 20F, 30F, 40F, 50F, and 60F. Guarded stairs
open when their guardian falls. The final seal needs both kings defeated and
returns the player to Abanis. Returning to any floor preserves defeated
enemies for the adventure. The route uses the existing native creature
runtime and prepared Cross Gate sprites. [Original quest route](https://www.ibluecg.com/task/?id=3-13)

`forest_holy_decree.gd` defines the walk masks, landings, and encounter posts.
`forest_holy_decree_art.gd` assembles the stage scenery from shared Frostpass
stone passages and lights, Falan furniture, and snowy trees. The Frostpass
desktop route fixture checks the fragment, all sixty landings, the original
guardian masks, both kings, and the return to Abanis.
`holy_decree_corridors.gd` generates connected rooms and stores scenery
counts interpreted from the recovered floor maps in Magic Power. Corridor
references use `BlueCrossgate/map/0/24009.dat` through `24067.dat`; the six
guardian references use `24069.dat` through `24074.dat`. Reused flagstones,
square pavers, Falan statuary and Falken chamber meshes keep the look
consistent. The 50F dais is red and the Twin Kings keep their low bone piles,
gold statues and upright seal.
The archive renders and desktop comparisons are under
`build/Other Files/Asset Toolkit/Frostpass/Cursed Maze/Sixty Floors/`.

- The approaches use the matching Falan street coordinates:
  West `(x - 141, z + 240)`, East `(-135 - x, -225 - z)`, and
  South `(168 + z, 3 - x)`. The pavement,
  buildings and trees inside each arch come from the city. The overlapping
  streets let the player walk across the area boundary in either direction.
  The gates use the archive's outdoor landings at Freyja (374,195),
  (475,196), and (424,259) for West, East, and South respectively. Each
  crossing turns the camera and character along the destination road.
- East Gate, South Gate and their Freyja roads use the source map's ground
  graphics through `freyja_ground_index.png` and `freyja_ground_atlas.png`.
  The shared ground and water shader include maps each 3D point back to the
  original tile, including the isometric tile orientation. The 3D lighting,
  foliage and water movement remain part of the current art style.
  The first areas draw the archived rivers without adding ocean around
  the region boundaries. Original riverbank rocks use the shared cliff mesh.
  The Il river bridge retains the original single arch, four pillars and
  grass deck. Its support overlaps the adjoining terrain while the river
  passes beneath it. The terrain and native army keep the same deck height.
  Rebuild the two texture files with
  `python3 tools/build_freyja_surface.py '../Magic Power' assets/maps/falan`.
- The countryside roads lead from the bridges to farmsteads, groves and ruins.
  The East and South trail follows the land route in Freyja's `100.dat`, with
  both sides using the same tile coordinates at the crossing. The West
  approach retains its separate waterways and the causeway through the marsh.
  West/South retain single arrivals; East Gate releases packs of three and
  stays beyond the safe gate approach. Freyja water supports the player at the visible surface,
  including the city pond. Walking into a river keeps the player there.
  Native enemy navigation retains the original water barriers.
  Regenerate the approach surfaces with `python3 tools/build_falan_approaches.py`
  with the Magic Power project next to this one, or pass its path as the first argument.
- The woodland from the **East Gate toward Il Village** retains the source tree
  families for Freyja tiles `(472–577,137–257)` and the Il road corridor
  `(530–711,215–366)`. `east_gate_scenery_data.gd` records 651 tree identities
  and 192 small flower, grass and rock anchors in map 100's source coordinates.
  Both sides of the river use the existing region transforms for matching
  placements and orientations. The first pass's 229 tree identities and 48
  detail anchors are preserved. `tools/build_falan_approaches.py::build_east_scenery` regenerates this
  data, also as part of the normal approach rebuild. `forest_falan_frontier.gd`
  reuses the existing Wind Meadow cedar, cloud pine, broadleaf, tall grass,
  ivory/coral flower and mossy boulder meshes; no new model master is needed.
  The tree change is visual only: existing positions, trunk obstacles, native
  navigation, original ground tiles and saved scenery are preserved. Small
  details use original anchors and skip water, roads, doors and solid scenery.
  Ambient scatter follows both regions' road masks so bushes and rocks leave
  the beginner route, river crossing and Il approach clear.
  These checks and batches run at map setup, with no new per-frame controller.
  Run `tests/forest-shrine/east_gate_scenery_test.gd` through Play Goemon with
  `-- --east-il-road`; matched before/after captures and logs are under
  `build/Other Files/BlueCG Map Study/East Gate Beginner Area/`.
  `east_gate_il_scenery_test.gd` uses the same flag to replay the East Gate,
  woodcutter house and Il gate round trips, check the extended scenery, and
  physically walk across the original single-arch river bridge and region seam.
  Its matched captures and logs are under `BlueCG Map Study/East Gate to Il/`.
  The November 12 continuation passes the rendered and headless Il route
  replays and the rendered beginner regression. The current save builds 67
  small details on the East Gate side and 156 on the coast side; these regions
  overlap. Rendered checks find no ambient scenery centered on their road masks.
  Regeneration is byte-identical and retains every first-pass source anchor.
  These passes do not add quests or change the beginner encounters.
  The shared bridge water-mask builder now copies its image before repainting
  the riverbed; headless textures can return the imported source image itself.
  This keeps bridge-water preparation from changing subsequent road queries.
- The signed roads continue into Western Lakes, East Coast, North Coast and
  Southern Lakes. These regions load from the same adventure save. They
  preserve Freyja's 3 m tile scale, traced roads and waterways, and reuse the
  Wind Meadow foliage at recovered tree anchors. Short dry connectors join
  gaps in the original dirt tiles. The outer coast route joins East Coast to
  North Coast, while Western Lakes remains a separate branch.
- Signed branches lead to the fixed village, cave, mine, and house entrances
  in the Freyja warp reference. Village gates and cave thresholds open on foot.
  The four village exteriors and the first rooms of the smaller
  destinations use their cached maps and shared Goemon scenery. Additional
  dungeon floors, village interiors, and quest events are separate work.
- The woodcutter's house connects on foot to the Northern Mountain Path and
  Tomato Farm. `tools/build_freyja_tomato_farm.py` traces the published Blue CG
  Day 5 map and places the well and both storehouse entrances at the documented
  cells. The farm perimeter and storehouse interior are reconstructions.
- Habaru's hidden room uses archived map `11028.dat` and sits directly beneath
  the chamber. After defeating 熊弟, walk onto the ladder at the foot of his
  bed. Approach the same ladder from below to climb back up. `tools/build_falan_room_art.py`
  records the original wall and furniture anchors. The 3D timberwork in
  `forest_falan_room_art.gd` reuses the room's batch and the cellar's crate model.
  The basement roof sits below the chamber floor and has a single ladder opening.

- City terrain comes from Magic Power's `BlueCrossgate/map/0/1000.dat`.
  Castle terrain comes from `BlueCrossgate/map/0/1500.dat`.
- The castle exterior uses the keep footprint encoded in map 1500's ground
  layer and the silhouette of graphic 10012. All seven 10013 annexes, the
  curtain walls, distinct square and round towers, four bridge approaches,
  and the courtyard fixtures use the archive placements. The carpeted
  palace stair has its own ramp at the original door. The island uses the
  original paving, with water extending beyond the edge of the archive.
  The live map labels the palace and cellar. The rear faces and vertical
  heights are fitted 3D interpretations of the isometric graphics.
  Rebuild the source placements with
  `python3 tools/build_falan_courtyard.py '../Magic Power' assets/maps/falan`.
- The masks rotate the source grids into world X/Z at 3 m per source tile.
  City uses `(3 * (y - 134), 3 * (153 - x))`. Castle uses
  `(3 * (y - 56), 3 * (41 - x))`. Red marks water 5000–5008.
  Blue marks paving. Alpha records the recovered ground extent.
- Falan's city pavement uses `city_paving_atlas.png` and
  `city_paving_index.png` to preserve the original streets, curbs, plazas,
  and medallions on the same 3 m grid. `city_street_data.gd` locates
  the new 3D street furniture at the source anchors. The city checks
  furniture against door markers, NPC positions, and saved scenery.
  Exposed flat building footprints use nearby lawn or courtyard stone.
  Rebuild these assets with `tools/build_falan_city_streets.py`, passing
  the Magic Power project path and `assets/maps/falan` as the output.
- `forest_falan_fortifications.gd` uses the same source anchors for the city
  curtain walls, bastions, gate lintels, and canal masonry. Eight raised
  bridge sections keep the original road surface above the water. The city
  replaces exact matches for the old fort props at load time, including
  when reading the earlier combined save. The three exterior links stay open.
- The city garden plan uses the original tree, clipped hedge, iron fence,
  statue and ornament anchors. Fence and hedge connections follow neighboring
  archive pieces. The scenery plan keeps the original routes and door markers
  clear and supplies both the meshes and fitted obstacles. The six original
  lily-water tiles also mark the park pond in `city_surface.png`.
  `forest_falan_gardens.gd` reuses Wind Meadow trees and shrubs and the cellar's
  crescent ornaments. `forest_falan_garden_statues.gd` is the editable source
  for the park's new lion, standing figures and mounted statue.
- Market displays, casks, carts, wares and low timber fences use the object
  anchors in `city_street_data.gd`. `forest_falan_market_goods.gd` builds the
  editable 3D fixtures and checks clearance around doorways and NPCs.
  `forest_falan_shopfronts.gd` fits timber portals, trade emblems and roof
  palettes to the existing shop shells by matching their original room doors.
- The cathedral and the two hospitals use the archive's city footprints and
  original door links. `forest_falan_civic_exterior.gd` authors the stained
  glass, buttresses, towers and shared hospital shell. The nave's 37 pew
  sections, two altar screens and other furnishings use the original room
  object anchors. The hospital interiors retain their tiled wards, 12 beds
  and three privacy curtains. `forest_falan_civic_rooms.gd` is the editable
  source for the new fixtures.
- The arena uses the original city plot and room IDs 1400–1404 and 1420–1424.
  `forest_falan_arena_art.gd` supplies the oval arcade, lobby fittings, stone
  platforms, garden courts, and the side-room signboards. The five ring
  colors are projected from the original arena graphics into
  `arena_inlays.png`. The main and side rings have an F passage between them.
  The standalone survival arena uses `arena_inlays_detail.png`, recovered
  bicubically from the original 292×217 sprites into five 256×256 patches.
  `python3 tools/prepare_arena_carvings.py '../Magic Power'` refreshes this detail
  atlas and `arena_carving_depth.png`; omit the argument to rebuild depth from
  the bundled detail pixels alone. The old city atlas is unchanged.
  Its shared engraved mesh is prepared by `forest_arena.gd::carved_inlay_mesh`;
  original city inlays and archived color pixels remain intact. Composition,
  dimensions and collision rules are documented in `docs/wind-meadow/falan-arena.md`.
  The three annex rooms that lack archived return doors have F markers back
  to their corridor so the tour works with NPC dialogue disabled.
- The scenery layouts in
  [city](../../../tests/forest-shrine/reference/maps/forest_falan_city.json)
  and [castle](../../../tests/forest-shrine/reference/maps/forest_falan_castle.json)
  place 3D buildings and trees on Goemon's 6 m scenery grid. The castle
  courtyard also uses the original 3 m anchors in `castle_courtyard_data.gd`
  for its battlements, annexes, moat parapets, hedges, lamps, and garden
  furniture. `castle_courtyard_paving.png` reprojects the original pale
  plazas, dark roads, garden tiles, and inlaid medallion onto the terrain.
  Rebuild those courtyard assets with `tools/build_falan_courtyard.py`,
  passing the Magic Power project path and `assets/maps/falan` as the output.
  Some object families and individual furnishings remain simplified.
- `npc_atlas.png` contains the original static art pixels from Magic Power's
  `godot/assets/exploration/npc-*.png` without resampling. Each atlas rectangle
  was compared byte for byte in RGBA against its source. The 373 placements
  in `npc_data.gd` retain the exterior or interior map ID from Magic Power's
  `npcs.json`. These are community-reference coordinates. All 373 placements
  now support F conversations through the existing Explorer NPC owner. See the
  appearance-based dialogue notes below.
- `interior_data.gd` contains 96 room and floor masks at 3 m per source tile.
  The 97th recovered area is the separately authored castle test. Walls and
  collision follow Magic Power's navigation grids. The 3D floor meshes use
  `room_floor_atlas.png`, reprojected from the original diamond tiles. The
  original wall sprites are projected onto vertical faces in
  `room_wall_atlas.png`, retaining window, paneling, and column patterns.
  `room_art_data.gd` preserves those tile choices and uses the archived prop
  IDs and anchors for 3D furniture variants. Furnishings use Goemon
  materials and stay outside walkable cells. Some prop families remain
  simplified. Homes without a recovered interior use a reusable room.
  Rebuild both atlases and the placement data with
  `tools/build_falan_room_art.py`, passing the Magic Power project path and
  `assets/maps/falan` as the output.
- The keep uses source-map 1520 for the three-flight entry staircase and
  1521 for the upstairs landing. Press **F** at their stair markers to go
  between floors. In the throne room (1511), the wide stone steps climb to
  the curtained dais, with the original five stool positions. Palace
  furnishings use the archived anchors for banquet tables, shelves, armor
  displays, braziers, and the royal chamber's canopied bed. The staircase
  and canopy geometry is authored in `forest_falan_palace_art.gd`.
- The courtyard stairwell leads to the blue shrine (1530) and its
  book-lined lower passage (1531). A side corridor off the palace entry
  hall leads to the lower gallery (1522). `forest_falan_cellar_art.gd`
  rebuilds the shrine platform, recessed gallery, and original stair
  strips. The same archived prop anchors place crescent monuments, iron
  grilles, ropes, and storage furnishings. Navigation and room links
  continue to use the archived walkable cells.
- The employment office follows city graphic 10607 and room map 1091.
  Its rounded stone porch and crenellated slate roof use the civic
  palette. Timber counters and ledgers reuse the bank furniture, and
  `forest_falan_employment_art.gd` adds the walkable staircase, benches,
  pennants and notices at their archived positions.
- The guild hall follows city graphic 10604 and interior map 1092. Its
  bannered porch and crenellated slate roof are assembled in
  `forest_falan_civic_exterior.gd`. The reception counter and storage
  furnishings are authored in `forest_falan_guild_art.gd`. The archived
  reception, office, entrance and six NPC placements share the same floor.
- The inn follows city graphic 10004 and room maps 1101–1105. Its round
  turrets and teal roof use the shared civic stone and roof pieces. The
  bar, corridor, lottery room and two furnished side rooms retain their
  archive floors, NPC positions and door links. The counters, stools,
  candles and chests are authored in `forest_falan_inn_art.gd`.
- The bank follows city graphic 10010 and interior map 1121. Its stepped
  slate façade uses the shared civic roof and door pieces. The teller
  counters, overhead grilles, vault and ledgers follow their archived
  placements in `forest_falan_bank_art.gd`. Both original NPCs remain in
  the hall and use the existing silent sprite renderer.
- City map 1000’s mansion uses dome graphic 10600 and paired pavilion
  graphic 10601 as the references for its new 3D rotundas. Floors 1301–1305
  retain their archived carpet, parquet and paneled walls. The recital
  stages, grand piano, settees, gallery stairs and writing desks are
  authored in `forest_falan_mansion_art.gd`. The room art generator
  straightens the four original paintings into `mansion_pictures.png`.
  Both mansion staircases are walkable through the turn and onto the
  upper landing. The original room links still use their **F** markers.
- Passages use Magic Power's classic connections from
  `godot/assets/exploration/world.json`. City and castle retain all four
  connecting entrances. The west, east, and south bridge approaches have
  permanently open stone entrances. The rooms retain recorded stairs and
  door links.

The [editable asset guide](../../blender/environments/wind_meadow/falan/START_HERE.md)
lists the new masters and their exports.

- Il Village (2000), Saint Laruka (2300) and Habaru Cave (11003–11005)
  are part of the same Freyja and Falan save. The destination generator
  reads the cached Blue CG grids and Magic Power's fixed warp list.
  The room art generator reuses the painted wall and furniture kit.
  Village NPCs use server placements and original static sprites.
  The cache is missing Laruka church's lower floor (2307); its
  replacement keeps the documented stair link.
- Il's exterior restoration uses `tools/build_il_restoration.py '../Magic Power'`.
  It recovers all 180 original ground graphics into `il_village_ground_*`,
  eight building placements and their five source graphics into
  `il_restoration_data.gd` / `il_buildings.png`. The existing coastal building
  renderer fits the thatched houses, shops, chief's house and stone church to
  the existing scenery bounds; unseen faces reflect the two archived faces.
  The existing meadow plants and rocks fill the original small scenery anchors.
  Village roads, shore, fences, doors, NPCs and saved maps retain their owners.
  The shared source-ground shader now paints Il's full land/water grid.
  Habaru's wall geometry uses prepared luminance relief from its existing
  `habaru_wall_faces.png` through `habaru_shapes.gd`; its ceiling reuses the
  undersea cave's clearance-based vault builder. Original walk masks, pools,
  stairs, furniture, hatch and the native boss/nine-bear encounter are retained.
  Run `il_habaru_restoration_test.gd -- --il-habaru-alyut` through Play Goemon
  for all six Il interior round trips, the cave road and stair links, ten native
  bears, ceiling clearance and persistent encounter completion. Captures/logs
  are under `build/Other Files/BlueCG Map Study/Il Restoration/`.
- Habaru preserves the Il passage (11003), the bear chamber (11004),
  and the Alyut passage (11005). The original tile orientation, pools and
  rock faces come from the archive. Shadowed faces use the same stone in
  3D, including behind furniture. Ozunack and nine Cave Bears use original
  sprites, attack frames and audio. Green slimes roam the two passages.
  熊弟 waits alone as a harmless shared army sprite. Approach within 8 map units
  and press F to open his dialogue. His final bear callout switches to a yelling
  portrait; finishing that page starts the existing native boss
  and nine-bear encounter, with pooled summon effects for the bears. Cleared slots
  persist; if the boss is already dead, remaining bears return without dialogue.
  Each passage prepares 42 unique
  native green-slime positions around the original 14 anchors, preserving
  original slots and cleared-unit records. East Gate/East Coast patrol posts
  are expanded threefold and release up to three monsters every 0.2 seconds.
  North Coast adds 60 authored dry-roadside posts with the adjoining coast
  monsters, expanded through the same three-member placement rule. Actual
  arrivals skip blocked land and retain the existing 240-unit adventure cap.
  Both cliff mouths sit on the original Freyja warp tiles, Il `(672,223)`
  and Alyut `(691,188)`. The six interior thresholds use the original
  grey stairs (17954), recessed stone stairwells (17955), and pale stairs
  (12001) at their archived cells. Walk onto any threshold to cross.
  Recover the sprites with
  `python3 tools/recover_habaru_encounter.py '../Magic Power'`.
- Habaru wayfinding retains six timber signposts along each existing village
  approach, village-gate directions and a cave title. The rock mouths are now
  3.2 times wider and 2.35 times taller; the added entrance frame and lamps have
  been removed. The existing cliff-profile cutout removes the ridge faces
  that previously covered the mouth, including the separate gate-ridge mesh.
  The cliff's existing collision boxes are split around the enlarged passage,
  retaining solid sides and overhead rock. The wider walk-in threshold still
  reaches the original dungeon at the original warp anchor.
  Il and Alyut reuse Falan's signposts, benches, produce tables and
  planted beds at their existing building frontages. These are authored dressing,
  not recovered archive placements. Placement checks protect the current doors,
  gates, NPCs and solid scenery; door links are queried before marker construction.
  Source graphics 11268/11269 use round walls and tiered thatch. Round shop 11271
  adds its low side wings; houses 11272/11273 and shop 11275 use source-style dormers,
  with the shop's sloping entrance canopy. Church 10607 uses its blue roof terrace,
  crenellations and round porch. These extend the shared source-painted mesh builder;
  they retain existing fitted collision footprints and original texture atlases.
  Il/Alyut no longer project the whole sprite over every face. The shared mesh
  builder uses `village_building_surfaces.*`: 14 rectified patches recovered from
  the preserved building atlases by `tools/build_village_building_surfaces.py`.
  Plaster, timber, trim, stone and roofing repeat at fixed physical scales;
  windows, doors and medallions keep their aspect on separately fitted panels.
  Both roof slopes have actual dormers. Fitting is baked before UV measurement,
  and matching graphic/fit pairs share cached meshes across both villages.
  Atlas gutters and explicit texture gradients isolate each patch. Opaque wall
  and roof tiles prevent the cutout holes caused by the old sprite projection.
  The original 2D art records two faces; other sides assemble the same recovered
  materials and architectural pieces rather than stretching those two faces.
  Regenerate through `build_il_restoration.py` or the surface tool; never paint
  over the generated atlas. Original building atlases remain unchanged.
  Village and countryside blank ground cells now reuse original grass graphic 5045
  instead of flat fallback color. The generator records its village atlas slot;
  the adjoining Freyja landscape reuses slot (0,2). Debug graphic 100 stays excluded.
  The connected countryside reuses recovered small plant/rock placements from the
  existing East Gate–Il–Alyut scenery catalog within the same gameplay owner.
  Run `habaru_wayfinding_test.gd -- --il-habaru-alyut` through Play Goemon for
  normal-camera cave views, centre and both-side on-foot entrances, all eleven
  village doorway round trips and frontage clearance. Cave/street captures are
  under `build/Other Files/BlueCG Map Study/Habaru Wayfinding/`; individual building
  views, original reference graphics and validation logs are under `Village Fidelity/`.
- The East Gate–Il canal bridge now belongs to one connected outdoor map.
  `tools/build_east_road.py` combines the existing masks in the East Gate frame;
  `forest_east_road.gd` prepares one 459-point-square terrain field and shared mesh.
  Both banks retain the original source coordinates, bridge, cliff/foliage assets
  and native army owner. The old bridge crossing no longer calls map travel.
  Gate and coast patrol posts share the existing 240-unit cap and city-side safety
  boundary. The former East Coast travel identifier remains a read-only entry
  alias; its arrivals, headings and Il returns are converted to the joined frame.
  Dungeon and building interiors retain their existing travel behavior. Original
  masks and user map files are preserved. `build_falan_approaches.py` regenerates
  the joined mask after preparing its source masks.
  `east_bridge_connected_test.gd -- --east-il-road` verifies walking both ways
  with identical model, bridge, world and native monster handles. The building
  wrap replay checks all thirteen buildings, fixed texel density, feature aspect,
  four views per distinct building and all eleven doorway round trips. Run
  `village_building_wrap_test.gd -- --il-habaru-alyut` through Play Goemon.
  Evidence is under `Building Wrap/` and `Connected East Road/` in the map study.
- Il and Alyut exteriors now share their surrounding playable landscape. Il is
  placed in the joined East Gate frame; Alyut is placed in North Coast. The
  existing source masks contribute their dry village cells to each road mask,
  retaining the countryside's waterways and blending the original 6 m village
  floor into the surrounding hills over an 18 m apron. No source PNG or saved map
  is rewritten. Ground and water shaders reuse both regions' original tile atlases.
  `forest_falan_frontier.gd` reuses the existing village scenery/query context to
  build all thirteen houses, gardens, NPCs, gates and fitted collision once. This
  context has no wave or army owner. Duplicate countryside props inside the village
  bounds are replaced by the original village placements. The native field, world,
  camera and monster handles remain alive at all three village gates; no gate is
  a travel trigger. Legacy village/interior return identifiers convert arrivals,
  headings and velocity into the shared outdoor frame. Building and cave interiors
  continue through their original links. `connected_villages_test.gd -- --east-il-road`
  checks physical gate crossings both ways, original paint/height/building/NPC
  preservation, all eleven doorway round trips and both Habaru mouths. Desktop
  outward-view captures and logs are under `BlueCG Map Study/Connected Villages/`.
- Alyut Village (2400) connects to both North Coast roads. Its general
  store, hospital, residence, Nancy's house and chief's house keep their
  original entrances. The chief's stair reaches teleport room 2499.
  `build_il_restoration.py` also recovers Alyut's 179 ground graphics, five
  building placements and four facade graphics into `alyut_ground_*`,
  `alyut_restoration_data.gd` and `alyut_buildings.png`. It reuses Il's coastal
  building renderer, fitted scenery bounds and meadow detail meshes.
  `build_falan_approaches.py::build_east_scenery` now includes the North Coast
  source tiles `(568–710,34–215)` around Habaru's Alyut exit and both village
  roads. Its shared catalog contains 924 tree identities and 859 small anchors
  across the complete East Gate–Il–Alyut corridor; water, routes and solid
  scenery filter actual placements at setup.
  Il and Alyut now show and share the adjoining playable countryside from inside
  the village, as described above. The earlier `forest_village_vista.gd` strip is
  retained only for standalone legacy village previews; normal travel uses the
  complete outdoor field and does not clip scenery at the village grid or rebuild
  the world at its gates. Existing source masks, tree masters and archived cliffs
  remain authoritative, with batches prepared at outdoor-area setup.
  `alyut_restoration_test.gd -- --il-habaru-alyut` replays the cave route, both
  village views, Alyut rooms and teleport room; evidence goes under
  `build/Other Files/BlueCG Map Study/Alyut Restoration/`.
  Focused rendered/headless restoration replays pass the village views, rooms,
  native bear-pack clear/re-entry and source-aligned roads. The older full
  combat/ladder replay historically reported 13 contact/hatch failures. The
  later Habaru Combat Fix replay resolves all thirteen: its temporary 5,000-HP
  fixture now raises maximum HP too, preventing regeneration from clamping Kaz
  back to 100 and ending the run before the hatch checks. Both headless and
  rendered full-route replays pass; logs are under `Habaru Combat Fix/`.
- Freyja's enclosed cave ceilings sit at about 11 m in the playable world.
  Walls meet the solid roofs, and the cave camera has room to pull back and
  tilt higher. Venoa, Habaru, the undersea caves, Great Wind and Alyut West
  use raised roof relief and rock sampled from their Blue CG wall sprites.
  Wall meshes follow the archive grid, including behind pools and banks.
  The original isometric maps did not draw an interior ceiling, so the roof
  uses the same stone palette as the walls. Rebuild the rock atlas with
  `python3 tools/build_falan_room_art.py '../Magic Power' assets/maps/falan`.
  Cave corridors gain up to one tile along each edge where the
  neighboring routes stay separate. Ozunack, the Great Bear, the Modified
  Zombie and the Wolf Captain use the original chamber tiles and object
  placements. The wider corridors meet those rooms at their archived edges.
  Imur Forest stays outdoors.
- Venoa Village (2100) connects to the south road at its archived Freyja
  entrance. Its equipment shop has two doors into the same room. The
  hospital annex and the chief's passage, side room and teleport room use
  the fixed Blue CG links. The village reuses the Falan building and
  furniture kit, including the original crescent arrangement in room 2199.
- Venoa Cave (熊洞) now follows its archived three-map route: Falan-side B1
  (11000) → B2 (11001) → village-side B1 (11002). Original stair cells are
  (20,59) ↔ (34,14) and (24,81) ↔ (35,10); the outdoor exits remain at
  Freyja (471,317) and (442,349). The miner's gate opens the original fenced
  stair pocket and the separate shortcut (11022), which reconnects at (10,59)
  on the village-side B1. All four collision masks match the cached client,
  including isolated floor cells; these corridors are never widened.
  The expanded population has 104 bears in 32/40/32 floor formations. The
  original 27 spawn slots remain first so their slain IDs stay stable; added
  bears occupy connected floor cells with space from stairs and the boss.
  This crowded real-time population is a Goemon adaptation, not an archived
  random-encounter count. The Great Bear stays on B2, and defeated bears stay down for the run. The miners
  and road sign retain their archived floor and position. The shortcut is empty.
  The shared Habaru rock projection prepares Venoa's original wall faces;
  original 17952/17953 stair samples use the existing stone-stair geometry.
  `python3 tests/forest-shrine/test_venoa_archive.py` compares every collision
  cell and inter-floor warp against the adjacent Magic Power archive. Run
  `freyja_villages_habaru_test.gd -- --venoa-cave` through Play Goemon to replay
  both cave directions, the shortcut, boss persistence and the village road.
  This restores map geography in the existing 3D game; current combat and the
  silent miner-gate interaction remain the game's adaptations.
- The 熊洞 → 維諾亞 → 海洞 corridor now uses 2,402 original scenery anchors
  across its road and coastal surroundings, including the previously omitted
  cliffs, trees, flowers and shore caps between the entrance studies. The
  existing static scenery batches, Wind Meadow meshes and recovered ground
  tiles retain the project's 3D presentation. `tools/build_undersea_details.py`
  expands the existing recovery bounds; it does not author a replacement road.
  Its `VENOA_ROADS` records the 193-cell walk from Freyja (442,349) via the
  village to 海洞 (343,497), plus the 79-cell branch from (331,481) to
  維諾亞海底洞窟 (299,538). Each cell follows archived walkability at the existing
  3 m scale. Full scenery/route comparisons are in `test_venoa_archive.py`;
  run `venoa_bear_road_test.gd -- --venoa-undersea` for capsule clearance and
  entrance returns, or `--venoa-cave` for crowded native bears and cave travel.
  Scenery models, cliff heights and unrelated landmarks remain 3D adaptations;
  this is source-grid recovery, not a pixel-identical original-client renderer.
- The outdoor dungeon approaches use the cliff footprints, warp cells,
  fence and landmark placements from Freyja `100.dat` and Sokia `300.dat`.
  The Falan-side Venoa entrance uses the original fenced mine approach.
  Natural cave mouths use mossy Freyja or bare Sokia rock painted with
  samples from the original cliff sprites. The Zombie
  Cave diamond and Imur grave sit in their original clearings. Linked
  entrance stairs are visible inside the single floors. Rebuild the
  entrance data with `python3 tools/build_falan_approaches.py`.
- The 海洞 → 維諾亞 → 熊洞 visual recovery now uses clustered crags, recovered
  moss/stone paint and the existing cedar/pine/broadleaf silhouettes. 熊洞 adds
  jagged stone volumes, dark backing/roof and shallow rocky pool edges. The
  procedural masters, exact source crops and preservation rules are documented
  in [the Venoa scenery guide](venoa_scenery/README.md). These changes preserve
  source cells, native obstacles, stairs, headroom and all 104 ordinary bears.
- The original Village and Fire Cave mouths of Venoa Undersea Cave both
  open onto the long winding 15593 passage. Either entrance can reach
  either exit on foot. Water Dragon Lizards and Lizard Warriors patrol
  both this passage and Sokia Undersea Cave.
- During Explore, press **M** for the current area map and **M** or **Esc**
  to close it. The cyan marker shows Kaz, gold markers point to entrances
  and roads, and coral marks boss chambers. From Falan use the South Gate.
  The Falan-side Venoa Cave entrance is on that map. Follow the road to
  Southern Lakes to reach the separate Sokia and Venoa undersea entrances.
- Cave pools use the water tiles from the original floor grid and a shallow
  animated surface. Bank graphics sit on the archived shore cells, including
  the approach outside each boss arena. The walkable tiles keep their original
  collision, including the shallow pools that can be crossed.
- The road past Venoa enters Sokia Undersea Cave at Freyja (343,497).
  Map 15003 connects that mouth and the Kili-side exit at Sokia (240,265)
  on the same floor. The original guards remain as silent sprites.
  Approaching the basin triggers 熊哥 (熱砂的歐茲尼克), two Water Dragon
  Lizards and two Lizard Warriors. The archived turn-based encounter uses a
  fixed location and real-time attacks here. Defeated enemies stay down for
  the run. [Blue CG encounter record](https://gamerch.com/blue-cg/453468)
  The coast from 300.dat connects to both Kili gates, including the west
  trailhead (274,294).
- Kili Village (3200) uses the original coastline, roads, wall lines,
  palms and ten building entrances. Its limestone shells reuse the
  shared stone materials and static box batches. The equipment shop,
  lower shop, tavern, hospital, chief's rooms, teleport room and two
  named homes use the cached daytime interiors. The four housing interiors
  (3801/2/3/7) now use recovered original server maps, documented below.
- The shared Freyja and Falan save plays at 130% of the archived dimensions,
  including Falan, the overworld, villages, interiors and dungeons. The saved
  layouts and archived tiles retain their original coordinates. Terrain,
  collision, doors and encounter placements are scaled into the playable world
  while Kaz's size, movement and attack distances stay in world units.
- The original yellow diamond at the suspicious rock in Sokia Undersea Cave
  (34,7) leads straight to Black Prayer. The dungeon uses the archived
  palace `16508.dat` as one floor with its original tile layout, barred gate,
  and archived furnishings. Press F by the silent guard to cross the bars.
  The cave camera eases back near a living dungeon boss and still respects
  walls and ceilings. Ruby,
  five Bloody Blades and four ghosts use the original sprites at Kaz's
  height or larger. Ruby heals while the Blades protect her and adds an
  ice burst when two remain. Victory opens the absorption rooms and
  Fengnu's House, which also has its archived Sokia entrance (349,261).
  Rebuild the combat sprites with
  `python3 tools/recover_habaru_encounter.py '../Magic Power' --ruby`.
- Kili's east exit (295,325) follows Sokia's archived dirt road to the
  western Great Wind Cave mouth (356,334). Enter the cached cave floor
  (13001) and walk through its connected passage to the east exit
  (133,26). The exit lands in Sokia at (402,304), where the dry coast
  route from 300.dat leads to Ghana's south gate (704,148).
  The four existing Sokia crops now retain all original scenery anchors, native
  ground and dry blocked tiles, replacing the old meadow scatter and mountain
  ring. Source bounds, regeneration and remaining 3D limits are documented in
  [the Sokia recovery guide](sokia/README.md).
- Ghana Village (3000) connects at the south gate: the road lands at (48,76)
  and the gate tile (48,77) returns to Sokia (704,148). Its streets, shore,
  cliffs, fences, well and six building fronts use the cached village layout.
  The fronts reuse `scripts/forest/forest_kili_art.gd`, including a white
  hospital variant, and the well reuses `assets/models/cedar_pass/well.glb`.
  The ten cached interiors include the equipment shop and general store,
  pub, hospital, both residences, and the chief's rooms and teleport chamber.
  The three fenced housing entrances use Ghana residence layouts as stand-ins
  for the uncached housing rooms. NPCs remain original silent sprites.
- Ghana's north gate (48,26) exits to Sokia (704,95); the adjacent outdoor
  gate tile (704,96) returns to Ghana (48,27). The north coast route follows
  the dry corridor from `300.dat` past the original guard (707,58) to the
  graves (715,34), with its shoreline, cliffs and guard fences intact. The
  guard remains a silent sprite. Press F at the original grave to enter
  Imur Forest directly.
- The grave leads to one open-air Imur Forest floor. A branching trail
  generated from the run seed connects directly to the graveyard. Returning
  to the forest during the same run rebuilds the same trail. The graveyard
  uses the recorded boss coordinates and a layout traced from the published
  map image. [Cemetery map reference](https://www.molibaike.com/Mission/Detail/fc27dc43-726c-40aa-8bf3-8f65698a9b4e)
  The native encounter starts as you approach. It runs the ghost and two
  soldiers, then Parukes and the rebels. Magic Seal, Life Drain, Earth Rage
  and rebel reinforcements are adapted to real-time combat. The return
  opens after victory and leads back to the same Ghana grave.
  Recover the sprite and sound data with
  `python3 tools/recover_habaru_encounter.py '../Magic Power' --grave`.
- The animated yellow diamond at (541, 39) leads to the single Zombie
  Cave floor using Arubas's Lab (15505). Six roaming zombies, three
  original red Hellhounds (101030) and the silent nurse share it with
  the Modified Zombie and three escorts. The return diamond remains
  usable. Victory opens the stair back to Freyja (544, 35). Recover the
  original sprites with
  `python3 tools/recover_habaru_encounter.py '../Magic Power' --zombie`.
- Alyut West Cave uses the Wolf Captain's hall (16503) as its main floor.
  The original mouth at (549, 43) offers a second landing with Shift+F
  at low tide. Zanark remains a silent 2D sprite. The post-fight memorial
  keeps its separate reward door and the shore exit at (550, 19).
  Approaching the Wolf Captain starts the native fight with two Sea Bats
  and two Pirates. Defeat all five to open the memorial. Recover the shared
  sprite batch with `python3 tools/recover_habaru_encounter.py '../Magic Power' --captain`.

## Undersea source details

`undersea_edges.png` and `undersea_edges.gd` recover the three small transparent
high wall caps (13004, 13016, 13028) omitted by the general room prop atlas. They
reuse `build_falan_room_art.project_boss_overlay`; the flat mesh draws source
placements in a single batch per room with the original palette. Recover with:

```sh
python3 tools/build_undersea_details.py '../Magic Power'
```

There are 38 edges on source map 15003 (Sokia) and 35 on 15593 (Venoa).
The archived floor, water and wall atlases remain authoritative. Undersea walk
masks now keep source tiles exactly; global 1.3 world scaling, ceilings, entrances
and the single saved venture remain in their existing owners. The one-floor
adaptation retains the main source floor and both original outside links.

The undersea exporter also prepares `undersea_floor_atlas.png`,
`undersea_wall_atlas.png`, `undersea_rock_atlas.png` and `undersea_props.png`.
It decodes the original indexed graphics with `palet_02.cgp`, the blue cave
palette matching the [Blue CG reference](https://guide.bluecg.net/blue-cg/453177),
and reuses the existing projections and atlas UV slots. Previously these
surfaces used the generic palette 0, which made the stone and shore overlays
green. The undersea wall atlas also retains the original face cutouts; the
blue stone shader fills those areas instead of the generic beige wall filler.
Do not tint the generic room atlases: other caves still reference those.
Re-running the command above rebuilds the four atlases and blue edge details
without changing room grids, entrances, NPCs, encounters or saved maps.

The same exporter now prepares `undersea_shapes.gd`, `undersea_roof_atlas.png`
and `undersea_shore_faces.png`. Wall relief uses a 5×9 grid sampled from each
original projected rock face, replacing the generic sine ripples for undersea
walls. Source-only navy back-face pixels are masked so matching blue rock
continues behind them. The existing wall mesh, source boundary, UVs and material
remain the owners; no separate scenery controller is used.

The high caps now sit just below the ceiling, at their archived horizontal
placements, rather than on the floor. The sealed vault uses opaque patches
from the tops of original rocks 13000 and 13019. Its height follows passage
clearance and stays above the previous 8.5 m minimum. Blue CG has no ceiling
or metric rock depths: the roof and sampled wall relief extend its 2D art into
3D, while the archived horizontal grid and palette remain unchanged.

The 13036–13071 shoreline bank tops keep the original source cells and walking
height. A single static batch restores their two original vertical face views
where they meet water. Non-walkable bank cells may rise to .74 m; walkable tops
stay flush with the passage. Pools retain their current level and behavior.

## Undersea entrances and stairs

The same recovery command prepares `undersea_entrances.gd` and the two
`undersea_stair_13268.png` / `undersea_stair_13269.png` stone surfaces.
The stair graphics match the existing Habaru stair shapes, so they reuse that
geometry and walking ramp with their original blue surfaces. The exporter
straightens the same source face/rim coordinates used for Habaru. Undersea
materials use world-projected sampling and archived palette compensation.
The source stair cells and existing single-floor exit links remain authoritative.

The exterior profiles trace the largest dark opening in composites of the
original outdoor maps: Freyja (343,497), (299,538), (251,493) and Sokia (240,265).
They retain the source asymmetry, mossy Freyja / bare Sokia cliff materials and
original warp positions. Lower openings keep Kaz's walking clearance; depth and
3D scale extend the original isometric artwork. A local cutout on the duplicated
cliff material removes the old ridge surface from behind each recess. Other
cliffs and shared materials retain their default zero-cutout behavior.

Each mouth and stair uses the existing walk-in transition, with a close threshold
at the source tile. Arrivals rest on the prepared stair ramp and do not require F
or dialogue. No new floors, map saves, controllers or teleport system are added.
`freyja_villages_habaru_test.gd -- --undersea-portals` checks all four round trips,
stair art/placement and repeated-arrival stability through normal walking input.

## Undersea outdoor surroundings

`build_undersea_details.py` also recovers the original scenery around the four
mouths: 388 placements across the three Freyja patches and 375 along the Sokia
landing toward Kili's west gate. `undersea_entrances.gd` records the source cells,
graphic IDs, footprints and bounded study areas. Existing entrance collision and
the wider road/terrain collision stay authoritative; overlapping old cliff art
and already-built tree placements are skipped. Trees, palms, flowers and fences
reuse the current shared 3D scenery assets. Their meshes and the cliff depth are
3D interpretations, not recovered original geometry.

Sokia Coast now uses `sokia_ground_index.png` / `sokia_ground_atlas.png`, recovered
from map 300 with the same tile projection as Freyja. This retains its actual
sand/grass patches and blue waterways; it no longer uses the meadow's baked
outer apron. The generic surface builder's default remains Freyja map 100.
`undersea_coast_banks.png` projects the original 12500–12535 grass-edge graphics
onto the existing terrain at their original cells. It replaces the low rock
mounds in these patches, with submerged detail staying below the water surface.
There is one shared static bank mesh per outdoor area and no per-frame builder.

The portal replay also checks these placements, source materials and the road
to Kili. Rendered coast/route captures and source composites are under
`build/Other Files/BlueCG Map Study/Undersea Surroundings/`. No saved map is
rewritten, no entrance moved, and no new interaction or dialogue is introduced.


## Kili coast and both coastal villages — 2026-11-12

The Sokia road from the undersea exit (240,265) to Kili's west entrance
(274,294) now follows 57 source walk cells, using original navigation footprints
and sand tiles. Both the full destination exporter and the focused undersea
exporter use `build_freyja_outlying.kili_road`; regenerating the destination masks
must not restore the older path through cliff footprints.

`coastal_village_data.gd` is generated by `build_undersea_details.py` from map
3200 (Kili) and 2100 (Venoa). It records every original building footprint and
1,114 / 734 recognized scenery placements respectively. Kili has seven source
building bodies plus the equipment-shop arcade; Venoa has seven building bodies,
including one continuous equipment shop with two entrances. The
original ground indices/atlases retain the exact source sand, paving and water.
Existing interior links and silent original NPC sprites are unchanged.

The Kili local source origin maps to Sokia through offset (215,249) in source
tiles. Recovery verifies 400 matching ground tiles at the west gate and both
pairs of original column IDs. Both open gates cross their source planes on foot;
position, forward motion and camera heading remain in the shared frame. The
outside views contain the same nearby buildings and original gate columns.
Venoa's outer/inner gate walls likewise share their source pieces.

`forest_kili_art.gd` owns the open columns and walls; source-specific architecture
and facade paint are in `forest_coastal_buildings.gd`. The shared projection
helper mirrors visible paint onto unseen faces. Original layouts and footprints
are recovered data; height, unseen faces, foliage meshes and cliff depth are
3D interpretations, not a pixel-identical recovery of the 2D artwork.

Validate with `freyja_villages_habaru_test.gd -- --kili-coast-road` through
Play Goemon for the complete walking route, both Kili gate round trips and
rendered village views. `--kili` / `--venoa` traverse the existing interior links;
`--undersea-portals` covers the four cave mouths; `--freyja-scale --gate-exteriors`
covers all three Falan crossings and walkable water. Evidence is under
`build/Other Files/BlueCG Map Study/Kili Coast Road/`. No additional map save or
app export is needed.

The building/interior pass recovers every cached wall and furnishing placement
in 23 linked room IDs using `build_coastal_villages.py`. Counters join at their
source tile boundaries, weapon displays and medicine cabinets use their original
paint, and the floor atlas includes the previously omitted 64×48 carpet tiles.
Source floor axes are corrected for both villages. Missing kitchen items,
stools, wall fittings and wooden stairs are assembled from shared primitives;
the existing stair tiles still own automatic transitions. Generic wall filler
does not duplicate the recovered wall objects. All village doors and internal
links now open on foot, with the original silent 2D NPC placements.

Run `--coastal-kili` / `--coastal-venoa` through Play Goemon for all room-link
round trips without F, source placement counts, NPC counts and rendered reviews.
Evidence is under `BlueCG Map Study/Coastal Village Rooms/`. The four Kili house
IDs (3801/2/3/7) now use distinct recovered server maps from
`assets/references/crossgate_kili_houses/` instead of residence substitutions.
The control maps 3220/3221 match the Blue CG cache in every ground/object cell;
live Blue CG versions of the four missing houses remain independently unverified.
Their original door tiles, partitions, floors and every furnishing are recovered;
3803 returns to its original outdoor tile (38,58). Open crates, a side barrel,
coal basket, book, cushion and loose fruit reuse shared procedural geometry.
House source previews and rendered room captures are under
`BlueCG Map Study/Kili Original Houses/`. The canonical venture JSON is not
rewritten and no extra saved map is created.

Kili exterior continuation (2026-11-17): all seven building bodies and the
equipment arcade keep their original facade paint and positions, with solid
roof canopies, hanging racks, pots/planters, hospital belfries/bells, crates,
medical packages and shop awnings. The roof kit and native 15-crop atlas recipe
are documented in the Falan asset guide; `recover_kili_surfaces.py --check`
reproduces the new surface paint. Approach walls/columns reuse a cached solid
kit. Kili/Sokia trees reuse the recovered Cross Gate flora; Sokia's mossy cliffs
reuse the Venoa crag kit. The source terrain, water, road, blocked cells, NPCs
and room/gate links retain their existing owners. Run
`kili_recovery_test.gd -- --east-il-road` through Play Goemon for the complete
coastal walking route and before/after collision comparison. Evidence is under
`build/Other Files/Asset Toolkit/Kili Village Recovery/`. These are fitted 3D
interpretations, with finer scenery and interiors still needing further work.


## Falan travel stones — 2026-11-13

The six original city crystals are restored at map 1000 cells (141,146),
(63,77), (244,100), (233,76), (74,123) and (164,130). During Explore, press
**E** within 4.5 map metres of one, select another stone, or cancel with Esc.
The ivory-framed menu pauses play. Local travel keeps the same map, player
progress and native army; it clears movement and resets camera follow. F/G/H
retain pet commands. Destinations use the existing clear-ground search and
reject a blocked landing. Nothing is written to saved maps or preferences.
This is the six-stone city network; village teleport-room quests are separate.

`tools/recover_falan_travel_stones.py` reads the preserved adjacent Magic Power
project's `godot/assets/exploration/world.json` and original graphic library.
It publishes the unchanged eight-frame original:3171 crystal, the six source
cells, and exact RGBA sprites 17235–17241. The original NPC source also records
these cells as login stones 5000–5005. The existing garden anchors retain each
shrine's three crescent stones, inscription stand and four carved corner posts.
That first sprite implementation is superseded by the solid 3D kit documented
below. The original sprite art remains preserved as the recovery reference. Other garden assets and collision plans
are preserved. The pixel hashes and source metadata are in
`travel_stone_source.json`; editable recovery is authoritative. Do not repaint
or modify generated images.

The shared outdoor ground renderer prepares a cached 32×32 texture-array layer
for every archived tile. Its mipmaps are generated independently, preventing
neighboring artwork bleeding into the grass/road at distance. Source pixels,
source tile indices, UV orientation, terrain triangles, collision, bridges,
water and scenery positions are unchanged. Ground and water share the same
prepared tile arrays, including connected village artwork.

Run `falan_gate_shortcuts_test.gd` through Play Goemon with `-- --east-il-road`.
It exercises all 30 distinct city trips, E/Esc, blocked/invalid use, unchanged
world/army/save state, original art and the three gate returns. Its rendered
checks also verify isolated distant mip colors and exact tile pixels. The
asset-toolkit `test_falan_travel_stones.py` checks pixel hashes and byte-identical
regeneration from the original source. Captures, logs and source reference crops
belong under `build/Other Files/Asset Toolkit/Falan Travel Stones/`.

Fresh verification for this change: **266 desktop checks and 246 headless checks
pass**, covering all 30 distinct city trips, E/Esc, blocked landings, exact source
sprite rectangles and gate returns. The desktop pass also verifies unchanged
base tile pixels and isolated farthest-mip colors. Both source-art tests pass,
including byte-identical regeneration from the attached archive. The connected
Il/Alyut regression and asset preservation pass. Source shrine crops, both shrine
orientations and East Gate near/far captures were visually reviewed. Tested
source hashes and limitations are recorded in `verification.json` beside the
captures. No full-army benchmark or long-session soak was run.


## Solid travel diamonds and shrine geometry — 2026-11-13 follow-up

The user's correction requires actual 3D geometry for both the crystal and its
surroundings. All six diamonds and 56 source ornaments now use shared opaque
meshes from `assets/models/environments/wind_meadow/travel_stones/travel_stone_kit.glb`.
The three inward-facing crescents per shrine have curved, thick bodies; their
flared bronze bases carry raised scrollwork. The four corner posts have ringed
stems and recessed cups. The paired inscription tablets are separate solid slabs
with rectified original markings. The crystal is an eight-triangle square
bipyramid with recovered cyan facet paint; its shared vertex shader turns its
vertices and normals through the original quarter-turn cadence.

Original positions, E/Esc menu, all 30 distinct city routes, blocked-arrival
checks, F/G/H, saved maps and the native army remain under their existing owners.
There is no per-stone process, sprite, billboard, alpha silhouette or added
collision/controller. Existing ornamental groups without a travel link remain
ornaments. Geometry and materials are loaded once through the existing scenery
cache. Editable source and export/paint instructions:
`assets/blender/environments/wind_meadow/travel_stones/START_HERE.md`.

Four-angle and component reviews plus actual city captures are under
`build/Other Files/Asset Toolkit/Falan Travel Stones 3D/`. The reconstructed
visible design follows the original references; unseen faces repeat those
motifs because no original 3D model is available. This supersedes the earlier
flat presentation without discarding its original pixel/reference files.

Fresh solid-kit verification: **279 Play Goemon desktop and 259 headless
assertions pass**. All four asset tests and active asset preservation pass.
The final eight-view asset review also verifies that the solid crystal visibly
turns. Four shrine angles, every component and the two in-game shrine
orientations were visually inspected against the archived art. The kit's
aggregate triangle-budget warning is retained and documented in its source
guide. Tested hashes, audit and limits are in the 3D evidence directory's
`verification.json`. No app was exported.

## Falan's original pond and city boundary — 2026-11-16

The main city no longer inherits the Goemon valley's cliff rim, terrain apron,
random foliage or distant mountain ring. Source gardens and user-placed
scenery stay under their existing owners; no reusable rock or tree asset was
deleted. The pond now displays original graphics 3880 and 5002 at all nine
source positions through one static mesh, replacing the invented bank rocks,
rushes and cylinder lilies. `city_pond_atlas.png` uses the established native
diamond projection and two-pixel gutters. Its editable recovery is
`tools/build_falan_city_streets.py::pond_art`; do not paint over the derivative.

Run `python3 tests/forest-shrine/test_falan_pond_archive.py` to compare both
graphics and all nine anchors with original city map 1000. Run
`Play Goemon.command --script res://tests/forest-shrine/falan_city_recovery_test.gd -- --east-il-road`
for matched city captures, all three gate returns, retired-marker validation
and saved-scenery preservation. Evidence and the unchanged-save hash are in
`build/Other Files/Asset Toolkit/Falan City Recovery/`. The city retains a
3D interpretation of the original; this is not a pixel-identical client.

## Solid original-style foliage — 2026-11-16

The user requested solid 3D scenery wherever practical. The 377 source garden
trees in Falan and 578 source trees in the southern road view now use three
source-shaped families, retaining their original placements and native obstacle
plans. These are solid meshes using the original foliage and bark paint, not
whole-tree sprites. See the editable masters and limits in
`assets/blender/environments/wind_meadow/crossgate_flora/START_HERE.md`.
The native source recipe and crown samples are `tools/recover_crossgate_foliage.py`
and `assets/maps/falan/flora/source.json`. The generic southern mountain ring
and random meadow dressing have been removed; user-placed scenery remains.

Run `python3 tools/recover_crossgate_foliage.py --check` and
`python3 tests/forest-shrine/test_crossgate_flora.py` for native paint, original
geometry counts, embedded textures, vertex shading and source preservation.
Use `Play Goemon.command --script res://tests/forest-shrine/falan_road_scenery_test.gd -- --venoa-undersea`
for the source-road capsule checks, cave returns, all 104 native bears and
matched office/garden/road views. Captures and logs live under
`build/Other Files/Asset Toolkit/Falan Road Recovery/`. Other architecture and
small props remain interpretations; this is not a pixel-identical original client.

## Source-referenced city buildings and small props — 2026-11-16

Fifty-seven unchanged saved house markers now use curved and gabled solid
roof families with rectified original plaster, slate, timber, window and door
paint. The original reference graphics are 10605 and 10081. Nearby original
city buildings identify the appropriate family; original dimensions are fitted
to the existing saved bounds. This improves appearance without moving doors,
colliders or user edits; distinctive civic buildings remain with their owners.
`tools/recover_falan_buildings.py --check` reproduces the paint/binding recipe.
Geometry and preservation instructions are in the Falan Blender asset guide.

The seven original street-lamp/column families now use cached solid meshes
(curved arms, cages, hooked post and decorative columns) at 113 source stations.
The gate bridges share the same lamp owner. The former box-lamp construction
is removed; original assets and saved scenery IDs are retained. The fixture
`falan_buildings_props_test.gd -- --east-il-road` covers colliders, house bounds
and winding, source lamp stations, custom-marker guards, all three gate returns
and warmed mesh identity. Evidence and limitations are in the Falan Buildings
and Props toolkit folder. This remains a 3D interpretation, not an exact
reconstruction of all original facades, ornaments and unseen building faces.

### Main-city noticeboards and brick planters

The solid noticeboards, native-lettered oval shop signs, bollard and four
planter families are authored in `scripts/forest/forest_falan_street_details.gd`.
`tools/recover_falan_street_details.py` regenerates `city_street_surfaces.*`,
`city_planter_art.png` and `city_planter_leaves.png`, including original graphic
hashes, opaque masonry controls and source-derived oval contours; `--check`
verifies reproduction. All 226 native bed stations now render, batched locally
with cached solid brickwork and reused shrub geometry carrying native paint.
Nine guarded house transforms/colliders use their archived centers, and four
generic room entries clear the restored bed rows. Native doors, NPC positions
and saved marker records remain intact. Fine depth and unseen surfaces remain
fitted. The Falan Blender asset guide records the shared parts and runtime
contract. Source/3D comparisons and fresh 1460 desktop / 519 headless checks are
under `build/Other Files/Asset Toolkit/Falan City Details/Planter Recovery/`.

## Appearance-based Falan conversations — 2026-11-22

Approach any of the 373 Falan street, castle or room NPCs and press **F**.
`npc_dialogue.gd` contains two original Traditional Chinese remarks for each of
the 127 unchanged atlas appearances, plus 127 personal remarks covering all
78 street characters, all 19 castle courtyard placements and selected royal
room speakers. Clothing, tools, posture and visible activity guide the writing.
These are locally authored conversations, not recovered BlueCG server text.
Shared sprites reuse their appearance remarks; named speakers can add their
personal line. A per-placement shuffle bag exhausts its lines before refilling.

`forest_explorer_npcs.gd` registers the existing sprites when the area changes,
using the same 0.15-second nearby/clear-path check and F control as recovered
Tina services. Portraits reference the speaker's existing atlas texture; no
master art or placement data changes. The shared ivory-framed dialogue, text
reveal and Space-release resume behavior stay in `forest_dialogue.gd`. Casual
conversations do not save or change quest inventory/Gold, and grant no services
or rewards. Existing recovered Tina scripts/services keep their own text/art.

Run `Play Goemon.command --headless --script
res://tests/forest-shrine/falan_npc_dialogue_test.gd` for all-appearance coverage
and representative city/castle/interior interaction checks; omit `--headless`
for rendered portraits/dialogue captures. Evidence stays under
`build/Other Files/Asset Toolkit/Falan NPC Dialogue/`.

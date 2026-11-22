# Black Prayer cave materials

Authoritative recipe: `tools/recover_black_prayer.py`. Editable placement and
seeded generation: `scripts/forest/forest_black_prayer.gd`; solid scenery assembly:
`scripts/forest/forest_black_prayer_art.gd`. Original client files stay in the
sibling Magic Power resource archive. `provenance.json` records the fixed map
hash, original graphics, packs, rows and decoded RGBA hashes.

Run `python3 tools/recover_black_prayer.py` to prepare, or add `--check` for a
read-only source comparison. Do not hand-edit `data.gd` or the prepared PNGs.

- `floors.png`: original native ground diamonds rectified to the existing
  32-column, 36-pixel room-floor atlas contract. Data ID zero is empty; positive IDs address texture cells from zero.
- `walls.png`: original maze/entrance cave faces using the existing 16-column,
  36×100 cave-wall contract. Index zero is reserved; each source has two faces.
- `rock.png`: opaque native cave-face samples mirrored into the shared four-family
  roof/stone sampler. Family 0 is the maze, family 1 the fixed entrance.
- `stair_17974.png` / `stair_17975.png`: original source sprites, reused as surface
  paint on the shared solid stair geometry. Stairs follow seeded anchors;
  downward holes share those anchors in the floor mesh and floor collision.
- `palace_wall.png`: original 15810 masonry, rectified from its visible left face
  onto the palace's existing solid walls. Source navigation and collision remain intact.

Walls, stairs and rock scatter use existing 3D builders. Rock shapes are fitted
interpretations of source 15011–15020, rather than recovered original 3D meshes.
Ruby's three solid barred panels retain their exact 17206 map placements and
existing collision/guard crossing. Four source 15819 overhead caps use raised
stone boxes at their archived cells. Six source 17683/17684 arch headers reuse
the existing solid arch mesh with native masonry, preserving their high placement instead
of showing their isometric black tops as low sprite panels.

`tools/recover_ruby_scenery.py` is the authoritative recipe for `scenery.png`,
`scenery.gd`, `scenery.json` and `pedestal_top.png`; use `--check` to compare without
writing. Original bookcases 16079/16080/16143 share rectified source fronts and
existing box/ledge geometry in `forest_black_prayer_art.gd`. Repeated placements
share one mesh per serial/span. Their 12×3 footprint and height ≤8.5 preserve the
archived navigation and ceiling contract. Pedestal 16100 reuses the same material
and box parts; its cropped blue topper retains the exact original pixels.
`scenery.json` records source hashes, atlas patches and the topper crop. Maze rock
scatter uses the prepared native rock material, with the existing seeded meshes.
Other ornate palace fixtures retain source sprites; do not replace them with
guessed furniture.


The same recipe/assembly now handles red columns 16464 and gold wall columns
16499 (22 source placements), plus five framed pictures 16130/16131/16132.
Columns share closed capped meshes by serial; picture faces reuse rectified
native paint within solid gilt frames. The pictures rotate toward the room from
the archived right wall. No collider/navigation/source cell moves. Heights fit
the existing 8.5 ceiling and footprints stay inside their one-cell contracts.
These are fitted 3D interpretations of source 2D silhouettes, not recovered
original 3D models. Square feature tiles must remain 112×112 before atlas
padding; rectangular thumbnail padding previously made column faces disappear.
The recipe checks fully opaque column/picture source crops and the fixture checks
cap coverage. Curtained arches, armored statues and the arched mirror now have studied solid
reconstructions described below; preserve other untouched source sprites.


The same authoritative recipe now includes native court linen, cabinet fronts,
red lacquer, blue ceramic, red/purple stool cloth and royal chair palette samples.
Four 16115 dining sets, standalone chair 16124, two 16140 urn cabinets and six
16204/16205 stools use these parts. `forest_falan_interior_furniture.gd::chair`
remains the authoritative whole chair geometry; the royal cached mesh owns its
three native color materials, preserving the original furniture and shared
materials. `turned` assembles closed stool/vase profiles with the existing
SourceMesh face builder. Repeated source placements reuse one mesh per family.
All assembled chairs stay inside their parent table's original blocked cells.

Top panels must sit above the gilt rim and map texture U along the original long
X axis. The first desktop pass caught a rim covering the linen; the corrected
fixture verifies the visible panel UVs and complete assembled footprint. These
3D profiles/backrest carvings are fitted, not original 3D geometry. Preserve all untouched source sprites and their native paint.


Carved details now come from `carvings.png`, `carvings_depth.png`, `carvings.gd`
and `carvings.json`, prepared by the same `recover_ruby_scenery.py` recipe.
The source chair back 16124, cabinet face 16140, arched mirror 16137 and round
tripod plate 17680 retain native paint. Alpha-derived silhouettes supply solid
backs; the existing Falan carving helper supplies bounded shallow relief from
the original pale strokes. Depth is interpreted shading, not original sculpture.
The chair's lower red seat pixels are separated from its back layer offline;
original archive pixels remain preserved and hashes/crop/mask rules are recorded.

`forest_falan_interior_furniture.gd::chair(false)` reuses the original legs,
seat and stretchers while omitting the incompatible plain back/posts. The royal
instances attach the native carved silhouette at the seat; default `chair()`
still returns the original complete model. Nine chair instances share the same
base, support and carved face. Two cabinets share their original front relief.
Twelve 17680 tripod ornaments reuse existing rod/oval primitives and native
metal colors; the 16137 wall mirror uses its original arch contour and paint.
All thirteen newly solid ornaments retain archived cells and add no colliders.

`forest_falan_carvings.gd::relief(feature, data)` accepts the Ruby preparation;
its default city data and existing generated mesh arrays are unchanged. Keep
all resource loading, pixel/depth reads and mesh assembly at setup. Front/rear
paint on the fitted solid backs uses the same recovered view; exact unseen rear
carvings remain fitted interpretations.
Source-gallery/context and recursive compound-footprint checks are in
`tests/forest-shrine/ruby_carvings_test.gd`. Evidence belongs under
`build/Other Files/Asset Toolkit/Ruby Carvings/`.


Curtains 16465/16466 and armored figures 16193/16196 now use cached solid
assemblies at all nine source cells. `forest_black_prayer_art.gd::court_prop`
owns these static variants. Two curtains reuse the established pleated-panel,
canopy-bar, rod and oval construction with native rectified red/gold cloth,
ornamental cornice and canopy paint. The cloth follows each curved cornice
without a floating gap. Both canopies fit their original 6×3 blocked footprint
and the 8.5 ceiling. No source cells or colliders change.

Seven armored statues reuse the same shared rod/oval/block primitives, with
layered pauldrons, fauld/tassets, gauntlets, knees, boots and closed crested helmets.
The two variants face into their respective sides of the hall. Their source
shaft proportions differ: 16193 has a slanting spear, 16196 a nearly upright
spear. High spear overhang follows the source silhouette; feet and low shafts
remain inside the original blocked cell. Native body paint is projected onto
the solid armor. Brown shaft pixels are separated from the armor derivative before nearest
native-color extension of transparent pixels to cover fitted edges/backs.
Retained opaque plate paint and archive masters stay intact. Shaft color is sampled from the spear above the body, not a nearby
steel gauntlet. Armor depth, unseen faces and canopy backs remain fitted from
2D evidence rather than recovered original 3D meshes.

`recover_ruby_scenery.py` still owns all preparation. Existing atlas tile offsets
remain stable as new tiles are appended. Meshes/materials are prepared once and
shared; nothing loads or builds during combat. The initial four court meshes placed 57,128 triangles across nine props;
the detail pass below now totals 100,300 across six meshes and seventeen props. No authored asset was decimated.
Focused source/gallery, compound bounds, repeated-setup and native-combat checks
are in `tests/forest-shrine/ruby_curtains_armor_test.gd`; evidence belongs under
`build/Other Files/Asset Toolkit/Ruby Curtains Armor/`.

Each of the six seeded maze floors now has 96 native enemies (six per room;
576 across all floors). This population is a real-time adaptation, not an
original fixed encounter count. The original 32 patrol slots and RNG draws stay
unchanged; 64 additional slots follow them so existing defeated-enemy records
remain valid. Species, levels 20–23, HP/damage formulas and Ruby's ten-member
boss party are unchanged. Stairs retain clear approaches, old deaths persist
when backtracking, and a fresh run still resets the run ledgers. Reuse the
native army's shared targeting, combat, death and pooled presentation owners.


The next court-detail pass keeps the two curtain profiles and their original
paint while adding bounded source-stroke relief to both gilded friezes. The
source cord traces in `recover_ruby_scenery.py::CORDS` use pixels within the
rectified 112×112 cloth faces; `curtain_point` places both cloth and sampled
cord geometry on the same folds. Do not use long straight cord segments across
those folds: they can disappear behind the cloth. The new relief material is
an owned copy with lighting enabled, leaving earlier native-palette paint intact.

Armor now separates native painted plates from bright physical rims and dark
articulated seams. Closed visors, central helmet ridges, neck bands, finger
segments and low boot lames use the existing cached primitives. Plate lighting
is isolated from the source scenery material; the earlier whole-body image is
no longer stretched over every joint/rim. Do not attach flat visor/skirt pictures
in front of the figure; they detach from the sculpted silhouette in side views.
The single source view still limits unseen shape and projection accuracy.

All eight native 16128/16129 vase pedestals now reuse the existing 16100 stand
geometry at its smaller source scale, the shared turned urn profile, source
lacquer/ceramic crops and separately carved original gilt faces. Thin gilt lines
edge the dark wooden caps. 16128 and 16129 face opposite sides of the original
hall; preserve every source cell and existing blocked tile. Mesh preparation
appends relief once before caching, never when placing another instance.

Preparation appends three scenery tiles without enlarging the 512×1024 atlas.
Four new carving features enlarge only the carving color/depth atlases from
512×128 to 512×256 (320 KiB more decoded RGBA8 color plus L8 depth before mips).
The 29 earlier scenery tiles and four earlier carving color/depth tiles remain
byte-identical at their original positions. The native archive images are intact.
The six seeded floors, 96 enemies on each floor and the original 32 death-ledger
slot identities are unchanged. Use `ruby_court_details_test.gd -- --east-il-road`
for the combined source-cell, relief-bound, repeated-setup and populated route
checks. Evidence is under `build/Other Files/Asset Toolkit/Ruby Court Details/`.

Final detail counts: armor 9,312 triangles per variant; curtains 11,730/13,002;
small vase stands 1,298 each. The seventeen affected placements total 100,300.
These counts exclude untouched palace furniture, flowers and architecture.


## Dressing mirror and flower arrangements

The remaining tall dressing mirror 16223 and all nine 16218/16219/16232 floor
arrangements now use `forest_black_prayer_art.gd::floral_prop`. The mirror keeps
its original static glass paint on a planar face over a solid back, separate
carved cabinet relief, gilt rails, turned vases and two white bouquets. The
source glass crop excludes the original attached flowers so those bouquets are
not baked into the glass as well. Its fitted height stays below the 8.5 ceiling.

The arrangement profiles stay distinct: narrow warm/yellow 16218, wider violet/
gold 16219 and low pink/ivory 16232. Source paint supplies the pot surfaces;
`recover_ruby_scenery.py::BOUQUET_CROPS` and `bouquet_palette` record the native
petal/leaf colors. The same recipe owns the added mirror paint and carved face.
The source sprites remain intact. Bouquet branch depth, flower shapes and
unseen mirror/cabinet faces are fitted interpretations of 2D art.

Reuse `flowers_coral.glb`, `flowers_ivory.glb`, `flowers_blue.glb` and
`leafy_shrub.glb` from `assets/models/environments/wind_meadow/`; their editable
masters remain under `assets/blender/environments/wind_meadow/`. The existing
`forest_wind_meadow_assets.gd::source` owns imported meshes/transforms. Native
palette variants copy vertex-color arrays without changing those shared source
arrays. Lower stem vertices converge into each vase mouth during cached mesh
assembly; the upper flowers retain the reused models. Added shrub foliage
matches the source's dense bouquets. Preserve the source double-sided petals/
leaves. Never modify the original imported mesh or material to tint a bouquet.

Four unique meshes place 33,453 triangles across these ten source placements:
16218/16219 are 2,883 each; 16232 is 3,144; 16223 is 6,984 including its two
bouquets. Sixteen colored part variants and four complete assemblies are cached
at setup. The original source cells, blocked tiles and gameplay ownership stay
unchanged. There is no wind controller or per-frame rebuild for these interiors.

Six appended scenery tiles grow its atlas from 512×1024 to 512×1280. One new
carving feature grows color/depth from 512×256 to 512×384, adding 832 KiB decoded
RGBA8+L8 before mips/engine overhead in total. All 32 earlier scenery tiles and
eight earlier carving color/depth tiles remain byte-identical in place. Use
`ruby_mirrors_flowers_test.gd -- --east-il-road` through Play Goemon for the
populated six-floor route, source-array preservation, stem contacts, reflection
planarity, compound bounds and repeated setup. Evidence belongs under
`build/Other Files/Asset Toolkit/Ruby Mirrors Flowers/`. The six floors stay
random with 96 native enemies each; Ruby's original ten-member party stays intact.

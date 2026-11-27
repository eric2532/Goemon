# Il and Saint Laruka

Explore maps 2000 (伊爾村 / the requested 一耳村) and 2300 (聖拉魯卡村)
retain their existing travel, NPC, dialogue and quest owners. No app export is
needed; use `/Users/eric/Desktop/Play Goemon.command`.

`tools/prepare_il_laruka.py` reads the adjacent Magic Power client archive and
the existing pinned warp reader. It follows both villages' links to 19 interior
IDs. Eighteen have client caches; the missing 2307 plan is recovered from the
pinned CGMSV server map under `assets/references/crossgate_laruka_basement/`.
Its paired 2306 map matches the client exactly. Source headers identify 2306
as the food shop and 2307 as the materials shop, correcting the old church labels.
The source ascending/descending stairs place the materials shop upstairs;
the actual underground workshop remains map 2303 below the equipment shop.
The original 2306 (7,3) ↔ 2307 (6,5) connection and existing behavior remain.

The preparer owns `data.gd`, the opaque native paint atlas, stone surface tiles,
rectified building paint, Laruka's original ground atlas/index, the chief's
lossless rooster crop, the recovered lower-room floor atlas, and `provenance.json`.
Originals remain read only.
`FORMS` keeps the visible building-foot/roof study in original image pixels.
`forest_il_laruka_buildings.gd` assembles coherent solid houses from those
footprints and measured facade/roof heights, with separate native wall, roof,
door, shutter and sign patches. Entire building pictures are not projected
over their unseen faces. The shared civic office supplies 10603/10607. Il's
chief retains its octagonal body, spreading thatch tiers, raised lantern and
rooster, capped ridge ornaments and framed windows. Laruka retains tiled timber
houses, the raised two-storey/two-door shop, pink food-shop/hospital roofs,
open chimney flues, pipe chimneys, the pub's sign/rails, equipment crest and
food display. Gables and opposite walls have complete timber framing and native
window/door paint. Hidden surfaces and depth remain interpretations of single-view
artwork; they are not recovered original 3D meshes.

`forest_il_laruka_art.gd` accounts for every available exterior object at its
original cell, reusing native scenery meshes and editable Cross Gate flora.
The established gate/lookout assemblies retain the original entrance anchors;
their native gate-group pictures are excluded from duplicate rendering. Furniture
and walls use the same native solid builders and shared mesh cache, batched
per graphic. Native ascending stairs render once; descending stairs sit below
their source floor openings, preserving the existing walk grid and warp owner.
The supplemental atlas is registered once with the original-map
paint catalog because native sign/wall builders resolve source pages there.
There is no new frame update or gameplay owner.

Native compound footprints replace generic exterior house collisions. Tree
trunks, fences and gate pieces remain physical. Laruka's near-gate copies use
the same source silhouettes on the immediate road approach. Il remains part
of the connected East Gate landscape. No route back to Falan is rebuilt.
Native 12500–12535 shoreline caps stay at ground level with rock descending
to water. Log footbridges use shallow parallel logs rather than firewood piles.

Regenerate and check:

```sh
python3 tools/prepare_il_laruka.py
python3 -m unittest discover -s tests/forest-shrine -p test_il_laruka_source.py
/Users/eric/Desktop/Play\ Goemon.command --headless --script res://tests/forest-shrine/il_laruka_geometry_test.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/il_laruka_review.gd
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/il_laruka_review.gd -- --details
/Users/eric/Desktop/Play\ Goemon.command --script res://tests/forest-shrine/il_laruka_house_views.gd
```

Evidence and separate village checklists live in
`build/Other Files/Asset Toolkit/Il and Laruka/`. `Source/` contains native map
renders and building/fixture contact sheets. `Before/` and `After/` use the same
fixed camera coordinates. The review checks coverage and selected live doors;
it is deliberately not a full street-by-street walk or performance benchmark.

The former 38046/38051 gap is resolved: the DAT IDs expand to original map
serials 238046/238051 in the EX pack. The adjoining 38043/38044 also expand;
the old unexpanded lookup selected portrait images. All 15 source curb/bank
placements now use the correct cap and brick paint, with supported walking
surfaces. Ground 25290 expands to paving 225290 for the 60 waterfront paving
cells. `laruka-mask.png` changes only the cap cells in the existing land mask.
The courtyard's top/skirt uses rectified native paving/brick paint at fixed
world scale instead of stretching floor art down the bank. Its mesh follows the
existing terrain triangles; collision is retained. Meadow scatter is excluded
from the source paving and cap cells. `quay-cells.gd` is generated from map 2300.
See `assets/references/crossgate_laruka_waterfront/` for source images, hashes
and the map-ID rule. No graphic is currently missing in either village's scope.
Reverse faces and hidden depth retain the interpretation limits above.

# Freyja west approach and Falan arrival

The saved test uses `terrain_detail: "freyja_west_gate"` on Standard Wind
Meadow. The layout is in
[`forest_freyja_west_gate.json`](../../../tests/forest-shrine/reference/maps/forest_freyja_west_gate.json).
The map editor can still move scenery and structures. The shoreline and bridge
are fixed terrain features at the original test scale.

`layout_mask.png` records terrain categories from Magic Power's decoded
Blue CG caches `map/0/100.dat` and `map/0/1000.dat`. Shared west-gate object
anchors and paving align Freyja coordinates to Falan coordinates by subtracting
(356, 107). One source tile is 3 m, with world X/Z equal to
`(3 * (tile_y - 194), 3 * (429 - tile_x))` in Freyja coordinates. The image
begins at (-84, -90) in world metres. The sample is (166–224, 459–342) in
Freyja Y/X, with image rows decreasing along the source X axis.

Red marks water tiles 5000–5008 and the water under the original paved bridge
strip. Green marks dirt 5198–5233 and 6400–6409. Blue records light masonry
and darker city streets. Alpha fades the cropped terrain into the surrounding
valley. Gate foundations and the banks at the edge of the study were adjusted
for the existing 6 m structure grid. In the combined **Freyja and Falan - Test**
save, the landing continues into the matching city streets. Walk through the
arch to enter Falan. In the other direction, the road crosses the marsh on a
causeway and branches into the first countryside routes.

The original gate, walls, farm roofs, trees, and masonry textures are reused
from the Wind Meadow kit. `round_gate_tower.tscn` in the Wind Meadow building
folder is the editable tower source. `forest_freyja_art.gd` authors the shared
bridge arch, rails and animated water plane. Its deck height and bounds agree
with the terrain used by physics and the native army.

Run `tests/forest-shrine/freyja_west_gate_test.gd` through Play Goemon with
`--headless --script` to check save/load, walkable bridge support, and the
blocked moat.

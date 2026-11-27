# Arcas and Wind Tower source candidates

These fourteen complete source layouts remain gated for review. Normal quest
access, full scenery and encounter-rule verification are unfinished. The full
Sokia + Venoa goal is recorded in `assets/maps/falan/sokia/README.md`; this branch
does not replace its surrounding-map and complete encounter scope.

`tools/prepare_sokia_wind_tower.py` owns this catalog, source encounter data and
source NPC/event records. Original source pixels, crop origins, footprints, map
cells and flags must stay intact. Regenerate the stage first; source checks and
canonical runtime evidence are under
`build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Wind Tower/`.

The shared measured-wall workflow owns the eight recovered wall forms:
17310/17316/17362/17364 and 17312/17314/17360/17366. Regenerate
`assets/maps/falan/university_region/ice_walls.json` with
`tools/prepare_university_ice_walls.gd`; `--check` verifies it without writing.
All64earlier profiles and the first four Wind profiles are preserved. Source
edge slopes determine facing. Exclude this family's uniform RGB20grey occluder
from the measured contour while retaining its dark coloured paint. The scoped
2pixel contour tolerance avoids dense pixel-scale geometry. Source17312/17314
are wholly grey backs; the matching17316/17310fronts supply inferred 3D paint.
Their original grey sprites remain intact. Preserve native void and source
anchors rather than filling black space or moving fragments onto the ground.
Depth and unseen faces remain inferred.

The shared `forest_original_map_solids.gd` column owner reuses
`forest_coastal_buildings.gd::kili_round` for17309/17311/17315/17317. Exact bright
shaft-detail registration places all four at the same world-screen anchor with
no mirror. The joined variants' larger crops contain attached walls; use the
complete17309body's height/radius instead of stretching a body to each crop.
Each variant retains its own original paint and native origin. Hidden round
sections and moulding volume are inferred; this is not recovered 3D geometry.
The registration evidence and first rejected bulky fit are retained in the
Wind Tower reports. Do not change the established ice-column fits when editing
this source family.

Inspect fixed gameplay-camera views and the original source composite before
extending a form. Measure scenery cost separately from the native army. A
source-data pass or a frozen-camera timing result does not approve all scenery,
enemy presentation or gameplay performance. Other tower columns, backs and
arches, outdoor301/302terrain and natural quest prerequisites remain required.

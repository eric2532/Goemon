# Ranger full-coverage hat

The approved v2.35 Ranger face and hair remain intact. The previous green hood
back and two gold opening cords left large scalp patches visible at the temples
and rear. They are replaced by a forest-green fitted crown with an integrated
nape panel, swept brim, chestnut band and one broad gold feather. The brim keeps
the painted eyes and eyebrows readable. Matte palette UV0, class colors and
chunky solid forms follow the Goemon style baseline without copying his design.

Rebuild from tracked native sources:

```sh
Blender -b --python tools/style_rogue_roster.py -- ranger
Blender -b --python tools/render_rogue_roster_review.py -- ranger --exported --headroom --portraits --output build/ranger-redesign/art/after
```

The standard generator dispatches Ranger to `tools/equip_ranger_hat.py`, which
first builds the existing roster anatomy and then replaces only the three hood
objects. The new four hat meshes are editable in `assets/blender/rogue/ranger.blend`.
The source exports through the established native batching helper to the live
styled model and regenerates its matching styled portrait.

Validation against the latest v2.37 source at `eb97bcc` passed 358 checks: eight
native pivots, all 131 retained meshes (121 body/weapon meshes), painted head
geometry and UVs, and all six existing solid hair meshes are exact. All six
exported body/weapon batches have identical geometry, UV, normal and index data.
All four new hat parts are closed positive-volume manifolds with no degenerate
faces. The crown occludes all 515 sampled upper/rear scalp points. The result has
7 mesh batches and 7,650 triangles. Other heroes, their v2.37 masks/equipment,
Goemon source/model/atlases, and the painted face atlas pass SHA-256 preservation
checks. No Godot import, runtime change or export is part of this art task.

Evidence is in `build/ranger-redesign/art`: `validation.json`, the before/after
four-angle comparison `ranger-hat-comparison.png`, and `after/ranger` front,
profile, three-quarter and back head renders plus shared-light Goemon full-body
comparisons. The actual exported GLB was used for all final renders. Inspection
shows a continuous covered crown/back, visible face and no exposed scalp or
unintended visible hair intersections. Gameplay verification belongs to the
parent release task.

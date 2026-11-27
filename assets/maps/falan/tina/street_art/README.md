# Live Tina street art

User-requested activation: 2026-11-23. These village-specific materials and
`forest_tina_village_art.gd` are now used by `forest_original_maps.gd` for the
six authored building families inside Tina, in day and night. The separate
northern approach house with the same source ID keeps its native mesh.
There is no preview toggle; J region travel uses this same live loader.

The builder is the editable source for real doorway/window trim, curved roofs,
the hospital cupola, the green round bay, the PUB and lean-to shed. It reuses
existing Source mesh, roof, cylinder and lathe helpers and existing spatial
MultiMesh batches. Native source maps and original painted masters remain
unchanged. Collision, doors, NPCs, interiors and other maps retain their owners.

Inside the stone-wall boundary, fence connectors are rebuilt with the existing
helper at 1.45 local units. The carved pillar, barrels, open box and plants use
owned scaled variants appropriate to the new house size. Shared meshes and
materials are never mutated. Ground retains the existing native atlas and source path/snow layout. The
experimental filtered ground image remains preserved but is not activated.

`tools/prepare_tina_village_art.py` reproduces the owned atlas derivatives and
records source hashes in `provenance.json`. The actual J key handler/menu choice
is exercised by `tests/forest-shrine/tina_street_art_review.gd`, including both
phases, all six families and three fixed gameplay cameras. Use
`-- --audit-out=res://build/Other Files/Asset Toolkit/Tina Recovery/Live Village Update`.
Focused setup/isolation contracts are in `tina_village_art_test.gd`; captures
and logs are under that same Asset Toolkit folder. This is a deliberate stylized
3D update, not a claim of pixel-identical original artwork or hidden geometry.

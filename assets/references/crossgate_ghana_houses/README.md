# Ghana residence source maps

`03804_room`, `03805_room` and `03806_room` are distinct original LS2MAP layouts
from the pinned classic archive in `provenance.json`. These replace the borrowed
3020/3021 interiors. The BlueCrossgate client cache lacks these three IDs;
classic archive recovery does not establish live BlueCG version parity.
No archived server program runs, and no dialogue is inferred from these maps.

Source exits are (3,10), (12,16) and (10,14). The western house's original return
lands at village (36,64), beside its (38,63) entrance. Keep that distinction.
Existing NPCs and quest behavior retain their owners; the recovered residences
have no verified indoor actor records and receive no invented inhabitants.

Reproduce with `python3 tools/recover_ghana_houses.py --check`,
`python3 tools/prepare_kili_ghana_rooms.py --check` and
`python3 tests/forest-shrine/test_kili_ghana_source.py`.
`tools/build_coastal_villages.py '../Magic Power'` prepares original floors and
every source furnishing through the existing coastal room/batched mesh owner.
Source pixels, map cells and editable geometry are retained; concealed 3D faces
are reconstructions. Evidence/checklists are under
`build/Other Files/Asset Toolkit/Kili Ghana Villages/`.

# Pinned Sokia server-map supplement

`tools/prepare_sokia_server_maps.py` prepares this separate package from the
source-pinned LS2MAP files in `assets/references/crossgate_sokia/maps/server/`.
It reuses the existing validated `reference_map()` decoder and converts the
floor/object planes offline into the existing MAP01 renderer format. No runtime
decoder, renderer, targeting owner or combat controller is added.

Thirteen previously unprepared layouts are included:5005,5006,5009,5010,13504,
13509,13512,15549,15556,15560,15562,15577,15800. Source11031/11039/11040 already
match the complete pinned layers in the East package and retain that owner.
Only15 graphics need new atlas rectangles. The other705 referenced graphics
reuse existing owners, including223 from East. All source RGBA crops are exact;
the old atlases and map catalog files are not repacked by this preparer.

LS2MAP has no client flag plane. `recorded=0` and
`source_flags_available=false` state that absence explicitly. The generated
0xc000 bits satisfy the existing renderer's visibility format; they are not
evidence of client recording, warp cells or original server flag semantics.
Walk bits derive from the existing original graphic-attribute decoder. Pinned
fixed-port candidates and conditional script declarations are retained
separately. Source layers remain exact, including blocked background100; its
visual treatment reuses the existing15525/15526 background-void policy.

`forest_original_map_art.gd::load_sokia_server()` loads the existing East art
before appending this supplement. Map ownership is initially review-only under
the existing `sokia_visual_only` contract. Per-map gate and roster QA must precede
activation; source events must not become unconditional walk-through shortcuts.

`encounters.json` contains original zones7037(map13509) and7039(map13512),
groups7032/7029/7031, levels25–27 and their source weights/probability ranges/
party limits. Existing East skins11(101422) and106(101503) are reused directly
through the South population/native owner. No Sokia actor-bank slots change.
Setup calls the existing selected-page helper, which restores these pages after
another East owner changes the shared material table. The other maps' absent
ambient rows and scripted-fight candidates are assessed separately; absence of
ambient rows is not a blanket safe-zone claim. Original probability-ramp,
count/stat binding and conditional event execution remain explicitly qualified.

Regenerate with `python3 tools/prepare_sokia_server_maps.py`; use `--check` to
verify the prepared output, or `--stage DIRECTORY` for a review package. Source
tests are `test_sokia_server_maps.py`; existing-renderer and direct native
fixtures are `sokia_server_maps_test.gd` and `sokia_server_maps_review.gd`.
Evidence is under canonical `Sokia Venoa Coverage/Server fixed maps/`.

Initial QA separates exact source/pixel checks, the 80-check prepared-renderer
pass, the 133-check repeated native-fight/page-return pass, and the 199-check GUI
run. The latter has 32 captures but is not visual signoff: five maps showed a
shared-atlas floor mosaic despite passing numeric checks, and 5005's house was
a generic painted box. Diagnostics and failed images are retained. No quest
route or map was activated from that failed visual review.

The retained five-page GPU probe then isolated actual upload corruption in
`atlas-1.png` and `university/atlas-0.png`; the other three bound pages matched
their source on every opaque/alpha pixel. All 62 warmed/fresh floor UVs matched.
`forest_original_map_art.gd::page_texture()` currently tests a setup upload from
exact prepared Image resources for those two pages and reuses them. Other pages keep their
existing imported textures. No PNG, atlas rectangle or source layout changed.
Regenerate/check these export-safe resources with the current-source Godot
script `tools/prepare_sokia_server_cpu_pages.gd` (append `-- --check` to check).
The original failed imported-page views and Metal diagnostics remain in the
report folder; corrected production views are reviewed separately.

The 5005 house now reuses the complete existing 11290 Coastal model. Its measured
15×12 metre foot frame matches the source 5×4 tile footprint, centred at the source
anchor plus (6,0,−4.5) metres without scaling. This preserves native origin
(−138,−365) exactly through the calibrated descriptor; roof/trim geometry is a
compatible existing 3D interpretation, not an exact silhouette claim. Source
walk/collider data and conditional entrances are unchanged. The source renderer
now passes 85 focused checks, including source foot placement and page reuse;
rendered validation and per-gate activation remain separate. The first production
repair run passed 43 numeric checks but was visually rejected: its floors still
showed corrupt GPU pixels, and the distant house view was cliff-occluded. Keeping
strong Image references also failed the measured GPU comparison. These failed
runs are retained; the late fixture substitutions are not production signoff.

The final setup path now calls `Art.finish_page_uploads()` at the existing map
build completion point, after later texture/mesh loads. It updates only pending,
newly-created CPU textures once, retaining the same shared RIDs. No upload,
retry or readback runs per frame or attack. A fresh production review without
fixture uploads/readbacks passed 103 checks on first and return visits to all
five affected maps: 21 fixed views, zero script/engine errors and zero Metal
fences. Every old map scene retired normally; all pending uploads finished.
The floors are visibly coherent in all views. The clear low front house view
shows its facade/foot frame; roof details are not judged from that angle.
Earlier failed runs and their Metal diagnostics remain historical evidence.

The map-source stage remains incomplete: `gate-npc-assessment.json` lists the
21 required source NPC roles and original-candidate/conditional gates still to
restore. The thirteen maps retain review-only flags while those per-map
contracts are recovered; fixed ports can activate as their own contracts pass.
This upload/geometry checkpoint does not establish quest or encounter-rule
completion.

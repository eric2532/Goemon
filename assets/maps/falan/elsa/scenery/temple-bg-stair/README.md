# 59530 source BG staircase

This is the installed staircase at the original 59530 door to 59534. It uses
the ordinary Explore scenery, HallSteps height, native movement and travel
owners. No direct warp, new room, blocked-cell override or new gameplay owner
is introduced.

Rebuild from the complete project:

```sh
python3 tools/prepare_elsa_second_stair.py
python3 tools/prepare_elsa_second_stair_support.py
python3 tools/prepare_elsa_second_stair_ground.py
python3 tools/publish_elsa_second_stair.py
```

The first three commands stage source reconstruction under the development
report's `Temple Interior/Central Assembly Candidate/Second Stair/`. The
publisher installs only this BG stair and composes the canonical BG floor
with the already installed entry pedestals. The private portal, wall and
central FG stair masks are deliberately absent from that composition. Do not
copy the private combined floor atlas into production. The archive is read only.

`mesh.json` retains original BG frame (6150,80)–(6460,464), eleven observed
riser/tread bands, source UVs and native floor XZ, six right/five left bracket
witnesses, blue rail silhouette and original charcoal/gold end posts. Height
does not shift the floor XZ along the original camera ray. `native-paint.png`
preserves selected original pixels. `body-native-witness.png` is the exact
32px source gray patch at (6400,304)–(6432,336); `body.png` mirrors it at a
consistent material scale around concealed plinth faces.

The source has no original 3D mesh. Rise scale 0.8, lower height 5.5361m,
upper height 7.5406m, corbel cross sections, wall thickness, concealed backs
and clipped upper continuation are inferred. Worn nosings keep flat original
tread centres and ease their edges within 0.15m of the inferred collision ramp.
No additional upper room or path is inferred. `data.json` supplies the existing
height owner with a lower ramp of grade 0.542005 and a 75×57 local grid at
0.5m spacing. The map-wide native field is 1195² samples; its existing revision
guard rebuilds it on navigation refresh, not every frame. This is setup/data
evidence, not a measured FPS claim. Every original blocked cell remains blocked.

Normal-production test `elsa_bg_stair_production_test.gd` passes 133 checks on
Metal: normal scene construction without private injections, native/model/
physics agreement, key-driven ascent/descent, repeat ascent, actual original
95,104 door → 59534(30,39), actual asymmetric return → 59530(95,80), and reuse
of the immutable stair mesh on re-entry. Peak walking height is 7.1729 world;
maximum grounded physics/model difference is 0.0955 world. Independently sampled
visible-surface gaps are 0.2254 above / 0.1677 below the rendered treads; the
moving-foot capture is inspected. These are distinct from physics agreement.

Source tests check archive-backed paint, original UV/XZ, riser evidence,
bracket witnesses, support hash and installed/staged correspondence. The
canonical floor has 59 CUT crops on one 512px page. The published pedestal
and stair photographs relocate (13,946 + 56,111 pixels). A separate explicit
57,712-pixel parent-paving mask fills concealed floor in 60 original owned/open
cells. Outside that mask, native RGB stays exact; only relocated-photo alpha
changes. CUT origins/extents, geometry, UVs and every walking bit stay unchanged.

The paving witness is the exact original local cobble patch at
(6192,444)–(6256,492), mirrored at native pixel scale. Its concealed pattern is
inferred. Selection is limited to absent/black BG or already relocated stair
photographs on original owned/open cells. All exposed source pixels stay exact.
No antialias-fringe repaint is enabled. Every selected pixel has existing CUT
geometry; the existing floor importer applies the repair directly to those
textures. No overlay plane or additional gameplay owner is installed.

A separate overlay quad left thin gaps because its sampling differed from the
original per-CUT UV insets. The shared CUT importer fixes that correspondence.
Shadow controls and a fringe repaint did not fix it; those trials are rejected.
Private and normal CUT-floor reviews each pass14 checks/four inspected Metal
views without runtime errors. Eleven source tests cover raw original pixels,
every scoped repair, complete original-CUT coverage and identical installed/
prepared files. The remaining temple columns, wall/arch joins and clipped upper
connection are still unfinished.

Use the desktop launcher for production movement and fixed art views:

```sh
GOEMON_WAIT_FOR_SCRIPT_SLOT=1 '/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/elsa_bg_stair_production_test.gd
GOEMON_WAIT_FOR_SCRIPT_SLOT=1 '/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/elsa_map_review.gd -- --labels=59530-second-stair-foot
GOEMON_WAIT_FOR_SCRIPT_SLOT=1 '/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/elsa_bg_stair_ground_review.gd -- --production --labels=59530-second-stair-foot,59530-second-stair-south-side
```

The broader temple, adjacent mixed architecture and island art checklist remain
unfinished. Original live-client height/upper contact parity is unverified.

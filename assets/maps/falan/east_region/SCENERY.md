# East region source-sized scenery

Keep original maps, graphic RGBA, source anchors, walk masks, actors and event
ownership unchanged. Generated images/JSON are derivatives. Edit the named
preparer or procedural mesh source, then regenerate; do not hand-edit generated
products or alter preservation hashes. Repeated placements share one immutable
mesh per source appearance through OriginalMaps batches.

| Family | Authoritative source and reused pieces | Derivatives | Enrollment/review state |
| --- | --- | --- | --- |
| 18 moulded/round room columns | `tools/prepare_east_room_columns.py`, `scripts/forest/forest_east_room_columns.gd`; closed profile helper from `forest_east_fallback_families.gd` | `room_columns/` | Live exact object owner, group7. Two asset views accepted; actual room/count review pending. |
| 38 beds, open chairs, benches, bookcases, cart, cloth line and hammock | `tools/prepare_east_room_furniture.py`, `scripts/forest/forest_east_room_furniture.gd`; complete Falan furniture/Tina bench/East village cart/Sokia hammock masters | `room_furniture/` | Live exact object owner after existing source-cell owners, group9. Stable91/0 asset review/14images accepted; actual source room/count review pending. |
| Cabinet/hutch/counter/table source references | `tools/prepare_east_room_casework.py`, `scripts/forest/forest_east_room_casework.gd`; Falan rounded furniture boards, rods, cabinet/bookcase shells and bank clock | `room_casework/` | 49 native references prepared; only19 candidate meshes. No production enrollment or visual acceptance yet. |
| 3 ceremonial hourglasses | `tools/prepare_east_hourglasses.py`, `scripts/forest/forest_east_hourglasses.gd`; shared round lathe plus existing furniture rod/oval primitives | `hourglasses/` | Candidate only; two-angle asset review queued. |
| Intact/destroyed Dragon Hourglass | `tools/prepare_east_dragon_hourglass.py`, `scripts/forest/forest_east_dragon_hourglass.gd`; ceremonial round glass/cap parts | `dragon_hourglass/` | Candidate only; no original catalog flag changes or production hook. |

Native fronts retain their source art. Important silhouettes and case/bed/chair
construction have physical depth. Small shelf book/door detail remains flat
inside the solid case; it is not projected over incompatible generic book rows.
Unseen backs, underside, board thickness, joints, glass curvature and supports
are inferred from visible construction and compatible local examples. They are
not original 3D measurements. Backs use independent lit wood/stone/metal rather
than stretching a front sprite around the model.

Dragon Hourglass composes the exact native painter order and origin from the
raw map and graphic aliases:15/13background pieces plus55/50original1001floor
placements. `*-native.png` preserves the full composition; `*-ground.png` and
`*-form.png` separate inferred occluded ground from the native curved-form paint. The destroyed form excludes
black void from the glass paint. Only observed round glass/caps/front supports
receive reconstructed depth; clouds, reflections and incidental painted motifs
retain flat native art. The suspended broken upper caps remain suspended.
No scenery recipe adds a route, actor, interaction or encounter.

Run each preparer with `--check` to verify native pins/derivatives. Asset preview
counters and parser checks do not establish actual-map placement, collision,
event behavior or visual fidelity. Actual cameras use
`tests/forest-shrine/east_room_fixtures_review.gd`; source/count census is under
`build/Other Files/Asset Toolkit/East Gate Region/Room Furniture/`. Candidate
studies are `east_room_casework_preview.gd` and `east_hourglass_preview.gd`.
Run them through the desktop source launcher; keep all captures/logs under the
canonical East Gate Region toolkit folder and review images separately.

### Current bounded additions (2026-11-27)

`forest_original_maps.gd` now early-dispatches only Eastern object10075 to the unchanged complete MagicShop master through `forest_east_classic_architecture.gd`. The original7x7footprint and tall native origin are fitted once; the caller adds noYscale. This does not enroll the other private architecture forms. Source/reverse accepted; actual two-map placement/clearance evidence remains pending.

Two Lektal annexes have372native/player/pet support checks and a separate15-check clean-timber material review. Four inferred.6m treads descend from1.2m deck support only on the original-open return cells; sourcewalk/warps unchanged. Their nearest main-house3255floating roof parts are a separate unhooked repair.

Root publication is bounded:16of19casework forms and7of30counter/table forms are live; the others remain private after partial visual rejection. Clock10567 now delegates to the thin mounted-detail owner, retaining its native hanging datum and source plane; the focused origin check passes60/0, while its fresh actual-room captures remain pending. The other30mounted details are private; their first gallery exposed reversed face/material assignment and an unsuitable timber sample, both corrected for a new31detail gallery.

Private candidates also include3small ceremonial hourglasses,2DragonHourglass compositions, the3255roof correction,1238504waterwheel,5market/crate forms, and15of53remaining classic furniture forms. All53source references are now recovered and censused:384object placements across the717fixed-map catalog. The15candidate forms reuse whole flower carts/open crates and existing extrusion/rounded-board pieces; no map hook is published. Counter/table references share49source references in room_casework. The old86candidate820/0construction result predates the wall-clock, roof-material and waterwheel updates and is historical, not current acceptance.

The second hourglass gallery has28checks/2geometry-budget warnings (57,819and56,357triangles for the giant compositions); visual problems remain in the giant rear glass and inferred floor. No canonical hourglass hook is published. The wheel now uses independent existing Tina timber11363at fixed1.35m pitch instead of stretching the original drawing across every rim/paddle; its fresh review is pending. The private3255roof still needs the revised slate/low-reverse review. Source-only references, parse checks and headless mesh checks do not certify rendered quality or reachable map placement.

`prepare_east_waterwheel.py` preserves original RGBA and exact43500(85,85) object38504/floor5001. Geometry reuses board/shaft pieces; native front paint is kept off hidden faces, and original water/foam is a separate flat motif. Twelve regular wheel sectors, frame joints, scale and hidden depth are reconstruction; the existing aquatic vertical offset is reused. The wheel is static, with no added collision, interaction or event. Review source/reverse before any hook.


### Whole-source follow-up, 2026-11-27

The complete background census covers717fixed maps. After per-placement native review,10maps contain structural background bodies and707are negative for a new body; shared family tiles alone do not prove a structure. Six ancient-root compounds, the Minokia stilt cottages, Kanabella houses and the earth-mouse statue remain explicit reconstruction work. Distant panoramas are a separate presentation item, not walkable structures. Reports are under `Background Layers/`.

The existing Alyut owner still draws its partial cached source despite the catalog having full restored2400bytes. Unknown cache cells add301art placements including79cliffs; these need the private whole-source owner completion. Il2000unknown-only completion is also in progress: preserve all59known client differences (56water-frame variations plus tree/flower choices), fill only4,107unknowncells, and retain the existing village/quest owner. Source catalog completeness must be updated with the bounded Il semantic-compatibility proof after validation.

Habaru11003/04/05has650restored unknown cells in total, all closed BG100rock filler withoutPG1objects in both source and existing walk masks; no new passage, stair, actor or room is omitted there. Current cave-wall appearance remains separate from this coverage proof.1155and11028are fully recorded.

Blue17197/17199are connected counter modules, not chests. Their nine-piece family17196..17204nowhas private exact source references, a fixed3m module study and an assembled33514gallery pending.17196/17198currently taking a lectern route is part of that correction. No counter-family hook is published, and concave/outer corner silhouettes need actual assembled review.


Mounted-detail publication: the corrected31asset gallery passes75checks with12source/reverse captures, all inspected. Source-facing native lettering is no longer mirrored; independent timber/metal/paper backs are retained. Clock10567stays in the casework scope; the other30details now use East OBJECT group15 after contextual owners. Their raw eligible census is226placements in115maps, with3legacy-owner exclusions explicitly listed. Five actual-map views/batch checks are queued; asset acceptance does not certify adjacent walls or quest behavior.

The Il compiler now preserves all6,693recorded cells and fills4,107unknowns, using same-object water5000..5008frame equivalence only for2000. All59recorded variants remain byte-exact;56are water frames and3are the existing tree/flower choices. The complete717map supplement now reports no incomplete layout rows. Independent source tests14/14pass. Il shore caps and Alyut whole-source runtime integration remain unfinished.

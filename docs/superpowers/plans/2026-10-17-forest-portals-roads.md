# Forest portals and roads implementation

Spec: ../specs/2026-10-17-forest-portals-roads.md. Work inline in the existing dirty workspace, preserving unrelated edits and Original Map. No reset or commits.

- [x] Add failing tests for old-map compatibility, portal rotation/protection, road strokes/undo/save, real portal spawns, road guidance/combat interruption and giant safety.
- [x] Extend document/model with optional portals and roads; isolate spawn/road helpers in forest_routes.gd. Preserve default no-portal behavior and wave accounting.
- [x] Add procedural visuals, portal preview, road brush/stroke input, width selection and selection/delete. Reuse saved-map lifecycle.
- [x] Verify headless and native integration, existing map/editor/spawn/role regressions, focused independent review; fix important issues.
- [x] Export/sign/test packaged app, preserve previous build, install, verify native boot and record results.

Review focus: portal congestion/visibility cannot consume pending units; multiple portals and giants retain exact counts; curved/branched roads cannot loop or shortcut; typing/GUI/drag cancel cannot paint accidentally; old maps and Original Map retain behavior.

Review ledger: actor-clearance, off-road rejoin around terrain and retraced-stroke cursor issues were reproduced with failing regressions, fixed, and independently rechecked. Model/document31 and editor12 checks pass. Existing map, spawn, role, HUD and original-world regressions pass. No outstanding findings from the focused review.

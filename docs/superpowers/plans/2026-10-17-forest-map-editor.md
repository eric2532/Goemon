# Forest map editor implementation

Spec: ../specs/2026-10-17-forest-map-editor.md

Work in the existing dirty workspace and preserve prior changes; no commits or resets. Implement inline, with a focused independent review after integration. User authorized implementation and preservation of the current map.

- [x] Document: add a regression test for immutable-original loading, edits, validation, undo, named atomic saves and reload. Observe failure before implementing forest_map_document.gd. Store the original snapshot in assets/maps.
- [x] World: extend ForestModel.reset with an optional layout, retaining default behavior. Rebuild map-owned render/collision nodes on application and rebuild navigation/worker jobs. Verify original parity and changed collision/navigation with the integration fixture.
- [x] Editor: add a preparation-only Map Editor button, paused editing toolbar, world selection/ghost, rotation/deletion, undo/redo, name field, saved-map picker, unsaved-work dialog and Play Map. Route inputs before existing construction handling; retain pan/zoom. Use current balance on fresh play and retain custom layout through restart.
- [x] Verify: document and real-scene integration tests, existing Forest model/world/lifecycle/HUD/view/combat regressions, native screenshots at 1280×800 and960×600, focused review. Repair important findings.
- [x] Rebuild: export and sign macOS, test the packaged map editor/original recovery, archive the pre-editor app visibly, install Goemon.app, verify native boot, record results and usage.

Review focus: malformed/oversized saves never mutate an open map; dialogs and text focus never trigger shortcuts; preview has no gameplay spend or simulation; restart uses the selected layout; original map and training area remain accessible.

Verification ledger: document35 and editor27 checks pass. Review found name-field focus and stranded-worker route issues; all fixed with observed failing regressions and rechecked independently. Lifecycle/definitive tests now isolate saved settings, and the hidden-raider fixture excludes the separately tested visible dummy. An unrelated Knight-bash clock assertion in rogue_test fails on both the pre-editor packaged build and current source; no combat code changed for it.

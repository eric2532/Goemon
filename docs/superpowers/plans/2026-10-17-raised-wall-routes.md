# Raised wall routes implementation plan

Goal: ship the two-route wall layout, elevated enemy movement, visible spawn portals and preserved old map in a rebuilt app.
Architecture: optional rampart segment metadata in schema1 maps; one shared height/clearance helper for renderer, nav, spawn and movement. Preset asset feeds the existing map document/editor. Existing flat model defaults stay unchanged; game default chooses the new preset.
Spec: docs/superpowers/specs/2026-10-17-raised-wall-routes.md
Tech: Godot 4.6.1, GDScript, JSON, native collision.

- [x] Snapshot touched sources and original map hash; write failing integration tests.
- [x] Implement preset data, bounded validation and round-trip preservation, height and cliff clearance helpers.
- [x] Build solid stone ramparts/ramp, merged-edge battlements, elevated portals, height queries and terrain picking.
- [x] Integrate elevated spawn/movement/guidance/AI line of sight and targets; verify all four roles including giant cross junction and descend.
- [x] New default and preset button, preserve Original Map and custom map precedence; frame map, reveal architecture landmarks.
- [x] Headless and native gameplay/collision/editor tests, flat map and Ninja regressions; native visual inspection.
- [x] Fresh focused review, signed export, packaged tests, old-app backup, install and native launch.

Ruling: work in the existing checkout to retain user-authored assets and all previous uncommitted features. Preserve before snapshots; no resets or unrelated edits.

Review resolution: reserve ramp-toe footprints by segment/tile overlap, including zero-height endpoints. Two failing entrance regressions passed after the fix.

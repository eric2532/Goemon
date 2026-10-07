# Fire Siege Universal Controls Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Play Fire Siege with Goemon, Edo and ten Rogue heroes using camera-facing universal controls.
**Architecture:** Decouple roster availability from the cursor-camera flag. Adapt native class input and aim at the existing combat facade; preserve the original class action implementations except forward hook eligibility. Keep the original Fire Siege director and camera.
**Tech Stack:** Godot 4.6.1 / GDScript / native macOS export.
**Spec:** docs/superpowers/specs/2026-10-07-fire-siege-controls.md

## Global Constraints
- Preserve original map, waves, towers, combat damage/contact timings and authored class abilities.
- No free cursor or lock-on in Fire Siege; preserve illustrated branch and exports.
- C is evasion; E is extra utility; no duplicate evasion for native roll classes.

## Review Focus
- Switching or pausing while holding attack/block must release input.
- Restart must retain camera-facing mode and reset cached class state.
- Camera rotation during melee must not redirect an already committed strike.
- Hooks/blinks/leaps must respect cover, range and forward direction.
- UI must accurately describe every hero and allow Edo as well as Rogue selection.

### Task 1: Mode, aim and universal controls
Files: scripts/game.gd, player.gd, rogue_roster_combat.gd, assets/rogue/scripts/class_actions.gd; test scripts/fire_siege_controls_tests.gd.
- [x] Add runtime regression exercising Fire Siege roster/camera, native primary/secondary attacks in camera headings, C/E mappings, forward hook and lifecycle behavior; run against baseline and observe failures.
- [x] Enable full roster in original Fire Siege, preserve Goemon profile, implement camera aim and utility/evade distinction. Capture attack direction and preserve native action timings.
- [x] Run new tests and relevant original Fire Siege / class suites; fix regressions.

### Task 2: Player-facing flow and delivery
Files: game.gd, rogue_roster_picker.gd, hud.gd, README.md; test tour and export preset.
- [x] Remove cursor entries from menu; make Fire Siege setup/roster discoverable, with truthful class mappings and existing Edo choice.
- [x] Verify real menu paths, pause, switches, build/draft and restart in runtime tests.
- [x] Record and inspect actual gameplay with Goemon, Knight, Mage, Explorer and all remaining heroes. Exercise camera turns, melee/projectiles, evade, jump and utility.
- [x] Export and launch a separate native Fire Siege app; verify packaged tests and native gameplay.
- [x] Obtain final review, fix material issues, commit and document results.

## Execution ledger
- Ruling: proceed with the approved in-chat control design and implement inline; no further design approval is needed for routine details under the user's direction to try this.
- Base: origin/feat/original-enemies-town-cap 4c3103e. Isolated worktree codex/fire-siege-universal-controls.

- Kept `start_defense()` as the existing direct entry point; introduced `choose_defense_hero()` for the menu flow so tactics tests and callers retain their contract.
- New control suite: initial baseline failed roster/camera availability. Expanded implementation passed 132 checks. Review added two reproductions (grown Edo assisted fireball steering and Goemon airborne attack turning); both failed before scoped fixes and passed afterward. Final source and release app: 134 checks, zero failures.
- Existing defense tactics, Three Gates, dogs and hero allies suites passed (logs copied with delivery). The separate legacy firecaster suite reports the same four failures on base 4c3103e and this branch: it still presses E for an Edo dodge that the base moved to C. No production change was made to disguise that baseline failure.
- Fresh code review completed by fire_siege_review. Both material findings fixed; original non-Fire-Siege targeting and airborne behavior preserved.
- Native export: dedicated `fire_siege` feature opens the original difficulty setup; universal arm64/x86_64 app with valid ad-hoc signature. Source editable models and artwork stay in this isolated checkout; illustrated 2D work remains separate.
- Delivery: /Users/eric/Desktop/Goemon Fire Siege. The video starts with a real live wave and then freezes AI/enables invincibility for readable per-class action demonstrations; ordinary gameplay settings are unaffected.
- Limitations: native class balance remains intentionally different. Explorer/Master Thief standard C evades need player balance feedback. Packaged headless test shutdown reports one dummy-renderer shader RID leak after all 134 checks; source run and visible rendering did not report gameplay errors. Not a new Linux release or GitHub release.
- Native launch verified in the exported app. User interaction was already active; read-only inspection showed Ninja on the original straight lane in the pause menu. Left that session intact instead of injecting controls. Input behavior was exercised by the real-engine action suite and recorded tour; a separate manual keyboard/mouse pass was not completed by the agent.
- Final packaged movie: 111.57 seconds, 1280×800, 30 fps. Inspected the live wave, per-hero samples, camera motion and roster. Local source, app and MP4 retained; no branch merge or release publication performed.

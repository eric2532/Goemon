# Ink Roster and Shrine Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver v2.52.0 with preserved character abilities, roster-wide ink-brush effects, hidden lock markers, and a buildable shrine gate.

**Architecture:** Implement two independently testable changes through the linked plans below, then validate their integration in one preview. Reuse existing effect admission, construction transactions, and wave ownership. Gate assignment and motion remain separate from player combat and shrine strikes.

**Tech Stack:** Godot 4.6.3, GDScript, ShaderMaterial, cached meshes/MultiMesh, Metal Forward+, universal macOS export.

**Spec:** `docs/superpowers/specs/2026-10-13-ink-roster-gate-design.md`, approved for planning on 2026-10-13.

## Global Constraints

- Reuse `/Users/eric/.codex/worktrees/fire-siege-spirit-effects/Sonic`, branch `codex/fire-siege-spirit-effects`; preserve the primary checkout, protected character models, and previous previews.
- Gate: 10 gold total; 5,000 HP; three-second nearby construction; eight attack positions; 20 base damage every 1.25 seconds per eligible attacker; another 10 gold to rebuild.
- Standard expanded map only: gate at (0,0,180), player start z=185, shrine z=220; 12-metre opening, side walls to x=±20, about four metres high.
- Preserve all twelve heroes, their combat values, Samurai’s five cuts/150-damage arrow/ten-second 5× ultimate, Magic Swordsman’s 100-damage/40-metre wave, and Ranger spread/curvature/aerial aiming.
- Preserve shrine 100/50 HP, one-HP strikes every 2.5 seconds, 300-enemy limit, five spawns/second, ten waves, tower/mine economy, exploration, discoveries, ice upgrades, and custom-map contracts.
- Retain quality and reduced-flash support, 2/3/4 live blade-ribbon limits, bounded geometry and displayed-frame impact admission. No new per-contact lights or unbounded per-frame nodes.
- Development first: automated crowd behavior/budget checks and actual renders; foreground FPS benchmarking and full-session performance claims remain deferred.
- Export a separate v2.52.0 app and ZIP using the exact existing Godot runtime; no push, merge, or release publication.

## Review Focus

1. A rebuilt gate must not trap enemies inside its panel or reclaim actors already past it. Gate plan Tasks 1/3.
2. A whole sword animation can finish between physics samples at boosted speed; the brush must remain visible without changing contact timing. Effects plan Task 1.
3. Original Goemon/Edo and Rogue heroes have different effect clocks; neither may leave stale effects or tick a shared pool twice after a switch. Effects plan Task 3.
4. A long update or death during windup must not replay gate contacts or reuse another actor’s slot. Gate plan Task 2.
5. Transparent-looking doors must actually permit player attacks/J aiming while solid walls still block them. Gate plan Tasks 1/3.

## Ordered execution

The independent parts are separate plans as requested by the writing-plans workflow:

- [ ] Execute [roster ink effects](/Users/eric/.codex/worktrees/fire-siege-spirit-effects/Sonic/docs/superpowers/plans/2026-10-13-roster-ink-effects.md) Tasks 1–3: materials, melee/projectile/impact treatments, original heroes, hidden lock marker.
- [ ] Execute [shrine gate](/Users/eric/.codex/worktrees/fire-siege-spirit-effects/Sonic/docs/superpowers/plans/2026-10-13-shrine-gate.md) Tasks 1–3: structure/construction, objective clocks/slots, movement and shrine integration.
- [ ] Complete release Task 7 below after both parts pass.

Preserve the user’s earlier execution choice: implement in this chat through
`superpowers:executing-plans`, then one independent final review. Do not dispatch
per-task implementers. Record RED/GREEN evidence and commit each deliverable.
The execution base is the commit saving these plans; inspect the linked worktree
before changes and do not reset it.

Run commands from the worktree with a task-specific variable:

```sh
goemon_engine='/Users/eric/Desktop/Projects_Codex/Sonic/backups/download-references/standalone-prototypes/Goemon-marc-prototypes-2026-10-10.JqoVC3/runtime/Godot.app/Contents/MacOS/Godot'
"$goemon_engine" --version
```

Expected version: `4.6.3.stable.official.7d41c59c4`. New game-attached suites
must have CLI hooks so the actual exported executable can run them. A valid
test run exits zero and prints its `_RESULT checks=… failures=0`; parse/runtime
errors are failures. Record known native headless shutdown diagnostics separately.

Verification commands referenced by the tasks use these exact forms:

| Suite family | Command and identifiers |
| --- | --- |
| Game-attached | `"$goemon_engine" --headless --path . -- --NAME-test`; NAME = `roster-ink-brush`, `shrine-gate-unit`, `shrine-gate`, `samurai-ink-brush`, `crimson-combat`, `magic-ink-brush`, `magic-swordsman-wave`, `fire-siege-controls`, `rogue-combat-upgrade`, `rogue-equipment-combat`, `attack-chain`, `power-combat`, `coin-scaling`, `firecaster`, `ranger-flight`, `ranger-storm`, `auto-lock`, `fire-siege-campaign`, `map-builder` |
| Standalone SceneTree | `"$goemon_engine" --headless --path . --script res://scripts/NAME.gd`; NAME = `combat_vfx_tests`, `projectile_query_tests`, `shrine_combat_tests`, `fire_siege_exploration_tests`, `fire_siege_structure_tests`, `fire_siege_state_tests`, `ice_tower_tests`, `neon_shrine_tests`, `map_document_tests`, `crowd_motion_tests` |
| Crosshair fixture | `"$goemon_engine" --headless --path . --script build/aim-lag/crosshair_runner.gd` |

Each command requires its result summary with zero failures and exit zero. For
exported-pack checks replace `--path .` with `--main-pack "$goemon_pack"`, where
`goemon_pack` is the extracted export's absolute `.pck` path. Native executable
checks use game-attached hooks; do not assume native export accepts external scripts.

### Task 7: Combined validation, independent review, and playable delivery

**Files:** modify `export_presets.cfg`; create `docs/fire-siege-mvp/ink-roster-gate-v2520.md`; create ignored `build/ink-roster-gate/checks.py`, `captures.gd`, `assemble.py`, and logs/results.

**Interfaces:** consume both plans’ suite hooks and gate/effect interfaces. Produce a universal app and archive under `/Users/eric/Downloads/Goemon-Fire-Siege-v2.52.0-Ink-Brush-Gate-Crosshair/`, with app name `Goemon Fire Siege Crosshair.app` and archive name `Goemon-Fire-Siege-v2.52.0-Ink-Brush-Gate-Crosshair-PREVIEW-macOS.zip`.

- [ ] **Step 1:** Extend the previous ignored release checker to run the three new suites (`roster-ink-brush`, `shrine-gate-unit`, `shrine-gate`) plus existing Samurai/Magic VFX, crimson combat, wave, full-roster controls/upgrades/equipment, Goemon attack-chain/power/coin, Edo firecaster, Ranger flight/storm, J lock, crosshair, effect-budget, projectile-query, shrine, exploration, districts, ice, construction/economy, and custom-map suites. Use the existing hooks/runners; do not infer success from an absent summary. Run affected suites after each task, then only broaden once for final integration.
- [ ] **Step 2:** Run combined source validation and render each hero’s primary/secondary, a confirmed impact, and representative ultimate; include all twelve heroes, dual blades, floor-contact Dragoon, airborne Ranger, and boosted Samurai. Capture the unbuilt/built/broken/rebuilt gate, transparent enemy view, attacking crowd, and HUD without lock circle/text. Allow deterministic capture freezing, record it, and make no FPS claim. Fix actual failures before proceeding.
- [ ] **Step 3:** Invoke requesting-code-review for one read-only independent review of the final change from the plan base, both implementation plans, and fresh evidence. Focus on the five Review Focus conditions and preserved abilities. Resolve findings with targeted regressions; do not repeat broad review/testing without a new unresolved issue. Require no remaining actionable findings.
- [ ] **Step 4:** Update only the existing `Fire Siege Crosshair macOS` preset version to 2.52.0. Run `"$goemon_engine" --headless --path . --export-release 'Fire Siege Crosshair macOS' build/ink-roster-gate/Goemon-v2.52.0.zip`. Extract with `ditto -x -k` to preserve executable permission. Rerun the checker against the exported `.pck`, run all three new hooks plus focused preserved Samurai/Magic abilities in the native executable, and inspect final exported-resource renders. Commit the implementation/release notes after checks pass.
- [ ] **Step 5:** Assemble the separate delivery with controls, version notes, exact results, source commit, renderer diagnostics, and `fps_verified=false`. Verify version 2.52.0, arm64/x86_64, deep/strict ad-hoc signature, 16 protected model hashes, and previous archive hashes; v2.51.3 ZIP SHA256 is `ce74375dc2a18b28bf14da51938ec8ed004d8edc40a57f92dab681fd798d2e45`. ZIP with `ditto`, verify CRC/SHA256, then extract it to a temporary directory and verify signature/version/executable permission/game-pack hash. Show the new app in Finder and provide app/ZIP links; preserve this worktree.

## Plan review status

The approved specification is covered by the two independent plans and release
task. Self-review checks names/types, costs/timers, all twelve heroes, collision
scope, slot/lifecycle rules, visual budgets, and delivery evidence. Awaiting the
user’s review of these plans before implementation; the execution method is
already selected.

# Ranger curved flight and third-shot combo implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline for this approved request.

**Goal:** Replace rigid Ranger arrows with varied, visible lateral drift, widen
the five-arrow fan, and make every third released LMB attack green and stronger.

**Architecture:** Ranger-only bounded flight offsets update the actual projectile
position and orientation; the native swept collision checks that curved path.
Count released LMB attacks independently of the melee combo timer. A fan is one
attack; RMB/3 never advances this counter. Ground shot three is a green arrow;
aerial shot three is a green fan. Preserve the v2.38 hat and fast roll.

**Tech stack:** Existing Godot GDScript, native mesh effects and macOS export.
**Spec:** User-approved explanation in this chat, 10 October 2026.

## Constraints and review focus

- Work only in `/Users/eric/.codex/worktrees/fire-siege-mvp/Sonic`.
- Smooth bounded drift, varied by arrow; collision follows the curve, not a straight proxy.
- Keep controlled aiming, projectile lifetimes, primary fire rate and downward landing shots.
- Fan step 0.24 radians instead of 0.18 (about 55 degrees overall).
- Third shot: 1.5x damage (101 ground / 38 per aerial arrow), 1.35x visual size,
  green energy mesh and segmented green trail. No new piercing behavior.
- Increment only on actual release; cancellation does not consume a shot;
  death/retry/hero reset clears progress. Secondary fan and Rain remain independent.
- Keep non-Ranger projectiles unchanged. No remote publication requested.

## Tasks

- [x] Add real-world tests for varying curved path positions/tangents, fan width,
  actual curved-cover collisions, normal aiming, 1/2/green-3 rhythm, cancellation,
  reset, secondary independence and aerial green fan. Run and observe failures.
- [x] Implement Ranger flight module, native release counter, wider fan and
  physical arrow / green power visual variants. Add the HUD's next-power label.
  Run focused tests and update intentional v2.38 fixture assumptions.
- [x] Capture rendered live normal drift, wide fan, green shot and aerial fan;
  review screenshots and sample real trajectory positions. Run equipment,
  controls and MVP regressions. Request one independent final code review.
- [x] Export v2.39 Fire Siege macOS, run packaged focused/rendered checks,
  compare mesh and package hashes, preserve v2.38 app and install tested app.
  Record verification and controls. Leave changes locally reviewable.

## Ledger

Confirmed existing v2.38 app and all previous edits are in the latest MVP
worktree. The older Desktop checkout is not touched. No new worktree needed.

Initial RED: 24 checks, 12 intended failures. First GREEN: 24/0. Expanded
position/tangent/native-damage checks: 28/0. Equipment63/0, controls136/0,
MVP72/0, rendered26/0 with six captures. Reviewer found missing reset through
cancel(false): real lifecycle RED31/3, then GREEN31/0. Pause cancellation uses
cancel(true), preserving the armed third shot. HUD names shortened to avoid
clipping. Package validation: focused31/0, equipment63/0, rendered26/0.

Ruling: lock the automated tour's native mouse-camera input while using explicit
yaw — macOS capture/release emitted motion that steered a packaged aerial volley
away from fixed targets. No gameplay camera change. Source/package now both
record yaw0 and all five38-damage impacts. Installed2.39 matches tested package
hashes and strict signature verification;2.38 preserved in the backup app.
The older Desktop checkout remains clean. No publication or commit requested.

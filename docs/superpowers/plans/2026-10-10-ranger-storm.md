# Ranger random coverage, accelerating combo and snap roll

> **For agentic workers:** Use superpowers:executing-plans inline.

**Goal:** Execute the user-approved Ranger update in the latest Fire Siege game.
**Architecture:** Replace periodic sideways flight with precomputed random smooth
waypoints. Normal bends are broad; power bends are shorter and more irregular.
Actual sampled segments retain native collision. Existing hit-chain count drives
Ranger firing rate, with no new global timer. Rain powers all release paths.
**Tech stack:** Godot GDScript and existing native meshes/macOS export.
**Spec:** Approved descriptions and final “execute this” in this chat.

## Constraints and decisions

- Latest `/Users/eric/.codex/worktrees/fire-siege-mvp/Sonic` only; baseline app2.39.
- Normal lateral sweep about1.4–1.9m; green about2.2–3.0m at normal size.
  Smooth, finite random waypoints, always moving forward. No teleport or homing.
- Green changes bend direction more often than normal; every third LMB remains
  green outside ultimate. Rain makes all LMB, RMB/3 and aerial releases green.
- Fire-rate chain multiplier1+.12 per live hit link, capped3.0; reset when the
  native chain expires. Preserve base upgrades and non-Ranger timing.
- Camera-relative movement input determines C roll, including diagonals.
  No input uses existing body facing. Duration.15sec, speed46m/sec (6.9m),
  cooldown.55sec, centered full tumble with cover collision.
- Preserve full hat, arrow sizes, five-arrow fan, downward aim, damage tickets.
- Wider random paths intentionally replace the guarantee of hitting five fixed
  points on the old launch rays. Tests use broad enemy coverage and native hits.

## Steps

- [x] Write/run failing tests for broad non-periodic path, green direction
  changes, true hit-chain cadence, all ultimate arrow types and expiry, eight
  WASD roll directions, no-input facing, distance/time, walls and lifecycle.
- [x] Implement trajectory, ultimate, combo speed, snap roll and HUD/data.
  Run focused checks and adjust intentional previous-version assumptions.
- [x] Render latest MVP tour with actual sampled trajectories, ultimate and
  fast roll. Run equipment, controls and MVP regressions and independent review.
- [x] Export/test macOS2.40; preserve2.39 and install verified latest app.
  Record hashes, screenshots, counts and docs. No remote publication.

## Ledger

Reused latest worktree with all v2.38/v2.39 edits intact; installed app2.39.0.


Initial focused RED:57 checks/34 failures. Updated focused GREEN:70/0,
equipment63/0, retained flight31/0, controls136/0, MVP72/0. Source rendered
tour38/0 with eight captures. Full model hash equals v2.39. Actual native
fan damage125, Rain aerial damage190, roll6.900m. Reviewer found trail clipping
(67/1 before fix) and world-space fading (70/2 before fix); both regressions pass.
Sustained max-combo/upgraded Rain with held LMB/RMB reached80 concurrent arrows
and700 FX before optimization, then123 FX with one reusable trail mesh per
arrow. Three simulated seconds took3.002 real seconds on the rendered M3 run.


Exported universal Fire Siege macOS2.40.0 passes202 packaged checks with zero
failures (70 focused,63 equipment,31 retained flight,38 rendered/eight captures).
Strict code signatures pass; installed executable/PCK hashes match the tested
app. Previous2.39 preserved at `build/Goemon Fire Siege before Ranger Storm
v2.39.app`; latest remains `build/final-macos/Goemon Fire Siege.app`. Desktop
legacy Git checkout verified clean. Hashes/results in ranger-storm/build-info.
No commit or publication. All approved implementation and verification complete.

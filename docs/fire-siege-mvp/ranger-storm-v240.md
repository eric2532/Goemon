# Fire Siege MVP v2.40 — Ranger random coverage and snap roll

This update is based on the latest local v2.39 Fire Siege MVP in
`/Users/eric/.codex/worktrees/fire-siege-mvp/Sonic`, branch
`codex/fire-siege-mvp`, with prior v2.38/v2.39 work preserved. The obsolete
Desktop checkout and v2.27 export preset are untouched.

## Behavior

Each Ranger arrow follows its own randomized, smooth lateral waypoints during
actual flight. Normal arrows sweep 1.4–1.9 metres to either side, with bends
4.2–6.2 metres apart. Green power arrows sweep 2.2–3.0 metres, changing lateral
direction at shorter irregular intervals of 1.4–2.5 metres. Amplitudes and bend
spacing scale with growth/range. These are bounded sideways sweeps with forward
travel; tips follow the sampled tangent, paths fade smoothly at full range,
and terrain/enemy collision sweeps the actual curve. No homing or teleporting.
Wider coverage can miss a small enemy placed exactly on the old straight ray.

Every third **released LMB attack** is green power, preserving the existing
67/101 damage ground shots and 25/38 damage per fan arrow. Aerial fans count as
one release; RMB/3 does not advance this counter. Canceled draws preserve the
pending third shot. Actual death/revival, reset and hero switching clear it.

The existing hit combo now increases Ranger firing speed by 0.12 per confirmed
attack link, up to **3× base speed**. Maintaining hits keeps this faster cadence;
misses eventually expire the 1.75-second native chain and restore base speed.
Existing speed upgrades multiply the base. Other heroes retain their original
combo speed. The HUD shows the live FIRE multiplier and powered release state.

**R Rain** lasts ten seconds and makes all Ranger release paths green/powered:
LMB ground shots, RMB/3 five-arrow fans, and double-jump downward fans. Power is
decided at release time; arrows already released retain power after Rain ends.
Outside Rain, the two-normal/third-green LMB rhythm returns. The wider five-arrow
fan and downward aerial aiming remain, with original projectile speeds/ranges.

**C** rolls for **0.15 seconds**, at **46 metres/second**, covering approximately
**6.9 metres** on clear ground; cooldown is **0.55 seconds**. Current WASD input
selects camera-relative direction, including diagonals. With no movement input,
body facing selects the direction. The full centered tumble, native cover
collision and short roll protection remain. Rolling cancels an unfinished draw.
The fitted head-covering hat and larger arrow models are preserved.

Curved trails use one reusable mesh/material per arrow with bounded recent
points, rather than allocating a separate trail node on each physics frame.
The visible path ends at the same collision contact as the arrow.

## Verification

- Focused Ranger storm suite: **70 checks, zero failures**. Includes actual
  release cadence, all Rain arrow types/expiry, eight roll directions, real
  WASD input, facing fallback, collision, trail reuse/world-space fading and
  lifecycle. Five seeds × three
  growth scales × two arrow types verify full-range, bounded continuous paths.
- Equipment: **63 checks, zero failures**. Coverage fixtures test total native
  damage across an area instead of five obsolete fixed straight-ray targets.
- Retained flight regression: **31 checks, zero failures**.
- Controls: **136 checks**; MVP: **72 checks**. Zero failures.
- Before implementation: 57 focused checks, 34 failures. Review's collision
  trail test failed before clipping the trail and passed after the fix.
- Rendered source tour: **38 checks, zero failures**, eight captures. Actual
  native fan damage125, aerial Rain damage190, roll6.900m, live combo6 links
  at1.72×. Geometry hash exactly matches v2.39 (full fitted hat preserved).
- Sustained rendered load: both LMB/RMB held for180 physics frames, combo3× and
  upgraded base2.25×. Peak80 powered arrows and123 effects, below the700 cap.
  Wall time3.002 seconds for three simulated seconds on this M3 fixture.
  This is a focused load fixture, not a full-wave performance benchmark.
- Independent review caught trail clipping and world-space fade errors. Native
  transformed-vertex regressions failed before each fix and passed afterward.
- Exported universal macOS app: **202 checks, zero assertion failures**
  (70 focused +63 equipment +31 flight regression +38 rendered). Eight package
  captures; all five Rain aerial arrows deal38 each. Package load fixture
  remains below the700-effect cap. Rendered package exits without errors.
- Strict signature validation passes. Installed executable and PCK SHA-256
  exactly match the tested export. The previous v2.39 app is preserved.

## Local build

- Installed: `build/final-macos/Goemon Fire Siege.app` (**2.40.0**).
- Backup: `build/Goemon Fire Siege before Ranger Storm v2.39.app` (**2.39.0**).
- Archive: `build/Goemon Fire Siege Ranger Storm v2.40.zip`.
- Package screenshots and samples: `build/ranger-storm/packaged-tour/`.
- Signature/hash/measurement manifest: `build/ranger-storm/build-info.json`.
- No commit, remote publication, or legacy-game changes in this update.

Evidence directory: `build/ranger-storm/`. Rendered tours save screenshots,
world-space samples, random waypoint arrays, damage, geometry hashes and input
observations. Headless suites have existing shutdown resource warnings; all
assertion results are recorded separately.

```sh
godot --headless --path . --fixed-fps 60 -- --ranger-storm-test
godot --headless --path . --fixed-fps 60 -- --rogue-equipment-combat-test
godot --headless --path . --fixed-fps 60 -- --ranger-flight-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-controls-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-mvp-test
godot --path . --max-fps 120 -- --ranger-storm-tour
```

Package sustained-fire measurements: `{"base_rate": 2.25, "combo_rate": 3.0, "peak_arrows": 80, "peak_effects": 125, "physics_frames": 180, "wall_seconds": 2.997758}`.

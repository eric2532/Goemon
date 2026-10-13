# Fire Siege MVP v2.39 — curved Ranger arrows and green third shot

Work stays in the latest `codex/fire-siege-mvp` checkout, building on the local
v2.38 Ranger hat, fast roll and aerial fan. The older Desktop checkout is clean.

## Behavior

Normal arrows have wood shafts, metal heads and green feathers. Their actual
world positions drift sideways in broad smooth curves. Each arrow varies in
amplitude and bend length; left/right initial bends alternate. Tips follow the
flight tangent, and short connected trails follow the real path. This replaces
the bright straight beam appearance. Drift is bounded to 0.32–0.46 metres at
normal size, with an 18–24 metre bend wavelength and smooth muzzle/range-end
transitions. Green arrows drift up to 20% farther. This keeps aiming controlled.

RMB/3 fans span about 55 degrees (0.24 radians between arrows), increased from
41 degrees. All five arrows release together and drift independently. Rain
retains held repeat fire, and the double-jump fan still descends to real ground.

Each third released LMB attack becomes green power. Two normal ground arrows
deal 67 each, then the green arrow deals 101. The green mesh is 35% larger, with
an energy aura, green connected trail and release ring. If the third LMB attack
is aerial, all five downward arrows become green and deal 38 each instead of
25. Aerial fans count as one LMB attack. RMB/3 does not consume this sequence.
The sequence survives pauses and waits between shots; canceled unreleased
attacks do not count. Death, revival, reset and hero changes clear it. The HUD
shows **Green Power** or **Green Fan** when the next attack is powered.

The existing 36/34 projectile speeds, primary firing cadence, 60/20 metre
lifetimes, cover collision and damage attribution remain. Collision sweeps
the actual curved segments. Other heroes' arrows keep their previous behavior.

## Verification

- Focused flight/combo suite: 31 checks, zero failures. Includes sampled actual
  lateral movement, variation, tip orientation, bounded drift, wider cone,
  curve-only cover clear of the original launch ray, normal/normal/power rhythm,
  native damage, secondary independence, cancellation, actual death/revival,
  hero switching, reset and green downward fan.
- Equipment suite: 63 checks, zero failures, including controlled long-range
  aiming, five separate wider-fan targets, early/high aerial hits, cover,
  retained fast roll and other-class equipment.
- Controls: 136 checks; MVP: 72 checks. Zero failures.
- Rendered flight tour: 26 checks, six captures, zero failures. Real MVP picker,
  input, meshes, enemies and damage. Saved world-space flight samples accompany
  the screenshots. The preserved Ranger geometry hash is recorded.
- Independent review found a combo-reset issue; its real lifecycle test failed
  before the fix and passed afterward. No further actionable finding reported.

The packaged app passes 31 focused, 63 equipment and 26 rendered checks (120
total), with zero assertion failures. All five green aerial targets receive
38 damage. Its preserved Ranger mesh hash matches the source and v2.38 exactly.
Strict code-signature validation passes; installed executable/PCK hashes match
the tested app. Package screenshots and sampled trajectories are in
`build/ranger-flight/packaged-tour/`; hashes and paths are in `build-info.json`.

Installed app: `build/final-macos/Goemon Fire Siege.app` (2.39.0).
Backup: `build/Goemon Fire Siege before Curved Arrows v2.38.app` (2.38.0).
Archive: `build/Goemon Fire Siege Ranger v2.39.zip`.

The tour locks native mouse camera input while its fixture sets explicit aim;
macOS capture/release motion had shifted one initial packaged volley away from
its fixed targets. This affects only automated evidence. The corrected source
and package both record yaw zero and five 38-damage impacts. Gameplay mouse
camera behavior remains intact.

Headless suites have existing shutdown resource warnings. The rendered tour
exits without warnings/errors. Evidence: `build/ranger-flight/` and its
`tour/verification-manifest.json`. The plan and test ledger are in
`docs/superpowers/plans/2026-10-10-ranger-flight.md`.

```sh
godot --headless --path . --fixed-fps 60 -- --ranger-flight-test
godot --headless --path . --fixed-fps 60 -- --rogue-equipment-combat-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-controls-test
godot --headless --path . --fixed-fps 60 -- --fire-siege-mvp-test
godot --path . --fixed-fps 60 --max-fps 120 -- --ranger-flight-tour
```

# Rogue Battle validation

Rogue Battle is an opt-in Sky Descent mode. Existing characters, worlds, encounter directors, damage, growth, upgrades, skills, assets and legacy modes stay shared. The mode adds orthographic framing, ground-cursor aim, buffered tap/hold melee and pooled contact accents.

## Run

```sh
godot --path . -- --rogue-battle
godot --headless --path . -- --rogue-battle-test
godot --path . -- --rogue-battle-visual
```

The suite exercises the real input and damage paths. It checks mode selection, existing island counts and characters, angle and projection, cursor-ground correspondence, independent movement, jumps, deliberate single attacks, held combos, primary/secondary buffer expiry, one contact per target, unchanged damage and pickups, evade/dash cancellation and resume, grown-character projectile aim, Edo fireballs, interior cutaways, flight bounds, pause, restart, and restoration of the original camera and automatic triplet.

## Verified 2026-10-04

- `rendered-final.log`: **49 checks passed**, zero failures or engine errors, native Metal Forward+ on Apple M3.
- `headless-final.log`: **45 checks passed**, zero failures; this pass preceded the three additional world-view checks and skips mouse-capture verification unsupported by Godot's headless display. It reports an ObjectDB cleanup warning on exit. The final rendered pass is clean.
- `legacy-direct-attacks.log`: **20 existing checks passed**, covering manual attacks, coin toggles, sweeps, cloak effects and interruption.
- `legacy-attack-chain.log`: **61 existing checks passed**, covering attribution, damage bonuses, chain timing, ranged abilities and resets.
- `exported-app.log`: **48 checks passed** from the signed macOS 2.25.0 release app. Headless shutdown reports one dummy-renderer shader allocation; the rendered source run is clean.
- Static parse validation, code-signature verification and `git diff --check` passed.

The current playable app is `build/Goemon.app`. Its predecessor is preserved at `build/Other Files/Goemon-before-Rogue-Battle-2026-10-04.app`; the new export ZIP is `build/Other Files/Goemon-Rogue-Battle.zip`.

## Captures

- `01-mode-selection.png`: separate mode entry alongside existing modes.
- `02-battle-overview.png`: live island encounter framing.
- `03-ground-cursor.png`: cursor and player heading markers.
- `04-heavy-contact.png`: actual 48-damage contact pose and impact.
- `05-edo-cursor-cast.png`: Edo's cursor-directed giant fireball.
- `06-tidefall-ground.png`: original ground scene with the new camera.
- `07-furnished-interior.png`: existing furnished room and cutaway.
- `08-flight-framing.png`: retained gold-cloak flight and camera bounds.

Tests freeze AI and use isolated target fixtures for deterministic attack checks. Ground/interior captures deliberately keep the encounter director stopped, so their HUD retains diagnostic island/freefall status. The normal run keeps the original live director.

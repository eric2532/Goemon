# Illidan's Metamorphosis missile

The patched `Units/CampaignUnitFunc.txt` entry **Eevm** selects
`Abilities/Weapons/DemonHunterMissile/DemonHunterMissile.mdl`. Normal evil
Illidan (**Eevi**) selects `IllidanMissile`; those are different effects.
The Meta model supplies a continuous cloud trail, a cloud impact squirt and a
flame-tail impact squirt. Its Death sequence is 667 ms; particles live 400 ms.
The existing DemonHunter launch/hit sound bank matches its MDX events.

The original also contains a **solid spinning rock**, previously omitted by the
Goemon recovery. Geoset 1 has 26 vertices / 24 triangles, `EQ_Rock2.blp`, and
`Sphere09`'s 667 ms global rotation loop. `source.json.rock` now preserves its
complete geoset, pivot/bone/rotation keys and prepared quaternion samples from
the existing Warcraft interpolator. Sampling uses 80 intervals per loop plus
every original key; runtime interpolates the prepared track. Coordinates map
`(x,y,z)` to `(x,z,-y)`, winding reverses for Godot, and geometry is centered on
its original rotation pivot. The requested enlarged scale is 0.09, producing
a roughly 3.0 × 3.2 × 3.4 m core, independent of the existing hit radius.

User clarification (2026-10-27): **no exposed rock surface; completely cover it
in purple flames**. The original rock texture is preserved as `rock.png` for
source fidelity, but gameplay uses animated purple fire on the native
mesh with softened additive edges and a dense local flame shroud. The shroud reuses the existing flame quad,
texture, material and trail envelopes, with 24 particles on a 1.35 m sphere.
The original purple glow, world-space trail and two impact emitters remain.
`fire_core.gdshader` reuses the existing painted-fire noise and original flame
texture; its clock is an instance parameter, reset with the pooled lease.
The stone and shroud disappear at impact. This enlarged fire coverage is Goemon
art tuning, not a claim of a pixel-exact Warcraft renderer.

`source.json` preserves the recovered MDX's sequences, materials, three emitter
definitions and hash. `clouds.png` and `flame.png` are unchanged copies of the
decoded originals under `Warcraft/assets/DemonHunter/original/`. The authoritative
original MDX, BLPs and editable character masters remain in that adjacent project.
Refresh these generated copies from the complete Goemon project with:

```sh
node tools/recover_warcraft_missile.cjs
```

The tool uses the existing Warcraft parser and checks the emitter order. It
does not save a Blender master or alter an original. Run the asset toolkit audit,
import refresh, preservation check and `test_illidan.py` after recovery.

The patched `Units/UnitWeapons.slk` entry **Edmm** uses `msplash`: full damage
inside 50 source units, half inside 150 and quarter inside 250, with enemies in
the splash mask. Campaign **Eevm** carries the same radii/factors but declares
`missile`, so those fields alone do not prove campaign splash activation.
Goemon explicitly enables the requested splash, mapping those bands to 1/3/5 m.
Base damage stays 64; direct contact gets full damage. Local native candidates,
fitted hurt volumes and world-cover rays decide hits. Splash hits enemies once,
including airborne targets; the fading effect adds no damage over time.

Goemon tuning: contact radius 0.9 m (formerly 0.45), flight lifetime 4 s (formerly
2.5), speed 28 m/s and current core sprite size 0.36. Unobstructed travel reaches
112 m. Enemy or wall contact starts the impact; a timed-out miss simply retires.
Warcraft's homing and chaos-armor rules are not newly added by this change.

`warcraft_projectile.gd` prepares the three source CPUParticles3D nodes plus the
covering flame shroud and one core MeshInstance3D per lease. They reuse
the original textures, source counts, lifetimes, spread, speed variation, size
and alpha envelopes, with the requested purple tint and a 0.03 art scale.
Godot billboard particles approximate Warcraft's tail geometry and squirt timing;
this is not an exact MDX renderer. All additive materials retain Unfogged.
Three immutable particle meshes/materials, the rock mesh/fire material, its
prepared spin track and neutral texture copies are shared.
The 24 warmed projectile leases cover four-second flight plus 667 ms impact at
the default maximum chain rate; resets clear old particles and impact state.

Source table extracts/hashes, native combat and rendered reuse evidence:
`build/Other Files/Asset Toolkit/Illidan Splash/`. Tests:
`warcraft_splash_test.gd`, `warcraft_splash_gameplay_test.gd`, plus existing
Warcraft character/energy/flight and fog regressions. No app export is needed.

Core/flame review: `tests/forest-shrine/illidan_rock_test.gd` through Play Goemon;
captures and measurements are in `build/Other Files/Asset Toolkit/Illidan Rock/`.

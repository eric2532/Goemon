# Sky combat and jumping islands — 2026-10-03

## Changes

- **2** toggles independent coin fire. It immediately fires, auto-aims at the nearest unobstructed on-screen enemy and repeats every 0.42 seconds divided by attack speed, with a 0.12-second minimum. It does not equip a different weapon, slow movement, occupy the manual queue or overwrite a manual attack's hit ticket. R, robe coins and confirmed-hit combo damage still apply. The subsequent coin-scaling update adds one coin per level and removes ranged red follow-ups; see [coin scaling](../coin-scaling/README.md). Dodge/dash/sky travel temporarily suspend shots; pause preserves the toggle; character changes, death and run resets disable it.
- **1** uses the existing R + LMB wind spin: 70 base damage, full-circle melee, powered reach and the robe's 16-coin ring. Combo spins skip windup; a connected heavy → spin retains the separate red cross hit.
- **784 islands** retain 14 layers, now in eight groups of seven per layer. Six shared polygon meshes and collision resources provide ridges, wedges, notches and irregular plateaus at varied sizes and rotations. Enemy spawning, patrols and ledge steering use the actual footprint. 672 local jump routes have real air gaps; continuous cloud roads are removed. Small cloud rest stops are spaced apart below the island plane.
- **Elite blast:** 1.2-second filling ground-circle warning, then 28 damage within 4.5 metres. Move out or jump above it.
- **Elite channel:** aim tracks for 0.65 seconds, then locks for a 0.55-second warning before a 1.8-second beam. The line pulses for 12 damage, respects player invulnerability and is clipped by cover. Heavy hits/freeze interrupt it, and death/unloading clean up its nodes.
- Small ranged throwers are included in island rosters and ground reinforcements. They throw two visible hostile projectiles after a windup and retreat at close range.

## Verification

Godot 4.6.1, fixed physics at 60 Hz. Each suite completed with zero failures:

| Suite | Assertions |
|---|---:|
| `--sky-combat-visual` | 45 |
| `--attack-chain-test` | 61 |
| `--destruction-test` | 33 |
| `--direct-attacks-test` | 20 |
| `--adventure-test` | 38 |
| `--map-shuffle-test` | 22 |
| `--flight-test` | 23 |
| `--descent-test` | 26 |
| `--world-performance-test` | 10 |

The 45 sky-combat checks also pass in the exported macOS app with `--headless --fixed-fps 60 -- --sky-combat-test`. They exercise physical sprint/double-jump travel across a gap, every island's flat collision and map bounds, non-overlap, all 672 open routes, repeated/on-off fire, echo filtering, movement speed, pause, dash cancellation, character switching, real hit attribution, max-speed projectile bounds, spin coverage/damage, blast dodges, locked beam aim, wall blocking, interruptions, live AI alternation and real ranged projectiles.

Rendered captures were inspected:

- `01-irregular-jump-islands.png`
- `02-hotkey-wind-spin.png`
- `03-elite-blast-warning.png`
- `04-elite-channel-beam.png`

The packaged headless renderer still reports the previously observed single `RendererDummy...DummyShaderE` RID warning at shutdown. The exported suite has no script errors or assertion failures. Normal rendered validation has no engine errors. Signature verification passes with `codesign --verify --deep --strict`; the executable includes arm64 and x86_64 architectures.

Automatic fire is rate-bounded, the six island meshes/collisions are shared, clouds are substantially fewer and combat remains streamed to nearby islands. These checks do not establish a numerical FPS improvement.

## Release

Current launcher: `build/Goemon.app`. Current ZIP: `build/Other Files/Goemon.zip`. The prior app and ZIP are preserved under `build/Other Files/before-sky-combat-20261003/`.

The existing paused game session is left running. Quit and reopen the current launcher to use the new build.

# Confirmed-hit combos and independent red attacks — 2026-10-02

Combo credit now comes from actual damage to a living enemy. Each attack/cast carries a shared ticket through its melee contacts, projectiles, explosions and delayed effects. One successful attack earns one link; a separate red bonus attack has its own ticket and earns another. Multiple targets and repeated beam/shield pulses refresh grace without duplicating the same attack's link. Reset invalidates earlier tickets, so old projectiles cannot restore a new run's combo.

Misses, blocked hits, empty casts, dead targets and unattributed environmental damage cannot create or refresh a combo. A connected swing can finish before its remaining 1.75-second grace drains; misses cannot hold that countdown. Held beams require continued damage. Speed now builds at +5% per link after the first, capped at 1.5×, multiplying existing speed upgrades. Chained pipe attacks retain immediate contact and no player hit freeze.

Damage gains 5% per confirmed link, capped at 1.5× after ten links. Each attack snapshots this multiplier; all targets, cast projectiles, sustained contacts and its red bonus use the same value. Central enemy damage applies it exactly once, after existing damage buffs; unattributed/environmental damage stays unscaled. Expiry affects new casts, and run reset invalidates prior tickets.

The normal weapon attack remains visible and retains its base damage. Chained pipe swings add a separate 24-base-damage forward melee slash with wall checks and one hit per target. A connected RMB → 1 produces a two-arm red cross: 73.5 spin damage + 25.2 bonus damage after the opening heavy hit (70 + 24 base, multiplied by 1.05), with the bonus counted as one additional link. Red damage preserves stronger knockback/recoil from the original hit and cannot recursively trigger another bonus. Chained long sweeps also add a red follow-up. Ranged coins retain hit-based combo credit and damage scaling, but never emit red bonus projectiles. Only melee attacks trigger red slashes. Existing robe coins remain attached to their originating attack's credit.

Regular enemy base health is multiplied by 5 before sky-layer and giant scaling. Their attack damage, movement and population are unchanged. Chain-link width/thickness is multiplied by 2.6, preserving link length, mesh detail and the 512-instance budget. Red effects reuse shared meshes and materials, add no lights/shadow passes, and retain a 24-effect limit.

## Validation

```sh
godot --headless --path . --fixed-fps 60 -- --attack-chain-test
godot --path . --fixed-fps 60 -- --attack-chain-visual
```

The shared suite has **61 headless assertions**: hit-only credit, no refresh on misses, expiry, reset invalidation, independent cross-slash damage, no repeated/recursive bonus, forward hit area and walls, immediate chained hits, ranged auto-aim and attribution, coins without ranged red bonuses, full LMB combo, chain sweep, Sky Strike, dash, fireball volleys, giant fireballs, delayed meteors, shield, teleport, beam contact/lost targets, 4.5× combined speed, pause, beefier enemies and bounded effects. A rendered-only assertion also reads back actual MultiMesh transforms to verify chain thickness; Godot's dummy headless renderer returns identity transforms.

Updated regressions pass: direct attacks (28), robe coins (27), pipe choreography (25), Edo firecaster (49). Together with the shared suite: **190 passing headless assertions**. These older suites use `--legacy-survival` followed by `--direct-attacks-test`, `--robe-coins-test`, `--combo-test` or `--firecaster-test`. Their damage expectations include the new independent red hits. Rig continuity, ordered hits, recoil strength, weapon restoration, input queues, interruptions, buffs and robe effects remain checked.

Rendered captures are `03-melee-cross-bonus.png`, `04-coin-plus-red-slash.png` and `05-thicker-chain.png`. The previous hit-only version passed 55 rendered assertions. Visual tests disable window focus to avoid ordinary desktop input interfering with synthetic input. The earlier hit-confirmed release is retained in `build/Other Files/before-hit-combo-20261002/`; current damage-scaling release verification is recorded below.

These checks establish correctness and bounded effect construction, not a GPU performance benchmark.

## Damage scaling and Y refresh · 2026-10-03

Damage validation covers normal openers, five-percent increments, a 1.5× cap, uniform multi-target damage, separate red hits, delayed projectile snapshots, expiry/reset, and real fireballs stacking combo damage with a damage pickup. RMB → 1 deals 48 + (48 + 24) × 1.05 = 123.6 total damage. An unrobed LMB triplet deals 22 + (22 + 24) × 1.05 + (30 + 24) × 1.15 = 132.4. Y replaces F5 throughout gameplay, hints and the pause menu. All 22 map-shuffle assertions pass, including Y input and F5 being unassigned.

The damage-scaling version passes 61 headless / 62 rendered chain assertions, plus 129 direct-attack, robe, pipe and firecaster regressions. Together with the 22 Y-refresh checks, 212 headless assertions pass. The rendered HUD shows separate SPD and DMG multipliers.

Updated `build/Goemon.app` and ZIP pass strict signature verification; the packaged app passes all 61 chain and 22 Y-refresh assertions. Previous release preserved in `build/Other Files/before-y-combo-20261003/`.

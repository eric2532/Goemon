# Task 3 — actor and fitted combat contact

Completed locally; no commits and no asset edits. Existing uncommitted work was retained. Changes in shared scripts are narrow capability checks over their existing contents.

## Implemented

- Added `scripts/forest/forest_enemy_contact.gd`: cached geometry extracted from the approved GLBs. Daruma uses five convex shapes (painted shell, left/right feet, left/right fists); humanoids use capsules derived from their exported skull/ribcage/pelvis bounds; Lantern uses separate shell and leg convex shapes. Convex vertices are sampled to at most 774 source vertices per part, retaining extrema, so projectile sweeps do not scan the original 12,012 shell planes on every call. Plane normals come from the hull geometry and face outward. Shape queries use the same `ForestEnemyCrowd.part_pose()` transforms as rendered animation. Capsule segments use analytical cylinder/sphere intersection rather than per-step samples.
- Forest actor exposes `combat_aim_point`, `combat_contact_point`, `combat_segment_hit`, `combat_segment_contact`, `combat_bounds` and `combat_knockback`. Fitted compound collision replaces the inherited small capsule. `body_radius=0` avoids double-counting body extent after fitted contact queries. Approved model scale is untouched; old Ninja `ground_giant` scale/multipliers are not activated.
- Actor uses authoritative positions, facing, HP and action timers. Direct hero damage first reads pending model HP; tower HP deltas synchronize through a tower-attributed hit exactly once. Daruma keeps normal damage and 3,000 HP, reduces ordinary impulses by 90%, ignores routine flinch and recoil, and preserves director windup/recovery when frozen. Freeze retains the previous fitted pose. Dash/bashes publish their impulses into authoritative state.
- Giant billboard health bar follows the closest lower hurt surface toward the hero. Shared damage labels also use fitted contact, through a capability check. Forest parent visibility still hides the entire actor including its health display.
- Roles `hurt_point` forwards to the shared fitted contact geometry. Staffed tower selection measures actual surface reach and surface visibility; model-owned arrows and arrow orientation/impact feedback target the fitted surface.
- Shared native melee snapshots, segment broadphase/narrowphase, Goemon melee/chain/dash/coins, Edo fireball/beam/shield/meteors, combo followups, Sky Strike, teleport bursts and elemental orbs use capability checks. Ordinary Ninja actors keep their previous fallback positions and radii.

## Changed paths owned by Task 3

New:
- `scripts/forest/forest_enemy_contact.gd`
- `tests/forest-shrine/enemy_contact_test.gd`

Modified (some already contained unrelated uncommitted changes):
- `scripts/forest/forest_raider.gd`
- `scripts/forest/forest_workforce.gd`
- `scripts/forest/forest_tower_arrows.gd`
- `scripts/forest/forest_enemy_roles.gd` — only `hurt_point`, coordinated with simulation agent
- `scripts/attack_chain.gd`
- `scripts/rogue_roster_combat.gd`
- `scripts/gold_coin.gd`
- `scripts/coin_volley.gd`
- `scripts/player.gd`
- `scripts/chain_pipe_combat.gd`
- `scripts/combo_energy.gd`
- `scripts/goemon_dash.gd`
- `scripts/sky_strike.gd`
- `scripts/smoke_teleport.gd`
- `scripts/edo_meteor_rain.gd`
- `scripts/orb_mechanics.gd`
- `scripts/enemy.gd` — fitted damage-label capability check
- `assets/characters/musashi/combat/musashi_combat.gd` — fitted shield contact
- `assets/vfx/fireball/fireball.gd`
- `assets/vfx/fire_beam/fire_beam.gd`

No changes to Blender files, model assets or textures. Root owns Forest game integration and inherited crowd type. Visual agent owns and fixed crowd culling after this task's native capture revealed an origin-only custom AABB.

## RED evidence

`godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/enemy_contact_test.gd -- --test`

Initial real-scene run: `FOREST_ENEMY_CONTACT_RESULT checks=8 failures=4` (`/tmp/enemy-contact-red.log`). Failures were missing fitted segment interface, routine giant flinch, excessive giant heavy impulse, and tower feedback at root plus UP. An earlier attempt was blocked by root's temporary preload of the not-yet-written crowd; that compile failure was not counted as RED evidence.

## Verification

All commands ran from `/Users/eric/Desktop/Projects_Codex/Sonic` using Godot 4.6.1.

| Command | Result | Log |
| --- | --- | --- |
| `godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/enemy_contact_test.gd -- --test` | 29 checks, 0 failures, exit 0 | `/tmp/enemy-contact-final.log` |
| `godot --path . --script tests/forest-shrine/enemy_contact_test.gd -- --test --visual` | 29 checks, 0 failures, exit 0; native Metal Apple M3 | `/tmp/enemy-contact-native-final.log` |
| `godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/modern_combat_test.gd -- --test` | 20 checks, 0 failures, exit 0 | `/tmp/enemy-contact-modern-final.log` |
| `godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/review_regression_test.gd -- --test` | 15 checks, 0 failures, exit 0 | `/tmp/enemy-contact-tower-final.log` |
| `godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/rogue_test.gd -- --test` | 64 checks, 0 failures, exit 0 | `/tmp/enemy-contact-rogue.log` |
| `godot --headless --path . --fixed-fps 60 --script scripts/projectile_query_tests.gd -- --test` | 9 checks, 0 failures, exit 0 | `/tmp/enemy-contact-projectile.log` |
| `godot --headless --path . --fixed-fps 60 -- --tower-defense-test` | full Tower Defense suite, 0 failures, exit 0 | `/tmp/enemy-contact-defense.log` |
| `godot --headless --path . --fixed-fps 60 -- --rogue-equipment-combat-test` | 63 checks, 0 failures, exit 0 | `/tmp/enemy-contact-equipment.log` |
| `godot --headless --path . --fixed-fps 60 -- --rogue-siege-tests` | 27 checks, 19 failures; legacy launch fixture mismatch, detailed below | `/tmp/enemy-contact-siege.log` |

Contact assertions cover visible feet, actual shell airborne sweeps, the empty gap between feet, outside-body misses, nearby native melee snapshots, fitted broadphase, ordinary damage/resistance, freeze retaining windup, tower-authoritative HP synchronization, low health bar, fitted tower impact, and every one of twelve heroes' real primary inputs against a giant foot.

Accelerated headless contact/modern/rogue/review/equipment harnesses reported existing ObjectDB/audio-resource cleanup warnings on shutdown (final contact: 15 resources; modern: 6; review: 1). No gameplay script errors appeared in their successful runs. The final native contact run exited cleanly with no script/render/cleanup errors.

Generic projectile harness initially run without user args followed the current Forest-title redirect and produced Nil setup errors; rerun with `-- --test` correctly initialized historical services and passed all nine checks.

## Native evidence and integration notes

`task3-contact-native.png` beside this report shows the giant's visible lower body, fists, feet and low health bar with its head above the battle camera. The final native diagnostic showed the giant at `(0,0,70)`, visible, one batch instance and culling bounds with world Z minimum `46.7116`. The first capture showed only a health bar because crowd custom bounds were centered at zero; visuals agent confirmed and fixed the bug, and final native full twelve-hero run was repeated after that fix.

Task 3 has no outstanding implementation work. Root still needs combined independent review, full integration/run cleanup, native gameplay tour and playable export. The contact helper dynamically uses crowd `part_pose`; keep that interface and group names (`body`, `foot_l`, `foot_r`, `fist_l`, `fist_r`). No asset rescaling fallback remains in contact.

## Legacy Rogue Siege broad-suite limitation

The historical suite expects a separate Rogue Siege main-menu button. Current product startup already removed that button. Its `pregame_rules` fails at `scripts/rogue_siege_tests.gd:151`, then `pressed` on a null button errors at line 152. The fixture consequently stays in Sky Descent, and later native ability/cannon accesses are Nil or wrong director properties. This task did not modify launch buttons, native combo timing or historical mode selection. Root was informed; unrelated baseline menu/fixture behavior was preserved.

All 19 named assertion failures observed:
- Main menu exposes a separate Rogue Siege launch button
- Rogue Siege combines the battle camera with the real tower-defense mode
- The existing ten-wave, 600-enemy Fire Siege director remains in charge
- Original battlefield, 24 mounts, twelve fire towers and twelve cannons are preserved
- Goemon tap 1 starts its intended duration and combo window at base speed (speed=1.000)
- Goemon stage 1 retains a visible windup without early contact or replacing his rig (speed=1.000)
- Goemon stage 1 contacts near 0.15 seconds once, in the cursor direction, with unchanged base damage (clock=0.420, speed=1.000)
- Goemon stage 1 finishes without an automatic extra strike
- Goemon tap 2 starts its intended duration and combo window at base speed (speed=1.000)
- Goemon stage 2 retains a visible windup without early contact or replacing his rig (speed=1.000)
- Goemon stage 2 contacts near 0.15 seconds once, in the cursor direction, with unchanged base damage (clock=0.420, speed=1.000)
- Goemon stage 2 finishes without an automatic extra strike
- Goemon tap 3 starts its intended duration and combo window at base speed (speed=1.000)
- Goemon stage 3 retains a visible windup without early contact or replacing his rig (speed=1.000)
- Goemon stage 3 contacts near 0.15 seconds once, in the cursor direction, with unchanged base damage (clock=0.420, speed=1.000)
- Goemon stage 3 finishes without an automatic extra strike
- pirate utility performs its own directional movement with Dragoon retreating backward
- Knight blocks frontal projectiles while rear shots and melee strikes still cause damage
- An actual incoming hit keeps horizontal knockback through native movement updates


## Independent review correction round 1

Read `task3-review.md` and addressed all three P2 findings. No unrelated legacy behavior was changed.

1. **One authoritative frozen pose.** The simulation agent added `enemy.frozen_pose`, captured shallowly before velocity is cleared and removed on freeze expiry (nested snapshots erased to avoid recursion). Actor `freeze_for()` captures the same field immediately before native freeze clears velocity. Actor snapshots now copy authoritative data on every sync; renderer snapshots copy live data even while frozen. Both `ForestEnemyCrowd.part_pose()` and shared `ForestEnemyContact.part_pose()` consume the authoritative retained pose while the live `frozen` timer is positive. World root position/facing still come from live authoritative data. This covers freezing a walking foot before its first actor/render update as well as an already-visible enemy.
2. **Chain obstruction ray restored.** Chain path finds the nearest point on the actual attack segment to the fitted hurt surface (or original legacy center), and casts from that segment point to the hurt point. It no longer casts an unconditional zero-length ray for every victim. A real 0.1m-thick `StaticBody3D` wall blocks the off-axis legacy victim; removing the wall restores damage.
3. **Caller-specific old centers preserved.** `AttackChain.segment_contact()` gained optional `legacy_center`, used only when the actor lacks the fitted capability. Chain and Edo beam supply their previous root+1.5m boss/root+1.1m other centers. Gold coins/volley keep their general aim-point fallback unchanged. Edo beam also retains its previous strict along-segment center bounds for legacy actors; the new test demonstrated the endpoint behavior before correction.

Changed paths in this correction round:

- `scripts/attack_chain.gd`
- `scripts/chain_pipe_combat.gd`
- `assets/vfx/fire_beam/fire_beam.gd`
- `scripts/forest/forest_enemy_contact.gd`
- `scripts/forest/forest_raider.gd`
- `scripts/forest/forest_enemy_crowd.gd` — only frozen snapshot consumption/cache eligibility; coordinated with the completed visuals task
- New `tests/forest-shrine/enemy_contact_review_test.gd`
- Simulation-owned `scripts/forest/forest_waves.gd` — authoritative frozen snapshot capture/expiry, implemented by simulation agent

### Review RED → GREEN

`godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/enemy_contact_review_test.gd -- --test`

- Initial clean assertion RED: 13 checks, 11 expected failures, exit 1 (`/tmp/enemy-contact-review-red.log`). Covered frozen model arrow surface, actual actor hull containment, freeze before first presentation, renderer raised-foot pose, a real chain wall obstruction, and both chain/beam legacy boss/elite/giant heights. No script errors in this RED run.
- After correction: 13 checks, zero failures (`/tmp/enemy-contact-review-green.log`, subsequently superseded by the 14-check run).
- Added explicit legacy beam endpoint preservation: RED 14 checks, one failure (`/tmp/enemy-contact-review-endpoint-red.log`); restored original legacy along-center guard; GREEN 14 checks, zero failures.
- Final new review suite: 14 checks, zero failures, exit 0 (`/tmp/enemy-contact-review-final.log`). The headless harness retains one resource cleanup warning on exit.

### Covering verification after the three fixes

| Command | Result | Log |
| --- | --- | --- |
| `godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/enemy_contact_test.gd -- --test` | 29 checks, 0 failures, exit 0 | `/tmp/enemy-contact-review-contact.log` |
| `godot --path . --script tests/forest-shrine/enemy_contact_test.gd -- --test --visual` | 29 checks, 0 failures, exit 0, native Metal Apple M3 | `/tmp/enemy-contact-review-native.log` |
| `godot --headless --path . --fixed-fps 60 --script scripts/projectile_query_tests.gd -- --test` | 9 checks, 0 failures, exit 0 | `/tmp/enemy-contact-review-projectile.log` |
| `godot --headless --path . --fixed-fps 60 --script tests/forest-shrine/review_regression_test.gd -- --test` | 15 checks, 0 failures, exit 0 | `/tmp/enemy-contact-review-tower.log` |
| `godot --path . --script tests/forest-shrine/enemy_contact_review_test.gd -- --test` | 14 checks, 0 failures, exit 0, native Metal Apple M3, clean teardown | `/tmp/enemy-contact-review-native-new-clean.log` |

The initial new review native run passed all 14 assertions but crashed with Godot signal 11 during fast `game.queue_free()` shutdown (`/tmp/enemy-contact-review-native-new.log`, exit 139). The native test now uses the project's existing `game.quit_clean()` path, as the existing native tours do. Its rerun passed all assertions and exited 0 without script/render/cleanup errors. The full 29-check native contact harness also exited cleanly. No legacy Rogue Siege broad suite was rerun in this correction round.

### Fitted geometry limitations clarified

The convex shapes are derived from source vertices at approved scale. Shell sampling retains extrema and a dense rounded hull but is an approximation of the original mesh between sampled vertices. Contact projects toward each convex part's center rather than solving an exact closest-surface distance. Radius sweeps use conservative hull-plane expansion rather than exact swept-sphere corner distance. Humanoid capsule intersections are analytical. These approximations do not create an old root capsule or remove the tested gap between Daruma's feet.

No remaining Task 3 review finding is deferred; ready for the root's independent re-review and integration/export work. Changes remain uncommitted.

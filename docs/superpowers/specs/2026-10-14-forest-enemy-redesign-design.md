# Forest Shrine enemy redesign spec

Date: 14 October 2026, Asia/Taipei.

Status: Implementation authorized by Eric on 14 October 2026: “ok implement these new enemies into the game”. The numerical defaults below are the starting playtest values; the earlier documentation-only hold has been superseded.

## Player experience

Each enemy creates a distinct defensive problem. Raiders pressure the hero, Archers threaten the workforce, Daruma break fortifications, and Lanterns threaten the shrine. Their silhouettes and actions must make these roles understandable during combat.

Daruma is a massive, slow siege threat. The player has time to see it approaching and react, but must commit sustained damage to stop it before it reaches a tower or wall. Its size must not translate into fast pursuit, instant attacks or an unresponsive damage sponge.

## Confirmed enemy roles

| Enemy | Primary target | Health requirement |
| --- | --- | --- |
| Masked Raider | Main character | High health |
| Reed Archer | Workers | Low health |
| Daruma Breaker | Towers and walls | A very large health pool; moves very slowly |
| Lantern Runner | Main shrine | Low health; rushes the shrine |

These priorities supersede the current shared rule where a nearby worker can redirect any enemy. Daruma must not switch to chasing the hero or workers just because they are nearby or attack it. The other three enemies' exact stats and fallback rules need their own balancing pass; this spec does not assign them new numbers.

## Models and scale

Preserve the completed rounded models, painted faces and fitted UV artwork. Humanoid enemies retain the Goemon-inspired large heads, compact torsos, short limbs, and large hands and feet. The Raider retains a full skull behind its wooden mask and substantial torso depth in profile.

| Enemy | Source height compared with Goemon | Current model version |
| --- | --- | --- |
| Masked Raider | 1.40× | forest_redesign_v01 |
| Reed Archer | 1.35× | forest_redesign_v01 |
| Daruma Breaker | 7.00× | forest_redesign_v02 |
| Lantern Runner | 1.55× | forest_redesign_v01 |

The current Daruma is four times the previous Daruma in every linear dimension: approximately 23.10 m high, 27.73 m wide including its fists, and 15.08 m deep. Preserve this scale during eventual import, collision setup and animation. Keep the original smaller asset available as a historical version.

The models are currently static assets. Rigging, movement and attack animation, collision shapes, and in-game replacement belong to a later authorized implementation pass.

## Daruma movement and health

The following values make the slow, durable direction concrete for a first playtest. They are proposed defaults rather than additional user-approved requirements.

| Parameter | Draft value |
| --- | --- |
| Movement speed | 0.75 m/s |
| Maximum health | 3,000 HP |
| Automatic healing | None |
| Automatic speed increase across waves | None |
| Building attack damage | 120 HP per completed strike |
| Attack windup | 1.5 seconds |
| Attack recovery | 3.5 seconds |

At 0.75 m/s, Daruma takes eight seconds to traverse one six-metre grid cell. Its movement remains deliberate throughout the run: no sprint, charge, teleport or catch-up burst. Stop movement during windup and recovery. Turning should also be slow and visibly committed, rather than snapping toward a different target.

Use actual high HP as its durability mechanism. Ordinary hero and tower damage should still reduce health visibly; do not quietly add damage immunity or a second hidden health layer. Its health bar must make accumulated damage easy to read. Final HP may be tuned after playtesting, but Daruma must remain substantially tougher than the other enemy types.

Proposed resistance to ordinary hits prevents the giant from being pushed around or having every attack canceled: reduce ordinary knockback displacement by 90 percent and ignore routine hit flinches. Preserve deliberate crowd-control abilities, including freeze, without advancing movement or attack timers while frozen. These resistance rules require review with the first combat playtest.

## Daruma targeting and attacks

Towers and walls form one preferred target group. Choose the closest reachable structure by valid approach route; do not treat every tower anywhere on the map as more important than every nearby wall. Keep the chosen target while approaching and attacking it. Reconsider when it is destroyed or its approach becomes invalid, avoiding repeated switching between equally suitable structures.

A gate blocking access to a preferred target may be breached as an obstacle. If no tower or wall remains reachable, the proposed fallback is to advance toward the shrine and breach intervening fortifications. This fallback is a draft rule; the confirmed primary targets remain towers and walls.

Before attacking, turn toward the structure, stop, and perform a readable slow windup. The visible stone fist and contact area must reach the structure before damage is applied. Strike once, then recover. If the selected structure disappears during windup, cancel its damage and choose another valid target. Only the selected building takes damage in the first prototype; additional area damage requires a separate design decision.

The large model needs meaningful contact locations. Judge attack reach against the building's occupied surface and the visible fist, rather than using the old generic distance from enemy center to building center. Avoid damage through intervening structures or trees.

## Navigation and arrival

A massive Daruma cannot use the existing single-cell navigation assumptions. Derive movement clearance from the core body, with separately fitted fists and feet, and validate broad approaches. Do not shrink collision to the small enemy capsule to make the giant fit a route. A narrow gate should not let it pass through solid posts.

Use authored or validated wide approaches into the settlement. A blocking wall or gate can be a breach target; trees and map boundaries are impassable unless forest destruction is explicitly designed later. Do not spawn a giant in an approach from which it cannot reach any valid objective.

The 0.75 m/s speed also needs an appropriate arrival distance. Proposed giant staging positions are approximately 80–100 m from the shrine, on a valid approach with the entire spawn footprint outside current shared vision. Ordinary enemies may retain their longer routes. Validate travel time to the actual fortification, rather than making the player wait several minutes for a giant to cross the full outer forest.

Introduce Daruma later in the run, initially one at a time. Exact wave composition and staging positions remain part of the later wave-design pass. Warning information and spawning must continue to respect fog of war.

## Presentation and combat readability

Animate a slow, heavy walk with alternating planted feet, restrained body rocking and deliberate fist motion. Foot placement and movement must agree; a large model sliding on the ground does not satisfy the slow-walk requirement. Preserve the painted faces and rounded surfaces throughout animation.

Hero melee attacks must be able to hit the visible feet or lower body. The player should not need to reach a 23-metre-high face to damage the enemy. Projectiles and tower arrows should register contact on fitted visible hurt areas, with hit feedback at that contact point.

Keep camera and feedback readable beside the giant. Its health display must remain usable when the head is above the combat camera. Do not reveal hidden enemies through labels, effects or the giant's health display. Pause must stop all its movement, windup, damage, recovery and control timers.

## Later implementation boundaries

Use the authoritative Forest Shrine simulation for enemy HP, targeting, paths and attack timing, and synchronize the rendered actor with that state. Define per-enemy role data instead of four copies of the same targeting rule. Keep combat state separate from mesh and material setup so asset changes do not silently alter target priorities.

Preserve the current hero kits, worker commands, construction, fog rules, five-wave run, testing treasury and doubled walls unless a later instruction changes them. The original documentation-only hold was superseded by Eric’s explicit instruction to implement these four enemies. Additional enemy types remain outside this pass.

## Acceptance criteria for an authorized implementation

1. All four enemies consistently select their specified primary target category.
2. Daruma retains the massive v02 scale and correctly fitted collision; it cannot pass through terrain, buildings or narrow gates.
3. A clear 12 m walk takes approximately 16 seconds at the draft speed. A later wave does not increase that speed.
4. Daruma starts with the configured large health pool, accumulates normal damage correctly, and dies only when health reaches zero.
5. Nearby hero and worker movement does not distract it from a valid tower or wall target.
6. Attacks have the full visible windup, apply one building hit at contact, and respect recovery. Missing targets receive no delayed damage.
7. Hero melee can damage visible lower hit areas, and arrows register against the actual model rather than empty space.
8. Wide-route validation, slow-arrival timing, fog, pause, freeze, wave completion and retry all work without a stuck giant or hidden progress.
9. Front, side, back, movement and attack reviews preserve the rounded forms and correctly mapped facial artwork in the exported game.

## Reference assets and saved design

- [Saved enemy design brief](../../enemy-concepts/enemy-design-v01.md)
- [Saved role data](../../enemy-concepts/enemy-design-v01.json)
- [Current asset catalog](../../enemy-concepts/3d-v01/asset-catalog.json)
- [Massive Daruma scale comparison](../../enemy-concepts/3d-v02/massive-daruma-scale-comparison.png)
- [Massive Daruma Blender source](../../../assets/blender/enemies/forest_redesign_v02/daruma_breaker.blend)
- [Massive Daruma GLB export](../../../assets/models/enemies/forest_redesign_v02/daruma_breaker.glb)

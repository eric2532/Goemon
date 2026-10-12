# Ink-brush roster effects and buildable shrine gate

Date: 2026-10-13

Status: the user approved the starting design in chat. This written specification
is awaiting review before implementation planning. Product code is unchanged.

## Outcome and approved choices

Give the remaining playable characters the ink-brush attack and hit style from
Samurai and Magic Swordsman, while preserving their current abilities. Remove
the target circle and LOCK label without removing J targeting or the aiming
crosshair. Add a wall-and-gate barrier ahead of the player’s starting position
that enemies must break through before reaching the shrine.

The user approved these choices together:

- One fixed gate with side walls, purchased and constructed as one barrier.
- The whole barrier costs 10 gold. The semi-transparent gate has 5,000 HP.
- The player can pass through the gate and attack enemies through it.
- Enemies prioritize breaking the gate. Rebuilding costs another 10 gold.
- Preserve existing character abilities and shrine defense battles.

Continue developing the separate crosshair preview with Godot 4.6.3. Keep the
Japanese districts, discoveries, shrine health, ice upgrades, Ranger spread and
curved shots, and current Samurai/Magic Swordsman effects. The user’s previous
development-first preference remains: functional crowd checks are required,
but foreground FPS benchmarking and a promise of 60 FPS are outside this work.

## Scope and approach

Use the existing construction transactions, bounded effect system, and defense
director. Add an isolated gate objective controller and enemy movement adapter,
following the existing shrine controller pattern. Keep combat data and cosmetic
effect generation separate.

A fixed barrier gives this first version a clear defense position. Freely placed
wall segments would additionally need placement validation, arbitrary route
changes, and rules for sealed routes; multiple independent doors would make
bypassing the intended defense point possible. Those alternatives are not part
of this release.

The gate belongs to the expanded standard Fire Siege map. Do not automatically
insert it into custom map documents or other modes. Shared character effects
may appear wherever those characters already use the same combat code; gate
targeting and construction remain scoped to Fire Siege.

## Character effects and preservation

The playable roster is Goemon, Edo, Pirate, Samurai, Ninja, Mage, Knight, Dragoon,
Magic Swordsman, Ranger, Explorer, and Master Thief. Upgrade the ten remaining
heroes; retain the two completed brush treatments.

| Hero | Visual treatment |
| --- | --- |
| Goemon | Gold/orange brush sweeps for pipe and chain attacks, painted coin wakes, and stronger confirmed-hit bursts. Preserve charged attacks, chained actions, aerial moves, and Golden Surge. |
| Edo | Fire-colored painted flame wakes and impact strokes, with the existing blue powered identity. Preserve normal/giant fireballs, charging, shield/special actions, dodge, and surge. |
| Pirate | Gold cutlass brush crescents following the blade, a painted flintlock wake, and warm impact fragments. Preserve combo, piercing round, roll, and untargetable drink. |
| Ninja | Brush katana cuts, painted shadow/shuriken feedback, and sharp hit bursts using the existing palette. Preserve teleport, shuriken flight, and Anbu Dance. |
| Mage | Fire/frost brush textures on existing projectile and area-effect geometry, with bright impact cores. Preserve charging, explosions, frost effects, blink, and Overflow. |
| Knight | Broad navy/steel brush cuts and stronger counter/impact strokes. Preserve shield, counter, block meter, dash, and ultimate. |
| Dragoon | Azure painted thrust wakes and brush-edged landing rings. Keep thrusts directional; preserve actual-floor landing, pulses, leap, backflip, and ultimate. |
| Ranger | Green painted arrow wakes, feather-like ink accents, and stronger confirmed-hit bursts. Preserve arrow silhouettes, power-shot cycle, spread, deviation, curvature, aerial aiming, roll, and rain. |
| Explorer | Brush feedback following both blades, painted cross-dash/hook wakes, and teal impact accents from the existing palette. Preserve travel and utility behavior. |
| Master Thief | Brush pipe sweeps and ember/smoke feedback, with stronger impacts in the existing palette. Preserve guard, meter, evade, smoke teleport, and ultimate. |
| Samurai / Magic Swordsman | Preserve the v2.51.3 red/purple brush effects, fast-step sampling, five-cut Samurai combo, huge red arrow, ultimate, and long-range purple energy wave. |

Use tapered pigment bodies, irregular inner edges, bristle grooves, bright cutting
edges, and small colored accents. Sword crescents follow real weapon poses;
projectiles receive painted wakes; thrusts remain spear-shaped; area attacks
receive brush-edged rings. A bow or fireball must remain recognizable as its
existing attack rather than being replaced with a melee crescent.

Confirmed hits receive a short bright core, colored ink fragments and, where
appropriate, a compact impact ring. Misses show the attack motion without a
confirmed-hit burst. Keep the heavy/finisher distinction. Avoid duplicated
generic effects when a brush treatment replaces them.

Damage, contact timing, reach, collision widths, piercing, travel, cooldowns,
status effects, invulnerability, combo bonuses, resource costs, and ultimate
duration/speed remain unchanged. Do not replace character models or animation
clips. Keep Samurai’s ten-second 5× ultimate and Magic Swordsman’s 100-damage,
40-metre wave with its current wide corridor and ground/air aiming rules.

Reuse Godot ShaderMaterial, cached meshes, and the existing batched particles.
Keep reduced-flash and Low-quality support. Extend bounded sampling for dual
weapons without unbounded per-frame nodes; both hands share the attack’s effect
budget. Preserve the existing 2/3/4 live ribbon limits at Low/Medium/High, the
bounded 18-pose / 104-vertex single-strip history, and displayed-frame/live
impact limits. New strips must have an explicit finite geometry budget.
High attack speed must not suppress the core stroke merely because an entire
emission window falls between physics frames. Trails expire and are cleared on
cancel, death, switch, pause, restart, and mode exit.

## Lock-on presentation

Remove only the world-projected target arc and LOCK text currently drawn by
`scripts/hud.gd`. Keep the center crosshair, J toggle, nearest-visible-target
selection, attack aiming, reacquisition, and manual camera control. Do not
introduce a replacement target badge. A normal toggle notification may remain.

## Gate placement and appearance

On the current standard layout, enemies enter at z=110, defense stations are
at z=155 and z=195, the player starts at z=185, and the shrine is at z=220.
Place the barrier across the route at (0,0,180), five metres ahead of the player
toward the enemy entrance. Keep the existing route, tower sites, and mine sites.

The initial dimensions are a 12-metre gate opening, two side walls extending
to x=-20 and x=20, and about four metres of wall height. Validate actual collision
and build access against the mines at (+/-18,0,175), towers near (+/-12,0,168),
their work areas, and the rear station. Adjust cosmetic thickness/roof overhang
within those clearances; keep the opening centered on the enemy route.

Use Japanese timber posts, stone wall bases, roof trim, and restrained red/cyan
emissive details consistent with the existing map. The closed gate panel stays
semi-transparent after completion, approximately 30% opacity, so enemies and
attacks are visible from the shrine side. Side walls and frame remain opaque.
The transparent panel must not cast an opaque shadow across its view.

Before purchase show an empty foundation/nearby construction preview. The
complete wall and gate appear only when construction completes. Show gate HP
and construction cost/progress close to the site; add compact gate health to
the defense HUD while retaining shrine health and its under-attack warning.

## Construction, health, and rebuilding

Use the existing stand-nearby construction interaction with a three-second
construction duration. The eligibility rules remain: living player, grounded,
stationary, within the existing 3.5-metre build range, affordable, and not in a
conflicting combat/travel action. Pause stops construction; interruption uses
the existing progress decay. Avoid competing tower/mine/gate work at once by
selecting one nearest eligible build site.

Charge exactly 10 gold once at successful completion, never on preview or
partial work. The completed gate starts at 5,000 HP with both side walls built.
There is no tower upkeep, passive damage, or income attached to the barrier.

At zero HP, stop gate attacks, remove the gate panel’s enemy collision, show a
brief bounded destruction effect, and leave a clear central opening. The built
side walls/frame remain standing. The same foundation offers a 10-gold rebuild
that restores the gate to 5,000 HP; it must not duplicate side walls or charges.
Do not add partial repairs or upgrades in this version.

Allow construction/rebuilding during setup and active waves, matching existing
construction availability. If living enemies occupy the gate panel’s collision
volume, defer completion and payment until the opening is clear; show a short
occupied-doorway prompt. Do not trap actors or teleport them on completion.
The player and friendly actors do not prevent completion, since they pass the
panel. Enemies already on the shrine side keep their current defense behavior.

Gate HP and construction state persist between waves. A new run clears the
barrier and starts it unbuilt. Hero death does not refill HP. Pause, restart,
wave retirement, victory/defeat, and mode exit invalidate pending strikes and
construction work without creating late purchases or stale damage.

## Collision and attacking through the gate

The gate panel blocks enemy movement only. Use a dedicated unused collision
layer for that panel and include it in the mask of applicable Fire Siege raiders.
Keep the player’s normal terrain mask and player attack/aim queries unchanged,
so the player can walk and attack through the panel. Friendly allies keep their
normal movement rules and can use the opening.

The solid side walls/frame use normal terrain collision. They block movement
and projectiles where solid geometry exists; the opening remains the firing
and exploration passage. Visibility and J targeting pass through the transparent
panel but still respect ordinary buildings and solid side walls. Do not make
other terrain transparent to attacks or target acquisition.

Scope the extra enemy mask to this map’s raiders. Remove it when the gate/run
is retired. Invalidate shared obstacle/navigation caches when solid side walls
are first created or removed, preserving the existing incremental navigation
budget. Destruction/rebuilding of only the panel must not trigger an unbounded
full-map rebuild each frame.

## Enemy priority and gate combat

While a built gate has HP, living wave-owned raiders on its entrance side head
along the existing route toward it and prioritize the gate over chasing the
player or shrine. Do not let normal local player interception bypass this
priority. Raiders already past the barrier or assigned to shrine combat keep
their existing behavior. After destruction, release gate assignments and
resume normal lane, player interception, and shrine combat without teleporting.

A bounded gate controller assigns eight attack positions across the front of
the opening, with clear separation, and distinct waiting positions for the
remaining wave population. Waiting raiders remain killable and converge on the
gate rather than walking through it or stacking on one position. Validate slot
and waiting-point clearance against existing structures. Reuse weak references
and run/wave ownership checks, and refresh assignment at a bounded cadence.

Initial balance: a full 1.25-second interval before the first hit and between
hits; 20 base gate damage per hit, scaled by existing enemy damage/archetype
multipliers. This is a gate-only attack clock and must not change player-hit
damage or the shrine’s 2.5-second / one-HP clock. Use existing windup, strike,
and recovery poses facing the gate. Each valid strike applies damage once.

Only living, current-wave, assigned, in-range, unobstructed, unstunned and
unfrozen enemies can damage it. Stun, freezing, or displacement cancels a
pending strike and requires a fresh interval. Ice slows approach movement,
retaining the current movement-only slowing rule. Pause suspends clocks; hero
death does not stop gate combat. Do not replay missed strikes after a long
frame. Retiring or destroying a gate clears all pending contacts.

The director owns gate-health transactions and defeat bookkeeping remains
unchanged. Gate attacks must never damage the player or shrine. Breaking the
gate grants no kill credit, reward, wave completion, or shrine breach damage.
All surviving attackers still count toward the wave’s living population.

Rebuilding must not reclaim enemies already inside the shrine court. If enemies
are still outside, they reacquire the rebuilt gate through the same bounded
controller. Prevent both existing shrine-arrival entry points from admitting
entrance-side enemies while a live gate is blocking their route.

## Component boundaries

- Shared brush materials and geometry own appearance and finite lifetimes.
  Existing combat code chooses effects at real poses, release, or confirmed hit.
- A dedicated gate structure owns its procedural visual, panel/side-wall
  collision, nearby construction presentation, and damage presentation.
- A gate controller owns attack slots, waiting positions, gate strike clocks,
  and assignment cleanup, separate from the shrine controller.
- A gate enemy-motion adapter owns facing, movement and attack poses. It runs
  before ordinary local player interception when gate priority applies.
- Fire Siege owns construction selection, price transactions, gate HP, run
  lifecycle, and integration with lane/shrine arrival.
- The HUD displays gate status and removes the lock marker without owning
  target selection, construction, or damage logic.

Preserve custom-map data contracts, the existing tower/mine model adapters,
300-enemy limit, five spawns per second, ten waves, economy rewards, and all
other playable controls. No unrelated refactor or new dependency is required.

## Validation and delivery

Use real-input combat checks for all twelve heroes’ primary, secondary,
utility/special and ultimate actions, including airborne Ranger attacks,
Mage/Edo charging, status effects, confirmed hits, misses, cancellation and
accelerated combos. Compare existing combat outcomes rather than assuming
visual changes cannot affect behavior. Inspect actual rendered attacks for
every hero and verify Low/reduced-flash visibility and finite effect admission
with dense enemy fixtures. Crowd functional tests are not FPS measurements.

Gate coverage must include:

- Empty start, unaffordable work, interrupted work, exact 10-gold payment,
  5,000 initial HP, paused progress, and construction across wave transitions.
- Hero/friendly passage; enemy blocking; melee/projectile/J aiming through the
  panel; side walls and ordinary buildings still blocking where appropriate.
- Gate-first priority despite a nearby player, eight bounded attackers,
  killable waiting enemies, first-hit interval, once-only damage, stun/freeze/
  knockback, ice slowing, hero death, and the full wave population remaining
  counted while attacking the gate.
- Zero-HP opening, resumed shrine battle, persistent damage across waves,
  occupied-doorway rebuild deferral without payment, one rebuild charge,
  restored HP, and no teleported or reassigned inside enemies.
- No stale damage, collision, purchases or effects after restart, pause,
  character switch, victory/defeat, mode exit, or retired wave ownership.
- Mine/tower access, free between-wave exploration, custom map compatibility,
  unchanged shrine rules, and hidden lock marker with working J and crosshair.

After implementation, run the affected existing suites and new checks on
source and exported resources, perform a bounded independent code review,
and verify the actual native app’s focused combat/gate checks. Inspect the new
shaders and gate in the real map. Record any native shutdown diagnostics and
unverified full-session/FPS status honestly.

Proposed delivery is v2.52.0, a separate universal arm64/x86_64, ad-hoc-signed
macOS preview built using the existing Godot 4.6.3 runtime. Preserve the
v2.51.3 app/ZIP and earlier archives, the primary checkout, and the protected
character model hashes. Provide the new app and ZIP with version notes and
verification evidence, including signature, archive CRC, executable permission,
and extracted game-pack hash checks. Work in the current spirit-effects
worktree and keep the development branch locally unless separately asked to
publish or merge it.

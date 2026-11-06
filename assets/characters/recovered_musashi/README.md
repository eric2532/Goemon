# Musashi: source recovery and playable integration

Recovered from the supplied US retail disc, SLUS-007.26. The rigid-part model
retains 80 recovered animation clips. Clips include phases of one action,
not 80 distinct playable moves. No original asset geometry was replaced.

## Controls

| Input | Action |
| --- | --- |
| WASD | Camera-relative movement using the recovered digital-pad values |
| Ctrl | Cautious walk |
| Left click | Four Fusion attacks; click again to queue each cut |
| Right click | Standing or airborne Lumina |
| Left hit → Right | Crosswise Cut (X Slash); right may be buffered during the first Fusion cut |
| Left → Left → Right | Tenderize, with its original rising and second-cut phases |
| Crosswise → Left → Right | Desperado, including the dual-sword leap and landing |
| Space | Jump; hold for height, release to shorten the rise |
| Space again | Original spinning double jump; L-Belt ability always unlocked |
| 1 | X Slash: one press performs Fusion → Lumina |
| 2 | Tenderize: one press performs Fusion → Fusion → rising Lumina cuts |
| 3 | Desperado: one press performs Fusion → Crosswise → Fusion → dual-sword leap |
| 4 | Immediate Lumina Rotation (charge requirement bypassed by request) |
| 5 | Mighty Strike counterattack shortcut |
| Hold E, release when READY | Original charge and release Lumina Rotation |
| Hold R | Frontal guard/charge; full charge can also use right click |
| Q | Fighter gallery; **Skills & Jump** assigns the five numbered skills |

**Leaping Strike · Air Attack** can be equipped in any numbered slot on any
fighter. While equipped, either attack button in the air (after the first or
second jump) enters the recovered Fusion finisher's apex, downstroke and landing
phases. The assigned skill key also works in the air. Ground attacks and manual
Space presses stay unchanged; unequipping restores ordinary aerial attacks.
Choose **Musashi · Variable Double Jump** in Jump Style to borrow his jumps too.
This is a reusable adaptation of the verified Fusion4 sequence, not a claim that
the original Rumparoni-SP has been identified. Other rigs reuse their own attack
gesture with the same prepared spell controller; no runtime retargeting is added.

The numbered defaults execute the full sequence automatically, with each cut's
existing windup, contact checks and damage. They continue the gestures on a miss
without inventing a hit. Extra mouse clicks do not restart an automated sequence;
hit interruption, focus loss, pause or changing fighters cancels it. Manual mouse
combos remain available. Saved custom slots take precedence over these defaults.
Rotation, Mighty Strike, D-Kick, Fence, Homing, Grenade and held 3-Way remain in
Skills & Jump. Reassigning these three combos to Musashi reuses his native body
and controller, with no extra hidden fighter or runtime created.

Source movement automatically reaches the original faster run. It no longer
uses the shared Shift boost, cape flight, coyote time, wall hop, generic evade
or progression jump multipliers. These changes apply only to Musashi.

## Restored fourth Fusion action

The fourth click now plays all five recovered phases: `800D4D88` windup (6
ticks), `800D4DA8` launch pose held through ascent, `800D4DB4` apex transition
(6 ticks with no Y integration), `800D4DD4` falling-contact pause until actual
floor contact, then `800D4DF4` landing (5 ticks).

`55B20` initializes -16 downward-positive source velocity without moving Y.
`55B9C` adds +3 per source tick before integrating, producing ascent values
-13,-10,-7,-4,-1 and an apex 35 units / .63m at the former fitted scale, now 1.89m above
takeoff with the requested threefold presentation. `55C64` resumes gravity during the falling contact and uses the original
soft terminal guard (29 crosses to 32). Damage occurs only in the falling
phase and each victim is struck once. The initializer uses original voice
0x5F6; event0x447 accompanies the apex transition; selector3 contact uses0x439.

Standing/air Lumina use original entries `800D4F14` / `800D4F8C` and contact
ticks8–14 /4–10. Mighty Strike uses table23 `800D552C`, contact10–19 and tick11
sound0x9DA. Ordinary Lumina Rotation uses the Norm module in MAIN/42: body
`800D5360`, eight windup ticks, ten accelerating world turns in a paused pose,
one following update to reset facing, then four recovery ticks at `800D53A4`.
Only Lumina(part25) scales: Rotation ramps to1.25×, Mighty Strike holds
0x19EB/4096 until exit. Rotation contact follows the swept82-unit blade tip
at30 source units above the ground, rather than hitting a whole circle at once.
The turn sums are286,602,948,1324,1730,2166,2632,3128,3654,4210 in4096-angle
units. Native actor5 descriptor8 draws its red ribbon; sound0x450 plays at entry.
Mighty Strike uses descriptor7 plus its golden vortex. Keys4/5 deliberately
bypass charge and the successful-defense prerequisite for immediate access. Existing game collision, damage and bonuses remain adapters.
The learned techniques restored below share these controllers. Throwing Fusion,
capturing/assimilating enemies and scroll powers are not implemented; five
previously recovered assimilated attacks are available independently.

## Learned sword techniques — 2026-10-30

Crosswise Cut is the requested X Slash. The retail `80155A44` branch requires
the first Fusion cut to connect before Lumina can follow. Its body is the
existing `800D4F14` Lumina animation; the missing behavior was the combo route
and one actor `0x54` impact on a successful follow-up. The red 48×48 texture,
CLUT, quad, accelerated growth, five-tick hold and fade come from the supplied
disc. Four prepared impact slots per model avoid loading or constructing an
effect during a hit. A missed opener still queues ordinary Lumina.

Tenderize uses `800D51E0` and `800D524C`: two distinct contact phases, a tick-8
upward impulse of -12 source units, and +1 gravity per 30Hz source update.
The second phase inherits drawn Lumina; the added `Recovered__800d524c` clip
preserves that context through its tick-15 sheathing command. Every preceding
animation, mesh, texture, joint and socket is preserved. The optimized derivative
must be regenerated after recovery.

Desperado uses `800D52A8`, then `800D52E8` when heavy is pressed, with both
original Fusion/Lumina ribbons. At tick 8 it lifts with -6 source units and
moves forward at 12 units per update, using the existing movement/collision
owner. Physical landing starts `800D533C`. Focus loss, pause, hit interruption
and character selection clear pending input and presentation.

The techniques are unlocked directly. One-press sequencing, mouse buffering, existing Goemon damage,
target bounds, hit-stop, collision and camera are adaptations; this is not full
PS1 gameplay parity. The original impact was drawn in screen pixels; its host
quad faces the camera at a world contact point and respects scene depth.

`techniques/sources.json` archives 13 decoded streams plus hashed original code,
contact/dispatch tables and the Crosswise sprite/palette. Dashing Pierce,
Fusion throw/return/absorb and Shish Kebab motion are recovered resources only;
their movement or enemy capture/carry behavior is not yet integrated. Rumparoni-SP
has not been positively identified. Elemental Lumina spells are deliberately
excluded from this recovery pass.

Rebuild with `tools/recover_musashi_actions.py`,
`tools/recover_musashi_sword_effects.py` and `tools/recover_musashi_techniques.py`,
then `python3 tools/goemon_assets.py optimize --asset musashi` and the toolkit
import/preservation/comparison checks. Use the bundled Python for NumPy/Pillow.
Run `tests/forest-shrine/musashi_techniques_test.gd` through Play Goemon for native
contacts, repeated use and actual Wind Meadow captures. Evidence belongs under
`build/Other Files/Asset Toolkit/Musashi Techniques/`.

## Source movement and jumping

`locomotion_sources.json` records raw vectors, constants, source functions and
hashes. Normal digital movement starts at8 source units per tick and adds
.0625 to11; cautious movement caps at4. Source coordinates are16.16 fixed
point with downward-positive Y. The former fitted .018m/unit conversion is
now .054m/unit: mesh, capsules, contacts and movement distances scale together
by three, retaining the same source timing and jump-height/body-size ratio.
Camera focus follows the larger torso while the chosen distance stays unchanged.
Other fighters and the normalized equipment preview keep their original size.

At full speed, releasing direction restores original table9 and its short skid:
entry initializes without moving, then eleven four-unit updates travel 2.376m
(.792m at the former fitted scale).
Slower release stops immediately.

The first jump initializes -18, then adds1.625 before each integrated air tick.
Releasing Space while rising adds another1. The L-Belt double jump resets
vertical velocity to-14 before the same tick's gravity, and displays the
original `800D4BE0` spin. Air direction follows the source speed rules; releasing
a direction retains horizontal momentum. Landing restores the two-jump budget.

The default nominal30Hz update is supported by the retail boot loop:
`GameModeDispatch` followed by `VSync(D_800B9A18)`, initialized to2. Original
state advances at30Hz while Godot integrates collisions on host physics
frames. Tests compare literal source trajectories and real body motion at
30/60Hz. Actual emulator-to-Godot frame comparison remains unperformed.

Original body opcode8 markers drive footsteps. The actual SC01 translation
unit maps material0 to0x406/407. Ordinary air landing uses0x42E;0x41E,
previously misidentified as landing, belongs to the ground stop/skid path.
The current environment uses the material0 bank; all original terrain-specific
audio assignments, SPU envelopes and reverb are not emulated.

## Original equipment appearances

`outfit_sources.json` contains five verified VRAM-copy groups and every one of
their32 combinations: L-Goggles, L-Belt, L-Brace, L-Vest and L-Shoes. The
comparison viewer changes actual recovered atlas pages on the existing meshes
and retains an independent material set per model. The original/base pages match the
current GLB texture pixels exactly. These are equipment combinations, not32
different story costumes. No separate story costume was verified. L-Cloth
crafts a Legendary Quilt; it is not a wearable costume.

Gameplay uses the latest full equipment (mask31), with no outfit preference or
picker. The comparison viewer can inspect the recovered alternatives. This
recovery does not reproduce original acquisition, BP costs,
fatigue, low-stat speed penalties, carrying, water/slippery-ground behavior or
every equipment ability. Mouse-facing guard strafe and camera-relative WASD
are intentional control adaptations. Those limits, Godot collision geometry
and the existing damage/VFX integration prevent claiming complete1:1 parity.

## Original colored sword effects

`sword_sources.json` recovers actor4/5 untextured additive Gouraud quads,
the 16-pair world-space ring, two samples per source update, native 30Hz
cadence, descriptor delay/duration/divisor tables and signed pose-header
endpoints for twenty-three attack/continuation entries. Fusion uses original blue
RGB(122,122,244) at full brightness; Lumina uses red RGB(244,122,122).
The alternate pale-yellow Fusion palette is selected by native save flag0x81,
whose gameplay meaning remains unverified; full gear does not force this flag.
Age and fade colors reproduce the native formulas. Separate native trail
indices retain their fades across the next attack, and interruptions clean up.

`special_sources.json` and `effects/special/` recover Mighty Strike's actual
34-vertex/96-triangle TMD, per-corner yellow/red/white/black palette, two
counter-rotating variants and warm twelve-sided shock ring. Source tick11
spawns the three effects once at transformed pose-header point[0,-6,-120].
Their positions are snapshotted in world space, with shared native light-bias
fade and original growth/spin constants. Backface culling avoids double
addition of the original explicit reverse-side triangles. The recovered
metal/block flash and line-spark geometry is archived for further contact
restoration; it is not substituted for every enemy's hit effect.

`charged_action_sources.json` records the distinction between ordinary Rotation
and Mighty Strike. The earlier Table23 "Rotation" label was incorrect; it has
been corrected in runtime controls and recovery tools.

The host renderer uses native-style additive blending without invented
particles or glow. Camera projection, color grading, native GTE lighting,
integer midpoint rounding, dithering and initial actor-queue phase still differ
or lack emulator frame comparison. Host attack-speed bonuses affect body
animation while the native effect queue retains its own30Hz cadence. This is
source-based recovery, not a claim of pixel-identical PS1 emulation.

Gameplay uses all five gear pieces. Double jump remains enabled independently
of the comparison viewer's equipment mask.

## Recovery evidence

`action_sources.json` includes source pointers, commands, event windows, hashes
and a stored GLB verification of3,441 recovered joint/frame transforms, with maximum
float32 error below3.61e-7. Bare continuations use the normal drawn-Fusion
visibility context. `outfit_sources.json` preserves source rectangles, copy
order, CLUT bindings and exact texture hashes. Audio provenance records original
executable dispatch, bank, sample, pitch and WAV hashes; identical decoded
0x406/407/42E and0x439/9DA samples are safely shared.

Tools: `recover_musashi_actions.py`, `recover_musashi_outfits.py`,
`recover_musashi_audio.py`, `recover_musashi_sword_effects.py` and
`recover_musashi_special_effects.py`, `recover_musashi_charged_actions.py`. Source reference: Druthulu/BFM-decomp revision
`b6a28f96bac70af70573826f767a96cf212fd5e3`, using actual SC01 translation units
and verified supplied-disc bytes. Development captures/reports live under the
canonical project's `build/Other Files/Musashi ROM Gameplay Audit/`.

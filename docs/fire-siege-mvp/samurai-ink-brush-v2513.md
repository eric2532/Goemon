# v2.51.3 Samurai and energy-wave ink-brush preview

Samurai's five-cut combo now paints red ink-brush crescents following his actual
katana. Dark crimson paint, warm white cutting edges, orange accents, tapered
ends and bristle grooves retain the distinct left/right, diagonal, front and
half-turn cuts. Confirmed katana hits create a white/red cut burst, crimson
fragments and an expanding red ring; the final cut has a larger hit burst.

The five animations, melee reach, contact timing, attack-chain damage bonuses,
150-damage piercing red energy arrow, arrow range and utility remain intact.
The ultimate still lasts ten seconds, repeats the same five cuts five times
faster, and displays the existing red energy aura. A short 0.08-second brush
tail during the ultimate keeps the faster strokes readable; extra attack-speed
bonuses shorten that tail proportionally.

Magic Swordsman's RMB / 3 energy wave now has a broad purple ink-brush body,
lavender-white cutting edges, cyan accents, a trailing crescent layer and ink
texture animated by the projectile clock. Its flight rules remain: 100 base
damage, 40-metre center travel, roughly 5-metre corridor, piercing enemies,
stopped by buildings; ground casts stay level and airborne casts keep vertical
aim. Normal 2.1-second cooldown and Final Strike's 0.42-second cadence remain.
His existing purple melee crescents and impacts are included.

Both sword trails sample the weapon after its actual pose updates. Consecutive
poses seed a new ribbon so ultimate-speed strokes remain visible between
physics frames; one final real pose is captured when a step crosses the end of
follow-through. Cuts that finish within one physics step retain one displayed
authored follow-through pose without delaying combat retirement. The ribbon keeps at most 18 poses / 104 vertices and fades in
0.16 seconds for Samurai, 0.20 seconds for Magic Swordsman. Low/Medium/High
retain the existing 2/3/4 live ribbon limit. Confirmed-hit bursts use the existing
displayed-frame/live admission caps and batched particles. The wave reuses its
two blade layers and two fins. No dynamic lights or screen-wide effects added.

This separate preview also includes the crosshair, J visible-target lock,
Ranger's spread and curved shots, Japanese districts and discoveries, shrine
defense and arrow-to-ice tower upgrades. Character model assets are unchanged.

Validation includes actual-input blade tracking for all five cuts, original
combo damage, finite trails, Low/reduced-flash visibility, ultimate-speed
nonzero ribbon geometry, 2×/3× pickup speed and 4.5× pickup-plus-chain tempo, cancellation/pause/reset/hero switches, damage to 20
enemies with bounded hit feedback, and the animated wave. The existing Samurai
combo/arrow/ultimate, Magic melee/wave, controls, crosshair, lock-on, Ranger,
effect-budget and projectile-query suites are rerun on source and exported
resources. Real map renders inspect the new shaders, cut angles and hit burst.
Full-session playtesting and FPS measurement remain deferred by the user.

Try it: BETA / Build & defend → Samurai or Magic Swordsman. LMB uses the melee
combo, RMB / 3 the energy projectile, R the ultimate. J toggles the nearest
visible target while you retain mouse camera control. Explore between waves;
hold Y to start shrine defense.

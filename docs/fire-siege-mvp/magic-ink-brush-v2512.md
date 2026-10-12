# v2.51.2 Magic Swordsman ink-brush preview

Magic Swordsman's three melee cuts now paint a purple crescent along the actual
sword path. A lavender cutting edge, dark violet body, bristle grooves and small
cyan accents give the slash an ink-brush appearance. The finishing cut follows
the sword's overhead swing. Misses show the swing without a hit burst.

Successful sword and energy-wave hits produce a compact white/lavender cut,
purple fragments and an expanding violet ring. The existing hit-stop, damage,
knockback and attack cadence remain intact; finishing hits have larger bursts.

The ranged wave from v2.51.1 remains: RMB / 3, 100 damage, 40-metre center travel,
roughly 5-metre corridor, piercing enemies, blocked by buildings. Ground casts
stay level, airborne casts retain vertical aim. Its ordinary 2.1-second cooldown
and Final Strike's 0.42-second repeat are unchanged.

The trail samples the native weapon after its pose is updated. One mesh stores
at most 18 blade poses, interpolated into at most 104 vertices. It stays in world
space as the player moves, stops emitting during recovery, and fades in 0.20s.
Low/Medium/High allow at most 2/3/4 live ribbons; impacts and particle bursts use
the existing displayed-frame and live feedback caps. No dynamic lights or
full-screen passes were added. Reduced flashes lower the cutting-edge emission.

This separate preview keeps the crosshair, J visible-target auto-lock, Japanese
districts and discoveries, shrine defense, ice upgrades, Ranger's spread and
curved shots, and other heroes' effects. Character model assets are unchanged.

Validation covers real melee input, all three cuts tracking the authored blade,
world-space movement, whiffs versus hits, expiry, cancellation, pause, hero
switches, reset, Low/reduced-flash visibility, crowded hit budgets and damage,
held attacks, ranged-wave behavior, and Ranger isolation. Related combat,
crosshair and flight suites are rerun against source and exported resources.
Rendered previews inspect the new brush shader and hit burst in the real map.
Full-session playtesting and FPS measurement remain deferred at the user's request.

Try it: choose BETA / Build & defend, then Magic Swordsman. LMB performs the
three-cut combo; RMB / 3 launches the long-range wave; R activates Final Strike.
J toggles closest-visible-target auto-attack while mouse camera control stays
with you. Explore between waves; hold Y to begin shrine defense.

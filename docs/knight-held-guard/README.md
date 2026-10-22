# Knight held guard

Hold RMB or 3 to raise Knight's frontal shield indefinitely. Release the final held input to lower it. Raising guard has no cooldown. Movement retains its existing guarding speed and shield pose; primary attacks wait until guard is lowered.

A frontal block prevents incoming damage and emits three large navy energy shields at 0, .22 and .44 seconds. Each shield sweeps six metres forward in .18 seconds, with a maximum width of twelve metres and height of 6.6 metres before the character's range multiplier. Its visible polygon is also its damage cross-section. Each face deals 80 base damage per contacted enemy, using the usual character damage/critical/combo modifiers. Solid cover and fog rules apply. Back attacks still hurt.

One burst can run at a time; additional hits remain blocked without stacking bursts. The guard stays raised throughout. Released shields finish if you lower guard; death, full cancellation, character changes and run resets discard pending damage. One burst earns one attack-chain link even when several faces/targets connect. Master Thief's existing timed guard remains unchanged.

Enemy health bars remain hidden after hits and tower damage. The player HUD and training dummy label are retained. The local saved invincibility setting was disabled after diagnosing enemy damage; future settings remain user-controlled. Enemy arrows now measure hero height relative to map terrain so a player on raised walls remains hittable.

Verification: `tests/forest-shrine/knight_held_guard_test.gd` exercises real input, guard lifetime, multi-source releases, front/rear damage, bounded bursts, three contacts, multiple targets, cover, cancellation and real melee/archer HP loss on both flat ground and raised walls. `--visual` saves a native shield preview. Low-fidelity, Ninja refresh, melee reach and Twin Ramparts regressions also run before export.

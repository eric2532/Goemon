# Japanese Districts Crosshair v2.51.0 preview

Built with Godot 4.6.3. This separate development preview enriches the three
expanded Fire Siege districts and adds J auto-lock while keeping mouse camera
control. FPS measurements are deferred at the user's request.

Sakura Grove has timber homes, an open tea house, shrine/fox altar, a pond bridge,
lantern paths and planted gardens. Neon Village has Japanese shopfronts, a
two-story inn, noren curtains, noodle/dumpling stalls, carts, a well and neon
frontage. Ruined Watchpost has weathered storehouses, a gatehouse, lookout tower,
broken walls and overgrown courtyards. Imported static meshes are batched by
surface and spatial cell, with no added real-time light or particle systems.

Each district retains its +3-gold supply cache and adds one hidden +2-gold chest
and one short lore discovery. Approach within 2.5 metres during preparation to
collect, with a clear line of sight. Rewards/finds occur once per run, reset on a
new run, and cannot be collected while paused, dead or defending. The HUD shows
supplies and discoveries separately. Total optional exploration income is 15 gold.

J toggles auto-attack and nearest visible enemy aim within 120 metres. Targets
must be in the camera frustum with terrain visibility from the camera and hero's
class launch position. Projectile release also checks its actual muzzle. Dead,
freed or off-screen targets release immediately; nearest/cover searches refresh
every 0.15 seconds. A gold LOCK marker identifies the current target. J does not
rotate the camera; mouse aim returns when disabled. All twelve heroes use this
reference, including Goemon's background coins and Edo's animated-hand fireballs.
Ranger retains release deviation, curved flight, third-shot power and broad fans.
Committed melee swings keep their captured direction until the next attack.

The main shrine, defense waves and attack pacing, twelve tower sites, four mines,
arrow-to-ice upgrades and custom map behavior remain. Hold Y for three seconds
when ready to defend. Building models have simple collision hulls; this pass adds
scenery and discoveries rather than a new NPC/interior interaction system.

Validation logs, engine/pack hashes and preview limitations are included beside
the packaged app. No sustained FPS claim is made for this preview.

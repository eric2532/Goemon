# Goemon — Fire Siege MVP / Sky Descent

A fully local Godot 4.6.3 action game. **Fire Siege MVP is the primary development
version**. This `codex/fire-siege-spirit-effects` branch adds Spirit Fortress's
visual techniques to the playable Fire Siege game as **v2.46.1**. The legacy
Sky Descent material below remains reference for that older mode.

The pushed **v2.45** base is on **`codex/fire-siege-mvp`**, commit `8758b73`.
See [agent review instructions, verification and screenshots](docs/fire-siege-mvp/github-review-v245.md).

## Fire Siege · Spirit Fortress effects · v2.46.1

Fire Siege now has petals and spirit motes, warm lantern/cool shrine lighting,
distance haze, animated banner cloth, water/foam side pools, floating stones
outside the field, and glowing shrine rune pulses. Use the existing Graphics
quality setting: Medium enables the effects; High also enables one shrine
accent shadow; Low removes the added effects and uses static banner cloth.
Pause freezes every animation. Custom maps gain atmosphere and animated
authored banners, while the map builder retains its clear editor lighting.

See [integration and verification](docs/fire-siege-mvp/spirit-fortress-v246.md)
and [source provenance](assets/vfx/spirit_fortress/README.md).

v2.46.1 shares identical banner meshes/materials, removes decorative shadow
passes, and corrects particle lifetime fading. See the
[effects performance audit](docs/fire-siege-mvp/spirit-performance-v2461.md)
for measured comparisons and their limits.

## Environment art

The colorful Edo environment reskin uses 13 original editable Blender assets and 128-pixel painted surface textures across Tidefall Sanctuary and the three dormant regions. Characters, gameplay, UI and collision remain unchanged. See [assets, screenshots and validation](docs/environment-reskin/README.md).

The main area now has 48 original Blender town buildings at 4× their previous linear scale, including three open-door houses with usable interiors. See the [expanded town views, entrance locations and validation](docs/tidefall-town-expanded/README.md). Existing routes, spawn and combat courts remain open.

The ground map is now **four times its previous area** (twice the width and depth), approximately **1,176 × 1,031 metres**. Existing Tidefall streets remain in place; new furnished districts occupy the expanded sides and north, with paths back to the original courts. Terrain pads keep entrances flush. Enemy AI freeze is a session-only Prototype Lab option and always resets to off when the game launches.

## Fire Siege · Automatic construction · v2.45.0

Version v2.45.0 introduced automatic construction; v2.46.0 retains it.
Stand beside an affordable tower or mine spot to build automatically. No B
input is needed. Empty sites use small muted stones; a full translucent
preview appears nearby, with a circular progress ring filling counterclockwise.
Moving, jumping or rolling stops work; standing nearby again resumes it.
The completed structure becomes solid and charges once. Tower: 3 seconds /
5 gold; mine: 4 seconds / 10 gold. See [construction controls and verification](docs/fire-siege-mvp/auto-build-v245.md).

### Automatic normal attack · v2.44.0

Press **J** during play to toggle automatic normal attacks for any hero. Move
and aim with the camera; no left click is needed. The HUD shows ON, PAUSED or
OFF. Normal attack speed, combo effects and Ranger's double-jump fan remain
active. Menus, construction and evasive moves suspend automatic attacks;
new runs, death, hero changes and entering the editor reset the toggle OFF.
Manual attacks and Mage charging still work. See [controls and verification](docs/fire-siege-mvp/auto-attack-v244.md).

### In-game map builder · v2.43.0

Choose **BUILD YOUR OWN MAP** in the main menu. Place scenery, ground tiles,
tower/mine sites and gameplay markers on a flat 160×310m field. Move/rotate,
duplicate/delete, snap to a 1/2/4m grid, undo/redo, save/load named local maps,
and press **Play Map**. Pause your custom siege and choose **Return to map
builder** to continue editing. The ordinary Fire Siege map remains available.

New modular pieces include a torii gate, garden pavilion, stone lantern,
stone wall, wooden fence, bamboo grove, cherry blossom, cedar, mossy boulder,
supply crates and jade banner. Ordered route markers support turns and
backward segments; validation catches blocked routes and unsafe spawn areas.
All v2.42 Ranger changes remain. See [builder controls and verification](docs/fire-siege-mvp/map-builder-v243.md).

### Previous Ranger high jump and held-Space slow fall · v2.42.0

Version v2.42.0 introduced the Ranger air update.
Ranger's first and second jumps now reach **twice their previous height**.
Hold **Space while falling** to descend at **one-third normal speed** and keep
firing arrows. Release Space to fall normally. Holding the first jump does not
automatically consume the double jump; release and press Space again for it.
Straight arrows with subtle launch variation, green third shots, combo firing
speed, Rain, five-arrow fans, fitted hat, larger arrows and quick WASD roll
remain. See the [air update and verification](docs/fire-siege-mvp/ranger-air-v242.md).

### Previous straight arrows with human aim variation · v2.41.0

Each Ranger arrow flies straight with small random horizontal and vertical aim
offsets. Normal aim varies up to2° horizontally/1.25° vertically; green power
shots up to2.5°/1.5°. All v2.40 features are retained. See the
[correction and verification](docs/fire-siege-mvp/ranger-precision-v241.md).

### Previous random coverage and snap roll · v2.40.0

Version v2.40 introduced broad random mid-flight sweeps, hit-combo firing
acceleration, Rain powering every release, and the0.15-second/6.9-metre roll.
The mid-flight sweeps are superseded by v2.41's small launch-angle variation.
See the [previous update](docs/fire-siege-mvp/ranger-storm-v240.md).

### Previous curved Ranger arrows and green third shot · v2.39.0

Version v2.39 introduced actual curved arrow flight, the wider fan, and each
third LMB release becoming a larger green energy shot with 50% more damage.
See the [previous flight update](docs/fire-siege-mvp/ranger-flight-v239.md).

### Previous Ranger fan shot and fast roll · v2.38.0

Version v2.38.0 was based on the latest v2.37 MVP. Ranger now wears a full fitted hat, uses arrows
20% larger than v2.37, and fires five simultaneous fan arrows with **RMB / 3**.
After **Space twice**, **LMB** fires the fan downward. **C** performs a fast
quarter-second tumble in the movement direction. See the
[Ranger update and verification](docs/fire-siege-mvp/ranger-upgrade-v238.md).

### Previous closed masks and Samurai proportions · v2.37.0

Download the [v2.37.0 MVP GitHub release](https://github.com/eric2532/Goemon/releases/tag/fire-siege-v2.37.0-mvp)
for the previously published universal macOS and Linux x86_64 builds. Repository access is required.

Samurai now has a shorter neck, a lower head/helmet position and a compact fitted
scarf. Dragoon's dragon helmet covers his face; Magic Swordsman wears a purple
demon mask beneath his crystal crown. The long animated scarf and v2.36 combat
updates remain. See the [mask refinement verification](docs/fire-siege-mvp/mask-refinement-v237.md).

### Previous equipment and skill update · v2.36.0

Dragoon wears a blue dragon helmet, Magic Swordsman a purple enchanted helmet,
and Samurai a red face-wrap scarf with a long animated tail. Ninja has a slightly
fuller jaw. Airborne Dragoon Leap (right-click / 3) now descends into an actual
ground impact; Ranger fires three times as often and uses twice-size arrows.
See the [equipment follow-up plan](docs/fire-siege-mvp/equipment-upgrade-v236-plan.md)
and [verification](docs/fire-siege-mvp/equipment-upgrade-v236-verification.md).

Choose **Fire Siege**, Beta or Hard, then Goemon, Edo or any of the ten Rogue heroes.
All ten Rogue heroes use the coordinated head, face-layout and hair direction
introduced by Magic Swordsman and Explorer. Exposed faces have integrated depth,
defined cheeks and jaws, and projecting noses; masks and headwear retain each
hero's identity. See the [original design direction](docs/art-direction/rogue-design-pilot.md)
and [roster upgrade plan](docs/fire-siege-mvp/roster-upgrade-v235-plan.md).
The local v2.35.0 app, visual review and validation are recorded in the
[upgrade verification](docs/fire-siege-mvp/roster-upgrade-v235-verification.md).
All twelve heroes now turn their bodies toward camera-relative movement in every direction, including backward and sideways travel. The camera follows backward movement immediately and waits for one metre of forward travel before following; each new forward input re-arms the buffer. Hero designs, camera-aimed attacks, signature skills and progression are preserved.
The redesign uses the published arrow tower, gold mine and construction FX from
`codex/fire-siege-economy-assets-v1` (`9b63371`).

Start with **10 gold**, twelve empty tower sites and four unbuilt mines, with three
mines close to spawn. Approach any accessible side of a structure and **hold B**
when the **IN RANGE** prompt appears. An arrow tower costs
**5 gold**, takes 3 seconds to build, and fires a visible **50-damage arrow every
0.5 seconds**. Each mine costs **10 gold**, takes 4 seconds, and independently
earns **2 gold/sec while the wave is spawning**. Empty progress bars and build-pad
circles are hidden; a bar appears after construction begins. Releasing B gradually reverses
construction; reholding resumes it. Moving interrupts construction and requires
a fresh B hold once stationary. Payment happens only on completion.

Every wave starts in unlimited preparation. **Hold Y for 3 seconds** to launch it.
Each of ten waves schedules **five enemies per second for 60 seconds**, then waits
until every remaining actor is killed or has breached the base. Wave N pays
**10 × N gold**, including the final 100 before victory. Kills retain progression
and direct healing but give no gold or pickups. There are no card drafts or upgrades.

Completed towers consume **0.1 gold/sec each**, including idle time, during spawning
and clearance. At zero funds, towers pause firing until paid time is available.
The mine stops earning during clearance, so holding the last enemy cannot farm gold.
Preparation and pause do not advance income or upkeep. Beta/Hard start at 100/50 base
integrity; each breach removes one integrity. Only loss of the base defeats the run.

Hero death keeps the siege moving: enemies are **35% faster** until revival after
**5 seconds**. Beta also offers **V / Revive Now**. Revival gives full health and two
seconds of protection. Right-drag the mouse to look around while downed. Gold,
waves, purchases and death state reset on retry.

**WASD** move, mouse camera, **Shift** sprint, **Space** jump, **LMB** primary and
**RMB / 3** secondary for the ten Rogue fighters (including holding/releasing),
**C** evade, **R** signature skill, **Q** hero roster, **G/H** existing
ally rosters, **Esc** pause. Goemon/Edo retain E/T/numbered abilities. **E** uses
Samurai's bow, Ninja's enlarged shuriken fan, Explorer's Hook Shot, or Master Thief's
Get Down. Allies keep existing prices and
abilities, stay active during hero death, and cannot be attacked by enemies.

The Rogue fighters use revised weapon grips and distinct attacks: Ninja's long
dash cut, Samurai's giant red slash, Explorer's evasive reverse-grip cuts and dash
cross slash, Dragoon's wider thrust and three blue landing shockwaves, and Knight's
two-second guard with a massive navy shield counter. Mage's primary releases a
fireball on click release, with larger charge tiers at one, two and three seconds;
frost nova freezes nearby enemies for three seconds without damage. Master Thief
has faster, wider pipe attacks and a stationary red guard while holding secondary,
lasting at most three seconds. Growth scales the pipe's reach and effects.

All twelve heroes' basic attacks have **three times their previous range**, with
growth scaling on top. Magic Swordsman can press LMB after the second jump to
dive forward and down into a powerful violet energy slash. Dragoon's normal and
second jumps reach **twice the normal height**. Pirate's shot is a visible,
ten-times-larger piercing bullet; every Mage fireball tier also pierces enemies
along its straight path. Solid cover still blocks projectiles.

Ninja and Explorer have a small energy meter. **Five completed light attacks**
fill it and earn one **free RMB / 3 heavy attack**, usable during the normal
cooldown. Using the bonus consumes the meter without restarting that cooldown.
Normal heavy attacks remain available when their cooldown expires. Death,
changing heroes and restarting clear the meter.

Launch with `--tower-defense`, or use the **Fire Siege macOS/Linux** export.
Run `--fire-siege-mvp-test`, `--fire-siege-campaign-test` and
`--fire-siege-controls-test`; `--rogue-combat-upgrade-test` checks the upgraded kits
and `--rogue-upgrade-tour` captures their appearance in game.
`--rogue-roster-v235-test` checks the new ranges, energy, piercing and aerial
skills; `--native-primary-range-test` covers Goemon and Edo. The rendered
`--rogue-roster-upgrade-tour` captures all ten designs and the new abilities.
`--movement-camera-test` checks every hero plus the forward buffer, reversals and Sky Strike recovery. Add `--movement-camera-visual` for rendered movement captures. Deterministic/asset suites are documented in
[implementation decisions](docs/fire-siege-mvp/decisions.md) and
[verification](docs/fire-siege-mvp/verification.md).

## Sky Descent · Active gameplay loop

Play begins on **Dawn Crown**, 728 metres above Tidefall. **784 islands form 14 altitude layers**, with eight nearby groups of seven islands per layer. Six polygon silhouettes (including ridges, wedges and notched shapes), seeded rotation and size variation replace the round platforms. Each group's central island has six surrounding jumping destinations, separated by real air gaps. Sprint and double-jump between them, descend to another layer, or use the gold cloak for long crossings. There are **no continuous cloud roads**: roughly 250 small, separated cloud platforms sit below the islands as resting places. Collisions, spawn points and enemy ledge steering follow each island's actual outline. Y generates a new map; retry preserves the seed. Ground arrival activates **50 giants and 24 nearby raiders**, regardless of which islands you visited.

**Gold flight cloak:** press **5** to equip/remove the gold version of the exact existing cape mesh, with the same cloth animation. **4** selects the red cloak. With gold equipped, **hold Space to ascend**, steer with WASD, and **hold Shift to boost**. Releasing Space eases into a gentle descent. Normal flight is 36 m/s horizontally and 18 m/s upward; boost is 64 m/s horizontally and 32 m/s upward. Level movement bonuses multiply horizontal flight. The body leans forward smoothly while airborne. Solid walls and clouds still block movement, and the cloak remains specific to Goemon when switching characters. Existing cloak ground movement and coin bonuses remain available.

Each defeated island enemy grants **one full level immediately**, without any drops to collect. Each pair of altitude layers adds one enemy per island, from **4 to 10**, for **5,488 starting island enemies** before reinforcements. One kill still grants one level until the **level-99 cap**; further kills count toward clearing the route. Both characters share levels. A fresh run or retry resets to level 1. Maximum health grows from **100 to 400** with default tuning (up to **4× base health** at level 99). Level-ups add only the newly earned health capacity to current HP, alongside normal kill healing; checkpoints and character switching preserve it. Attack speed, movement speed and jump height grow gradually to **+75%, +40%, and +60%**; cloak and temporary buffs still multiply those bonuses. Ground jumps, air jumps and wall hops all gain height.

Ground giants use **5× model and collision size, 8× health, and 3× attack damage**, with matching melee reach and reduced knockback. Two giants spawn in each of the nine original courts and sixteen furnished districts after arrival, leaving the landing area clear. The HUD tracks remaining giants. Health upgrades prepare the hero for this final ground encounter.

The ten nearest island encounters stay loaded, with at most 120 island enemies. New actors enter at a maximum of four per frame to smooth travel and reinforcement bursts. Nearby-island HUD searches refresh five times per second; distance labels and combat meters still update each frame. Island searches inspect nearby altitude layers, sort precomputed distances, and reuse HUD panel styles. The scene contains roughly 30% fewer nodes than the dense road layout. Rendered timing results are mixed and do not yet establish an FPS improvement; see [sky performance measurements](tests/sky-performance/README.md). Loading follows both horizontal and vertical travel, including flying back up after reaching ground. Defeat records persist across unloading and revisits. Skipping an island never awards kills or marks it cleared. The HUD lists nearby islands by altitude, grid location and distance and identifies cloud rests and freefall.

The main mode has no global survival countdown or timed ground swarms. Islands with unfinished objectives gain two reinforcements every eight gameplay seconds, up to twelve living enemies per island and the configured global actor limit. Distant islands track their rosters without creating offscreen actors. Completing the objective disables that island’s reinforcements; finish its remaining guards to mark it cleared. Partial kills and objective progress remain recorded across revisits. Nearby enemies pursue and attack, and other islands visibly patrol their platforms. Pausing freezes reinforcement timers. Knocked-off enemies count as kills. The HUD shows nearby island choices, cleared islands and character level. Sky Strike, Edo teleport and meteor targeting respect the current island and its elevation.

The runtime island silhouettes use six shared meshes and collisions from `scripts/island_shapes.gd`. The original Blender kit is retained as source/reference: three meadow/rock island variants, two sculpted cloud banks, and a sun with halo rings. Editable source: [Sky_Descent_Islands_and_Clouds.blend](assets/blender/sky_descent/Sky_Descent_Islands_and_Clouds.blend). Rebuild with `tools/build_sky_descent.py` in Blender. Runtime exports live under `assets/models/sky_descent/`. The flat-topped cloud platform variants are authored in [Walkable_Clouds.blend](assets/blender/sky_descent/Walkable_Clouds.blend) and rebuilt with `tools/build_walkable_clouds.py`.

Cedar Pass revisions `034d81a` and `e44a1bb` are merged from `origin/feat/cedar-pass-environment-pack`. The full editable pack, furnished buildings and traversal lab live in `asset_packs/cedar_pass/`; its 22 GLB exports are also copied into `assets/models/cedar_pass/` for the main Godot project. The sky islands use its pine, sakura, cedar, gate and bamboo assets. The main ground map now includes **96 furnished Cedar Pass buildings across 16 districts**: shops, inns, tea houses, warehouses, shrines and gatehouses. Authored wall/furniture collision and smooth entry/stair ramps are active. Roofs and near walls cut away indoors, with a closer camera; collision remains solid. Inns have accessible upstairs rooms. All six designs now use **1.5× their authored scale**, including furnishings, doors, collision and stairs, alongside the existing enlarged Tidefall buildings.

Validate the ground expansion, real enemy pursuit/damage, reinforcement rules, all six building entrances, cameras and inn stairs with `--district-test` (`--district-visual` captures interiors). Validate free descent with `--descent-test`, or `--descent-visual` for rendered views. The route test checks landing samples across every layer and map corner, isolated-cloud landing/jumping, skipped layers, revisits, and a full-height fall. `--flight-test` validates all 784 island and scattered cloud collision surfaces, flight controls, boost, cape/character switching, collision, and returning to the sky from ground; `--flight-visual` also captures the gold cape and map. Prior survival behavior remains available for diagnostics with `--legacy-survival`; older test commands below require that flag when they assume the former swarm mode.

**2 is an on/off coin toggle.** It fires immediately and repeats alongside movement, pipe attacks and chain attacks, aiming at the nearest unobstructed enemy on screen. Each cast owns its combo/damage ticket. Missing never creates a combo. **Every level adds one coin per volley: level 1 = 1 coin, level 10 = 10, through 99 at the level cap.** Level-ups apply to the next volley even while 2 is already on. The extra coins form a forward fan, with its central coin keeping exact auto aim. All coins do real damage; the volley shares one combo link. Large volleys use instanced meshes and one controller each, and merge same-frame hit feedback per target. The base interval is 0.42 seconds, sped up by attack-speed bonuses with a 0.12-second minimum to bound projectile load even at 100 links. R makes the repeating coins giant; the robe retains its bonus coin. Dodges and travel attacks temporarily suspend firing; pause freezes it. Character switches, death and new runs turn it off. The HUD displays the coin count and `ON/OFF`. Coins never generate red bonus slashes.

**1 is the same wind spin as R + left click:** 70 base damage, full-circle melee coverage, powered melee reach, the existing wind animation, and a 16-coin ring with the robe. It works outside R without activating R's other buffs. A live combo skips its windup and adds the separate red hit; RMB → 1 retains the red cross slash.

**Elites alternate two dodgeable specials.** An orange ground circle fills for 1.2 seconds before a 28-damage blast. Move out or jump above it. Their beam tracks for 0.65 seconds, locks its direction for the remaining 0.55-second warning, then channels for 1.8 seconds. The channel pulses for 12 damage, respecting player invulnerability and solid cover. Heavy attacks and freeze interrupt these attacks; defeating or unloading the elite removes its effects. Some small island enemies and roughly a quarter of ground raiders are purple ranged throwers; they wind up, launch two visible projectiles and retreat when crowded.

Validate traversal/enemy changes with `--sky-combat-test` or `--sky-combat-visual`; use `--coin-scaling-test` / `--coin-scaling-visual` for level-scaled coin volleys and melee-only red bonuses. See [sky combat validation](tests/sky-combat/README.md) and [coin scaling validation](tests/coin-scaling/README.md).

## Play

Open **build/Goemon.app**, then choose **Sky Descent** or **Tower Defense / Fire Siege**. The macOS application includes the game engine and all content. You do not need Godot, a terminal, an account, or an internet connection.

### Fire Siege mode boundary

The MVP rules above replace the old Fire Siege battery/card economy. The original
`TowerDefense` director, cannon/flame assets and card catalog remain available to
the historical Rogue Siege configuration; Three Gates keeps its separate rules.
Old `--defense-fire-*`, `--defense-tactics-*` and `--tower-defense-beta-*` scripts
are historical fixtures with obsolete Fire Siege opening/balance expectations.
Current redesigned-mode acceptance is covered by the MVP, campaign, structures,
state and hero-control suites. Use `--tower-defense --hard-defense` for Hard.

### Tower Defense · Three Gates (retained standard configuration)

The original three-lane endless configuration is retained for comparisons. Launch with `--standard-defense --tower-defense`; its existing `--tower-defense-test` and `--tower-defense-visual` commands automatically select this standard configuration.

A separate 640 × 760 metre battlefield has three long approaches—Jade, Gold, and Ember—leading from distant enemy gates to a shared shrine. Fight with the same Goemon/Edo characters, weapons, combos, spells, jumps, dodges, and gold-cloak flight as Sky Descent. Enemies advance down their assigned lanes and attack you when you intercept them. Solid roadside walls provide cover while leaving the routes open.

Start with **250 gold**. Walk to one of the **nine wall mounts** and press **F** to buy a **100-gold cannon**. Cannons automatically aim and fire at enemies; press F again at an installed cannon to upgrade it. Every defeated raider pays **12 gold**, including cannon kills. Clearing a wave pays an additional bonus and gives you time to build and reposition before the next swarm. Wave sizes and strength grow over an endless run; live enemy counts remain bounded by the existing enemy limit.

The HUD shows gold, wave timing, shrine health, and tower construction information. Raiders that reach the shrine damage it without awarding a kill or gold. The run ends if you fall or the shrine is destroyed. **Esc → Restart defense** resets the battlefield and economy; **Main menu** lets you switch back to Sky Descent. Pausing freezes waves and cannon fire.

Developer checks: `--tower-defense-test` exercises the new mode; `--tower-defense-visual` also captures the menu, battlefield, cover, and cannon combat in `tests/tower-defense/`. Use `--tower-defense` to launch directly into the mode.

Keep the play folder simple: `build/Goemon.app` is the single current launch icon. ZIP exports, previous versions and staging folders belong under `build/Other Files/`. Future releases should replace the current app in place and preserve older copies inside that supporting folder.

Performance work now includes **80 m terrain sections** so offscreen terrain and shadow passes can be culled, shorter visibility ranges for small scenery and interior furnishings, collision-tested interpolation for distant island patrols, and a navigation builder that yields after each cell when its 0.8 ms budget is exhausted. Nearby combat, airborne enemies and knockback retain full collision movement. All terrain and building collision remains active. Run `--world-performance-test` for terrain seam, patrol, knockback, freeze and navigation consistency checks. See [repeatable measurements and validation](tests/world-performance/README.md).

The application is a universal Apple Silicon / Intel macOS build. The project uses Godot's native Metal Forward+ renderer. Select Performance in Settings if needed.

Press **Y** during play (or choose **Esc → Y · Shuffle map + new run**) to generate a new seeded layout and restart the descent. Islands, isolated cloud rests, town houses, furnished districts and outpost shrines change location. The coastline and central landmark/interior anchors stay fixed so the terrain and original routes remain usable. **Restart descent** retries the current seed; the pause screen displays it. Shuffling resets health, kills, levels, combo and encounters, while preserving settings.

Island enemies acquire you while you approach or jump above their arena. Reaching the ground adds **24 nearby regular raiders** alongside the **50 district giants**, spread across at most four arrivals per frame with a 3 ms spawning budget. Raiders replenish every eight seconds while giants remain, and distant raiders recycle without awarding kills. The global enemy limit still applies. Clear the remaining ground enemies after the giants to liberate Tidefall. Validate with `--map-shuffle-test` or `--map-shuffle-visual`.

## Island objectives and run upgrades

Melee attacks and spells stay **manual**, with an optional **2 coin-fire toggle**. Nearby-island labels now show **ELITE**, **SHRINE** or **AMBUSH**, along with layer, location and distance. Elite islands have one larger guard with twice the usual health. Shrine islands have a guarded **360-health shrine**; damage persists if you leave and return. Ambush islands require **25 seconds** near the island; time pauses when you leave or pause the game. Each objective awards one upgrade choice, once per run. You can still skip islands and descend freely.

Press **F** after earning a choice to pause combat and pick **Power (+10% damage)**, **Vitality (+10% maximum health)** or **Tempo (+5% attack speed)**. Power and Vitality cap at ten selections each; Tempo caps at five. Upgrades add within their category, multiply existing bonuses, and restore 20 health when chosen. A capped choice becomes a full heal. Escape or “Choose later” preserves the choice. Character switching preserves upgrades; restart and Y reset them. See [adventure validation](tests/adventure/README.md).

## Playable skins

Open **Settings → Playable skins · Choose your look** from the main menu or pause menu. Original Goemon remains the default. **Ren · Storm Rival** is an optional chibi-anime skin with a cocky grin, large blue eyes, broad swept cobalt hair, a white headband and an indigo shoulder sash. It builds on Goemon’s compact body and expressive proportions, using the same in-game lighting. Both skins have live previews and a Golden Surge preview. Selection applies immediately and is saved across launches, character switches and retries. Weapons, cloak and abilities retain their existing behavior. See [asset sources and validation](docs/goemon-skins/README.md).

## Attack chains

Combos now start and grow on **confirmed enemy or building hits**. Swinging into air, blocked attacks and empty spell casts do not add links or refresh the timer. Each connected attack or cast earns one link, and a separate red bonus attack earns another when it connects. Multiple targets, projectile fans and repeated beam/shield pulses do not multiply links from the same attack; sustained hits refresh grace. A connected swing finishes before its remaining 1.75-second grace drains, while a missed swing does not pause that countdown. Held beams need real contacts to preserve a chain. Pause freezes grace; death and new runs reset it, invalidating old projectile tickets.

Each link beyond the first adds **5% attack speed**, capped at **1.5× at 11 links**, multiplying level and pickup bonuses. During a live chain, **LMB pipe swings, RMB heavy swings and 1 wind spins skip windup and hit immediately when the attack starts**. Enemy recoil and each swing's follow-through remain, without player hit freeze. The opener and first attack after expiry keep their normal windup.

**Damage also grows by 5% per confirmed link**, up to **1.5× after ten landed links**. The next attack snapshots the bonus when it starts; all of its targets, projectiles, sustained spell hits and separate red follow-up share that multiplier. It stacks with existing damage upgrades. Expiry returns new attacks to base damage, while already-cast projectiles retain their bonus; restarting invalidates old bonuses. The combo HUD shows speed, damage and remaining grace. **25 links = HEATED**, **50 = BLAZING**, and **100 = UNLEASHED**, with milestone bursts and sound. These milestones do not further accelerate the existing speed ramp.

The original weapon attacks and colors stay visible. Chained pipe swings add a **separate red melee attack for 24 base damage**, with its own forward hit area, wall checks and exactly-once damage. **A connected RMB → 1 creates a red cross slash in front of the character**: the 360-degree wind spin and forward red attack have 70 and 24 base damage. After the opening heavy hit, their shared 1.05× bonus produces 73.5 + 25.2 damage. Its two visual arms are one bonus hit. The red hit does not weaken a heavy attack's launch or recoil and cannot recursively create more bonus attacks. Chained long sweeps also add a red melee follow-up.

**2 automatically aims at the nearest visible, unobstructed enemy within projectile range**. Coins keep their combo damage scaling and confirmed-hit credit, but never create red projectiles. **Only melee pipe attacks, wind spins and chain sweeps trigger red bonus slashes.** With no target, 2 fires camera-forward. Existing robe coins remain and share their originating attack's combo credit. Manual mouse attacks, 1 and 3 share an eight-input queue; E, C, T, pause, character switching and retry clear pending attacks.

For this combat test, **regular monsters have 5× their previous health**, including the base health used by sky-layer scaling and ground giants. Their attack damage and movement speed are unchanged. The chain weapon's links are **2.6× wider/thicker**, with unchanged link length, mesh detail and the existing 512-instance budget.

Red effects reuse shared meshes and materials, cast no shadows, add no lights, and cap temporary slash effects at 24. See [combo validation](tests/attack-chain/README.md).

At **100 confirmed links**, the HUD shows **UNLEASHED**. Every manual attack (1, 3, LMB or RMB) releases immediately, with no windup, recovery lock or input queue. Goemon’s 2 remains a toggle with a bounded automatic cadence; enabling it releases its first coin immediately. Goemon's light pipe triplet releases all three strikes together. Edo gains 1 for volley, 2 for giant fireball and 3 for meteor rain. E, R and T also skip their cooldowns or startup where applicable. Projectiles and meteors still travel through the world; shield and beam pulses keep their normal cadence. Once the hit-based combo expires, normal attack timing returns.

## Building destruction and growth

All **157 buildings**—48 town houses, 96 furnished district buildings and 13 temples/shrines—have **240 health** and take damage from weapons and spells. Walls still block attacks; a hit displays the building's remaining health. At 75% health, cracks appear across the surfaces; at 40%, the cracks deepen and one separately authored roof piece breaks off, with its collision removed. A regular building also reveals one attack-speed, ice or fire pickup when destroyed. Objective shrines instead award their island upgrade. Destruction removes the building and its collision, refreshes enemy navigation, and leaves short-lived cosmetic rubble. Rubble has no physics simulation and is capped at 96 pieces.

Each destroyed building grants **+2% character size and attack reach**, capped at **2× after 50 buildings**. Melee reach, projectile travel distance and width, and spell areas grow proportionally; the camera pulls back to accommodate the larger character. The HUD shows size/reach and buildings broken. At maximum growth, ordinary enemies receive **2.5× knockback**, elites 1.6× and giants/bosses 1.2× (before their existing resistance), so smaller foes scatter while larger ones remain a threat. Growth lasts for the run; restarting or pressing Y restores buildings and resets size. Validate with `--destruction-test` or `--destruction-visual`.

## Survival rules — v2.7

- **One map:** Tidefall Sanctuary. The other three locations and their portals are hidden; their source assets remain available for later development.
- **Ten minutes:** the HUD counts down from 10:00. Staying alive until 00:00 wins; losing all vitality ends the run.
- **Periodic swarms:** up to 100 enemies arrive when the run begins, then another wave every 10 gameplay seconds. Each minute adds 10 enemies to each new wave: 100 in minute one, 110 in minute two, through 190 in minute ten. There are 60 waves (8,700 requested arrivals before capacity limits); the last arrives at 00:10 remaining.
- **Automatic pursuit:** ninjas, wind scouts and iron brutes spawn on clear ground around the hero and immediately run toward them. Surviving enemies remain between waves. Defeated enemies are replaced only by future waves.
- **Pause and retry:** Escape, Settings and Prototype Lab freeze the clock and waves. Restart survival / Try again resets the timer, population, kills and power-ups.

The default hard limit is **200 active enemies**, including practice enemies. Prototype Lab exposes a 32–400 limit that takes effect on the next run; changing it never removes living enemies. Each wave requests only available slots, discards overflow and replaces any previous unplaced request. Skipped demand does not accumulate or burst after kills; the next scheduled wave replenishes free slots. The ten-minute clock, 60-wave progression and wave-size growth remain intact. Spawning retains its 12-per-frame / 3 ms budget and safe placement checks. Swarm bodies use the animated crowd renderer without a full skeleton per actor. The default is a conservative population bound, not a measured Mac frame-rate guarantee.

The HUD shows time remaining, wave number and size, the next swarm countdown, enemies alive and kills. The former guardian/door expedition objective is inactive in this mode. Existing characters, weapons, abilities, healing drops and map traversal remain available.

## Weapons, power-ups and spells — v2.11

**Elemental orb prototype — v2.18:** every defeated enemy drops a random **1–5 orbs**, split between yellow attack-speed, blue ice and red fire. Yellow adds **+50% attack speed per stack, up to four stacks / 3× speed**, lasting 20 gameplay seconds and refreshing with each yellow pickup. The old damage and range orbs no longer drop.

Orbs within **8 m** automatically fly into the hero after a short drop animation. Nearby attraction starts with clear line of sight; attracted drops keep following a moving or jumping hero. Uncollected floor orbs last 90 gameplay seconds; attracted orbs do not expire in flight. The former 48-orb discard cap is removed.

Collect **five blue ice orbs** for an automatic ice burst beside the hero, freezing enemies within **7 m for two seconds**. Frozen enemies cannot move or begin attacks, and normal hits cannot shorten the freeze. Collect **five red fire orbs** for a fire-and-smoke explosion within **7 m**, dealing **100 base damage**. Cover blocks both effects. Ice and fire have independent HUD counters, preserve leftovers, and work with either character. Mass collections retain every completed set; effects are briefly staggered for readability. Pause freezes timers, and retry resets counts and pending effects.

A floating **horseshoe magnet** appears on reachable ground shortly after starting, then every 30 seconds, with up to three active at once. The minimap marks magnets with **M**. Walk within 2.5 m to pull every existing orb across the map, including through cover. Magnets expire after 90 seconds so new ones can appear around a moving player. Sound Studio includes separate ice-burst, fire-burst and magnet slots.

New swarms use alternating sectors around the hero at **22–38 m**, with terrain-aware fallback. Pursuers have varied approach lanes and a short movement lead; they close directly for melee range. Coastlines, walls and narrow passages still constrain where enemies can spawn or approach.

Attack speed accelerates Goemon's full combo, heavy attacks, powered spin, coin throws and both legs of T Sky Strike. It also accelerates Edo's triple volleys, large fireball attacks, beam damage ticks, shield pulses, R cooldown and smoke teleport action. Projectiles fly faster with proportionally shorter lifetimes to preserve travel distance. Damage applies to every outgoing hit, including T, beam, shield and smoke. Buff duration, ordinary running/jumping and the survival clock still use normal gameplay time.

**Goemon — direct number attacks (v2.17):** the number keys now attack immediately instead of selecting a persistent weapon. **1** performs a single broad horizontal pipe swing for 48 base damage. **2** throws a normal coin, or a full-sized piercing giant coin during R. **3** performs a 140° chain-pipe fan sweep with **11 m base reach**, increased from 6.5 m, dealing 70 damage once per enemy; R keeps the flaming 110-damage sweep and increases its reach to 18.15 m before range-orb bonuses. Each action returns to the previously equipped weapon. Rapid taps queue up to eight additional number attacks, with no cooldown between animations; attack-speed orbs accelerate them. Holding a number key does not create OS-repeat attacks. E, C, T, pause, character switching and retry clear queued number attacks.

**Mouse attacks:** LMB retains the automatic three-hit pipe combo, and R changes it into the existing 360° wind spin. RMB retains the heavy strike. The robe still adds bonus coins to number attacks and mouse attacks, including the 16-coin ring on an R spin. The chain pipe's Blender asset, effects, collision checks, damage scaling and custom sound slots are preserved. Its long sweep appears only for the number-key attack, then restores the prior weapon.

**Clean combat visuals:** enemy attack-range rings, meteor target circles and the player's old charge/ground-aura circles are removed. Actual weapon trails, fire, smoke and shield effects remain visible; the hit areas themselves are unchanged.

**Edo:** a fixed fireball moveset, with no weapon switching. Tap LMB for three fireballs in a fan; hold it to repeat volleys. RMB immediately throws one larger explosive fireball (96 base damage, 3.8 m splash radius). Attack-speed boosts shorten both casts and accelerate projectile flight. During **R / Blue Surge**, hold LMB for the steerable shield beam. It passes through walls and every enemy in its path. Yellow attack-speed stacks lengthen it immediately: 38 / 57 / 76 / 95 / 114 m at the default base length. Release LMB to stop. R lasts seven seconds; its expiry ends the LMB beam. T now casts Meteor Rain; the beam stays on R + held LMB.

**Meteor Rain (T):** Edo plants his feet, raises his right arm overhead and drives it downward. The strike summons a random **4–12 falling fireballs**, first targeting separated nearby enemy groups within 80 m, then spreading remaining impacts across surrounding ground. Even with no enemies, the spell rains over several areas ahead. Each meteor deals **240 base damage** in a **5.5 m radius**, once per enemy per impact; overlapping meteors can hit the same enemy again. Solid cover blocks the blast. Every landing uses the same Blender-authored fire-and-smoke explosion as his E dodge. Damage and range orbs boost the blast; attack speed accelerates both the pose and rainfall. There is no cooldown: rapid T taps queue up to eight additional casts. Holding T does not auto-repeat. Dodging or taking an unshielded hit interrupts an unreleased spell; released meteors finish independently. Pause freezes falling meteors and clears uncast queued inputs; character switching and restart clear the rainfall.

**Fire dodge:** E teleports Edo to clear ground with fire-and-smoke explosions at departure and arrival. Each enemy can take 36 base damage once per dodge. Bright flame lobes expand into rising charcoal smoke. Editable Blender source: `assets/blender/vfx/Edo_Fire_Explosion.blend`; reproducible generator: `tools/build_edo_fire_explosion.py`; runtime meshes: `assets/models/vfx/edo_fire_burst.glb`.

Pausing stops held fire and beam and preserves the remaining R power; resume and press LMB again to fire. Switching characters, dodging and loss of window focus stop held attacks. Edo's 1 / 2 keys do nothing. Restart clears power-ups and transformations.

**Music settings (v2.17.1):** background music is **off by default**, including when upgrading an older settings file. Sound effects remain enabled at the existing master volume. Turn **Settings → Background music** on to play the locally supplied **TalesWeaver OST – Reminiscence**, looping through the menu and game; turn it off to stop the music immediately. The preference is saved across launches. The MP3 remains bundled at `audio/talesweaver_reminiscence.mp3` and follows the master volume when enabled.

## Attack sound priority and Goemon dash — v2.12

Player attacks have 16 reserved playback voices. Enemy attacks, reactions, impacts and footsteps cannot interrupt them. Impact sounds play at 45% of their former mix level, with at most two overlapping copies per impact type. Custom recordings retain their pitch and per-slot gain.

**Goemon E:** dash four metres toward the camera heading over 0.20 seconds, with 0.34 seconds of invulnerability and a shared 0.80-second evade cooldown. Each enemy touched takes only 4 base damage once, but is knocked strongly away; damage orbs apply. All three weapons support E, and walls stop the dash and block the shove. The heading locks for the short dash. Pause, character switching and restart cancel the dash and its protection. Two new Sound Studio slots cover the dash and shove.

## Ronin cloak — v2.16

Press **4** to wear or remove Goemon’s weathered crimson ronin cloak. A thick neck wrap, layered shoulder mantle and ankle-length body wrap cover his torso and legs, with a narrow front opening and two long scarf tails. Torn holes, frayed hems, scorched edges and old repairs retain the battle-worn look. The lower panels open and stream opposite his actual movement direction, including strafes, while the shoulders remain covered. Cloth motion settles smoothly after stopping and through jumps. The editable Blender scene includes Goemon for fitting; his original character source is unchanged. Garment source: `assets/blender/costumes/goemon_ronin_scarf.blend`; game export: `assets/models/costumes/ronin_scarf.glb`; generator: `tools/build_ronin_scarf.py`.

While Goemon wears it, normal movement, sprinting and slow walking are **3× faster**, and **Space can be pressed four times** for a quad jump. The jump dots and control hints update with the outfit. Taking it off restores normal speed and double jump; toggling in midair does not refill spent jumps. The short E dash and attack timings keep their existing behavior. The scarf works with every weapon and Golden Surge. Its selection survives character switching and retries, but only Goemon gains its effects; Edo keeps his normal movement and double jump. Cloth motion freezes on pause. The cloak now uses normal visual running cadence at the 3× travel speed, with adjusted foot contacts. Jump 1 keeps the normal lift, jump 2 performs a rising 360° vertical spin in the opposite direction to jump 3, jump 3 keeps its rising 360° spin, and jump 4 performs a forward flip around the torso. Each turn completes in 0.42 seconds during ascent. The base outfit and Edo retain their existing double jump animations.

While wearing the cloak, every pipe combo hit, heavy strike, chain throw and chain fan also launches a forward gold coin. Coin-weapon attacks gain one additional coin with a slight spread. During R, each pipe spin releases **16 coins in a full 360° ring** at contact, alongside its existing wind and melee damage. These are regular damaging projectiles (20 base damage each), affected by damage, attack-speed and range orbs and Golden Surge's coin size/speed bonuses. Walls stop them. Each attack releases its bonus once, even when it hits multiple enemies; removing the robe before contact cancels the bonus. Edo, T and E retain their existing attacks.

## Controls

| Input | Action |
|---|---|
| W / S / A / D | Move relative to the camera and turn the whole body toward travel |
| Ctrl, held | Slow walk |
| Mouse | Orbit the camera |
| Mouse wheel | Zoom |
| Q | Toggle Goemon / Edo |
| 1 / 2 / 3 | Goemon: R-style wind spin / toggle automatic coins / long chain sweep |
| 4 | Goemon: toggle Ronin cloak, granting 3× movement and quad jump |
| Space, repeated | Double jump, or quad jump with Goemon’s scarf; press beside a wall in midair to hop off; WASD steers |
| Shift, held | Accelerate into a sprint |
| Left mouse | Goemon: three-hit combo, or R wind spin. Edo: triple fireball; hold to repeat, or hold for beam during R |
| Right mouse | Goemon: heavy pipe strike / five-coin fan. Edo: large explosive fireball |
| R | Goemon: 30-second Golden Surge moveset. Edo: 7-second Blue Surge moveset and shield |
| T | Goemon: Sky Strike leap / hit / return. Edo: Meteor Rain (tap; rapid taps queue casts) |
| F | Open earned island upgrade choices; combat pauses while choosing |
| F1 | Prototype Lab: pause and edit gameplay values / spawn enemies |
| C | Evade, with brief invulnerability |
| E | Goemon: short forward dash and shove. Edo: fire-and-smoke teleport |
| Tab | Toggle soft targeting assistance |
| Escape | Pause / resume |

An attack automatically equips a stowed pipe. Melee hits require range, facing, and an unobstructed line of sight. Coins are unlimited, cooldown-limited physical projectiles: quick throws deal 20 damage per coin and split throws launch five coins for 24 damage each. They fly toward the camera heading, with optional soft assistance for unobstructed enemies within a forward cone; terrain and walls stop them. Coins now use the supplied oval koban reference: a beveled gold body, raised rim, engraved bars and original seal marks. Selecting a different weapon cancels any pending attack. Enemy wind-up animations telegraph attacks; evade and punish the recovery. Defeating a ninja restores some vitality. Spirit sparks also heal you.

## Sky Strike smoke and tenfold maps

The leap still takes 0.24 seconds out and 0.19 seconds back, deals 160 base damage, and accepts rapid queued T presses without a cooldown. It now has a dedicated rising takeoff whoosh and a heavy stomp impact, using the existing volume/mixing system. Blender-authored smoke billows replace the two circular effects, expanding upward on takeoff and outward with dust at impact. Editable source: `assets/blender/vfx/Sky_Strike_Smoke.blend`; export generator: `tools/build_sky_smoke.py`.

T has no target-distance cap and searches all living enemies in the loaded area. Short leaps retain their original arcs; obstructed routes try higher arcs to clear terrain. Completely enclosed paths can still block the leap. Damage, return position, rapid input queue, pause, and character-switch cleanup are preserved.

Each map's playable area is exactly **10×** the previous release (linear dimensions multiplied by √10). Nine connected outposts add shrines, courts, paths and scenery. Survival waves replace the former preplaced encounter population. Distant actors keep pursuing beyond 100 m; their models are hidden until approach to reduce rendering cost, and they remain available to T targeting. The minimap fits the entire expanded area.

## Combat expansion

Settings includes Edo beam width / diameter (0.5–6 m) and length (5–65 m). Defaults are 2.8 m and 38 m. Settings save locally and apply to the next beam. Attack-speed stacks multiply this base length and update the active beam immediately. Activate R, then hold LMB to channel the beam; release LMB to stop.

Enemies include the original ninja plus fast wind scouts, durable iron brutes, and ranged ember casters. Defeated enemies drop one energy orb: **yellow** grants 1.5× damage, **blue** adds 50% attack speed, up to four stacks / 3×, and **red** grants 1.5× melee reach / projectile hit width. Each lasts 20 gameplay seconds; collecting the same type refreshes its timer and blue adds a stack. Different types can coexist. Drops expire after 25 seconds and clear on area travel; active buffs carry between areas and reset on restart / new game.

Edo now uses an anime refinement with expressive amber eyes, a confident smirk, a tall sculpted black crest and a face-framing fringe. His compact body and crimson/orange/charcoal costume palette remain, with clean flame motifs, lapel borders and ivory wrap details. His existing rig, animations and combat remain compatible; earlier Blender sources are preserved. See [editable source, comparison and validation](docs/edo-anime/README.md).

Sound Studio now has 20 additional recording slots for Goemon’s spin, giant toss and T, every Edo spell (including the sustained beam), and all five chain-pipe sounds. Use the search box to find an attack. Custom beam recordings loop while channeling. Each slot has record, preview, save, restore and volume controls. Sound Studio accepts only one active recording. Saving atomically replaces the selected slot’s prior WAV; no take history or layered takes are created. Renaming the game to Goemon preserves the existing settings and recordings in the legacy `Godot/app_userdata/Azure Ember` directory.

## Prototype Lab

**F1**, or **Pause → Prototype Lab**, opens the paused tuning interface. Tune health, outgoing damage, pipe reach, movement, coin damage/speed/count, powered spin / giant-coin damage, Golden Surge duration, and enemy health/damage. Spawn stationary dummies or practice enemies and test either R moveset. Obsolete Goemon charge-time controls are hidden.

Tuning saves locally. Invincibility, enemy-AI freeze and healing are available for experiments. Practice enemies disappear on restart. Pausing freezes survival, power-up and transformation timers.

## Explore Tidefall

The survival map retains its coast and beach, river and waterfall, cherry trees and palms, temple buildings with open interiors, walkable bridge, cave passage, western ruins, eastern Storm Court and outer training courts. Reaching Tidefall Temple restores vitality and establishes a recovery point. Spirit sparks remain collectible during the run.

Jade Grotto, Sakura Highlands and Sunforge Citadel are retained in the source but inaccessible during survival. There are no portal markers, travel controls or guardian objectives. Restart survival starts a fresh ten-minute run on Tidefall.

Both characters can **wall hop**: jump into a wall, then press **Space again** to kick upward and away. A short contact grace window and eased air steering make push-off forgiving, even while holding toward the wall. Each hop uses the landing sound (including your Sound Studio recording), preserves momentum along the wall, and works after air jumps are spent without refilling them. Holding Space does not repeat wall hops.

Both jumps recharge on landing. The second jump performs a forward somersault rather than a horizontal spin. The second jump refreshes upward velocity and can redirect horizontal momentum with WASD. Holding Space does not repeatedly jump. A third jump is not available. Ground waves test your actual height above terrain, so jumping is a functional counter.

## Presentation and systems

- Blender-authored, skinned chibi hero with reference-led blue/gold hair, facial features, layered clothing, a golden pipe, and simplified ninja/guardian variants.
- Procedural idle, jogging, sprinting, airborne, landing, evasion, and attack poses with continuous blending, squash, anticipation, and follow-through.
- Elevated perspective camera with mouse orbit, zoom, movement anticipation, FOV response, restrained banking, five obstacle probes, and foliage fading.
- Physical terrain, sloped stair approaches, bridge deck collisions, short step handling, buffered jumps, and fall recovery.
- Three light-combo stages, heavy knockback, short hit-stop, slash arcs, damage numbers, enemy telegraphs, and four distinct area guardians, including ranged volleys and jumpable ground waves.
- Main menu, pause menu, restart, defeat and victory states; saved volume, sensitivity, display mode, and graphics settings.
- Procedurally synthesized original music and action sounds; no downloaded assets or external dependencies.

This is a stylized procedural prototype, not a finished AAA production. Traversal is grounded running, sprinting, jumping, and evading; rail grinding, loop running, and wall running are not implemented. Live animation preserves code-driven combat timing through an imported seven-bone rig; Blender sources also include 13 editable/exported animation clips. The game has no persistent campaign save; settings persist locally.

## Blender asset pipeline

The v1.3 asset edition integrates 15 editable Blender sources and matching GLBs: Goemon (blue/gold hair), ninja, four guardians, pipe, oval koban, cherry/green trees, palm, moss rock, paper lantern, torii and modular temple roof. Working controllers, hitboxes, camera, bosses, Prototype Lab and area generation are retained.

See [the Blender workflow](docs/BLENDER_PIPELINE.md) for editing/exporting and [the audit](docs/ASSET_AUDIT.md) for migration decisions. Sources are under assets/blender; game exports are under assets/models. Preserve hand edits with tools/export_blender.py; the separate initial generator deliberately rebuilds models.

Terrain, water, grass, route assembly, bridge geometry and effects remain procedural. No online content was used. Blender sources and reference images are excluded from the standalone game.

## Project

Open `project.godot` in Godot 4.6.1 and press Run. The configured main scene is `scenes/main.tscn`.

The private development repository is [eric2532/Goemon](https://github.com/eric2532/Goemon). It includes gameplay source, runtime assets, editable Blender sources, tools and validation notes. Builds, Godot caches, local backups, Blender recovery files and generated test captures are excluded from Git. The archived Musashi visual-development ZIP also stays local.

For a fresh checkout, clone the repository with an authenticated GitHub account, then open `project.godot` in Godot and allow the assets to import. To create the macOS application described above, use the `macOS` export preset; create the local `build/Other Files/` directory first.

To upload future changes from this project folder:

```sh
git status
git add .
git commit -m "Describe the game update"
git push
```

Review `git status` before committing to confirm that only the intended files are included.

- `scripts/game.gd`: startup, menus, settings, audio, effects, game state, integration tests.
- `scripts/prototype_lab.gd`, `scripts/tuning.gd`: live gameplay tuning UI and persisted values.
- `scripts/surge_aura.gd`: original animated golden energy effect.
- `scripts/combat_tests.gd`: physical-input combat and tuning integration tests.
- `scripts/player.gd`: input, movement, attacks, health, traversal.
- `scripts/camera.gd`: responsive orbit, follow, zoom, collision.
- `scripts/hero_model.gd`: original model and procedural animation.
- `scripts/enemy.gd`: ninja and boss behavior.
- `scripts/world.gd`: terrain, architecture, vegetation, water, particles.
- `scripts/hud.gd`: HUD, objective, minimap, combat feedback.
- `scripts/gold_coin.gd`: original cash-coin mesh and swept projectile collision.
- `scripts/expedition_area.gd`: seeded connected maps and confined boundaries.
- `scripts/area_gate.gd`: large, always-open portals and return doors.
- `scripts/swarm_survival.gd`: countdown, growing waves, safe spawn placement and victory.
- `scripts/survival_tests.gd`: survival rules, pursuit, pause/retry, win/loss and crowd-load checks.
- `scripts/endless_encounters.gd`: retained legacy encounter support.
- `assets/vfx/fire_beam/fire_beam.gd`: Edo’s piercing fire ray, stack-based length and timed damage.
- `scripts/boss_wave.gd`: expanding jumpable boss attacks.
- `scripts/expansion_tests.gd`: gameplay and multi-area regression tests.
- `export_presets.cfg`: universal macOS release preset.

## Verification

Current chain weapon, recording, meteor and combat checks:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --chain-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --chain-visual
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --meteor-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --meteor-visual
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --firecaster-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --firecaster-visual
```

`tests/chain-pipe/` contains weapon/recording checks, in-game captures and the Blender asset review. `tests/meteor.log` checks the pose, targeting, damage, orb scaling, queued taps, pause and cancellation. `tests/edo-meteor/*.png` shows the casting pose, falling fireballs and explosions. `tests/firecaster.log` verifies startup music, volley repetition, large-fireball splash, stacked floor orbs, beam penetration/steering, dodge damage and effects, cleanup and Goemon regressions. `tests/edo-firecaster/*.png` shows the in-game effects and Blender preview. Earlier combat tests describe retired Edo controls.

Current survival checks:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --survival-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --survival-test --survival-load
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --survival-visual
```

`tests/survival.log` records the current survival integration results. `tests/survival-*.png` contains visual captures. Older expedition tests and release notes below describe previous modes; door, guardian and fixed-population assertions no longer apply to the active survival mode.


`tests/expansion.log` records weapon selection, double jumping, projectile hits and wall blocking, real door interactions, backtracking state, all guardians, generated route floors, actual traversal, map boundaries, deterministic seeds, new-seed variation, and area retries. `tests/area-visual.log` records rendered spot checks of the new maps.

`tests/expansion-regression.log` records the automated integration checks: physical movement, jump input, light/heavy attack input, pause/resume input, cave-camera obstruction, full bridge crossing, temple stair entry, equipment toggle, boss victory, and return to menu. `tests/export.log` records the release export. PNGs in `tests/` document visual inspection.

Combat update checks are recorded in `tests/combat.log`, `tests/combat-smoke.log`, and `tests/combat-expansion-regression.log`.

Developer-only test commands:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --combat-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --expansion-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --smoke-test
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --visual-test --capture-only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release macOS 'build/Other Files/Goemon.zip'
```

### Reference-accurate hero update (1.4)
The active hero now uses the user-supplied original Goemon mesh and atlas, preserving its 460 triangles and UVs. Editable source: `assets/blender/characters/kai.blend`; embedded-texture game export: `assets/models/characters/kai.glb`. Comparison: `tests/reference-comparison.png`. The original reference and attribution are retained under `assets/references/goemon_original`. See `docs/BLENDER_PIPELINE.md` for rig mapping, update/export workflow and the blue-only source limitation of the gold transformation.

### Locomotion update (1.5)
The original character mesh and texture are unchanged. The hero now uses an articulated 17-bone rig, 24 editable animations, speed/direction blending, planted-foot terrain correction and hand-bone weapon attachments. Ctrl walks; S backpedals; A/D strafe. See `docs/LOCOMOTION.md` for the audit, animation pipeline and validation. Motion review: `tests/locomotion-review.mp4`.

## Anime locomotion update — v1.6

The existing character now runs with pelvis-led twist, a counter-rotating chest, dynamic clavicles, larger arm arcs, delayed hands and stronger leg drive. The neck and head lean forward into running and sprinting while keeping the face controlled. The model and textures are unchanged. Editable source and export instructions are in `docs/LOCOMOTION.md`.

## Supplied gold hair — v1.6.1

R now swaps to the actual taller Sudden Impact hairstyle from the supplied model, with its original texture. The normal character, face, locomotion and transformation mechanics are preserved. Both editable hair variants live in `assets/blender/characters/kai.blend`.

## Supplied pipe — v1.6.2

The equipped pipe now uses the actual weapon from the supplied Goemon Outfit archive, with its original gold/silver textures. The outfit was excluded. Editable weapon source: `assets/blender/weapons/golden_pipe.blend`.

## Sound Studio — v1.7.0

Open **Settings → Sound Studio · Record sounds**. Choose your microphone and a sound slot, press **Record**, then **Stop → Listen to take → Save take**. Record up to eight seconds for swings, impacts, coin throws, jumps and other effects. Each slot has volume and Restore default controls. The first recording may ask for macOS microphone permission. Your recordings stay on this computer and persist between game sessions. See `docs/SOUND_STUDIO.md`.

## Directional body motion — v1.7.1

Sideways movement now carries a subtle directional turn and lean through the hips, shoulders and head, including smooth reversals. The shoulder stance is slightly more open through the rig. Character meshes, textures, R hair, supplied weapon and Sound Studio remain intact.

## Ready idle — v1.7.2

The idle stance now has gently bent elbows, arms held slightly away from the body, and a slow breathing cycle through the chest, head, hips and knees with planted feet.

## Compact idle arms — v1.7.3

Idle arms are about 10% shorter, with shoulders connected and full-size hands. Movement and attacks blend back to normal reach; the ready stance and breathing remain.

### v1.7.4 — relaxed compact idle
Idle arms are another 10% shorter, with a little more elbow bend, wider shoulder stance and outward clearance. Breathing and full attack reach are preserved.

### v1.8.0 — game feel
Added transient acceleration/braking/pivot and jump/landing reactions over approved locomotion, faster attack contact, local hit-stop, directional enemy recoil and camera impulses, contact sparks, and separate reaction/environment audio. Evade cancels attacks; late heavy input buffers. See `docs/GAME_FEEL.md`.

### v1.9.0 — choreographed pipe combo
One click now flows through a fast diagonal opener, wide left sweep, and loaded right power finisher. Full-body pose layers, continuous hand paths, planted feet and stronger finishing knockback/feedback preserve the approved character and pipe assets. See `docs/PIPE_COMBO.md`.

### v1.9.1 — right-side charge stance
Pipe and coin charges use a coiled stance with a bent elbow, raised free-hand guard and weapon aimed right. Bounded arm IK replaces the legacy charge rotation; hold/release/cancel blend back into existing movement.

### v1.9.2 — reference-style koban
The thrown/held coin now uses a thin, long rounded gold koban with modeled rim, engraved-looking bands and dark stamps on both sides. Editable Blender source and exported GLB are included.

## v2.1 · Controls, encounters and jumps

Q toggles characters; 1/2 select weapons for the active character. Evade is C. Regular encounters originally contained three times as many enemies (54 in Tidefall and 36 in each generated area); the tenfold-map release increases these totals to 540 and 360, with one guardian per area. Both characters jump roughly 50% higher; first and second jump launch speeds are adjustable in Prototype Lab.

## v2.2 · Edo fire beam and free exploration

Character names are Goemon and Edo. Edo’s fully charged ranged attack channels a 2.8-metre-wide fire ray for three seconds, reaching up to 38 metres in clear space. It follows his position and camera aim, stops at solid cover and deals 18 base damage every 0.2 seconds. Tap LMB still throws a normal fireball. Mouse turning steers the beam continuously. Its fire shield automatically protects Edo and burns nearby enemies throughout the channel, including while R is on cooldown. The automatic shield ends with the beam; an independently active R shield keeps its remaining duration. Switching character or weapon, evading or travelling cancels the beam.

Portals now have tall stone frames, a luminous animated interior, an overhead beacon, clear destination labels and a six-metre interaction radius. All doors remain open while regular enemies respawn indefinitely. Q switches Goemon/Edo; 1/2 remain weapon selectors; C remains evade. Character geometry is unchanged.

`tests/edo-beam/` contains new gameplay checks, rendered beam/portal captures and release validation. Run `--edo-test` for the automated feature suite or `--edo-visual` for rendered captures.

## v2.5 · Area stomp, pursuit, and smoke teleport

Goemon’s T landing hits every enemy within five metres (160 base damage each, solid cover blocks damage). The leap timing, unlimited target range, return, sounds and queued presses stay the same. Range pickups also expand the landing radius.

Enemies now pursue across the full map using a shared terrain-aware route field, including distant enemies with hidden models. Portals have a bright swirling energy surface, orbiting rim, particles and a tall cyan beacon. Press F within six metres to travel.

Edo’s LMB fireball fires without charging. Hold T in either weapon mode for an immediate beam; release T to stop. E teleports to random clear ground within 75 metres (about 100 footsteps): departure and arrival smoke deal 12 base damage within four metres, once per enemy, and Edo hops before vanishing and after reappearing. The dodge cooldown is 0.75 seconds. C remains the directional evade. Pause, character switching and map travel safely cancel abilities.

Validation: `--aoe-edo-test` runs the updated combat, teleport and cross-map pursuit checks; `--aoe-edo-visual` also captures effects and portals in `tests/aoe-pursuit-edo/`.

## v2.6 · Crowd performance and Goemon stride

The full map and enemy population are retained. Ordinary enemies use a 2,694-triangle close model; beyond the nearest 32 detailed combatants, a shared 777-triangle mesh animates on the GPU in one crowd batch. Guardians retain their original models. Enemy names appear only at close range, and distant enemies keep pursuing while their rendering is culled. Physics bodies, health, damage, drops and unlimited T targeting remain active for every enemy.

Enemy routes are cached briefly, navigation-field rebuilding is spread across frames, and grounded movement interpolates collision-checked short segments. Full collision physics still handles guardians, hit reactions and airborne enemies. This avoids hundreds of redundant ground-contact solves every frame.

Goemon's running and sprinting use shorter foot travel, lower swing clearance, an earlier heel lift and more hip clearance. Terrain foot planting, original limb lengths, player speed, combat timings and jumps are preserved.

`--performance-audit` records frame timings for the full map and a 541-enemy crowd and captures running poses. Results, Blender mesh generation logs and regression checks are in `tests/performance-legs/`.

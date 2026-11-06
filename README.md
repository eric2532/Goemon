# Goemon

Goemon is a Godot action and defense game. Forest Shrine is the current player experience: prepare the fort, build defenses, and destroy the four enemy Skullpion statues in Wind Meadow Valley. Workers staff buildings automatically. The central castle has a raised square courtyard with four side stairs and two defending towers on each side. Four roads connect it to the valley routes and enemy forts. Wind Meadow Valley is the only bundled playable map, in standard and large sizes. User-saved maps remain available in the map editor; retired layouts are excluded regression fixtures.

## Play and edit

Open `/Users/eric/Desktop/Play Goemon.command` to run the latest complete source with painterly scenery. Open `/Users/eric/Desktop/Edit Goemon.command` for the same project in Godot.

The launchers target the complete source on `main` at `/Users/eric/Desktop/Projects_Codex/Sonic`. Keep both launchers pointed at that source if it moves.

Godot 4.6 is used by the project. Runtime GLBs and animation data are supplied; Blender is needed for art editing, not ordinary play.

During preparation, open **Mercenaries** with **M**, then click a card or press
**1 Ninja, 2 Dragoon, 3 Ranger, 4 Explorer, 5 Knight**. Each press hires one ally
at clear ground near your castle for the displayed ryo price and two food.
They seek enemies across the valley and return home when the area is clear.

**Smaller ÷1.5** and **Bigger ×1.5** are directly on the preparation map beside
Build and Tools. Each click divides or multiplies the map's width and length;
the label shows 1×, 1.5× or 2.25× (up to 5.06× the original area). Resizing keeps
the current run and placements, and refuses a change that would crop objects or
move the cliff under a structure or character. The first resize prepares terrain
and can pause for several seconds. Use **Tools → Map Editor → Save** to keep a resized custom
layout across restarts. The editor's **New preset…** menu loads a fresh standard
or large valley.

In **Tools → Map Editor**, the 3×3 build grid uses **1–9** (including the keypad).
The first page is **1 Guard Tower, 2 Cannon Tower, 3 Farm, 4 Wall, 5 Gate,
6 Tree, 7 Mossy Rock, 8 Spawn Portal, 9 Road**. **[ / ]** or **Page Up / Page Down**
switch between the three asset pages; numbering restarts at 1
on each page. These hotkeys stay inactive while typing map names or numeric values.

Page two adds **Bush, Cedar, Pine, Sakura, Bamboo, River Rock, Moss Boulder,
Stone Block and Wall Cap**. Page three adds **Wall Corner, Wall Piece, Wall Ruins
and Fence**. The new tree appearances reuse the meadow's organic foliage with a
Breath of the Wild inspired natural palette and soft shading. Modular pieces
provide ground-level static scenery/cover; functional structures use page one.

Choose a scenery piece, set **Scenery size**
(0.5×–2×) and **Rotation**, then click the ground to place it. Use **Select** and
click a placed tree or rock to change those values; **R** turns scenery by 15°.
**Undo / Redo**, **Save / Load**, and **Play map** retain these transformations.
Rocks and trunks block movement at their fitted size. Keep scenery clear of
roads, structures and portal exits. Ordinary tree/rock edits update only the
affected scenery chunks; loading a layout or starting Play map still prepares
the complete map and can pause briefly.

## Team leveling

Every enemy defeated by you, allies, or towers contributes to one team level.
The first level needs 20 kills. Each level pauses play for three maroon/silver
cards: **Tower**, **Worker**, and **Character**. Click one or press **1 / 2 / 3**
to upgrade every matching friendly unit, including future recruits and towers.
Team level and XP appear beside castle health. Restarting clears all run bonuses.
See the [team leveling spec](docs/team-leveling-spec.md) for cards, numbers, and reset rules.

## Development

- `scripts/`, `scenes/`: game logic and scenes.
- `assets/models/`, `assets/animations/`: exported runtime art and motion data.
- `assets/blender/`, `assets/textures/`, `assets/references/`: editable masters and references.
- `assets/maps/`: bundled map presets. Preserve user maps, preferences, and recordings outside the app bundle.
- `tools/`: asset authoring, export, and verification tools.
- `tests/`: executable regressions and focused usage notes. Start with [Forest Shrine tests](tests/forest-shrine/README.md).

Run checks from the source checkout being changed. For example:

```sh
godot --headless --path . --script tests/forest-shrine/model_test.gd
godot --headless --path . --script tests/forest-shrine/map_document_test.gd -- --test
```

Use the installed Godot executable if `godot` is not on PATH. Native render and input checks need a real window; inspect their script arguments before running them.

## Enemy waves

Open **Tools → Core Game Balance** on the building map. Each wave has separate
counts for Sword, Gun, Spear, Vambee, Haya Wolf, Vambee Torso, Slow Guy and
Skullpion. Zero excludes a type. START releases the first wave; later waves
arrive every 60 seconds and retain any blocked arrivals from earlier waves.
Up to three ordinary enemies also arrive each second at reachable clear ground,
sharing the same wave totals and active cap. Old combined settings
migrate once, preserving effective enemy totals and the saved boss toggle.

Starting group size (10) and Growth per group (+1) control arrivals independently
at each spawn spot: 10, 11, 12, and so on after a member starts attacking.
Growth 0 keeps groups fixed. These settings apply next run; each numbered wave
resets growth. Wave composition still sets exact totals, so the final group can
be smaller. Barracks keep growing groups while repeating their selected mix.

Retired forest enemy GLBs/textures and Daruma's optimized copy have been removed
from runtime assets. Editable Blender masters remain under `assets/blender/`;
assets referenced by other game modes remain available.

## Spell equipment

Open the fighter gallery with Q, then **Skills & Jump**. Any fighter can assign a
special ability to each of **1, 2, 3, 4 and 5**. The HUD names the five slots.
Assignments are saved separately for each fighter; existing E/R/T assignments
remain saved and also appear on 1/2/3.
**Restore original skills & jump** restores the default bar. Tap/hold and
release behavior follows the equipped ability. Normal weapon controls stay with
the character.

Ranger's **3 · Rapid Shot** fires ten arrows together in a broad fan. Tap or hold
to repeat every 0.25 seconds; Rain powers the arrows. It is also available to
every fighter through **Q → Skills & Jump → Ranger · Rapid Shot** on any of 1–5.
His original five-arrow Fan Shot and primary combo remain separate.

Goemon uses **1 Dash, 2 Surge, 3 Sky Strike, 4 Coins, 5 Chain Pipe**.
Musashi uses **1 X Slash, 2 Tenderize, 3 Desperado, 4 Rotation, 5 Mighty Strike**;
equip Grenade, 3-Way, D-Kick, Fence, Homing, Guard, Charged Rotation or
Leaping Strike in any slot when preferred. His
existing E charge and R guard remain available. Chief keeps his five weapons
unless a slot is explicitly equipped with a skill. Mouse attacks, movement,
Space, C, Z/X capes and preparation menu shortcuts retain their roles.

`scripts/spells/spell_catalog.gd` defines stable spell IDs. `spell_loadout.gd` owns
assignments and input; each `spell_instance.gd` owns its own casting state and
cooldowns. Existing combat controllers provide the original effect and collision
rules, using a private source rig where authored sockets or collision curves are
needed. Transferred moves retain the wearer's locomotion pose; their spell effects
and special equipment follow the original ability.

Run `tests/forest-shrine/modular_spells_test.gd` for cross-character casting,
charge/release, buffs, cooldown preservation and equipment UI checks. Add
`-- --visual` for a rendered capture under `build/Other Files/Spell Modularity/`.

## Art and audio

Read [the Blender workflow](docs/BLENDER_PIPELINE.md) and the [character art standard](docs/art-direction/goemon-character-standard.txt) before editing masters. Animation and weapon workbenches under `docs/` keep their own `START_HERE.txt` instructions beside the editable files. Follow the relevant asset's README and provenance rather than an old milestone report.

[Sound Studio](docs/SOUND_STUDIO.md) documents recording and replacing attack sounds. The selected visual inspiration reference is [Game Art Style](https://gameartstyle.loopyhop.com/).

The game icon renders the existing playable Goemon head into `icon.png` and
`icon.icns`. To regenerate both on macOS, close the game and run
`"/Users/eric/Desktop/Play Goemon.command" --script res://tools/render_game_icon.gd`.
This changes no model or animation and stages icon sizes under `build/Other Files/Game Icon/`.
Add `-- --launcher` to render the Play command's three-quarter face icon in that
staging folder without replacing the game's front-facing icon.

## App delivery

Export only when an app build or distribution is requested. Follow [AGENTS.md](AGENTS.md): stage and verify outside `build/`, then atomically replace the single `build/Goemon.app`. The complete painterly source currently uses the **Painterly Preview macOS** preset. Keep development artifacts in `build/Other Files/`; move superseded apps and app-only ZIPs to Trash.

Keep this README focused on current entry points. Git contains the release history, completed implementation plans, and retired reports.

# Cross Gate

Cross Gate is a Godot action game. The current desktop Play opens Falan Arena: the recovered Cross Gate city arena, with its five colored stone platforms and red carpets, adapted for pure survival against slimes entering from four sides. There are no castle objectives. Standard and Large sizes are available in Map Editor. Saved maps remain available; previous valley layouts are excluded regression fixtures. See `docs/wind-meadow/falan-arena.md` for the reusable artwork and terrain contracts.

## Play and edit

Open `/Users/eric/Desktop/Play Goemon.command` to run the latest complete source with painterly scenery. Open `/Users/eric/Desktop/Edit Goemon.command` for the same project in Godot.

The launchers target the complete source on `main` at `/Users/eric/Desktop/Projects_Codex/Sonic`. Keep both launchers pointed at that source if it moves.

Godot 4.6 is used by the project. Runtime GLBs and animation data are supplied; Blender is needed for art editing, not ordinary play.

Choose your fighter, then use **Equipment** before entering the map. During play,
press **Q** to open the same combined window. Gear stays on the left, the item or
pet collection is in the middle, and character stats are always visible on the
right. There are no separate **I** or **Shift+P** windows. **Q / Esc** returns to
the previous game or preparation state; plain **P** still summons/recalls pets.

Click **Main Character** to return to character selection; picking a fighter
or backing out returns to Equipment. The large model preview still opens the
skin picker. Select a pet slot to edit its gear and skills. The collection tabs show matching
items and skills. Use the **+** beneath an equipped skill to buy its next level;
character stats, character skills and pet skills spend the same run-only points.
Pet skill levels belong to the selected pet. Hover upgrade buttons for the
current and next effects. Gear, cosmetic, skin and skill choices save immediately;
**Back** keeps them. **Enter Map** starts play with the current selection.

Select a top-row pet to inspect its gear and skills; a gold outline marks the
selected slot. **Change pet** opens the inline collection for that slot, and
choosing a replacement changes only that slot. Equipped pets show a checkmark
and slot number, with full details on hover; their catalog cards cannot remove
or duplicate them. Use **× Remove** explicitly to remove the selected pet.
**Add pet** appears at the next free slot. Existing saved pack order stays
compact, and removed pets retain their keyed gear, skills and learned levels.
Changes save immediately, with rollback on save failure.

The right panel follows the selected pet: live current/maximum health when
summoned, maximum health before summoning, normal damage per contact, recovered
attack contacts/duration, base movement speed and its three equipped skill
levels. Facing can vary the recovered sequence, and escort/catch-up movement
can exceed base speed. These are read-only pet stats; the existing skill plus
buttons still spend shared points. Selecting a character restores its stat
allocation controls. Original portraits, cosmetics and native pet combat keep
their existing owners. Equipment retains its item double-click/Enter controls;
Build and Mercenaries stay absent from the map HUD, and **M** retains its combat
minimap function.

In editor/preparation sessions on saved valley maps, **Smaller ÷1.5** and **Bigger ×1.5** sit beside
Tools. Each click divides or multiplies the map's width and length;
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
The first level needs 20 kills. Each level pauses play for three Cross Gate ivory/slate
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

## Level-up stats

Press **Q** for Equipment. Each level gives +20 maximum HP, +3% baseline
physical/magic damage, +2 defense and one shared upgrade point. The icon cards
show current values and spent stat ranks. Point effects remain Vitality
(+100 HP and +1 HP/sec), Attack (+15% physical damage), Magic power (+15% magic
damage), Attack Speed (+10%), Defense (+10), and Critical/Dodge/Counter chance
(+1 percentage point each, capped at 100%). Hover a symbol or plus button for
its name and effect. Upgrades follow the controlled fighter for this run and
reset on a new run; saved character/skill baselines stay intact. Cards remain
off by default. The blue mana meter stays below health; skills do not consume
mana in this presentation pass.

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
Shift + Space jumps (press again in the air for the existing second jump).
Plain Space dodges when ! appears. C and preparation menu shortcuts retain their roles.
Press **Q** to open Equipment, then choose your weapon under **Weapons**.

In Cross Gate combat, **left-click** attacks. **Right-click** sends summoned
pets to the enemy under your aim or locked with **Tab**. With neither target,
right-click clears the mark and sends pets hunting for separate enemies.
**F** holds them in place, and **Z** calls them back.

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

The game icon reuses the preserved painted Shin portrait in `assets/ui/portraits/crossgate/shin.png` to prepare `icon.png` and
`icon.icns`. To regenerate both on macOS, close the game and run
`"/Users/eric/Desktop/Play Goemon.command" --script res://tools/render_game_icon.gd`.
This changes no model or animation and stages icon sizes under `build/Other Files/Game Icon/`.
Add `-- --launcher` to prepare the same Shin icon for the existing Play command in that
staging folder without replacing the game icon.

## App delivery

Export only when an app build or distribution is requested. Follow [AGENTS.md](AGENTS.md): stage and verify outside `build/`, then publish the single `build/Cross Gate.app` and move the superseded `Goemon.app` to Trash. The complete painterly source currently uses the **Painterly Preview macOS** preset. Keep development artifacts in `build/Other Files/`; move superseded apps and app-only ZIPs to Trash.

Keep this README focused on current entry points. Git contains the release history, completed implementation plans, and retired reports.

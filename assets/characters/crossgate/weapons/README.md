# Native Cross Gate weapon choices

## Original boomerang — 2026-11-25

The default `weapon:boomerang` uses the original eight flight graphics
22082–22089 and the Lv1A 木製大型回力鏢 icon (original row 13973 / serial
21201). Complete source flight images remain under `boomerang/source-*.png`;
the airborne atlas keeps their blade pixels and omits their baked ground shadows.
The shared projectile retains its curve, moving return, broad swept contacts,
once-per-enemy hit tracking and pooled lifecycle.

All 237 compatible appearances have a complete matching native unarmed throw
set. Prepared movement atlases are referenced directly; missing throw/guard
frames are recovered offline. Original action 7 supplies equipped action 5,
with its exact release marker, duration, body pixels and origins. The 37 other
appearances keep their existing restrictions because a matching complete native
set was not verified. `boomerang/provenance.json` lists every inclusion/exclusion.
水龍shin's ordinary boomerang preserves its purple hair on the native bare body.
Its separate **水龍 Boomerang** item (`weapon:water-dragon-boomerang`) retains
the approved custom body, sixteen-frame projectile, icon, blue wave and ice
audio. Its blue wave now plays at confirmed enemy contact through a separate
pooled effect; the body and weapon pixels are preserved. Saved `weapon:boomerang` selects
the original, and the custom item is selectable on 水龍shin.

Regenerate with `python3 tools/prepare_crossgate_boomerangs.py '../Magic Power'`,
then prepare player audio and cosmetics using their existing tools. Add `--check`
to verify the source frames and referenced movement. The general weapon
preparer also keeps these routes. Run `original_boomerang_test.gd` and
`water_dragon_weapons_test.gd` through Play Goemon, followed by the Cross Gate
Mirror Image movement regression for copied loadouts. Evidence belongs under
`build/Other Files/Asset Toolkit/Original Boomerang/Implementation/`.

## Native weapon catalog

`catalog.json` maps the current Cross Gate appearances to verified weapon
choices. `native` selects an existing
prepared stance; `root` selects a recovered full-body animation set in this
directory. Water Dragon Sword Shin (900050) uses the separately documented offline stitch
in `../shin/README.md`; its route retains the original sword combat contract.

Rebuild from the preserved sibling source with:

```
python3 tools/prepare_crossgate_weapons.py '../Magic Power'
python3 tools/prepare_crossgate_weapons.py '../Magic Power' --check
```

The checker compares every exported frame's RGBA bytes and origin with the
original decoder, plus source frame tables, clip durations, catalog and sound
hashes. Native frame flags determine contacts and bow release; low flags retain
swing/draw cues. The 2026-11-14 recovery passes 139,464 frame/origin comparisons.
Preserve original binaries, prepared character defaults, custom attacks,
source frame tables and audio. Atlas imports disable alpha-border rewriting.
Game runtime never reads the sibling project or original archives.

Regular six-weapon families reuse reviewed archive labels and native art/cues.
Nonconsecutive Shin teal and Saizo pink records were reviewed independently.
Special Shin's classic plain sword/spear looks have six source choices. Its
white/red look has five: axe `ch1:658`, bow `659`, sword `660`, staff `661`,
spear `662`. The former prepared white/red "polearm" is actually staff art;
its old Z index remains readable, while explicit new Staff/Spear routes use
their proper native records. Glowing/fixed looks, including the golden spear,
retain their prepared weapons rather than borrowing a plain outfit. Ten Kaz
outfits use their matching native axe, bow, fist, staff and spear alongside the
prepared sword. Original Kaz, both Blond / Rose looks, Yellow / Red Sparks
and Classic Red / Silver have no verified alternate weapon set. Maze keeps its
existing weapons and saved identity. Pass `--kaz-only` to prepare or check only
Kaz's routes, then refresh `tools/prepare_crossgate_player_audio.py` and the
offline cosmetic anchors with `tools/prepare_crossgate_cosmetics.py`.

Selection loads the chosen atlases, motion data and cue audio on the existing
character model. Combat uses existing local melee queries, timed contacts,
pooled arrows/kunai, native army targets and skill controllers. Alternate staff
attacks use their actual contact counts; they do not inherit Uru's five-hit
assumption. Native default attacks remain on their existing paths. Staff uses
the existing staff base damage; other weapons use the existing physical base.
Borrowed bows get normal arrows; only the archer identity owns archer skills.
Weapon-dependent shortcuts refresh when equipment changes.

Run `weapon_equipment_test.gd` through Play Goemon for saves, restrictions,
all appearance/weapon routes, eight-direction atlas selection, actual native
army damage, bow release, Kunai counts, weapon cycling, incompatible-outfit fallback
and repeated resource reuse. Desktop captures and source-review sheets belong
under `build/Other Files/Asset Toolkit/Cross Gate Weapon Inventory/`.

## Beast Master on every appearance

`weapon:beast-master` uses the appearance's existing dagger or boomerang
motion when available. The 40 supplemental profiles under `beast_master/`
reuse each appearance's prepared cast and movement. For 29 appearances the
dagger pose uses the outfit's original throw and release cue. The other 11
use timed release gestures built from matching source poses, with the frame
order and release timing recorded in `tools/crossgate_beast_master_fallbacks.json`.

Run `python3 tools/prepare_crossgate_beast_master.py '../Magic Power'` to
prepare the supplemental profiles and refresh the cosmetic anchors with
`tools/prepare_crossgate_cosmetics.py`. Add `--check` to the Beast Master
command to verify the source pixels, origins, clocks and reused motion
references. Source review is under `build/Other Files/Asset Toolkit/Beast Master Skins/`.


## Ordinary attack wind — 2026-11-17

`wind-motion-cues.json` is the reviewed source-key → per-contact motion table.
It covers all 923 non-fist melee source keys in the current 271 appearances
(937 non-fist setups, plus 228 fist setups). The review groups only exact
matching eight-direction alpha silhouettes and original frame anchors, ignoring
consecutive held-frame repeats: 403 distinct sequences. Source frame boards,
manual family cues, original inventory and rendered contact evidence are in
`build/Other Files/Asset Toolkit/Cross Gate Melee Wind/Alternate Skins/`.
Inspect the real grip, weapon direction, contact sequence and motion before
adding a new key; never infer the cue from the weapon label. Unknown future
sources retain a neutral fallback until reviewed. Clip annotations and the table
load once through the existing model cache.

The approved sword crescents follow rising/falling or side swings. Axe crescents
have a thicker shell and a 0.28-second fade. Actual thrusts use the original
textured piercing stroke without a drawn arrowhead. Staff thrusts use the first
approved rounded pounce; staff chops use the approved blunt Uru gust directed
up/down. Bog's mixed staff contacts select a chop and then a pounce. Some Emilia
and Moe polearms chop rather than thrust; Lancelot's axe thrusts. Special Bei's
sword spins. Fixed Moe 106708 uses original bow-release art despite its existing
catalog label; its wind follows the forward release. Fixed Ami 115258 uses a palm
gesture and receives the rounded forward gust. These exceptions preserve their
original sprites and existing gameplay contracts.

All effects retain the pale blue/white source texture, tint and subtle opacity.
No range ground circle is emitted. Original skin artwork, including native auras
and embedded weapon effects, is preserved. Each effect reaches the real strike
endpoint plus contact padding; body-sized caps no longer hide range bonuses.
The crescent's forward edge and the rounded gust's leading front are fitted in
world space, including camera depth. Staff chops also travel up/down with the
source gesture. These are short wind shapes indicating reach, not persistent
hitbox outlines. Contact clocks, damage, cooldowns and exact local queries remain
under the original combat owner; the fading wind cannot deal a later hit.

Unarmed attacks keep the rounded Uru gust approved for punches, slightly larger
and oriented forward. The exact approved fragment shape, original source atlas,
tint and fade remain intact. `crossgate_skin_wind_test.gd -- --fists-only`
is the isolated fist matrix; omit the flag for all current appearances and
weapons. `crossgate_melee_wind_test.gd` is the smaller shared default-weapon
regression. Both use the existing bounded shared mesh/material/native batch,
without per-swing resource loading, material creation or a new simulation owner.

### Gentler range-related breadth — 2026-11-17

The strike now supplies its range-bonus scale to the shared wind presentation.
Normal silhouettes are preserved; the range-dependent breadth uses square-root
growth instead of linear growth. Forward reach stays at the real hit boundary.
This affects wind art only: damage/query width, item effects, source motions and
color are unchanged. Separate Width accessories remain a proposed gameplay change.
Evidence and normal/×3 comparisons are under the wind toolkit's `Narrower Width/`.

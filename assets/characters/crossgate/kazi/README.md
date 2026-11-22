# Kaz / Blue Cross Gate #102488

The live character uses these original recovered Blue CG sprites and animations.
The user reverted the illustrated upgrade on 2026-11-06. The original six atlases,
frame order, offsets, durations and side portrait are preserved. `../kazi_hd/` is
archived and excluded from imports/exports. The gallery and HUD use
`portrait-front.png`, frame 0 of recovered standing clip 76. This is the
original 45° front diagonal, the closest authored direction to 30°.

The user subsequently requested a less blocky display without changing the art.
The existing Sprite3D now uses linear texture sampling. All source images,
animation frames, origins, proportions and durations remain unchanged; this is
display smoothing, with no generated artwork or additional texture pages.

The user identified this character as Kazi on 2026-11-06 and confirmed the
original sprite preview before implementation. Stable playable fighter ID: 34.
Source record: `ex:1727`, Dragon expansion. No 3D model or rig is present.

`motions.json` preserves seven original actions in all eight directions: stand,
walk, run, attack, cast, hurt and fall (56 clips, 872 frame references). The six
PNG atlases contain 824 unique cropped frames. Visible RGBA pixels, original
frame origins, source records and durations are retained; transparent margins
are removed only during offline packing. Original archive SHA-256 fingerprints
and every original frame record are in the manifest.

The supplied archives and decoder remain read-only in the adjacent Magic Power
project. Reproduce the exports from the Goemon source root:

```sh
python3 tools/recover_crossgate_kazi.py '/Users/eric/Desktop/Projects_Codex/Magic Power'
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
```

The extractor checks every unique frame against its packed pixels. Do not paint
or rescale generated atlases. Future art edits should have a separate editable
source and exporter; these recovered pixels are the immutable reference.

`scripts/crossgate_model.gd` uses one camera-facing Sprite3D. Its 83-pixel
standing body (clip 95, hood top -76 through shoe edge 7, excluding blade/sparks)
matches `character_proportions.gd`'s Goemon height, 3.2206185 m. The seven-pixel
foot offset grounds that reference. Existing per-character size settings still
multiply the prepared visual. Facing chooses the original camera-relative direction.
This sprite orders directions NW, N, NE, E, SE, S, SW, W: add one to the normal
N-first index. The initial import missed that offset and displayed diagonal art
for straight travel; explicit front/back/left/right regressions now cover it.
Prepared textures are shared across the player and native pooled hero bodies.
Only changed frames update the existing region/offset. Six lossless atlases use
85.5 MiB of RGBA texels without mipmaps; PNG disk sizes are not GPU memory.
There is no runtime extraction, retargeter or per-attack loading/material creation. Grounded body sprites use
`assets/materials/crossgate_body.gdshader`: original pixels below the feet
write depth at the ground intersection of the same camera ray, preserving
the complete effect while retaining wall occlusion. Airborne sprites keep
normal depth. Current atlas materials are prepared on appearance/weapon
selection and released when that appearance changes; never cache all visited
skins or create materials during attacks.

`scripts/crossgate_combat.gd` specializes the existing recovered-enemy player
adapter. Shared exact segment contact, bounded native candidate query, cover
checks, hit history, damage attribution and cancellation remain authoritative.
LMB and RMB perform the same .6-second sword action. Original Kaz's cuts
land at 5/11 and 6/11 of the gesture. Both sample the same forward 90°
sweep with .42 m contact padding and reach 5.6 m straight ahead at default
size, matching the ground outline. Each cut deals 250 base damage once per
target, for 500 base damage when both connect. They share one attack ticket
and use regular sword contact feedback.
Jump/dodge, selection, progression, shared spells and
health use Hero. This adds no ordinary enemy wave type or automatic wave count.
The native mirror validation accepts kind 134 for Kazi, through the same owner.

Original swing sound 103 (`cgply01a.wav`) plays at source attack frames 3/7;
direction 0 contains only frame 3. The cue list is captured at attack start,
so orbiting the camera cannot duplicate cues. Confirmed sword hits use
recovered Cross Gate cue 133 (`cgply11a.wav`). The archived heavy cue 134
(`cgply11b.wav`) remains available in Sound Studio.
Shared physical impact 255 (`cgefc04.wav`) remains available to other cues.
The samples are prepared through SoundLibrary and its existing bounded voices,
recording/gain/mute controls and nearby-ally filter. A miss produces swings only;
dodge, focus loss and selection cancel pending cues with the existing attack.
Walking uses Goemon's prepared footsteps, as does every shared footstep fallback.
The old prototype `audio/step.wav` is excluded from gameplay/default previews.
PCM hashes and source provenance are in `assets/audio/crossgate/kazi/provenance.json`.
Recovery checks exact sample PCM and does not synthesize replacement sounds.

The source contains 19 actions / 152 directional clips in total. This game
keeps the seven gameplay actions above in the main atlas. Throw, sit, wave, happy, angry,
sad, shake, rock, scissors, paper and fish remain in the preserved source.
No 16-direction or interpolated 3D views were found in this sprite record.

Kaz's normal jump shows the original guard pose during the existing windup,
then hurt frame 0 for a brief flinch, run frame 3 for the rising tuck, run
frame 15 on descent, and fall frames 5 and 3 on touchdown. These are zero-based
indices. All outfits use their own sprites in all eight directions.
Only the guard art needed a new atlas. Recover its 120 unchanged poses with
`python3 tools/recover_crossgate_jump_guards.py '../Magic Power'`. Its eight
columns follow the game direction order. The four rows are Original, Blond /
Rose, Blond / Rose Aura and Yellow / Red Sparks, followed by the eleven
additional outfits in `recover_crossgate_kaz_skins.py` order. Each 100 × 112 cell keeps
its source origin at (50, 91).

Run `Play Goemon.command`, open the fighter gallery with Q and select Kazi.
WASD moves, Shift sprints, LMB/RMB attacks, Space jumps and C evades. Shared
skills can be equipped through the existing Skills & Jump menu.

## Kaz outfits and Maze

### Selected Fire audio — 2026-11-17

The user's numbered sound gallery calls original Kaz 102488 **Kaz 1** and
Yellow / Red Sparks 109146 **Kaz 4**. Both now layer the original level-10
Fire rise 282 and impact 266 alongside their existing source sword sounds.
No boss cry was selected. Other outfits, Maze and equipped alternate weapon
sources retain their original audio.

The first existing sword cue carries Fire rise, including empty swings; the
second existing confirmed contact carries Fire impact. The other sword cue and
first contact keep their original samples, so a two-cut attack does not repeat
the Fire layer twice. Original source cues remain 103/133 for Kaz 1 and 104/104
for Kaz 4. Attack duration, contact count, damage and source artwork are unchanged.

`tools/prepare_crossgate_player_audio.py '../Magic Power'` prepares and verifies
these user-selected mixes in the existing shared sample bank. Immutable original
PCM, full sample tails, original pitch, common attenuation to prevent clipping,
selection-time caches and existing pooled voices retain their previous owners.
Run it with `--check`, run `tools/goemon_assets.py check`, then use
`crossgate_player_audio_test.gd -- --kaz-fire --visual` through Play Goemon for
both appearances, every weapon route/eight facings, hit/miss audio and Studio
previews, recordings/gain/mute, repeated voices and five native copies per look.
Evidence is under `build/Other Files/Asset Toolkit/Kaz Special Sound Review/Fire/`.
Quit and reopen Play Goemon to replace audio already cached by a running game.

Shared weapon skills retain these layers too: Combo and charged strikes use
the selected native attack; Qi/Moon/Spirit weapon gestures use its prepared
swing and effect-contact cues; Bee Flurry and one-contact counters retain the
complete selected impact mix. The spell's own charge, release and projectile
audio is preserved. Pure elemental casts keep their existing spell audio.
`crossgate_skin_skill_audio_test.gd` covers Kaz 1/4 and all nine reviewed Shin
looks across thirteen skills, plus five native Moon casters per Kaz look.
It saves real desktop Bee Flurry/Moon recordings and evidence under
`build/Other Files/Asset Toolkit/Skin Skill Audio/`.

Kaz's skin gallery contains sixteen choices, including Maze under the same Kaz
card. The Skin picker saves the selected appearance in the existing settings.
The three earlier alternate looks are recovered
from `puk3:833` (#109890, Blond / Rose), `puk3:834` (#109891, Blond / Rose
Aura, identical artwork under #116567) and `puk2:893` (#109146, Yellow / Red
Sparks). The gallery uses the same source-pixel canvas and foot origin for
each portrait. The world sprite switches atlases on selection and reads
the selected outfit's sword clip. Original Kaz has a purple slash and blast.
Yellow / Red Sparks has its own red burst. Both draw the complete original
effect frames on the body sprite, so the art scales with Model size and
growth. Blond / Rose and Blond / Rose Aura use their own two-strike katana
clips. Every skin makes two regular sword contacts.

Maze is fighter 36. Look 7's sword and throwing records are `joy:599`
(#100528) and `joy:598` (#100527). His world sprite uses Kaz's pixel scale
and inherits Kaz's configured model size until Maze has a size override.
Character Select → **Loadout** saves which of Katana and Kunai comes first.
**Z** cycles the saved primary weapon, secondary weapon, Fist, then the
primary weapon again. The HUD shows the active form beside Maze's portrait.
Fist uses all eight directions of `joy:598` action 5, with one punch contact
at source frame 7. Its original skill on **1** fires eight gold Qi Blasts.
**3** plays Shining before summoning five Mirror Images in the equipped
form. **6** starts with 陽炎 and can be reassigned in Loadout.

Maze and the two rose skins play the 42 recovered katana frames in .6 seconds.
The swing cue plays at source frames 12 and 26, and the cuts land at frames
13 and 27 (zero-based). Each cut uses the shared forward sweep and regular
250 base damage. Maze's katana has no blast.

Maze can run and steer throughout the kunai throw. Either mouse button
locks onto the nearest visible, unobstructed enemy within 120 m at base
range. The throw follows that target's position through release. With an
empty lock it throws forward. Original
action 7 has nine frames over 800 ms, with release flag 10111 on frame 7
(zero-based). The archived client uses knife serials 22090–22105 for flight.
Maze's flight and HUD use a single kunai isolated from the overlapping pair
in graphic serial 21100 (`v3:31`). A mask preserves the foreground blade's
source pixels and the exporter prepares 16 directions with nearest sampling.
The throw plays in about 267 ms and releases at about 207 ms. The kunai
flies at 72 m/s. Its sprite and contact radius are 15% smaller than the
earlier enlarged version. Goemon reuses the prepared sound 111 (`cgply05a.wav`) and
the shared swept projectile pool. The base range is 120 m and the base
damage is 250. Walls and terrain block the knife. Walking and landing
use Goemon's prepared sounds.

Rebuild the costume and Maze atlases with the preserved Magic Power project.
The extractor keeps source frame indices, checks exact packed pixels, and
verifies the throw cue and original sound bytes.

```sh
python3 tools/recover_crossgate_kaz_skins.py '../Magic Power'
```

Pass `--maze-only` to rebuild only Maze's atlas. Pass `--punch-only` to
recover the Qi Blast poses for classic Kaz (`joy:816`, #100890) and
Uru (`joy:841`, #105714). Each uses all eight directions and the
original 10131 contact marker. Maze shares his existing Fist frames.

### 刀刃亂舞

With Kunai equipped, **1** plays a nine-frame green-white flash, then
throws one knife at each of the six closest visible enemies with a clear
path. With fewer eligible enemies, Maze throws fewer knives. A clear shot
deals the ordinary kunai's 250 base damage. The five-second cooldown starts
when knives leave his hand. Saved Loadout assignments take precedence over
the default.

Goemon uses the selected six-frame BlueCG effect **110473** from `v3:94`,
direction 0, at five client ticks per frame. The sprite has no sound
marker. Maze uses the user-selected Blue Cross Gate impact cue **141** for
ordinary kunai and Blade Dance, without a second reaction cue. The sample
is copied byte for byte from `NewClient.7z/bin/se/cgply15.wav`.
The opening uses the shared high-rank **110100** sheet at three ticks per
frame and sound **251**. Its reference frame spans 2.2 standing body heights
and the rays center on Maze's torso. The original lower-rank **110103**
sheet remains available as a reference. The impact is centered
on the enemy and uses six times the source scale. The six #21100 kunai and
real-time targeting are Maze's adaptation.
[BlueCG's skill announcement](https://www.bluecg.net/forum.php?mod=viewthread&tid=30)

```sh
python3 tools/recover_crossgate_blade_dance.py '../Magic Power'
```

## ※鴻雁追月 · Lv. 11

Kaz defaults to 追月 on **1**. Six sword waves launch together and lock onto
distinct visible enemies. Each hit deals 3,000 base damage before combat
modifiers. Goemon uses its existing closest
visible target query, fitted hit volumes, cover checks and five-second
cooldown. Spare waves fan forward when fewer than six targets are available.
A saved slot assignment takes precedence over the default.

Each projectile paints the forward Blue Cross Gate slash onto a rounded
version of Kojiro's folded Wind mesh. White tips and lavender inner streaks
follow the [Cross Gate footage around 0:17](https://www.youtube.com/watch?v=tFqO_KN2a5g&t=16s).
The mesh is prepared once and shared
with one material across all Kaz waves. `moon-waves-relief.png` supplies the
full crest silhouette. Each wave leaves a short trail of white sparks.
The volley starts at a common point in front
of Kaz and fans toward its targets. Each crest unfolds to its 3× length as
it clears the caster. Its tip
moves toward its target at the same 8 cm clearance used for Kojiro's Wind
launch, following terrain and decks with a short downward ray.
Charge, swing, release and hit cues use the original audio.

The preserved Blue Cross Gate client dispatches the skill family 2005
(tech 200510 at level 11) at `0x42fd78`. State `0xf6` at `0x40586f`
uses its rank index 10 branch. It spawns the whole volley on the sword
release flag, then calls sound 268 once at `0x405933`. The projectile
factory at `0x416aa0` chooses one of resources 104222 through 104237,
starts with two ten-pixel movement updates and uses four frames at
31 updates each. Ordinary contact uses sound 255 at `0x406002`.
The factory copies the caster’s two planar coordinates at `0x416af9`
and `0x416aff`. The update at `0x415d60` advances just those coordinates,
and `0x416190` measures contact distance in the same plane. Goemon sweeps the
ground path against its native fitted hit volumes.
The [Blue Cross Gate skill table](https://wiki.biligame.com/bluecg/%E8%BF%BD%E6%9C%88)
lists six targets and 55% damage for rank 11.

The original nine-frame charge (110100) holds three updates per frame
and plays sound 251 on its first frame. Goemon uses the one-update
transition after charge completion from the client's effect-first update
order. Kaz's current sprite 102488
lacks a projectile flag in its sword clip, so the Goemon animation uses
its existing pose art on the timing of classic Kaz 100028. The classic
clip plays sound 103 at frames 12 and 26 and releases on frame 27
(flag 10134), all zero-based. On Goemon's 60 Hz timeline, the opening
charge is tick 0, the sword cues are ticks 40 and 54, and all six waves
appear with sound 268 on tick 55. The spell chain keeps this cadence
fixed, and the charge placement, ground glide and target selection follow
Goemon's world. These timing references come from the archived client.

Regenerate the archived and relief atlases, hotbar icon and original WAV with
`python3 tools/recover_crossgate_moon.py '../Magic Power'`. The extractor
checks the preserved snapshot hash, rank branch, classic markers, source
frame pixels and release cue. See `tests/forest-shrine/crossgate_moon_test.gd`
for the desktop and native army replay.

## 氣功蛋 · Qi Orbs

Kaz and Uru can equip **Kazi · 氣功蛋 · Qi Orbs** in **Q → Skills & Jump**.

One press plays the charge and releases eight homing orbs. They lock onto the
eight closest distinct visible enemies within 144 m for Kazi, or 48 m when
borrowed. Kazi's Qi Orbs pass through valley ground during targeting and
flight. Fire, Ice, Meteor and Wind also pass through walls.
If fewer are available, the spare shots fan forward. Each locked hit deals
750 base damage before the caster's modifiers. Solid cover can stop a shot
after launch. The cast has a five-second cooldown.

The preserved Magic Power report is
`../Magic Power/research/qigong-20261101/recovery.json` relative to the project
root. Its `assets/110016.png` (eight projectile frames) and `assets/110100.png`
(nine high-rank charge frames) are copied byte-for-byte to
`assets/characters/crossgate/qigong/orbs.png` and `charge.png`. The report's
SHA-256 values match both copies. The shared spatial shader shows the source
dark blue and bright cyan frames on Kaz. Uru uses a red-and-white palette
that keeps the same two glow patterns. The display
is 6.3 m by 6.192 m at standard size. Kazi's
existing cast gesture plays during the .45-second charge. The recovered
251/254 sounds are copied from the same report and impact 255 reuses Kazi's
existing sample with identical PCM. The eight-lock volley, damage, cooldown
and real-time travel are Goemon adaptations of the recovered Blue Cross Gate
presentation.

Orb contact uses the visible orb's center and the recovered alpha diameter
of the current frame. The shared thin ground outline shows Kazi's sword reach
during combat and follows the existing character reach settings.

## Level-11 elemental spells

Kaz defaults to Ice on **3**, Wind on **4** and **隕石** (Meteor) on **5**.
Uru defaults to Fire on **2**. All four elemental spells are available through
**Skills & Jump** and have five-second cooldowns. They use the Qi Orbs lock
range and visibility rules.

Fire and Ice appear at up to eight locked positions. The main elemental
effects are four times their earlier body-scaled size. Their damage areas
grow with the artwork. The recovered charge flare is anchored at Kazi's
feet and measures twice his standing height on its reference frame before
any Skill Balance size adjustment. Orange signals Fire, cyan signals Ice,
yellow signals Wind and green signals Meteor. Fire hits once for 1,500
base damage. Ice hits up to three times at 400 each. Overlapping Fire or Ice
zones share the same per-pulse hit history. Wind launches eight homing
effects, with spare winds fanning forward. Each wind's area deals up to four
250-damage hits on contact, and separate winds can overlap.

Meteor drops up to eight stones onto the locked locations. Each enemy in
the impact areas can take two 650-damage hits per cast. The second pulse
follows the first by ten physics ticks at 60 Hz, and overlapping impacts
share hit history for each pulse.

The read-only source is `../Magic Power/godot/assets/humanoid-spells/manifest.json`.
Its level-11 single, strong and super forms map to the same cast and target
art for each of these elements. The exact PNG copies in
`assets/characters/crossgate/elements/` use cast **110052**, Fire **110140**,
Ice **110020**, Wind **110044**, trail **110007** and impacts **110001–110003**.
Fire alternatives 110141 and 110142 have the same bytes as 110140. The port
uses cast sound **259**, Fire **282/266**, Ice **264/131/132/131/132** and Wind
**269** for flight and contact. The timings and cues use the recovered frame
clock. Meteor uses the three original **110032–110034** variants and recycles
the shared trail and impact sheets. Sound **262** plays on release and **131**
plays on each pulse. Targeting, the 3D fall path, area damage and extra hit
pulses are Goemon rules.

The five magic icons reuse frames of the recovered Blue Cross Gate spell
effects. The transparent 64 px crops in `icons/` use zero-based frames
Qi Orbs 1 (violet tint to match Goemon), Fire 8, Ice 10, Wind 0 and Meteor
variant 1 frame 3. Their source sheets are `../qigong/orbs.png` (8×1) and
`../elements/{fire,ice,wind,meteor-1}.png` (8×2, 8×2, 4×1 and 8×2).

## 連擊

Kaz's default **2** charges and blinks beside the nearest reachable enemy
within 32 m, then repeats within 10 m of each landing for up to eight
distinct enemies. Each hop checks the destination and path against solid
cover. A grounded press without a valid target leaves the skill ready.
The first cast deals 375 base damage per cut. Consecutive casts multiply
that by 1.5×, 2×, 2.5× and so on. Each cast locks its multiplier on the
first blink. Starting another skill or toggling 陽炎 clears the streak.
The five-second cooldown starts on the first blink. Saved slot assignments
take precedence over the default.

The 0.45-second windup uses the original nine-frame **110100** glow and
sound **251** from the prepared Qi Orbs assets. One sprite follows Kaz's
torso until the first blink or an interruption.
The strike uses Kaz's recovered sword clip through its first contact and
plays the original swing at frame 3. Each blink stamps three of the existing
陽炎 afterimages along the path and plays sound 210. The original seven-frame
連擊 impact is resource **110133** in the preserved Magic Power
`godot/assets/humanoid-spells/manifest.json`. The recovery script above copies
the sheet byte-for-byte to `combo-impact.png` and crops zero-based frame 4
for the hotbar icon. The impact plays at 90% of its recovered four-tick frame
rate. Its main burst is 2.1 times Kaz's standing height, including model size
settings. It uses 128/255 opacity in the army's existing effect pool.

## 陽炎 · Kagerou

Press **6** to toggle guaranteed dodge. Kaz starts with it off. The hotbar
shows ON or OFF, and either toggle plays the original dodge sound. The icon
is made from the existing front-diagonal Kaz frame and two translucent copies.
The recovery script above regenerates it.

The visual comes from static inspection of the preserved 2026-10-30 Blue
Cross Gate client image at
`../Magic Power/research/newclient20261030/combat/bluecg-virtual-memory.bin`,
SHA-256 `8babbe4ad20e4e1e2a6992ecf086d47ef3527426879699f83fa2cebb1a476afe`.

- The ordinary physical contact code at `0x405ec5` handles result bit
  `0x100`. It enables the defender's afterimages, plays sound ID **210**
  at `0x405f48`, and sends the defender into state `0x1d`.
- State `0x1d` at `0x409134` walks backward four pixels per update for
  13 updates. The **52-pixel** maximum maps to about **2.02 m** at Kaz's
  normal model size. The ordinary sequence holds through update 28,
  then state `0x0b` walks home at four pixels per update and snaps within
  five pixels. In Goemon he reaches home on update 40.
- The emitter at `0x4154a2` takes a snapshot every two updates. The
  callback at `0x41bd60` retires each afterimage after 12 updates
  (**0.20 s** at Goemon's 60 Hz). The 32-bit sprite path at `0x517a05`
  uses alpha 128/255. The six reusable sprites keep each snapshot's pose
  and position until it expires.
- The original sample is `NewClient.7z/bin/se/cgbtl09.wav`. The file and
  decoded PCM hashes match the archived client sample. The existing
  SoundLibrary plays it for a dodge or either toggle and supports user
  recordings, gain and mute.

The Blue Cross Gate client can wait for an attacker's animation state or
use a faster return in special branches. Goemon uses the ordinary physical
dodge timing for its real-time melee and projectiles, groups overlapping
contacts into one visual reaction, and keeps the physics body under the
player's movement controls. The toggle and guaranteed dodge are Goemon rules.
Client disassembly and replay evidence are under
`build/Other Files/Asset Toolkit/Kaz Kagerou/BlueCG/`.

Focused checks and a paired standard-army benchmark live in
`tests/forest-shrine/crossgate_kazi_test.gd` and `crossgate_kazi_benchmark.gd`.
Reports and reviewed captures are under `build/Other Files/Cross Gate 102488/`;
performance interpretation is in `docs/goemon-performance-guide.md`.

## Shared hold-X guard — 2026-11-12

The selectable Cross Gate roster uses hold X for a frontal guard. The player
reuses source action 9, including the existing `jump-guard.png` direction/weapon
rows when action 9 is absent from the main atlas. `crossgate_model.gd` selects
that prepared pose while the shared Hero owns input, facing and incoming damage.
All selectable skins, weapon stances and eight directions are checked in
`tests/forest-shrine/crossgate_guard_test.gd`. No guard art was regenerated.

Guard reduces frontal damage by 75%, suppresses ordinary knockback and pauses
new attacks/auto-attacks/spells. It waits for the current action to finish;
jump/dodge, focus loss and character switching release the intent. Backward
movement retains facing. Existing Defense reduction, damage recovery and Shin's
on-hit counter remain in their original owners. Arena slimes use native delayed
guarding and their already packed original guard art; see the performance guide
for timing, scope and current verification.


## Complete Kaz skin inventory — 2026-11-16

Eleven more reviewed outfits are available under Kaz's existing skin picker:

| Skin ID | Appearance | Original sword record |
| --- | --- | --- |
| 100028 | Classic · Brown / Teal | original:2402 |
| 100034 | Classic · Teal / Yellow and Red | original:2408 |
| 100040 | Classic · Red / Navy | original:2414 |
| 100046 | Classic · Black / White and Red | original:2420 |
| 100049 | Classic · Red / Silver | v3:517 |
| 100891 | Black Hair / Black | joy:938 |
| 100918 | Blond / Black | joy:785 |
| 100969 | Black Hair / Red | v3:519 |
| 105564 | Black Hair / White | joy-ex:427 |
| 105570 | Black Hair / Blue and White | joy-ex:433 |
| 105608 | Red Hair / Black | joy-ex:421 |

These use the existing source-pixel exporter, shared movement timeline and
original 42-frame katana action, with two contacts at frames 13/27 during the
existing .6-second attack. No weapon transfer, new combat owner or retargeting
is involved. Each new outfit has its own one-page atlas (about 6.09 MiB RGBA),
selected through the existing load/release path. The shared guard sheet extends
its original four rows without changing their pixels. Maze keeps fighter ID 36,
its saved gear/skills and prepared sword/kunai/fist behavior. Ten Kaz outfits
have matching axe, bow, fist, staff and spear art in the Equipment catalog. The
Original, Blond / Rose, Blond / Rose Aura, Yellow / Red Sparks and Classic
Red / Silver outfits retain their prepared sword. A weapon saved under Kaz
stays in the loadout while an incompatible outfit uses its sword.

The archive review covers the 12,936 catalog records and 1,911 omitted NewClient
EX animation aliases. Neutral and attack art were reviewed separately from head
mask shortlists; sitting-only records and unrelated characters are excluded.
Undecodable archive records remain unresolved. The extra aura ID 116567 still
shares 109891's artwork and is not a duplicate choice. Reverted illustrated
references and approved painted/conversation masters remain preserved.

```sh
python3 tools/recover_crossgate_kaz_skins.py '../Magic Power'
python3 tools/recover_crossgate_jump_guards.py '../Magic Power'
python3 tools/recover_crossgate_kaz_skins.py '../Magic Power' --check
python3 tools/prepare_crossgate_weapons.py '../Magic Power'
# Refresh the runtime head inventory and original head cache, per the portrait README.
'/Users/eric/Desktop/Play Goemon.command' --headless --script res://tests/forest-shrine/skin_head_hud_test.gd -- --catalog
python3 tools/prepare_crossgate_heads.py
python3 tools/prepare_crossgate_heads.py --check
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/kaz_maze_skin_test.gd
```

Source reviews, exact-pixel checks, gameplay logs and rendered captures live in
`build/Other Files/Asset Toolkit/Kaz Complete Inventory/`. Use Play Goemon →
Kaz → Equipment → click the portrait. No app export is needed for these changes.

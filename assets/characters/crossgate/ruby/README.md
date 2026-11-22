# Uru · Blue Cross Gate

Fighter ID 35 uses the white-and-red staff appearance (#20, animation
105716, `joy:813`) with its original pixels, size and animation origins.
The exporter preserves the optional orange rune and sparks from #31
(animation 109907, `puk3:850`) in separate atlas regions. Gameplay plays the
body frames and leaves those two effect layers unused.

`motions.json` retains all 19 original actions, eight directions, source
frame records, durations and cue markers. Gameplay uses the original
standing, walking, running, staff attack, casting, hurt and fall motions.
The other source gestures, including the throw and its sound cue, are
preserved for reference. Both mouse buttons use the original two-second
staff animation. The five source contacts at frames 15, 19, 23, 27 and 31
use Goemon's shared native melee query and deal 100 base damage each.
The damage, sweep reach and cover rules are Goemon adaptations. Swing
and successful contact use the archived Blue Cross Gate PCM (109 and
139). Walking and landing use Goemon's prepared defaults.

Keys 1–5 use the shared Cross Gate spell kit, combo clock and projectile
pool. Uru starts with Spirit Shockwave on 1 and Fire on 2. Equippable
Qi Orbs alternate darker red and brighter red-white glows on Uru.
The shader tints the original frames per pooled instance on release. The
other spells use the shared original Blue Cross Gate sounds and artwork.
Uru and Kaz have independent saved assignments and sound overrides.
Both use the same translucent melee range outline. Its opacity has no
effect on actual contact reach.

With Qi Orbs equipped and full flashes enabled, both fighters use the original level-11
charge sheet (110100) at 2.2 times standing height on its first frame.
The original contact sheets (110001–110003) begin near the target and
are given at least 0.10 seconds of lead before point-blank damage.
The pre-contact placement and timing are Goemon adaptations. The
contact flash plays on the existing orb lease and adds no damage pulse.
Reduced Flashes retains the lower-intensity presentation.

## Lv. 11 精神衝擊波 · ※高感應電流

The preserved client uses cast sheet **110052**, sound **259**, ring
**114177**, normal sparks **110001–110003**, and contact sound **255**.
Uru's staff animation releases on frame 11, at tick 33. The rank-11
client creates one lead ring and four children, all on action zero.
The skill icon uses the same ring art, with four small rings behind the leader.
Goemon fits the children's quadratic spread to the shot's 3D flight.
Each child stamps its previous pose once per 60 Hz update, including
its ring frame and stationary position. The copies use the original
128/255 opacity and expire after 12 updates. The visible trail can
outlive the moving projectile.

The ghost callback at `0x416830` clones the four child rings through
`0x41bd90`. Its render flag sets alpha to 128 at `0x517a0e`, and
`0x41bd60` deletes the stationary copy on its twelfth update.

The rank-11 parser runs through `0x42dee5` with protocol 267 and
sublevel 10. Factory `0x4176c0` gives the first and later shots states
`0x10` and `0xf0`. Their ordinary contacts both use the three standard
sparks. The orange **110477** is selected by a different state and was
used in the initial Goemon implementation.

Goemon adapts Blue Cross Gate's row attack into a homing barrage. One
query locks the candidates within 192 m. Every visible enemy with a
clear path receives one shot for 5,000 base damage. Solid cover can
stop a shot in flight. The five-second cooldown starts on the opening
cast. Large barrages wait for available projectile slots and send every
eligible shot in batches.

## Lv. 11 恢復魔法 · ※再生術

Press **6** to cast Regrowth (**※再生術**), including at full HP.
The cast glow and cue **261** (`cgefc10.wav`) open the spell. The
original target effect, sheet **110176**, descends to Uru's torso and
plays cue **291** (`cgefc38.wav`) on arrival. The cast holds each of
seven frames for three ticks and the target effect has 20 frames at
two ticks each.

After the arrival animation, Regrowth is ready for six heals. Starting
a staff attack or casting a spell triggers a pulse. Walking, jumping,
and regular dodges leave the heals armed. Each pulse restores up to
`floor(Recovery × 2.4)` HP, capped at missing HP. Recovery starts at 100
and can be tuned under Uru in Character Balance. A full-HP pulse still
shows the green hoops and plays cue **279** (`cgefc28.wav`). Only actual
healing spends a charge and displays the green HP digits. The ten-second
cooldown starts on cast. A new cast refreshes the six heals. Defeat or a
fighter switch clears them.

The cast uses the rank-11 sheet **110081** and the hoops use the
approved green recolor of **110085**, with every original alpha mask
preserved. The hoops hold each of 46 frames for two ticks. Cue 279 is
from the original green hoops sheet **110165**. All three WAV imports
preserve the archived PCM. The skill icon uses the fourteenth frame of the
green hoops, with the healing rings stacked above one another.

To rebuild from the read-only Magic Power archive, run
`python3 tools/recover_crossgate_ruby.py '../Magic Power'` from the Goemon
source root. The exporter checks matching donor clocks, original body
pixels, atlas copies and source WAV hashes. Refresh Godot imports after
a rebuild. To verify gameplay, open Play Goemon, press Q and select Uru in
Blue Cross Gate. Character selection shows the Cross Gate roster only; older saved identities and assets remain preserved.


## Corrected appearance inventory — 2026-11-16

Uru has 32 appearances, including eight Special choices, with 182 original
weapon combinations. Four appearances were wrongly placed here during the
previous inventory: black/gold armor 100700, ornate 100798 and 120428, and
red-rune 109912 belong only under Rei. The three new Rei outfits now use their
correct `fighters/rei/ID` roots; the red rune was already in Rei's gallery.
Classic black Ruby 100650 belongs to Uru and is removed from Rei's earlier
catalog. The previous 36-choice report is historical and does not establish
correct ownership.

Uru's original skin 0, gameplay root, five-contact staff and saved key `35`
remain unchanged. Original model heads now replace painted HUD routes; paintings
and prior head source art are preserved separately. Pink pet 111691 remains
unarmed-only and gold flame 109909 remains staff-only. Other Uru appearances
retain all six supplied weapons. Rei's red ornate outfit keeps five weapons
without an invented fist source. Saved character IDs and existing correct
loadouts remain unchanged; an old invalid appearance setting follows the existing
validation fallback. Incorrect Uru choices are not silently converted to Rei.

The 27 added Uru choices and their exact archive keys live in
`tools/crossgate_uru_skins.json`. The shared special exporter prepares these
alongside correctly owned pet/effect appearances in `SpecialSkins.CATALOG`.
`ex:1549` (100662) remains an exact 976-frame duplicate of 100656's unarmed
source; 105712 is represented by original skin 0. No duplicate is added.

Rebuild with `../special-skins-README.md`, then prepare the original HUD heads
using `assets/ui/portraits/crossgate/README.md`. Run the current focused fixture:

```sh
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/crossgate_uru_inventory_test.gd
```

Corrected ownership, source preservation, front-head previews and current
regression evidence are under `build/Other Files/Asset Toolkit/Model HUD Heads/`.
The earlier discovery scans and 36-choice captures stay under
`build/Other Files/Asset Toolkit/Uru Complete Inventory/` as historical evidence.
Only recoverable verified artwork is assigned; uncertain identities and
sitting-only gestures remain excluded. No future-client completeness is claimed.

To choose a skin, relaunch Play Goemon → Equipment → Uru → portrait. Special
pet appearances remain skins of Uru, using the existing native combat and army.

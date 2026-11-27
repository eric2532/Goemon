# Black Prayer / 露比 recovery

The suspicious rock in Sokia Undersea Cave now leads through original entrance
16507, six generated maze floors, and original Ruby palace 16508. Previously it
jumped directly to the palace. Return stairs traverse every floor in both
directions; the palace arrival is the original (39,5) endpoint. Reward rooms
remain locked until all ten members of Ruby's party die. Retreat to the maze
remains possible before victory.

Each maze floor uses a deterministic run seed plus its own stable runtime ID
30101–30106. Corridors, room extents and both stair positions change across runs;
returning during a run preserves the map. The current reconstruction chooses
64×64 cells and sixteen rooms. The source specifies 40–80 cells on both map
axes; its separate 10–20 fields describe door dimensions, not room count.
It uses the existing DFS/carving helpers with three-tile corridors. The exact
original server maze algorithm has not been recovered. These runtime IDs are
not claims about original transient cache filenames. The fixed entrance and
boss palace retain original navigation, consistent with the source dungeon
configuration; they are not randomized.

All six maze floors use native floor 9555, original cave-wall faces, solid 3D
up/down stairs 17974/17975, fitted grey rock scatter and a closed roof. Palace
walls use source 15810 stone instead of generic masonry; four overhead caps
and six arch headers use raised stone geometry. Three original barred
panels use solid iron geometry. Ten archived bookcases now use shared solid
cases, shelves and gilt trim with native rectified book fronts. Pedestal 16100
has a solid stem and the original blue ornament pixels. Both native red/gold curtains and all seven armored statues now use cached
solid geometry, source paint and their archived cells; high spears preserve
the two original poses. Remaining untouched palace decorations retain original
sprites. Twenty-two source columns
(16464/16499) now have solid capped red/gold faces; five source pictures
(16130/16131/16132) use solid gilt frames and their original picture paint, facing
into the room from the archived right wall. See `assets/maps/falan/black_prayer/README.md` and
`assets/references/black_prayer/README.md` for source paths and preparation.

Both curtain friezes now use bounded native-stroke relief and raised cords
following their source cloth folds. Armor keeps native plate paint with physical
helmet/finger/boot details and separate ridges/joints. Eight small 16128/16129
vase pedestals reuse the existing stand/vase parts with original lacquer, blue
ceramic and carved gilt faces, facing the original two sides of the hall. No
source cells, navigation or gameplay owners change. Unseen 3D surfaces remain
fitted interpretations of the original sprites.

The remaining tall mirror 16223 now has its original static glass paint over a
solid back, a source-carved cabinet and two white bouquets. Nine 16218/16219/
16232 arrangements retain their original pot paint, native petal/leaf palettes
and distinct tall, wide and low silhouettes. They reuse existing whole Wind
Meadow flower/shrub meshes through owned color copies, preserving source meshes,
all placements and collision. Lower stems enter the vases; unseen shapes and
branch depth remain fitted from 2D evidence.

The six logical floors now resolve config301 encounter15001 through the existing
native movement-encounter owner. Its equal-weight groups15006/15004/15005 retain
the source mixed Ghost/Bloody Blade, Ghost-only and Blade-only rosters. The
prepared source member IDs, levels/count fields and mandatory flags remain
available in `assets/maps/falan/black_prayer/encounters.json`. Floor levels
20/21/21/22/22/23 follow the pinned reference editor's formula; original server
level progression is not authenticated. The existing native chance1–3 and
uniform party sizes1–6 remain adaptations with raw source fields retained.

The earlier96 static patrol stations and `black_prayer_slain` keys remain
compatibility data, preserving old slot identities and generation. They no
longer supply the live ordinary pool. Ordinary source deaths cannot unlock
Ruby's separate reward ledger. This restores source-specific groups, rather
than reducing population to claim performance. Existing native targeting,
combat and pooled presentation still own every actor.

Source boxAmount4 is a whole-branch total under the recovered reference
generator; current Prayer loot/refresh remains a required reconciliation.
Original room generation, door dimensions/placement, dynamic stair103012
versus cached17974/17975 and encounter timing/count distributions remain
qualified. Known config/floor indexes do not establish transient client map IDs.

Ruby retains original actor 100654, five Blades 101600 and four Ghosts 101121,
original cached animation/sound preparations and fourteen named spells: single
and strong Heal/Recovery, Holy Shield, physical/magic Absorb/Reflect/Null, Super
Ice, Super Meteor and Super Confusion. With at most two surviving Bloody Blades,
Ruby alternates the three offensive spells with support. Typed wards use actual
native hit handling, finite contacts and expiry; reflection returns the incoming
amount through the existing attacker lifecycle. Recovery restores native HP.
Paired casts reuse the original spell pose, sixteen prepared original effect
clips and shared audio/visual pools. Six typed contact sheets replace the generic
physical/magic ward rectangles: physical/magic Reflect 110109/110113, Absorb
110117/110121 and Null 110125/110129. They play when a native ward actually takes a
contact, with their original sound markers. Confusion uses original cube 110163
throughout the existing timed state. Holy Shield now uses original contact sheet
110098: the gold ring and four blue rays replace the persistent prototype shield.
It plays on accepted native physical/magic contacts while the existing reduction
is active, not continuously during the whole buff. The compact production
event path retains target, amount and duration fields for these statuses.

`assets/references/black_prayer/spell-effect-factory.json` records the archived
client factory at 0x41a600. The ward branches query the matching skill protocols
55–60 at 0x437c10 and select the six distinct resources. Confusion uses kind 6
and the rank-five tier selects 110163. This executes archived bytes with inert
actor/allocator/video/audio fixtures and the already documented EAX tier repair;
it is not live server/client playback. `test_ruby_effect_factory.py` repeats
those seven cases. World anchors, repeated Confusion scheduling and compositing
are fitted to the existing 3D presentation; source frames/origins/cues are intact.

Evidence is pinned in `assets/characters/crossgate/black_prayer/spells/manifest.json`:
server enemy 260092, base 3002, AI 11017 and fourteen matching tech rows. The
[historic Black Prayer report](https://games.sina.com.cn/z/cross/diaocha/heiseqidao.shtml)
and [quest reference](https://gamerch.com/blue-cg/452872) support the wider repertoire
and low-Blade phase. The pinned AI lists eight special choices; the full rotation
also includes spells documented by those encounter reports.

Levels remain 50/30/30; existing real-time balance remains 60,000 boss HP and shared
progression formulas. Exact original AI probabilities, turn scheduling, magic
resistance and absolute healing/damage math remain unrecovered. Healing preserves
the source single/group ratio; source turn counts become timed pulses. Wards use
3–5 seconds and one contact (two for Null); Holy Shield reduces physical/magic
damage by a sampled 50–100 percent for three seconds. Confusion reverses movement
for four seconds while preserving stored orders and exact navigation; original
random friendly-fire decisions are not implemented. Ward/Recovery clocks keep
expiring during freeze, while a frozen caster pauses its committed spell. This
is a closer real-time adaptation, not a complete 1:1 turn-based restoration.

The source script contract now has a scoped live implementation. NPC81000 at16508(24,11)
is `StandEnemy`, encounter11007→group11009; all ten members are mandatory and
the source victory is16509(24,12). The prior39m activation, free guard crossing
and legacy reward-door unlock have been replaced by the source NPC/item/solo
programs through the existing F/dialogue/native owners. Natural letter/candle/
proof acquisition, both ten-member source fights and original post-return
coordinates pass the current465-check native fixture; rendered review remains
separate. Original real-time combat and generation adaptations remain qualified.

Post16509 uses the existing Ruby art at its own104 anchors. The exact pinned
server map fills all571 uncached cells, preserving every recorded client tile
and every flag.3354/5011 clients are fully recorded and have existing-owner
supplements. See `assets/maps/falan/black_prayer/events/README.md` and canonical
`Black Prayer source route/` evidence. Pre-battle16508's253 western cells now use their own pinned source completion,
including73 nonzero floor cells and43 visible wall anchors. All2247 recorded
cells/flags and recorded navigation remain exact;68 source-open cells are added.
Focused native156/156 passes; final normal-camera review remains separate. Original template NPC count/refresh, StandEnemy
repeat/cooldown/escape and profession/training parity remain unverified.

## Verification

Run the generator fixture directly with Godot headless:
`tests/forest-shrine/black_prayer_maze_test.gd`. It checks 32 seeds × six floors,
three-tile stair connectivity, every open cell, sealed edges, distinct layouts,
clear patrol stations, reference levels and sequential return links.

Run `tests/forest-shrine/black_prayer_recovery_test.gd -- --east-il-road` through
`/Users/eric/Desktop/Play Goemon.command` for rendered review, or add `--headless`
for gameplay assertions. This enters through the actual Sokia cave link, visits
all six floors, physically walks down/up stairs, checks persistent native patrol
deaths, enters Ruby's original palace, checks the ten-person native formation,
locked rewards, healing/ice phase and reward-house return. It uses Cross Gate
Kaz and preserves the saved adventure. Evidence belongs under
`build/Other Files/Asset Toolkit/Ruby Dungeon Recovery/`.

Run `python3 tools/recover_black_prayer.py --check`, the ordinary asset audit
and `python3 tools/goemon_assets.py check`. No app export is needed. These checks
are not a full-army performance or long-session soak result.

## Ruby spell and furniture checks

`tests/forest-shrine/ruby_spells_recovery_test.gd -- --east-il-road` follows the
actual six-floor route using Cross Gate Kaz, observes all fourteen casts, checks
healing, real Confusion input, source furniture bounds, reuse, cleanup and saved
adventure preservation. Run through Play Goemon for rendered review. The fixture
freezes escorts and wounds the party to observe support spells; it does not change
the production party count or HP/damage formulas.

`tests/forest-shrine/ruby_compact_events_test.gd` checks the production compact
marshaller separately; recording full events must not hide missing status fields.
`native/terrain_math/crowd/ruby_spells_test.cpp` checks exact ward channels,
reflection, charges, expiry during freeze, regeneration, casting pause/resume,
Confusion steering and native lifecycle reuse. Run both new preparation recipes
with `--check`: `tools/recover_ruby_spells.py` and `tools/recover_ruby_scenery.py`.
Evidence lives in `build/Other Files/Asset Toolkit/Ruby Spells/`.

`ruby_remaining_effects_test.gd -- --east-il-road` observes actual blocked native
contacts, the original cube, all 27 new solid details at source cells, bounds,
complete column caps and mesh reuse. It also exercises twelve presentation waves
of thirty simultaneous original contact effects (five placements × six types),
then checks pool expiry and material/node reuse. These synthetic presentation
waves are separate from the actual ten-member native boss encounter; they are
not five independently simulated bosses. Evidence is under
`build/Other Files/Asset Toolkit/Ruby Remaining Effects/`.

## Holy Shield and royal furniture

`holy-shield-factory.json` distinguishes ordinary guard flag 0x4 (110000), Special
Guard flag 0x400 (110098 with skill-protocol query 8), and ordinary impact 110133.
The archived branch 0x40b0ec–0x40b16f also selects original impact sounds 131–132.
`test_ruby_holy_source.py` repeats all six flag/sound-endpoint fixtures. Actor
fields, impact submission, audio and RNG are inert fixtures; resource selection
and skill lookup execute the original instructions. The server's Holy Shield E1
row 850 is TECH_SpecialGuard, protocol 8, RS50/RE100. This identifies the correct
contact graphic rather than assigning the ordinary guard sheet by appearance.

The four 400 ms source frames and their bounds remain intact. Effect scale is
measured against Ruby's original 85-pixel standing body and current 1.1× Kaz
height; other spells retain their existing scales. Contact centering/compositing
are fitted to the existing 3D effect player; original random impact jitter and
turn-based scheduling remain unrecovered. No new defense simulation or damage
formula was added. The native owner emits the existing typed ward-contact event.

Four source dining sets 16115, chair 16124, two urn cabinets 16140 and six round
stools 16204/16205 now use solid reusable scenery. Dining sets reuse two complete
existing chair meshes each; native ivory/gilt/seat colors are isolated on the
royal cached mesh. Original cloth, cabinet panels, red tops, ceramic and stool
paint come from the corresponding source sprites. Body/carving silhouettes remain
fitted interpretations, especially the borrowed chair backs. Native cells,
compound footprints, navigation, the six random floors and reward ownership are
unchanged. Other ornate source details remain preserved for later recovery.

`ruby_holy_shield_test.gd -- --east-il-road` extends the previous route/effect
fixture with both actual Holy Shield hit channels, source-relative sizing,
original sounds, pool cleanup and thirteen new source placements. It also checks
compound chair footprints and native linen UV orientation. Evidence belongs in
`build/Other Files/Asset Toolkit/Ruby Holy Shield/`.

## Carved furniture and remaining ornaments

Nine royal chair backs now use the native 16124 painted outline and shallow
carved detail in place of the earlier plain bowed backs. The existing chair
builder supplies their legs/seat/stretchers; ordinary Falan chairs keep their
complete original mesh. Two source 16140 cabinet fronts gain bounded native
pattern relief. Twelve round tripod ornaments 17680 and arched mirror 16137
now use solid source-painted silhouettes and shared existing parts. The mirror
retains the original static painted reflection, without a new reflection pass.

Preparation reuses the Falan/arena shallow-depth recipe and the existing Falan
relief and silhouette builders. Source-alpha contours preserve the painted
outline; material alpha preserves internal cutouts. Front/rear support paint
reuses the single recovered view. Depth and unseen surfaces remain fitted 3D
interpretations. The original archive, fixed placements, colliders, navigation,
party lifecycle and all six random maze floors remain unchanged. Curtained
arches, armored figures and other ornate originals remain for later study.

`ruby_carvings_test.gd -- --east-il-road` follows the actual six-floor route,
checks 24 source-painted features, 13 newly solid ornament placements, recursive
assembled bounds, absence of new collision owners, shared meshes/materials,
original plain-chair preservation and repeated setup/reuse. Run through Play
Goemon for gallery and original-hall visual review, with the source recipe's
`--check`, generator check and ordinary asset audit/preservation checks.

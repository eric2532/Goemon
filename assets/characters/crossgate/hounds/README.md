# Blue Crossgate Gatekeeper Hounds

Goemon uses native army type 19 for all 21 guard hound appearances. During
battle, P queues only missing members of the saved five-pet loadout. Open
Pets beside Stats or press Shift+P to choose portraits, filter Hounds/Mantises/
Aura & effects, and save. Each source key occupies at most one slot. Saving
recalls removed pets and preserves retained pets' wounds; new selections arrive
on P. Empty selections persist. The army places up to three per tick on clear
ground near the player and retries blocked placements.
The pack does not affect the enemy wave roster or kill reinforcements.

The hounds have 3,000 base HP, a 4.5 m/s combat pursuit speed, and 30 damage
per eligible contact. Pet cards add 30% damage, 20% movement speed, or 30%
maximum HP per rank for the current run. They apply to existing and later
hounds. A health upgrade retains the amount of damage a hound has taken.
They acquire threats within 18 m of the player, or
within 10 m while the player runs. They stay with a reachable target even
when the player moves away. After a fight, each dog picks a clear spot
around the player. It runs to a nearby spot or blinks to a distant one
after a brief staggered pause. When the player stands still, the dogs
stagger short walks with idle pauses of 4–12 seconds.
G sends the pack to hunt reachable enemies across the battlefield.
The dogs sprint up to 22 m/s on long approaches and slow to 4.5 m/s near
their targets. After a kill they look for another enemy. New assignments
favor targets with fewer dogs and cap at four dogs for regular enemies
and six for Skullpion. H calls the dogs back on foot at up to 34 m/s.
They slow into separate spots around the player and hold until the next
G order.
The blue hound's front-diagonal standing sprite is 40 percent taller than
Kazi. The same scale drives the fitted bounds, movement clearance and
bite reach, independent of Enemy Size. Hounds have no floating health bars.
Each selected guard has one of five portrait slots below the player health bar.
The portrait's opacity follows its current share of maximum HP. Its slot
goes blank when it dies. `hud-heads.png` contains the 21 cropped front idle
sprites in summon order and is rebuilt by the extractor below.

The preserved Magic Power client supplies idle, walk, run, attack, hurt and
fall in eight directions for every approved appearance. The atlas
keeps exact visible colors, frame order, offsets and native durations. The
extractor verifies the pixels as they are indexed and packed, and verifies
the original WAV PCM hashes. Rebuild with:

```sh
python3 tools/recover_crossgate_hounds.py '/Users/eric/Desktop/Projects_Codex/Magic Power'
```

The atlas includes the Purgatory Gatekeeper (#108448), white/green aura
(#109927), pink/gold flame (#119618), and Three-Headed Hellhound (#102007).
Purgatory's ring accompanies its two-second, three-contact attack. The white
and pink variants retain their four contacts. The three-headed hound has
three directional gestures with one or six contact markers. The pink hound
uses a different impact sample in one direction. Both directional variants
select their sprite and sound timeline together when an attack starts.

The existing native melee and cover checks decide whether a contact marker
deals damage in Goemon. Original run clips contain no sound markers. The
cast sound (156) is archived with its source markers for reference.

## Original pet switch

The preserved Blue Cross Gate NewClient snapshot formats a battle pet
selection as `M|%X` at `0x4941E5` and recall as `M|FF` at `0x493FA6`.
Its `MON` result handler at `0x425110` queues the incoming pet's sound
(state `0x4E`, sound ID 204, `cgbtl03.wav`) and appearance (state `0x34`
at `0x409EE3`). Effect kind `0x16` selects animation 110096 at `0x41A7A4`.
The outgoing branch instead uses ID 205 and animation 110097. The inspected
snapshot is `research/newclient20261030/combat/bluecg-virtual-memory.bin` in
the Magic Power project, SHA-256
`8babbe4ad20e4e1e2a6992ecf086d47ef3527426879699f83fa2cebb1a476afe`.

`summon.png` preserves the seven original frames and their ground origin.
The 400 ms source header quantizes to three 60 Hz updates per frame. Goemon
loops the frames for the incoming state's 51-update window at the native
spawn point. Hounds enter combat at their existing full size. The shared
audio pool plays one copy of the cue while a group of arrivals overlaps.

P now toggles the selected pack: queued or living companions are recalled;
otherwise the saved pack is queued. Successful recall plays the original ID 205
(`cgbtl04.wav`) once at the player through the same priority voice pool, including
canceled pending arrivals. Empty packs, key release/repeat and paused input stay
silent. H remains the separate return/follow order. The recovery command above
records both switch sounds' source WAV hashes and verifies unchanged PCM against
`motions.json`. Prepared WAV containers omit archive metadata; samples are exact.

The archived Purgatory artwork has seven unreadable frame records in direction
5. Its six run frames use the neighboring original view and its first attack
frame uses the next readable original frame in the same clip. The original
clip durations and cue times still apply. The source substitutions are listed
in `motions.json`.

The runtime resolves the camera-facing source direction and frame in the
existing spatial batches. One shared indexed atlas uses 22 R8 layers
(88 MiB), plus the frame lookup and palette. The native snapshot carries
each living body's stable color and animation clock. The existing corpse
pool plays the source fall with the same color after retirement.

The effect comparison and rendered game checks are under
`build/Other Files/Asset Toolkit/Cross Gate Hounds/`.

## Shared loadout bank

`../guard_pets/` composes these unchanged hound atlas pages with the mantises
through the existing renderer and native guard lifecycle (historical native kind
19). `scripts/forest/pet_catalog.gd` owns stable source keys, prepared portraits
and the five-slot limit. `tools/recover_crossgate_mantises.py` rebuilds the composed
lookup and palette without rewriting this directory. See `../mantises/README.md`
for the inventory, exact archive keys and recovery limits.

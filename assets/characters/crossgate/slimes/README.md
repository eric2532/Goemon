# Cross Gate slimes

**Play Goemon** opens the editable game in slime test mode with Kazi
selected. The explicit flag also works with development fixtures:

```sh
"/Users/eric/Desktop/Play Goemon.command" -- --crossgate-pet-test
```

Start Battle queues one pack at each of the four Wind Meadow castle
exits. Each pack has all 29 appearances. The next 116 slimes are due
every ten seconds, including while earlier waves are fighting. Arrivals
are placed up to three per side per world tick on clear, reachable
ground. At the 240-enemy cap, any remaining arrivals wait for space.
Team XP and pet upgrades carry across waves. The regular roster and
its reinforcements stay out of this mode.
**Settings → Enemy Balance → Slime** edits the shared HP, damage and
movement speed.
Defaults are 5,000 HP, 30 damage per hit and 3.0 m/s. The test uses
these values directly.

The preserved Blue Cross Gate client supplies 2,312 clips and 19,768
frame records. `motions.json` maps every sprite ID to its archive record
and stores each clip's frame count, duration and cues. The indexed atlases
retain source colors and relative frame offsets. The runtime scales the
original 1.8 m sprite fit by three to match the 5.4 m shared combat body.
The original artwork and source client are read only.

Live melee uses the original idle, walk, run, attack, hurt and fall
artwork. The source impact cue drives one native damage check per attack.
Start/stop transitions and cast are also packed for later use. Guard is now
live: the native arena kit uses source action 9 (table slot 9), transferred
as sprite wire clip 6 by both render packers. The shared shader resolves that
slot only for the ten-action slime atlas; six-action cave/pet sheets retain
their original mapping. No source pixels or timing tables were changed.
Milky Slime has no after-run clip in this archive. Its cast cue is the
fifth recovered WAV. It plays on the source cast timeline and is stored
alongside the four WAVs used by live melee.

The slime atlas uses 16 shared R8 layers, or 64 MiB of index pixels.
The game loads it during setup in slime test mode and reuses the native
spatial sprite batches, corpse pool and spatial voices.

```sh
python3 tools/recover_crossgate_slimes.py '/Users/eric/Desktop/Projects_Codex/Magic Power'
```

The extractor checks the indexed pixels and source PCM hashes. The
desktop combat fixture and captures are under
`build/Other Files/Asset Toolkit/Cross Gate Slimes/`.

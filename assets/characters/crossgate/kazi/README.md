# Kazi / Blue Cross Gate #102488

This folder preserves the recovered original art. The live character now uses
the separate illustrated derivative in `../kazi_hd/`; the original runtime and
measurement notes below document the initial port.

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
There is no runtime extraction, retargeter or per-attack loading/material creation.

`scripts/crossgate_combat.gd` specializes the existing recovered-enemy player
adapter. Shared exact segment contact, bounded native candidate query, cover
checks, hit history, damage attribution and cancellation remain authoritative.
LMB and RMB perform the same .6-second original sword gesture. Port balance is
33 base damage, 3 m segment, .42 m contact radius, and contact at 5/11 of the
gesture. Server hit timing and original BlueCG balance are unverified; these are
explicit Goemon adapters. Jump/dodge, selection, progression, shared spells and
health use Hero. This adds no ordinary enemy wave type or automatic wave count.
The native mirror validation accepts kind 134 for Kazi, through the same owner.

Original swing sound 103 (`cgply01a.wav`) plays at source attack frames 3/7;
direction 0 contains only frame 3. The cue list is captured at attack start,
so orbiting the camera cannot duplicate cues. Confirmed hits use recovered
Cross Gate generic physical impact 255 (`cgefc04.wav`). Kazi-specific server
impact selection remains unverified; this impact mapping is a Goemon adapter.
Both samples are prepared through SoundLibrary and its existing bounded voices,
recording/gain/mute controls and nearby-ally filter. A miss produces swings only;
dodge, focus loss and selection cancel pending cues with the existing attack.
Walking uses Goemon's prepared footsteps, as does every shared footstep fallback.
The old prototype `audio/step.wav` is excluded from gameplay/default previews.
PCM hashes and source provenance are in `assets/audio/crossgate/kazi/provenance.json`.
Recovery checks exact sample PCM and does not synthesize replacement sounds.

The source contains 19 actions / 152 directional clips in total. This game
bundles the seven gameplay actions above; throw, defend, sit, wave, happy, angry,
sad, shake, rock, scissors, paper and fish remain in the preserved source.
No 16-direction or interpolated 3D views were found in this sprite record.

Run `Play Goemon.command`, open the fighter gallery with Q and select Kazi.
WASD moves, Shift sprints, LMB/RMB attacks, Space jumps and C evades. Shared
skills can be equipped through the existing Skills & Jump menu.

Focused checks and a paired standard-army benchmark live in
`tests/forest-shrine/crossgate_kazi_test.gd` and `crossgate_kazi_benchmark.gd`.
Reports and reviewed captures are under `build/Other Files/Cross Gate 102488/`;
performance interpretation is in `docs/goemon-performance-guide.md`.

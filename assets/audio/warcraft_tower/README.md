# Warcraft III Guard Tower audio

Four byte-for-byte WAVs recovered from the existing local Warcraft project at
`/Users/eric/Desktop/Projects_Codex/Warcraft`. `source.json` records archive paths,
file/PCM hashes, original sound-table rows and the model/table evidence hashes.
The original archives and models remain untouched.

The patched `Units/HumanUnitFunc.txt` entry `hgtw` selects
`Abilities/Weapons/GuardTowerMissile/GuardTowerMissile.mdl`. Its original MDX
contains `SNDXKGUA` and `SNDXMARR`. `AnimLookups.slk` resolves these to
`GuardTowerAttack` and `ArrowHit`; `AnimSounds.slk` selects the three
`GuardTowerMissileLaunch*.wav` files and **ArrowImpact.wav**. The similarly named
`GuardTowerMissileHit*.wav` family is not this missile's selected contact cue.

Recovery used the source project's existing `work/mpq.py` / StormLib reader,
searching `War3Patch.mpq`, `War3xlocal.mpq`, `War3x.mpq`, then `war3.mpq`.
All four selected WAVs come from `war3.mpq`. Re-extract the `samples[].path`
entries in `source.json` through `MPQ.read` and verify each SHA-256 before
replacing anything. No download, conversion, normalization or trimming is needed.
Godot imports use uncompressed 22,050 Hz mono PCM16 to preserve the samples.

`forest_tower_arrows.gd` prepares these through `character_audio_bank.gd` once,
then reuses the existing 28-voice SFX pool and overlap limit. Launch variations
use the existing randomizer. Arrival alone plays the impact, at original pitch
with the pool's small pitch variation. Existing visibility, recording, pause and
master-volume behavior remains. Ranger sounds and recordings are independent.
The superseded bow source files remain preserved with their original provenance.

Verify through the desktop launcher:

```sh
"/Users/eric/Desktop/Play Goemon.command" --resolution 1280x800 --script res://tests/forest-shrine/bow_source_audio_test.gd
```

This checks exact imported PCM, all three variations, actual launch/arrival,
recording/visibility/mute/pause, overlap limiting, sixty repeated shots with no
retained resources, and Ranger recordings/previews. Reports belong under
`build/Other Files/Asset Toolkit/Warcraft/Tower Audio/`.

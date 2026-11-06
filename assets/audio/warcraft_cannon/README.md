# Human Cannon Tower sounds

Recovered byte-for-byte from the user's adjacent Warcraft project. `source.json`
records original archive paths, sound-table rows, WAV/PCM hashes and model events.
Read with the existing `../Warcraft/work/mpq.py` StormLib reader, in order:
War3Patch, War3xlocal, War3x, war3. No executable, transcoding or normalization.

The patched `hctw` unit selects CannonTowerMissile and HumanTower's `upgrade,second`
form. Missile events `KCAN` and `MCAN` resolve through AnimLookups/AnimSounds to
three **CannonTowerMissileLaunch** variants and three **CannonTowerMissile** impact
variants. `CannonTowerWhat1` is the unit selection cue. The tower's `DHLS` event
selects **BuildingDeathSmallHuman**, not the similarly named large-building cue.
All twelve selected files retain their exact original PCM and sample rates:

- Three firing cues and three explosion cues.
- Cannon selection, Human small-building death and Human cancel/removal.
- Shared placement, Human completion and original construction sound.

The six combat clips use the existing 28-voice SFX pool. Selection, completion,
destruction and removal reuse the four-voice placement pool. Placement already
uses the same original file in `warcraft_building/`; its recovered duplicate is
retained here for the complete provenance set. The construction sample is
preserved but not looped: current Goemon buildings complete instantly. Worker
repairing retains the existing Peasant hammer samples and timing.

As of 2026-10-30, every successful building purchase plays the same original
`PeasantBuildingComplete1` ("Job's done") with its placement cue. A dragged wall
plays this pair once for the whole purchase. Rejected purchases, recording,
muting and explicit pause stay silent. Worker staffing is automatic; preparation
inspection offers repair/removal without manual worker-assignment controls.

Preparation and battle respect pause, master volume, recording and visibility.
Resources/randomizers are prepared once; no audio is loaded during firing.
`tests/forest-shrine/human_cannon_tower_test.gd` verifies all files and imported PCM,
variants, playback, worker firing and bounded repeated use. Recovery workbench,
archive evidence and reports: `build/Other Files/Asset Toolkit/Human Cannon Tower/`.

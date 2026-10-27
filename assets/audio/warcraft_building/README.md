# Building placement

`BuildingPlacement.wav` is the original Warcraft III sample from
`war3.mpq:Sound\Buildings\Shared\BuildingPlacement.wav`. The patched archive
lookup selects `War3x.mpq:UI\SoundInfo\UISounds.slk`, whose
`PlaceBuildingDefault` row points to this file. `source.json` records both source
hashes, the complete row, and the WAV/PCM hashes. Extraction uses the existing
`../Warcraft/work/mpq.py` StormLib reader, checking patch, expansion-local,
expansion, then base archives. The WAV is byte-for-byte unchanged.

Goemon plays one cue after successful construction: towers, barracks, mines,
walls, gates, shrines and enemy castles. A dragged wall line plays once for the
batch. Previews and rejected placements stay silent. The existing four-voice
construction pool preserves pitch and follows game volume, pause and recording
suppression. Ongoing worker repair/build hammering retains the separate Peasant
samples. No game executable is launched during recovery.

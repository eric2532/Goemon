# Frost Dragon opening roar

`roar.wav` preserves retail event `B37` from Brave Fencer Musashi's Frost Dragon
encounter: `SC04/FILE_011`, bank slot 51, sample 20, two source-pitched layers.
The opening handler calls it at `0x8018715C` after enabling the boss HP display.
`sources.json` records the original bank, tone records, source hashes and limits.
This is dry recovered audio; PSX ADSR and reverb are not emulated.

Rebuild with `python3 tools/recover_frost_dragon_audio.py`. The complete bank and
event catalog remain under `build/Other Files/Asset Toolkit/Dragoon Frost Dragon Audio/`.
Gameplay uses it as Dragoon's Dragon Leap voice on actual landing, alongside the
existing impact. Sound Studio's Dragon Leap Voice recording, gain, mute and
Restore default control it. Native allied landings share the spatial voice pool
and its existing overlap throttle. No combat or animation timing is changed.

User follow-up: keep B37 for landing. Its voice and the existing landing impact
now play at 80% of their previous gain, multiplied by the saved user controls.

The user selected preview **08** (`BA9`, three sample-6 layers with a deeper
ending) for the ground attack. `ground_attack.wav` matches that approved preview
byte for byte, including its .4 peak headroom; `ground_attack_sources.json`
preserves its original records, pitch curves, delays and selection hash.
Rebuild both cues with the same recovery command above.

The hunting cue plays once at the first follow-up pulse (.26 s after landing),
during the opening hunting pass. Player and native allies reuse their existing
voice pools and pulse delivery. Sound Studio exposes **Hunting dragon · ground
attack** with independent recording, gain, mute and Restore default controls.
Landing still uses B37 and its existing .8 gain. Damage, pulse times, travel,
dragon size and lifetime are unchanged.

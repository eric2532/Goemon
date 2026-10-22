# Sasuke original ROM audio

Recovered from the supplied Mystical Ninja Starring Goemon USA ROM, SHA256 `1603be37427a33548857fc3d2e8867ede71121c353fb631b79b44f1d94845d80`. The 47 stereo 44,100 Hz PCM files preserve the original samples, source sequencer pitch, envelopes, delays and random voice choices. This is dry event reconstruction; original RSP interpolation/filtering and console room reverb are not emulated. No replacement sound was synthesized.

The original MIPS character sound dispatcher, random group lookup, native sound curves, release guards, charge thresholds and collision receipts were executed to establish the mappings. All 47 WAV hashes and 41 sequencer traces are recorded in `provenance.json` and `control_trace_hashes.json`. Thirty-five used ADPCM waveforms were independently compared with the Nintendo SDK decoder: maximum difference one PCM value from the SDK clamp convention.

| Action | Verified native events |
| --- | --- |
| Jump | 21F plus weighted voice 38B / 38C / 38C |
| Landing / hard landing | 220 / 218 |
| Hurt / death | 388 / original 392 or 38A choice |
| Gold kunai | Entry voices 387 / silence / 393; weapon 210 at frame 2, 210 at 6, 218 + 211 at 7 |
| Gold kunai contact | Tier 3 initializer class 24 selects victim event 221 |
| Firecracker release | 387 + 20B at source frame 4 |
| Firecracker contact / detonation | Victim 24F / projectile 104 |
| Ice / charged Hail Beam release | 393 + 103 at source frame 8 / 9; airborne charged release at 8 |
| Ice contact | Victim 221 |
| Held charge | 24C at 0.5 seconds; 24D at 1.5, 24E at 2.5, alternating each second |
| Hair attack / contact | 213 / victim 24F; no added voice |
| Jetpack entry | 21F + finite 14F + voice 394 |

The jetpack weapon event and voice use separate playback ownership. Landing, switching or cancellation stops its finite 14F weapon layer while the original voice tail can finish. Primary voices play once at native entry; weapon cues do not duplicate them. Shared contact feedback suppresses its generic sounds for Sasuke so only the verified source receipt plays. Source-silent actions and adaptation-only evade/footstep/environment slots stay silent. Shared pickup/orb effects retain their game behavior.

Sasuke uses recovered originals as his defaults, following the Goemon policy. Recording files remain preserved; gain and mute controls apply to the actual named moves and native event slots. The runtime mapping is `scripts/recovered_sasuke_audio.gd`. Full recovery scripts, original event renders, SDK comparisons and executable source proofs remain in the primary project at `build/Other Files/Sasuke ROM Recovery/Audio/`.

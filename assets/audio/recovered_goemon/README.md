# Mystical Ninja Starring Goemon — user ROM audio recovery

These files come from the user's verified USA cartridge ROM, identified in `provenance.json`. No internet sound pack or newly generated replacement is used. Only Goemon (character ID 1) receives these defaults. Saved recording files and settings are preserved. Goemon playback bypasses recorded takes in favor of originals; gain/mute controls remain active. Other characters retain their recording precedence.

The source N64 MIPS audio sequencer was executed in Unicorn, including its event commands, pitch curves, ADSR updates, random modulation, note retriggers, and delays. Its `alSynStartVoice`, `alSynSetPitch`, `alSynSetVol`, `alSynSetPan`, and stop calls were captured. Audio is decoded from each original ADPCM block using its original predictor coefficients. An independent build of the SDK decoder agrees on all 437 complete music/SFX/voice samples; the only differences are the SDK tool's -32767 clamp versus this decoder's -32768 clamp (at most one PCM unit). The AIFC export utility writes an incorrect PCM-style frame count for ADPCM, so verification corrects that metadata to 16 decoded samples per 9-byte block before invoking the independent SDK decoder; all complete sample lengths are then asserted equal.

These are **dry event reconstructions**, not bit-exact emulator recordings. The offline renderer uses linear interpolation and equal-power panning; it does not emulate the RSP resampling filter or room reverb. Thus the original identity, playback pitch, note/envelope timing, and voice content are recovered, while the final console DSP differs. Full extraction scripts, raw ADPCM exports, event control traces, decoded candidates, and verification results remain in `build/Other Files/Goemon ROM Recovery/Audio` in the main workspace. `control_trace_hashes.json` identifies those traces.

## Source mapping

| Use | Original actor evidence | Sound events |
| --- | --- | --- |
| Jump | `801E20A0`, random group 1 through `801DD830`, normal jump index `0x21` through `801DD6E0` | `21D` + `379` or `37A` (weights 1:2) |
| Pipe combo 1 (basic / Gold Pipe) | actions `58` / `68`, ROM event curve channels 0 and 1, frame 3 | `217` + `20B` |
| Pipe combo 2 (basic / Gold Pipe) | actions `59` / `69`, channel 1 only, frame 4 | `20C` |
| Pipe combo 3 (basic / Gold Pipe) | actions `5A` / `6A`, channels 0 and 1, frame 6 | `217` + `20D` |
| Confirmed enemy contact | shared victim callback `8021AB18`, attacker classes `15/16/17`, receipt `victim Task+38` | `24F` |
| Coin and chain enemy contact | coin initializer `801E8F50`: normal selector `1` class `1F`, charged selector `12` class `1B`; chain initializer `801E9AE0`: head and eight subsegments class `15`; same victim callback `8021AB18` | `24F` |
| Coin charge | `801DC27C`, held B bit`4000`; auxiliary+`36` reaches15 (0.5s at30Hz), full charge60 (2s) | `24C` at tick15; no charging voice |
| Charge sustain | effect `801EC860`, effect tick30/60/90/etc while charge state1/2 (roughly held1.5s/2.5s/3.5s/etc) | alternating `24D` / `24E`; release states0/3 suppress retriggers |
| Charged coin release | charge return3 stored auxiliary+`68` at `801CB970`; selects `7F/80/81`, `801F50A4` at frame4.5 | `15A` + random group6; no normal preparation pair |
| Charged coin contact burst | charged projectile update `801ECCF0`, receipt at projectile+`34`, sound call `801ECE14`; victim callback independently emits `24F` | projectile `29A` plus victim `24F` |
| Coin preparation | `801E2950`, attack entry | `20E` + `24B` |
| Coin voice | `801F50A4`, release frame 4.5, random group 6 | `37B`, `376`, `372` |
| Charged coin supplemental sound | selector `12`, three-coin cost | `15A` |
| Chain release | `801F4984`, last-frame threshold 5 | `205` + `20B` |
| Chain voice | random group 4 | `381`, `37C`, `371` |
| Golden transformation | Goemon case in `801E75D4`, call at `801E7658`; action `82` | `173`: SFX bank 1 instruments 7 and 46; voice bank 2 instrument 42 |

`Audio/verify_gold_pipe_audio.py` executes all frames of the original basic (`58/59/5A`) and Gold Pipe (`68/69/6A`) actor sound prefixes, including `801DD720`, the full channel evaluator `80032B20`, bitstream decoder `80034268`, and character sound lookup `801DD6E0`. The six actions resolve the same Goemon sound groups `1/2/3`, event IDs, and frames `3/4/6`; Gold Pipe has no separate upgraded swoosh. Its `6B/6C/6D` recovery rows have no sound-event header and their original handlers execute silently. This prefix check excludes the collision initializer and therefore establishes swing cues only; the initializer voices are verified below. `gold_pipe_audio_verification.json`, embedded in the manifest, records this proof. The existing `pipe_1/2/3.wav` files therefore apply to Gold Pipe unchanged.

`Audio/verify_charge_sustain.py` executes96 effect-state/actor/counter cases, establishing the alternating `24D/24E` sustain cues at one-second intervals beginning one second after effect creation. The three visual actors issue the same event together; executing the original audio queue with three requests produces a control trace identical to one request for each event (`charge_sustain_queue_verification.json`). Playback therefore emits one cue per interval, and cancellation stops future retriggers while the finite event tail completes.

`Audio/verify_attack_voice_charge.py` also executes eight native held/released charge cases. The charge leaves the current idle/locomotion action active while spawning charge effect selector`11`; the charged throw is a later action, rather than an invented hold animation. Applying this source charge only during current Super Goemon is a gameplay binding adaptation. The internal asset name `triple_coin.wav` refers to the three-coin-cost release event; it does not establish three simultaneous projectiles. Event `24C` is finite (2.045 seconds) and the native charge function makes no stop-sound call when released, so its source tail continues. The proof also checks three charged-release variants below/at frame4.5 and repeated updates: exactly one group6 voice and event `15A`.

The current RMB heavy strike uses the recovered third pipe motion and its `pipe_3` sound. Current chain sweep/fire moves reuse the recovered chain release when that same source animation is selected; those bindings are adaptations.

Pipe entry voices come from `801E3834`, called by the attack entry, through `801E3A74` and table `802046D4`. First strike (basic index0 / Gold index10) uses random group4: events `381/37C/371`. Second strike (index1/11) uses group0 and is silent. Finisher (index2/12) uses group6: `37B/376/372`. These are shared native voice events also used by chain and coin attacks. Voice begins at action entry, ahead of the swing cue. The earlier prefix-only proof stubbed the collision initializer and incorrectly concluded all pipe entries were silent; `Audio/verify_attack_voice_charge.py` corrects that omission by executing the full initializer, random group lookup, and character sound lookup for all18 variant cases. The transformation's voice begins 0.55 seconds after its event trigger, following the original event script; this delay is retained in `golden_voice.wav`. Its effects begin at 0.28 seconds. The split weapon/voice files preserve independent recording controls. `golden_complete.wav` is supplied for the complete legacy event. The original generic victim callback is used by hurt-state entries in zero-based overlay files `0031`, `0032`, and `0037`. Executing that original callback verifies silence without a collision receipt and event `24F` for all three Goemon pipe attack classes (`15/16/17`). It selects `221` for other attack classes (`19/1A/23/24`), so that sound is not mislabeled as Goemon pipe contact. `Audio/verify_contact_audio.py` and `contact_audio_verification.json` preserve eight executable proof cases: no receipt, three Goemon attack tiers, and four other attack classes. The result is also embedded in `provenance.json`.

`Audio/verify_projectile_contact.py` supplies four further executable proof cases. Original dispatcher `801E8964` routes normal coin selector `1` to `801E8F50`, charged selector `12` through `801ECCB8` to that same initializer, and chain selector `2` to `801E9AE0`. The coin initializer selects class `1F` or `1B` at `801E8FA4–801E8FB8` and passes it to `801EE228` at `801E90B0`. That helper writes its argument to `Task+4C` at `801EE238`. Chain head setup passes class `15` at `801E9DB0`; each of its eight subsegments passes `15` at `801E9FAC`. The script executes these class writes with fixture allocation/model/geometry calls, then executes the original victim contact callback for each head projectile. All select `24F`; none require the alternate event `221`. `projectile_contact_verification.json` records the results and is embedded in the manifest.

`Audio/verify_charged_coin_contact.py` executes four original charged-projectile cases and the victim callback: an enemy receipt produces projectile event `29A` plus victim event `24F`; lifetime expiry produces neither projectile burst. Without an enemy, the same projectile burst occurs only when its world-query result is `7FFF`; the opposite branch is silent. The exact world-query behavior is recorded without assuming every terrain hit should emit it. Current charged-coin entity contacts add `charged_coin_burst.wav` once per projectile through the audio helper.

The current game applies the verified `24F` contact policy to its own enemies; this target binding is an adaptation. Pipe, normal/heavy coin, and chain contacts share the same recovered event, preserving the source policy without an invented heavier sound. Unsupported current-game moves and unverified environment impacts retain existing defaults.

The original bank initialization at ROM `0x6EE40` confirms CTL/TBL pairs:

- music: `0x7EC20` / `0x973C0` (134 instruments; instrument 21 is also used by chain event `205`)
- SFX: `0x86B10` / `0x1AB460` (79 instruments)
- voices: `0x8B400` / `0x2537E0` (224 instruments)

Each WAV's manifest records event IDs, sample ROM addresses, raw ADPCM SHA-256, loops, duration, and any mix gain. Audio is stereo 44,100 Hz, signed 16-bit PCM. Runtime pitch must stay 1.0 because source pitch is baked into these renders.

Primary references used to interpret the user ROM:

- [klorfmorf/mnsg](https://github.com/klorfmorf/mnsg): USA segment layout and included libultra data structures.
- [klorfmorf/Goemon64Recomp](https://github.com/klorfmorf/Goemon64Recomp): original sound-player structure and audio callback interval (`patches/sound.c`).
- [jsdf/n64soundtools](https://github.com/jsdf/n64soundtools): independent CTL/TBL parsing and AIFC export.
- [n64decomp/sdk-tools](https://github.com/n64decomp/sdk-tools): independent SDK VADPCM decoder used for comparison.

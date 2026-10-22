# Dragoon landing strike audio — 2026-10-17

The user-supplied [Landing Sound Effects clip by Celestial SFX](https://www.youtube.com/watch?v=FW4tiK_N9kc) contains six separated impacts. The fourth (6.465–7.31 seconds) supplies the body/ground landing layer.

Dragon Leap now plays one composite on actual floor contact:

- New landing impact, offset 0 ms, gain 1.0.
- Existing `thrust-dragoon-2.wav` spear piercing impact, offset 8 ms, gain .65.
- Existing `sweep-dragoon.wav` lance attack, offset 16 ms, gain .45.

The result is 0.845 seconds, stereo 48 kHz PCM16, peak normalized to −7.5 dBFS with short click-prevention fades. There are no clipped samples. Normal pitch keeps the spear transient crisp. The strike plays once even when landing on empty ground; delayed shockwave damage pulses do not replay it. Descent/cancellation remain silent. Damage, collision, animation, range, timing, regular jumps and the grounded right-click sweep are unchanged.

Sound Studio's **Dragon Leap (airborne)** weapon preview uses the new composite. Existing custom recordings, gains, mutes and paired voices retain their normal routing. Both the regular game and painterly preview include the update; previous app bundles are retained as **Before Dragoon Landing Audio** copies.

Assets: `assets/rogue/audio/landing-dragoon.wav` (selected impact), `landing-strike-dragoon.wav` (game composite), `dragoon_landing.source.json` (exact source windows, layer gains, offsets and hashes). Rebuild with `python3 tools/build_dragoon_landing_audio.py /path/to/landing-source.wav`. Existing spear source attribution remains in `dragoon_spear.source.json`.

Validation evidence is in the original checkout's `build/Other Files/dragoon-landing-audio-20261017/`: 14 real-floor audio checks passed headlessly and natively, including custom takes, cancellation, no aerial trigger and no pulse replay. WAV validation confirms format, fades, conservative peaks and no clipping. Independent review reconstructed the mix sample-for-sample and found no important issues.

Legacy test limitations were also checked against the unchanged game: `lance_audio_test.gd` has three old fixed pre-contact timing assertions; `flight_test.gd`, `repeat_test.gd`, `sweep_test.gd`, and Dragoon's animation `gameplay_test.gd` assume flat ground at z=70, now inside the Twin Ramparts ramp. Their raw failures reproduce identically before this audio change. `baseline-regressions.json` records exact assertions. A temporary runner supplies the protected Original Map for the flight/repeat/sweep checks, without changing gameplay or user maps; results are in `flat-map-regressions.json`. Bow audio and painterly preservation checks also pass.

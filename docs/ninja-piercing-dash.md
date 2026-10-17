# Ninja movement and piercing Shadow Cut

Ninja now shares Explorer's authored run, jump ascent, falling and landing body poses. Ninja's existing speeds, jump strengths, air steering and double-jump controller remain in effect, including per-character balance overrides. Ninja keeps its custom idle, enlarged purple-handled blade, local weapon-to-hand grips, authored RMB start/finish poses, and tucked second jump. Landing poses take priority over idle after a real airborne interval; idle resumes after recovery.

Shadow Cut's route remains .42 seconds at 27m/s (11.34m when unobstructed), using native player collisions. Damage now sweeps a 3D volume along every travelled segment against the enemies' actual fitted shapes. Skipped frames cannot leave holes in the path. Each enemy can take 76 base damage once during travel. At the actual endpoint, a separate forward cut reaches 3.6m with width1.35m before range/reach scaling and deals another76 base damage once. An enemy touched by both phases takes both. The two phases use one cast ticket and one attack-chain link; neither counts toward Ninja's three-basic-hit cooldown refresh. Fog, cover, damage modifiers and criticals still apply. A cancelled dash cannot deliver its pending final hit. Accepted contacts do not freeze the travelling character.

The finishing cut now has a saturated purple upright crescent at the endpoint and a violet capsule footprint matching the finishing segment and radius. Its edge fades over .38 seconds and its footprint outline lasts .5 seconds, staying at the impact location rather than following Ninja. The cue appears at the existing instant of damage; it adds no persistent damage or delay. Its scale follows melee reach, with subdued glow under reduced-flash settings. The original custom finish pose recovers as before. Explorer's own RMB is unchanged.

## Bow source selection

User source: [Sound arrow effect, Volk Mark](https://www.youtube.com/watch?v=_1GYa-CG-cU), decoded length4.714s. Five silence-separated effects were extracted, all used:

| Source effect | Source seconds | Use |
| --- | --- | --- |
| 1 | .420–.925 | Ranger power shot |
| 2 | 1.390–1.745 | Ranger regular release1 |
| 3 | 2.255–2.660 | Ranger regular release2 |
| 4 | 3.160–3.625 | Tower release1 |
| 5 | 4.160–4.590 | Tower release2 |

Trimmed tails, pitch-preserving tempo adjustment,90Hz high-pass, short fades and conservative normalization keep rapid shots clear. Ranger's first two regular releases alternate, followed by the power release on the third shot; empowered power arrows use the power release. Towers alternate their two quieter effects without inheriting the player's Sound Studio overrides. Existing custom Ranger recordings, per-move controls and previews remain supported. Samurai and enemy archer fallback sounds are unchanged.

Rebuild assets with `python3 tools/build_bow_source_audio.py /path/to/bow-source.wav`. Exact source cuts, processing, peaks, hashes and provenance are recorded in `assets/rogue/audio/bow_source.source.json`.

## Verification

`ninja_pierce_finish_test.gd` covers multi-target travel, repeat suppression, separate endpoint damage, double contact, rear/range/cover/fog rejection, cancellation, chain attribution, shared takeoff/fall/run, actual stationary landing bone transforms, return to custom idle and a complete physical dash. `--visual` captures native views.

`bow_source_audio_test.gd` exercises actual Ranger and tower audio pools, the third-shot selection, Sound Studio previews and custom recording priority. Regressions include authored Ninja poses/gameplay, three-hit refresh, hit-only drift, melee reach/response, low-fidelity enemies and held Knight guard. Evidence and rebuilt-app verification are under `build/Other Files/bow-ninja-dash-20261017/`.

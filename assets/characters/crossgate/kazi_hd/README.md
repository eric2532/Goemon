# Archived illustrated Kazi

The user canceled this upgrade and restored the original Blue CG art on
2026-11-06. The live character and portraits use `../kazi/`. This folder is
excluded from imports/exports; do not reactivate it without a new user request.
The notes below describe the retired illustrated implementation.

Playable ID 34 uses the user's approved illustrated concept across stand, walk,
run, attack, cast, hurt and fall in eight directions: NW, N, NE, E, SE, S, SW, W.
The 56 clips retain all 872 frame slots, original clip durations and recovered
sword sound markers. This is newly illustrated artwork; original pixel art is
preserved separately in `../kazi/`.

The current revision lengthens the same slim curved blade throughout all clips.
Run sheets use forward heel plants, backward stance travel and restrained bob.
The contact revision is saved in `revisions/run-contact/` in the reference folder.
Offline stance-height calibration uses one body ruler across all eight views:
166 prepared pixels standing/walking and 148 in the crouched running stance.
Hair/profile width never controls scale; individual poses retain their movement
without per-frame resizing.
Per-row registration removes sheet baseline drift; the fallen body settles onto
the floor during its final poses. These corrections run in the offline baker.

Editable identity/sprite-sheet masters and generation records live in
`assets/references/crossgate_kazi_hd/`, excluded from imports and game exports.
Read that folder's AGENTS.md before editing. Built-in ImageGen produced the
illustrations; the offline baker registers body/feet, crops transparent margins,
resamples to twice the original body resolution and packs shared atlases. Never
paint these derivatives. Correct a master and run:

```sh
python3 tools/prepare_crossgate_kazi_hd.py bake
```

`bake --pilot` stages available masters under the HD Preview report folder;
normal baking refuses an incomplete 56-clip set. `motions.json` retains master,
texture and original-motion hashes. The existing full-body gallery portrait and
circular HUD use separate crops of the approved concept.

The existing Sprite3D and native pooled hero bodies share one prepared texture
set. Only frame region/offset changes during play. The standing body is 166
prepared pixels at Goemon's 3.2206185 m reference height. Walk/run advance from
actual travelled distance (two metres per walk cycle; 4.7 metres per illustrated
run cycle, calibrated from side-view boot travel), preserve normalized phase on turns/speed changes and
emit two footfalls per grounded stride through the existing Goemon sample and
voice pool. Shared casting starts at frame zero. Movement, collisions, contact,
damage, reach, cancellation and original attack audio retain their controllers.
The shared landing fallback also uses Goemon's prepared sample; recovered special
character audio and user recordings/gain/mute overrides retain priority.

The illustrated textures cost more memory than the original pixel art; consult
the current manifest's `texel_bytes` and the fresh foreground measurements in
`docs/goemon-performance-guide.md`. These are shared once, not copied per ally.
Evidence and animation reviews live under
`build/Other Files/Cross Gate 102488/HD Preview/`. Use Play Goemon to run current
source; no app export is needed for iteration.

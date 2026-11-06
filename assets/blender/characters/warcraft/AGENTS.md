# Recovered Warcraft playable characters

The user's October 25 request uses the original Warcraft characters, not cosplay.
The authoritative editable masters remain in the adjacent Warcraft project:

- `/Users/eric/Desktop/Projects_Codex/Warcraft/assets/Blademaster/Blademaster.blend`
- `/Users/eric/Desktop/Projects_Codex/Warcraft/assets/Illidan/Illidan.blend`

Illidan replaces Demon Hunter in stable slot 32 (2026-10-25). Preserve the
`demon-hunter` asset/skill keys for saved settings. The previous DemonHunter
master remains intact in Warcraft. Illidan's package README documents the
native 24-action master and the export-only 0.9-second melee preparation.
Export only this replacement with the command below followed by `-- Illidan`.

Read each package's README.md before editing. Preserve packed textures, native
rigs, all actions, geoset opacity properties, billboard constraints and particle
properties. Export the main master, never a showcase or portrait file.
Do not rebuild the importer over authored edits or save into these masters from
Goemon's exporter. This folder points to the existing masters to avoid divergent
editable copies.

From the complete Goemon source:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/export_warcraft_characters.py
```

The exporter reads saved edits without saving the master, verifies its SHA-256,
and writes GLBs to `assets/models/characters/warcraft/`. Custom-property material
opacity and prepared particles are sampled at 30 Hz into each character's
`assets/characters/warcraft/<name>/motion.json`. Original WAVs are copied without
resampling. Original archives, portrait actions and showcase remain in Warcraft.

Run the audit, optimize both `warcraft-blademaster` and `warcraft-demon-hunter`,
refresh imports, run `tests/asset-toolkit/warcraft.gd`, and inspect the toolkit's
rendered comparisons before activating those two candidates. Every named
Geoset is protected because body/form/effect visibility uses it independently.
After activation refresh imports, render selection portraits with
`Play Goemon.command --script res://tools/capture_playable_enemy_portraits.gd -- 31 32`,
run the same test with `-- --packed`, run
`python3 tools/goemon_assets.py check`, and use the desktop launcher to run
`tests/forest-shrine/warcraft_characters_test.gd`. Full commands and controls:
`docs/recovered-warcraft.md`. No app export is needed for development.


Mirror Image additionally uses the generated native ally atlas
`assets/characters/ally_crowd/31.res`. After changing its model, motion sidecar,
billboard metadata or baker, run `tools/bake_warcraft_allies.gd` with headless
Godot and run `tests/forest-shrine/army_warcraft_test.gd`. The latter verifies
source fingerprints and sampled original skin transforms / geoset opacity.
`tools/recover_warcraft_effects.py` copies source spell textures/emitter values
and records native billboard flags without modifying the Warcraft masters.
See the added-skills section of `docs/recovered-warcraft.md` for reusable pieces
and the desktop skill fixture. Preserve the same native army/combat/pooling paths.

## Human Peasant workforce — 2026-10-26

The Human worker replaces the Goemon workforce visual. Its authoritative editable
masters are `Warcraft/assets/Peasant/Peasant.blend` and
`Peasant_Portrait.blend` in the adjacent Warcraft project. Read that package's
README and `assets/characters/warcraft/peasant/README.md` before editing. Preserve
all 22 body actions, four portrait actions, six geosets, weights and packed textures.
Export only this worker with `tools/export_warcraft_characters.py -- Peasant`
under Blender. Default export still selects the two playable heroes.

Audit, optimize/compare `warcraft-peasant`, refresh imports and run
`tests/asset-toolkit/warcraft.gd` before activation. After activation/import,
rebuild `tools/bake_warcraft_worker.gd`, run
`tests/asset-toolkit/warcraft_worker.gd`, capture `tools/capture_worker_portrait.gd`
through Play Goemon, refresh imports, run preservation and the desktop worker
fixture. This reuses the existing army pose texture format/shader, workforce
owner and four construction voices. No live skeleton or retargeter is needed.
Keep the Peasant's native hand, visible tower bow and shared projectile muzzle
consistent. Do not hide a whole body geoset to stow the axe: it is embedded in
Geoset_00 and bound to AxHandle01. Native Gold clips supply the sack.

## Illidan first-person hands — 2026-10-27

The separate player-only close-up sculpt is `illidan_hands.blend` in this folder.
It contains anatomical arms, palms, knuckles, tendons and claws, using the recovered
Chief finger-joint hierarchy with authored `Stand Alternate` / `Attack Alternate`
clips. The approved concept is `illidan_resting_reference.png`. Subsequent user
requests doubled the forearm/upper-arm thickness, then doubled palms, fingers and
claws. Keep those proportions and the natural resting wrists. The cast opens and
fans the fingers, extends the palms and recovers; the existing combat controller
still releases at .26 source seconds and owns damage/cooldowns.

Edit this saved master, then export it read-only with:

```
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/prepare_illidan_viewmodel.py
```

Run the `illidan-first-person` asset recipe, preservation/imported-motion and
rendered comparisons, then `tests/forest-shrine/illidan_shooter_test.gd` through
Play Goemon. Keep the two skinned mesh names, 30 finger joints, the Muzzle socket,
vertex colors, and both clips. No army bake is needed: this is a single camera
viewmodel using Chief's existing viewport and bob; the original world/army model
remains in the external Warcraft master. One-time sculpt scripts and captures are
in `build/Other Files/Asset Toolkit/Illidan Hands/`; never replay them over edits.

Follow-up, 2026-10-27: index, middle, ring and little fingers (including their
claws) are now 90% of their doubled length, retaining thickness. Palms, thumbs
and arm bulk remain enlarged. The casting thumbs spread another 20 degrees at
the base and extend another 8 degrees at the middle/tip joints; their idle and
recovery keys are unchanged. Preserve these latest proportions/poses. The source
before this adjustment is retained at `refs/codex/illidan-before-thumb-spread`.

Fuller palms follow-up, 2026-10-27: the user approved
`illidan_fuller_palms_reference.png`. The saved sculpt now fills out the palms,
blends them into the wrists, and tapers the oversized finger-base knuckles into
the existing finger shafts. Preserve the smoother silhouette and natural webbing;
do not restore the large round MCP lumps. The claws, rig, animation keys, skin
weights, topology and 33,094-triangle budget are unchanged. Source before this
sculpt is retained at `refs/codex/illidan-before-fuller-palms`; its one-time sculpt
script, preservation report and actual game captures are under
`build/Other Files/Asset Toolkit/Illidan Hands/Fuller Palms/`.

Finger-length follow-up, 2026-10-28: the user still found the fingers too long.
The four non-thumb finger chains and their claws are another 10% shorter than
the fuller-palm version (81% of the earlier doubled length). Keep their existing
thickness, fuller palms, thumbs and casting animation. The prepared mesh and
finger bind positions change together; the palm Muzzle socket stays unchanged.
The previous source is `refs/codex/illidan-before-second-finger-shortening`;
the guarded one-time edit and verification evidence are under
`build/Other Files/Asset Toolkit/Illidan Hands/Shorter Fingers/`.

Stronger fingers follow-up, 2026-10-28: the finger and claw cross-sections are
12% thicker, fading gently into the smooth finger bases. Preserve the shortened
lengths, fuller palms, rig, weights and authored poses; do not restore MCP lumps.
The previous source is `refs/codex/illidan-before-stronger-fingers`; the guarded
one-time sculpt and evidence are in
`build/Other Files/Asset Toolkit/Illidan Hands/Stronger Fingers/`.

Palm-girth follow-up, 2026-10-28: the palm and thumb-pad volume is up to 15%
deeper and 8% wider, fading into the wrist and finger roots. Preserve the smooth
bases, shorter/thicker fingers, claws, rig and casting keys. The previous source
is `refs/codex/illidan-before-palm-girth`; the guarded sculpt and evidence are in
`build/Other Files/Asset Toolkit/Illidan Hands/Fuller Palm Girth/`.

Nail/proportion follow-up, 2026-10-28: replace the broad pointed caps with thin,
curved dorsal nails whose inset roots blend from skin into dark keratin. Rounded
fingertip pads support the transition. All ten digit chains are another 10%
shorter; the palms are 10% narrower, with finger roots moved inward to match.
Keep finger thickness, palm depth, animation keys and the central Muzzle socket.
The two meshes/materials and 37 bones remain; the prepared detail is now 35,074
triangles. The previous source is `refs/codex/illidan-before-integrated-nails`;
the guarded authoring pass and evidence are under
`build/Other Files/Asset Toolkit/Illidan Hands/Integrated Nails/`.

Finger-root follow-up, 2026-10-28: the user found the palm/finger connection too
thin. The eight long-finger bases and neighboring webbing now flare smoothly
into the palm; sampled root radii are about 22–24% fuller. Preserve this connected
taper without separate round knuckle lumps. The latest lengths, nail geometry,
palm proportions, rig, weights and authored poses remain intact; there are still
35,074 triangles. The previous source is
`refs/codex/illidan-before-stronger-finger-roots`; the guarded sculpt and evidence
are in `build/Other Files/Asset Toolkit/Illidan Hands/Stronger Finger Roots/`.

Forearm follow-up, 2026-10-28: soften the faceted/cylindrical forearm surface
with rounded contours, a gentle muscle-to-wrist taper and oval cross-sections.
Preserve overall arm bulk and the completed hands/finger roots exactly. This is
an offline surface edit with the same 35,074 triangles, rig, weights and clips.
The previous source is `refs/codex/illidan-before-smoother-forearms`; the guarded
sculpt and evidence are in
`build/Other Files/Asset Toolkit/Illidan Hands/Smoother Forearms/`.

## Mountain King — 2026-10-30

Slot 33 uses the authoritative external `Warcraft/assets/MountainKing/MountainKing.blend`
and its separate portrait master. Read that package README before editing. Keep
all 27 body /10 portrait actions, eight body geosets, native bones and the animated
`avatar_skin` property: normal/Avatar are layers of the same geometry. Export
read-only with `tools/export_warcraft_characters.py -- MountainKing` under Blender;
default exports remain Blademaster/Illidan. Follow recipe `warcraft-mountain-king`
and the pipeline in `docs/recovered-warcraft.md`. The requested blue glow is baked into the saved master's packed texture
(2026-10-30 follow-up). Armor and clothes are also authored blue in both
body and portrait masters, including Avatar armor. Preserve the face/beard and
gold accents; original extracted textures remain untouched. Preserve authored blue;
do not restore a runtime-only tint. `tools/author_mountain_king_blue.py` records
geometry/UV/weight/rig/action preservation for that source edit.
Effect resources are prepared by `tools/recover_mountain_king_effects.cjs` and
`tools/bake_mountain_king_effects.gd`, never by per-character runtime retargeting.
The effect baker colors both additive energy and the hammer's opaque TeamColor00
layer blue (2026-11-05); preserve the original extracted red source texture and
sampled Birth/Death motion. Rebuild the effect resource instead of tinting casts.

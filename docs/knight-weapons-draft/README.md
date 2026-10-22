# Knight weapon and costume assets — review draft

The live game, current model sources, runtime scripts, and `build/Goemon.app` are untouched. This directory has `.gdignore`, so Godot will not import these review assets into the project.

The claymore follows the supplied reference: broad slate steel blade, raised central ridge, irregular gold inlays, heavy stepped gold guard, long steel grip, and gold pommel. The resting pose lowers his sword hand and angles the blade naturally outward and slightly back, with the wrist aligned to the actual hilt. Its cutting edge faces forward; its broad flat faces point left and right, so the front view shows its narrow edge rather than presenting its decorated side.

The wall shield is **10% smaller in width and height than the previous draft**, while the lion retains its physical size to reduce the empty space around the emblem. This follows the earlier 20% width reduction; final dimensions are 2.16× the current source width and 2.7× its height. Its rear grip is centered horizontally and vertically, so Goemon holds its middle. The crest is a **flat 2D painted gold lion sigil** informed by the latest supplied reference: symmetrical flowing mane strands, rounded ears, a strong face outline, and blue negative spaces around the eyes, nose, and muzzle. Its UV texture uses one gold tone and no embossed geometry, bevels, or relief shadows. The blue face, gold frame, and silver rim remain. The rim is a closed beveled shell with a practical handgrip.

Pose revision: the shield is centered on the hand at its lowered carry position. It sits at a slight angle at rest to keep his face visible. During the running preview, its face points outward to Knight's left and its width lies along his side. The sword is carried on his right, with its face turned outward and its tip leaning back. Both hands remain attached to their grips; the torso stays steady while the legs stride.

Costume revision: faceted silver boots and a long almost-black navy cape (`#080f28`). The cape extends from the shoulders to the ankles, about 32% longer than the original, with restrained dark blue folds. Boot material assignments change; the original body/face/hair geometry, UVs, weights, and bone lengths stay intact. Only the old cape component is replaced in the costume mesh.

Cape refinement: 30% wider across the hem, with more shoulder width, so its silhouette shows beside the body in the front view. Four editable cloth morph controls provide backward billow, independent left/right edge flutter, and hem sway. The shoulders stay pinned. Resting cloth moves gently; running cloth lifts and flutters more while his torso and weapon arms remain steady. Both Blender presentation sources contain the animation; the costume GLB preserves the morph controls for later integration.

## Review

- [Knight ready pose](ready-three-quarter.png)
- [Cape motion at rest](knight-idle-cape.gif)
- [Front](ready-front.png), [profile](ready-side.png), [back](ready-back.png)
- [Running animation](knight-running-carry.gif), [run front](run-front.png), [left side](run-side.png), [three-quarter](run-three-quarter.png)
- [Sword close-up](sword-closeup.png), [sword front](sword-front.png)
- [Shield front](shield-front.png), [shield back](shield-back.png)

## Editable sources and exports

- `knight-weapons.blend`: weapons only, separate editable mesh parts, packed textures, studio camera.
- `knight-ready-preview.blend`: unchanged Goemon body/hair geometry and skeleton, revised costume and weapons, resting pose, and 24-frame gentle cape animation.
- `knight-run-preview.blend`: editable 16-frame running presentation with steady weapon carry and torso, animated legs and fluttering cape, and packed textures.
- `knight-costume-draft.glb`: revised skinned character body/costume, including silver boots and long navy cape; weapons are separate exports.
- `knight-reference-claymore.glb`: standalone sword, batched `Weapon_Cutlass_Geometry` beneath `Weapon_Cutlass`.
- `knight-wall-shield.glb`: standalone shield, batched `Weapon_Pistol_Geometry` beneath `Weapon_Pistol`.
- `lion-sigil.svg`: editable flat vector lion artwork.
- `lion-shield-paint.png`: packed UV texture for the painted shield face.
- `reference-lion.png`: the user's supplied reference, retained unmodified.

GLB roots are at the hand grip origin. Blade length follows Blender +Z / glTF +Y. Editable weapon sources use separated display positions. Both sources embed their textures.

The poses and running animation are for asset review. No gameplay holding angle, attack range, damage, blocking behavior, or animation has been integrated. When integrating later, retain the existing global weapon scale and adapt the hand poses and physical reach to the new geometry.

## Reproduce and verify

From the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python docs/knight-weapons-draft/build_draft.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python docs/knight-weapons-draft/verify_draft.py
```

`verification.json` records actual dimensions, source geometry/UV/weight preservation, unchanged bone lengths, live-file hashes, saved-source checks, real palm-to-grip alignment, and independent GLB reimport validation.

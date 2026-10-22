# Original Sasuke

Source: Mystical Ninja Starring Goemon USA retail ROM. No retargeted rig, replacement body, remeshing, or recolored substitute weapon is used.

- Body: extracted file295/native file128, SHA256 `616cb13cc5ed6a3ca00f7ec4eeb93188fe33c47fa9e4a481129a98e62851a50f`.
- Face: file296, thirteen original expressions. The ROM's own initial/update functions801DAF54/801DB060/801DB1D4 generated every action's texture schedule for character index2.
- Static PIC: file297, decoded by original ROM80014D70/80014DD8 in MIPS Unicorn.
- Motion: file298, SHA256 `65d4b347d9d90195b2a4c9a5935f56e15e27c26a9507dbf848ac9683702deca8`. All156 clips and232 action rows at802005A0 are retained. The original parent hierarchy and native action playback rates are stored alongside composed world matrices. Translation divisor32, scale divisor256,1024 rotation units/turn,30 native frames/second.
- Gold tier3 kunai: original DL09002AA8 and09002BC8, selected by8020448C[2*3+2]->80204438. Native801E8078 binds shared file80 PIC801C from090044F0 to segmentD and restores Sasuke's segment9. Generated linear texture coordinates use original vertex normals and gSPTexture scale.
- Original bomb skeleton09000064 and ice DL09008220 are available as projectile visuals. Native hair and jetpack attachments remain in their source actions.

The runtime places all original rigid meshes directly using their native animation matrices. The single source-unit conversion0.015158092072935184 matches the accepted Goemon reference, preserving Sasuke's native relative stature (standing height2.523715m). The source +Z front is rotated to the controller's -Z front. Only a fixed feet offset is added.

`portrait.png` and the three transparent `icons/` images are rendered from these same meshes/materials. Portrait uses native action68 frame0 because the native idle has no weapon nodes.

Reproducible recovery scripts, original execution proofs, source channels, texture metadata, screenshots and logs live at the primary project's `build/Other Files/Sasuke ROM Recovery/Model/`. Native execution validation covers26958 exact integer channel samples and6390 world matrices across all156 clips (maximum float error2.63e-5). Asset verification compares706 source vertex records,10 static/body textures plus13 face textures,232 action rows and156 clips. Runtime model tests cover11985 action/part samples, native rates, source stature, both kunai paths, actual combat Node ownership, projectiles, hair and locomotion.

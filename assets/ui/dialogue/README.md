# Approved conversation style

User approval (2026-11-12): keep the 熊弟 conversation style for all conversations.
Reuse `scripts/forest/forest_dialogue.gd` and its existing menu skin, with a large
painted character portrait on the left, a speaker nameplate, an ivory-framed dark
dialogue box across the bottom and a dimmed gameplay background. Preserve readable
native text, the responsive layout, gradual reveal at 18 characters/second and
Space to reveal/continue. Resume gameplay on the closing Space release so it
cannot also trigger a jump.

User direction (2026-11-25): regular NPC conversations show the speaker name and
dialogue without an enlarged duplicate of the NPC's world sprite. The shared
Explorer NPC owner passes a null portrait for residents and signs in every area.
Special encounters keep their separately approved painted portraits.

Use each speaker's own name and dialogue while keeping this shared presentation
consistent. Preserve approved portrait masters and reuse them
as references for expressions. Reuse the existing dialogue component rather than
creating a separate UI per character. Conversation triggers and outcomes remain
encounter-specific; the shared style does not make every conversation start a fight.

## 熊弟 dialogue portrait

`kumatei-confident.png` is the user-approved authoritative portrait (2026-11-12).
Use this exact image as the reference for future expressions, preserving the face,
tan skin, muscular proportions, blue/black/gold outfit and white arm wraps.
The tall grey flat-top is **his hair, not a cap**. Do not add a hat or black spiky
fringe. Preserve this approved master; save expression variants beside it.

Generated with the built-in imagegen tool from the approved dialogue mockup and
the recovered actor 100625 sprite. Final prompt: preserve the approved portrait's
face, outfit and pose; replace the mistaken cap and dark spikes with tall silver-grey
flat-top hair and clipped sides, visibly textured as hair; extract only the waist-up
character on true alpha transparency, without text, UI or background.

Master: 1122 × 1402 RGBA, 2,078,019 bytes (about 6 MiB decoded), SHA-256
`0e340a2dda23e8638db61412db789c89dfdd2e586ee6c7b0563a24266b124a8d`.

`forest_dialogue.gd` uses this PNG and native Godot text (18 characters/second).
The panel reuses `preparation_skin.gd` and the recovered Blue Crossgate ivory
frame documented in `../crossgate/menu/README.md`. That source is a system-menu
frame; the original client's specific NPC dialogue frame has not been verified.
No source client artwork is overwritten or recoloured.

熊弟 waits alone and harmless in his chamber while alive. Approach within 8 map
units on his level and press F when “F · 和熊弟交談” appears. This opens the
dialogue box; Space reveals the remaining text, then the next Space press/release
advances to the final bear callout and yelling expression. Finish that page with
Space to start combat and summon his nine bears with the existing pooled arrival effect.
Outside talking range, F still commands pets to hold. Leaving resets the intro;
defeated slots stay defeated, and surviving bears return if the boss is already dead.

## Bear callout and yelling expression — 2026-11-12

The final page says “熊兄弟們，出來吧！\n一起上，讓他見識我們的厲害！”
with `kumatei-shouting.png`. Both textures are preloaded. Page changes reuse the
same portrait and text controls, reset the text reveal and keep gameplay paused.
Only dismissing the final page on Space release starts the encounter.

The expression was edited with the built-in imagegen tool using the approved
`kumatei-confident.png` as the reference/edit target. The original is unchanged.
The new PNG is 1122 × 1402 RGBA with real alpha transparency, 1,985,443 bytes
(6,292,176 decoded RGBA bytes); SHA-256
`a36c7d057a4161758c71d5d5831057b543022ea33fccebf2e53b8c4da399becd`.
It preserves the scar, grey flat-top hair, outfit, pose and portrait framing.

Final generation prompt:

> Use case: identity-preserve. Asset type: transparent game dialogue portrait expression variant. Edit target and authoritative identity/style reference: the supplied kumatei-confident.png. Change ONLY his facial expression to an intense angry battle yell calling his bears: eyebrows sharply furrowed, fierce focused eyes, mouth open wide in a forceful shout with natural teeth and tongue, tense cheek/jaw. Keep the exact same character identity, cross-shaped cheek scar, tan skin, silver-grey flat-top HAIR with clipped sides (hair, NOT a cap or hat), muscular proportions, black vest with blue trim, gold straps and sash, white forearm wraps, same hand-on-hip pose, body, outfit, painted anime rendering, lighting, framing and silhouette. Keep the head at the same angle and size, do not redesign or add anything. Waist-up portrait aligned exactly like the original so switching expression in a dialogue box feels seamless. Preserve genuinely transparent alpha background. No text, no speech bubble, no frame, no scenery, no extra characters, no hat. Output just the one yelling portrait with full hair silhouette and same body crop, approximately the original 1122 by 1402 portrait aspect ratio.

## 法爾肯

Approach the dais after Yeka opens the barrier and press **F** near 法爾肯.
The shared conversation component displays two original Traditional Chinese
pages. Space reveals or advances each page. Releasing Space on the last page
starts the native boss and five guards. A living boss waits again on re-entry.
The defeated boss stays absent, and surviving guards can return.

`falken-shadow.png` is an original ImageGen portrait for this introduction.
The faceless shadow figure has luminous eyes and a bronze water seal.
It is a 1122 × 1402 RGBA PNG with transparent edges and SHA-256
`bdfc0e2e00125a28c2ea239d15e5e3a6da2a47dc3dafcc9d7db53c85c605620f`.
Both pages use the same portrait. The game reuses the existing waiting sprite
and dialogue component, and only the native encounter can spawn combat units.

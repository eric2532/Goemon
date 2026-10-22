# Rogue cast: Goemon visual baseline

Current MVP direction (9 October 2026): the user approved the v2.34.1 Magic
Swordsman and Explorer pilots, then requested the same coordinated design
throughout the Rogue cast. The remaining eight now use class-specific face,
hair, mask or helmet designs, with the accepted pilots preserved. See
[the roster rollout](rogue-roster-upgrade.md) and [the pilot notes](rogue-design-pilot.md).
Historical exact-head approvals below are superseded by this all-roster request.

The approved master is `assets/blender/characters/kai.blend`. Keep that model,
its original atlas and the illustrated 2D exploration intact. The complete user
art brief is saved in `goemon-character-standard.txt` beside this document.

## Actual master inspection

Blender 5.2.2: normal body 240 vertices / 406 triangles; normal hair 71 vertices /
54 triangles. Alternate gold hair is a separate hidden object. The only mesh
modifier is Armature. The rig has 22 articulated bones. Normal materials use the
original nearest-filtered painted atlas, roughness 1, metallic 0, specular 0.
Head/hair reaches 3.3 game meters, with hair spanning approximately 2 meters;
the body including the face reaches 2.35m. Goemon's giant hair is identity-specific.
The broad skull, large painted eyes, simplified nose/mouth/ears, short neck,
compact ribcage/waist, mitten-like hands, short legs and broad shoes are the shared
style language. Facial and clothing details are mostly painted rather than raised.
No bevel-heavy or realistic glossy PBR treatment belongs in this cast.

## Identity comparison before adaptation

Existing Rogue portraits and editable Blender sources are the available identity
references. No separate original 2D concept drawings were found. These are not
claimed to be those missing drawings.

| Hero | Preserve from Rogue | Apply from Goemon |
|---|---|---|
| Pirate | Teal tricorn and coat, red lining, eyepatch, amber eye, beard, cutlass, pistol, flask | Broad head and face, compact coat volume, enlarged gloves and boots, matte gold accents |
| Samurai | Red lamellar armor, ivory crescent helmet, blue sash, katana and yumi | Chunkier helmet/head relationship, short strong legs, large tabi, simplified armor planes |
| Ninja | Slim silhouette, violet hood/mask, split scarf, short sword and shuriken | Large visible eyes, full head volume beneath hood, readable mitts and shoes, fewer tiny seams |
| Mage | Blue/ivory robes, tall hat, silver hair, staff, wand, grimoire | Broad face, solid hair masses, compact torso inside robe, matte cloth and crystal colors |
| Knight | Closed platinum visor, blue heraldry/plume, shield and straight sword | Enlarged helmet, broad shoulder/torso mass, chunky armored feet, large color areas |
| Dragoon | Azure dragon armor, horned helmet, seafoam mantle and long lance | Enlarged head, simplified scale forms, strong gloves/boots, no metallic shine |
| Magic Swordsman | Silver swept hair, amethyst armor, asymmetric mantle, rune claymore | Broad anime face, larger eyes, shorter legs, real skull depth, solid hair locks, matte purple/silver |
| Ranger | Green hood, forest layers, quiver and ornate greatbow | Lean but compact anatomy, broad hood/head, simplified face and bracers, heavier footwear |
| Explorer | Copper goggles, auburn braid, ochre coat, teal scarf, satchel, paired blades | Distinct smaller frame with large head/eyes, thicker hands and boots, fewer micro-seams |
| Master Thief | Broad belly, cheerful weathered face, russet robe, plum trousers, long pipe | Preserve weight and relaxed silhouette; simplify robe detail, enlarge head/hands/feet without slimming him |

## Implementation and review

`tools/style_rogue_roster.py` uses preserved editable component sources in
`assets/blender/rogue/originals`. It changes body regions independently, retains
costume/weapon components, simplifies dense primitive topology, removes selected
microdetails and consolidates matte costume colors into 128px nearest-filtered
palettes. Faces use the painted atlas described below. Sources retain separate editable components;
GLBs batch by animated pivot. Existing native joint roles and rigid weapon axes
remain compatible with the Rogue action animator. Their rest pose remains the
native relaxed arm pose, not Goemon's T pose, because the native skills depend on it.

`tools/render_rogue_style.py` renders every hero beside the unchanged Goemon master
with identical orthographic camera, ground, lights, background and settings in
front, side, three-quarter and back views. The game keeps its existing 1.15 visual
scale and +Z-to−Z wrapper convention. Original imports remain available separately.

Validation requires checking the comparison images, roster portraits, and actual
Fire Siege movement/actions; code tests alone cannot judge the designs.

## Superseded 2.29.0

The user rejected the enlarged heads and raised facial features in this version.
It is historical context, not an approved face or proportion reference.

All ten derivatives are integrated into the roster and native actor. Review
caught and fixed detached facial details, clipped comparison silhouettes, and
Ninja's hood/mask attachment. Each final hero has four comparison renders.
The packaged macOS app passed 134 combat/control checks and a 70.63-second
recording exercised every revised hero's orbit, movement, jump, evade, primary,
secondary and signature. The deterministic recording pauses AI and grants
invincibility; normal gameplay is unchanged. The native launch reached the
normal difficulty, roster, card and map flow and was left paused on Magic Swordsman.
The approved Goemon geometry, UVs, atlas, 22 bones and 24 clips passed preservation
verification. Original 2D concepts remain unavailable; existing Rogue sources and
portraits were used. Costumes retain more geometry than the Goemon original,
while sharing one matte palette per hero and only 7–9 animated mesh batches.
No remote or Linux release was published for this art update.

## Painted face correction: 2.29.1

Head scales are reduced 24–31% relative to 2.29.0. All nine visible faces are
UV-painted directly onto the actual head mesh. Separate eyes, brows, noses, lips,
cheeks, jaws, facial hair and smile creases are removed. Knight retains his closed
helmet at the smaller head scale. Hair, hats, ears and Ninja's mask remain geometry.
The original Goemon and Edo assets are unchanged.

`assets/rogue/styled/faces/painted-faces.png` was created and refined with the
built-in image-generation tool; `prompt.txt` records both prompts and provenance.
The atlas has distinct painted identities in a 3×3 grid. Skull fronts use planar
UVs; skull backs, ears and exposed skin use plain skin areas without repeating
facial features. The face material is matte and uses linear texture filtering.
The Blender sources pack the image and preserve editable meshes and UVs.

The face expressions are currently fixed paintings, like the reference approach;
this change does not add blinking or animated mouth textures. Existing body,
head-turning and native combat animations remain active.

Final verification: the exported 2.29.1 macOS app passed all 134 combat/control
checks. Its 70.63-second art-tour recording exercised all ten revised heroes,
with camera orbits, movement, jumps, evades and native attacks. Comparison renders
and gameplay frame sequences were inspected. Native launch reached difficulty,
roster, upgrade selection and the actual Fire Siege map; the app was left paused
with Magic Swordsman. Code-signature verification passed. An existing exit-only
resource cleanup warning remains in the automated tour log; it did not interrupt
the recording or normal launch. No GitHub/Linux release accompanies this correction.

## Head silhouette refinement: 2.29.2

The user approved the painted facial artwork and requested better head shapes.
The nine exposed skulls now use an editable surface with deliberate cranium,
cheek, jaw and chin loops, replacing the source's stretched spherical forms.
The chin ends 12% of the old skull height higher; the eye and mouth positions use
the original UV projection bounds, and the approved face atlas is byte-identical.
The cheeks transition into a shorter tapered jaw, with gentler taper for Mage
and Explorer and fuller cheeks for Master Thief. Ears are smaller and flatter.
Knight's enclosed helmet and the original Goemon/Edo geometry remain unchanged.
Head pivots, hair/headwear, clothing, weapons and combat rules are preserved.
The upper skull blends back into its original hair-fitting envelope above the
brows. Mage's head components sit 0.08m lower and Samurai's 0.06m lower to keep
the exposed neck restrained; UV bounds move with each head, and all native
animation pivots remain unchanged.

Verification: all nine skulls passed manifold, winding and degenerate-face checks.
All exported native joint transforms match 2.29.1 exactly, and the face atlas is
byte-identical. Four-angle comparisons and close-ups were reviewed, including a
hair-overlap correction. The final packaged app passed 134 combat/control checks
with zero failures; its 70.63-second recording covers the entire revised roster's
turning, movement, jumping, evasion and native attacks. Gameplay frame sequences
were inspected. The signed 2.29.2 app was launched normally and left open at hero
selection. Editable sources, comparison renders and the new recording are saved
beside the app; the preceding 2.29.1 app and recording are retained separately.

## Slimmer faces and additional hair: 2.29.3

The user found 2.29.2 too round. Lower cheek widths are reduced about 12%, and
the jaw now tapers more clearly toward the short chin. The original painted
face atlas and its landmark projection remain unchanged. Each exposed face has
two solid tapered temple locks in its existing hair colour, tucked under the
existing hair, hat or hood. Magic Swordsman also has a smooth solid rear hair
layer behind the long silver locks, covering gaps. Samurai's chin tie follows
the narrowed jaw. Knight keeps his closed helmet; Goemon and Edo are untouched.

The nine skulls, eighteen new temple locks and silver hair underlayer passed
manifold and winding checks. Native animation transforms and the painted atlas
match the previous version. Multi-angle renders and the final 70.63-second
packaged gameplay recording were inspected. The packaged control/combat suite
passed 134 checks with zero failures, code signing verified, and the native app
was reopened successfully on the actual Fire Siege map.

## Approved design, slight ear coverage: 2.29.4

The user approved the complete 2.29.3 design and requested only slightly more
hair over the ears. Two small solid side tufts per exposed head overlap the
upper ear, while leaving the lobe and jewellery visible. Existing skulls,
painted faces, temple locks, hairstyles, costume and gameplay remain unchanged.
Knight's closed helmet remains intact. Treat 2.29.3/2.29.4 as the approved design.

Validation: all 1,405 pre-existing objects retain identical geometry, transforms
and parenting versus approved commit 4ffb11a. The eighteen new tufts passed
manifold, winding and degenerate-face checks. Multi-angle renders and the
70.63-second packaged gameplay recording were inspected. The packaged control
and combat suite passed 134 checks with zero failures. The signed 2.29.4 app
was launched normally and left open at Fire Siege difficulty selection.
The test harness still reports existing resource-cleanup warnings at exit.

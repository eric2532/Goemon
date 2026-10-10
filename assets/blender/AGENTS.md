# Character art direction

Current user correction (2026-10-09, Ranger hat): replace Ranger's open hood
with a fitted forest-green hat whose crown and rear nape panel fully cover the
scalp, with a readable brim and optional feather. Preserve the approved v2.35
painted face, facial depth, UVs and all solid hair meshes exactly, plus native
body/weapon geometry and pivots. Rebuild through tools/equip_ranger_hat.py
(also dispatched by style_rogue_roster.py). Inspect the live exported front,
profile, three-quarter and back beside Goemon; regenerate the matching portrait.

Current user correction (2026-10-09, v2.37): Samurai's neck looks too long;
shorten the neck and lower the head/helmet assembly, refitting the red scarf into
a compact mouth-and-neck wrap while retaining its long animated tail. Dragoon's
dragon helmet must cover his face; Magic Swordsman needs a purple demon mask
covering his face. This supersedes the open-face/readable-nose direction below
for those two helmets and authorizes Samurai's head-pivot height adjustment.
Keep underlying painted faces intact, retain class colors, native weapons and
all other heroes. Verify front/profile/three-quarter/back and animated gameplay.

Current user direction (2026-10-09, v2.36 equipment): add a clearly dragon-shaped
blue/teal/silver helmet for Dragoon, a cool magical purple helmet for Magic
Swordsman, and a long red Samurai scarf covering neck and mouth with a wind-driven
tail. Slightly thicken Ninja’s jaw. These targeted equipment changes supersede
headwear preservation for those classes; keep the approved integrated painted
faces, readable eyes/noses, costumes, native pivots and all other heroes unchanged.
Samurai tail uses a dedicated Head/ScarfTail empty and ScarfTail_Geometry export,
with root-local geometry along Blender +Y / Godot -Z for continuous cloth motion.
Keep editable sources and reproducible generator, inspect all four angles beside
Goemon and in gameplay. Preserve Master Thief’s accepted nose UV landmark V .430.

Current user direction (2026-10-09, approved rollout): the user approved the
v2.34.1 Magic Swordsman and Explorer face-depth pilots and explicitly requested
updated faces and designs for ALL Rogue characters. Extend their fuller forward
facial volume, rounded integrated nose, deliberate cheek/jaw/chin, coordinated
painted UV features and bold solid hair to the remaining eight heroes. Preserve
each class identity, costume, gear, body/weapon geometry and native pivots. Knight
keeps his defining closed helmet; carry the direction through his visor and crest.
Keep the accepted two pilots and Goemon master/atlas intact. This approval
supersedes the historical exact-face/head/hair restrictions for the whole Rogue
cast. Record four-angle comparisons and gameplay verification for this rollout.

Current user direction (2026-10-09): Fire Siege MVP is the primary development
version. The user approved trying a new coordinated head/face/hair design on
Magic Swordsman and Explorer, inspired by their supplied anime adventure figures.
For these two pilots, this supersedes the historical exact-head/hairstyle and
fixed-face-layout restrictions below. Fit painted facial features to intentional
cheek, jaw, chin and skull geometry, with subtle integrated facial volume and
bold solid hair clumps. Retain character identities and native animation/weapon
pivots. Review front, side, three-quarter and gameplay views before extending
the direction to the remaining Rogue cast. Keep the Goemon master intact.

Latest pilot feedback: the v2.34 faces look too flat and recessed in side view.
Give both pilot heads fuller facial depth, a gently projecting brow and cheek/
mouth region, and a visible integrated nose bridge/tip. Preserve the painted
identity and avoid a deep orbital dent or a thin pointed nose. Judge the actual
side and three-quarter silhouette, not just the frontal artwork.

For playable character modeling, use the approved `characters/kai.blend` Goemon
as the game's visual/technical baseline. Read the complete user brief at
`../../docs/art-direction/goemon-character-standard.txt` and the actual master
geometry/materials before editing another character. Preserve each character's
identity reference, costume, body type, colors, weapons and personality; do not
make Goemon clones. Compare full front, side and three-quarter views beside Goemon
under shared lighting before integration, then verify the character in gameplay.
Keep source models editable and preserve native combat/animation compatibility.
The approved Goemon source and atlas are not a template to overwrite or reshape.

User correction (2026-10-07): facial features must be PAINTED onto the head
texture, like Goemon. Do not build separate eyeballs, eyebrows, noses, lips, or
facial-hair pieces. Keep a simple volumetric head, restrained head proportions,
and use editable UV face artwork. The rejected oversized-head/raised-feature
version is not an approved reference.

The painted face artwork was approved in the next user review. Keep that atlas
unchanged when refining head geometry. Replace the stretched sphere silhouette
with a rounded cranium, intentional cheeks, a short tapered jaw and rounded chin;
keep painted facial landmarks stable and check hair/ear/headwear fit from all sides.

Latest refinement: 2.29.2 cheeks were too round. Use slimmer cheeks and a clearer
jaw taper, with modest extra temple/side hair to frame the face. The approved
painted face artwork stays unchanged. Do not restore full round cheeks.

User approved the complete 2.29.3 design. Preserve its exact faces, skull shapes,
costumes and hairstyles. The only requested follow-up is slightly more side hair
over the ears; keep that adjustment small and retain the visible ear lobes.

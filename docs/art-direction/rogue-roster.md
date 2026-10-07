# Rogue cast: Goemon visual baseline

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
microdetails, rebuilds anime eye surfaces and consolidates matte colors into
128px nearest-filtered palettes. Sources retain separate editable components;
GLBs batch by animated pivot. Existing native joint roles and rigid weapon axes
remain compatible with the Rogue action animator. Their rest pose remains the
native relaxed arm pose, not Goemon's T pose, because the native skills depend on it.

`tools/render_rogue_style.py` renders every hero beside the unchanged Goemon master
with identical orthographic camera, ground, lights, background and settings in
front, side, three-quarter and back views. The game keeps its existing 1.15 visual
scale and +Z-to−Z wrapper convention. Original imports remain available separately.

Validation requires checking the comparison images, roster portraits, and actual
Fire Siege movement/actions; code tests alone cannot judge the designs.

## Delivered 2.29.0

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

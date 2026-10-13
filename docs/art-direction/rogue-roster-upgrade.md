# Approved Rogue design rollout

On 9 October 2026 the user approved the v2.34.1 Magic Swordsman and Explorer
pilots and requested updated faces and designs for the complete Rogue cast.
This applies the accepted integrated depth, painted-feature coordination and
solid hair language to the remaining eight heroes. The accepted pilots and
Goemon master are retained exactly.

The source identity references are the editable Rogue models and portraits;
the user's anime adventure figure image guides the translation into volume.
Goemon supplies the matte painted material treatment, compact anatomy and large
readable shapes. The new skulls use explicit cheek, jaw and chin rings with
class-specific proportions, supported eye/brow planes and a broad rounded nose
integrated into the surface. Eyes, eyebrows, mouths, beards and expressions stay
painted. The shared approved face artwork remains unchanged; UV0 landmarks now
fit the geometry.

| Character | Distinct design in this rollout | Preserved identity |
| --- | --- | --- |
| Pirate | Broad captain's jaw, supported cheeks and nose, swept dark fringe and rear locks | Eyepatch/beard, teal tricorn and coat, queue, earrings, cutlass and pistol |
| Samurai | Firm short chin, deliberate cheek-to-jaw break, short black temple/nape locks | Crescent kabuto, red lamellar armor, blue sash, katana and yumi |
| Ninja | Narrow alert eye plane, fitted full hood and curved cloth mask, dark temple locks | Violet topknot and split scarf, slim silhouette, sword and shuriken |
| Mage | Compact softer jaw, rounded cheek transition, broad silver fringe and long closed locks | Tall celestial hat, blue/ivory robe, earrings, staff, wand and grimoire |
| Knight | Supported brow visor, rounded projecting jaw guard and three substantial cobalt plumes | Closed platinum armet, blue heraldry, shield and straight sword |
| Dragoon | Crisp tapered jaw and cheek apex, swept charcoal temple/nape locks | Azure horned/winged helmet, seafoam mantle, dragon armor and long lance |
| Ranger | Lean tapered jaw, high cheek plane and asymmetric chestnut fringe/temples | Green hood, forest layers, quiver and greatbow |
| Master Thief | Broad mature jaw, smile-supported cheeks, swept chestnut hair and silver temples | Weathered painted face/moustache, slouched cap, broad belly, russet robe and pipe |

Knight intentionally has no exposed face. His enclosed visor and plume receive
the same attention to front/side silhouette. Replacing it with visible eyes would
remove his established identity.

## Technical preservation and verification

The generators preserve native empty transforms, parenting, body components and
weapon geometry. Head accessories are only refitted where the new surface needs
it: Samurai chin ties and Ninja's forehead plate/gem. Knight's head armor and
Ninja's mask/hood are explicitly rebuilt. The new parts are editable separate
meshes in the source; exports batch by the existing animated pivots.

A visual pass corrected Ninja scalp intersections in the old decimated hood and
replaced the projecting mask with cloth that follows the actual skull and wraps
the neck. Knight's gold spine is sampled against the actual dome and visor
surfaces. These fit corrections came from side and three-quarter renders.

Independent Blender verification against the preserved baseline confirms 70
native pivots and 1,018 body/weapon components exactly unchanged. In total,
1,168 retained components match their baseline geometry, transforms, parenting
and UV-layer layout. All 72 new/sculpted mesh components pass closed-manifold,
positive-volume and nondegenerate-face checks. The additional fitted accessory
meshes are checked during generation. Actual GLBs contain one UV0 set per
primitive; all seven exposed faces cover the correct painted features with
hundreds of distinct UV coordinates. The eight models total 7–9 animated mesh
batches each.

The two accepted pilot sources, models, reports and portraits, the Goemon master
and the face atlas remain byte-identical. All eight models were rebuilt from
tracked originals and revalidated, proving the rollout needs no ignored baseline
files to reproduce. Runtime and packaged gameplay verification belongs to the
parent integration task and is recorded separately.

## Reproduction

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/sculpt_rogue_roster.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/style_rogue_roster.py -- pirate samurai ninja mage knight dragoon ranger master-thief
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/render_rogue_roster_review.py -- pirate samurai ninja mage knight dragoon ranger master-thief --portraits
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/verify_rogue_roster_art.py -- build/rogue-roster-upgrade/baseline build/rogue-roster-upgrade/art-validation.json
```

The ordinary style generator dispatches the two accepted heroes through the
pilot generator and the remaining eight through the roster sculptor. It retains
the approved designs when regenerating a complete roster.

Evidence is under `build/rogue-roster-upgrade/`, which contains `.gdignore` so
Godot does not import the Blender backups. `baseline/` contains 45 preserved
files and SHA-256 hashes. `before/` and `after/` use identical orthographic cameras,
lights and framing, with shared-Goemon front, side, three-quarter and back renders.
Head closeups hide weapon meshes to keep profile landmarks visible; the full-body
comparisons retain all equipment. Neither review renderer saves the source or
master. Eight class portraits are regenerated from the finished assets.

## Independent review refinement

Master Thief's atlas tile places the painted nose base higher than the other
faces. Actual-engine profile review caught the shared landmark sampling brown
moustache on the integrated nose tip. His generator now uses a per-class V .430
nose landmark. This is a UV-only correction: the atlas, all geometry and native
transforms remain exact. His portrait and comparison renders were regenerated;
all other heroes, including Ninja, remain unchanged.

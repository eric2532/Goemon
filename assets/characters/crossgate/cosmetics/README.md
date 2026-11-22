# Recovered equippable cosmetics

The additional **水龍 · Crossed Spear & Axe** back cosmetic uses the preserved
Water Dragon spear and axe item art from Shin's `900050/polearm/item.png` and
`900050/axe/item.png`. Its rear view and icon put the spear on the left and
the slightly lowered axe on the right. `prepare_crossgate_cosmetics.py` appends
eight prepared views on one extra atlas page; the original 400 resources and
their page regions stay intact. The icon is cropped from that exact rear view.
It uses the existing wing depth, head attachments, five slots, saves and native
copy lifecycle. Front views reverse sides as the wearer turns. The recovered
item views are projected offline; they are not newly recovered 3D artwork.
Side views project each weapon separately, with staggered mounts and at least
60% blade-face width, rather than squeezing the entire X to 22% width.
The mount shifts sixteen source pixels behind the facing direction in side
views; the earlier positive offset pointed toward the torso. Offline shaded
edge copies give the side artwork a thin rim without adding runtime layers.
The user's two size reductions keep the pair at about 68% of its original size.
Approved placement B lowers it four pixels, preserving the lowered axe and X.

The 400 wardrobe resources come from the preserved BlueCG client in the
neighboring `Magic Power` project. Artwork IDs, rather than unverified server
item names, are the stable saved identities (`cosmetic:119010`, for example).
The catalog includes 246 head pieces, 101 wing/back pieces and 53 effects.
The original client files and the earlier wearable export remain unchanged.

`tools/prepare_crossgate_cosmetics.py` decodes original pixels and packs shared
atlases using the existing Cross Gate packer. It retains source origins, frames,
facing and animation durations. Transparent animation frames remain transparent.
The four directional face pieces retain their authored hidden back views.
Tiny fall markers are excluded from the runtime clips; missing fall/action
art uses the item's standing animation for the same facing. These are local
Goemon presentation rules, not a claim about current BlueCG server equipment.
No original stat bonuses, inventory restrictions, hits or damage are imported.

The current Cross Gate character/skin/weapon frames have offline attachments.
Native head coordinates seed preparation. Missing points use the selected skin's
approved original head crop and its own directional head pixels, with exact
color neighborhoods followed by masked color matching. The small C helper is
compiled only for asset preparation under `build/Other Files/Asset Toolkit/`;
the game never loads it. Low-confidence fits remain identifiable in
`Sponsor Cosmetics/Preparation/anchor-methods.json` and need visual review when
adding or changing motion. These prepared fits are local adaptations, not
recovered native coordinates. Editable source artwork and portraits are preserved.
Keep matching samples inside the head: including the shoulders let rear-facing
Kaz's similar black coat win during an attack. The focused Python regression
uses that reviewed original frame to catch this mistake.

Movement/attack review also rejects stale native points outside the rendered
body and uses valid heads from the same pose and neighboring keyframes. When a
spinning head turns away from the body facing, a wider match checks the skin's
other authored head views. `head-fits.json` also contains reviewed hurt/fall
foreheads and final corpse poses, including obscured Red Lightning frames,
guarded by source RGBA hashes and exact dimensions/origins. Inspect changed source pixels rather than
updating those hashes to bypass a failure. No body/item pixels are repainted.

Hurt/death matching uses those actual pose heads across compatible skins and
weapons, including the fist/dagger aliases. A native point touching clothing is
not enough to establish a head. Palette variants can reuse a matching upper-head
outline after translation; the offline bit-mask matcher tolerates at most six
percent outline differences, rejects solid/ambiguous strips, and prefers nearby
matches. Keeping collars out of this patch is essential. Reviewed atlas regions
take precedence even if another action encounters the same pixels first;
conflicting annotations for a shared region stop preparation. All matching and
the compiled helper stay outside the running game.

The current audit covers 758,524 frame uses and 776 custom guard cells, with no
pixel-support gaps in the previously reviewed movement set. The full reaction
review extends that check to every authored action and raw hurt/fall frame,
including the final corpse hold. Coverage near pixels is a technical check; review the
rendered boards and normal-input clips as well. Preparation caches exact inputs
outside the game; sample preparation does not overwrite published attachments.

`anchors.json` indexes compact eight-byte records in `anchors.bin`: atlas x/y
as unsigned 16-bit values and local head x/y as signed quarter-pixel values.
The existing model's actual texture, region and offset select the point, so
skin, weapon, jumping and prepared animation changes use the rendered frame.
The runtime reads the lookup once on setup and binds selected body pages;
animation does not load files, reconstruct scenes or create materials.

`cosmetic_catalog.gd` shares the immutable atlas/material cache.
`cosmetic_layers.gd` manages up to five reusable Sprite3D layers on the existing
Cross Gate model. Wings/back pieces move behind the body in front views and
ahead of it in back views, while scenery can still occlude them. Head pieces
and effects use the established body shader. Character and native-copy life,
movement, combat clocks, targeting and pooling remain owned by their existing
controllers. These body-worn resources are character equipment; pets retain
their existing independent Qi cosmetics.

The Equipment hub uses its existing scroll grid, five cosmetic slots and atomic
wearer-specific save/discard/unequip flow. Qi colors retain their current format.
Rebuild after changing source motion; never hand-edit generated atlases or
replace hashes to silence a stale-source failure.

```sh
python3 tools/prepare_crossgate_cosmetics.py
python3 tools/prepare_crossgate_cosmetics.py --check
python3 tools/audit_crossgate_cosmetic_alignment.py
python3 -m unittest discover -s tools -p 'test_prepare_crossgate_cosmetics.py'
python3 tools/goemon_assets.py audit
python3 tools/goemon_assets.py check
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/cosmetic_equipment_test.gd
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/cosmetic_equipment_test.gd -- --alignment
python3 tools/audit_crossgate_cosmetic_alignment.py --all-animations
"/Users/eric/Desktop/Play Goemon.command" --script res://tests/forest-shrine/cosmetic_equipment_test.gd -- --all-animations
```

The full fixture checks every available selected-skin frame and the full resource
matrix. Hurt/death captures step the existing combat owner through every source
frame in all eight facings, then hold the last death frame; this is controlled
visual review playback, not a performance recording. Evidence belongs in
`Sponsor Cosmetics/Reaction Review/` and `Gameplay/all-animations/`.

Texture imports use lossless compression, no mipmaps and
`process/fix_alpha_border=true`. This fills invisible border RGB for filtering
without changing the authored opaque pixels or alpha masks; it prevents the
source's transparent green/white key colors from appearing as outlines.
Keep those parameters when adding atlas pages. The painterly export preset
includes the runtime catalog and both attachment files; app export is still
only performed when the user requests a build. Research, audits, fit studies,
logs and gameplay captures belong under `build/Other Files/Asset Toolkit/Sponsor Cosmetics/`.

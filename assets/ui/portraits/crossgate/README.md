# Original model HUD heads

Current policy (2026-11-16): all Cross Gate character HUD portraits use the
original selected model's head. `model-heads.json` maps the existing validated
character/skin loadout keys to prepared PNGs in `model/`. The existing
`painted_heads.gd` loader and immutable texture cache remain the shared owner.
Identical heads share a texture, including Kaz's Maze skin and saved Maze ID.
Painted masters, historical `skins.json` routes and conversation art are preserved.

Every head comes from the first original standing frame, facing 5 (toward the
viewer). `model-head-crops.json` stores a reviewed rectangle for each saved
character/skin key: remodels can move the chin independently of body height,
and ribbons/hair can extend above that height estimate. New keys must have an
explicit reviewed crop before preparation writes any images. Preparation
includes five extra source rows below the former chin crop for a little neck,
retains source RGBA pixels and uses integer nearest scaling. The visible top
aligns to y=8 on a transparent 256-pixel canvas, meeting the HUD circle's top
without a circular mask cutting the hair. Four extra rows above the reviewed
crop preserve high hair/accessory pixels; width stays within 224 pixels and
height within 232 pixels. Original hair, faces, colors and source overlays are retained;
no portrait is redrawn. The HUD uses nearest filtering. Some original characters
have angled poses or faces partly hidden by hair; those source details stay intact.
`model-head-provenance.json` records the exact atlas, frame, crop, placement and
pixel hash for every route. There is no portrait work in attack or hit loops.

After changing or recovering character skins, run these commands from the project:

```sh
'/Users/eric/Desktop/Play Goemon.command' --headless --script res://tests/forest-shrine/skin_head_hud_test.gd -- --catalog
python3 tools/prepare_crossgate_heads.py
python3 tools/prepare_crossgate_heads.py --check
python3 tools/test_prepare_crossgate_heads.py
'/Users/eric/Desktop/Play Goemon.command' --script res://tests/forest-shrine/skin_head_hud_test.gd
```

The catalog exporter includes all current Cross Gate identities; preparation also
preserves the two hidden classic Shin loadout routes. A stale inventory fails
against the weapon catalog. Both head route JSONs remain in the export include
filter. Desktop checks cover actual models, matching HUD heads, XP retention and
cached texture/resource reuse. Source checks recompute every PNG without drawing
or filtering new pixels. Review rendered comparisons separately from assertions.
Evidence and contact sheets live under
`build/Other Files/Asset Toolkit/Model HUD Heads/`.

The earlier 2026-11-16 crop recheck covered 257 current/saved routes (255 selectable
entries plus two hidden Shin saves), including Bei, Moe and Ami. It restores
lower faces on affected Uru, Emilia, Pete, Bei and Moe designs, Cedi's highest
hair row and Moe's ribbon tips. Other heads keep their reviewed source crops;
Kaz's aura crop already contains its chin. Full source/head boards and a
before/after sheet are under `Crop Review/`. The pixel regression checks complete
reviewed head regions in six previously clipped designs and canvas padding for
every prepared texture. The later top-alignment/neck correction covers all 272
current/saved routes; its evidence is under `Top Alignment/`. Source checks
require the same visible top for every prepared PNG and exact hair, face and
neck pixels in seven reviewed designs. The desktop comparison now includes
the actual HUD circle behind every skin. This does not replace visual review of future skins.

# Historical painted head preparation

Every selectable Cross Gate model/skin has an explicit entry in `skins.json`,
keyed by the existing `Roster.loadout_key`: for example `34:109890` for blond
Kaz, or `35` for Uru’s original appearance. The original 80 selections use 53 heads:
45 newly painted variants and eight matching original portraits. The Pete,
Grace, Rei and Cedi addition brings the route total to 134: their 53 matching
heads use recovered source pixels and palettes in `recovered/`, preserving all
existing painted masters. Rebuild those source heads with
`tools/recover_crossgate_selected_cast.py`. Heads are
shared only where the visible head is unchanged; weapon/aura changes do not
need duplicate artwork. Head-only variants omit clothing so outfit changes do
not produce a mismatched collar. The earlier green-scarf Shin Special painting
is preserved, but his red-haired/blue-scarf source models use the matching Shin
portrait. Original recovered portraits and skin-gallery previews remain intact.

`painted_heads.gd` resolves the validated selected skin through the existing
roster helper and caches each immutable texture when first selected. Keep the
full-resolution transparent PNG masters and each Godot import's 256-pixel size
limit with mipmaps disabled. One imported RGBA head is approximately 0.25 MiB;
cycling through all 53 heads can retain about 13.25 MiB before engine overhead.
Nothing loads or processes portraits in attack/hit loops; changing a skin may
load its head once.

The built-in Imagegen tool creates the painted artwork, using the prior heads
for style and each actual selected sprite for hair, face, palette and accessory
identity. Exact prompts and source/output hashes are in `skin-provenance.json`;
the original nine prompts remain in `provenance.json`. Bog variants preserve
his approved dialogue identity, crossed cheek scar and flat-top HAIR, not a cap.
Do not overwrite the approved dialogue master or the main-menu painting.

When adding a selectable skin, add its explicit matching route and artwork.
Keep `skins.json` in the export preset's include filter. Run through the desktop
launcher with `--script res://tests/forest-shrine/skin_head_hud_test.gd` for the
complete model/skin/HUD matrix and source-versus-head review boards. Add
`-- --catalog` to capture only the recovered source catalog. Reports and images
are under `build/Other Files/Asset Toolkit/Painted Portrait HUD/Skins/`. Review visual matching
separately from technical route, model-ID, XP and resource-reuse assertions.

The 2026-11-16 Special skin additions append twelve recovered HUD heads, keeping
all existing painted images and routes. Uru's original key stays `35`; new skins
use their existing character/skin key. See
`assets/characters/crossgate/special-skins-README.md` for the source inventory.


The Uru inventory expansion adds 31 explicit `35:skin` routes using recovered
`uru-ID.png` heads. Original `35` keeps its approved painting; `46:109912`
keeps Rei's existing recovered head independently of Uru's `35:109912`.
All source heads and other heroes' routes remain preserved. The current Uru
inventory and verification are documented in `assets/characters/crossgate/ruby/README.md`.

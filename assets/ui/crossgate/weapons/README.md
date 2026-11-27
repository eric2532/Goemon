# Cross Gate weapon HUD sprites

## Beast Master

`beast-master.png` arranges four original standing pet sprites on a transparent
64×64 tile. Equipment, the weapon HUD and the all-pets hotbar slot share it.
The source family atlases and frame tables remain intact. Use action 0, frame 0
from each family, crop the transparent bounds, and resize proportionally with
nearest-neighbor sampling. For the bee, crop just above the separate ground
shadow before resizing.

| Sprite | Family skin and facing | Width | Placement |
| --- | --- | ---: | --- |
| 螳螂 | `mantises` 0, facing 4 | 29 | (2, 1) |
| 水龍 | `dragon_lizards` 1, facing 4 | 36 | (0, 34) |
| 蜜蜂 | `bees` 3, facing 5 | 29 | (34, 1) |
| 地獄犬 | `hounds` 0, facing 6 | 31 | (33, 26) |

## Approved red boxing gloves — 2026-11-25

The user selected classic red gloves (option A) to replace the Fist icon.
`defaults/boxing-gloves-red.png` is the shared Equipment/HUD icon; the display
name is Boxing Gloves. The stable `weapon:unarmed` item ID, unarmed attack
route, stats and equip restrictions stay unchanged. Equipment no longer applies
the earlier white fist tint. Both catalog-backed icons and the HUD's direct
stance preloads use the same new texture.

`source/boxing-gloves-red-master.png` and `source/boxing-gloves-red-prompt.md`
preserve the approved built-in image_gen artwork and preparation recipe. The
48×48 runtime derivative contains 35×38 visible pixels. Existing fist art and
all earlier masters remain intact; `defaults/provenance.json` records the new
art separately from the historical fist entry.

## Three-Weapon Combo icon — 2026-11-20

`three-weapon.png` puts Sword SW023 upright in front of crossed Spear SP015
and Axe AX012 in a 米 silhouette. Equipment and the active weapon tile share
this texture through `equipment.gd`. Reproduce it from the project root using
the archived catalog sprites:

```sh
python3 - <<'PY'
from pathlib import Path
from PIL import Image, ImageOps
root = Path('assets/ui/crossgate/weapons')
catalog = Path('build/Other Files/Asset Toolkit/Cross Gate Weapon Catalog/original-pngs')
nearest = Image.Resampling.NEAREST
icon = Image.new('RGBA', (64, 64))
for folder, code, angle, position in [
    ('spears', 'SP015', 7, (5, 11)),
    ('axes', 'AX012', -7, (15, 11)),
    ('swords', 'SW023', -45, (20, 3)),
]:
    path, = (catalog / folder).glob(f'{code}-*.png')
    source = Image.open(path).convert('RGBA')
    source = source.crop(source.getbbox())
    if folder == 'axes':
        source = ImageOps.mirror(source)
    posed = source.rotate(angle, expand=True, resample=nearest)
    posed = posed.crop(posed.getbbox())
    if folder == 'swords':
        posed = posed.resize((24, 57), nearest)
    assert position[0] + posed.width <= icon.width and position[1] + posed.height <= icon.height
    icon.alpha_composite(posed, position)
icon.crop(icon.getbbox()).save(root / 'three-weapon.png')
PY
```

## Selected UI defaults — 2026-11-15

The user selected SW044 (Sword), AX053 (Axe), SP002 (Spear), ST001 (Staff),
BW005 (Bow), KN008 (Dagger) and TH001 (Throwing). Cropped, unchanged source
pixels are under `defaults/`; exact source keys, serials, bounds and hashes are
recorded in `defaults/provenance.json`. The complete 694-record source catalog
and original PNGs remain in the Cross Gate Weapon Catalog under build evidence.

Fist uses the new original wrapped-fist pixel artwork, generated with built-in
image_gen. Its full-resolution master and exact prompt are preserved in
`source/`, excluded from imports/exports; the runtime derivative is 48×48 with
nearest-neighbor sampling and transparent alpha. The corrected design wraps
cloth bandages around the knuckles, hand and wrist, with a more compact footprint.
On 2026-11-16 the user selected option 1, the classic diagonal redraw, from five
Cross Gate-style choices. `source/fist-classic-master.png` and
`source/fist-classic-prompt.md` preserve the selected artwork and exact prompt.
The runtime icon is the exact selected 48×48 preview with 30px-high visible art.
It shares the other icons' unframed presentation without a heavy outer contour.
The old glove and all earlier generated masters are preserved.

Equipment inventory, the allowed-icons row, equipped slots, previews and generic
Cross Gate HUD stances reuse `equipment.gd`'s selected textures. The Dagger keeps
the existing `weapon:kunai` save ID and attack route for compatibility. Kunai is
reserved for a separate future item. `defaults/dagger.tres` centers KN008's
unchanged 24×23 pixels on a 37×37 transparent canvas, matching the sword's native
height so the dagger stays visibly smaller in every shared UI view. TH001 is saved as the Throwing UI default;
it does not add a boomerang or another equip permission. Native special-effect
stance icons keep their existing specific artwork. No combat animation, atlas,
attack contract, stat, restriction or saved weapon ID changes with this UI edit.

## Regular dagger flight — 2026-11-16

The shared thrown Dagger now uses KN008's selected regular silver blade and gold
crossguard, matching Equipment. `assets/characters/crossgate/maze/regular-dagger.png`
contains sixteen 48×48 flight cells, prepared with the existing nearest-neighbor
rotation recipe in `tools/recover_crossgate_kaz_skins.py::prepare_dagger`.
Rebuild it from the project root with:

```sh
PYTHONPATH=tools python3 -c "from recover_crossgate_kaz_skins import KAZ, prepare_dagger; prepare_dagger(KAZ.parent / 'maze')"
python3 -m unittest discover -s tools -p test_regular_dagger.py
```

The original `maze/dagger.png`, `dagger-icon.png` and source projectile metadata
remain preserved. Only the shared projectile texture changes: player throws,
Blade Dance and native copies reuse it; arrows keep their own atlas. Flight
cell size, pixel density, combat radius, speed, range, damage, release clocks,
saved IDs and source body animations stay under their existing owners.

## Preserved original UI artwork

These icons represent the active stance in the Z tile. They use original
inventory artwork selected by silhouette and color. The Fist and Unarmed
stances share a glove icon. Maze's Kunai reuses its existing
`assets/characters/crossgate/maze/dagger-icon.png` sprite.

The PNGs were decoded from the preserved Magic Power archive with
`tools/cg_library.py`'s `image_from_record(pack, row)`. Only transparent
margins were cropped.

| PNG | Pack | Row | Graphic serial |
| --- | --- | ---: | ---: |
| katana | original | 13963 | 20091 |
| sword | original | 13887 | 20015 |
| polearm | original | 13677 | 20405 |
| fist | v3 | 32 | 21300 |
| axe | original | 13372 | 20200 |
| red-sword | original | 13957 | 20085 |
| red-polearm | original | 13764 | 20492 |
| staff | original | 13800 | 20628 |

Staff is prepared by `tools/prepare_crossgate_weapons.py`. Character Gear uses
these same icons; weapon-specific full-body sprites remain separate from HUD art.

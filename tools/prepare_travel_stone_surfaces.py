"""Rectify original Cross Gate carving and material patches for solid travel props."""
from pathlib import Path
import json
from PIL import Image, ImageFilter, ImageStat

ROOT = Path(__file__).resolve().parents[1]
CELL = 256
# Clockwise corners in the preserved original sprite, without its silhouette/shadow.
PATCHES = {
    'bronze_carving': (17239, [(8,101),(19,106),(19,113),(8,108)]),
    'gold_rim': (17239, [(6,85),(18,91),(18,95),(6,89)]),
    'dark_bronze': (17239, [(20,115),(28,111),(28,114),(20,118)]),
    'moon_stone': (17239, [(6,44),(15,44),(15,58),(6,58)]),
    'post_carving': (17241, [(7,46),(14,49),(14,55),(7,52)]),
    'inscription_large': (17235, [(24,3),(44,15),(34,21),(16,10)]),
    'inscription_small': (17235, [(14,24),(23,29),(17,33),(8,28)]),
    'gold_plain': (17239, [(15,90),(18,91),(18,94),(15,93)]),
}


def build(output=ROOT/'assets/textures/wind_meadow/travel_stones'):
    output.mkdir(parents=True, exist_ok=True)
    art = Image.open(ROOT/'assets/maps/falan/travel_stone_ornaments.png').convert('RGBA')
    sizes = [(60,63), (68,62), (52,116), (48,138), (48,126), (48,137), (32,64)]
    atlas = Image.new('RGB', (4*CELL, 2*CELL))
    for i, (name, (serial, corners)) in enumerate(PATCHES.items()):
        index = serial-17235
        w,h = sizes[index]
        source = art.crop((index%4*144,index//4*144,index%4*144+w,index//4*144+h))
        ul,ur,lr,ll = corners
        patch = source.transform((240,240), Image.Transform.QUAD, (*ul,*ll,*lr,*ur), Image.Resampling.BICUBIC)
        assert patch.getchannel('A').getextrema()[0] == 255, name
        patch = patch.convert('RGB')
        if name in ['gold_rim','dark_bronze','moon_stone','gold_plain']:
            tone = tuple(round(v) for v in ImageStat.Stat(patch).mean)
            patch = Image.blend(patch.filter(ImageFilter.GaussianBlur(2)), Image.new('RGB',patch.size,tone), .65)
        tile = patch.resize((CELL,CELL),Image.Resampling.BICUBIC)
        tile.paste(patch,(8,8))
        for y in range(CELL):
            for x in range(CELL):
                if min(x,y)<8 or max(x,y)>=CELL-8:
                    tile.putpixel((x,y),patch.getpixel((min(239,max(0,x-8)),min(239,max(0,y-8)))))
        atlas.paste(tile,(i%4*CELL,i//4*CELL))
    atlas.save(output/'surface_paint.png')
    # Only the crystal's colored solid is used as face paint; its baked ground shadow is excluded.
    Image.open(ROOT/'assets/maps/falan/travel_stone.png').crop((0,0,56,60)).convert('RGB').save(output/'crystal_paint.png')
    (output/'source_patches.json').write_text(json.dumps(PATCHES,indent=2)+'\n')
    return atlas


if __name__ == '__main__':
    build()

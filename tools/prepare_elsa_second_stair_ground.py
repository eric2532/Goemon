"""Recover concealed parent paving only on original owned/open stair cells."""
import json
import math
from PIL import Image
import recover_elsa_island as source
import prepare_elsa_second_stair as stair
from prepare_elsa_gate import native_layers

RECT=(6120,60,6500,560)
PAVING_RECT=(6192,444,6256,492)


def build():
    _,native=native_layers([],RECT,59530)
    photo=Image.open(stair.OUT/'bg-photo-mask.png').convert('L')
    width,height,planes=source.reference_map(59530)
    _,_,labels,_=source.components(59530)
    scope=json.loads((source.REPORT/'scope.json').read_text())
    components=set(scope['rooms']['59530']['components'])
    _,tile=native_layers([],PAVING_RECT,59530)
    assert tile.size==(64,48)
    assert all(a==255 and min(r,g,b)>40 and max(r,g,b)-min(r,g,b)<18 for r,g,b,a in tile.getdata())
    tile.save(stair.OUT/'parent-paving-native-witness.png')
    paint=Image.new('RGBA',native.size);mask=Image.new('L',native.size);cells=set()
    for y in range(native.height):
        for x in range(native.width):
            u,v=x+RECT[0],y+RECT[1]
            tx,ty=(u-PAVING_RECT[0])%128,(v-PAVING_RECT[1])%96
            sample=tile.getpixel((tx if tx<64 else 127-tx,ty if ty<48 else 95-ty))
            # Continue RGB beneath zero alpha so mipmaps do not add black seams.
            paint.putpixel((x,y),(*sample[:3],0))
            cx,cy=math.floor(u/64-v/48+.5),math.floor(u/64+v/48+.5)
            if not (0<=cx<width and 0<=cy<height):continue
            index=cy*width+cx
            if planes[2][index] or labels[index] not in components:continue
            original=native.getpixel((x,y))
            px,py=u-stair.RECT[0],v-stair.RECT[1]
            relocated=0<=px<photo.width and 0<=py<photo.height and photo.getpixel((px,py))
            if original[3] and max(original[:3])>3 and not relocated:continue
            paint.putpixel((x,y),sample)
            mask.putpixel((x,y),255);cells.add((cx,cy))
    native.save(stair.OUT/'parent-ground-original.png')
    paint.save(stair.OUT/'parent-ground.png');mask.save(stair.OUT/'parent-ground-mask.png')
    record=dict(map=59530,candidate_only=True,origin=list(RECT[:2]),size=list(native.size),
                path='res://'+str((stair.OUT/'parent-ground.png').relative_to(source.ROOT)),
                pixels=sum(bool(v) for v in mask.tobytes()),cells=[list(p) for p in sorted(cells)],
                stair_photo_mask_sha256=source.sha(photo.tobytes()),
                source_rgba_sha256=source.sha(native.tobytes()),rgba_sha256=source.sha(paint.tobytes()),
                patches=[dict(native_rect=list(PAVING_RECT),rgba_sha256=source.sha(tile.tobytes()))],
                inference='Concealed parent paving repeats matching local original cobbles at native pixel scale. Original owned/open cells only; absent/black BG or relocated stair photographs. Every exposed source pixel stays exact. The existing CUT floor importer supplies original geometry and UVs; no new collision, walking, rooms or travel.')
    (stair.OUT/'parent-ground.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    from prepare_elsa_hall_entry_floor import compose_canonical_floor
    compose_canonical_floor(stair.OUT/'Parent Floor',stair.OUT)
    print('ELSA_BG_STAIR_PARENT_GROUND',record['pixels'],'pixels;',len(cells),'original owned/open cells',flush=True)


if __name__=='__main__':build()

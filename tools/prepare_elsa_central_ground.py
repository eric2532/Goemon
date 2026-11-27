"""Private parent-floor repair under the relocated central59530 photographs.

Only archived open cells inside the removed source silhouettes receive paint.
Nearby original paving supplies the hidden continuation; no walking data changes.
"""
import json
import math
from PIL import Image, ImageChops
import recover_elsa_island as source
import prepare_elsa_central_assembly as central
import prepare_elsa_central_portal as portal
from prepare_elsa_gate import native_layers

OUT=central.OUT/'Steps'


def build():
    native=Image.open(central.OUT/'414-422-native.png').convert('RGBA')
    mask=native.getchannel('A').point(lambda a:255 if a else 0)
    bg_mask=Image.open(portal.OUT/'bg-photo-mask.png').convert('L')
    relocated=Image.new('L',native.size)
    relocated.paste(bg_mask,(portal.RECT[0]-central.ORIGIN[0],portal.RECT[1]-central.ORIGIN[1]))
    mask=ImageChops.lighter(mask,relocated)
    width,height,planes=source.reference_map(59530)
    cells=set()
    for y in range(native.height):
        for x in range(native.width):
            if not mask.getpixel((x,y)):continue
            u,v=x+central.ORIGIN[0],y+central.ORIGIN[1]
            cx=math.floor(u/64-v/48+.5);cy=math.floor(u/64+v/48+.5)
            if not(0<=cx<width and 0<=cy<height) or planes[2][cy*width+cx]:
                mask.putpixel((x,y),0)
            else:cells.add((cx,cy))
    padding=192
    rect=(central.ORIGIN[0]-padding,central.ORIGIN[1]-padding,
          central.ORIGIN[0]+native.width+padding,central.ORIGIN[1]+native.height+padding)
    _,background=native_layers([],rect,59530)
    # The relocated BG arch/post photographs are no longer parent-floor paint.
    background.putalpha(ImageChops.subtract(background.getchannel('A'),
        bg_mask.transform(background.size,Image.Transform.AFFINE,(1,0,rect[0]-portal.RECT[0],0,1,rect[1]-portal.RECT[1]))))
    # A confirmed, entirely paved CUT avoids sampling nearby walls/rail photos.
    serial=1856;tile,offset,cut=source.cut_image(59530,serial)
    assert planes[0][92*width+99]==serial and tile.size==(64,48)
    assert all(a==255 and min(r,g,b)>40 for r,g,b,a in tile.getdata())
    paint=Image.new('RGBA',native.size)
    # Infill owns concealed/dark pixels only; preserve exposed source BG in place.
    own=mask.copy()
    for y in range(native.height):
        for x in range(native.width):
            original=background.getpixel((x+padding,y+padding))
            if original[3] and max(original[:3])>40:own.putpixel((x,y),0)
            if not own.getpixel((x,y)):continue
            # Reflect alternate copies: continuous edges, unchanged native texels
            # and scale. This is inferred paving, not an original hidden design.
            u,v=x+central.ORIGIN[0],y+central.ORIGIN[1]
            tx=u%128;ty=v%96
            paint.putpixel((x,y),tile.getpixel((tx if tx<64 else 127-tx,ty if ty<48 else 95-ty)))
    paint.putalpha(own);paint.save(OUT/'ground-infill.png');own.save(OUT/'ground-infill-mask.png')
    record=dict(map=59530,candidate_only=True,origin=list(central.ORIGIN),size=list(native.size),
        cells=[list(p) for p in sorted(cells)],pixels=sum(bool(v) for v in own.tobytes()),
        background_rect=list(rect),background_sha256=source.sha(background.tobytes()),
        rgba_sha256=source.sha(paint.tobytes()),patches=[dict(serial=serial,cell=[99,92],origin=list(offset),cut=list(cut),rgba_sha256=source.sha(tile.tobytes()),repeat='mirrored at native pixel scale')],
        inference='Concealed paving copied from nearby original BG; clipped to original open cells and relocated photographs. No collision, navigation or travel changes.')
    (OUT/'ground-infill.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_CENTRAL_GROUND',record['pixels'],'concealed pixels;',len(cells),'original open cells; native paving CUT',serial,flush=True)


if __name__=='__main__':build()

"""Four rejected reverse-shell prototypes; exact native front/ground partition."""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw
from prepare_east_nature import ROOT,sources
OUT=ROOT/'assets/maps/falan/east_region/round_cactus'
# Source-pixel contours separate the observed plant from the painted sand.
# Round sections reuse existing lathe geometry; hidden rib sections are inferred.
FORMS={
11746:dict(polygon=[[22,0],[34,2],[42,12],[43,27],[37,44],[26,52],[15,49],[7,44],[1,27],[1,15],[8,5]],parts=[[0,0,43,52]],grain_box=[18,17,30,32],profile=[[0,.65],[.15,.94],[.65,1],[.88,.85],[1,.12]]),
11782:dict(polygon=[[23,0],[35,5],[43,16],[47,25],[42,32],[31,34],[19,35],[6,31],[2,22],[4,12],[13,5]],parts=[[0,0,47,35]],grain_box=[17,7,29,19],profile=[[0,.85],[.18,1],[.52,.95],[.82,.6],[1,.13]]),
11785:dict(polygon=[[21,0],[29,4],[36,9],[42,20],[43,30],[36,38],[23,40],[10,37],[2,31],[1,20],[8,10],[14,6]],parts=[[0,7,44,40]],grain_box=[16,13,30,28],details=[[13,0,30,12]],profile=[[0,.7],[.2,.96],[.5,1],[.80,.72],[1,.12]]),
11786:dict(polygon=[[20,0],[31,3],[38,12],[39,23],[45,31],[47,41],[41,47],[26,49],[14,43],[5,33],[1,24],[1,13],[8,4]],parts=[[0,0,39,38],[20,25,47,48]],grain_box=[11,10,24,24],part_grain_boxes=[[11,10,24,24],[29,32,39,41]],details=[[28,18,42,30]],profile=[[0,.68],[.2,.96],[.5,1],[.80,.72],[1,.12]]),
}
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
    table,_,pins=sources();pages={};rows={};OUT.mkdir(parents=True,exist_ok=True)
    for serial,form in FORMS.items():
        g,path=table[serial]
        if path not in pages:pages[path]=Image.open(path).convert('RGBA')
        x,y,w,h=g['rect'];original=pages[path].crop((x,y,x+w,y+h));assert sha(original.tobytes())==g['rgba_sha256']
        mask=Image.new('1',original.size);ImageDraw.Draw(mask).polygon([tuple(p) for p in form['polygon']],fill=1)
        body=original.copy();ground=original.copy();detail=original.copy();detail_mask=Image.new('1',original.size)
        for box in form.get('details',[]):
            for yy in range(box[1],box[3]):
                for xx in range(box[0],box[2]):
                    r,green,b,a=original.getpixel((xx,yy))
                    flower=(r>120 and green>90 and r>b*1.5 and green>b*1.5) if serial==11785 else (r>100 and r>green*1.2 and r>b*1.4)
                    if a and flower:detail_mask.putpixel((xx,yy),1)
        for yy in range(h):
            for xx in range(w):
                p=original.getpixel((xx,yy));is_body=mask.getpixel((xx,yy));is_detail=is_body and detail_mask.getpixel((xx,yy));body.putpixel((xx,yy),(*p[:3],p[3] if is_body and not is_detail else 0));ground.putpixel((xx,yy),(*p[:3],0 if is_body else p[3]));detail.putpixel((xx,yy),(*p[:3],p[3] if is_detail else 0))
        # Small body-only RGB sample: opaque independently repeated hidden grain,
        # never the front silhouette, flower, sand or complete facade.
        part_grains=[]
        for index,box in enumerate(form.get('part_grain_boxes',[form['grain_box']])):
            gx,gy,gr,gb=box;colors=[body.getpixel((xx,yy))[:3] for yy in range(gy,gb) for xx in range(gx,gr) if body.getpixel((xx,yy))[3]>=128]
            assert colors;mean=[sum(p[c] for p in colors)/len(colors) for c in range(3)];tile=Image.new('RGBA',(128,128))
            for yy in range(128):
                for xx in range(128):
                    source=colors[((xx//3)*37+(yy//3)*71+(xx//3)*(yy//3)*11)%len(colors)]
                    tile.putpixel((xx,yy),(*(round(source[c]*.35+mean[c]*.65) for c in range(3)),255))
            name=f'{serial}-grain'+(f'-{index}' if index else '')+'.png';tile.save(OUT/name);part_grains.append(name)
        for name,image in [('body',body),('ground',ground),('detail',detail)]:image.save(OUT/f'{serial}-{name}.png')
        attachments=[]
        for index,box in enumerate(form.get('details',[])):
            detail.crop(tuple(box)).save(OUT/f'{serial}-detail-{index}.png')
            points=[(xx,yy) for yy in range(box[1],box[3]) for xx in range(box[0],box[2]) if detail.getpixel((xx,yy))[3]>=128];assert points
            bottom=max(p[1] for p in points);base=[sum(p[0]+.5 for p in points if p[1]==bottom)/sum(p[1]==bottom for p in points),bottom+.5];attachments.append(base)
        derivatives={p.name:sha(Image.open(p).convert('RGBA').tobytes()) for p in sorted(OUT.glob(f'{serial}-*.png'))}
        rows[str(serial)]=dict(graphic=serial,origin=g['origin'],footprint=g['footprint'],source_rgba_sha256=g['rgba_sha256'],source_size=[w,h],detail_attachments=attachments,part_grains=part_grains,derived_rgba_sha256=derivatives,**form,inference='Existing round-profile primitive fits measured native plant bounds; ribs and hidden rounded continuation are inferred. Sand stays flat. Independent body-only grain repeats around the hidden volume; the blue/olive pair retains separate observed body palettes. Flower/body/ground are an exact three-way native RGBA partition; flower attachment uses its last opaque source pixel.')
    data=dict(schema=1,scope='PRIVATE four-form reverse repair prototype, no live hook.',source_catalogs=pins,graphics=rows)
    (OUT/'data.json').write_text(json.dumps(data,indent=2)+'\n');print('ROUND_CACTUS_PROTOTYPES',len(rows))
if __name__=='__main__':prepare()

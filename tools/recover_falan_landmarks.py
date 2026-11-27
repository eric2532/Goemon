"""Rectify original landmark ornaments; keep the archive and shared village paint intact."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import sys
from PIL import Image, ImageChops, ImageDraw
from build_village_building_surfaces import surface_atlas, PATCHES as VILLAGE_PATCHES, CELL, INSET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan'
PATCHES = {
    'bank_sign': (10010, [(103,224),(173,269),(173,319),(103,274)], True, (112,80)),
    'inn_sign': ('inn_front', [(105,116),(180,165),(180,223),(105,174)], True, (112,80)),
    'healer': (10602, [(255,238),(278,253),(278,286),(255,271)], True, (48,72)),
    'guild_banner': (10604, [(264,232),(317,197),(317,265),(264,300)], True, (72,112)),
    'inn_window': (10004, [(148,348),(170,362),(170,397),(148,383)], True, (40,112)),
    'bank_window': (10010, [(399,248),(411,240),(411,276),(399,284)], True, (40,96)),
    'hospital_window': (10602, [(241,169),(251,176),(251,203),(241,196)], True, (40,80)),
    'guild_window': (10604, [(153,284),(168,274),(168,316),(153,326)], True, (36,100)),
    'office_pennant': (10607, [(138,249),(144,243),(144,276),(138,282)], True, (24,112)),
    'office_porch_face': (10607, [(60,211),(120,254),(120,278),(60,235)], True, (112,35)),
    'office_right_window': (10607, [(160,282),(183,298),(183,370),(160,354)], True, (40,112)),
    'office_lower_front': (10607, [(147,361),(155,366),(155,400),(147,395)], True, (24,102)),
    'office_lower_side': (10607, [(240,381),(247,376),(247,410),(240,415)], True, (24,102)),
    'office_side_near': (10607, [(229,251),(239,245),(239,291),(229,297)], True, (24,110)),
    'office_side_far': (10607, [(311,194),(321,188),(321,234),(311,240)], True, (24,110)),
    'castle_clock': (10012, [(180,226),(212,251),(212,278),(180,253)], True, (96,96)),
    'cathedral_window': ('cathedral', [(330,503),(345,514),(345,592),(330,581)], True, (32,112)),
    'cathedral_bell': ('cathedral', [(57,238),(74,247),(74,272),(57,263)], True, (40,72)),
    'inn_side_sign': ('inn_side', [(283,239),(350,197),(350,245),(283,287)], True, (112,80)),
}
INN_SIDE_OUTLINE=[(285,251),(288,245),(297,237),(315,224),(334,213),(344,209),(348,210),(349,215),(349,242),(286,281)]
INN_FRONT_OUTLINE=[(106,121),(112,121),(180,165),(183,170),(183,224),(176,227),(104,178),(104,124)]
FACADES = {1201:(10001,'cathedral_window'),1091: (10607,'office_window'),1092:(10604,'guild_window'),1101:(10004,'inn_window'),
           1111:(10602,'hospital_window'),1112:(10602,'hospital_window'),1121:(10010,'bank_window')}
REUSE = {'office_window':'church_window','office_rosette':'medallion'}


def rect(index, size):
    patch = Image.new('RGBA', size)
    patch.thumbnail((CELL-INSET*2,CELL-INSET*2), Image.Resampling.LANCZOS)
    w,h = patch.size
    return (index%4*CELL+INSET+(112-w)//2,index//4*CELL+INSET+(112-h)//2,w,h)


def prepare(source):
    sys.path.insert(0,str(source/'tools'))
    import cg_library as library
    lookup = library.serial_index()
    images, provenance = {}, {}
    serials = {p[0] for p in PATCHES.values()} | {VILLAGE_PATCHES[name][0] for name in REUSE.values()}
    for serial in serials:
        if serial == 'cathedral':
            controls=(OUT/'city_proportion_references.gd').read_text().split('const PAINT={',1)[1]
            x,y,w,h=map(int,re.search(r'"civic_1201":Rect2\((\d+),(\d+),(\d+),(\d+)\)',controls).groups())
            with Image.open(OUT/'city_civic_source_paint.png') as paint, Image.open(OUT/'city_civic_source_mask.png') as mask:
                image=paint.crop((x,y,x+w,y+h)).convert('RGBA');image.putalpha(mask.crop((x,y,x+w,y+h)))
            images[serial]=image
            reference=json.loads((OUT/'city_proportion_references.json').read_text())['records']['civic_1201']
            provenance[serial]={'source':'Original 10001 plus its recovered ground-layer facade pieces','parts':reference['rgba_hashes'],'rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest()}
            continue
        entry = lookup[10004 if serial in ('inn_side','inn_front') else serial]
        image = library.image_from_record(entry['pack'],entry['row'])
        provenance[serial] = {'pack':entry['pack'],'row':entry['row'],
                              'rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest()}
        if serial in ('inn_side','inn_front'):
            outline=INN_SIDE_OUTLINE if serial=='inn_side' else INN_FRONT_OUTLINE
            mask=Image.new('L',image.size);ImageDraw.Draw(mask).polygon(outline,fill=255)
            image=image.copy();image.putalpha(ImageChops.multiply(image.getchannel('A'),mask))
            provenance[serial]['source_graphic']=10004
            provenance[serial]['source_mask']=outline
        images[serial] = image
    atlas,_ = surface_atlas(images,PATCHES)
    # Retain only the original dark healer engraving; the 3D wall supplies its stone.
    i = list(PATCHES).index('healer')
    x,y,w,h = rect(i,PATCHES['healer'][3])
    for py in range(y,y+h):
        for px in range(x,x+w):
            r,g,b,a = atlas.getpixel((px,py))
            atlas.putpixel((px,py),(r,g,b,min(a,max(0,min(255,(145-min(r,g,b))*12)))))
    rows = ['extends RefCounted','## Generated by tools/recover_falan_landmarks.py; source facade paint.',
            'const ATLAS=preload("res://assets/maps/falan/city_landmark_details.png")',
            'const VILLAGE=preload("res://assets/maps/falan/village_building_surfaces.png")','const FEATURES={']
    for i,(name,patch) in enumerate(PATCHES.items()):
        rows.append(f' "{name}":[ATLAS,Rect2{rect(i,patch[3])}],')
    for name,original in REUSE.items():
        i = list(VILLAGE_PATCHES).index(original)
        rows.append(f' "{name}":[VILLAGE,Rect2{rect(i,VILLAGE_PATCHES[original][3])}],')
    rows += ['}','const FACADES={']
    rows += [f' {floor}:[{serial},"{feature}"],' for floor,(serial,feature) in FACADES.items()]
    rows.append('}')
    meta = {'graphics':provenance,'patches':PATCHES,'reused_village_features':REUSE,'facades':FACADES,'ink_only_features':['healer'],
            'method':'Rectified original windows and facade ornaments on solid 3D buildings. Fitted placement is an interpretation, not exact recovered geometry.'}
    return atlas,'\n'.join(rows)+'\n',meta


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    atlas,data,meta=prepare(args.source.resolve())
    path=OUT/'city_landmark_details'
    if args.check:
        with Image.open(path.with_suffix('.png')) as actual: assert actual.tobytes()==atlas.tobytes()
        assert path.with_suffix('.gd').read_text()==data
        assert json.loads(path.with_suffix('.json').read_text())==json.loads(json.dumps(meta))
        print('PASS: landmark source paint, shared feature reuse and',len(FACADES),'facade bindings reproduce exactly')
    else:
        atlas.save(path.with_suffix('.png'),optimize=True)
        path.with_suffix('.gd').write_text(data)
        path.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
        print('Recovered',len(PATCHES),'native panels and reused two existing office features for',len(FACADES),'facades')

if __name__=='__main__': main()

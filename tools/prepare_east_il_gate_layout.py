"""Private exact source2000/source100 gate-layout records; originals unchanged."""
import hashlib
import json
from math import hypot
from pathlib import Path
import sys

from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Gate'
IDS={11032,11077,11078,11140,11141,11142,11144,11147,11148}


def main():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    files={2000:ROOT/'assets/maps/falan/east_region/il_source_completion/hybrid-map.bin',
           100:ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/100.dat'}
    maps={};graphics={};lookup=lib.serial_index()
    for source,path in files.items():
        width,height,bg,pg,flags=lib.parse_map(path.read_bytes());offset=(0,0) if source==2000 else (636,312);rows=[]
        for i,serial in enumerate(pg):
            x,z=i%width,i//width;nx,nz=x-offset[0],z-offset[1]
            if serial not in IDS or hypot(nx-45,nz-31)*3. >= 40.:continue
            graphic=lookup[serial];east,south=max(1,graphic['east']),max(1,graphic['south'])
            rows.append({'cell':[x,z],'village_axis_cell':[nx,nz],'graphic':serial,'floor':bg[i],'marker':flags[i],
                         'relative_to_warpcenter':[(nx-45)*3,(nz-31)*3],
                         'footprint_cells':[x,z-south+1,east,south]})
            if serial not in graphics:
                image=lib.image_from_record(graphic['pack'],graphic['row']).convert('RGBA')
                graphics[serial]={'serial':serial,'pack':graphic['pack'],'row':graphic['row'],'size':list(image.size),
                                  'origin':[graphic['x'],graphic['y']],'footprint':[east,south],'ground':graphic['ground'],
                                  'native_rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest()}
        maps[source]={'warpcenter':[45,31] if source==2000 else [681,343],'source_rows':rows,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    a={tuple(r['village_axis_cell']+[r['graphic']]) for r in maps[2000]['source_rows']}
    b={tuple(r['village_axis_cell']+[r['graphic']]) for r in maps[100]['source_rows']}
    assert len(a)==25 and len(b)==24 and a-b=={(49,33,11147),(50,33,11148)} and b-a=={(49,33,11148)}
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').touch()
    for serial,graphic in graphics.items():
        lib.image_from_record(graphic['pack'],graphic['row']).save(OUT/f'{serial}-native.png')
    # Diagnostic thumbnails only. Runtime art continues to use untouched native
    # partitions/masters; this contact sheet is never an asset input.
    small=sorted(serial for serial in graphics if serial!=11032);sheet=Image.new('RGB',(4*240,2*250),'#e8dfc8');draw=ImageDraw.Draw(sheet)
    for i,serial in enumerate(small):
        image=Image.open(OUT/f'{serial}-native.png').convert('RGBA');image.thumbnail((220,205));x,y=(i%4)*240,(i//4)*250
        sheet.paste(image,(x+(240-image.width)//2,y+28+(205-image.height)//2),image)
        draw.text((x+8,y+5),f'{serial}  {graphics[serial]["footprint"]} ground={graphics[serial]["ground"]}',fill='#181816')
    sheet.save(OUT/'native-gate-parts.jpg',quality=94)
    report={'scope':'PRIVATE gate source-layout proof. No meshes, colliders, route radius, shared kit or map bytes changed.',
            'maps':maps,'graphics':graphics,'source_tuple_translation':[636,312],
            'common_rows':23,'village_only':[list(row) for row in sorted(a-b)],'source100_only':[list(row) for row in sorted(b-a)],
            'reuse_contract':['Pure11077/11078leaf/post meshes retain their original-owner Y; no secondYfit.',
                             'The existing lookout tower is compatible at warpcenter: native11032anchor(42,25)/center(43,24),3x3footprint,17.055m measured roof versus kit17.05m.',
                             'The procedural palisade rectangles are a reusable kit, not an exact25rowlayout. Preserve the known11148end-wall position independently in each original map.',
                             'Reuse timber/stone/native wall parts at their exact original cells. Retain sourceclosed footprint/warp ownership; do not add a door or collider route.'],
            'pending':['Exact source-row palisade meshes/normal+reverse asset review and original-cell collision clearance.',
                       'Actual low2000and original100 normal/second gate views; source table entry/return and existing event ownership.'],
            'source_hashes':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in [Path(__file__),*files.values(),ROOT/'scripts/forest/forest_freyja_destination_art.gd',ROOT/'scripts/forest/forest_east_il_gate_parts.gd']}}
    (OUT/'source-contract.json').write_text(json.dumps(report,indent=2)+'\n');print('Private original gate source rows:Il25/host24/common23; source100 native wall is one cell shorter.')


if __name__=='__main__':main()

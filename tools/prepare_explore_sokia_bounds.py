"""Extend derived Sokia fitting data to the already completed original cells."""
import base64
import copy
import hashlib
import json
from pathlib import Path
import sys
import zlib
ROOT=Path(__file__).resolve().parents[1]
FIELDS=['visible_bounds','solid_bounds','void_cliffs','cap_pixels','wall_caps']

def main():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    fixed_path=ROOT/'assets/maps/falan/sokia/fixed/catalog.json'
    fixed=json.loads(fixed_path.read_text())['maps'];lookup=lib.serial_index()
    path=ROOT/'assets/maps/original_crossgate/explore_recovered/catalog.json';data=json.loads(path.read_text());reports=[]
    for key,row in data['layout_overrides'].items():
        if key not in fixed:continue
        original=fixed[key]
        for field in FIELDS:row[field]=copy.deepcopy(original[field])
        raw=zlib.decompress(base64.b64decode(row['restored_raw']))
        _,_,floor,objects,_=lib.parse_map(raw);added=[]
        for serial in sorted({s for s in floor if s}|{s for s in objects if s>=1000}):
            if str(serial)in row['visible_bounds']:continue
            g=lookup[serial];image=lib.image_from_record(g['pack'],g['row']);box=image.getbbox()
            if box:
                row['visible_bounds'][str(serial)]=[g['x']+box[0],g['y']+box[1],box[2]-box[0],box[3]-box[1]];added.append(serial)
            if 12500<=serial<13400 or 17840<=serial<=17875:
                body=image.copy();body.putdata([(r,g,b,a if max(r,g,b)>45 else 0)for r,g,b,a in image.getdata()]);bounds=body.getbbox()
                if bounds:row['solid_bounds'][str(serial)]=[g['x']+bounds[0],g['y']+bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]]
                elif serial not in row['void_cliffs']:row['void_cliffs'].append(serial)
        row['fixed_bounds_complete']=True
        row['fixed_bounds_provenance']={'basis':'Existing Sokia alpha bounds and >45RGB solid-cliff filtering, applied to exact source sprites for completed cells. Original fitting entries are preserved.','original_catalog_sha256':hashlib.sha256(fixed_path.read_bytes()).hexdigest(),'added_visible_bounds':added}
        for field in FIELDS:
            old=original[field]
            assert all(row[field][k]==v for k,v in old.items())if isinstance(old,dict)else all(v in row[field]for v in old)
        reports.append({'map':row['id'],'added_visible_bounds':added})
    path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    out=ROOT/'build/Other Files/Asset Toolkit/Explore Access/sokia-completed-source-bounds.json'
    out.write_text(json.dumps({'qualification':'Derived source-image fit metadata only. Original raw maps, all existing fit entries and bitmap masters are unchanged. Actual rendered routes remain separate.','maps':reports},ensure_ascii=False,indent=2)+'\n')
    print('SOKIA_COMPLETED_SOURCE_BOUNDS',reports)

if __name__=='__main__':main()

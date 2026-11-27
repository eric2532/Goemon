"""Read-only native-object census for the proposed bounded East Nature owner."""
import hashlib,json
from collections import Counter
from pathlib import Path
from review_east_backgrounds import ROOT,CATALOG,decode

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Owned240'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
    catalog=json.loads(CATALOG.read_text());nature_path=ROOT/'assets/maps/falan/east_region/nature/data.json';nature=json.loads(nature_path.read_text());ids={int(s) for s in nature['graphics']}-{11699}
    placements=[];maps={};counts=Counter()
    for row in catalog['maps'].values():
        w,h,raw,values,bits,aliases=decode(row);mid=int(row['id']);n=w*h;selected=[]
        for i,native in enumerate(values[n:]):
            serial=aliases.get(native,native)
            if serial in ids:selected.append([mid,i%w,i//w,serial]);counts[serial]+=1
        maps[str(mid)]=dict(size=[w,h],source_raw_sha256=sha(raw),legacy_owner=bool(row.get('east_existing_owner',False)),placements=len(selected))
        placements.extend(selected)
    OUT.mkdir(parents=True,exist_ok=True)
    report=dict(scope='Read-only full717active fixed-map object-plane census. Contextual owner evaluation is separate; generated decoration dependencies do not imply fixed placements.',catalog_sha256=sha(CATALOG.read_bytes()),nature_data_sha256=sha(nature_path.read_bytes()),candidate_ids=sorted(ids),excluded=[11699],maps=maps,placements=placements,counts={str(s):counts[s] for s in sorted(ids)})
    (OUT/'native-placements.json').write_text(json.dumps(report,separators=(',',':'))+'\n')
    print('NATURE_NATIVE_CENSUS maps=',len(maps),'placements=',len(placements),'used_ids=',len(counts),'unused_ids=',len(ids-set(counts)))
if __name__=='__main__':prepare()

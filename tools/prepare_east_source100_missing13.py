"""PRIVATE source contract for13current-field rows omitted by generic filters."""
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_library as lib
import cg_assets as cg
from prepare_field_assets import navigation_grid
B=ROOT/'build/Other Files/Asset Toolkit/East Gate Region';OUT=B/'Runtime Audit/Source100 Missing13'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
 report=B/'Runtime Audit/Source100 Scene Owners/review.json';scene=json.loads(report.read_text());rows=[r for r in scene['prepared219']if not r['present']];assert len(rows)==13 and not scene['source_changed'];source=B/'Runtime Audit/Source100 Candidate/100.dat';w,h,g,o,f=lib.parse_map(source.read_bytes());lookup=lib.serial_index();walk=navigation_grid(w,h,g,o,lookup);field=json.loads((ROOT/'assets/maps/falan/east_region/field-scenery.json').read_text());records=[]
 for row in rows:
  x,y=map(int,row['cell']);serial=int(row['native_graphic']);i=y*w+x;assert o[i]==serial;category=row['prepared_pinned_field_owner'];source_row=next(r for r in field['east_gate'][category]if list(map(int,r[:2]))==[x,y]and int(r[2])==serial);entry=lookup[serial];attrs=cg.RECORD.unpack_from(cg.graphic_index(entry['pack'])[0],entry['row']*40)[7];near=[]
  for yy in range(max(0,y-2),min(h,y+3)):
   for xx in range(max(0,x-2),min(w,x+3)):
    at=yy*w+xx;near.append(dict(cell=[xx,yy],ground=g[at],object=o[at],native_open=bool(walk[at])))
  records.append(dict(cell=[x,y],native_graphic=serial,category=category,source_row=source_row,ground=g[i],native_open_at_anchor=bool(walk[i]),source_footprint=list(attrs[:2]),object_walk_attribute=int(attrs[2]),source_neighborhood=near,rule='Source placement is confirmed. Runtime filters must be diagnosed before any visual-only private bypass; no current walk/closed cell, link, collider or encounter changes.'))
 OUT.mkdir(parents=True,exist_ok=True);d=dict(scope='PRIVATE stage contract only;13exact source object anchors. Not live, not visual acceptance.',source_raw_sha256=sha(source.read_bytes()),scene_report_sha256=sha(report.read_bytes()),scene_inputs=scene['source_hashes'],records=records,counts=dict(trees=sum(r['category']=='trees'for r in records),details=sum(r['category']=='details'for r in records)),gate_policy='Hold any placement intersecting a protected entrance until its original event/approach contract is verified. Do not relax a shared generic filter.');(OUT/'source.json').write_text(json.dumps(d,indent=2)+'\n');print('SOURCE_MISSING13',d['counts'])
if __name__=='__main__':prepare()

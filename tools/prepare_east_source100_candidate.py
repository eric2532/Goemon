"""PRIVATE unknown-only East/north-coast source100 raw/native-ground supplement."""
import hashlib,json,os,sys
from collections import Counter
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_library as lib
from build_freyja_surface import build as build_ground
B=ROOT/'build/Other Files/Asset Toolkit/East Gate Region';OUT=B/'Runtime Audit/Source100 Candidate'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
 audit=json.loads((B/'Runtime Audit/Source100 Completeness/report.json').read_text());base=ROOT/'assets/maps/falan/freyja_source/100.dat';full=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat';raw=base.read_bytes();reference=full.read_bytes();assert sha(raw)==audit['active_sha256']and sha(reference)==audit['full_compatible_candidate_sha256'];w,h,g,o,flags=lib.parse_map(raw);fw,fh,fg,fo,ff=lib.parse_map(reference);assert(w,h)==(fw,fh)and flags==ff;n=w*h;candidate=bytearray(raw);allowed=set();changed=[]
 for area,row in audit['areas'].items():
  for x,y,oldg,oldo,newg,newo,flag in row['missing_raw_cells']:
   i=y*w+x;assert i not in allowed and not flags[i]&0xc000 and[g[i],o[i]]==[oldg,oldo]and[fg[i],fo[i]]==[newg,newo];allowed.add(i)
   for plane in[0,1]:at=20+(plane*n+i)*2;candidate[at:at+2]=reference[at:at+2]
   changed.append(dict(cell=[x,y],area=area,before=[oldg,oldo],after=[newg,newo]))
 assert len(allowed)==42662;result=bytes(candidate);rw,rh,rg,ro,rf=lib.parse_map(result);assert(rw,rh)==(w,h)and rf==flags
 assert all((rg[i],ro[i])==(fg[i],fo[i])if i in allowed else(rg[i],ro[i])==(g[i],o[i])for i in range(n));assert all((rg[i],ro[i])==(g[i],o[i])for i,f in enumerate(flags)if f&0xc000)
 OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').touch();(OUT/'100.dat').write_bytes(result);state=json.loads((ROOT/'assets/maps/falan/freyja_source/provenance.json').read_text());state.update(active=False,active_sha256=sha(result),stage='PRIVATE-East-core-unknown-only',active_layout_complete=False,whole_map100_active=False,completion_scope='Only42662unrecordedtuples in the audited114874core field cells. OpaqueCity,joinedIl/Alyut and1956neighbor-goal outliers remain unchanged.',protected_active_sha256=sha(raw));(OUT/'provenance.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
 previous=os.environ.get('CROSSGATE_FREYJA_SOURCE_DIR');os.environ['CROSSGATE_FREYJA_SOURCE_DIR']=str(OUT)
 try:indices=build_ground(ROOT.parent/'Magic Power',OUT,100)
 finally:
  if previous is None:os.environ.pop('CROSSGATE_FREYJA_SOURCE_DIR',None)
  else:os.environ['CROSSGATE_FREYJA_SOURCE_DIR']=previous
 old_index=Image.open(ROOT/'assets/maps/falan/freyja_ground_index.png').convert('RGBA');new_index=Image.open(OUT/'freyja_ground_index.png').convert('RGBA');old_atlas=Image.open(ROOT/'assets/maps/falan/freyja_ground_atlas.png').convert('RGB');new_atlas=Image.open(OUT/'freyja_ground_atlas.png').convert('RGB');assert new_atlas.crop((0,0,old_atlas.width,old_atlas.height)).tobytes()==old_atlas.tobytes();assert all(new_index.getpixel((i%w,i//w))==old_index.getpixel((i%w,i//w))for i in range(n)if i not in allowed)
 index_changes=[]
 for row in changed:
  x,y=row['cell'];a=old_index.getpixel((x,y));b=new_index.getpixel((x,y))
  if a!=b:index_changes.append(dict(cell=[x,y],native_ground=rg[y*w+x],before=list(a),after=list(b)))
 proof=dict(scope='PRIVATE reviewable raw/native-ground candidate only; no production files or scenery placement changed.',source_active_sha256=sha(raw),source_full_sha256=sha(reference),candidate_sha256=sha(result),known_tuples_preserved=sum(bool(f&0xc000)for f in flags),all_client_flags_preserved=True,all_outside_allowed_tuples_preserved=n-len(allowed),allowed_core_field_cells=sum(r['counts']['field_cells']for r in audit['areas'].values()),changed_raw_tuples=len(changed),changed_raw_cells=changed,index_changes=len(index_changes),index_changes_by_ground=dict(Counter(r['native_ground']for r in index_changes)),native_ground_index_additions=index_changes,protected_index_rgba_sha256=sha(old_index.tobytes()),candidate_index_rgba_sha256=sha(new_index.tobytes()),protected_atlas_rgb_sha256=sha(old_atlas.tobytes()),candidate_atlas_rgb_sha256=sha(new_atlas.tobytes()),original_atlas_prefix_preserved=True,original_atlas_size=list(old_atlas.size),candidate_atlas_size=list(new_atlas.size),reuse='Existing build_freyja_surface.build, original project_tile and graphic decoder. Existing native slots/pixels remain exact; only missing native bindings append.',scenery='Not authored or duplicated here. The292missing raw PG1anchors require existing219scene-owner proof and73older-owner checks.',unaccepted=['No shared publication or active field completion claim.','No runtime Native/camera/collision or visual route acceptance.','Native water identity additions are source-backed original frames; runtime sea/backdrop behavior remains a separate owner.'])
 (OUT/'preservation.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n');print('EAST100_CANDIDATE',len(changed),'raw',len(index_changes),'index','known',proof['known_tuples_preserved'],'atlas',new_atlas.size)
 return proof
if __name__=='__main__':prepare()

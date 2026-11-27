"""Stage24 audited unknown tuples; never write the active merged100 input."""
import base64
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import struct
import sys

from PIL import Image
from build_falan_room_art import COLS,STRIDE,project_tile

ROOT=Path(__file__).resolve().parents[1]
REGION=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
BASE=REGION/'Village Props/Cliff Audit/Source Context Audit/Prototype'
OUT=BASE/'Bridge24 Candidate'
AUDIT=REGION/'Runtime Audit/Source100 Bridge Edge Audit/reference-owner-piece-addendum.json'
REFERENCE=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat'
CANONICAL=ROOT/'assets/maps/falan/freyja_source/100.dat'
CITY_ATLAS=ROOT/'assets/maps/falan/city_paving_atlas.png'

def digest(raw):return hashlib.sha256(raw).hexdigest()
def sha(path):return digest(path.read_bytes())
def label(path):
 try:return str(path.relative_to(ROOT))
 except ValueError:return str(path)
def encoded(value):return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
def png(image):
 target=io.BytesIO();image.save(target,format='PNG',optimize=True);return target.getvalue()
def packed_bits(walk):
 result=bytearray((len(walk)+7)//8)
 for i,value in enumerate(walk):
  if value:result[i>>3]|=1<<(i&7)
 return base64.b64encode(result).decode()
def main():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
 import cg_library as lib
 from prepare_field_assets import navigation_grid
 audit=json.loads(AUDIT.read_text());plan=audit['raw_completion_plan_only'];owners=audit['halo_graphic_owner_proof']
 assert {r['graphic'] for r in owners}=={10653,10661,10662},'Require allthree existing Falan-owner proofs'
 raw_path=BASE/'100.dat';raw=raw_path.read_bytes();reference=REFERENCE.read_bytes();descriptor=json.loads((BASE/'field100-restore.json').read_text())
 assert digest(raw)==plan['base_sha256']==descriptor['raw_sha256']=='c0226aeab3301dde8ab11a452bd3e2adfccf8c2659dbddb49fab7aedd272a564'
 assert digest(reference)==plan['reference_sha256']=='636a2c90719b5004520a6699fcf7bbe3bd62bbe81f07673737ac822e65ceee11'
 assert sha(CANONICAL)==descriptor['canonical_baseline_sha256']
 w,h,bg,pg,flags=lib.parse_map(raw);rw,rh,rbg,rpg,_=lib.parse_map(reference);cw,ch,cbg,cpg,cflags=lib.parse_map(CANONICAL.read_bytes());n=w*h
 assert (w,h)==(rw,rh)==(cw,ch)==(840,610)
 paths=[Path(__file__),AUDIT,REFERENCE,CANONICAL,CITY_ATLAS,ROOT/'tools/build_falan_room_art.py',raw_path,BASE/'field100-restore.json',BASE/'freyja_ground_index.png',BASE/'freyja_ground_atlas.png',Path(lib.__file__),Path(sys.modules['prepare_field_assets'].__file__),lib.DB]
 for path,expected in audit['source_hashes'].items():
  path=ROOT/path.removeprefix('res://');assert sha(path)==expected,('Audited source changed',path);paths.append(path)
 before={label(p):sha(p) for p in paths}
 rows=plan['tuples'];assert len(rows)==24
 indices={r['index'] for r in rows};assert len(indices)==24
 assert {(i%w,i//w) for i in indices}=={(x,y) for y in range(193,201) for x in range(437,440)}
 after=bytearray(raw)
 for row in rows:
  i=row['index'];x,y=row['cell'];assert i==y*w+x
  assert (bg[i],pg[i])==tuple(row['before'])==(0,0) and flags[i]==row['flags_preserved']==0
  assert (cbg[i],cpg[i])==(0,0) and not cflags[i]&0xc000,'Never overwrite client-known tuples'
  assert (rbg[i],rpg[i])==tuple(row['pinned_after'])
  for plane,value in enumerate(row['pinned_after']):struct.pack_into('<H',after,20+(plane*n+i)*2,value)
 after=bytes(after);_,_,abg,apg,aflags=lib.parse_map(after)
 changed={i for i in range(n) if (abg[i],apg[i])!=(bg[i],pg[i])};assert changed==indices
 assert after[:20]==raw[:20] and after[20+n*4:]==raw[20+n*4:] and aflags==flags
 assert all((abg[i],apg[i])==(bg[i],pg[i]) for i in range(n) if i not in indices)
 lookup=lib.serial_index();walk_before=navigation_grid(w,h,bg,pg,lookup);walk_after=navigation_grid(w,h,abg,apg,lookup);walk_reference=navigation_grid(w,h,rbg,rpg,lookup)
 assert packed_bits(walk_before)==descriptor['native_walk_bits']
 for row in rows:
  i=row['index'];assert bool(walk_reference[i])==row['pinned_reference_open'];assert bool(walk_after[i])==bool(walk_reference[i])
 walk_delta=[{'cell':[i%w,i//w],'before':bool(walk_before[i]),'after':bool(walk_after[i]),'planned_raw_cell':i in indices} for i in range(n) if bool(walk_before[i])!=bool(walk_after[i])]
 index=Image.open(BASE/'freyja_ground_index.png').convert('RGBA');original_index=index.tobytes();atlas=Image.open(BASE/'freyja_ground_atlas.png').convert('RGB')
 assert sha(BASE/'freyja_ground_index.png')==descriptor['ground']['index_sha256'] and sha(BASE/'freyja_ground_atlas.png')==descriptor['ground']['atlas_sha256']
 slots={}
 for i,serial in enumerate(bg):
  pixel=index.getpixel((i%w,i//w))
  if pixel[3] and serial not in (0,100):
   slot=pixel[0]+pixel[1]*COLS;assert serial not in slots or slots[serial]==slot;slots[serial]=slot
 original_atlas=atlas.copy();city_atlas=Image.open(CITY_ATLAS).convert('RGB');city_cols=city_atlas.width//STRIDE
 city_tiles={}
 for slot in range(city_cols*(city_atlas.height//STRIDE)):
  x=slot%city_cols*STRIDE;y=slot//city_cols*STRIDE;tile=city_atlas.crop((x,y,x+STRIDE,y+STRIDE));city_tiles.setdefault(digest(tile.tobytes()),[]).append((slot,tile))
 old_slots=set(slots.values());free=[s for s in range(max(old_slots)+1,COLS*(atlas.height//STRIDE)) if s not in old_slots];reused=[];by_pixels={}
 for serial in sorted({r['pinned_after'][0] for r in rows}-slots.keys()):
  source=lookup[serial];native=lib.image_from_record(source['pack'],source['row']);tile=project_tile(native);pixels=digest(tile.tobytes())
  assert pixels in city_tiles,'Reuse the exact existing Falan paving, never substitute another floor'
  source_slot,prepared=city_tiles[pixels][0]
  if pixels not in by_pixels:
   assert free;slot=free.pop(0);by_pixels[pixels]=slot;atlas.paste(prepared,(slot%COLS*STRIDE,slot//COLS*STRIDE))
  slot=by_pixels[pixels];slots[serial]=slot
  reused.append({'graphic':serial,'target_slot':slot,'source_atlas_path':'res://'+str(CITY_ATLAS.relative_to(ROOT)),'source_slot':source_slot,'source_all_identical_slots':[s for s,_ in city_tiles[pixels]],'native_record':source,'source_native_rgba_sha256':digest(native.tobytes()),'projected_rgb_sha256':pixels})
 for slot in old_slots:
  box=(slot%COLS*STRIDE,slot//COLS*STRIDE,slot%COLS*STRIDE+STRIDE,slot//COLS*STRIDE+STRIDE)
  assert atlas.crop(box).tobytes()==original_atlas.crop(box).tobytes()
 prefix_height=descriptor['ground']['existing_atlas_size'][1]
 assert atlas.size==original_atlas.size and atlas.crop((0,0,atlas.width,prefix_height)).tobytes()==original_atlas.crop((0,0,atlas.width,prefix_height)).tobytes()
 bindings=[]
 for row in rows:
  x,y=row['cell'];graphic=row['pinned_after'][0];assert graphic in slots,'Reuse an existing prepared native floor'
  old=index.getpixel((x,y));assert old[3]==0,'Never replace an existing nonzero binding'
  slot=slots[graphic];pixel=(slot%COLS,slot//COLS,0,255);index.putpixel((x,y),pixel)
  tile=atlas.crop((slot%COLS*STRIDE,slot//COLS*STRIDE,slot%COLS*STRIDE+STRIDE,slot//COLS*STRIDE+STRIDE))
  bindings.append({'cell':[x,y],'graphic':graphic,'slot':slot,'rgba':pixel,'existing_tile_rgb_sha256':digest(tile.tobytes())})
 rgba=index.tobytes();pixel_changes={i for i in range(n) if rgba[i*4:i*4+4]!=original_index[i*4:i*4+4]};assert pixel_changes==indices
 owner_rows={(tuple(r['source100_cell']),r['graphic']) for r in owners}
 graphics=[r for r in rows if r['pinned_after'][1]>=1000];assert len(graphics)==3
 assert all((tuple(r['cell']),r['pinned_after'][1]) in owner_rows for r in graphics)
 new_descriptor=json.loads(json.dumps(descriptor));new_descriptor.update({'raw_sha256':digest(after),'combined_changed_union':descriptor['combined_changed_union']+24,'native_walk_bits':packed_bits(walk_after),'boundary_completion_rows':rows,'existing_pg1_owners':owners,'boundary_completion_status':'STAGED unknown-only proposal; no duplicate PG1 enrollment or source-height/support publication'})
 new_descriptor['combined_changed_counts']['bridge_boundary_unknown']=24
 new_descriptor['ground']['index_sha256']=digest(png(index))
 new_descriptor['ground']['atlas_sha256']=digest(png(atlas))
 new_descriptor['ground']['reused_city_paving_tiles']=reused
 new_descriptor['source_hashes'].update({str(AUDIT.relative_to(ROOT)):sha(AUDIT),str(REFERENCE.relative_to(ROOT)):sha(REFERENCE),str(Path(__file__).relative_to(ROOT)):sha(Path(__file__))})
 products={'100.dat':after,'freyja_ground_index.png':png(index),'freyja_ground_atlas.png':png(atlas),'field100-restore.json':encoded(new_descriptor),'owner-preservation.json':encoded({'existing_owners':owners,'rule':'Data identity only. Preserve the existing Falan city1000 fortification/gate art, collision and routes; do not enroll these three source100 PG1 drawings again.'})}
 contract={'status':'PRIVATE STAGE ONLY. Root must review before any active merged-input replacement.','base_sha256':digest(raw),'candidate_sha256':digest(after),'reference_sha256':digest(reference),'size':[w,h],'changed_tuples':rows,'source_bounds':[437,193,3,8],'scope':'Exact24-cell Falan/East bridge interface restoration; this is an explicit data-only boundary exception, not a general x<440 field-goal expansion.','known_client_cells_preserved':sum(bool(cflags[i]&0xc000 or cbg[i] or cpg[i]) for i in range(n)),'all_existing_recorded_tuples_preserved':sum(bool(flags[i]&0xc000 or bg[i] or pg[i]) for i in range(n)),'header_preserved':True,'whole_marker_plane_preserved':True,'outside_plan_raw_tuples_preserved':n-24,'index_changed_pixels':len(pixel_changes),'outside_plan_index_pixels_preserved':n-24,'protected_bridge_restored_cells':sum(r['protected_bridge'] for r in rows),'nonzero_pg1_fortification_rows':len(graphics),'nonfortification_paving_control_rows':24-len(graphics),'native_walk_delta':walk_delta,'native_walk_delta_counts':dict(Counter('opened' if r['after'] else 'closed' for r in walk_delta)),'source_original_closed_controls_remain_closed':all(not walk_after[r['index']] for r in rows if r['pinned_after'][1]==2),'source_height_inference':'None added. The whole existing bridge/gate remains its original current owner; its6m3D datum is not a native elevation claim. Walk flags and physical support are distinct.','ground':{'atlas_reused_path':'res://'+str((BASE/'freyja_ground_atlas.png').relative_to(ROOT)),'atlas_sha256':sha(BASE/'freyja_ground_atlas.png'),'atlas_size':atlas.size,'no_added_atlas_slots':True,'bindings':bindings},'existing_graphic_owners':owners,'intended_future_targets':{name:'res://'+str((BASE/name).relative_to(ROOT)) for name in products},'descriptor_path_note':'Staged descriptor retains intended future raw/index locations and candidate hashes. It deliberately fails against c022 until a reviewed atomic replacement; do not load it as an active source.','products':{name:digest(data) for name,data in products.items()},'source_hashes':before,'source_changed':[p for p,d in before.items() if sha(ROOT/p)!=d],'preservation_limits':'Raw/flags/index identity only. No Host fields, bridge pieces, NPCs, colliders, art, navigation runtime, source routes, context flag, canonical data or export are changed.'}
 assert not contract['source_changed']
 contract['ground'].pop('no_added_atlas_slots')
 contract['ground'].update({'atlas_before_sha256':sha(BASE/'freyja_ground_atlas.png'),'atlas_candidate_sha256':digest(products['freyja_ground_atlas.png']),'atlas_dimensions_unchanged':True,'all_existing_bound_slots_preserved':len(old_slots),'old_base_atlas_image_prefix_rgb_preserved':True,'newly_bound_existing_padding_slots':sorted(by_pixels.values()),'reused_city_paving_tiles':reused})
 products['source-contract.json']=encoded(contract)
 OUT.mkdir(exist_ok=True)
 for name,data in products.items():
  target=OUT/name
  if '--check' in sys.argv:assert target.read_bytes()==data,('Stale staged product',name)
  else:target.write_bytes(data)
 assert sha(raw_path)==plan['base_sha256'],'Active c022 source changed'
 print(json.dumps({k:v for k,v in contract.items() if k in ['status','base_sha256','candidate_sha256','known_client_cells_preserved','all_existing_recorded_tuples_preserved','index_changed_pixels','protected_bridge_restored_cells','nonzero_pg1_fortification_rows','nonfortification_paving_control_rows','native_walk_delta_counts','source_changed']},indent=2))

if __name__=='__main__':main()

"""Source measurements for the remaining scoped East stone families; no runtime enrollment."""
import base64,hashlib,json,struct,sys,zlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
AUDIT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit'
ART=ROOT/'assets/maps/original_crossgate'
ALIASES=[1233290,1233291,1233292,1233293,1238211,1238212,1260054]
def main():
 classified=json.loads((AUDIT/'classic-classification.json').read_text())
 wanted={row['graphic']:row for row in classified['graphics']if row['category']in ['cave_wall_or_cave_cap','rock_or_stalagmite_cluster']}
 catalog=json.loads((ART/'east/catalog.json').read_text());records={}
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 for serial in [*wanted,*ALIASES]:
  token=str(serial);source_row=wanted.get(serial)
  if source_row:
   g={'pack':source_row['source_pack'],'row':source_row['source_row'],'origin':source_row['native_origin'],'footprint':[int(n)for n in source_row['native_footprint']],'rect':[0,0,*map(int,source_row['native_pixels'])],'rgba_sha256':source_row['source_rgba_sha256']}
  else:g=catalog['graphics'][token]
  image=lib.image_from_record(g['pack'],g['row']).convert('RGBA');w,h=image.size;page=None
  assert hashlib.sha256(image.tobytes()).hexdigest()==g['rgba_sha256']
  paint=Image.new('L',image.size);neutral=opaque=visible=0
  for iy in range(h):
   for ix in range(w):
    r,gr,b,a=image.getpixel((ix,iy))
    if a<128:continue
    opaque+=1
    if max(r,gr,b)<=45 and max(r,gr,b)-min(r,gr,b)<3:neutral+=1
    else:paint.putpixel((ix,iy),255);visible+=1
  box=paint.getbbox();row=wanted.get(serial,{})
  category=row.get('category','aliased_terrain')
  role='source_rock_volume'
  if category=='cave_wall_or_cave_cap':
   role='sparse_cave_cap_or_edge'if h<32 or visible/max(1,opaque)<.20 or box and box[3]-box[1]<h*.3 else'painted_modular_cave_wall'
  if serial==1260054:role='sealed_carved_door_crag'
  if serial in [1238211,1238212]:role='lava_face_patch'
  records[token]={'graphic':serial,'role':role,'category':category,'native_rgba_sha256':g['rgba_sha256'],'source_page':page,'rect':g['rect'],'origin':g['origin'],'footprint':g['footprint'],'ground_flag':g.get('ground'),
   'visible_paint_pixels':visible,'opaque_pixels':opaque,'neutral_occlusion_pixels':neutral,'visible_box':box,'visible_opaque_ratio':visible/max(1,opaque),
   'object_placements_before_owner_preemption':row.get('object_placements'),'contexts':row.get('contexts',[]),'only_legacy_contexts':row.get('only_legacy_contexts',False),'existing_owner_note':row.get('known_owner_note',''),
   'planned_owner':'Reuse source_rock/measured_profile for actual stone volume; source-alpha shallow stone contour at original height for sparse occlusion caps. Existing door/nav/water/void owners stay authoritative.',
   'status':'source_measurements_only_not_implemented_or_visually_accepted'}
  if serial==1260054:records[token]['source_observation']='Sealed carved door panel embedded in moss cliff. Reuse candidate12543 shares220x399canvas,3x3footprint and[-107,-374]origin; native paint/silhouette vary. No open door or route is inferred.'
  if serial==1233293:records[token]['source_observation']='Original236x640canvas contains transparent lowerhalf; measure actual visible rock, preserving original origin instead of stretching the entire canvas.'
 # Confirm native walk/portal context before selecting any opaque volume.
 routes=json.loads((ROOT/'assets/maps/falan/east_region/routes.json').read_text());portals={}
 def portal(source,cell):
  if cell is not None:portals.setdefault(int(source),set()).add(tuple(cell))
 for source,x,y,target,tx,ty in routes['fixed']:portal(source,[x,y]);portal(target,[tx,ty])
 for row in routes['event_links']+routes['inline_warps']:portal(row['source'],row.get('cell'));portal(row['target'],row.get('landing'))
 exceptions=[];placements=0;exact_contexts={}
 for path,maprow in catalog['maps'].items():
  source=int(Path(path).stem);w,h=maprow['size'];count=w*h;bits=zlib.decompress(base64.b64decode(maprow['walk']))
  packed=maprow.get('reference_variant_raw')if maprow.get('active_layout_variant')=='pinned-reference'else maprow.get('restored_raw',maprow['raw'])
  raw=zlib.decompress(base64.b64decode(packed));objects=struct.unpack_from('<'+str(count)+'H',raw,20+count*2);aliases=maprow.get('graphic_aliases',{})
  for i,native in enumerate(objects):
   serial=str(aliases.get(str(native),native))
   if serial not in records:continue
   record=records[serial];x,y=i%w,i//w;opened=[];entries=[];placements+=1
   context=exact_contexts.setdefault(serial,{}).setdefault(source,{'map':source,'count':0,'sample_cells':[],'existing_owner':maprow.get('east_existing_owner',False)});context['count']+=1
   if len(context['sample_cells'])<6:context['sample_cells'].append([x,y])
   for dz in range(int(record['footprint'][1])):
    for dx in range(int(record['footprint'][0])):
     xx,yy=x+dx,y-dz
     if not 0<=xx<w or not 0<=yy<h:continue
     k=yy*w+xx
     if bits[k>>3]&(1<<(k&7)):opened.append([xx,yy])
     if (xx,yy)in portals.get(source,set()):entries.append([xx,yy])
   if opened or entries:exceptions.append({'map':source,'graphic':int(serial),'cell':[x,y],'native_walkable_footprint_cells':opened,'source_route_cells':entries,'existing_owner':maprow.get('east_existing_owner',False)})
 for serial,contexts in exact_contexts.items():
  records[serial]['exact_map_contexts']=list(contexts.values())
  if not records[serial]['contexts']:records[serial]['contexts']=list(contexts.values())
 out={'scope':'Read-only source measurements for645classic stone/cave graphics plus7aliased terrain. This is not runtime enrollment or rendered acceptance.','source_catalog_sha256':hashlib.sha256((ART/'east/catalog.json').read_bytes()).hexdigest(),'classification_sha256':hashlib.sha256((AUDIT/'classic-classification.json').read_bytes()).hexdigest(),'graphics':records,'exact_object_placements':placements,'walk_or_portal_footprint_exceptions':exceptions,'volume_rule':'An opaque volume must never cover these source-walkable or exact portal cells; preserve source art with explicit opening/overhang or shallow contour until exact context geometry is available.'}
 (AUDIT/'STONE_SOURCE_PLAN.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 from collections import Counter
 print('EAST_STONE_SOURCE_PLAN',len(records),dict(Counter(row['role']for row in records.values())))
if __name__=='__main__':main()

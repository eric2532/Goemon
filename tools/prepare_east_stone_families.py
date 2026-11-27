"""Prepare review candidates for the652 scoped stone/cave families; never enroll runtime maps."""
import argparse,hashlib,json,sys,tempfile
from pathlib import Path
from PIL import Image,ImageDraw
from prepare_abanis_cliffs import measured_profile
from prepare_east_stone_profiles import source_contour_profile,clean_native_front
from prepare_elsa_scenery import outline
ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit'
OUT=REPORT/'Stone Family Candidate'

def clean_front(original):
 # Reuse the established Native border-occlusion rule. No original RGB changes.
 w,h=original.size;mask=Image.new('L',original.size);pixels=original.load()
 for y in range(h):
  for x in range(w):
   r,g,b,a=pixels[x,y]
   if a<128 or max(r,g,b)<=45 and max(r,g,b)-min(r,g,b)<3:mask.putpixel((x,y),255)
 for x,y in [(x,y)for x in range(w)for y in (0,h-1)]+[(x,y)for y in range(h)for x in (0,w-1)]:
  if mask.getpixel((x,y))==255:ImageDraw.floodfill(mask,(x,y),128)
 result=original.copy()
 for y in range(h):
  for x in range(w):
   if mask.getpixel((x,y))==128:result.putpixel((x,y),(*pixels[x,y][:3],0))
 return result

def prepare(out):
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 plan_path=REPORT/'STONE_SOURCE_PLAN.json';plan=json.loads(plan_path.read_text());classic=json.loads((REPORT/'classic-classification.json').read_text());raw_rows={str(r['graphic']):r for r in classic['graphics']};east=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())['graphics']
 specs={};out.mkdir(parents=True,exist_ok=True)
 for token,row in plan['graphics'].items():
  source=raw_rows.get(token)
  pack=source['source_pack']if source else east[token]['pack'];record=source['source_row']if source else east[token]['row']
  art=lib.image_from_record(pack,record).convert('RGBA');assert hashlib.sha256(art.tobytes()).hexdigest()==row['native_rgba_sha256']
  front=clean_native_front(art)if row['role']=='sealed_carved_door_crag'else clean_front(art);front.save(out/(token+'-front.png'))
  g={'origin':row['origin'],'footprint':row['footprint'],'rect':[0,0,*art.size],'rgba_sha256':row['native_rgba_sha256']};role=row['role']
  spec={'graphic':int(token),'kind':role,'source_graphic':g,'source_native_rgba_sha256':row['native_rgba_sha256'],'source_pack':pack,'source_row':record,'front_sha256':hashlib.sha256((out/(token+'-front.png')).read_bytes()).hexdigest(),'source_contexts':row['contexts'],'only_legacy_contexts':row['only_legacy_contexts'],'height_frame':'original-owner','visible_box':row['visible_box'],'status':'prepared_source_candidate_not_enrolled_or_visually_accepted'}
  if role in ['source_rock_volume','painted_modular_cave_wall','lava_face_patch']:
   profile,coverage=measured_profile(art,g)
   spec['source_coverage']=coverage
   if role=='source_rock_volume':profile,proof=source_contour_profile(front,g,profile);spec['source_contour']=proof
   spec['profile']=profile
   if role=='source_rock_volume'and art.width>=art.height*.85 and art.height<140:
    spec['whole_model_reuse_candidate']='res://assets/models/environments/wind_meadow/mossy_boulder.glb'
    spec['reuse_limit']='Fit the existing model to actual source silhouette/height; retain original unmodified master and use no imported colliders. Inspect native palette and cluster count before selection.'
  elif role=='sparse_cave_cap_or_edge':
   spec['cap_outline']=outline(front.crop(row['visible_box']))
   spec['native_elevated_contour']={'visible_box':row['visible_box'],'origin':row['origin'],'height_per_pixel':.045,'inferred_edge_depth':.12}
   spec['inferred_support']='Reuse compatible same-family painted cave wall only inside original blocked footprint; never turn black bitmap occlusion into a measured solid silhouette. Source cap paint and elevation remain separate.'
  elif role=='sealed_carved_door_crag':
   spec['body_reuse_candidate']=12543;spec['sealed_door_source_box']=[35,205,115,375];spec['sealed_door_outline']=[[94,211],[103,220],[110,240],[108,264],[113,275],[102,302],[96,314],[91,344],[78,359],[36,339],[39,307],[49,283],[55,260],[70,239],[78,223]]
   spec['gate_rule']='Original carved panel is sealed. Preserve original event/quest owner; no new aperture, warp or interaction is inferred.'
   mask=Image.new('L',art.size);ImageDraw.Draw(mask).polygon([tuple(p)for p in spec['sealed_door_outline']],fill=255)
   stone=[p[:3]for i,p in enumerate(art.getdata())if mask.getpixel((i%art.width,i//art.width))and p[0]>p[1]*1.10 and p[1]>p[2]*1.10]
   spec['tablet_edge_rgb']=[sorted(p[c]for p in stone)[len(stone)//2]/255 for c in range(3)]
  visible=[p[:3]for p in art.getdata()if p[3]>=128 and max(p[:3])>45]
  if visible:spec['inferred_back_rgb']=[sorted(p[c]for p in visible)[len(visible)//2]/255 for c in range(3)]
  singles={12100,12101,12102,12103,12104,12105,12106,12107,12108,12110,12111,12112,12113,12114,12115,12116,12119,12121,12122,12124,12126,12129,12130,12131,12133,12134,12149,12150,12153}
  pairs={12109,12117,12118,12120,12123,12127,12128,12132,12135}
  if int(token)in singles|pairs:
   spec['reuse_asset']='res://assets/models/environments/wind_meadow/'+('modular/boulder_pair.tscn'if int(token)in pairs else'mossy_boulder.glb')
   spec['reuse_frame']='Whole existing source geometry, fitted to measured native profile proportions; no imported colliders and no shared material mutation.'
  specs[token]=spec
 for token,spec in specs.items():
  if spec['kind']!='sparse_cave_cap_or_edge':continue
  neighbours=[(abs(int(other)-int(token)),other)for other,row in specs.items()if row['kind']=='painted_modular_cave_wall'and row['source_graphic']['footprint']==spec['source_graphic']['footprint']and abs(int(other)-int(token))<=36]
  if neighbours:
   closest=min(distance for distance,other in neighbours);candidates=[other for distance,other in neighbours if distance<=max(11,closest)]
   spec['inferred_support_graphic']=int(max(candidates,key=lambda other:specs[other].get('source_coverage',0)))
 print('EAST_STONE_CANDIDATES',len(specs),'source families, no runtime enrollment')
 payload={'schema':1,'source_plan_sha256':hashlib.sha256(plan_path.read_bytes()).hexdigest(),'scope':'Review-only source art/profile candidates for652stone/cave families. New typed lower-bank/ground families are a separate follow-up. No map placement, renderer enrollment, collision, walk, water or portal changes.','graphics':specs}
 (out/'data.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--publish',action='store_true');parser.add_argument('--check',action='store_true');args=parser.parse_args()
 target=ROOT/'assets/maps/falan/east_region/stone_families'if args.publish else OUT
 if args.check:
  with tempfile.TemporaryDirectory(prefix='east-stone-check-',dir='/private/tmp')as temporary:
   folder=Path(temporary);prepare(folder)
   stale=[path.name for path in folder.iterdir()if not(target/path.name).exists()or(target/path.name).read_bytes()!=path.read_bytes()]
   assert not stale,'Stale stone candidates: '+','.join(stale[:12])
  print('EAST_STONE_CANDIDATES_CHECK PASS')
 else:prepare(target)
if __name__=='__main__':main()

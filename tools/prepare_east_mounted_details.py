"""Preserve native thin wall details, two static figures and two loose floor motifs."""
import argparse, ast, hashlib, io, json, math, statistics, sys
from pathlib import Path
from PIL import Image,ImageDraw
from recover_venoa_walls import native_without_ground_shadow
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/maps/falan/east_region/mounted_details'
MOUNTED=[10526,10547,10550,10551,10567,10569,10582,11113,11114,11119,11122,16139,16236,16237,16238,16239,16240,16241,16242,16243,16565,16645,17521,17522,17523,17560,17563]
FIGURES=[14529,14536];FLOORS=[11059,17674];IDS=sorted(MOUNTED+FIGURES+FLOORS)
PICTURES=[16139,*range(16236,16244),17521,17522,17523]

def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 catalog={}
 for path in ['assets/maps/original_crossgate/catalog.json', 'assets/maps/falan/sokia/fixed/catalog.json', 'assets/maps/original_crossgate/university/catalog.json', 'assets/maps/original_crossgate/elsa/catalog.json', 'assets/maps/original_crossgate/east/catalog.json']:
  graphics=json.loads((ROOT/path).read_text())['graphics']
  for token,g in graphics.items():
   if 'sokia/fixed' not in path or token not in catalog:catalog[token]=g
 definition=next(n for n in ast.parse((ROOT/'tools/prepare_elsa_scenery.py').read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='outline');scope={'math':math,'Image':Image};exec(compile(ast.Module(body=[definition],type_ignores=[]),'<reused-native-outline>','exec'),scope)
 atlas=Image.open(ROOT/'assets/maps/original_crossgate/building-surfaces.png').convert('RGBA');wood=atlas.crop((256,1664,384,1792));wood_hash=hashlib.sha256(wood.tobytes()).hexdigest();results={};graphics={}
 def png(name,image):
  stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);results[name]=stream.getvalue()
 for serial in IDS:
  g=catalog[str(serial)];original=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(original.tobytes()).hexdigest();assert digest==g['rgba_sha256'],serial
  front,_=native_without_ground_shadow(original);png(f'{serial}-front.png',front)
  mode='floor' if serial in FLOORS else 'figure' if serial in FIGURES else 'mounted';slope=0.
  if serial in PICTURES:
   alpha=front.getchannel('A');rows=[];bounds=front.getbbox()
   for x in range(bounds[0]+2,bounds[2]-2):
    yy=[y for y in range(front.height)if alpha.getpixel((x,y))>200]
    if yy:rows.append((x,min(yy)))
   mx=statistics.mean(x for x,y in rows);my=statistics.mean(y for x,y in rows);observed=sum((x-mx)*(y-my)for x,y in rows)/max(1,sum((x-mx)**2for x,y in rows));slope=.75 if observed>=0 else -.75
  elif mode=='mounted':slope=-.75 if g['footprint'][0]>g['footprint'][1] or serial==10567 else .75 if g['footprint'][1]>g['footprint'][0] else 0.
  back=Image.new('RGBA',front.size)
  if serial in FIGURES:back=front.copy() # Native static figure style shares its original sprite appearance; no NPC behavior.
  else:
   for y in range(0,back.height,wood.height):
    for x in range(0,back.width,wood.width):back.paste(wood,(x,y))
   if serial in [10550,10582,16565,16645]:back=Image.new('RGBA',front.size,(99,103,96,255))
   if serial==17563:back=Image.new('RGBA',front.size,(219,211,180,255))
   if serial==17560:back=Image.new('RGBA',front.size,(178,70,24,255))
   back.putalpha(front.getchannel('A'))
  png(f'{serial}-back.png',back)
  graphics[str(serial)]={'mode':mode,'size':list(front.size),'origin':g['origin'],'footprint':g['footprint'],'bounds':list(front.getbbox()),'slope':slope,'ground':g['origin'][1]+front.getbbox()[3]-1 if mode=='figure' else 0.,'depth':.14 if serial==10567 else .008 if serial==17563 else .018 if serial in FIGURES else .03 if serial in PICTURES or serial==17560 else .08,'edges':scope['outline'](front),'source_rgba_sha256':digest,'source_pack':g['pack'],'source_row':g['row']}
 data={'schema':1,'graphics':graphics,'reuse':'Existing Elsa native alpha-relief shell; separate source-facing and independently painted reverse surfaces. No new rendering owner.', 'back_wood_tile_rgba_sha256':wood_hash,'inferred':['Original hanging height, alpha holes and source-facing artwork are preserved. Thin closed edge thickness and unseen wood/metal/cloth reverse are inferred.','10567 is a wall clock: native origin[3,-144] with69px image leaves its bottom75native pixels above the ground datum. Preserve its hanging height and sourceXZ instead of fitting a floor-standing clock and shifting it across the room. Existing Inn.details also identifies10567as a wall-mounted clock.','The two static human drawings remain source object art. This does not add NPCs or encounters.'],'scope':'31 exact source details;10567delegates through the existing published casework scope; other30remain private pending visual and actual-map review.'}
 results['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();return results

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();bad=[]
 for n,b in products().items():
  f=OUT/n
  if a.check:
   if not f.exists() or f.read_bytes()!=b:bad.append(n)
  elif not f.exists()or f.read_bytes()!=b:OUT.mkdir(parents=True,exist_ok=True);f.write_bytes(b)
 if bad:raise SystemExit('Stale mounted details: '+', '.join(bad))
 print(('Verified' if a.check else 'Prepared')+'31 source-preserving thin/flat details; original RGBA retained.')
if __name__=='__main__':main()

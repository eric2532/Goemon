"""Pinned native wheel/water references; geometry stays a private reconstruction."""
import argparse,base64,hashlib,io,json,statistics,struct,sys,zlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/waterwheel'

def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 cat=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text());g=cat['graphics']['1238504']
 image=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(image.tobytes()).hexdigest();assert digest==g['rgba_sha256']
 front=image.copy();water=Image.new('RGBA',image.size);f=front.load();w=water.load()
 for y in range(image.height):
  for x in range(image.width):
   r,bg,b,a=image.getpixel((x,y))
   if y>130 and b>r*1.05 and b>=bg*.92:
    w[x,y]=(r,bg,b,a);f[x,y]=(r,bg,b,0)
 placements=[]
 for path,row in cat['maps'].items():
  source=int(Path(path).stem)
  payload=row['reference_variant_raw'] if row.get('active_layout_variant')=='pinned-reference' else row.get('restored_raw',row['raw'])
  raw=zlib.decompress(base64.b64decode(payload));width,height=struct.unpack_from('<II',raw,12);cells=width*height;aliases=row.get('graphic_aliases',{})
  for i,n in enumerate(struct.unpack_from(f'<{cells}H',raw,20+cells*2)):
   if int(aliases.get(str(n),n))==1238504:placements.append({'source':source,'cell':[i%width,i//width],'native_object':n,'native_floor':struct.unpack_from('<H',raw,20+i*2)[0]})
 assert len(placements)==1 and placements[0]['source']==43500,placements
 data={'schema':1,'graphic':1238504,'origin':g['origin'],'footprint':g['footprint'],'size':list(image.size),'source_rgba_sha256':digest,'source_pack':g['pack'],'source_row':g['row'],'placements':placements,
       'front_hub_pixel':[62,136],'hub_height':4.55,'radius':4.2,'wheel_depth':6.,'sectors':12,'water_offset':-2.1,'frame_rise':3.1,'frame_width':.70,
       'inferred':['The visible shaft and repeated rim/paddle divisions guide a closed timber wheel. Hidden circumference, twelve regular sectors, depth, frame joints and measured physical scale reconstruct the single native view; they are not original3D measurements.',
                   'Only native blue water/foam pixels are separated into a flat source-ground motif. The source anchor is water floor5001; the assembly follows the existing aquatic/boat owner offset -2.1m, keeping the motif on the original-map water surface. This vertical reconstruction does not change its sourceXZ anchor.',
                   'The wheel is static; no unverified animation, collision, route or interaction is added.']}
 result={'data.json':(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()}
 timber=Image.open(ROOT/'assets/maps/original_crossgate/building-surfaces.png').convert('RGBA').crop((256,1664,384,1792))
 source_tile_hash=hashlib.sha256(timber.tobytes()).hexdigest()
 observed=[p for p in image.getdata()if p[3]>200 and p[0]>p[1]*1.12 and p[1]>p[2]*1.18]
 original=list(timber.getdata());target=[statistics.median(p[k]for p in observed)for k in range(3)];base=[statistics.median(p[k]for p in original)for k in range(3)];gain=[target[k]/max(1,base[k])for k in range(3)]
 timber.putdata([tuple(min(255,round(p[k]*gain[k]))for k in range(3))+(p[3],)for p in original])
 data['inferred'].append('Timber faces reuse the existing clean Tina fence11363 grain at a fixed1.35m pitch; the front-facing wheel drawing is a reference rather than a texture stretched across rims, paddles and hidden supports.')
 data['timber_reference']={'path':'assets/maps/original_crossgate/building-surfaces.png','rect':[256,1664,128,128],'native_graphic':11363,'original_rgba_sha256':source_tile_hash,'prepared_rgba_sha256':hashlib.sha256(timber.tobytes()).hexdigest(),'native_wheel_wood_median':target,'rgb_gain':gain,'world_pitch':1.35}
 data['inferred'].append('The source-facing supports are heavy boards rising close to the rim, not thin poles. Their0.70m width and3.10m rise above the hub are inferred from the native silhouette; the shared grain is color-fitted to this wheel native wood median without changing the source tile.')
 result['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()
 for name,im in [('native.png',image),('front.png',front),('water.png',water),('timber.png',timber)]:
  stream=io.BytesIO();im.save(stream,format='PNG',optimize=True);result[name]=stream.getvalue()
 return result

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args();bad=[]
 for name,raw in products().items():
  path=OUT/name
  if args.check:
   if not path.exists()or path.read_bytes()!=raw:bad.append(name)
  elif not path.exists()or path.read_bytes()!=raw:OUT.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
 if bad:raise SystemExit('Stale native waterwheel: '+', '.join(bad))
 print(('Verified'if args.check else'Prepared')+' source1238504 wheel references and exact43500placement; no runtime hook.')
if __name__=='__main__':main()

"""Remove duplicate rooftop paint only where a measured3D chimney/hatch replaces it."""
import argparse,hashlib,io,json
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/maps/falan/east_region/lektal_roof';SERIAL=1233255
MASKS=[[(67,0),(113,0),(119,94),(99,112),(53,89),(53,65)],[(133,79),(177,51),(211,77),(204,108),(173,132),(137,110)]]
CHIMNEY=[(80,0),(103,0),(111,8),(111,16),(102,26),(102,43),(108,61),(115,70),(119,87),(103,103),(83,106),(58,88),(60,74),(69,68),(74,47),(77,24),(71,17),(70,8)]

def padded_tile(image,quad):
 patch=image.transform((112,112),Image.Transform.QUAD,tuple(v for p in quad for v in p),Image.Resampling.NEAREST)
 tile=Image.new('RGBA',(128,128));tile.paste(patch,(8,8))
 tile.paste(patch.crop((0,0,112,1)).resize((112,8)),(8,0));tile.paste(patch.crop((0,111,112,112)).resize((112,8)),(8,120))
 tile.paste(tile.crop((8,0,9,128)).resize((8,128)),(0,0));tile.paste(tile.crop((119,0,120,128)).resize((8,128)),(120,0))
 return tile

def products():
 cat=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text());g=cat['graphics'][str(SERIAL)];path=ROOT/'assets/maps/original_crossgate'/cat['pages'][g['page']];atlas=Image.open(path).convert('RGBA');x,y,w,h=g['rect'];native=atlas.crop((x,y,x+w,y+h));assert hashlib.sha256(native.tobytes()).hexdigest()==g['rgba_sha256']
 mask=Image.new('L',native.size);draw=ImageDraw.Draw(mask)
 for polygon in MASKS:draw.polygon(polygon,fill=255)
 clean=native.copy();clean.putalpha(Image.composite(Image.new('L',native.size),native.getchannel('A'),mask));atlas.paste(clean,(x,y));files={}
 # Rectify a whole, unobstructed slate patch. The old generic blue tile was a
 # different design and made the cleared attachment margins glow bright cyan.
 roof_quad=[(145,170),(163,195),(204,154),(187,139)]
 wall_quad=[(193,248),(193,277),(211,265),(211,237)]
 surfaces=Image.open(ROOT/'assets/maps/falan/east_region/landmarks/surfaces.png').convert('RGBA');surfaces.paste(padded_tile(native,roof_quad),(0,128));surfaces.paste(padded_tile(native,wall_quad),(384,128))
 chimney_quad=[(80,34),(75,55),(98,69),(99,41)]
 cap_quad=[(78,6),(77,14),(91,23),(99,10)]
 corner_quad=[(190,281),(188,293),(197,298),(201,285)]
 for quad,at in [(chimney_quad,(128,640)),(cap_quad,(256,384)),(corner_quad,(256,0))]:surfaces.paste(padded_tile(native,quad),at)
 chimney_mask=Image.new('L',native.size);ImageDraw.Draw(chimney_mask).polygon(CHIMNEY,fill=255)
 chimney=native.copy();chimney.putalpha(Image.composite(native.getchannel('A'),Image.new('L',native.size),chimney_mask))
 for name,image in [('house-atlas.png',atlas),('depth-mask.png',mask),('surfaces.png',surfaces),('chimney-front.png',chimney)]:
  stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);files[name]=stream.getvalue()
 data={'schema':1,'graphic':SERIAL,'source_rgba_sha256':g['rgba_sha256'],'source_atlas':str(path.relative_to(ROOT)),'source_atlas_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'rect':g['rect'],'origin':g['origin'],'chimney_base':[94,94],'chimney_height_pixels':72,'chimney_cap_height_pixels':18,'hatch_top':[[138,81],[174,59],[206,82],[171,105]],'hatch_lift_m':.60,'replacement_masks':MASKS,'inferred':['Only hidden chimney rear/cap circumference and hatch board thickness continue native construction. Roof attachment is measured from the reused actual house roof triangles, not guessed elevation.','Cleared rooftop paint reveals the existing blue-roof material where the source part occluded it; original RGBA/map/walk/event data stay unchanged.'],'scope':'One1233255house appearance. Candidate geometry and roof-connected source/second-camera acceptance are required before enrollment.'}
 data['roof_surface_patch']=roof_quad;data['roof_surface_tile']=[0,128,128,128]
 data['chimney_source_mask']=CHIMNEY;data['hidden_log_surface_patch']=wall_quad
 data['hidden_chimney_surface_patch']=chimney_quad;data['hidden_cap_surface_patch']=cap_quad;data['corner_log_surface_patch']=corner_quad
 data['inferred'].append('Only the private blue-roof surface tile is replaced by a rectified unobstructed native slate patch. Hidden roof slopes continue this material at the existing fixed world pitch; other shared/local atlas tiles remain unchanged.')
 files['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();return files

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();bad=[]
 for name,raw in products().items():
  f=OUT/name
  if a.check:
   if not f.exists()or f.read_bytes()!=raw:bad.append(name)
  elif not f.exists()or f.read_bytes()!=raw:OUT.mkdir(parents=True,exist_ok=True);f.write_bytes(raw)
 if bad:raise SystemExit('Stale Lektal roof derivative: '+', '.join(bad))
 print(('Verified'if a.check else 'Prepared')+'one bounded Lektal roof depth derivative; original atlas/map unchanged.')
if __name__=='__main__':main()

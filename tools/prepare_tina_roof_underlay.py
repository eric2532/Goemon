"""Recover Tina's occluded main-roof underlay from preserved same-roof paint."""
from pathlib import Path
import argparse,hashlib,json
from PIL import Image,ImageDraw,ImageFilter,ImageStat
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/tina/buildings'

def prepare(serial=11407):
 catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
 g=catalog['graphics'][str(serial)];x,y,w,h=g['rect']
 source=Image.open(ROOT/'assets/maps/original_crossgate'/catalog['pages'][g['page']]).convert('RGBA').crop((x,y,x+w,y+h))
 assert hashlib.sha256(source.tobytes()).hexdigest()==g['rgba_sha256']
 # The foreground bay hides this region of the main roof; reuse this building's own unobscured roof paint.
 fill=source.copy();paint=source.filter(ImageFilter.GaussianBlur(6))
 grain_box=(134,70,182,102) if serial==11407 else (200,58,248,90)
 grain=source.crop(grain_box);mean=ImageStat.Stat(grain).mean
 # Continue each visible roof plane from its unobscured upper section behind the bay.
 apex=(223,1) if serial==11404 else (226,4);near=(286,291) if serial==11404 else (255,260) if serial==11407 else (254,276)
 for y in range(source.height):
  for x in range(source.width):
   left=(68,130) if serial==11404 else (75,132) if serial==11407 else (15,182)
   right=(444,187) if serial==11404 else (445,187) if serial==11407 else (393,129)
   edge=left if (x-apex[0])*(near[1]-apex[1]) < (y-apex[1])*(near[0]-apex[0]) else right
   ax,ay=edge[0]-apex[0],edge[1]-apex[1];bx,by=near[0]-apex[0],near[1]-apex[1]
   dx,dy=x-apex[0],y-apex[1];det=ax*by-ay*bx
   radius=(dx*by-dy*bx+ax*dy-ay*dx)/det
   scale=min(1,.32/max(.001,radius))
   color=paint.getpixel((round(apex[0]+dx*scale),round(apex[1]+dy*scale)))
   gx=x%96;gy=y%64;detail=grain.getpixel((gx if gx<48 else 95-gx,gy if gy<32 else 63-gy))
   fill.putpixel((x,y),tuple(max(0,min(255,round(color[c]+(detail[c]-mean[c])*.35))) for c in range(3))+(color[3],))
 mask=Image.new('L',source.size);draw=ImageDraw.Draw(mask)
 draw.ellipse((133,107,341,285) if serial==11404 else (113,119,339,281),fill=255);draw.ellipse((211,114,252,151) if serial==11404 else (211,114,242,146),fill=255)
 mask=mask.filter(ImageFilter.GaussianBlur(10))
 image=Image.composite(fill,source,mask)
 proof={'source_graphic':serial,'source_rgba_sha256':g['rgba_sha256'],'borrowed_paint':'Same roof plane, upper 32 percent of its radius; subtle mirrored grain from '+('[134,70,182,102]' if serial==11407 else '[200,58,248,90]'),
        'mask':'Foreground bay roof and its finial only; original file is preserved. The same visible roof plane continues behind the bay with subtle same-roof grain. Unseen main-roof paint is an explicit reconstruction.',
        'output_rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest()}
 if serial==11404:proof['borrowed_paint']='Same roof plane, upper 32 percent of its radius; subtle mirrored grain from '+str(list(grain_box))
 return image,proof

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');p.add_argument('--serial',type=int,choices=[11404,11407,11408],default=11407);a=p.parse_args();im,proof=prepare(a.serial)
 image_path=OUT/f'{a.serial}-main-roof.png';proof_path=OUT/('underlay.json' if a.serial==11407 else f'underlay-{a.serial}.json')
 if a.check:
  assert Image.open(image_path).convert('RGBA').tobytes()==im.tobytes()
  assert json.loads(proof_path.read_text())==proof
 else:
  OUT.mkdir(parents=True,exist_ok=True);im.save(image_path);proof_path.write_text(json.dumps(proof,indent=2)+'\n')
 print('PASS: Tina main-roof underlay, preserved original pixels and same-building paint provenance',a.serial)
if __name__=='__main__':main()

"""Private source-exact cactus face with a smooth inferred rounded section."""
import hashlib,json,math
from pathlib import Path
from PIL import Image,ImageFilter
from prepare_east_nature import ROOT,sources,outline
OUT=ROOT/'assets/maps/falan/east_region/cactus_volume_prototype'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
 table,_,pins=sources();OUT.mkdir(parents=True,exist_ok=True);rows={}
 for serial in [11178]:
  g,page=table[serial];im=Image.open(page).convert('RGBA').crop((g['rect'][0],g['rect'][1],g['rect'][0]+g['rect'][2],g['rect'][1]+g['rect'][3]));assert sha(im.tobytes())==g['rgba_sha256']
  front=Image.open(ROOT/f'assets/maps/falan/east_region/nature/{serial}-front.png').convert('RGBA');w,h=front.size
  # The old generic bbox retained isolated neutral shadow71pixels16rows below
  # this green stem. They are source ground paint, not a floating plant base.
  colored_rows=[y for y in range(h) if sum(a>=128 and max(r,g,b)-min(r,g,b)>12 for r,g,b,a in[front.getpixel((x,y))for x in range(w)])>=3]
  body_bottom=max(colored_rows)+1;residual_ground=front.copy();removed=0
  for yy in range(h):
   for xx in range(w):
    r,green,b,a=front.getpixel((xx,yy));shadow=yy>=body_bottom and max(r,green,b)-min(r,green,b)<=12
    residual_ground.putpixel((xx,yy),(r,green,b,a if shadow else 0))
    if shadow and a:front.putpixel((xx,yy),(r,green,b,0));removed+=1
  alpha=front.getchannel('A');field=Image.new('F',(w,h),0)
  # A native contiguous horizontal section becomes an ellipse, rather than the
  # Manhattan-distance pyramids responsible for the rejected folded surface.
  for y in range(h):
   x=0
   while x<w:
    if alpha.getpixel((x,y))<128:x+=1;continue
    left=x
    while x<w and alpha.getpixel((x,y))>=128:x+=1
    right=x;radius=(right-left)*.5
    for xx in range(left,right):field.putpixel((xx,y),math.sqrt(max(0,radius*radius-(xx+.5-(left+right)*.5)**2))*.105)
  # PIL cannot blur F directly; fixed16-bit quantization changes only inferred
  # depth, never original paint, alpha, origin or footprint.
  encoded=Image.frombytes('L',front.size,bytes(min(255,round(v*40))for v in field.getdata())).filter(ImageFilter.GaussianBlur(1.5));depth=[[round(encoded.getpixel((min(x,w-1),min(y,h-1)))/40,5) for x in range(0,w+2,2)]for y in range(0,h+2,2)]
  colors=[p[:3]for p in front.getdata()if p[3]>=128 and p[1]>p[2]*1.1];tone=[sum(p[c]for p in colors)/len(colors)for c in range(3)];back=front.copy()
  for y in range(h):
   for x in range(w):
    color=front.getpixel((x,y));rib=1+.06*math.cos(x/2.1)+.025*math.sin(y/8+x*.13);back.putpixel((x,y),(*(max(0,min(255,round(c*rib)))for c in tone),color[3]))
  grain=Image.new('RGBA',(128,128))
  for yy in range(128):
   for xx in range(128):
    rib=1+.06*math.cos(xx/7.5)+.02*math.sin(yy/15+xx*.08);grain.putpixel((xx,yy),(*(max(0,min(255,round(c*rib)))for c in tone),255))
  grain.save(OUT/f'{serial}-grain.png')
  front.save(OUT/f'{serial}-front.png');back.save(OUT/f'{serial}-back.png');residual_ground.save(OUT/f'{serial}-residual-ground.png');rows[str(serial)]=dict(graphic=g,graphic_id=serial,native_rgba_sha256=g['rgba_sha256'],front_rgba_sha256=sha(front.tobytes()),visible=list(front.getbbox()),ground_offset=g['origin'][1]+body_bottom-1,body_bottom=body_bottom,residual_neutral_ground_pixels=removed,grid_step=2,depth_grid=depth,edges=outline(front),solid_parts=[dict(start=[27,132],end=[30,25],radius_pixels=10),dict(start=[29,30],end=[42,11],radius_pixels=12),dict(start=[22,79],end=[10,55],radius_pixels=10),dict(start=[34,54],end=[48,36],radius_pixels=10)],inference='Source-confirmed residual neutral shadow pixels below the colored stem are separated as ground. Private rounded section and measured64-sided cactus-part trials both preserve native original RGBA/origin/footprint. Hidden body sections and independently painted green ribs are inferred; private until actual review.')
 (OUT/'data.json').write_text(json.dumps(dict(graphics=rows,source_catalogs=pins),indent=2)+'\n');print('CACTUS_VOLUME_PRIVATE',len(rows))
if __name__=='__main__':prepare()

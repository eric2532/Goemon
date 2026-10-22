from pathlib import Path
from PIL import Image,ImageDraw
import json,math,random,ast
P=Path(__file__).resolve().parents[1];(P/'textures').mkdir(exist_ok=True)
# Read only the data assignment; Blender is not imported by this texture utility.
tree=ast.parse((P/'tools/build_dogs.py').read_text());node=next(x for x in tree.body if isinstance(x,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='DOGS' for t in x.targets));rows=eval(compile(ast.Expression(node.value),'<dog data>','eval'),{'dict':dict})
for r in rows:
 base=tuple(round(min(1,c)**(1/2.2)*255) for c in r['scarf']);line=tuple(round(c*.72+110*.28) for c in base);im=Image.new('RGB',(512,512),base);d=ImageDraw.Draw(im)
 for yy in range(-128,640,64):
  shift=64 if (yy//64)%2 else 0
  for xx in range(-128,640,128):
   for rad in [48,36,24]:d.arc((xx+shift-rad,yy-rad,xx+shift+rad,yy+rad),180,360,fill=line,width=2)
 random.seed(800+int(r['id']));pix=im.load()
 for y in range(512):
  for x in range(512):
   noise=random.randrange(-3,4)+(1 if x%3==0 else -1)+(1 if y%4==0 else 0);pix[x,y]=tuple(max(0,min(255,c+noise)) for c in pix[x,y])
 im.save(P/'textures'/f"{r['id']}_woven_wave.png")
print('Ten original seamless textile textures created.')

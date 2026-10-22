from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,sys
P=Path(__file__).resolve().parents[1];(P/'previews').mkdir(exist_ok=True);BG=(238,230,215)
def font(n,b=False):return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if b else '')+'.ttf',n)
def fit(out,path,rect):
 im=Image.open(path).convert('RGB');im.thumbnail(rect[2:]);out.paste(im,(rect[0]+(rect[2]-im.width)//2,rect[1]+(rect[3]-im.height)//2))
rows=json.loads((P/'reference_observations.json').read_text())['notes'];ids=sys.argv[1:]
for r in rows:
 id=r['id']
 if ids and id not in ids:continue
 model=P/'renders'/f'{id}_threequarter.png'
 if not model.exists():continue
 out=Image.new('RGB',(2200,1180),BG);d=ImageDraw.Draw(out);d.text((30,18),id+' / '+r['name'].upper()+' — REFERENCE & BLENDER MODEL',font=font(28,True),fill='#292d34');fit(out,next((P/'references').glob(id+'-*.png')),(0,90,1100,1040));fit(out,model,(1100,90,1100,1000));d.text((35,70),'APPROVED DRAWING',font=font(18),fill='#61594e');d.text((1135,70),'ACTUAL STATIC 3D MODEL',font=font(18),fill='#61594e');d.text((1135,1130),'Modeled fur and editable gear · no rig or animation',font=font(18),fill='#61594e');out.save(P/'previews'/f'{id}_comparison.jpg',quality=94)
 views=['front','side','threequarter','backthreequarter','portrait']
 if all((P/'renders'/f'{id}_{v}.png').exists() for v in views):
  out=Image.new('RGB',(2500,650),BG);d=ImageDraw.Draw(out);d.text((25,18),id+' / '+r['name'].upper()+' — MODEL VIEWS',font=font(30,True),fill='#292d34')
  for j,v in enumerate(views):fit(out,P/'renders'/f'{id}_{v}.png',(j*500,100,500,450));d.text((j*500+20,590),v.upper(),font=font(20),fill='#61594e')
  out.save(P/'previews'/f'{id}_views.jpg',quality=94)
ready=[r for r in rows if (P/'renders'/f"{r['id']}_threequarter.png").exists()]
out=Image.new('RGB',(2300,110+(len(ready)+4)//5*570),BG);d=ImageDraw.Draw(out);d.text((25,22),'NINJA DOGS / ACTUAL BLENDER MODELS',font=font(32,True),fill='#292d34')
for i,r in enumerate(ready):
 x=(i%5)*460;y=110+(i//5)*570;fit(out,P/'renders'/f"{r['id']}_threequarter.png",(x,y,460,490));d.text((x+20,y+508),r['id']+' '+r['name'],font=font(24,True),fill='#292d34')
out.save(P/'previews/model_lineup.jpg',quality=94)
if all((P/'renders'/f"{r['id']}_rear.png").exists() for r in rows):
 out=Image.new('RGB',(2300,1250),BG);d=ImageDraw.Draw(out);d.text((25,22),'NINJA DOGS / REAR VIEWS',font=font(32,True),fill='#292d34')
 for i,r in enumerate(rows):
  x=(i%5)*460;y=110+(i//5)*570;fit(out,P/'renders'/f"{r['id']}_rear.png",(x,y,460,490));d.text((x+20,y+508),r['id']+' '+r['name'],font=font(24,True),fill='#292d34')
 out.save(P/'previews/rear_lineup.jpg',quality=94)

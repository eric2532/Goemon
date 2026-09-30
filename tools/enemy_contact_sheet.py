from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json
R=Path(__file__).resolve().parents[1];D=R/'docs/original-enemies'
a=json.loads((D/'asset-catalog.json').read_text())['assets']
im=Image.new('RGB',(1600,900),'#182027');d=ImageDraw.Draw(im)
f='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
font=ImageFont.truetype(f,25);small=ImageFont.truetype(f,17);title=ImageFont.truetype(f,43)
d.text((50,33),'TIDEFALL / ORIGINAL ENEMY SET',font=title,fill='#f4e7c4');d.text((52,92),'Low-poly Blender masters · original 256px painted atlas · cloud preview',font=font,fill='#aebdb9')
for i,row in enumerate(a):
 x=30+i*395;im1=Image.open(R/row['thumbnail']).convert('RGBA');im1.thumbnail((390,555));im.paste(im1,(x+(390-im1.width)//2,185),im1)
 n=row['asset_id'].split('/')[-1];d.text((x+16,766),n.replace('_',' ').title(),font=font,fill='#f3d494');d.text((x+16,809),f"{row['triangles']} triangles  /  1 material",font=small,fill='#aebdb9')
d.text((48,861),'Rigid-part GPU animation; existing combat rules retained. No crowd FPS claim from these previews.',font=small,fill='#819795')
im.save(D/'enemy-contact-sheet.png')

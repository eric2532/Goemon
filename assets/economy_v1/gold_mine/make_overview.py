from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
D=Path(__file__).parent
W,H=1800,1250
im=Image.new('RGB',(W,H),(233,228,216));dr=ImageDraw.Draw(im)
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';bold='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
f_title=ImageFont.truetype(bold,42);f_sub=ImageFont.truetype(font,22);f_label=ImageFont.truetype(bold,22)
dr.text((45,28),'FIRE SIEGE / GOLD MINE',font=f_title,fill=(39,45,47))
dr.text((47,87),'Editable Blender geometry  •  GLB with four animation clips  •  Real rendered views',font=f_sub,fill=(76,79,77))
items=[('front_three_quarter','WORKING / THREE-QUARTER'),('front','WORKING / FRONT'),('rear_three_quarter','WORKING / REAR'),('unbuilt','UNBUILT SITE'),('construction','CONSTRUCTION / MID-BUILD'),('reinforced_proposal','REINFORCEMENT / VISUAL PROPOSAL')]
for i,(file,label) in enumerate(items):
 x=25+(i%3)*590;y=140+(i//3)*535
 src=Image.open(D/'renders'/f'{file}.png').convert('RGB');src.thumbnail((574,478))
 im.paste(src,(x+(574-src.width)//2,y));dr.text((x+8,y+481),label,font=f_label,fill=(42,47,47))
dr.line((45,1200,1755,1200),fill=(179,169,150),width=2)
dr.text((47,1211),'4.55 × 4.73 m footprint   /   2.89 m height   /   9,404 triangles   /   Base cost 10 gold, combat income 2 gold/sec',font=f_sub,fill=(76,79,77))
im.save(D/'goldmine_overview.png',optimize=True)

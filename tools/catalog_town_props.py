"""Refresh the nine-prop contact sheet from Blender-rendered PNG previews."""
from PIL import Image, ImageDraw, ImageFont
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1];r=root/'docs/town-props'
assets=json.loads((r/'asset-catalog.json').read_text())['assets']
out=Image.new('RGB',(1440,1370),'#15212b');draw=ImageDraw.Draw(out)
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
try:
 font=ImageFont.truetype(font_path,23);small=ImageFont.truetype(font_path,17);title=ImageFont.truetype(font_path,32)
except OSError:
 font=small=title=ImageFont.load_default()
draw.text((28,20),'TIDEFALL / ORIGINAL STREET KIT',font=title,fill='#f1e0ba')
draw.text((28,65),'Editable Blender masters | pixel textures | main area only',font=font,fill='#b9c4cf')
for i,e in enumerate(assets):
 x=(i%3)*480;y=110+(i//3)*420
 im=Image.open(root/e['thumbnail']).convert('RGB');im.thumbnail((460,340));out.paste(im,(x+(480-im.width)//2,y))
 draw.text((x+15,y+345),e['asset_id'].split('/')[-1],font=font,fill='#f1e0ba')
 draw.text((x+15,y+376),f"{e['triangles']} triangles / {e['materials']} materials",font=small,fill='#b9c4cf')
out.save(r/'contact-sheet.jpg',quality=92)

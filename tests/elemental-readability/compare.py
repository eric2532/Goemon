from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import re,json
root=Path(__file__).resolve().parents[2];p=root/'docs/elemental-readability'
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',25)
im=Image.new('RGB',(1120,1950),'#172128');d=ImageDraw.Draw(im)
d.text((18,14),'BEFORE',font=font,fill='white');d.text((578,14),'AFTER — same gameplay camera',font=font,fill='white')
for i,name in enumerate(['fire','smoke','ice','overlap','surge_overlap']):
 y=55+i*378;d.text((18,y),name.replace('_',' ').upper(),font=font,fill='#ebd39a')
 for j,version in enumerate(['before','after']):
  shot=Image.open(p/f'{version}-{name}.png').convert('RGB');im.paste(shot.crop((360,280,920,620)),(j*560,y+33))
im.save(p/'before-after-contact.jpg',quality=92)
counts={}
for name,marker in [('elemental-orbs','ELEMENTAL_ORBS_RESULT'),('firecaster','FIRECASTER_RESULT'),('meteor','METEOR_RESULT')]:
 s=(root/f'tests/elemental-readability/{name}.log').read_text();assert marker+' failures=0' in s and 'SCRIPT ERROR' not in s
 counts[name]=len(re.findall(r'^PASS:',s,re.M))
before=re.findall(r'camera=(.*)',(root/'tests/elemental-readability/before.log').read_text());after=re.findall(r'camera=(.*)',(root/'tests/elemental-readability/after.log').read_text());assert len(before)==len(after)==6 and before==after
(p/'validation.json').write_text(json.dumps({'passed_checks':counts,'same_camera_pairs':6,'camera_transform':before[0],'baseline_commit':'65fa8b172270307abc8fb1554d74efacbadbff22','renderer':'Godot 4.6.3 / OpenGL compatibility / Mesa llvmpipe (cloud)'},indent=2)+'\n')
print(counts)

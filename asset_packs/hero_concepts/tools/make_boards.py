from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
R=Path(__file__).resolve().parents[1]
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',23)
small=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
for f in sorted((R/'previews').glob('*_three_quarter.png')):
 name=f.name.split('_')[0];ref=next((R/'references').glob('*-'+name+'-*.png'))
 board=Image.new('RGB',(1500,960),'#f5efe2');d=ImageDraw.Draw(board)
 a=Image.open(ref).convert('RGB');a.thumbnail((750,850));board.paste(a,((750-a.width)//2,50+(850-a.height)//2))
 b=Image.open(f).convert('RGB');b.thumbnail((750,850));board.paste(b,(750+(750-b.width)//2,50+(850-b.height)//2))
 d.text((30,15),name.upper()+' / APPROVED CONCEPT',font=font,fill='#292c2e');d.text((780,15),'EDITABLE 3D INTERPRETATION',font=font,fill='#292c2e')
 d.text((30,925),'Static model • front concept supplied; unseen sides interpreted • brushwork simplified',font=small,fill='#59544e')
 board.save(R/'previews'/f'{name}_comparison.jpg',quality=92)
# Consistent front / profile / back views and a contact sheet for all ten.
for f in sorted((R/'previews').glob('*_three_quarter.png')):
 name=f.name.split('_')[0];views=['three_quarter','front','side','back']
 if not all((R/'previews'/f'{name}_{v}.png').exists() for v in views):continue
 board=Image.new('RGB',(1600,560),'#f5efe2');d=ImageDraw.Draw(board)
 for i,view in enumerate(views):
  a=Image.open(R/'previews'/f'{name}_{view}.png').convert('RGB');a.thumbnail((400,480));board.paste(a,(i*400+(400-a.width)//2,42))
  d.text((i*400+16,12),name.upper()+' / '+view.replace('_',' '),font=small,fill='#292c2e')
 d.text((16,534),'Source geometry • static / unrigged • studio excluded from export',font=small,fill='#59544e')
 board.save(R/'previews'/f'{name}_turnaround.jpg',quality=92)
order=['sen','raku','izumi','gaku','shiro','banji','touma','roan','nagi','kuren']
lineup=Image.new('RGB',(2000,1180),'#f5efe2');d=ImageDraw.Draw(lineup)
d.text((28,18),'APPROVED TEN / EDITABLE STATIC BLENDER CHARACTERS',font=font,fill='#292c2e')
for i,name in enumerate(order):
 f=R/'previews'/f'{name}_three_quarter.png'
 if not f.exists():continue
 a=Image.open(f).convert('RGB');a.thumbnail((392,490));x=(i%5)*400;y=60+(i//5)*545
 lineup.paste(a,(x+(400-a.width)//2,y));d.text((x+18,y+498),f'{i+1:02d}  {name.upper()}',font=font,fill='#292c2e')
lineup.save(R/'previews'/'lineup.jpg',quality=92)

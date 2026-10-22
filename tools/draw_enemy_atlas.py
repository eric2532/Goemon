from PIL import Image,ImageDraw
from pathlib import Path
import random
root=Path(__file__).resolve().parents[1]; out=root/'assets/textures/enemies/original_set/enemy_atlas.png'
im=Image.new('RGB',(256,256));d=ImageDraw.Draw(im)
colors=['#283b77','#c44732','#e7c88a','#473525','#8c6139','#282735','#758065','#a97758','#eee1b6','#d19631','#77473d','#39555b','#d85730','#ead7a0','#332c39','#bc8b4f']
r=random.Random(44)
for i,c in enumerate(colors):
 x=i%4*64;y=i//4*64;d.rectangle((x,y,x+63,y+63),fill=c)
 for n in range(95):
  xx=x+r.randrange(64); yy=y+r.randrange(64);base=tuple(int(c[k:k+2],16) for k in (1,3,5));v=r.choice([-9,-5,5,9]);d.line((xx,yy,xx+r.randrange(1,5),yy),fill=tuple(max(0,min(255,a+v)) for a in base))
 # seam / brush stripes inside swatches
 if i in [0,1,6,7]:
  for xx in [5,58]:d.line((x+xx,y,x+xx,y+63),fill=tuple(max(0,a-25) for a in base),width=2)
 if i in [2,4,9,15]:
  for yy in range(5,64,9):d.line((x,y+yy,x+63,y+yy-2),fill=tuple(max(0,a-25) for a in base),width=1)
# mask tile 8, bold red asymmetric cheek markings
x,y=0,128
d.polygon([(4,y+18),(24,y+23),(23,y+30),(7,y+27)],fill='#262739');d.polygon([(37,y+23),(59,y+16),(56,y+27),(38,y+30)],fill='#262739')
d.polygon([(27,y+30),(32,y+24),(37,y+38),(30,y+40)],fill='#b5a076')
d.line((21,y+49,43,y+47),fill='#292638',width=3)
for xx in [9,48]:d.polygon([(xx,y+34),(xx+8,y+38),(xx+4,y+47)],fill='#c44732')
# lantern tile 13
x,y=64,192
for yy in range(4,64,9):d.line((x,y+yy,x+63,y+yy),fill='#b89762',width=2)
d.polygon([(x+4,y+18),(x+25,y+23),(x+22,y+31),(x+10,y+29)],fill='#302b38');d.polygon([(x+37,y+22),(x+60,y+13),(x+55,y+29),(x+39,y+31)],fill='#302b38')
d.rectangle((x+15,y+23,x+18,y+27),fill='#fff0b7');d.rectangle((x+46,y+22,x+49,y+26),fill='#fff0b7')
d.polygon([(x+9,y+39),(x+30,y+44),(x+56,y+34),(x+47,y+53),(x+24,y+58)],fill='#302b38');d.polygon([(x+17,y+42),(x+28,y+46),(x+27,y+50),(x+19,y+47)],fill='#fff0b7');d.polygon([(x+39,y+44),(x+49,y+39),(x+45,y+47),(x+39,y+49)],fill='#fff0b7')
# daruma face tile 12
x,y=0,192
d.ellipse((x+5,y+3,x+58,y+58),fill='#f2d7a0')
d.polygon([(x+9,y+18),(x+24,y+9),(x+28,y+19),(x+11,y+25)],fill='#302b38');d.polygon([(x+34,y+19),(x+40,y+10),(x+56,y+16),(x+56,y+25)],fill='#302b38')
d.ellipse((x+15,y+25,x+25,y+36),fill='#302b38');d.ellipse((x+39,y+25,x+49,y+36),fill='#302b38')
d.line((x+15,y+44,x+31,y+40,x+48,y+44),fill='#302b38',width=4);d.line((x+25,y+48,x+32,y+53,x+40,y+47),fill='#302b38',width=3)
im.save(out)

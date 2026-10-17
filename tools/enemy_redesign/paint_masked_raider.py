"""Editable hand-painted wood mask and weathered indigo cloth maps."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math,random
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/textures/enemies/forest_redesign_v01';OUT.mkdir(parents=True,exist_ok=True)
rng=random.Random(47)
S=1024
img=Image.new('RGB',(S,S),(214,190,142));d=ImageDraw.Draw(img)
# Longitudinal wood grain with subtle tonal variation, finer towards edges.
for i in range(240):
 x=rng.randrange(S);shade=rng.choice([(199,172,123),(222,201,158),(187,161,113)])
 pts=[(x+int(7*math.sin(y/110+i)),y) for y in range(-10,S+10,30)]
 d.line(pts,fill=shade,width=rng.choice([1,1,2,3]))
for i in range(34):
 x=rng.randrange(S);y=rng.randrange(S);d.line([(x,y),(x+4,y+25),(x+1,y+48)],fill=(172,146,99),width=2)
# Red lightning markings and angular brow accents painted into the wood.
red=(154,57,37);ink=(31,29,23);shadow=(80,65,43)
for flip in [False,True]:
 def pts(a):return [(S-x if flip else x,y) for x,y in a]
 d.polygon(pts([(140,35),(204,59),(320,330),(228,210)]),fill=red)
 d.polygon(pts([(95,537),(241,642),(337,590),(248,706),(208,659)]),fill=red)
 # Thick angry eye/brow painted as one readable stroke with inset muted eye region.
 d.polygon(pts([(185,308),(225,390),(291,437),(418,484),(397,544),(313,564),(256,528),(215,445)]),fill=ink)
 d.polygon(pts([(236,444),(284,492),(367,515),(320,548),(274,526)]),fill=shadow)
 # Small chin scar has irregular split wood shape.
 d.line(pts([(173,808),(192,771),(212,783)]),fill=ink,width=8)
# Center carved nose indicated entirely through painted grain/shadow.
d.line([(506,444),(505,551),(487,599),(499,620),(527,620),(541,598)],fill=(112,88,56),width=5)
d.line([(496,627),(513,636),(534,628)],fill=(115,84,52),width=5)
# Downturned broad mouth and lower cheek marks.
d.line([(279,783),(319,744),(385,713),(472,703),(549,707),(631,729),(707,780)],fill=ink,width=15)
d.ellipse((269,774,290,795),fill=ink);d.ellipse((697,771,718,792),fill=ink)
# Short weathered splits do not form additional geometry.
for pts in [[(510,2),(505,104)],[(768,7),(750,102)],[(371,961),(382,909)],[(601,1024),(600,943)],[(882,774),(881,849)]]:d.line(pts,fill=(106,83,53),width=4)
img.save(OUT/'masked_raider_mask.png')
# Weathered indigo weave, tan abrasion and irregular worn hem.
cloth=Image.new('RGB',(S,S),(54,68,87));d=ImageDraw.Draw(cloth)
for y in range(0,S,8):d.line([(0,y),(S,y)],fill=(58,72,91),width=1)
for x in range(0,S,8):d.line([(x,0),(x,S)],fill=(47,62,81),width=1)
for i in range(180):
 x=rng.randrange(S);y=rng.randrange(S);w=rng.randint(4,15);h=rng.randint(4,24)
 d.polygon([(x,y),(x+w,y+3),(x+w//2,y+h),(x-3,y+h//2)],fill=rng.choice([(99,95,78),(122,110,85),(80,83,81)]))
cloth.save(OUT/'masked_raider_indigo.png')
print(OUT)

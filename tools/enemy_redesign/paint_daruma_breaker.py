"""Paint Daruma's whole-shell UV atlas; all face landmarks are pigment."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math, random
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/textures/enemies/forest_redesign_v01/daruma_breaker_shell.png'
W=H=2048
im=Image.new('RGBA',(W,H),(158,47,34,255));d=ImageDraw.Draw(im)
def p(u,v):return (int(u*W),int((1-v)*H))
def poly(pts,c):d.polygon([p(*q) for q in pts],fill=c)
def ell(a,b,c):d.ellipse([p(a[0],b[1]),p(b[0],a[1])],fill=c)
def line(pts,c,w):d.line([p(*q) for q in pts],fill=c,width=w,joint='curve')
random.seed(72)
# Subtle brush-striated lacquer shading and worn flecks, continuous through rear.
for j in range(W):
 u=j/W; shade=7*math.sin(u*math.tau*11)+4*math.cos(u*math.tau*23)
 d.line([(j,0),(j,H)],fill=(int(160+shade),int(48+shade*.32),int(35+shade*.2),255))
for i in range(450):
 u=random.random();v=random.uniform(.08,.93);r=random.uniform(.0005,.003)
 poly([(u-r,v),(u,v+r*1.5),(u+r*.6,v+r*.4),(u+r*.3,v-r)],(193,104,61,255))
# Lower belly gold medallion and broad painted rays.
ell((.400,.225),(.600,.522),(194,135,61,255))
for s in [-1,1]:
 for n in range(4):
  x=.50+s*(.093+.026*n)
  poly([(x,.23),(x+s*.012,.245),(x+s*.025,.505),(x+s*.004,.514)],(222,187,115,255))
ell((.418,.248),(.582,.497),(204,153,77,255))
# Cream face field has an irregular rounded traditional painted border.
poly([(.362,.575),(.344,.608),(.347,.693),(.356,.772),(.385,.815),(.445,.834),(.505,.84),(.566,.833),(.616,.81),(.645,.765),(.654,.681),(.649,.615),(.633,.577),(.589,.557),(.411,.557)],(231,208,157,255))
# Cheek and forehead pigment lending form while surface retains full curvature.
poly([(.36,.594),(.367,.694),(.38,.72),(.378,.627),(.421,.578),(.398,.567)],(215,181,126,255))
poly([(.64,.594),(.633,.694),(.62,.72),(.622,.627),(.579,.578),(.602,.567)],(215,181,126,255))
line([(.497,.785),(.494,.740),(.488,.704)],(199,161,107,255),9)
line([(.507,.785),(.51,.743),(.517,.706)],(242,223,177,255),12)
# Eyes with dark circumferential ink, ochre rim, cream sclera and focused pupils.
for cx in [.433,.567]:
 ell((cx-.041,.658),(cx+.041,.750),(40,34,29,255))
 ell((cx-.035,.665),(cx+.035,.745),(177,101,53,255))
 ell((cx-.028,.670),(cx+.028,.742),(237,218,169,255))
 # pupil slightly inward makes a fierce convergent stare.
 pcx=cx+(.007 if cx<.5 else -.007)
 ell((pcx-.011,.694),(pcx+.011,.731),(72,70,56,255))
 ell((pcx-.0065,.701),(pcx+.0065,.722),(24,26,25,255))
 ell((pcx-.005,.716),(pcx-.001,.723),(248,235,203,255))
# Thick swept eyebrows, descending toward nose. Hair strokes remain painted.
poly([(.379,.756),(.389,.792),(.405,.806),(.419,.799),(.453,.765),(.478,.743),(.481,.729),(.47,.722),(.445,.735),(.415,.757)],(29,34,34,255))
poly([(.621,.756),(.611,.792),(.595,.806),(.581,.799),(.547,.765),(.522,.743),(.519,.729),(.53,.722),(.555,.735),(.585,.757)],(29,34,34,255))
for s in [-1,1]:
 for k in range(5):
  line([(.5+s*(.090+k*.004),.790-k*.003),(.5+s*(.100+k*.004),.802-k*.005)],(29,34,34,255),7)
# Nose is entirely painted, a small russet hooked form with an ochre bridge.
poly([(.487,.685),(.481,.671),(.477,.658),(.486,.649),(.499,.657),(.512,.649),(.524,.658),(.519,.672),(.511,.684),(.499,.678)],(139,67,39,255))
poly([(.488,.669),(.5,.676),(.513,.669),(.507,.663),(.497,.666)],(194,119,63,255))
# Moustache sweeps under eyes; separate negative-space cheeks retained.
poly([(.482,.640),(.455,.640),(.421,.655),(.391,.662),(.378,.649),(.376,.623),(.391,.609),(.415,.608),(.443,.621),(.474,.629)],(32,37,35,255))
poly([(.518,.640),(.545,.640),(.579,.655),(.609,.662),(.622,.649),(.624,.623),(.609,.609),(.585,.608),(.557,.621),(.526,.629)],(32,37,35,255))
for s in [-1,1]:
 for k in range(4):
  line([(.5+s*(.106+k*.002),.64-k*.006),(.5+s*(.126+k*.002),.652-k*.004)],(32,37,35,255),6)
# Frown and chin lines.
line([(.427,.578),(.451,.598),(.478,.607),(.5,.610),(.522,.607),(.549,.598),(.573,.578)],(77,43,29,255),12)
line([(.462,.58),(.5,.586),(.538,.58)],(209,172,117,255),5)
# Ink 福 belly emblem, regular Japanese glyph with brush-like rough rim.
fontpath=next(Path('/System/Library/Fonts').glob('*角*W9.ttc'))
font=ImageFont.truetype(str(fontpath),410)
glyph=Image.new('RGBA',(500,500),(0,0,0,0));gd=ImageDraw.Draw(glyph)
b=gd.textbbox((0,0),'福',font=font);gd.text(((500-(b[2]-b[0]))/2-b[0],(500-(b[3]-b[1]))/2-b[1]),'福',font=font,fill=(36,40,35,255))
glyph=glyph.resize((310,480),Image.Resampling.LANCZOS)
im.alpha_composite(glyph,(W//2-155,int(H*(1-.372))-240))
# Intentional lacquer scuff at the lower and upper silhouette, outside artwork.
d=ImageDraw.Draw(im)
for pts in [[(.29,.6),(.30,.63),(.307,.625),(.299,.599)],[(.61,.86),(.64,.85),(.632,.842),(.607,.846)],[(.37,.17),(.382,.185),(.40,.18),(.389,.166)],[(.78,.55),(.8,.585),(.807,.58),(.788,.545)]]:poly(pts,(221,169,109,255))
OUT.parent.mkdir(parents=True,exist_ok=True);im.save(OUT)
print(OUT)

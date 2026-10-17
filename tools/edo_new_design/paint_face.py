"""Editable graphic face for the new Edo prototype; no old texture is reused."""
from pathlib import Path
from PIL import Image, ImageDraw
import math

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/blender/characters/edo_new_design/face.png'
S = 3
im = Image.new('RGB', (1024*S, 1024*S), '#e6ac79')
d = ImageDraw.Draw(im)
def poly(points, color):
    d.polygon([(int(x*S), int(y*S)) for x,y in points], fill=color)
def line(points, color, width):
    d.line([(int(x*S),int(y*S)) for x,y in points],fill=color,width=int(width*S),joint='curve')
def ellipse(box,color):
    d.ellipse(tuple(int(v*S) for v in box),fill=color)
ink='#302728'
# Narrow, sloping eyes: a decisive graphic expression at game scale.
for mirror in [False, True]:
    tr=lambda pts:[(1024-x if mirror else x,y) for x,y in pts]
    eye=[(156,427),(216,437),(320,455),(434,469),(406,518),(342,542),(242,524),(184,485)]
    mask=Image.new('L',im.size,0); md=ImageDraw.Draw(mask)
    md.polygon([(int(x*S),int(y*S)) for x,y in tr(eye)],fill=255)
    layer=Image.new('RGB',im.size,'#faefd8');ld=ImageDraw.Draw(layer)
    cx=324 if not mirror else 1024-324
    ld.ellipse((int((cx-49)*S),420*S,int((cx+49)*S),552*S),fill='#8c4a26')
    ld.ellipse((int((cx-35)*S),453*S,int((cx+35)*S),534*S),fill='#dd973d')
    ld.ellipse((int((cx-15)*S),420*S,int((cx+15)*S),526*S),fill=ink)
    ld.ellipse((int((cx-28)*S),455*S,int((cx-7)*S),476*S),fill='#fff8df')
    im.paste(layer,(0,0),mask);d=ImageDraw.Draw(im)
    poly(tr([(149,414),(225,429),(332,451),(444,468),(425,483),(314,466),(215,450),(176,451)]),ink)
    line(tr([(184,485),(242,524),(342,542),(406,518)]),'#784832',5)
    poly(tr([(174,355),(205,333),(300,365),(425,417),(433,438),(304,392),(204,371)]),ink)
    line(tr([(258,561),(355,568)]),'#b87a51',4)
# Small nose shadow complements volume in the actual head mesh.
line([(503,597),(491,660),(514,672)],'#ae6d46',7)
line([(521,674),(538,668)],'#c48353',4)
# Off-centre, restrained smile.
line([(401,754),(464,765),(535,766),(589,757),(618,739)],ink,8)
line([(605,740),(618,739),(623,745)],ink,5)
line([(470,793),(541,791)],'#bf8057',4)
# One small identifying cheek mark, painted rather than raised geometry.
poly([(737,577),(772,568),(757,608),(734,615)],'#b46e4b')
OUT.parent.mkdir(parents=True,exist_ok=True)
im.resize((512,512),Image.Resampling.LANCZOS).save(OUT)
print(OUT)

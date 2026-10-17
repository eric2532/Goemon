from PIL import Image,ImageDraw
from pathlib import Path
import math
R=Path(__file__).resolve().parents[2]
S=2048
im=Image.new('RGB',(S,S),'#e6d5a8');d=ImageDraw.Draw(im)
def poly(points,color):d.polygon([(int(x*S),int(y*S)) for x,y in points],fill=color)
def ellipse(box,color):d.ellipse(tuple(int(v*S) for v in box),fill=color)
ink='#22262b';white='#fff0c8'
# Bold brush-like eyebrows and slanted mischievous eyes.
poly([(.08,.12),(.24,.18),(.43,.37),(.36,.40),(.21,.27)],ink)
poly([(.92,.12),(.76,.18),(.57,.37),(.64,.40),(.79,.27)],ink)
ellipse((.11,.28,.43,.52),ink);ellipse((.57,.28,.89,.52),ink)
ellipse((.17,.30,.38,.46),white);ellipse((.62,.30,.83,.46),white)
ellipse((.28,.32,.365,.445),ink);ellipse((.635,.32,.72,.445),ink)
# Thick hooked smile; both cheek corners run upward, two painted fangs.
poly([(.08,.55),(.14,.53),(.21,.60),(.39,.67),(.61,.67),(.79,.60),(.86,.53),(.92,.55),(.89,.69),(.75,.83),(.60,.89),(.40,.89),(.25,.83),(.11,.69)],ink)
poly([(.16,.61),(.27,.67),(.21,.76)],white)
poly([(.84,.61),(.73,.67),(.79,.76)],white)
poly([(.45,.54),(.50,.49),(.55,.54),(.50,.57)],'#9e753d')
# Warm broad paper color, no raster photo or projected 2D head.
path=R/'assets/textures/enemies/forest_redesign_v01/lantern_runner_face.png';path.parent.mkdir(parents=True,exist_ok=True)
im.resize((1024,1024),Image.Resampling.LANCZOS).save(path)
print(path)

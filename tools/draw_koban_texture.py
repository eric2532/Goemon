"""Local, original koban engraving atlas; no downloaded imagery or textures."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/textures/weapons/koban';OUT.mkdir(parents=True,exist_ok=True)
W,H=512,1024
im=Image.new('RGB',(W,H),(240,184,29));d=ImageDraw.Draw(im)
cut=Image.new('L',(W,H));c=ImageDraw.Draw(cut)
# Slight broad gold variation, no photographic noise.
for y in range(H):
 color=(int(241+8*math.sin(y/H*math.pi)),int(183+15*math.sin(y/H*math.pi)),30)
 d.line((0,y,W,y),fill=color)
for y in range(130,925,38):
 # Dark recessed strokes with a narrow lit lower lip.
 points=[(35,y+7),(140,y+2),(255,y+4),(375,y-2),(477,y-9)]
 d.line(points,fill=(153,83,13),width=8);c.line(points,fill=170,width=8)
 d.line([(x,yy+7) for x,yy in points],fill=(255,219,72),width=4)
font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',116)
for center,glyph,tilt in [(310,'壱',-5),(696,'両',4)]:
 stamp=Image.new('RGBA',(176,196));sd=ImageDraw.Draw(stamp)
 sd.rounded_rectangle((7,7,169,189),radius=9,fill=(242,179,29,255),outline=(113,55,13,255),width=8)
 sd.rectangle((18,19,158,177),outline=(159,84,15,255),width=3)
 bounds=sd.textbbox((0,0),glyph,font=font)
 sd.text(((176-(bounds[2]-bounds[0]))/2-bounds[0],(196-(bounds[3]-bounds[1]))/2-bounds[1]),glyph,font=font,fill=(105,47,10))
 stamp=stamp.rotate(tilt,resample=Image.Resampling.BICUBIC)
 im.paste(stamp,(168,center-98),stamp)
 # An inset stamp, kept shallow to avoid chunky raised blocks.
 c.rounded_rectangle((174,center-92,338,center+92),radius=9,fill=95)
for y in (105,929):
 d.ellipse((199,y-51,313,y+51),fill=(222,146,22),outline=(115,58,12),width=6)
 # Small petal / seal strokes resembling the reference's rounded end punches.
 for pts in [[(215,y),(241,y-30),(251,y+22),(275,y-29),(295,y)],[(218,y+14),(256,y+35),(292,y+11)],[(223,y-13),(254,y-37),(289,y-12)]]:
  d.line(pts,fill=(111,52,11),width=7)
 c.ellipse((200,y-51,312,y+51),fill=100)
im.save(OUT/'koban_color.png')
# Tangent-space OpenGL normal map, transferable through glTF (not Blender bump nodes).
height=cut.filter(ImageFilter.GaussianBlur(1.2));h=height.load()
normal=Image.new('RGB',(W,H));pixels=normal.load()
for y in range(H):
 for x in range(W):
  dx=-(h[min(W-1,x+1),y]-h[max(0,x-1),y])*.55/510
  dy=-(h[x,min(H-1,y+1)]-h[x,max(0,y-1)])*.55/510
  nx,ny,nz=-dx*4,dy*4,1.0
  length=math.sqrt(nx*nx+ny*ny+1)
  pixels[x,y]=tuple(int((v/length*.5+.5)*255) for v in (nx,ny,nz))
normal.save(OUT/'koban_normal.png')
print('KOBAN_ATLASES',OUT)

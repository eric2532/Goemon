from pathlib import Path
from PIL import Image, ImageDraw
import math, random
root=Path(__file__).resolve().parents[2]; out=root/'assets/textures/enemies/forest_redesign_v01';out.mkdir(parents=True,exist_ok=True)
S=1536
im=Image.new('RGB',(S,S)); p=im.load()
for y in range(S):
 v=1-y/(S-1)
 for x in range(S):
  u=x/(S-1);front=math.exp(-((u-.5)/.20)**6)
  shadow=max(0,min(1,(v-.57)*3.5));shade=.64+.36*front-.29*shadow
  p[x,y]=(int(191*shade),int(150*shade),int(103*shade))
d=ImageDraw.Draw(im)
def pts(values):return [(int(u*S),int((1-v)*S)) for u,v in values]
# Artwork maps directly around the rounded skull. Eye shapes slope inward angrily.
for sign in [-1,1]:
 c=.5+sign*.082
 eye=[(c-.044,.578),(c+.044,.578),(c+.039,.510),(c-.031,.505)]
 if sign<0:eye=[(c-.045,.583),(c+.044,.565),(c+.038,.511),(c-.033,.509)]
 else:eye=[(c-.044,.565),(c+.045,.583),(c+.033,.509),(c-.038,.511)]
 d.polygon(pts(eye),fill='#252a24')
 inset=[(c-.036,.570),(c+.035,.565),(c+.026,.522),(c-.025,.521)]
 d.polygon(pts(inset),fill='#dfd1a1')
 xx=int((c-sign*.006)*S); yy=int((1-.545)*S)
 d.ellipse((xx-16,yy-35,xx+16,yy+30),fill='#111711')
 d.ellipse((xx-6,yy-16,xx+1,yy-7),fill='#d5bd7f')
 brow=[(c-sign*.049,.615),(c+sign*.040,.670),(c+sign*.039,.638),(c-sign*.050,.583)]
 d.polygon(pts(brow),fill='#1b221d')
 # restrained crease and cheek brushwork
 d.line(pts([(c-sign*.048,.496),(c-sign*.059,.480)]),fill='#725b3e',width=5)
d.line(pts([(.493,.538),(.499,.472),(.514,.464)]),fill='#806444',width=5)
im.save(out/'reed_archer_face.png')
rng=random.Random(448)
im=Image.new('RGB',(1024,1024),'#777749');d=ImageDraw.Draw(im)
for _ in range(1050):
 x,y=rng.randrange(1024),rng.randrange(1024);r=rng.randrange(7,39);col=rng.choice(['#687341','#475e3d','#8c8854','#a39a66','#596943'])
 poly=[(x+math.cos(j*math.tau/8)*r*rng.uniform(.4,1.1),y+math.sin(j*math.tau/8)*r*rng.uniform(.6,1.4)) for j in range(8)]
 d.polygon(poly,fill=col)
for _ in range(700):
 x,y=rng.randrange(1024),rng.randrange(1024);d.line((x,y,x+rng.randrange(3,9),y+rng.randrange(2,7)),fill='#92915d',width=1)
im.save(out/'reed_archer_cloak.png')
im=Image.new('RGB',(1024,1024),'#bd9757');d=ImageDraw.Draw(im)
for x in range(0,1024,4):
 col=rng.choice(['#a27d40','#d0ae6a','#c5a361','#d6b878']);d.line((x,0,x,1024),fill=col,width=rng.choice([1,1,2]))
for y in range(0,1024,95):d.line((0,y,1024,y),fill='#98763f',width=4)
im.save(out/'reed_archer_straw.png')

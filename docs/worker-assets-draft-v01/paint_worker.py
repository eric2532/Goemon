"""Deterministic UV artwork for the isolated Worker model, following enemy art."""
from pathlib import Path
from PIL import Image, ImageDraw
import math, random
OUT=Path(__file__).resolve().parent/'textures'
OUT.mkdir(exist_ok=True)
S=1536
im=Image.new('RGB',(S,S));pix=im.load()
for y in range(S):
    v=1-y/(S-1)
    for x in range(S):
        u=x/(S-1)
        front=math.exp(-((u-.5)/.245)**6)
        shade=.82+.18*front-.075*max(0,(v-.72)/.28)
        pix[x,y]=tuple(int(c*shade) for c in (202,157,112))
d=ImageDraw.Draw(im)
def pts(values):return [(round(u*S),round((1-v)*S)) for u,v in values]
def poly(values,color):d.polygon(pts(values),fill=color)
def line(values,color,width):d.line(pts(values),fill=color,width=width,joint='curve')
def oval(cx,cy,rx,ry,color):
    a,b=pts([(cx-rx,cy+ry),(cx+rx,cy-ry)])
    d.ellipse((a,b),fill=color)
for sign in [-1,1]:
    cx=.5+sign*.083
    outer=cx+sign*.046
    inner=cx-sign*.043
    # Painted angry eyelids: outer edge is higher than inner edge.
    poly([(outer,.603),(inner,.559),(inner+sign*.006,.455),
          (outer-sign*.006,.458),(outer+sign*.008,.510)],'#292b25')
    poly([(outer-sign*.008,.585),(inner+sign*.010,.550),
          (inner+sign*.014,.474),(outer-sign*.011,.475),
          (outer-sign*.002,.514)],'#f0e5c6')
    oval(cx-sign*.005,.517,.0145,.044,'#443126')
    oval(cx-sign*.005,.517,.009,.036,'#1d211d')
    oval(cx-sign*.011,.539,.0035,.009,'#fff0cd')
    # Heavy tapered brows furrow inward. No separate brow geometry.
    poly([(cx+sign*.052,.686),(cx-sign*.046,.619),
          (cx-sign*.044,.584),(cx+sign*.049,.647)],'#262922')
    line([(outer-sign*.008,.448),(outer+sign*.004,.429)],'#a67852',5)
    for k in range(3):
        line([(outer-sign*.006+k*sign*.006,.390),
              (outer+sign*.004+k*sign*.006,.414)],'#b8875f',3)
# Compact nose is part of the actual skull, with restrained painted side shade.
line([(.499,.491),(.494,.408),(.506,.398)],'#a4764b',5)
line([(.510,.405),(.518,.410)],'#b58155',4)
# Clear DOWN-TURNED mouth (center higher than corners), no smiling corners.
mouth=[]
for i in range(33):
    t=i/32
    mouth.append((.458+.084*t,.260+.036*math.sin(math.pi*t)))
line(mouth,'#64412d',10)
line([(.460,.260),(.456,.245)],'#825436',4)
line([(.540,.260),(.544,.245)],'#825436',4)
line([(.486,.618),(.488,.595)],'#a97a50',4)
line([(.514,.618),(.512,.595)],'#a97a50',4)
im.save(OUT/'worker-angry-face.png')

def woven(name,base,seed,contrast=12):
    rng=random.Random(seed)
    image=Image.new('RGB',(1024,1024),base);p=image.load()
    for y in range(1024):
        for x in range(1024):
            n=rng.randrange(-3,4)
            weave=(2 if (x//3)%2==0 else -2)+(2 if (y//3)%2==0 else -2)
            p[x,y]=tuple(max(0,min(255,c+n+weave)) for c in base)
    draw=ImageDraw.Draw(image)
    for i in range(190):
        x=rng.randrange(1024);y=rng.randrange(1024)
        color=tuple(max(0,min(255,c+rng.randrange(-contrast,contrast+1))) for c in base)
        draw.line((x,y,x+rng.randrange(3,10),y+rng.randrange(1,4)),fill=color,width=1)
    image.save(OUT/name)
woven('worker-teal-cloth.png',(77,118,119),5015)
woven('worker-trouser-cloth.png',(78,67,54),5016)
woven('worker-linen.png',(207,192,157),5017,7)
rng=random.Random(5018)
im=Image.new('RGB',(1024,1024),'#c0a36b');d=ImageDraw.Draw(im)
for x in range(0,1024,3):
    col=rng.choice(['#b39761','#c3a76e','#cdb17b','#bda06a'])
    d.line((x,0,x,1024),fill=col,width=1)
for y in range(0,1024,104):
    d.line((0,y,1024,y),fill='#aa8c54',width=3)
    d.line((0,y+4,1024,y+4),fill='#ceb27b',width=2)
im.save(OUT/'worker-woven-straw.png')
im=Image.new('RGB',(1024,1024),'#a17b48');d=ImageDraw.Draw(im)
for y in range(0,1024,48):
    for x in range(0,1024,48):
        light=(x//48+y//48)%2
        col=rng.choice(['#ad8750','#b18a54','#b8935e']) if light else rng.choice(['#916b39','#9a7441','#a07a47'])
        d.rectangle((x+2,y+2,x+45,y+45),fill=col)
        if light:d.line((x+3,y+12,x+45,y+12),fill='#c19d66',width=2)
        else:d.line((x+12,y+3,x+12,y+45),fill='#b18d58',width=2)
im.save(OUT/'worker-basket-weave.png')
print('WORKER_DRAFT_TEXTURES_COMPLETE')

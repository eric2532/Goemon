"""Shared native-art measurement and offline stone geometry helpers; no runtime state."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
H=32/3

def clean_face(image):
 a=np.asarray(image).copy()
 occluded=(a[:,:,3]<128)|((a[:,:,:3].max(2)<=45)&((a[:,:,:3].max(2)-a[:,:,:3].min(2))<3))
 border=Image.fromarray(np.uint8(occluded)*255)
 for x,y in [(x,y)for x in range(image.width)for y in (0,image.height-1)]+[(x,y)for y in range(image.height)for x in (0,image.width-1)]:
  if border.getpixel((x,y))==255:ImageDraw.floodfill(border,(x,y),128)
 # Remove large uniform native occlusion masks; retain enclosed dark painted crevices.
 neutral=(a[:,:,3]>=128)&(a[:,:,:3].max(2)<=45)&((a[:,:,:3].max(2)-a[:,:,:3].min(2))<3)
 seen=np.zeros(neutral.shape,bool);hidden=np.zeros(neutral.shape,bool)
 for sy,sx in zip(*np.where(neutral)):
  if seen[sy,sx]:continue
  queue=[(sy,sx)];seen[sy,sx]=True
  for y,x in queue:
   for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
    nx,ny=x+dx,y+dy
    if 0<=nx<image.width and 0<=ny<image.height and neutral[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;queue.append((ny,nx))
  if len(queue)>=512:
   for y,x in queue:hidden[y,x]=True
 valid=(a[:,:,3]>=128)&(np.asarray(border)!=128)&~hidden
 # Native black occlusion regions do not supply visible painted-face samples.
 mask=Image.fromarray((valid*255).astype('uint8'));distance=np.zeros(valid.shape,np.float64);shrink=mask
 for step in range(1,33):
  shrink=shrink.filter(ImageFilter.MinFilter(3));distance+=np.asarray(shrink)/255.
 a[:,:,3]=np.where(valid,a[:,:,3],0)
 return Image.fromarray(a),valid,np.clip(distance/32,0,1)


def lobes(image,valid):
 rgb=np.asarray(image)[:,:,:3].astype(float);r,g,b=rgb.transpose(2,0,1)
 warm=np.clip((r-.72*g)/55.,0,1)*np.clip((r-72)/90.,0,1)
 score=(.30*r+.59*g+.11*b)*warm*valid
 score=np.asarray(Image.fromarray(np.clip(score,0,255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.8))).astype(float)
 peaks=np.asarray(Image.fromarray(score.astype('uint8')).filter(ImageFilter.MaxFilter(13)))
 ys,xs=np.where((score>=peaks-.01)&(score>45))
 candidates=sorted(zip(score[ys,xs],xs,ys),reverse=True);result=[]
 for strength,x,y in candidates:
  if any((x-p['center'][0])**2+(y-p['center'][1])**2<13**2 for p in result):continue
  radii=[]
  for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
   radius=4
   for step in range(4,19):
    xx,yy=x+dx*step,y+dy*step
    if not 0<=xx<score.shape[1] or not 0<=yy<score.shape[0] or score[yy,xx]<strength*.30:break
    radius=step
   radii.append(radius)
  rx=max(7.,(radii[0]+radii[1])*.65);ry=max(8.,(radii[2]+radii[3])*.65)
  result.append({'center':[int(x),int(y)],'radius':[round(rx,2),round(ry,2)],'source_patch_score':round(float(strength),3)})
  if len(result)>=64:break
 return result


def native_triangles(profile):
 v=np.asarray(profile['vertices'],float);n=int(profile['sides']);tri=[]
 for layer in range(int(profile['levels'])-1):
  for side in range(n):
   i=layer*n+side;j=layer*n+(side+1)%n
   tri.extend([[v[j],v[j+n],v[i+n]],[v[j],v[i+n],v[i]]])
 crown=np.asarray(profile['crown'],float);bottom=crown*np.array([1,0,1])
 for side in range(n):
  tri.append([v[-n+side],v[-n+(side+1)%n],crown]);tri.append([v[side],bottom,v[(side+1)%n]])
 return np.asarray(tri)


def project(points,g,pixel_height):
 p=np.asarray(points);return np.stack([(p[...,0]+p[...,2])*H-g['origin'][0],(p[...,2]-p[...,0])*8-p[...,1]/pixel_height-g['origin'][1]],axis=-1)


def native_patch_sampler(image,patches,ph,tile=None):
 # Hidden stone carries a fixed-world-scale continuation of measured source
 # boulder centres/radii/tints. This never samples/wraps the whole front sprite.
 rgba=np.asarray(image,float);rgb=rgba[:,:,:3]/255.;valid=rgba[:,:,3]>=128
 leaf=valid&(rgb[:,:,1]>rgb[:,:,0]*1.04)&(rgb[:,:,1]>rgb[:,:,2]*1.15)
 moss=np.median(rgb[leaf],axis=0)if leaf.any()else np.array([.28,.39,.19])
 width=min(96,image.width);height=min(96,image.height)
 if tile is None:
  choices=[]
  for y in range(0,image.height-height+1,8):
   for x in range(0,image.width-width+1,8):
    selected=[p for p in patches if x<=p['center'][0]<x+width and y<=p['center'][1]<y+height]
    score=sum(p['source_patch_score']*math.sqrt(p['radius'][0]*p['radius'][1])for p in selected)
    score*=float(valid[y:y+height,x:x+width].mean())
    choices.append((score,x,y))
  _,x,y=max(choices);tile=[x,y,width,height]
 x,y,width,height=tile
 selected=[p for p in patches if x<=p['center'][0]<x+width and y<=p['center'][1]<y+height]
 assert selected,'A hidden stone tile must contain unchanged measured native lobes'
 centers=np.asarray([np.array(p['center'])-[x,y]for p in selected],float)
 radii=np.asarray([p['radius']for p in selected],float);depths=np.asarray([p['inferred_depth_m']for p in selected],float)
 smooth=np.asarray(image.filter(ImageFilter.GaussianBlur(2)),float)/255.
 tints=np.asarray([smooth[p['center'][1],p['center'][0],:3]for p in selected]);period=np.array([width,height])
 def plane(uv):
  delta=(np.asarray(uv)-centers+period*.5)%period-period*.5
  r2=np.sum((delta/radii)**2,axis=1);field=depths*np.maximum(0,1-r2)**.55;i=int(np.argmax(field));amount=float(field[i])
  blend=min(1.,amount/.19);blend=blend*blend*(3-2*blend)
  return amount,moss*(1-blend)+tints[i]*blend
 def sample(point,normal):
  u=H*math.sqrt(2);v=1/ph
  coordinates=[[point[2]*u,-point[1]*v],[point[0]*u,point[2]*v],[point[0]*u,-point[1]*v]]
  weights=np.abs(normal)**4;weights/=max(1e-12,weights.sum());amount=0.;color=np.zeros(3)
  for weight,uv in zip(weights,coordinates):
   d,c=plane(uv);amount+=weight*d;color+=weight*c
  return amount,color
 proof={'source_window':tile,'source_lobe_centres':[p['center']for p in selected],
        'world_pitch_pixels_per_m':[H*math.sqrt(2),1/ph],
        'rule':'Only measured source boulder centres/radii/depths and patch-average tints repeat at fixed world scale on inferred hidden sides/caps. No source photograph, projected shadows, noise peaks or UV-edge clamping.'}
 return sample,proof


def rounded_native(tris,iterations=3):
 # Standard closed-mesh Loop subdivision, reused only for the East visual derivative.
 ids={};vertices=[];faces=[]
 for tri in tris:
  face=[]
  for p in tri:
   key=tuple(np.round(p,7))
   if key not in ids:ids[key]=len(vertices);vertices.append(p)
   face.append(ids[key])
  faces.append(face)
 vertices=np.asarray(vertices);bounds=[vertices.min(0),vertices.max(0)]
 for _ in range(iterations):
  neighbours=[set()for p in vertices];edges={}
  for a,b,c in faces:
   for i,j,k in [(a,b,c),(b,c,a),(c,a,b)]:
    neighbours[i].add(j);neighbours[j].add(i);edges.setdefault(tuple(sorted((i,j))),[]).append(k)
  updated=[]
  for i,adjacent in enumerate(neighbours):
   n=len(adjacent);beta=3/(8*n)if n>3 else 3/16
   updated.append((1-n*beta)*vertices[i]+beta*vertices[list(adjacent)].sum(0))
  edge_ids={}
  for (a,b),opposite in edges.items():
   assert len(opposite)==2,'Native profile is not closed'
   edge_ids[(a,b)]=len(updated);updated.append((vertices[a]+vertices[b])*3/8+vertices[opposite].sum(0)/8)
  refined=[]
  for a,b,c in faces:
   ab=edge_ids[tuple(sorted((a,b)))];bc=edge_ids[tuple(sorted((b,c)))];ca=edge_ids[tuple(sorted((c,a)))];refined.extend([[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]])
  vertices=np.asarray(updated);faces=refined
 low,high=bounds;vmin,vmax=vertices.min(0),vertices.max(0);vertices=(vertices-vmin)/(vmax-vmin)*(high-low)+low
 return vertices[np.asarray(faces)]


def raster(points,normals,uv,face,eye,g,ph,source=False,clay=False,palette=None,grazing_fade=False,unlit=False):
 eye=np.asarray(eye,float);eye/=np.linalg.norm(eye);right=np.cross([0,1,0],eye);right/=np.linalg.norm(right);up=np.cross(eye,right)
 allp=points.reshape(-1,3);center=(allp.min(0)+allp.max(0))*.5
 if source:w,h=face.width*2,face.height*2;xy=project(points,g,ph)*2
 else:
  xy=np.stack([(points-center)@right,-(points-center)@up],axis=-1)*42;w,h=720,720;xy+=np.array([w/2,h/2])
 z=points@eye;canvas=np.empty((h,w,3),float);canvas[:]=[38,47,55];buffer=np.full((h,w),-np.inf);pixels=np.asarray(face).astype(float)
 light=np.array([-.6,1.,.8]);light/=np.linalg.norm(light)
 for k,triangle in enumerate(xy):
  x0,y0=np.floor(triangle.min(0)).astype(int);x1,y1=np.ceil(triangle.max(0)).astype(int);x0=max(0,x0);y0=max(0,y0);x1=min(w-1,x1);y1=min(h-1,y1)
  if x0>x1 or y0>y1:continue
  a,b,c=triangle;den=np.cross(b-a,c-a)
  if abs(den)<1e-8:continue
  yy,xx=np.mgrid[y0:y1+1,x0:x1+1];qx=xx+.5-a[0];qy=yy+.5-a[1]
  wb=(qx*(c-a)[1]-qy*(c-a)[0])/den;wc=((b-a)[0]*qy-(b-a)[1]*qx)/den;wa=1-wb-wc;inside=(wa>=0)&(wb>=0)&(wc>=0)
  zz=wa*z[k,0]+wb*z[k,1]+wc*z[k,2];inside&=zz>buffer[y0:y1+1,x0:x1+1]
  if not inside.any():continue
  n=wa[:,:,None]*normals[k,0]+wb[:,:,None]*normals[k,1]+wc[:,:,None]*normals[k,2];n/=np.maximum(1e-8,np.linalg.norm(n,axis=2))[:,:,None]
  shade=.55+.45*np.maximum(0,n@light)
  rgb=np.empty((*wa.shape,3));rgb[:]=[153,164,144]if clay else[123,139,88]
  if palette is not None:rgb=wa[:,:,None]*palette[k,0]+wb[:,:,None]*palette[k,1]+wc[:,:,None]*palette[k,2]
  if uv is not None and not clay and not (uv[k]<0).all():
   puv=wa[:,:,None]*uv[k,0]+wb[:,:,None]*uv[k,1]+wc[:,:,None]*uv[k,2];ix=np.clip(puv[:,:,0].astype(int),0,face.width-1);iy=np.clip(puv[:,:,1].astype(int),0,face.height-1);sample=pixels[iy,ix];valid=(puv[:,:,0]>=0)&(puv[:,:,0]<face.width)&(puv[:,:,1]>=0)&(puv[:,:,1]<face.height)&(sample[:,:,3]>=128)
   if palette is None:rgb=sample[:,:,:3];inside&=valid
   else:
    if grazing_fade:
     angle=np.clip((np.abs(n@eye)-.18)/.37,0,1);angle=angle*angle*(3-2*angle)
     mixed=rgb*(1-angle[:,:,None])+sample[:,:,:3]*angle[:,:,None]
     rgb=np.where(valid[:,:,None],mixed,rgb)
    else:rgb=np.where(valid[:,:,None],sample[:,:,:3],rgb)
  if not unlit:rgb*=shade[:,:,None]
  canvas[y0:y1+1,x0:x1+1][inside]=rgb[inside];buffer[y0:y1+1,x0:x1+1][inside]=zz[inside]
 return Image.fromarray(np.clip(canvas,0,255).astype('uint8'))



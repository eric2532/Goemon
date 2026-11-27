"""Restore only uncovered original-alpha fringe in the private one-cliff study."""
import hashlib
import json
import math
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from prepare_east_cliff_boulder_study import OUT, FOLDER
from east_cliff_geometry import project, raster


def components(mask):
 pending=set(zip(*np.where(mask)));result=[]
 while pending:
  first=pending.pop();queue=deque([first]);group=[first]
  while queue:
   y,x=queue.popleft()
   for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
    neighbour=(y+dy,x+dx)
    if neighbour in pending:pending.remove(neighbour);queue.append(neighbour);group.append(neighbour)
  result.append(group)
 return result


def fringe_geometry(image,g,ph,points,normals,palette,uv,registered):
 rgba=np.asarray(image)
 valid=rgba[:,:,3]>=128;missing=valid&(abs(registered.astype(float)-rgba[:,:,:3]).max(2)>1)
 assert ((registered[missing]==[38,47,55]).all(1)).all(),'Restore only uncovered native art, never conceal wrong UV/RGB registration'
 yy,xx=np.mgrid[:image.height,:image.width];sum_=((xx+.5)+g['origin'][0])*3/32;difference=((yy+.5)+g['origin'][1])/8
 ground_x=(sum_-difference)*.5;ground_z=(sum_+difference)*.5;fx,fz=g['footprint']
 ground=missing&(ground_x>=-2.4)&(ground_x<=fx*3-.6)&(ground_z>=.6-fz*3)&(ground_z<=2.4)
 eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye);across=np.array([1.,0,1.]);across/=np.linalg.norm(across);down=np.array([-8.,-1/ph,8.]);down/=np.linalg.norm(down)
 cloud=np.unique(points.reshape(-1,3).round(6),axis=0);cloud_uv=project(cloud,g,ph);depths=cloud@eye
 additions=[];addition_normals=[];addition_colors=[];addition_uv=[];records=[]
 groups=[('ground',list(zip(*np.where(ground))))]+[('adjacent_surface',group)for group in components(missing&~ground)]
 for kind,pixels in groups:
  if not pixels:continue
  mask=np.zeros(valid.shape,bool)
  for y,x in pixels:mask[y,x]=True
  centroid=np.mean([[x+.5,y+.5]for y,x in pixels],axis=0);distance=np.linalg.norm(cloud_uv-centroid,axis=1);near=distance<=distance.min()+1.
  depth=float(depths[near].max());normal=np.array([0.,1.,0.])if kind=='ground'else eye
  def point(u,v):
   if kind=='ground':
    s=(u+g['origin'][0])*3/32;d=(v+g['origin'][1])/8
    return np.array([(s-d)*.5,0.,(s+d)*.5])
   return eye*depth+across*((u+g['origin'][0])/(32/3*math.sqrt(2)))+down*((v+g['origin'][1])/math.sqrt(128+1/ph**2))
  rows=0
  for y in range(image.height):
   marks=np.flatnonzero(mask[y]);start=0
   while start<len(marks):
    end=start
    while end+1<len(marks)and marks[end+1]==marks[end]+1:end+=1
    x0,x1=int(marks[start]),int(marks[end])+1;source=np.array([[x0,y],[x1,y],[x1,y+1],[x0,y+1]],float);quad=np.array([point(u,v)for u,v in source]);color=rgba[y,x0:x1,:3].mean(0)
    for indices in [[0,1,2],[0,2,3]]:
     additions.append(quad[indices]);addition_normals.append(np.tile(normal,(3,1)));addition_colors.append(np.tile(color,(3,1)));addition_uv.append(source[indices])
    back=quad-normal*.003
    for indices in [[2,1,0],[3,2,0]]:
     additions.append(back[indices]);addition_normals.append(np.tile(-normal,(3,1)));addition_colors.append(np.tile(color*.80,(3,1)));addition_uv.append(np.full((3,2),-1.))
    rows+=1;start=end+1
  records.append({'kind':kind,'original_alpha_pixels':len(pixels),'horizontal_native_runs':rows,'nearest_measured_source_depth':depth,'source_box':[int(min(x for y,x in pixels)),int(min(y for y,x in pixels)),int(max(x for y,x in pixels)+1),int(max(y for y,x in pixels)+1)]})
 combined=np.concatenate([points,additions]);ns=np.concatenate([normals,addition_normals]);colors=np.concatenate([palette,addition_colors]);texture_uv=np.concatenate([uv,addition_uv])
 return combined,ns,colors,texture_uv,records,missing,valid


def main():
 report=json.loads((OUT/'study.json').read_text());arrays=np.load(OUT/'geometry.npz');points=arrays['triangles'];normals=arrays['normals'];palette=arrays['palette'];uv=arrays['uv']
 meta=json.loads((FOLDER/'data.json').read_text())['graphics']['12538'];g={'origin':meta['source_origin'],'footprint':meta['source_footprint']};ph=meta['pixel_height']
 image=Image.open(FOLDER/'12538.png').convert('RGBA');rgba=np.asarray(image);registered=np.asarray(Image.open(OUT/'12538-source-projection.png'))[::2,::2]
 combined,ns,colors,texture_uv,records,missing,valid=fringe_geometry(image,g,ph,points,normals,palette,uv,registered)
 eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
 rear=np.array([.5,.3705,1.]);rear/=np.linalg.norm(rear)
 raster(combined,ns,None,image,rear,g,ph,clay=True).save(OUT/'12538-final-rear-clay.png')
 raster(combined,ns,np.full_like(texture_uv,-1.),image,rear,g,ph,palette=colors).save(OUT/'12538-final-rear-shaded.png')
 raster(combined,ns,texture_uv,image,eye,g,ph,palette=colors).save(OUT/'12538-final-source-shaded.png')
 registration=raster(combined,ns,texture_uv,image,eye,g,ph,palette=colors,source=True,unlit=True);registration.save(OUT/'12538-final-source-registration.png')
 native=Image.open(OUT/'12538-native-untouched.png').convert('RGBA');sheet=Image.new('RGB',(native.width*4+60,native.height*2+64),'#262f37');draw=ImageDraw.Draw(sheet)
 draw.text((20,12),'Untouched native RGBA',fill='white');draw.text((native.width*2+40,12),'3D source view: unlit registration proof',fill='white');native2=native.resize((native.width*2,native.height*2),Image.Resampling.NEAREST);sheet.paste(native2,(20,42),native2);sheet.paste(registration,(native.width*2+40,42));sheet.save(OUT/'12538-final-native-comparison.png')
 actual=np.asarray(registration)[::2,::2];matching=valid&(abs(actual.astype(float)-rgba[:,:,:3]).max(2)<=1)
 fringe={'source_study_sha256':hashlib.sha256((OUT/'study.json').read_bytes()).hexdigest(),'source_native_rgba_sha256':hashlib.sha256(native.tobytes()).hexdigest(),'restored_source_alpha_pixels':int(missing.sum()),'components':records,'native_pixels':int(valid.sum()),'exact_registered_pixels':int(matching.sum()),'registration_fraction':float(matching.sum()/valid.sum()),'triangles_added':len(combined)-len(points),'inferred':'Only original observed alpha absent from the projected body is restored. Ground-adjacent fringe stays at the existing source datum; other fringe continues the nearest measured surface depth as thin native art. Back color and0.003m separation are inferred. No terrain plane, walk/collision data, source anchor, routes, rooms or portals are changed. These remain private shaded/material studies, not actual gameplay acceptance.'}
 (OUT/'fringe-study.json').write_text(json.dumps(fringe,ensure_ascii=False,indent=2)+'\n');np.savez_compressed(OUT/'geometry-with-fringe.npz',triangles=combined,normals=ns,palette=colors,uv=texture_uv)
 print('EAST_CLIFF_FRINGE_STUDY',int(missing.sum()),'native pixels;',len(combined)-len(points),'triangles;',float(matching.sum()/valid.sum()),'registered; no publication')


if __name__=='__main__':main()

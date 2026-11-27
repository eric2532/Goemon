"""One private connected-cliff study; never publishes runtime assets."""
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from asset_pipeline.glb import GLB
from east_cliff_geometry import native_patch_sampler, project, raster
from prepare_east_cliff_boulder_study import ROOT, intersections, source_body, vertex_normals

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study'


def master(name):
    path=ROOT/'assets/models/cedar_pass'/f'{name}.glb';source=GLB.read(path)
    assert source.doc['nodes']==[{'mesh':0,'name':name}]
    primitive=source.doc['meshes'][0]['primitives'][0]
    points=np.asarray(source.accessor(primitive['attributes']['POSITION']))
    colors=np.asarray(source.accessor(primitive['attributes']['COLOR_0']))[:,:3]
    ids=np.asarray(source.accessor(primitive['indices']),int).reshape(-1,3)[:,[0,2,1]]
    low,high=points.min(0),points.max(0)
    points=(points-(low+high)*.5)/((high-low)*.5)
    return points,colors,ids,{'source':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_bounds':[low.tolist(),high.tolist()],'triangles':len(ids),'whole_original_master':True,'rounding_passes':0}


def source_depth(triangles,g,ph,pixels):
    """Barycentric original-view envelope; arbitrary view depth is not a new peak."""
    uv=project(triangles,g,ph);a,b,c=uv[:,0],uv[:,1],uv[:,2]
    ab,ac=b-a,c-a;div=ab[:,0]*ac[:,1]-ab[:,1]*ac[:,0];nonzero=abs(div)>1e-9;div=np.where(nonzero,div,1.)
    result=[]
    for pixel in pixels:
        q=pixel-a;wb=(q[:,0]*ac[:,1]-q[:,1]*ac[:,0])/div;wc=(ab[:,0]*q[:,1]-ab[:,1]*q[:,0])/div;wa=1-wb-wc
        valid=nonzero&(np.minimum(wa,np.minimum(wb,wc))>=-1e-6)
        points=triangles[valid,0]*wa[valid,None]+triangles[valid,1]*wb[valid,None]+triangles[valid,2]*wc[valid,None]
        result.append(points)
    return result


def study():
    meta,core,core_normals,face,g=source_body(12538);ph=meta['pixel_height']
    eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    rgba=np.asarray(face,float)/255.;leaf=(rgba[:,:,3]>.5)&(rgba[:,:,1]>rgba[:,:,0]*1.04)&(rgba[:,:,1]>rgba[:,:,2]*1.15)
    moss=np.median(rgba[leaf,:3],axis=0);patches=meta['measured_native_lobes'];smooth=np.asarray(face.filter(ImageFilter.GaussianBlur(3)),float)/255.
    _,tile=native_patch_sampler(face,patches,ph);tx,ty,tw,th=tile['source_window'];tile_patches=[p for p in patches if tx<=p['center'][0]<tx+tw and ty<=p['center'][1]<ty+th]
    normals=core_normals.mean(1);normals/=np.maximum(1e-9,np.linalg.norm(normals,axis=1))[:,None]
    low,high=core.reshape(-1,3).min(0),core.reshape(-1,3).max(0)
    # The continuous original envelope is the body. Measured pale-stone masters
    # overlap deeply into it; green mass is not replaced by hundreds of spheres.
    selected=[];u_scale=32/3*math.sqrt(2);v_scale=1/ph
    for axis,axes in [(0,[2,1]),(2,[0,1]),(1,[0,2])]:
        for ix in range(math.floor(low[axes[0]]*u_scale/tw)-1,math.ceil(high[axes[0]]*u_scale/tw)+1):
            for iy in range(math.floor(low[axes[1]]*v_scale/th)-1,math.ceil(high[axes[1]]*v_scale/th)+1):
                for patch in tile_patches:
                    px,py=np.array(patch['center'])-[tx,ty];at=[(ix*tw+px)/u_scale,(iy*th+py)/v_scale]
                    hits=intersections(core,at,axes)
                    if not hits:continue
                    for point,index in [min(hits,key=lambda hit:hit[0][axis]),max(hits,key=lambda hit:hit[0][axis])]:
                        normal=normals[index]
                        if abs(normal[axis])+1e-4<max(abs(normal)) or normal@eye>.22 or point[1]<.35:continue
                        if axis==1 and normal[1]<.4:continue
                        x,y=np.rint(project(point,g,ph)).astype(int)
                        if not(0<=x<face.width and 0<=y<face.height and face.getpixel((x,y))[3]>=128):continue
                        rx=min(1.,max(.60,patch['radius'][0]/u_scale*1.25));ry=min(1.,max(.55,patch['radius'][1]*ph,rx*.90));rd=max(.80,rx,ry*.90)
                        row={'point':point,'normal':normal,'radii':np.array([rx,rd,ry]),'patch':patch}
                        if not any(np.linalg.norm(point-old['point'])<.7*(rx+old['radii'][0])for old in selected):selected.append(row)
    masters={name:master(name)for name in ['river_rock','split_crag']};rocks=[];colors=[];records=[]
    for index,row in enumerate(selected):
        n=row['normal'];axis=np.eye(3)[int(np.argmin(abs(n)))];across=axis-n*(axis@n);across/=np.linalg.norm(across);along=np.cross(across,n)
        matrix=np.stack([across,n,along],axis=1)*row['radii'][None,:]
        name='split_crag' if index%3==0 else 'river_rock';points,master_colors,ids,proof=masters[name]
        # Seventy-two percent of the inferred normal radius is embedded. The
        # exposed quarter continues a rock face instead of a loose potato stack.
        center=row['point']-n*row['radii'][1]*.72;volume=points@matrix.T+center
        if volume[:,1].max()>high[1]:volume[:,1]-=volume[:,1].max()-high[1]
        if volume[:,1].min()<0:volume[:,1]-=volume[:,1].min()
        # Keep additions behind the already measured source-facing envelope.
        # No part of the original observed face is repainted by a new stone.
        hits=source_depth(core,g,ph,project(volume,g,ph))
        for vertex,points_on_ray in enumerate(hits):
            if not len(points_on_ray):continue
            limit=max(points_on_ray@eye)-.012;advance=volume[vertex]@eye-limit
            if advance>0:volume[vertex]-=eye*advance
        x,y=row['patch']['center'];stone=smooth[y,x,:3]
        luma=master_colors@np.array([.2126,.7152,.0722]);luma=np.clip(luma/np.median(luma),.8,1.15)
        growth=np.clip((master_colors[:,1]-master_colors[:,0]-.015)/.12,0,1)*.18
        palette=(stone[None,:]*(1-growth[:,None])+moss[None,:]*growth[:,None])*luma[:,None]
        rocks.append(volume[ids]);colors.append(palette[ids]*255.)
        records.append({'master':name,'source_patch':row['patch']['center'],'surface_point':row['point'].tolist(),'radii':row['radii'].tolist(),'embedded_normal_radius_fraction':.72,'projective_photo':False})
    core_palette=np.tile(moss*255.,(*core.shape[:2],1))
    # Pale stone patches on the observed body use feature-sized palette fields,
    # never copied photo fragments. Exact source-angle registration remains on
    # the one continuous original-facing body, only at that recorded direction.
    coordinates=project(core,g,ph)
    field=np.zeros(core.shape[:2]);tint=np.zeros_like(core)
    for patch in patches:
        delta=(coordinates-np.array(patch['center']))/np.array(patch['radius']);weight=np.maximum(0,1-(delta*delta).sum(2))**.4
        better=weight>field;field=np.maximum(field,weight);x,y=patch['center'];tint[better]=smooth[y,x,:3]*255.
    blend=np.clip(field*.9,0,.9);core_palette=core_palette*(1-blend[:,:,None])+tint*blend[:,:,None]
    triangles=np.concatenate([core,*rocks]);normals=vertex_normals(triangles);palette=np.concatenate([core_palette,*colors]);uv=np.full((*triangles.shape[:2],2),-1.)
    front=(core_normals.mean(1)@eye)>.58;uv[:len(core)][front]=project(core[front],g,ph)
    return meta,face,g,ph,triangles,normals,palette,uv,{'reused_masters':[v[3]for v in masters.values()],'deeply_overlapped_stone_reliefs':records,'source_patch_tile':tile,'continuous_core_triangles':len(core),'observed_core_triangles':int(front.sum()),'additional_triangles':sum(len(x)for x in rocks),'geometry_bounds':[triangles.reshape(-1,3).min(0).tolist(),triangles.reshape(-1,3).max(0).tolist()]}


def main():
    OUT.mkdir(exist_ok=True);meta,face,g,ph,points,normals,palette,uv,report=study();eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    blank=np.full_like(uv,-1.);native=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA')
    face.save(OUT/'12538-observed-native.png');native.save(OUT/'12538-native-untouched.png')
    raster(points,normals,uv,face,eye,g,ph,palette=palette,source=True).save(OUT/'12538-source-shaded.png')
    raster(points,normals,blank,face,[-1,.30,1],g,ph,palette=palette).save(OUT/'12538-front-independent.png')
    raster(points,normals,blank,face,[.5,.37,1],g,ph,palette=palette).save(OUT/'12538-rear-independent.png')
    raster(points,normals,blank,face,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    report.update(status='PRIVATE_ONE_FAMILY_NOT_ACCEPTED',source=meta,triangles=len(points),cpu_triangle_position_normal_color_uv_float64_bytes=points.nbytes+normals.nbytes+palette.nbytes+uv.nbytes,inference='One retained continuous source-contour mass, with irregular whole preserved RiverRock/SplitCrag masters deeply overlapped into hidden sides. This is intersecting visual geometry, not a Boolean welded mesh. Hidden depth/palette/occluded upper body are inferred. New stone surfaces carry no projected photograph. The original-facing continuous core alone can carry registered native paint near the exact original camera; other views use feature-sized independent stone/moss palette and will need fixed-scale fine material in actual rendering. Source footprint anchors, native walk/collision, original map placement counts, doors and routes are unchanged. No runtime publication.')
    (OUT/'study.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');np.savez_compressed(OUT/'geometry.npz',triangles=points,normals=normals,palette=palette,uv=uv)
    sheet=Image.new('RGB',(1440,1440),'#26333b');draw=ImageDraw.Draw(sheet)
    for index,name in enumerate(['12538-source-shaded.png','12538-front-independent.png','12538-rear-independent.png','12538-rear-clay.png']):
        image=Image.open(OUT/name).convert('RGB');image.thumbnail((700,680));x=index%2*720;y=index//2*720;sheet.paste(image,(x+(720-image.width)//2,y+32+(680-image.height)//2));draw.text((x+12,y+10),name,fill='white')
    sheet.save(OUT/'one-family-contact.png');print('EAST_CONNECTED_CLIFF_STUDY',len(report['deeply_overlapped_stone_reliefs']),'embedded irregular reliefs',len(points),'triangles; no runtime publication')


if __name__=='__main__':main()

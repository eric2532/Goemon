"""Private12538whole Edo moss-rock/foliage reuse; no runtime enrollment."""
import hashlib
import json
import math

import numpy as np
from PIL import Image

from asset_pipeline.glb import GLB
from east_cliff_geometry import project,raster
from prepare_east_cliff_boulder_study import ROOT,study,vertex_normals

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study/Whole Cluster04'


def main():
    OUT.mkdir(exist_ok=True)
    face,g,ph,old,_,old_palette,old_uv,description=study(12538);count=description['core_triangles'];core=old[:count].copy();eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    source_low,source_high=np.array(description['source_contour']['fitted_source_bounds']);crown=source_high[1];mid=(source_low+source_high)*.5
    # Recess the continuous moss core with a monotone view-depth map. Native
    # projection, ground and crown remain exact; modules can expose real rock
    # and foliage rather than being swallowed by a smooth outer envelope.
    fade=np.clip(core[:,:,1]/1.8,0,1)*np.clip((crown-core[:,:,1])/1.8,0,1)
    amount=.8*np.tanh(np.sum((core-mid)*eye,axis=2)/1.8)*fade
    core-=eye*amount[:,:,None]
    path=ROOT/'assets/models/edo/moss_rock.glb';model=GLB.read(path);assert model.doc['nodes']==[{'mesh':0,'name':'Body'}]
    primitives=[];textures=[];proof=[]
    for index,p in enumerate(model.doc['meshes'][0]['primitives']):
        vertices=np.asarray(model.accessor(p['attributes']['POSITION']));ids=np.asarray(model.accessor(p['indices']),int).reshape(-1,3)[:,[0,2,1]];uv=np.asarray(model.accessor(p['attributes']['TEXCOORD_0']))
        texture_path=ROOT/'assets/models/edo'/('moss_rock_rock.png'if index==0 else'moss_rock_leaf.png');texture=Image.open(texture_path).convert('RGBA')
        primitives.append((vertices,ids,uv));textures.append(texture);proof.append({'source_texture':str(texture_path.relative_to(ROOT)),'sha256':hashlib.sha256(texture_path.read_bytes()).hexdigest(),'triangles':len(ids)})
    full=np.concatenate([p[0]for p in primitives]);low,high=full.min(0),full.max(0);center=(low+high)*.5
    # Preserve the whole editable master's Y, rock/leaf relationship, UVs and
    # proportions. Native pale clusters choose positions; no green-rock blobs.
    selected=[]
    for row in sorted(description['placements'],key=lambda r:(not r['source_front'],r['point'][1],r['point'][0])):
        if row['source_patch_kind']!='native_pale_stone':continue
        point=np.array(row['point']);radius=max(row['radii'][0],row['radii'][2]);scale=min(1.35,max(.65,radius*1.1))
        if any(np.linalg.norm(point-s['point'])<1.8*min(scale,s['scale'])for s in selected):continue
        selected.append({'point':point,'normal':np.array(row['normal']),'scale':scale,'source_patch':row['source_patch'],'source_front':row['source_front']})
    # The original model uses repeat UVs, including negative coordinates.
    # Tiled source regions preserve that contract and the leaf alpha; neither
    # transparent leaf pixels nor out-of-tile UVs become opaque white geometry.
    atlas=Image.new('RGBA',(1024,896),(0,0,0,0));atlas.paste(face,(0,0));offset=256
    for i,texture in enumerate(textures):
        for y in range(3):
            for x in range(3):atlas.paste(texture,(offset+i*384+x*128,y*128))
    moss_texture=np.array(textures[0]).copy();moss_texture[:,:,:3]=(moss_texture[:,:,:3].astype(float)*np.array([.50,.88,.44])).clip(0,255).astype('uint8');moss_texture=Image.fromarray(moss_texture)
    for y in range(4):
        for x in range(4):atlas.paste(moss_texture,(x*128,384+y*128))
    triangles=[core];uvs=[old_uv[:count]];palettes=[old_palette[:count]];placements=[]
    for row in selected:
        normal=row['normal'];yaw=math.atan2(normal[0],normal[2]);c,s=math.cos(yaw),math.sin(yaw);rotation=np.array([[c,0,s],[0,1,0],[-s,0,c]])
        delta=(full-center)@rotation.T;point=row['point'].copy();scale=row['scale'];point-=normal*.30
        # Keep whole module proportions. Surface attachment is inferred within
        # the recorded cliff body; do not shrink edge modules into tiny dots.
        for axis in [0,2]:
            lo=point[axis]+delta[:,axis].min()*scale;hi=point[axis]+delta[:,axis].max()*scale
            if lo<source_low[axis]:point[axis]+=source_low[axis]-lo
            if hi>source_high[axis]:point[axis]-=hi-source_high[axis]
        top=point[1]+(high[1]-center[1])*scale;bottom=point[1]+(low[1]-center[1])*scale
        if top>crown:point[1]-=top-crown
        if bottom<0:point[1]-=bottom
        for index,(vertices,ids,uv)in enumerate(primitives):
            placed=(vertices-center)@rotation.T*scale+point;triangles.append(placed[ids]);colors=np.full((*ids.shape,3),255.);palettes.append(colors)
            mapped=(uv+np.array([1.,0.]))*np.array(textures[index].size)+np.array([offset+index*384,0]);uvs.append(mapped[ids])
        placements.append({'source_patch':row['source_patch'],'source_front':row['source_front'],'center':point.tolist(),'whole_uniform_scale':scale,'yaw':yaw,'source_position':row['point'].tolist()})
    triangles=np.concatenate(triangles);uv=np.concatenate(uvs);palette=np.concatenate(palettes);normals=vertex_normals(triangles)
    # Core photograph is a source-camera reference only. The actual whole
    # reused modules retain their original native UV/materials from every side.
    independent=uv.copy()
    for index in range(count):
        dominant=int(np.argmax(abs(normals[index].mean(0))))
        axes=[2,1]if dominant==0 else[0,2]if dominant==1 else[0,1]
        origin=np.array([320.,400.])if dominant==0 else np.array([64.,656.])if dominant==1 else np.array([64.,400.])
        independent[index]=triangles[index][:,axes]*32.+origin
    original_view=raster(triangles,normals,uv,atlas,eye,g,ph,source=True).crop((0,0,face.width*2,face.height*2));original_view.save(OUT/'12538-source-adapted.png')
    raster(triangles,normals,independent,atlas,[-1,.30,1],g,ph).save(OUT/'12538-front-whole-model.png')
    raster(triangles,normals,independent,atlas,[.5,.37,1],g,ph).save(OUT/'12538-rear-whole-model.png')
    raster(triangles,normals,None,atlas,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    native=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA');native.save(OUT/'12538-native-untouched.png');scaled=native.resize((face.width*2,face.height*2),Image.Resampling.NEAREST);pair=Image.new('RGB',(face.width*4,face.height*2),'#26333b');pair.paste(scaled,(0,0),scaled);pair.paste(original_view,(face.width*2,0));pair.save(OUT/'native-and-source.png')
    atlas.save(OUT/'source-atlas.png');np.savez_compressed(OUT/'geometry.npz',triangles=triangles,normals=normals,palette=palette,uv=uv)
    report={'status':'PRIVATE_SINGLE_FAMILY_UNACCEPTED','graphic':12538,'source_model':str(path.relative_to(ROOT)),'source_model_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_primitives':proof,'whole_clusters':len(placements),'placements':placements,'triangles':len(triangles),'retained_source_contour':description['source_contour'],'geometry_bounds':[triangles.reshape(-1,3).min(0).tolist(),triangles.reshape(-1,3).max(0).tolist()],'inference':'Whole compatible Edo moss-rock module, including its original separate foliage, source materials, UVs and proportions. Original measured pale stone clusters choose attachment positions, with uniform fitting/yaw/hidden continuation inferred. The source-facing contour core remains; no green feature is invented as another stone. No gameplay map/source placement/foot/collision/nav/route changes or runtime publication. Original-angle photograph is a reference on the observed core only; all reused module surfaces use their original rock/leaf texture, never wrapped nativecliff photographs.'}
    (OUT/'study.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('EAST_WHOLE_CLUSTER_STUDY',len(placements),'whole rock+foliage modules',len(triangles),'triangles')


if __name__=='__main__':main()

"""One private12538 column/ledge study; no asset enrollment or map mutation."""
import hashlib
import json
import math

import numpy as np
from PIL import Image, ImageFilter

from asset_pipeline.glb import GLB
from east_cliff_geometry import project, raster, rounded_native
from prepare_east_cliff_boulder_study import ROOT, study, vertex_normals
from prepare_east_cliff_mass_study import source_depth

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study/Columns And Ledges05'


def master(name):
    path=ROOT/'assets/models/cedar_pass'/f'{name}.glb';model=GLB.read(path)
    assert model.doc['nodes']==[{'mesh':0,'name':name}]
    primitive=model.doc['meshes'][0]['primitives'][0]
    vertices=np.asarray(model.accessor(primitive['attributes']['POSITION']))
    ids=np.asarray(model.accessor(primitive['indices']),int).reshape(-1,3)[:,[0,2,1]]
    low,high=vertices.min(0),vertices.max(0);center=(low+high)*.5
    # Preserve the whole master's XYZ proportions and upright Y. A single
    # bounded corner pass softens the original low-poly control mesh.
    triangles=rounded_native((vertices-center)[ids],1)
    return triangles,{'source':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_bounds':[low.tolist(),high.tolist()],'uniform_scale_only':True,'corner_passes':1}


def main():
    OUT.mkdir(exist_ok=True)
    face,g,ph,old,_,old_palette,old_uv,description=study(12538)
    count=description['core_triangles'];core=old[:count].copy();eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    source_low,source_high=np.array(description['source_contour']['fitted_source_bounds']);crown=source_high[1]
    original_core=core.copy();core_normals=vertex_normals(core)
    fade=np.clip(core[:,:,1]/1.3,0,1)*np.clip((crown-core[:,:,1])/1.3,0,1)
    recess=np.clip((.58-core_normals@eye)/.65,0,1)*1.65*fade
    core+=eye*recess[:,:,None]
    models={name:master(name)for name in ['split_crag','cliff_step','river_rock']}
    rgba=np.asarray(face,float)/255.;valid=rgba[:,:,3]>.5
    green=valid&(rgba[:,:,1]>rgba[:,:,0]*1.04)&(rgba[:,:,1]>rgba[:,:,2]*1.15)
    moss=np.median(rgba[green,:3],axis=0);smooth=np.asarray(face.filter(ImageFilter.GaussianBlur(2)),float)/255.
    grain=np.asarray(Image.open(ROOT/'assets/textures/wind_meadow/cliff_paint.png').convert('RGB'),float)/255.
    # One connected green matrix; source-sized pale features receive structural
    # stones, never a second population of equally sized green stones.
    core_colors=np.tile(moss*255.,(*core.shape[:2],1))
    selected=[]
    for row in sorted(description['placements'],key=lambda r:(not r['source_front'],-r['radii'][2],r['point'][1])):
        if row['source_patch_kind']!='native_pale_stone':continue
        point=np.array(row['point']);radius=max(row['radii'][0],row['radii'][2])
        if any(np.linalg.norm(point-np.array(old_row['point']))<.95*(radius+max(old_row['radii'][0],old_row['radii'][2]))for old_row in selected):continue
        selected.append(row)
    parts=[core];colors=[core_colors];uvs=[old_uv[:count]];records=[]
    for index,row in enumerate(selected):
        normal=np.array(row['normal']);point=np.array(row['point']);rx,_,ry=row['radii']
        name='river_rock'if point[1]<.8 else'cliff_step'if normal[1]>.42 or rx>ry*1.25 else'split_crag'
        original,proof=models[name];span=np.ptp(original.reshape(-1,3),axis=0)
        # The tall source patches select upright columns; broad low patches
        # select ledges. Uniform fitting keeps master Y roundness intact.
        scale=min(rx*2.0/span[0],ry*2.25/span[1]);scale=max(.18,min(.95,scale))
        yaw=math.atan2(normal[0],normal[2]);c,s=math.cos(yaw),math.sin(yaw);rotation=np.array([[c,0,s],[0,1,0],[-s,0,c]])
        module=original@rotation.T*scale
        halfdepth=max(.1,float(np.ptp(module.reshape(-1,3)@normal))*.5)
        center=point-normal*halfdepth*.25;module+=center
        if module[:,:,1].min()<0:module[:,:,1]-=module[:,:,1].min()
        if module[:,:,1].max()>crown:module[:,:,1]-=module[:,:,1].max()-crown
        # Whole master surfaces stay intact. Projectively flattening individual
        # vertices produced the rejected long strips and broken column faces.
        normals=vertex_normals(module)
        x,y=row['source_patch'];stone=smooth[y,x,:3]
        stone=np.maximum(stone,moss*np.array([1.3,1.03,1.12]));stone=np.minimum(stone,.90)
        cap=np.clip((normals[:,:,1]-.3)/.6,0,1)*.52
        palette=(stone[None,None,:]*(1-cap[:,:,None])+moss[None,None,:]*cap[:,:,None])*255.
        native_uv=project(module,g,ph);observed=(normals.mean(1)@eye)>.60;native_uv[~observed]=-1
        parts.append(module);colors.append(palette);uvs.append(native_uv)
        records.append({'master':name,'source_patch':row['source_patch'],'source_front':row['source_front'],'source_surface_point':row['point'],'uniform_scale':scale,'yaw':yaw,'embedded_halfdepth_fraction':.25,'green_stone':False,'front_photo':'Only original-facing surfaces; no hidden-side wrapping'})
    triangles=np.concatenate(parts);palette=np.concatenate(colors);uv=np.concatenate(uvs);normals=vertex_normals(triangles)
    # Fine world-sized existing painted grain on hidden stone/moss; no native
    # front photograph is repeated over individual volumes or grazing sides.
    factors=np.zeros(triangles.shape[:2])
    for axis,axes in [(0,[2,1]),(1,[0,2]),(2,[0,1])]:
        coords=triangles[:,:,axes]*1.15;ix=np.floor(coords[:,:,0]*grain.shape[1]).astype(int)%grain.shape[1];iy=np.floor(coords[:,:,1]*grain.shape[0]).astype(int)%grain.shape[0]
        grey=grain[iy,ix]@np.array([.2126,.7152,.0722]);weight=abs(normals[:,:,axis])**4;total=np.maximum(.001,np.sum(abs(normals)**4,axis=2));factors+=(.84+grey*.32)*weight/total
    palette*=factors[:,:,None]
    source=raster(triangles,normals,uv,face,eye,g,ph,source=True,palette=palette);source.save(OUT/'12538-source-shaded.png')
    for name,camera in [('front',[-1,.30,1]),('rear',[.5,.37,1])]:
        direction=np.array(camera);direction/=np.linalg.norm(direction);physical_uv=uv.copy()
        physical_uv[(normals.mean(1)@direction)<.45]=-1
        raster(triangles,normals,physical_uv,face,camera,g,ph,palette=palette).save(OUT/f'12538-{name}-independent.png')
    raster(triangles,normals,None,face,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    native=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA');native.save(OUT/'12538-native-untouched.png');scaled=native.resize((face.width*2,face.height*2),Image.Resampling.NEAREST)
    pair=Image.new('RGB',(face.width*4,face.height*2),'#26333b');pair.paste(scaled,(0,0),scaled);pair.paste(source,(face.width*2,0));pair.save(OUT/'native-and-source.png')
    np.savez_compressed(OUT/'geometry.npz',triangles=triangles,normals=normals,palette=palette,uv=uv)
    report={'status':'PRIVATE_SINGLE12538_NOT_ACCEPTED','graphic':12538,'triangles':len(triangles),'source_projectively_preserved_core_triangles':count,'structural_stones':len(records),'placements':records,'masters':[model[1]for model in models.values()],'source_contour':description['source_contour'],'geometry_bounds':[triangles.reshape(-1,3).min(0).tolist(),triangles.reshape(-1,3).max(0).tolist()],'inference':'Measured source contour/projection retained; hidden core is recessed1.65m along original view rays with ground/crown fade. Hidden pale columns/ledges inferred from original pale patch scales and carried around sides; whole Cedar masters keep upright Y/uniform proportions and overlap deeply. Green remains continuous moss/foliage matrix, not green stones. Original-facing core/column surfaces can carry registered native projection; grazing and hidden surfaces use independent pale stone/moss palette plus fixed-scale existing cliff grain. No whole-face wrap. Black upper occlusion remains unrecorded reconstruction. Source anchors, map placements, ground/crown/walk/collision/routes unchanged. Private geometry/material study only; no runtime publication or family acceptance.'}
    assert np.allclose(project(core,g,ph),project(original_core,g,ph))
    (OUT/'study.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('EAST_COLUMN_LEDGE_STUDY',len(records),'structural stones',len(triangles),'triangles; PRIVATE')


if __name__=='__main__':main()

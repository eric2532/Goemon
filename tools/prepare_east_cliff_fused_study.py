"""Private source-based12538 fused angular mass; originals remain read-only."""
import argparse
import hashlib
import json
import math
import numpy as np
from PIL import Image
from asset_pipeline.glb import GLB
from east_cliff_geometry import project, raster
from prepare_east_cliff_boulder_study import ROOT, study, vertex_normals

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study/Fused Angular14'


def prepare():
    OUT.mkdir(exist_ok=True)
    face,g,ph,old,_,_,_,description=study(12538);core=old[:description['core_triangles']]
    low,high=np.array(description['source_contour']['fitted_source_bounds']);parts=[{'name':'MeasuredClosedMatrix','triangles':core.tolist()}];masters={};sources={}
    raw={tuple(p['center']):p for p in description['measured_native_patches']if p['kind']=='native_pale_stone'}
    for name in ['split_crag','cliff_step']:
        path=ROOT/'assets/models/cedar_pass'/f'{name}.glb';glb=GLB.read(path);p=glb.doc['meshes'][0]['primitives'][0]
        points=np.asarray(glb.accessor(p['attributes']['POSITION']));ids=np.asarray(glb.accessor(p['indices']),int).reshape(-1,3)[:,[0,2,1]]
        span=np.ptp(points,axis=0);points-=(points.min(0)+points.max(0))*.5;masters[name]=(points,ids,span);sources[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    for index,row in enumerate(description['placements']):
        if row['source_patch_kind']!='native_pale_stone':continue
        normal=np.array(row['normal']);normal[1]=0
        if np.linalg.norm(normal)<.1:normal=np.array(row['point'])-(low+high)*.5;normal[1]=0
        normal/=np.linalg.norm(normal);patch=raw[tuple(row['source_patch'])];rx=patch['radius'][0]/(32/3*np.sqrt(2));ry=patch['radius'][1]*ph
        name='cliff_step'if rx>ry*1.7 else'split_crag';points,ids,span=masters[name];scale=min(rx*2.9/span[0],max(ry*4.7,rx*1.5)/span[1]);scale=np.clip(scale,.28,.95)
        yaw=math.atan2(normal[0],normal[2]);c,s=math.cos(yaw),math.sin(yaw);rotation=np.array([[c,0,s],[0,1,0],[-s,0,c]])
        placed=points@rotation.T*scale+np.array(row['point'])-normal*.15
        for axis in range(3):
            if placed[:,axis].min()<low[axis]:placed[:,axis]+=low[axis]-placed[:,axis].min()
            if placed[:,axis].max()>high[axis]:placed[:,axis]-=placed[:,axis].max()-high[axis]
        parts.append({'name':f'{name}_{index}','triangles':placed[ids].tolist(),'source_patch':row['source_patch'],'raw_radius':patch['radius'],'uniform_scale':float(scale)})
    payload={'source_contour':description['source_contour'],'graphic':g,'pixel_height':ph,'source_master_sha256':sources,'voxel_size_m':.075,'parts':parts,'inference':'Whole ORIGINAL angular Cedar crag/ledge geometry, with no Loop rounding or projective vertex flattening, intersects one source-fitted closed matrix. Remeshing is new shape authoring to fuse intersections, not optimization or a count/quality reduction. Ground/crown/foot/source placements/navigation remain separate original owners.'}
    (OUT/'source-geometry.json').write_text(json.dumps(payload,separators=(',',':')));face.save(OUT/'observed-native.png');print('EAST_FUSED_SOURCE_PARTS',len(parts))


def render():
    source=json.loads((OUT/'source-geometry.json').read_text());data=json.loads((OUT/'fused-geometry.json').read_text());points=np.array(data['vertices']);ids=np.array(data['faces'],int)[:,[0,2,1]];triangles=points[ids];normals=vertex_normals(triangles)
    face=Image.open(OUT/'observed-native.png').convert('RGBA');g=source['graphic'];ph=source['pixel_height'];eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    rgba=np.asarray(face,float);green=(rgba[:,:,3]>=128)&(rgba[:,:,1]>rgba[:,:,0]*1.04)&(rgba[:,:,1]>rgba[:,:,2]*1.15);warm=(rgba[:,:,3]>=128)&(rgba[:,:,0]>rgba[:,:,1]*.9)&(rgba[:,:,0]>100);moss=np.median(rgba[green,:3],axis=0);stone=np.median(rgba[warm,:3],axis=0)
    cap=np.clip((normals[:,:,1]-.12)/.65,0,1);coat=.18+cap*.65;palette=stone[None,None,:]*(1-coat[:,:,None])+moss[None,None,:]*coat[:,:,None];uv=project(triangles,g,ph)
    raster(triangles,normals,uv,face,eye,g,ph,source=True,palette=palette).save(OUT/'12538-source-shaded.png')
    for name,camera in[('front',[-1,.30,1]),('rear',[.5,.37,1])]:raster(triangles,normals,None,face,camera,g,ph,palette=palette).save(OUT/f'12538-{name}-color.png')
    raster(triangles,normals,None,face,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    native=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA');native.save(OUT/'12538-native-untouched.png');scaled=native.resize((face.width*2,face.height*2),Image.Resampling.NEAREST);pair=Image.new('RGB',(face.width*4,face.height*2),'#26333b');pair.paste(scaled,(0,0),scaled);pair.paste(Image.open(OUT/'12538-source-shaded.png'),(face.width*2,0));pair.save(OUT/'native-and-source.png')
    np.savez_compressed(OUT/'geometry.npz',triangles=triangles,normals=normals,palette=palette,uv=uv)
    report={'status':'PRIVATE_SINGLE12538_NOT_ACCEPTED','triangles':len(triangles),'blender_geometry':{k:v for k,v in data.items()if k not in['vertices','faces']},'source_inputs_sha256':source['source_master_sha256'],'source_contour':source['source_contour'],'voxel_size_m':source['voxel_size_m'],'inference':source['inference'],'visual_validation_pending':'Original silhouette/projection versus native and both physical faces must pass review. No runtime publication, source map layout, collider, nav, quest gate or source placement changes.'};(OUT/'study.json').write_text(json.dumps(report,indent=2)+'\n');print('EAST_FUSED_STUDY_RENDER',len(triangles),'triangles PRIVATE')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--render',action='store_true');args=parser.parse_args()
    render()if args.render else prepare()

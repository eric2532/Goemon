"""Private whole-crag assembly behind the retained12538 observed face."""
import hashlib
import json
import math

import numpy as np
from PIL import Image

from east_cliff_geometry import project, raster, native_triangles, rounded_native
from prepare_east_cliff_boulder_study import ROOT, source_body, vertex_normals
from prepare_east_cliff_column_study import master
from prepare_east_stone_profiles import source_contour_profile

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study/Whole Ridge Ring10'


def main():
    OUT.mkdir(exist_ok=True)
    meta,observed,observed_normals,face,g=source_body(12538);ph=meta['pixel_height'];eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    native=json.loads((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_text())['profiles']['12538'];profile,proof=source_contour_profile(face,g,native)
    loft=rounded_native(native_triangles(profile),2);normals=vertex_normals(loft);low,high=np.array(proof['fitted_source_bounds']);center=(low+high)*.5;crown=np.array(proof['crown'])
    # Retain only observed original-facing rock, not the rejected smooth green
    # inferred reverse. A closed inner body and whole crags own hidden depth.
    selected=np.zeros(len(observed),bool)
    shell=observed[selected];shell_uv=project(shell,g,ph)
    matrix=loft.copy();matrix[:,:,0]=center[0]+(matrix[:,:,0]-center[0])*.58;matrix[:,:,2]=center[2]+(matrix[:,:,2]-center[2])*.58;matrix[:,:,1]*=.85
    parts=[matrix,shell];colors=[np.tile([151.,151.,108.],(*matrix.shape[:2],1)),np.tile([126.,145.,88.],(*shell.shape[:2],1))];uvs=[np.full((*matrix.shape[:2],2),-1.),shell_uv]
    models={name:master(name)for name in ['split_crag','cliff_step','river_rock']}
    # Source-high side and whole footprint locate major structural courses.
    # Pale source spots are exposures on these bodies, not tiny loose stones.
    across=np.array([1.,0,1.]);across/=np.linalg.norm(across);inward=center-crown;inward[1]=0
    courses=[]
    ring=np.array(profile['vertices'])[:profile['sides']]
    for side in range(0,profile['sides'],2):
        height_=float(proof['side_heights'][side])
        if height_<.8:continue
        radial=ring[side]-center;radial[1]=0;position=center+radial*.76
        y=0.
        while y<height_-.3:
            course_height=min(3.8,height_-y);name='split_crag'if course_height>2.4 else'cliff_step'
            courses.append((name,position.copy(),y+course_height*.5,course_height,math.atan2(radial[0],radial[2])+.22))
            y+=course_height*.92
    records=[]
    for index,(name,position,y,height_,yaw)in enumerate(courses):
        original,source=models[name];span=np.ptp(original.reshape(-1,3),axis=0);scale=height_/span[1]
        at=position.copy();at[1]=y
        c,s=math.cos(yaw),math.sin(yaw);rotation=np.array([[c,0,s],[0,1,0],[-s,0,c]])
        volume=original@rotation.T*scale+at
        if volume[:,:,1].min()<0:volume[:,:,1]-=volume[:,:,1].min()
        if volume[:,:,1].max()>high[1]:volume[:,:,1]-=volume[:,:,1].max()-high[1]
        # Whole model dimensions remain uniform; rigid fitting keeps footprints.
        for axis in [0,2]:
            lo,hi=volume[:,:,axis].min(),volume[:,:,axis].max()
            if lo<low[axis]:volume[:,:,axis]+=low[axis]-lo
            if hi>high[axis]:volume[:,:,axis]-=hi-high[axis]
        ns=vertex_normals(volume);cap=np.clip((ns[:,:,1]-.28)/.6,0,1)
        pale=np.array([166.,162.,115.]);moss=np.array([77.,116.,58.]);palette=pale[None,None,:]*(1-cap[:,:,None]*.65)+moss[None,None,:]*cap[:,:,None]*.65
        parts.append(volume);colors.append(palette);uvs.append(project(volume,g,ph));records.append({'master':name,'uniform_scale':scale,'yaw':yaw,'center':at.tolist(),'source':source})
    triangles=np.concatenate(parts);palette=np.concatenate(colors);uv=np.concatenate(uvs);normals=vertex_normals(triangles)
    grain=np.asarray(Image.open(ROOT/'assets/textures/wind_meadow/cliff_paint.png').convert('RGB'),float)/255.
    variation=np.zeros(triangles.shape[:2])
    for axis,axes in [(0,[2,1]),(1,[0,2]),(2,[0,1])]:
        pos=triangles[:,:,axes]*1.08;ix=(pos[:,:,0]*grain.shape[1]).astype(int)%grain.shape[1];iy=(pos[:,:,1]*grain.shape[0]).astype(int)%grain.shape[0]
        grey=grain[iy,ix]@np.array([.2126,.7152,.0722]);weight=abs(normals[:,:,axis])**4;variation+=(.83+grey*.34)*weight/np.maximum(.001,np.sum(abs(normals)**4,axis=2))
    palette*=variation[:,:,None]
    raster(triangles,normals,uv,face,eye,g,ph,palette=palette,source=True).save(OUT/'12538-source-shaded.png')
    for name,camera in [('front',[-1,.30,1]),('rear',[.5,.37,1])]:
        viewing=np.array(camera);viewing/=np.linalg.norm(viewing);physical_uv=np.full_like(uv,-1.)
        raster(triangles,normals,physical_uv,face,camera,g,ph,palette=palette).save(OUT/f'12538-{name}-color.png')
    raster(triangles,normals,None,face,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    original=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA');original.save(OUT/'12538-native-untouched.png');scaled=original.resize((face.width*2,face.height*2),Image.Resampling.NEAREST)
    pair=Image.new('RGB',(face.width*4,face.height*2),'#26333b');pair.paste(scaled,(0,0),scaled);pair.paste(Image.open(OUT/'12538-source-shaded.png'),(face.width*2,0));pair.save(OUT/'native-and-source.png')
    np.savez_compressed(OUT/'geometry.npz',triangles=triangles,normals=normals,palette=palette,uv=uv)
    report={'status':'PRIVATE_ONE12538_NOT_ACCEPTED','triangles':len(triangles),'original_observed_face_triangles':len(shell),'closed_inner_matrix_triangles':len(matrix),'whole_crags':records,'source_contour':proof,'bounds':[triangles.reshape(-1,3).min(0).tolist(),triangles.reshape(-1,3).max(0).tolist()],'inference':'Existing whole SplitCrag/CliffStep masters assemble overlapping structural courses around the measured source side-height ring. No retained source-photo facade or smooth outer reverse covers those closed whole volumes; a reduced closed inner matrix only seals gaps. Original source-angle projection is a separate material reference; physical front/rear show independent natural finish. Only source-high side/foot/crown are measured; rear course arrangement, reduced inner closed matrix and natural hidden moss/stone finish are inferred. Whole uniform proportions/material pitch retained. No source layout, walk, collider, portal, map placement or runtime asset changes. Private shape comparison only; native silhouette and grazing paint must still be judged before any publication.'}
    (OUT/'study.json').write_text(json.dumps(report,indent=2)+'\n');print('EAST_WHOLE_CRAG_ASSEMBLY',len(records),'whole masters',len(triangles),'triangles PRIVATE')


if __name__=='__main__':main()

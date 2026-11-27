"""Private12538: pale patches are lower exposures of whole moss-coated rocks."""
import json
import numpy as np
from PIL import Image, ImageFilter
from east_cliff_geometry import project, raster
from prepare_east_cliff_boulder_study import ROOT, study, master, vertex_normals
from prepare_east_cliff_mass_study import source_depth

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study/Measured Moss Rocks13'


def main():
    OUT.mkdir(exist_ok=True)
    face,g,ph,old,_,_,_,description=study(12538);core=old[:description['core_triangles']].copy();eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    low,high=np.array(description['source_contour']['fitted_source_bounds']);middle=(low+high)*.5
    matrix=core.copy();matrix[:,:,0]=middle[0]+(matrix[:,:,0]-middle[0])*.55;matrix[:,:,2]=middle[2]+(matrix[:,:,2]-middle[2])*.55;matrix[:,:,1]*=.76
    stone,normals,original_colors,ids,proof=master();front=[row for row in description['placements']if row['source_front']and row['source_patch_kind']=='native_pale_stone']
    rgba=np.asarray(face,float);green=(rgba[:,:,3]>=128)&(rgba[:,:,1]>rgba[:,:,0]*1.04)&(rgba[:,:,1]>rgba[:,:,2]*1.15);moss=np.median(rgba[green,:3],axis=0);blur=np.asarray(face.filter(ImageFilter.GaussianBlur(2)),float)
    raw_patches={tuple(p['center']):p for p in description['measured_native_patches']if p['kind']=='native_pale_stone'}
    moss_pattern=np.asarray(Image.open(ROOT/'assets/models/edo/moss_rock_leaf.png').convert('RGB'),float)/255.
    parts=[matrix];colors=[np.tile(moss,(*matrix.shape[:2],1))];placements=[]
    for source in front:
        pixel=np.array(source['source_patch']);hits=source_depth(core,g,ph,[pixel])[0]
        if len(hits)<2:continue
        for reverse in [False,True]:
            point=hits[np.argmin(hits@eye)if reverse else np.argmax(hits@eye)].copy()
            outward=np.array([1.,0,-1.])if reverse else np.array([-1.,0,1.]);outward/=np.linalg.norm(outward)
            across=np.cross([0,1,0],outward);basis=np.stack([across,[0,1,0],outward],axis=1)
            # The native pale patch is the lower exposed portion; its green
            # mass above belongs to this same whole rock, not a second stone.
            raw=raw_patches[tuple(source['source_patch'])];rx=raw['radius'][0]/(32/3*np.sqrt(2));ry=raw['radius'][1]*ph;radii=np.array([rx*1.12,max(rx*.72,ry*1.5),max(.4,min(1.0,rx*1.03))])
            center=point+np.array([0,ry*.35,0])-outward*.12
            points=stone*radii@basis.T+center
            if points[:,1].min()<0:points[:,1]-=points[:,1].min()
            if points[:,1].max()>high[1]:points[:,1]-=points[:,1].max()-high[1]
            for axis in[0,2]:
                if points[:,axis].min()<low[axis]:points[:,axis]+=low[axis]-points[:,axis].min()
                if points[:,axis].max()>high[axis]:points[:,axis]-=points[:,axis].max()-high[axis]
            local=(stone[:,1]+1.)*.5
            texture_uv=points[:,[0,2]]*1.65;ix=(texture_uv[:,0]*128).astype(int)%128;iy=(texture_uv[:,1]*128).astype(int)%128
            noise=moss_pattern[iy,ix]@np.array([.2126,.7152,.0722]);noise=(noise-np.median(noise))/max(.02,float(np.std(noise)))
            cap=np.clip((local-.40+noise*.22)/.22,0,1);cap=cap*cap*(3-2*cap)
            x,y=source['source_patch'];pale=blur[y,x,:3];palette=pale[None,:]*(1-cap[:,None])+moss[None,:]*cap[:,None]
            variation=original_colors@np.array([.2126,.7152,.0722]);variation=np.clip(variation/max(.01,float(np.median(variation))),.88,1.12);palette*=variation[:,None]
            parts.append(points[ids]);colors.append(palette[ids]);placements.append({'native_pale_exposure':source['source_patch'],'inferred_reverse':reverse,'center':center.tolist(),'radii':radii.tolist(),'native_raw_radii':raw['radius'],'upright_y':True,'separate_green_stone':False})
    triangles=np.concatenate(parts);palette=np.concatenate(colors);ns=vertex_normals(triangles);uv=project(triangles,g,ph)
    raster(triangles,ns,uv,face,eye,g,ph,source=True,palette=palette).save(OUT/'12538-source-shaded.png')
    for name,camera in[('front',[-1,.30,1]),('rear',[.5,.37,1])]:raster(triangles,ns,None,face,camera,g,ph,palette=palette).save(OUT/f'12538-{name}-color.png')
    raster(triangles,ns,None,face,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    native=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA');native.save(OUT/'12538-native-untouched.png');scaled=native.resize((face.width*2,face.height*2),Image.Resampling.NEAREST);pair=Image.new('RGB',(face.width*4,face.height*2),'#26333b');pair.paste(scaled,(0,0),scaled);pair.paste(Image.open(OUT/'12538-source-shaded.png'),(face.width*2,0));pair.save(OUT/'native-and-source.png')
    np.savez_compressed(OUT/'geometry.npz',triangles=triangles,normals=ns,palette=palette,uv=uv)
    report={'status':'PRIVATE_SINGLE12538_NOT_ACCEPTED','triangles':len(triangles),'whole_closed_rocks':len(placements),'placements':placements,'reused_master':proof,'source_contour':description['source_contour'],'inference':'Raw per-exposure source radii replace the old.9/.81 clamps. One whole moss-coated rock for each original pale exposure; the green upper mass is part of that rock. WorldY stays upright; no extra ownerYscale, normal-asY rotation or projective vertex flattening. Reverse exposures continue the same source design at the far source-envelope intersection; depth/upper rock continuation and reduced hidden core are inferred. Existing Edo moss texture modulates the material boundary, avoiding identical horizontal bands. No distinct green-stone population and no photo fragments on physical views. Native RGB is separate original-angle reference. Source footprints/anchors/walk/doors/map placements unchanged; no runtime publication.'}
    (OUT/'study.json').write_text(json.dumps(report,indent=2)+'\n');print('EAST_MOSS_COATED_ROCK_STUDY',len(placements),'closed rocks',len(triangles),'triangles PRIVATE')


if __name__=='__main__':main()

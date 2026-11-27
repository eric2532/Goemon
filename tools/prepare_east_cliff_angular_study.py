"""Private single-family angular/embedded repair of the retained cliff study."""
import hashlib
import json

import numpy as np
from PIL import Image, ImageFilter

from east_cliff_geometry import project,raster,rounded_native
from prepare_east_cliff_boulder_study import ROOT,study,vertex_normals
from prepare_east_cliff_mass_study import master,source_depth

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study/Angular Embedded03'


def main():
    OUT.mkdir(exist_ok=True)
    face,g,ph,old,normals,old_palette,old_uv,description=study(12538)
    count=description['core_triangles'];core=old[:count].copy();eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    u=np.array([1.,0,1.]);u/=np.linalg.norm(u);v=np.cross(u,eye);v/=np.linalg.norm(v)
    models={name:master(name)for name in ['river_rock','split_crag']};parts=[core];colors=[old_palette[:count]];uvs=[old_uv[:count]];records=[]
    rgba=np.asarray(face,float)/255.;leaf=(rgba[:,:,3]>.5)&(rgba[:,:,1]>rgba[:,:,0]*1.04)&(rgba[:,:,1]>rgba[:,:,2]*1.15);moss=np.median(rgba[leaf,:3],axis=0);blur=np.asarray(face.filter(ImageFilter.GaussianBlur(2)),float)/255.
    high=description['source_contour']['fitted_source_bounds'][1][1]
    for index,row in enumerate(description['placements']):
        normal=np.array(row['normal']);position=np.array(row['point']);rx,depth,ry=row['radii']
        # The old study turned the master's Y dome toward the surface normal.
        # Keep its actual Y as tangent-up; only inferred depth changes.
        across=np.eye(3)[int(np.argmin(abs(normal)))];across=across-normal*(across@normal);across/=np.linalg.norm(across);up=np.cross(across,normal)
        if row['source_front']:across,up=u,v
        if up[1]<0:across=-across;up=-up
        depth=max(.9,depth*1.6,rx*1.15,ry*1.05)
        basis=np.stack([across,up,normal],axis=1);matrix=basis*np.array([rx,ry,depth])[None,:]
        name='split_crag' if index%3!=1 else 'river_rock';vertices,master_colors,ids,proof=models[name]
        original_vertices=vertices
        softened=rounded_native(vertices[ids],1);vertices=softened.reshape(-1,3)
        nearest=np.argmin(np.sum((vertices[:,None,:]-original_vertices[None,:,:])**2,axis=2),axis=1);master_colors=master_colors[nearest];ids=np.arange(len(vertices)).reshape(-1,3)
        center=position-normal*depth*.52;volume=vertices@matrix.T+center
        if volume[:,1].max()>high:
            excess=volume[:,1].max()-high
            volume-=eye*(excess/eye[1]) if row['source_front'] else np.array([0,excess,0])
        if volume[:,1].min()<0:
            deficit=-volume[:,1].min()
            volume+=eye*(deficit/eye[1]) if row['source_front'] else np.array([0,deficit,0])
        if not row['source_front']:
            for vertex,hits in enumerate(source_depth(core,g,ph,project(volume,g,ph))):
                if len(hits):
                    advance=volume[vertex]@eye-max(hits@eye)+.012
                    if advance>0:volume[vertex]-=eye*advance
        patch=row['source_patch'];x,y=patch;stone=blur[y,x,:3]
        growth=np.clip((master_colors[:,1]-master_colors[:,0]-.015)/.12,0,1)
        blend=growth*.25 if row['source_patch_kind']=='native_pale_stone' else .60+growth*.40
        luma=master_colors@np.array([.2126,.7152,.0722]);luma=np.clip(1+(luma/np.median(luma)-1)*.25,.92,1.08)
        palette=(stone[None,:]*(1-blend[:,None])+moss[None,:]*blend[:,None])*luma[:,None]
        part=volume[ids];parts.append(part);colors.append(palette[ids]*255.)
        # Exact original-angle coverage is classified from the unchanged native
        # image/envelope, not each deformed rock normal. Physical front/rear
        # studies below deliberately omit photo projection entirely.
        texture_uv=project(part,g,ph)
        uvs.append(texture_uv)
        records.append({**row,'reused_master':name,'closed_edge_softening_passes':1,'physical_local_y':'tangent-up, never surface-normal','inferred_depth':depth,'embedded_normal_radius_fraction':.52,'projected_photo':'original native image/envelope coverage only at its exact camera; omitted entirely from physical front/rear studies'})
    points=np.concatenate(parts);normals=vertex_normals(points);palette=np.concatenate(colors);uv=np.concatenate(uvs)
    # The independent finish uses the existing fixed-world-scale cliff grain.
    grain=np.asarray(Image.open(ROOT/'assets/textures/wind_meadow/cliff_paint.png').convert('RGB'),float)/255.
    for axis,axes in [(0,[2,1]),(1,[0,2]),(2,[0,1])]:
        coords=points[:,:,axes]*1.08;xx=np.floor(coords[:,:,0]*grain.shape[1]).astype(int)%grain.shape[1];yy=np.floor(coords[:,:,1]*grain.shape[0]).astype(int)%grain.shape[0]
        grey=grain[yy,xx]@np.array([.2126,.7152,.0722]);weight=abs(normals[:,:,axis])**4;total=np.sum(abs(normals)**4,axis=2)
        palette*=(1+((.83+grey*.34)-1)*(weight/np.maximum(.001,total)))[:,:,None]
    source=raster(points,normals,uv,face,eye,g,ph,source=True,palette=palette);source.save(OUT/'12538-source-shaded.png')
    independent=np.full_like(uv,-1.)
    raster(points,normals,independent,face,[-1,.30,1],g,ph,palette=palette).save(OUT/'12538-front-independent.png')
    raster(points,normals,independent,face,[.5,.37,1],g,ph,palette=palette).save(OUT/'12538-rear-independent.png')
    raster(points,normals,independent,face,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    native=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA')
    original=json.loads((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_text())['profiles']['12538']['rgba_sha256']
    assert hashlib.sha256(native.tobytes()).hexdigest()==original
    native.save(OUT/'12538-native-untouched.png')
    canvas=Image.new('RGB',(face.width*4,face.height*2),'#26333b');scaled=native.resize((face.width*2,face.height*2),Image.Resampling.NEAREST);canvas.paste(scaled,(0,0),scaled);canvas.paste(source,(face.width*2,0));canvas.save(OUT/'native-and-source.png')
    np.savez_compressed(OUT/'geometry.npz',triangles=points,normals=normals,palette=palette,uv=uv)
    report={'status':'PRIVATE_SINGLE_FAMILY_UNACCEPTED','graphic':12538,'triangles':len(points),'unchanged_source_core_triangles':count,'unchanged_source_patch_placements':len(records),'master_preservation':[model[3]for model in models.values()],'source_contour':description['source_contour'],'placements':records,'geometry_bounds':[points.reshape(-1,3).min(0).tolist(),points.reshape(-1,3).max(0).tolist()],'material':'Only observed front-facing facets can carry original-angle native projection. All physical gameplay/front/rear studies shown separately use independent source palette + preserved fixed-world-scale cliff grain, no full-sprite fragments. Proposed actual shader fades projected art outside a narrow original camera cone.','inference':'Retained source-contour body and all measured/continued feature positions remain. Added original whole angular masters keep tangent-up Y, increased inferred normal depth and52percent embedding to overlap the core. These are intersecting visual volumes, not Boolean welded. Hidden shape/depth/upper occlusion is reconstructed; no maps/source placements/collision/walk/routes changed. No runtime publication.'}
    (OUT/'study.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('EAST_ANGULAR_EMBEDDED_STUDY',len(records),'retained stone positions',len(points),'triangles')


if __name__=='__main__':main()

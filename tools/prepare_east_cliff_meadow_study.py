"""Private whole-Meadow-rock source-contour deformation for12538."""
import hashlib
import json
import numpy as np
from PIL import Image
from asset_pipeline.glb import GLB
from east_cliff_geometry import native_triangles, project, raster
from prepare_east_cliff_boulder_study import ROOT, source_body, vertex_normals, intersections
from prepare_east_stone_profiles import source_contour_profile

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study/Whole Meadow Rock11'


def main():
    OUT.mkdir(exist_ok=True)
    meta,_,_,face,g=source_body(12538);ph=meta['pixel_height']
    source=json.loads((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_text())['profiles']['12538'];profile,proof=source_contour_profile(face,g,source)
    body=native_triangles(profile);low,high=np.array(proof['fitted_source_bounds']);center=(low+high)*.5;crown=np.array(profile['crown'])
    path=ROOT/'assets/models/environments/wind_meadow/mossy_boulder.glb';model=GLB.read(path);assert len(model.doc['meshes'])==1 and len(model.doc['nodes'])==1
    p=model.doc['meshes'][0]['primitives'][0];points=np.asarray(model.accessor(p['attributes']['POSITION']));ids=np.asarray(model.accessor(p['indices']),int).reshape(-1,3)[:,[0,2,1]];colors=np.asarray(model.accessor(p['attributes']['COLOR_0']))[:,:3]
    original=points.copy();bounds=[points.min(0),points.max(0)];unit=(points-bounds[0])/(bounds[1]-bounds[0]);fitted=[]
    for fraction in unit:
        at=low+(high-low)*fraction;blend=fraction[1]**2
        at[[0,2]]=at[[0,2]]*(1-blend)+crown[[0,2]]*blend
        hits=intersections(body,at[[0,2]],[0,2]);ceiling=max((hit[0][1]for hit in hits),default=high[1])
        at[1]=fraction[1]*ceiling;fitted.append(at)
    fitted=np.array(fitted);fitted[:,1]*=high[1]/fitted[:,1].max();triangles=fitted[ids];normals=vertex_normals(triangles)
    rgb=np.asarray(face)[:,:,:3].astype(float);alpha=np.asarray(face)[:,:,3]>=128;green=alpha&(rgb[:,:,1]>rgb[:,:,0]*1.04)&(rgb[:,:,1]>rgb[:,:,2]*1.15);warm=alpha&(rgb[:,:,0]>rgb[:,:,1]*.9)&(rgb[:,:,0]>100)
    moss=np.median(rgb[green],axis=0);stone=np.median(rgb[warm],axis=0);material_green=np.clip((colors[:,1]-colors[:,0]-.015)/.12,0,1)
    luma=colors@np.array([.2126,.7152,.0722]);luma=np.clip(luma/max(.01,float(np.median(luma))),.85,1.18)
    palette=(stone[None,:]*(1-material_green[:,None])+moss[None,:]*material_green[:,None])*luma[:,None];palette=palette[ids]
    eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye);uv=project(triangles,g,ph)
    raster(triangles,normals,uv,face,eye,g,ph,source=True,palette=palette).save(OUT/'12538-source-shaded.png')
    for name,camera in [('front',[-1,.30,1]),('rear',[.5,.37,1])]:raster(triangles,normals,None,face,camera,g,ph,palette=palette).save(OUT/f'12538-{name}-color.png')
    raster(triangles,normals,None,face,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    native=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA');native.save(OUT/'12538-native-untouched.png');scaled=native.resize((face.width*2,face.height*2),Image.Resampling.NEAREST);pair=Image.new('RGB',(face.width*4,face.height*2),'#26333b');pair.paste(scaled,(0,0),scaled);pair.paste(Image.open(OUT/'12538-source-shaded.png'),(face.width*2,0));pair.save(OUT/'native-and-source.png')
    np.savez_compressed(OUT/'geometry.npz',triangles=triangles,normals=normals,palette=palette,uv=uv)
    report={'status':'PRIVATE_SINGLE12538_NOT_ACCEPTED','whole_master':str(path.relative_to(ROOT)),'whole_master_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_vertex_bounds':[b.tolist()for b in bounds],'triangles':len(triangles),'topology_original':True,'source_contour':proof,'bounds':[fitted.min(0).tolist(),fitted.max(0).tolist()],'inference':'Whole approved Meadow mossy-boulder topology is reused, with an explicit source-contour deformation: source footprint bounds set X/Z, measured high-side crown attracts upper vertices, source-profile vertical intersections set each vertex ceiling. No source master changes or extra Y-owner compression. Existing stone/moss material partition and native palette continue around hidden sides. Original image is reference-only at source angle; physical front/rear show independent finish. Hidden deformation is reconstructed3D, not original3Dproof. No runtime/map/footprint/walk/collider/route or source placement changes.'}
    (OUT/'study.json').write_text(json.dumps(report,indent=2)+'\n');print('EAST_WHOLE_MEADOW_STUDY',len(triangles),'triangles PRIVATE')


if __name__=='__main__':main()

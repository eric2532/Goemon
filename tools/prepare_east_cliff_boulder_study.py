"""One private East cliff volume study using preserved stone-master geometry."""
import hashlib
import json
import math
import struct
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from asset_pipeline.glb import GLB
from east_cliff_geometry import clean_face, lobes, native_patch_sampler, native_triangles, project, raster, rounded_native

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/maps/falan/east_field_cliffs/relief'
OUT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study'
MODEL = ROOT / 'assets/models/cedar_pass/river_rock.glb'


def decode_published_reference(serial):
    meta = json.loads((FOLDER/'data.json').read_text())['graphics'][str(serial)]
    blob = (FOLDER/f'{serial}.bin').read_bytes()
    assert blob[:4] == b'ECR3'
    ns, np_, ni, npi, length = struct.unpack_from('<IIIII', blob, 4)
    raw = zlib.decompress(blob[24:]); assert len(raw) == length
    solid = np.frombuffer(raw[:ns*40], '<f4').reshape(-1, 10)
    ids = np.frombuffer(raw[(ns*10+np_*12)*4:], '<u4')[:ni].reshape(-1, 3)
    center = np.array([(meta['source_footprint'][0]-1)*1.5, 0., -(meta['source_footprint'][1]-1)*1.5])
    return meta, solid[ids, :3]+center, solid[ids, 3:6]


def source_body(serial):
    """Reproduce the retained source-facing body from authoritative native inputs.

    Runtime derivatives never become their own editable source. The native image,
    shared source profile and explicit East contour fitter remain authoritative.
    """
    from prepare_east_stone_profiles import source_contour_profile
    source_path=ROOT/'assets/maps/original_crossgate/cliff-profiles.json';source=json.loads(source_path.read_text());graphic=source['extra_graphics'][str(serial)]
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
    row=lib.serial_index()[serial];original=lib.image_from_record(row['pack'],row['row']).convert('RGBA')
    assert hashlib.sha256(original.tobytes()).hexdigest()==source['profiles'][str(serial)]['rgba_sha256']
    face,valid,fade=clean_face(original);profile,proof=source_contour_profile(face,graphic,source['profiles'][str(serial)]);ph=profile['pixel_height'];patches=lobes(original,valid)
    yy,xx=np.mgrid[:face.height,:face.width];depth=np.zeros(valid.shape)
    for patch in patches:
        x,y=patch['center'];rx,ry=patch['radius'];height=min(.70,max(.22,min(rx/(32/3*math.sqrt(2)),ry*ph)*1.35));patch['inferred_depth_m']=round(height,4)
        depth=np.maximum(depth,height*np.maximum(0,1-((xx-x)/rx)**2-((yy-y)/ry)**2)**.55)
    depth*=np.clip(fade*4,0,1)
    rounded=rounded_native(native_triangles(profile));normals=vertex_normals(rounded);eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    fitted=np.asarray(profile['vertices']+[profile['crown']]);low,high=fitted.min(0),fitted.max(0)
    def sample(uv):
        x,y=uv
        if not 0<=x<face.width-1 or not 0<=y<face.height-1:return 0.
        a,b=int(x),int(y);fx,fy=x-a,y-b
        return (depth[b,a]*(1-fx)+depth[b,a+1]*fx)*(1-fy)+(depth[b+1,a]*(1-fx)+depth[b+1,a+1]*fx)*fy
    result=[]
    for triangle,normal_row in zip(rounded,normals):
        values=[]
        for point,normal in zip(triangle,normal_row):
            view=normal@eye;cap=np.clip((normal[1]-.45)/.35,0,1);cap=cap*cap*(3-2*cap);at=point.copy();at[1]-=1.2*cap
            amount=sample(project(at,graphic,ph));blend=np.clip((view-.3)/.3,0,1);blend=blend*blend*(3-2*blend)*(1-cap)
            delta=(eye*blend+normal*.85*(1-blend))*amount;limit=1.
            for axis in range(3):
                if delta[axis]>1e-8:limit=min(limit,(high[axis]-point[axis])/delta[axis])
                elif delta[axis]<-1e-8:limit=min(limit,(low[axis]-point[axis])/delta[axis])
            values.append(point+delta*max(0,limit))
        result.append(values)
    result=np.asarray(result);normals=vertex_normals(result);center=np.array([(graphic['footprint'][0]-1)*1.5,0.,-(graphic['footprint'][1]-1)*1.5])
    # Retain the existing encoded body's Float32 frame exactly for the visual
    # comparison, without reading any generated runtime geometry as an input.
    result=(result-center).astype(np.float32).astype(float)+center;normals=normals.astype(np.float32).astype(float)
    meta={'native_rgba_sha256':hashlib.sha256(original.tobytes()).hexdigest(),'source_profile_sha256':hashlib.sha256(source_path.read_bytes()).hexdigest(),'source_origin':graphic['origin'],'source_footprint':graphic['footprint'],'pixel_height':ph,'measured_native_lobes':patches,'source_contour':proof}
    return meta,result,normals,face,graphic


def vertex_normals(triangles):
    key = lambda point: tuple(np.round(point, 7))
    sums = {}
    for triangle in triangles:
        normal = np.cross(triangle[2]-triangle[0], triangle[1]-triangle[0])
        for point in triangle: sums[key(point)] = sums.get(key(point), np.zeros(3)) + normal
    for point, normal in sums.items(): sums[point] = normal / max(1e-12, np.linalg.norm(normal))
    return np.asarray([[sums[key(point)] for point in triangle] for triangle in triangles])


def intersections(triangles, point, axes):
    """Source-envelope intersections along one existing world axis."""
    a, b, c = triangles[:, 0, axes], triangles[:, 1, axes], triangles[:, 2, axes]
    # NumPy advanced indices keep the axis dimension first; transpose if needed.
    if a.shape[1] != 2: a, b, c = a.T, b.T, c.T
    ab, ac, q = b-a, c-a, np.asarray(point)-a
    divisor = ab[:,0]*ac[:,1]-ab[:,1]*ac[:,0]
    valid = abs(divisor) > 1e-10; divisor = np.where(valid, divisor, 1.)
    wb = (q[:,0]*ac[:,1]-q[:,1]*ac[:,0])/divisor
    wc = (ab[:,0]*q[:,1]-ab[:,1]*q[:,0])/divisor; wa = 1-wb-wc
    valid &= np.minimum(wa, np.minimum(wb, wc)) >= -1e-5
    return [(triangles[index,0]*wa[index]+triangles[index,1]*wb[index]+triangles[index,2]*wc[index], index) for index in np.flatnonzero(valid)]


def master():
    glb = GLB.read(MODEL)
    assert len(glb.doc['nodes'])==1 and glb.doc['nodes'][0].get('mesh')==0 and not any(key in glb.doc['nodes'][0] for key in ['matrix','translation','rotation','scale']), 'Inspect changed master transforms before reuse'
    primitive = glb.doc['meshes'][0]['primitives'][0]
    positions = np.asarray(glb.accessor(primitive['attributes']['POSITION']))
    normals = np.asarray(glb.accessor(primitive['attributes']['NORMAL']))
    colors = np.asarray(glb.accessor(primitive['attributes']['COLOR_0']))[:, :3] if 'COLOR_0' in primitive['attributes'] else np.tile([.4,.45,.35],(len(positions),1))
    ids = np.asarray(glb.accessor(primitive['indices']), dtype=int).reshape(-1, 3)[:,[0,2,1]]
    low, high = positions.min(0), positions.max(0)
    scale = (high-low)*.5
    # The model's own Y is normalized once; no .1/.045 owner scale is applied.
    positions = (positions-(low+high)*.5)/scale
    # One closed Loop pass removes this compatible master's flat low-poly corners;
    # the original asset, dimensions and characteristic asymmetry remain intact.
    original=positions.copy();rounded=rounded_native(positions[ids],1);positions=rounded.reshape(-1,3)
    distance=np.linalg.norm(positions[:,None,:]-original[None,:,:],axis=2);nearest=np.argsort(distance,axis=1)[:,:3]
    weights=1/np.maximum(.01,np.take_along_axis(distance,nearest,axis=1));weights/=weights.sum(1)[:,None]
    colors=(colors[nearest]*weights[:,:,None]).sum(1);normals=vertex_normals(rounded).reshape(-1,3);ids=np.arange(len(positions)).reshape(-1,3)
    return positions, normals, colors, ids, {'source': str(MODEL.relative_to(ROOT)), 'sha256': hashlib.sha256(MODEL.read_bytes()).hexdigest(), 'source_bounds': [low.tolist(), high.tolist()], 'triangles': len(ids), 'closed_loop_rounding_passes':1, 'owner_y_scale_applied': False}


def study(serial=12538):
    meta, core, core_normals,face,_ = source_body(serial)
    g = {'origin': meta['source_origin'], 'footprint': meta['source_footprint']}; ph = meta['pixel_height']
    eye = np.array([-1.,16*ph,1.]); eye /= np.linalg.norm(eye)
    # Reuse the source-fitted envelope, not the old uniform-height box.
    sys.path.insert(0, str(ROOT/'tools'))
    from prepare_east_stone_profiles import source_contour_profile
    source = json.loads((ROOT/'assets/maps/original_crossgate/cliff-profiles.json').read_text())
    profile, proof = source_contour_profile(face, g, source['profiles'][str(serial)])
    coarse = native_triangles(profile)
    placement_surface=core
    envelope_normals=core_normals.mean(1);envelope_normals/=np.maximum(1e-12,np.linalg.norm(envelope_normals,axis=1))[:,None]
    low, high = coarse.reshape(-1,3).min(0), coarse.reshape(-1,3).max(0)
    measured=[dict(p,kind='native_pale_stone')for p in meta['measured_native_lobes']]
    original_rgba=np.asarray(face);r,g_,b=original_rgba[:,:,:3].astype(float).transpose(2,0,1)
    green=np.uint8(np.clip((g_-.72*r-.28*b)*3+g_*.25,0,255));green_image=Image.fromarray(green).convert('RGBA');green_image.putalpha(face.getchannel('A'))
    for patch in lobes(green_image,original_rgba[:,:,3]>=128):
        if any(np.linalg.norm(np.array(patch['center'])-p['center'])<8 for p in measured):continue
        rx,ry=patch['radius'];patch['inferred_depth_m']=min(.70,max(.22,min(rx/(32/3*math.sqrt(2)),ry*ph)*1.35));patch['kind']='native_moss_mass';measured.append(patch)
    _, tile = native_patch_sampler(face, meta['measured_native_lobes'], ph)
    tx, ty, tw, th = tile['source_window']
    patches = [p for p in measured if tx<=p['center'][0]<tx+tw and ty<=p['center'][1]<ty+th]
    image = np.asarray(face.filter(ImageFilter.GaussianBlur(2)),float)/255.
    rgba = np.asarray(face,float)/255.; leaf=(rgba[:,:,3]>.5)&(rgba[:,:,1]>rgba[:,:,0]*1.04)&(rgba[:,:,1]>rgba[:,:,2]*1.15); moss=np.median(rgba[leaf,:3],axis=0)
    u_scale=32/3*math.sqrt(2); v_scale=1/ph
    moss_patches=[p for p in measured if p['kind']=='native_moss_mass']
    moss_tile=None
    variants=[('primary',tile,patches,[0.,0.])]
    if moss_patches:
        _,moss_tile=native_patch_sampler(face,moss_patches,ph)
        mx,my,mw,mh=moss_tile['source_window'];extra=[p for p in moss_patches if mx<=p['center'][0]<mx+mw and my<=p['center'][1]<my+mh]
        variants.append(('moss_gap',moss_tile,extra,[mw*.5,mh*.5]))
    selected=[]
    for tag,tile_info,source_patches,phase in variants:
        tx,ty,tw,th=tile_info['source_window'];candidates=[]
        for axis, axes in [(0,[2,1]),(2,[0,1]),(1,[0,2])]:
            # Original measured patches continue at the same world pitch. The
            # second moss phase fills only gaps left by the first stone layer.
            for ix in range(math.floor(low[axes[0]]*u_scale/tw)-1,math.ceil(high[axes[0]]*u_scale/tw)+1):
                for iy in range(math.floor(low[axes[1]]*v_scale/th)-1,math.ceil(high[axes[1]]*v_scale/th)+1):
                    for patch in source_patches:
                        cx,cy=np.array(patch['center'])-[tx,ty]+phase
                        at=[(ix*tw+cx)/u_scale,(iy*th+cy)/v_scale]
                        hits=intersections(placement_surface,at,axes)
                        if not hits:continue
                        hits=[min(hits,key=lambda hit:hit[0][axis]),max(hits,key=lambda hit:hit[0][axis])]
                        for point,index in hits:
                            normal=envelope_normals[index]
                            if abs(normal[axis])+1e-4<max(abs(normal)):continue
                            if axis==1 and normal[1]<.4:continue
                            sample=np.rint(project(point,g,ph)).astype(int)
                            observed=0<=sample[0]<face.width and 0<=sample[1]<face.height and face.getpixel(tuple(sample))[3]>=128 and max(face.getpixel(tuple(sample))[:3])>45
                            if normal@eye>.60 and normal[1]<.60 and observed:continue
                            if point[1]<.3:continue
                            rx=min(.90,max(.55,patch['radius'][0]/u_scale*1.30))
                            ry=min(.85,max(.45,patch['radius'][1]*ph,rx*.90))
                            rd=min(.70,max(.35,rx*.85,patch['inferred_depth_m']))
                            candidates.append({'point':point,'normal':normal,'radii':np.array([rx,rd,ry]),'patch':patch,'continuation':tag})
        for candidate in sorted(candidates,key=lambda row:(-row['radii'][0]*row['radii'][2],*row['point'])):
            if any(np.linalg.norm(candidate['point']-other['point'])<.55*(candidate['radii'][0]+other['radii'][0]) for other in selected):continue
            selected.append(candidate)
    # Actual source-facing boulders use their own measured centres, not a repeated
    # tile. U/V radii preserve the native projected feature; the inferred depth
    # follows the projection's null ray, giving a complete rounded volume.
    source_uv=project(placement_surface,g,ph);u_axis=np.array([1.,0,1.]);u_axis/=np.linalg.norm(u_axis);v_axis=np.cross(u_axis,eye);v_axis/=np.linalg.norm(v_axis)
    for patch in measured:
        hits=[]
        a,b,c=source_uv[:,0],source_uv[:,1],source_uv[:,2];ab=b-a;ac=c-a;q=np.asarray(patch['center'])-a;div=ab[:,0]*ac[:,1]-ab[:,1]*ac[:,0];valid=abs(div)>1e-9;div=np.where(valid,div,1.)
        wb=(q[:,0]*ac[:,1]-q[:,1]*ac[:,0])/div;wc=(ab[:,0]*q[:,1]-ab[:,1]*q[:,0])/div;wa=1-wb-wc;valid&=np.minimum(wa,np.minimum(wb,wc))>=-1e-5
        for index in np.flatnonzero(valid):hits.append(placement_surface[index,0]*wa[index]+placement_surface[index,1]*wb[index]+placement_surface[index,2]*wc[index])
        if not hits:continue
        point=max(hits,key=lambda p:p@eye);rx=patch['radius'][0]/u_scale;ry=patch['radius'][1]/math.sqrt(128+1/ph**2);rd=min(.70,max(.35,rx*.75,patch['inferred_depth_m']))
        selected.append({'point':point,'normal':eye,'radii':np.array([rx,rd,ry]),'patch':patch,'source_front':True,'basis':np.stack([u_axis,eye,v_axis],axis=1)})
    points,normals,colors,ids,model=master();rocks=[];rock_normals=[];rock_colors=[];rock_uv=[];placements=[]
    master_luma=colors@np.array([.2126,.7152,.0722]); master_light=np.clip(master_luma/np.median(master_luma),.65,1.18)
    growth=np.clip((colors[:,1]-colors[:,0]-.015)/.12,0,1)
    for candidate in selected:
        n=candidate['normal'];axis=np.eye(3)[int(np.argmin(abs(n)))];across=axis-n*(axis@n);across/=np.linalg.norm(across);along=np.cross(across,n)
        matrix=candidate.get('basis',np.stack([across,n,along],axis=1))*candidate['radii'][None,:]
        center=candidate['point']-n*candidate['radii'][1]*.24
        volume=points@matrix.T+center
        if volume[:,1].max()>high[1]:
            excess=volume[:,1].max()-high[1]
            volume-=eye*(excess/eye[1]) if candidate.get('source_front',False) else np.array([0,excess,0])
        if volume[:,1].min()<0:
            deficit=-volume[:,1].min()
            volume+=eye*(deficit/eye[1]) if candidate.get('source_front',False) else np.array([0,deficit,0])
        transformed=normals@np.linalg.inv(matrix); transformed/=np.linalg.norm(transformed,axis=1)[:,None]
        patch=candidate['patch'];x,y=patch['center'];stone=image[y,x,:3]
        mask=growth*.35 if patch['kind']=='native_pale_stone' else .65+growth*.35
        palette=(stone[None,:]*(1-mask[:,None])+moss[None,:]*mask[:,None])*master_light[:,None]
        rocks.append(volume[ids]);rock_normals.append(transformed[ids]);rock_colors.append(np.clip(palette[ids]*255,0,255))
        projected=project(volume[ids],g,ph)
        rock_uv.append(projected)
        placements.append({'source_patch':patch['center'],'source_patch_kind':patch['kind'],'source_front':candidate.get('source_front',False),'continuation':candidate.get('continuation','measured_front'),'point':candidate['point'].tolist(),'radii':candidate['radii'].tolist(),'normal':n.tolist()})
    # A normal-direction inset can fold adjacent faces into long fins. Compress
    # only depth along the native projection's null ray, with a monotone bounded
    # mapping and zero displacement at the unchanged source ground/crown.
    before_projection=project(core,g,ph);center=(low+high)*.5
    bottom=np.clip(core[:,:,1]/.6,0,1);bottom=bottom*bottom*(3-2*bottom)
    top=np.clip((high[1]-core[:,:,1])/.6,0,1);top=top*top*(3-2*top)
    amount=.35*np.tanh(np.sum((core-center)*eye,axis=2)/1.2)*bottom*top
    derivative_bound=.35/1.2+.35*(1.5/.6)*abs(eye[1]);assert derivative_bound<1.
    core=core-eye*amount[:,:,None];core_normals=vertex_normals(core)
    core_projection_error=float(abs(project(core,g,ph)-before_projection).max());assert core_projection_error<1e-9
    uv=project(core,g,ph)
    core_colors=np.tile(moss*255,(*core.shape[:2],1))
    triangles=np.concatenate([core,*rocks]);ns=np.concatenate([core_normals,*rock_normals]);palette=np.concatenate([core_colors,*rock_colors]);all_uv=np.concatenate([uv,*rock_uv])
    report={'graphic':serial,'status':'private_one_family_study_not_published','reused_master':model,'closed_reused_boulders':len(selected),'core_triangles':len(core),'boulder_triangles':sum(len(p)for p in rocks),'source_patch_tile':tile,'measured_native_patches':measured,'placements':placements,'source_contour':proof,'core_reconstruction':{'method':'Monotone native-view depth compression, tapered to zero at the original ground and crown; no variable-normal offset or new fold mechanism.','maximum_depth_compression_m':.35,'maximum_derivative_change_bound':float(derivative_bound),'native_projection_error_pixels':core_projection_error,'ground_crown_anchors_changed':False},'inferred':'The compatible existing River Rock master receives one closed Loop rounding pass. Actual front volumes use original measured centres/U-V radii and inferred view-ray depth; hidden pale-stone and moss clusters repeat only measured patch data at fixed world pitch over a recessed closed moss core. Hidden whole-boulder radii range0.35–0.90m, with inferred normal radius0.35–0.70m; no extra village Y compression. Original master moss/stone pattern supplies separate native-palette materials. Proposed material uses original projective RGB only around the recorded native viewing direction and continues independent stone/moss palette at other angles; no geometry clipping or front sprite wrapping. Source anchor, footprint cells, collision, roads, doors and portals remain unchanged. Hidden silhouette continuation is inferred; actual launcher review remains required.'}
    report['moss_gap_continuation']=moss_tile
    return face,g,ph,triangles,ns,palette,all_uv,report


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    face,g,ph,triangles,normals,palette,uv,report=study()
    view=[.5,.3705,1]
    raster(triangles,normals,uv,face,view,g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    # Proposed native-view material: original-angle photo remains on observed
    # fronts; far outside that angle, closed source-palette stone continues it.
    # This is a material proposal, not removal or clipping of rear geometry.
    rear_uv=np.full_like(uv,-1.)
    raster(triangles,normals,rear_uv,face,view,g,ph,palette=palette).save(OUT/'12538-rear-color.png')
    eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye)
    raster(triangles,normals,uv,face,eye,g,ph,palette=palette).save(OUT/'12538-front-color.png')
    registration=raster(triangles,normals,uv,face,eye,g,ph,palette=palette,source=True,unlit=True)
    registration.save(OUT/'12538-source-projection.png')
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
    row=lib.serial_index()[12538];native=lib.image_from_record(row['pack'],row['row']).convert('RGBA')
    assert hashlib.sha256(native.tobytes()).hexdigest()==json.loads((FOLDER/'data.json').read_text())['graphics']['12538']['native_rgba_sha256']
    native.save(OUT/'12538-native-untouched.png')
    sheet=Image.new('RGB',(native.width*4+60,native.height*2+64),'#262f37');draw=ImageDraw.Draw(sheet)
    draw.text((20,12),'Untouched native RGBA (including original occlusion mask)',fill='white')
    draw.text((native.width*2+40,12),'3D source angle: unlit paint-registration study',fill='white')
    native2=native.resize((native.width*2,native.height*2),Image.Resampling.NEAREST);sheet.paste(native2,(20,42),native2)
    sheet.paste(registration,(native.width*2+40,42));sheet.save(OUT/'12538-native-and-source-angle.png')
    original=np.asarray(face)[:,:,:3];registered=np.asarray(registration)[::2,::2];valid=np.asarray(face)[:,:,3]>=128
    equal=(abs(registered.astype(float)-original.astype(float)).max(2)<=1)&valid
    report['registration']={'native_rgba_sha256':hashlib.sha256(native.tobytes()).hexdigest(),'method':'Untouched source sprite beside the exact source-angle geometry raster, with lighting disabled only for RGB/UV registration comparison. Shaded volume studies are separate.','clean_observed_pixels':int(valid.sum()),'matching_observed_pixels':int(equal.sum()),'matching_observed_fraction':float(equal.sum()/valid.sum()),'unregistered_observed_pixels':int((valid&~equal).sum()),'source_rgb_changes':False}
    (OUT/'study.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    np.savez_compressed(OUT/'geometry.npz',triangles=triangles,normals=normals,palette=palette,uv=uv)
    print('EAST_BOULDER_VOLUME_STUDY',report['closed_reused_boulders'],'complete stones;',len(triangles),'triangles; no runtime publication')


if __name__=='__main__':main()

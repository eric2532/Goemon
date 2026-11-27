"""One private native-alpha closed cliff study; no runtime publication."""
import hashlib
import json
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from east_cliff_geometry import project, raster, native_patch_sampler
from prepare_east_cliff_boulder_study import ROOT, source_body, vertex_normals
from prepare_east_cliff_mass_study import master

OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study/Closed Surface02'


def depth_buffers(tris,g,ph,size):
    width,height=size;near=np.full((height,width),-np.inf);far=np.full((height,width),np.inf)
    eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye);uv=project(tris,g,ph);depth=tris@eye
    for k,t in enumerate(uv):
        x0,y0=np.floor(t.min(0)).astype(int);x1,y1=np.ceil(t.max(0)).astype(int)
        x0,y0=max(0,x0),max(0,y0);x1,y1=min(width-1,x1),min(height-1,y1)
        if x0>x1 or y0>y1:continue
        a,b,c=t;div=np.cross(b-a,c-a)
        if abs(div)<1e-8:continue
        yy,xx=np.mgrid[y0:y1+1,x0:x1+1];q=np.stack([xx-a[0],yy-a[1]],axis=-1)
        wb=(q[:,:,0]*(c-a)[1]-q[:,:,1]*(c-a)[0])/div;wc=((b-a)[0]*q[:,:,1]-(b-a)[1]*q[:,:,0])/div;wa=1-wb-wc
        valid=np.minimum(wa,np.minimum(wb,wc))>=-1e-6;value=wa*depth[k,0]+wb*depth[k,1]+wc*depth[k,2]
        near[y0:y1+1,x0:x1+1]=np.maximum(near[y0:y1+1,x0:x1+1],np.where(valid,value,-np.inf))
        far[y0:y1+1,x0:x1+1]=np.minimum(far[y0:y1+1,x0:x1+1],np.where(valid,value,np.inf))
    for buffer in [near,far]:
        rows=[]
        for y in range(height):
            x=np.flatnonzero(np.isfinite(buffer[y]))
            if len(x):buffer[y]=np.interp(np.arange(width),x,buffer[y,x]);rows.append(y)
        for y in range(height):
            if y not in rows:buffer[y]=buffer[min(rows,key=lambda row:abs(row-y))]
    return near,far,eye


def rock_field(name):
    points,colors,ids,proof=master(name);tri=points[ids]
    # Sample the whole preserved asymmetric master along its local depth axis.
    # A flat angular face remains a face; no Gaussian sphere replaces it.
    field=np.zeros((49,49))
    for y in range(49):
        for x in range(49):
            p=np.array([x/24-1,y/24-1]);a,b,c=tri[:,0,:2],tri[:,1,:2],tri[:,2,:2];ab=b-a;ac=c-a;q=p-a
            div=ab[:,0]*ac[:,1]-ab[:,1]*ac[:,0];valid=abs(div)>1e-9;div=np.where(valid,div,1.)
            wb=(q[:,0]*ac[:,1]-q[:,1]*ac[:,0])/div;wc=(ab[:,0]*q[:,1]-ab[:,1]*q[:,0])/div;wa=1-wb-wc;valid&=np.minimum(wa,np.minimum(wb,wc))>=0
            z=tri[:,0,2]*wa+tri[:,1,2]*wb+tri[:,2,2]*wc
            if valid.any():field[y,x]=max(0.,float(z[valid].max())+.55)/1.55
    return field,proof


def sample(field,uv):
    x,y=uv
    if not(-1<=x<=1 and -1<=y<=1):return 0.
    x=(x+1)*24;y=(y+1)*24;ix=min(47,int(x));iy=min(47,int(y));fx=x-ix;fy=y-iy
    return (field[iy,ix]*(1-fx)+field[iy,ix+1]*fx)*(1-fy)+(field[iy+1,ix]*(1-fx)+field[iy+1,ix+1]*fx)*fy


def main():
    OUT.mkdir(exist_ok=True);meta,core,_,face,g=source_body(12538);ph=meta['pixel_height'];near,far,eye=depth_buffers(core,g,ph,face.size)
    masters=[rock_field(name)for name in ['river_rock','split_crag']];patches=meta['measured_native_lobes'];_,tile=native_patch_sampler(face,patches,ph);tx,ty,tw,th=tile['source_window']
    hidden=[p for p in patches if tx<=p['center'][0]<tx+tw and ty<=p['center'][1]<ty+th]
    rgba=np.asarray(face,float)/255.;valid=rgba[:,:,3]>=.5;leaf=valid&(rgba[:,:,1]>rgba[:,:,0]*1.04)&(rgba[:,:,1]>rgba[:,:,2]*1.15);moss=np.median(rgba[leaf,:3],axis=0);smooth=np.asarray(face.filter(ImageFilter.GaussianBlur(3)),float)/255.
    u_axis=np.array([1.,0,1.]);u_axis/=np.linalg.norm(u_axis);v_axis=np.cross(u_axis,eye);v_axis/=np.linalg.norm(v_axis);u_scale=32/3*math.sqrt(2);v_scale=math.sqrt(128+1/ph**2)
    def inverse(uv,depth):return u_axis*((uv[0]+g['origin'][0])/u_scale)+v_axis*((uv[1]+g['origin'][1])/v_scale)+eye*depth
    vertices={};palettes={};locations={};step=4
    def point(uv,back):
        key=(*uv,back)
        if key in vertices:return vertices[key]
        x,y=uv;ix=min(face.width-1,max(0,x));iy=min(face.height-1,max(0,y));value=far[iy,ix] if back else near[iy,ix]
        color=moss.copy();relief=0.;winner=0.
        for index,patch in enumerate(hidden if back else patches):
            center=np.array(patch['center'],float);radius=np.array(patch['radius'],float)
            delta=np.array(uv)-center
            if back:delta=(delta+np.array([tw,th])*.5)%np.array([tw,th])-np.array([tw,th])*.5;radius*=1.55
            amount=sample(masters[index%2][0],delta/radius)
            if amount>winner:
                winner=amount;px,py=patch['center'];pale=smooth[py,px,:3]
                color=moss*(1-min(1,amount*.9))+pale*min(1,amount*.9)
            relief=max(relief,amount*min(1.,max(.55,patch['inferred_depth_m']*1.5)))
        value+=(-1 if back else 1)*relief
        p=inverse(uv,value)
        # The source datum stays closed at zero; view-ray correction preserves
        # original alpha/U-V projection rather than tilting the native face.
        if p[1]<0:p+=eye*(-p[1]/eye[1])
        vertices[key]=p;palettes[key]=color*255.;locations[key]=np.array(uv,float);return p
    cells=set()
    for y in range(0,face.height,step):
        for x in range(0,face.width,step):
            if valid[y:min(y+step,face.height),x:min(x+step,face.width)].any():cells.add((x,y))
    triangles=[];colors=[];uv=[]
    def add(keys,native=False):
        triangles.append([point(k[:2],k[2])for k in keys]);colors.append([palettes[k]for k in keys]);uv.append([locations[k]if native else[-1.,-1.]for k in keys])
    for x,y in sorted(cells):
        coords=[(x,y),(min(face.width,x+step),y),(min(face.width,x+step),min(face.height,y+step)),(x,min(face.height,y+step))]
        front=[(*p,False)for p in coords];back=[(*p,True)for p in coords]
        add([front[0],front[1],front[2]],True);add([front[0],front[2],front[3]],True);add([back[2],back[1],back[0]]);add([back[3],back[2],back[0]])
        for a,b,neighbor in [(0,1,(x,y-step)),(1,2,(x+step,y)),(2,3,(x,y+step)),(3,0,(x-step,y))]:
            if neighbor not in cells:add([front[a],back[a],back[b]]);add([front[a],back[b],front[b]])
    triangles=np.asarray(triangles);palette=np.asarray(colors);uv=np.asarray(uv);normals=vertex_normals(triangles)
    source=raster(triangles,normals,uv,face,eye,g,ph,source=True,palette=palette);source.save(OUT/'12538-source-shaded.png')
    empty=np.full_like(uv,-1.)
    raster(triangles,normals,empty,face,[-1,.30,1],g,ph,palette=palette).save(OUT/'12538-front-independent.png')
    raster(triangles,normals,empty,face,[.5,.37,1],g,ph,palette=palette).save(OUT/'12538-rear-independent.png')
    raster(triangles,normals,empty,face,[.5,.37,1],g,ph,clay=True).save(OUT/'12538-rear-clay.png')
    native=Image.open(ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Boulder Volume Study/12538-native-untouched.png').convert('RGBA');assert hashlib.sha256(native.tobytes()).hexdigest()==meta['native_rgba_sha256'];native.save(OUT/'12538-native-untouched.png')
    pair=Image.new('RGB',(native.width*4,native.height*2),'#26333b');pair.paste(native.resize((native.width*2,native.height*2),Image.Resampling.NEAREST),(0,0),native.resize((native.width*2,native.height*2),Image.Resampling.NEAREST));pair.paste(source,(native.width*2,0));pair.save(OUT/'native-and-source.png')
    np.savez_compressed(OUT/'geometry.npz',triangles=triangles,normals=normals,palette=palette,uv=uv)
    report={'status':'PRIVATE_SINGLE_FAMILY_UNACCEPTED','graphic':12538,'source':meta,'reused_whole_master_depth_fields':[r[1]for r in masters],'native_alpha_cells_4px':len(cells),'triangles':len(triangles),'geometry_bounds':[triangles.reshape(-1,3).min(0).tolist(),triangles.reshape(-1,3).max(0).tolist()],'inferred':'One closed continuous source-alpha-derived front/back surface, with original fitted-envelope depth and source-measured asymmetric whole-rock depth fields. Original-view projection stays native; 4px boundary interpolation, unseen depth/upper occlusion/back palette are inferred. No loose repeated lobe geometry and no native-photo fragments on backs. Source-facing photograph is confined to one observed surface at the native view; actual material must fade it outside the original camera, with fine independently tiled hidden stone/moss finish. This remains an offline single-family study: no runtime/nav/collision/placement publication or claim of visual acceptance.'}
    (OUT/'study.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('EAST_CLOSED_SURFACE_STUDY',len(cells),'source cells',len(triangles),'triangles')


if __name__=='__main__':main()

"""Offline native/closed-wall comparison; actual gameplay-camera review stays separate."""
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
AUDIT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit'
CANDIDATE=AUDIT/'Cave Room Candidate'
OUT=AUDIT/'Cave Room Study'
IDS=[13720,13721,13723,13733,13612,13613,17065,17075,17076]


def render(row,g,eye,source=False,clay=False):
    eye=np.asarray(eye,float);eye/=np.linalg.norm(eye);right=np.cross([0,1,0],eye);right/=np.linalg.norm(right);up=np.cross(eye,right)
    front=np.asarray(Image.open(CANDIDATE/f"{g['serial']}-front.png"),float);tile=np.asarray(Image.open(CANDIDATE/f"{g['serial']}-surfaces.png"),float)
    w,h=(g['size'][0]*3,g['size'][1]*3) if source else (420,640)
    canvas=np.full((h,w,3),[38.,47.,55.]);buffer=np.full((h,w),-np.inf)
    low=np.asarray(row['bounds']['position']);high=low+row['bounds']['size'];center=(low+high)*.5
    light=np.array([-.6,1.,.8]);light/=np.linalg.norm(light)
    for part,surface in enumerate(row['surfaces']):
        vertices=np.asarray(surface['vertices']);normals=np.asarray(surface['normals']);uv=np.asarray(surface['uv']);uv2=np.asarray(surface['uv2']);ids=surface['indices'] or list(range(len(vertices)))
        if source:
            xy=np.stack([(vertices[:,0]+vertices[:,2])*32/3-g['origin'][0],(vertices[:,2]-vertices[:,0])*8-vertices[:,1]/.045-g['origin'][1]],axis=-1)*3
        else:xy=np.stack([(vertices-center)@right,-(vertices-center)@up],axis=-1)*65+np.array([w/2,h/2])
        depth=vertices@eye
        for k in range(0,len(ids),3):
            index=ids[k:k+3];tri=xy[index];x0,y0=np.floor(tri.min(0)).astype(int);x1,y1=np.ceil(tri.max(0)).astype(int)
            x0=max(0,x0);y0=max(0,y0);x1=min(w-1,x1);y1=min(h-1,y1)
            if x0>x1 or y0>y1:continue
            a,b,c=tri;den=np.cross(b-a,c-a)
            if abs(den)<1e-10:continue
            yy,xx=np.mgrid[y0:y1+1,x0:x1+1];qx=xx+.5-a[0];qy=yy+.5-a[1]
            wb=(qx*(c-a)[1]-qy*(c-a)[0])/den;wc=((b-a)[0]*qy-(b-a)[1]*qx)/den;wa=1-wb-wc
            weights=np.stack([wa,wb,wc],axis=-1);z=weights@depth[index];visible=(weights.min(2)>=0)&(z>buffer[y0:y1+1,x0:x1+1])
            if not visible.any():continue
            n=weights@normals[index];n/=np.maximum(1e-10,np.linalg.norm(n,axis=2))[:,:,None]
            shade=.65+.35*np.maximum(0,n@light);sample_uv=weights@uv[index]
            if part==0 and surface.get('colors'):
                rgb=(weights@np.asarray(surface['colors'])[index])*255
                if source:
                    tx=sample_uv[:,:,0]*front.shape[1];ty=sample_uv[:,:,1]*front.shape[0]
                    sample=front[np.clip(ty.astype(int),0,front.shape[0]-1),np.clip(tx.astype(int),0,front.shape[1]-1)]
                    native=(tx>=0)&(tx<front.shape[1])&(ty>=0)&(ty<front.shape[0])&(sample[:,:,3]>=128)
                    rgb=np.where(native[:,:,None],sample[:,:,:3],rgb)
                sample=np.concatenate([rgb,np.full((*rgb.shape[:2],1),255)],axis=2)
            elif part==0:
                tile_origin=weights@uv2[index]
                tx=np.clip((sample_uv[:,:,0]%1*128+tile_origin[:,:,0]).astype(int),0,tile.shape[1]-1)
                ty=np.clip((sample_uv[:,:,1]%1*128+tile_origin[:,:,1]).astype(int),0,tile.shape[0]-1);sample=tile[ty,tx]
            else:
                tx=sample_uv[:,:,0]*front.shape[1];ty=sample_uv[:,:,1]*front.shape[0]
                sample=front[np.clip(ty.astype(int),0,front.shape[0]-1),np.clip(tx.astype(int),0,front.shape[1]-1)]
                visible&=(tx>=0)&(tx<front.shape[1])&(ty>=0)&(ty<front.shape[0])&(sample[:,:,3]>=128)
            rgb=np.full((*wa.shape,3),[153.,164.,144.]) if clay else sample[:,:,:3]
            if not(source and part>0):rgb=rgb*shade[:,:,None]
            canvas[y0:y1+1,x0:x1+1][visible]=rgb[visible];buffer[y0:y1+1,x0:x1+1][visible]=z[visible]
    return Image.fromarray(np.clip(canvas,0,255).astype('uint8'))


def main():
    dump=json.loads((OUT/'meshes.json').read_text());catalog=json.loads((CANDIDATE/'data.json').read_text())['graphics'];costs={}
    if (OUT/'room-meshes.json').exists():dump['graphics'].update(json.loads((OUT/'room-meshes.json').read_text())['graphics'])
    for token,row in dump['graphics'].items():costs[token]={'triangles':row['triangles'],'bounds':row['bounds'],'role':row['role'],'vertices':sum(len(s['vertices'])for s in row['surfaces'])}
    (OUT/'geometry-costs.json').write_text(json.dumps({'graphics':costs,'scope':'Exact private mesh payload; no current runtime enrollment or actual frame-time claim.'},indent=2)+'\n')
    for start in range(0,len(IDS),3):
        page=Image.new('RGB',(4*420,3*680),(31,39,46));draw=ImageDraw.Draw(page)
        for j,serial in enumerate(IDS[start:start+3]):
            token=str(serial);g=catalog[token];row=dump['graphics'][token];y=j*680
            native=Image.open(CANDIDATE/f'{serial}-native.png').convert('RGBA');native=native.resize((native.width*3,native.height*3),Image.Resampling.NEAREST);native.thumbnail((400,620),Image.Resampling.NEAREST)
            page.paste(native,(210-native.width//2,y+50+(620-native.height)//2),native)
            source=render(row,g,[-1,.72,1],source=True);source.thumbnail((410,620),Image.Resampling.LANCZOS);page.paste(source,(420+(420-source.width)//2,y+50+(620-source.height)//2))
            for col,clay in [(2,False),(3,True)]:page.paste(render(row,g,[1,.65,-1],clay=clay),(col*420,y+40))
            draw.text((12,y+8),f'{serial} native | source axis | inferred reverse | reverse clay · {row["triangles"]}tri · {row["bounds"]["size"][1]:.3f}m',fill='white')
        path=OUT/f'native-geometry-{start//3+1:02d}.png';page.save(path);print(path,flush=True)


if __name__=='__main__':main()

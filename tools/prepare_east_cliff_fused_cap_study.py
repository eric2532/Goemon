"""Bounded native-scale ledge continuation on the private12538 hidden upper panel."""
import hashlib
import json
import math
import numpy as np
from asset_pipeline.glb import GLB
from prepare_east_cliff_boulder_study import ROOT, intersections, vertex_normals

BASE=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Connected Mass Study'
PARENT=BASE/'Fused Angular14'
OUT=BASE/'Fused Angular15'


def prepare():
    OUT.mkdir(exist_ok=True)
    source=json.loads((PARENT/'source-geometry.json').read_text());core=np.array(source['parts'][0]['triangles']);normals=vertex_normals(core).mean(1);normals/=np.linalg.norm(normals,axis=1)[:,None]
    ph=source['pixel_height'];eye=np.array([-1.,16*ph,1.]);eye/=np.linalg.norm(eye);low,high=np.array(source['source_contour']['fitted_source_bounds'])
    path=ROOT/'assets/models/cedar_pass/cliff_step.glb';glb=GLB.read(path);p=glb.doc['meshes'][0]['primitives'][0];vertices=np.asarray(glb.accessor(p['attributes']['POSITION']));ids=np.asarray(glb.accessor(p['indices']),int).reshape(-1,3)[:,[0,2,1]];span=np.ptp(vertices,axis=0);vertices-=(vertices.min(0)+vertices.max(0))*.5
    parts=[];locations=[];pitch=1.65
    for x in np.arange(low[0]+1.,high[0]-1.,pitch):
        for z in np.arange(low[2]+1.,high[2]-1.,pitch):
            hits=intersections(core,[x,z],[0,2])
            if not hits:continue
            point,index=max(hits,key=lambda row:row[0][1]);normal=normals[index]
            if normal[1]<.24 or normal@eye>.08 or not(3.<point[1]<high[1]-.8):continue
            if any(np.linalg.norm(point-other)<pitch*.95 for other in locations):continue
            yaw=math.atan2(normal[0],normal[2])+.25;c,s=math.cos(yaw),math.sin(yaw);rotation=np.array([[c,0,s],[0,1,0],[-s,0,c]])
            scale=1.25/span[1];at=point+np.array([0,-.22,0]);placed=vertices@rotation.T*scale+at
            if placed[:,1].max()>high[1]-.05:continue
            if any(placed[:,axis].min()<low[axis]or placed[:,axis].max()>high[axis]for axis in[0,2]):continue
            parts.append({'name':'SourceScaleHiddenLedge_%d'%len(parts),'triangles':placed[ids].tolist(),'inferred':True,'source_surface_point':point.tolist(),'source_normal':normal.tolist(),'uniform_scale':float(scale)});locations.append(point)
    source['parts']=parts;source['parent_master']=str(PARENT/'study.blend');source['parent_master_sha256']=hashlib.sha256((PARENT/'study.blend').read_bytes()).hexdigest();source['inference']+=' Bounded follow-up carries original native-scale raw CliffStep ledges across only the hidden upper panel (upward/back-facing source matrix samples, fixed1.65mpitch, same ground/crown/footbounds). No other source layout/field/asset changes.'
    source['source_master_sha256'][str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest();(OUT/'source-geometry.json').write_text(json.dumps(source,separators=(',',':')))
    (OUT/'observed-native.png').write_bytes((PARENT/'observed-native.png').read_bytes());print('EAST_FUSED_CAP_PARTS',len(parts))


if __name__=='__main__':prepare()

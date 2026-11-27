"""Private source-angle control/whole-part fitting; no clipping or camera discard."""
from collections import deque
import numpy as np
from PIL import ImageFilter
from east_cliff_geometry import project


def pinned_subdivision(triangles,iterations=3):
    lookup={};points=[];faces=[]
    for triangle in triangles:
        face=[]
        for point in triangle:
            key=tuple(point.round(7))
            if key not in lookup:lookup[key]=len(points);points.append(point)
            face.append(lookup[key])
        faces.append(face)
    points=np.array(points);height=float(points[:,1].max());pinned={i for i,p in enumerate(points)if abs(p[1])<1e-7 or abs(p[1]-height)<1e-7};original={i:points[i].copy()for i in pinned}
    for _ in range(iterations):
        neighbours=[set()for p in points];edges={}
        for a,b,c in faces:
            for i,j,k in[(a,b,c),(b,c,a),(c,a,b)]:neighbours[i].add(j);neighbours[j].add(i);edges.setdefault(tuple(sorted((i,j))),[]).append(k)
        updated=[]
        for i,adjacent in enumerate(neighbours):
            n=len(adjacent);beta=3/(8*n)if n>3 else 3/16
            updated.append(points[i]if i in pinned else (1-n*beta)*points[i]+beta*points[list(adjacent)].sum(0))
        edge_ids={}
        for (a,b),opposite in edges.items():
            assert len(opposite)==2,'Closed source-contour matrix required'
            edge_ids[a,b]=len(updated)
            if abs(points[a,1])<1e-7 and abs(points[b,1])<1e-7:
                updated.append((points[a]+points[b])*.5);pinned.add(len(updated)-1)
            else:updated.append((points[a]+points[b])*3/8+points[opposite].sum(0)/8)
        refined=[]
        for a,b,c in faces:
            ab=edge_ids[tuple(sorted((a,b)))];bc=edge_ids[tuple(sorted((b,c)))];ca=edge_ids[tuple(sorted((c,a)))];refined.extend([[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]])
        points=np.array(updated);faces=refined
    assert all(np.array_equal(points[i],value)for i,value in original.items())
    return points[np.array(faces)],{'pinned_original_ground_and_crown_controls':len(original),'original_controls_exact':True,'ground_edges_stay_on_source_plane':True,'AABB_reexpansion':False,'subdivision_passes':iterations}


class NativeSilhouette:
    def __init__(self,image,g,ph,guard=2):
        self.g,self.ph=g,ph
        self.inside=np.asarray(image.getchannel('A').filter(ImageFilter.MinFilter(guard*2+1)))>=128
        h,w=self.inside.shape;self.nearest=np.full((h,w,2),-1,int);pending=deque()
        for y,x in zip(*np.where(self.inside)):self.nearest[y,x]=[x,y];pending.append((x,y))
        while pending:
            x,y=pending.popleft()
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                a,b=x+dx,y+dy
                if 0<=a<w and 0<=b<h and self.nearest[b,a,0]<0:self.nearest[b,a]=self.nearest[y,x];pending.append((a,b))

    def valid(self,points):
        pixels=np.rint(project(points,self.g,self.ph)).astype(int);h,w=self.inside.shape
        valid=(pixels[...,0]>=0)&(pixels[...,0]<w)&(pixels[...,1]>=0)&(pixels[...,1]<h)
        result=np.zeros(valid.shape,bool);result[valid]=self.inside[pixels[...,1][valid],pixels[...,0][valid]];return result

    def move_control(self,point,max_pixels=8.):
        uv=project(point,self.g,self.ph);h,w=self.inside.shape;x,y=np.rint(uv).astype(int);x=np.clip(x,0,w-1);y=np.clip(y,0,h-1)
        target=self.nearest[y,x].astype(float);delta=target-uv
        if np.linalg.norm(delta)>max_pixels:return point.copy(),float(np.linalg.norm(delta)),False
        # Keep physical Y/depth height intact. This moves a source-profile X/Z
        # control point to measured alpha, never flattens an existing rock.
        result=point.copy();result[0]+=(delta[0]/(32/3)-delta[1]/8)*.5;result[2]+=(delta[0]/(32/3)+delta[1]/8)*.5
        return result,float(np.linalg.norm(delta)),True

    def controls(self,triangles):
        result=triangles.copy();lookup={};moved=[];unresolved=[]
        for i,triangle in enumerate(triangles):
            for j,point in enumerate(triangle):
                key=tuple(point.round(7))
                if key not in lookup:
                    if self.valid(point):lookup[key]=point
                    else:
                        corrected,distance,okay=self.move_control(point)
                        lookup[key]=corrected
                        (moved if okay else unresolved).append(distance)
                result[i,j]=lookup[key]
        return result,{'bounded_source_profile_controls_moved':len(moved),'maximum_control_image_shift_pixels':max(moved,default=0.),'unresolved_controls':len(unresolved),'physical_Y_unchanged':bool(np.array_equal(result[:,:,1],triangles[:,:,1]))}

    def generated_rim(self,triangles,pins):
        pinned={tuple(point.round(7))for point in pins};cache={};result=triangles.copy();moved=[];unresolved=[]
        for i,triangle in enumerate(triangles):
            for j,point in enumerate(triangle):
                key=tuple(point.round(7))
                if key not in cache:
                    if key in pinned or self.valid(point):cache[key]=point
                    else:
                        corrected,distance,okay=self.move_control(point,max_pixels=8.)
                        cache[key]=corrected;(moved if okay else unresolved).append(distance)
                result[i,j]=cache[key]
        for point in pins:assert any(np.array_equal(point,value)for key,value in cache.items()if key==tuple(point.round(7)))
        return result,{'generated_rim_vertices_fitted':len(moved),'maximum_rim_image_shift_pixels':max(moved,default=0.),'unresolved_generated_vertices':len(unresolved),'original_ground_crown_controls_unchanged':True,'physical_Y_unchanged':bool(np.array_equal(result[:,:,1],triangles[:,:,1]))}

    def whole_part(self,triangles,low,high,targets=None):
        center=(triangles.reshape(-1,3).min(0)+triangles.reshape(-1,3).max(0))*.5
        eye=np.array([-1.,16*self.ph,1.]);eye/=np.linalg.norm(eye)
        offsets=[np.zeros(2)]
        for radius in[4.,8.,12.,16.,20.,24.]:
            for angle in np.arange(8)*np.pi/4:offsets.append(np.array([np.cos(angle),np.sin(angle)])*radius)
        winner=None;best_fraction=0.;partial=(triangles.copy(),1.,np.zeros(2),0.)
        for scale in[1.,.95,.9,.85,.8,.75,.7,.65,.6,.55,.5,.45,.4,.35,.3]:
            for offset in offsets:
                delta=np.array([(offset[0]/(32/3)-offset[1]/8)*.5,0.,(offset[0]/(32/3)+offset[1]/8)*.5])
                posed=(triangles-center)*scale+center+delta;minimum,maximum=posed.reshape(-1,3).min(0),posed.reshape(-1,3).max(0);lo=-np.inf;hi=np.inf
                for axis in range(3):
                    if abs(eye[axis])<1e-9:
                        if minimum[axis]<low[axis]or maximum[axis]>high[axis]:lo,hi=1.,0.
                    else:
                        a=(low[axis]-minimum[axis])/eye[axis];b=(high[axis]-maximum[axis])/eye[axis]
                        if eye[axis]<0:a,b=b,a
                        lo=max(lo,a);hi=min(hi,b)
                if lo>hi:continue
                depth=min(hi,max(lo,0.));posed+=eye*depth
                samples=np.concatenate([posed.reshape(-1,3),posed.mean(1)]);fraction=float(self.valid(samples).mean())
                if fraction>best_fraction:best_fraction,partial=fraction,(posed,scale,offset,depth)
                if fraction<.999:continue
                if targets is not None:
                    projected=project(posed,self.g,self.ph);a,b,c=projected[:,0],projected[:,1],projected[:,2];ab,ac=b-a,c-a;div=ab[:,0]*ac[:,1]-ab[:,1]*ac[:,0];nonzero=abs(div)>1e-8;div=np.where(nonzero,div,1.)
                    covered=True
                    for target in targets:
                        q=target-a;wb=(q[:,0]*ac[:,1]-q[:,1]*ac[:,0])/div;wc=(ab[:,0]*q[:,1]-ab[:,1]*q[:,0])/div
                        if not(np.minimum(1-wb-wc,np.minimum(wb,wc))[nonzero]>=-1e-6).any():covered=False;break
                    if not covered:continue
                cost=(1-scale)*.65+np.linalg.norm(offset)*.01+abs(depth)*.02
                if winner is None or cost<winner[0]:winner=(cost,posed,scale,offset,depth)
        if winner is None:
            posed,scale,offset,depth=partial
            return posed,{'whole_uniform_fit':scale,'tested_inside_fraction':best_fraction,'rigid_image_plane_shift_pixels':offset.tolist(),'inferred_view_depth_shift_m':float(depth),'individual_feature_assignment_unresolved':True,'measured_feature_rays_retained':False,'topology_and_whole_master_proportions_retained':True,'vertex_projection_flattening':False}
        _,posed,scale,offset,depth=winner
        return posed,{'whole_uniform_fit':scale,'tested_inside_fraction':1.,'rigid_image_plane_shift_pixels':offset.tolist(),'inferred_view_depth_shift_m':float(depth),'measured_feature_rays_retained':targets is not None,'topology_and_whole_master_proportions_retained':True,'vertex_projection_flattening':False}

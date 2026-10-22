"""Adapt recovered Blood Gulch to Goemon's shared physical/navigation grid.

The native source remains untouched. Only native ground is rasterized for
navigation; cliffs/boulders stay separate boundary art. Eight level attack
lanes and the existing four-gate castle clearing are documented adaptations.
"""
import argparse, collections, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/maps/blood_gulch'
WIDTH=161;SPACING=3.;ORIGIN=-240.
ENTRIES=[(-16,-26,2),(-9,-26,2),(-21,-8,1),(-21,-1,1),(21,8,3),(21,15,3),(10,26,0),(18,26,0)]

def smooth(t):
 t=max(0.,min(1.,t));return t*t*(3-2*t)

def segment_distance(x,z,a,b):
 dx=b[0]-a[0];dz=b[1]-a[1];length=dx*dx+dz*dz
 t=max(0.,min(1.,((x-a[0])*dx+(z-a[1])*dz)/length)) if length else 0
 return math.hypot(x-a[0]-dx*t,z-a[1]-dz*t)

def subtract_volume(polygon, planes):
 """Subtract a convex volume, interpolating native positions and UVs.

 Each plane is (nx,ny,nz,d), with volume interior n dot p <= d. A
 triangle can produce several convex fragments outside the cut volume.
 """
 remaining=polygon;result=[]
 for nx,ny,nz,d in planes:
  if not remaining:break
  inside=[];outside=[]
  for a,b in zip(remaining,remaining[1:]+remaining[:1]):
   da=nx*a[0][0]+ny*a[0][1]+nz*a[0][2]-d;db=nx*b[0][0]+ny*b[0][1]+nz*b[0][2]-d
   if da<=1e-8:inside.append(a)
   if da>=-1e-8:outside.append(a)
   if (da< -1e-8 and db>1e-8) or (da>1e-8 and db< -1e-8):
    t=da/(da-db)
    vertex=([a[0][i]+(b[0][i]-a[0][i])*t for i in range(3)],[a[1][i]+(b[1][i]-a[1][i])*t for i in range(2)])
    inside.append(vertex);outside.append(vertex)
  if len(outside)>=3 and any(nx*v[0][0]+ny*v[0][1]+nz*v[0][2]-d>1e-8 for v in outside):result.append(outside)
  remaining=inside if len(inside)>=3 else []
 return result

def clip_polygon(polygon, planes):
 """Intersect a native triangle with a cell, retaining barycentric source UVs."""
 for nx,ny,nz,d in planes:
  if not polygon:break
  result=[]
  for a,b in zip(polygon,polygon[1:]+polygon[:1]):
   da=nx*a[0][0]+ny*a[0][1]+nz*a[0][2]-d;db=nx*b[0][0]+ny*b[0][1]+nz*b[0][2]-d
   if da<=1e-8:result.append(a)
   if (da< -1e-8 and db>1e-8) or (da>1e-8 and db< -1e-8):
    t=da/(da-db);result.append(([a[0][i]+(b[0][i]-a[0][i])*t for i in range(3)],[a[1][i]+(b[1][i]-a[1][i])*t for i in range(2)]))
  polygon=result if len(result)>=3 else []
 return polygon

def lane_volume(a,b,radius=24.,clearance=12.):
 """Convex sixteen-sided capsule, extruded only to walker clearance."""
 points=sorted(set((p[0]+radius*math.cos(i*math.tau/16),p[1]+radius*math.sin(i*math.tau/16)) for p in (a,b) for i in range(16)))
 def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
 lower=[];upper=[]
 for p in points:
  while len(lower)>=2 and cross(lower[-2],lower[-1],p)<=0:lower.pop()
  lower.append(p)
 for p in reversed(points):
  while len(upper)>=2 and cross(upper[-2],upper[-1],p)<=0:upper.pop()
  upper.append(p)
 hull=lower[:-1]+upper[:-1];planes=[(0,1,0,clearance)]
 for a,b in zip(hull,hull[1:]+hull[:1]):
  dx=b[0]-a[0];dz=b[1]-a[1];planes.append((dz,0,-dx,dz*a[0]-dx*a[1]))
 return planes

def build(source,output):
 native=json.loads(source.read_text());bounds=native['bounds_halo_units'];cx=sum(bounds[0])/2;cy=sum(bounds[1])/2;scale=3.048
 grounds=[g for g in native['groups'] if g['role']=='ground'];ground=grounds[0]
 assert all(g['image']==ground['image'] for g in grounds),'Ground groups need material-specific surfaces if native diffuse differs'
 # Center the flat clearing at native floor height, retaining vertical metres.
 def position(v):
  x,y,z=v['p'];return [(x-cx)*scale,z*scale,-(y-cy)*scale]
 heights=[None]*(WIDTH*WIDTH);uvs=[None]*len(heights)
 for ground in grounds:
  gp=[position(v) for v in ground['vertices']]
  for face in ground['faces']:
   a,b,c=[gp[i] for i in face]
   det=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
   if abs(det)<1e-8:continue
   x0=max(0,math.ceil((min(a[0],b[0],c[0])-ORIGIN)/SPACING));x1=min(WIDTH-1,math.floor((max(a[0],b[0],c[0])-ORIGIN)/SPACING))
   z0=max(0,math.ceil((min(a[2],b[2],c[2])-ORIGIN)/SPACING));z1=min(WIDTH-1,math.floor((max(a[2],b[2],c[2])-ORIGIN)/SPACING))
   for iz in range(z0,z1+1):
    z=ORIGIN+iz*SPACING
    for ix in range(x0,x1+1):
     x=ORIGIN+ix*SPACING;u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/det;v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/det
     if min(u,v,1-u-v)<-1e-6:continue
     at=iz*WIDTH+ix;h=u*a[1]+v*b[1]+(1-u-v)*c[1]
     if heights[at] is not None and h<heights[at]:continue
     heights[at]=h;uvs[at]=[sum(w*ground['vertices'][vi]['uv'][axis] for w,vi in zip((u,v,1-u-v),face)) for axis in range(2)]
 covered=[int(h is not None) for h in heights]
 baseline=heights[80*WIDTH+80]
 assert baseline is not None,'Castle center must be inside native ground'
 # Fill base footprints (enclosed holes), but not the canyon exterior.
 exterior=set();queue=collections.deque()
 for iz in range(WIDTH):
  for ix in range(WIDTH):
   at=iz*WIDTH+ix
   if ix in (0,WIDTH-1) or iz in (0,WIDTH-1):exterior.add(at);queue.append(at)
 while queue:
  at=queue.popleft();iz,ix=divmod(at,WIDTH)
  for nx,nz in ((ix-1,iz),(ix+1,iz),(ix,iz-1),(ix,iz+1)):
   ni=nz*WIDTH+nx
   if 0<=nx<WIDTH and 0<=nz<WIDTH and not covered[ni] and ni not in exterior:exterior.add(ni);queue.append(ni)
 filled_base_samples=sum(1 for i,c in enumerate(covered) if not c and i not in exterior)
 for i in range(len(covered)):
  if i not in exterior:covered[i]=1
 # Nearest original ground supplies height/UV beneath removed bases and scenery.
 queue=collections.deque(i for i,h in enumerate(heights) if h is not None)
 while queue:
  at=queue.popleft();iz,ix=divmod(at,WIDTH)
  for nx,nz in ((ix-1,iz),(ix+1,iz),(ix,iz-1),(ix,iz+1)):
   ni=nz*WIDTH+nx
   if 0<=nx<WIDTH and 0<=nz<WIDTH and heights[ni] is None:heights[ni]=heights[at];uvs[ni]=uvs[at][:];queue.append(ni)
 heights=[h-baseline for h in heights]
 routes=[]
 for x,z,rotation in ENTRIES:
  start=(x*6,z*6);end=((0,-48) if rotation==2 else (-48,0) if rotation==1 else (48,0) if rotation==3 else (0,48))
  routes.append([start,end])
 def lane_distance(x,z):return min(segment_distance(x,z,*route) for route in routes)
 def cut_distance(x,z):return min(max(abs(x),abs(z))-66,lane_distance(x,z)-18)
 for iz in range(WIDTH):
  for ix in range(WIDTH):
   at=iz*WIDTH+ix;x=ORIGIN+ix*SPACING;z=ORIGIN+iz*SPACING;distance=cut_distance(x,z)
   factor=smooth(distance/18.)
   heights[at]*=factor
   if distance<=0:covered[at]=1
 # Clip source faces against finite-height clearance volumes. This retains
 # native upper walls and the exact canyon skyline instead of deleting tall
 # faces merely because their projected footprint touches a battle clearing.
 volumes=[[(1,0,0,72),(-1,0,0,72),(0,0,1,72),(0,0,-1,72),(0,1,0,12)]]
 volumes.extend(lane_volume(*route) for route in routes)
 cliffs=[];removed_cliff_faces=0;clipped_cliff_faces=0;unchanged_cliff_faces=0
 for group in native['groups']:
  if group['role'] not in ('cliff','boulder'):continue
  points=[];tex=[]
  for face in group['faces']:
   polygon=[]
   for i in face:
    p=position(group['vertices'][i]);p[1]-=baseline;polygon.append((p,group['vertices'][i]['uv']))
   fragments=[polygon]
   for volume in volumes:
    fragments=[piece for fragment in fragments for piece in subtract_volume(fragment,volume)]
    if not fragments:break
   if not fragments:removed_cliff_faces+=1;continue
   if fragments==[polygon]:unchanged_cliff_faces+=1
   else:clipped_cliff_faces+=1
   for fragment in fragments:
    for i in range(1,len(fragment)-1):
     triangle=[fragment[0],fragment[i],fragment[i+1]]
     # Discard numerical slivers at clipping-plane intersections.
     a,b,c=[q[0] for q in triangle];ab=[b[k]-a[k] for k in range(3)];ac=[c[k]-a[k] for k in range(3)]
     cross=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
     if sum(v*v for v in cross)<1e-12:continue
     for p,uv in triangle:points.append(p);tex.append(uv)
  if points:cliffs.append({'image':group['image'],'detail_image':group.get('detail_image'),'detail_scale':group.get('detail_scale',1),'points':points,'uv':tex,'is_cliff':True})
 # Exact same diagonal as ForestKaiTerrain.height(): h00,h10,h01 / h10,h11,h01.
 points=[];tex=[]
 for iz in range(WIDTH-1):
  for ix in range(WIDTH-1):
   at=iz*WIDTH+ix
   if not all(covered[i] for i in (at,at+1,at+WIDTH,at+WIDTH+1)):continue
   for dx,dz in ((0,0),(1,0),(0,1),(1,0),(1,1),(0,1)):
    at=(iz+dz)*WIDTH+ix+dx;points.append([ORIGIN+(ix+dx)*SPACING,heights[at],ORIGIN+(iz+dz)*SPACING]);tex.append(uvs[at])
 # Original native floor closes the exact contact with canyon walls. These
 # fragments are physical scenery support, not new navigation coverage. Unlike
 # the rejected full-grid underlay, each point lies in an actual source face.
 full_cells={(ix,iz) for iz in range(WIDTH-1) for ix in range(WIDTH-1) if all(covered[i] for i in (iz*WIDTH+ix,iz*WIDTH+ix+1,(iz+1)*WIDTH+ix,(iz+1)*WIDTH+ix+1))}
 inner_edges=[]
 for ix,iz in full_cells:
  x=ORIGIN+ix*SPACING;z=ORIGIN+iz*SPACING
  for neighbor,a,b in [((ix-1,iz),(x,z),(x,z+3)),((ix+1,iz),(x+3,z),(x+3,z+3)),((ix,iz-1),(x,z),(x+3,z)),((ix,iz+1),(x,z+3),(x+3,z+3))]:
   if neighbor not in full_cells:inner_edges.append((a,b))
 edge_owners={};native_faces=[]
 for g in grounds:
  for face in g['faces']:
   polygon=[]
   for i in face:
    q=position(g['vertices'][i]);q[1]-=baseline;polygon.append((q,g['vertices'][i]['uv']))
   native_faces.append(polygon)
   for a,b in zip(polygon,polygon[1:]+polygon[:1]):
    a=(a[0][0],a[0][2]);b=(b[0][0],b[0][2]);key=tuple(sorted((tuple(round(v,5) for v in a),tuple(round(v,5) for v in b))))
    edge_owners.setdefault(key,[]).append((a,b))
 native_edges=[owners[0] for owners in edge_owners.values() if len(owners)==1]
 cap_points=[];cap_uv=[];cap_owners=[];cap_height_cache={}
 def cap_height(p,ix,iz):
  key=tuple(round(v,7) for v in p)
  if key in cap_height_cache:return cap_height_cache[key]
  x,y,z=p;u=(x-ORIGIN)/SPACING-ix;v=(z-ORIGIN)/SPACING-iz;at=iz*WIDTH+ix
  h00,h10,h01,h11=[heights[i] for i in (at,at+1,at+WIDTH,at+WIDTH+1)]
  grid=h00+(h10-h00)*u+(h01-h00)*v if u+v<=1 else h11+(h01-h11)*(1-u)+(h10-h11)*(1-v)
  dn=min(segment_distance(x,z,a,b) for a,b in native_edges);di=min(segment_distance(x,z,a,b) for a,b in inner_edges)
  weight=dn/(dn+di) if dn+di>1e-7 else 1.
  # Native outer contact stays at the original cliff foot. Only the
  # inner grid edge uses adapted heights; applying shoulder flattening at
  # dn=0 would lower this floor away from untouched native rock faces.
  native=y
  result=native*(1-weight)+grid*weight;cap_height_cache[key]=result;return result
 for owner,polygon in enumerate(native_faces):
  x0=max(0,math.floor((min(p[0][0] for p in polygon)-ORIGIN)/3));x1=min(159,math.floor((max(p[0][0] for p in polygon)-ORIGIN)/3))
  z0=max(0,math.floor((min(p[0][2] for p in polygon)-ORIGIN)/3));z1=min(159,math.floor((max(p[0][2] for p in polygon)-ORIGIN)/3))
  for iz in range(z0,z1+1):
   for ix in range(x0,x1+1):
    if (ix,iz) in full_cells:continue
    x=ORIGIN+ix*3;z=ORIGIN+iz*3
    clipped=clip_polygon(polygon,[(1,0,0,x+3),(-1,0,0,-x),(0,0,1,z+3),(0,0,-1,-z)])
    # Split along the same field diagonal so inner-grid seams are exact.
    for diagonal in [(1,0,1,x+z+3),(-1,0,-1,-x-z-3)]:
     piece=clip_polygon(clipped,[diagonal])
     for i in range(1,len(piece)-1):
      tri=[piece[0],piece[i],piece[i+1]]
      a,b,c=[v[0] for v in tri]
      if abs((b[0]-a[0])*(c[2]-a[2])-(b[2]-a[2])*(c[0]-a[0]))<1e-8:continue
      cap_owners.append(owner)
      for p,uv in tri:cap_points.append([p[0],cap_height(p,ix,iz),p[2]]);cap_uv.append(uv)
 data={'width':WIDTH,'spacing':SPACING,'origin':[ORIGIN,ORIGIN],'heights':heights,'covered':covered,'bridges':[0]*len(heights),'groups':[{'image':ground['image'],'detail_image':ground['detail_image'],'detail_scale':100,'grass_image':ground['secondary_image'],'grass_scale':60,'points':points,'uv':tex,'is_cliff':False}],'cliffs':cliffs}
 data['groups'].append(dict(data['groups'][0],points=cap_points,uv=cap_uv))
 output.write_text(json.dumps(data,separators=(',',':')))
 # Compact inspection metadata is versioned; bulky build interchange is temporary.
 report={k:data[k] for k in ['width','spacing','origin','heights','covered','bridges']}
 report['boundary_cap_source_triangles']=cap_owners
 report['approach_routes']=[[[a[0]+(b[0]-a[0])*i/100,a[1]+(b[1]-a[1])*i/100] for i in range(101)] for a,b in routes]
 (DEST/'adaptation.json').write_text(json.dumps(report,separators=(',',':'))+'\n')
 layout=json.loads((ROOT/'assets/maps/forest_four_gates.json').read_text())
 layout['buildings']=[b for b in layout['buildings'] if b.get('kind')!='mine']
 layout.update(title='Blood Gulch Castle',terrain_source='blood_gulch',terrain_scale=1.2,trees=[],ramparts=[],deposits=[],portals=[dict(x=round(x*1.2),z=round(z*1.2),rotation=r) for x,z,r in ENTRIES],roads=[])
 (ROOT/'assets/maps/forest_blood_gulch.json').write_text(json.dumps(layout,indent=1)+'\n')
 provenance={'source':{'map':native['map'],'sha256':native['map_sha256'],'bsp':native['bsp_tag'],'native_materials':native['source_material_count'],'native_triangles':sum(len(g['faces']) for g in native['groups']),'native_ground_materials':len(grounds),'rasterized_native_ground_triangles':sum(len(g['faces']) for g in grounds),'textures':native['images']},'coordinate_transform':{'meters_per_halo_unit':scale,'godot_axes':['halo_x','halo_z','-halo_y'],'center_halo_xy':[cx,cy],'floor_baseline_meters':baseline},'battle_adaptations':{'castle_pad_half_width_m':66,'pad_height_m':0,'attack_lane_half_width_m':18,'shoulder_blend_m':18,'entries_cells':ENTRIES,'routes_m':routes,'removed_scifi_base_triangles':sum(len(g['faces']) for g in native['groups'] if g['role']=='removed_base'),'filled_base_grid_samples':filled_base_samples,'removed_intrusive_cliff_triangles':removed_cliff_faces,'clipped_native_boundary_triangles':clipped_cliff_faces,'unchanged_native_boundary_triangles':unchanged_cliff_faces,'cliff_clearance_height_m':12,'ground_cells_rendered':len(points)//6,'boundary_cap_triangles':len(cap_points)//3,'boundary_cap_height':'Original unchanged native cliff-foot height blended continuously to adapted covered grid edges; no shoulder flattening at outer contact; source UV unchanged; navigation coverage unchanged','retained_native_boundary_triangles':sum(len(g['points'])//3 for g in cliffs),'ground_resampling':'3m grid; original grass UV barycentrically interpolated; identical triangle split for rendering/physics/navigation','brightness':'Native pixels preserved; shader daylight/color treatment is a separate presentation adaptation.'}}
 (DEST/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
 print('BLOOD_GULCH_BATTLE',len(points)//3,'ground triangles',sum(len(g['points'])//3 for g in cliffs),'native boundary triangles','covered',sum(covered),'heights',min(heights),max(heights))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=DEST/'source.json');p.add_argument('--output',type=Path,required=True);args=p.parse_args();build(args.source,args.output)

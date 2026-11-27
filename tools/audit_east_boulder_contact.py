"""Read-only contacts between the private closed core and complete stone volumes."""
import json
from pathlib import Path
import numpy as np
from prepare_east_cliff_boulder_study import OUT


def ray_intervals(triangles,origin,direction):
 a,b,c=triangles[:,0],triangles[:,1],triangles[:,2];e1=b-a;e2=c-a;p=np.cross(direction,e2);det=np.sum(e1*p,axis=1);valid=abs(det)>1e-9;det=np.where(valid,det,1.)
 q=origin-a;u=np.sum(q*p,axis=1)/det;v=np.sum(np.cross(q,e1)*direction,axis=1)/det;t=np.sum(np.cross(q,e1)*e2,axis=1)/det
 valid&=(u>=-1e-6)&(v>=-1e-6)&(u+v<=1.000001)&(t>=0)
 hits=sorted(t[valid]);unique=[]
 for value in hits:
  if not unique or value-unique[-1]>1e-4:unique.append(float(value))
 return [(unique[i],unique[i+1])for i in range(0,len(unique)-1,2)]


def inside_any(points,triangles):
 a,b,c=triangles[:,0],triangles[:,1],triangles[:,2];normals=np.cross(c-a,b-a);normals/=np.maximum(1e-10,np.linalg.norm(normals,axis=1))[:,None]
 distance=np.einsum('pfi,fi->pf',points[:,None,:]-a[None,:,:],normals)
 return bool((distance.max(1)<=.01).any())


def contact_report(report,triangles):
 core_count=report['core_triangles'];per=report['reused_master']['triangles'];core=triangles[:core_count]
 rocks=[triangles[core_count+i*per:core_count+(i+1)*per]for i in range(report['closed_reused_boulders'])]
 bounds=[(v.reshape(-1,3).min(0),v.reshape(-1,3).max(0))for v in rocks];unique=[np.unique(v.reshape(-1,3).round(7),axis=0)for v in rocks]
 direct=set();grounded=set();records=[];edges=[]
 for index,(rock,placement)in enumerate(zip(rocks,report['placements'])):
  point=np.asarray(placement['point']);normal=np.asarray(placement['normal']);origin=point+normal*3;direction=-normal
  ci=ray_intervals(core,origin,direction);ri=ray_intervals(rock,origin,direction)
  overlaps=[min(a[1],b[1])-max(a[0],b[0])for a in ci for b in ri];overlap=max(overlaps,default=-1e9)
  if overlap>.005:direct.add(index)
  if abs(float(rock[:,:,1].min()))<=.005:grounded.add(index)
  records.append({'volume':index,'source_patch':placement['source_patch'],'source_front':placement['source_front'],'direct_core_overlap_m':overlap if overlaps else None,'rests_on_existing_source_base_datum':index in grounded})
 for i,a in enumerate(rocks):
  for j in range(i+1,len(rocks)):
   if (np.minimum(bounds[i][1],bounds[j][1])-np.maximum(bounds[i][0],bounds[j][0])).min()<0:continue
   if inside_any(unique[i],rocks[j])or inside_any(unique[j],a):edges.append([i,j])
 connected=set(direct|grounded);changed=True
 while changed:
  changed=False
  for a,b in edges:
   if (a in connected)!=(b in connected):connected.update([a,b]);changed=True
 isolated=sorted(set(range(len(rocks)))-connected)
 result={'source_study':'Prepared source-derived closed core and stone arrays','closed_volumes':len(rocks),'direct_core_contacts':len(direct),'source_base_contacts':sorted(grounded),'volume_contacts':edges,'supported_by_core_or_source_base_through_pile':len(connected),'unsupported_volumes':isolated,'records':records,'scope':'Read-only geometric contact study. Core ray intervals use actual prepared triangles; volume adjacency tests vertices against rounded convex rock planes with1cm tolerance. A separate stone may rest on the existing source base datum; this does not add ground or collision. This is separate from native pixel registration, visual judgment and actual world-terrain review.'}
 return result


def main():
 report=json.loads((OUT/'study.json').read_text());arrays=np.load(OUT/'geometry.npz');result=contact_report(report,arrays['triangles'])
 (OUT/'volume-contacts.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('EAST_BOULDER_CONTACTS',result['closed_volumes'],'volumes;',result['direct_core_contacts'],'core contacts;',result['supported_by_core_or_source_base_through_pile'],'connected;',len(result['unsupported_volumes']),'unconnected')


if __name__=='__main__':main()

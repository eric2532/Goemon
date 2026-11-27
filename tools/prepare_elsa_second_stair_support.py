"""Stage shared model/native/physical support for the existing BG stair mesh."""
import json
import math
import recover_elsa_island as source
import prepare_elsa_central_assembly as central

OUT=central.OUT/'Second Stair'


def inside(x,z,points):
    result=False
    for a,b in zip(points,points[1:]+points[:1]):
        if (a[2]>z)!=(b[2]>z) and x<(b[0]-a[0])*(z-a[2])/(b[2]-a[2])+a[0]:result=not result
    return result


def surface_height(x,z,points):
    for i in range(1,len(points)-1):
        a,b,c=points[0],points[i],points[i+1]
        denominator=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
        if abs(denominator)<1e-10:continue
        u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/denominator
        v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/denominator
        if min(u,v,1-u-v)>=-1e-9:return u*a[1]+v*b[1]+(1-u-v)*c[1]
    return None


def build():
    data=json.loads((OUT/'data.json').read_text())
    faces=[f for f in data['surfaces'] if f['paint']=='native']
    lower=data['flights'][0]
    lower_start=next(f for f in faces if f['role']=='lower observed riser')['points'][0][0]
    lower_end=min(p[0] for f in faces if f['role']=='lower original tread' for p in f['points'])
    ramp_gradient=lower['top']/(lower_start-lower_end)
    assert ramp_gradient<.55
    spacing=.5
    low=[math.floor(min(p[axis] for f in faces for p in f['points'])/spacing)*spacing-6 for axis in [0,2]]
    high=[math.ceil(max(p[axis] for f in faces for p in f['points'])/spacing)*spacing+6 for axis in [0,2]]
    size=[round((b-a)/spacing)+1 for a,b in zip(low,high)];heights=[]
    for z in range(size[1]):
        for x in range(size[0]):
            at=[low[0]+x*spacing,low[1]+z*spacing]
            found=[]
            for f in faces:
                value=surface_height(*at,f['points'])
                if value is None:continue
                if f['role'].startswith('lower '):value=lower['top']*max(0,min(1,(at[0]-lower_end)/(lower_start-lower_end)))
                found.append(value)
            heights.append(max([0]+found))
    gradient=max(abs(heights[z*size[0]+x]-heights[zz*size[0]+xx])/spacing
        for z in range(size[1]) for x in range(size[0]) for xx,zz in [(x+1,z),(x,z+1)] if xx<size[0] and zz<size[1])
    width,height,_=source.reference_map(59530)
    record=dict(map=59530,candidate_only=True,includes_riser_faces=True,lower_ramp=dict(x=[lower_end,lower_start],height=lower['top'],gradient=ramp_gradient),geometry_sha256=data['geometry_sha256'],
        steps=dict(external_visual=True,support_all_grid=True,map_width=width,map_origin=[-(width//2)*3,-(height//2)*3],
            grid=dict(origin=low,size=size,spacing=spacing,heights=heights)),
        maximum_axis_gradient=gradient,
        limits=['Support follows the existing lower flight as one ordinary collision ramp; visible treads, source floor XZ and source blocking remain unchanged.',
            'Original blocked cells and source boundaries remain authoritative. No normal activation.',
            'Actual movement, native reachability, physical/model height and visual foot contact must be checked.'])
    (OUT/'support-data.json').write_text(json.dumps(record,separators=(',',':'))+'\n')
    print('ELSA_SECOND_STAIR_SUPPORT lower_ramp',size,'samples',len(heights),'max_height',max(heights),'axis_gradient',gradient,'lower_gradient',ramp_gradient,flush=True)


if __name__=='__main__':build()

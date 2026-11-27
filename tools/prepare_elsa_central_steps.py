"""Stage the original central landing, turning flights and source-coloured rails.

The client confirms blocked cells on this raised architecture. This visual fit
does not invent climb routes, change walking cells or replace actor support.
"""
import json
import math
import statistics
from collections import deque
from PIL import Image,ImageDraw,ImageChops
import recover_elsa_island as source
import prepare_elsa_central_assembly as central

OUT=central.OUT/'Steps'
VERTICAL=math.sqrt(2*((32/3)**2-8**2))


def point(u,v,height=0):
    # Preserve the original source projection at an inferred decorative height.
    return [u*3/64-(v+height*VERTICAL)/16,height,u*3/64+(v+height*VERTICAL)/16]


def lerp(a,b,t):return [x+(y-x)*t for x,y in zip(a,b)]
def add(a,b):return [x+y for x,y in zip(a,b)]
def mul(a,s):return [x*s for x in a]
def subtract(a,b):return [x-y for x,y in zip(a,b)]


def rounded(points,indices,radius=8):
    result=[]
    for i,p in enumerate(points):
        if i not in indices:result.append(p);continue
        before,after=points[i-1],points[(i+1)%len(points)]
        a=lerp(p,before,min(.3,radius/math.dist(p,before)))
        b=lerp(p,after,min(.3,radius/math.dist(p,after)))
        for sample in range(7):
            t=sample/6;result.append([(1-t)**2*a[k]+2*t*(1-t)*p[k]+t*t*b[k] for k in [0,1]])
    return result


def detect_balusters(native,cap,depth=27):
    selected=set();assignments={}
    for y in range(native.height):
        for x in range(native.width):
            r,g,b,a=native.getpixel((x,y))
            if not a or not(r>25 and r>g*1.10 and g>b*1.10):continue
            choices=[]
            for i,(p,q) in enumerate(zip(cap,cap[1:])):
                if abs(q[0]-p[0])<.1:continue
                t=(x-p[0])/(q[0]-p[0])
                if not 0<=t<=1:continue
                delta=y-(p[1]+(q[1]-p[1])*t)
                if 2<=delta<=depth:choices.append((abs(delta-10),i,t))
            if choices:selected.add((x,y));assignments[x,y]=min(choices)[1:]
    result=[]
    while selected:
        pending=[selected.pop()];points=[]
        while pending:
            x,y=pending.pop();points.append((x,y))
            for dx in [-1,0,1]:
                for dy in [-1,0,1]:
                    p=x+dx,y+dy
                    if p in selected:selected.remove(p);pending.append(p)
        if len(points)<3:continue
        x=sum(p[0] for p in points)/len(points);y=sum(p[1] for p in points)/len(points)
        nearest=min(points,key=lambda p:(p[0]-x)**2+(p[1]-y)**2)
        segment,t=assignments[nearest]
        result.append(dict(native=[x,y],segment=segment,t=t,pixels=len(points)))
    result.sort(key=lambda m:(m['segment'],m['t']))
    merged=[]
    for m in result:
        if merged and math.dist(merged[-1]['native'],m['native'])<5:continue
        merged.append(m)
    return merged


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    native=Image.open(central.OUT/'414-422-native.png').convert('RGBA')
    bands=json.loads((central.OUT/'stair-source-bands.json').read_text())
    assert source.sha(native.tobytes())==bands['native_rgba_sha256']
    surfaces=[]
    markers=[]
    def source_markers(cap,depth=27):
        result=detect_balusters(native,cap,depth)
        markers.append(result)
        return result
    def face(points,paint='body',uv=None,role='hidden structural closure'):
        surfaces.append(dict(points=points,paint=paint,uv=uv or [[.5,.5]]*len(points),role=role))
    def native_face(pixels,height,paint='native',role='source surface'):
        absolute=[[u+central.ORIGIN[0],v+central.ORIGIN[1]] for u,v in pixels]
        face([point(u,v,height) for u,v in absolute],paint,pixels,role)
    def beam(a,b,width,height,paint,role):
        dx,dz=b[0]-a[0],b[2]-a[2];length=math.hypot(dx,dz)
        if length<.01:
            if abs(a[1]-b[1])<.01:return
            y=min(a[1],b[1])
            beam([a[0]-width*.5,y,a[2]],[a[0]+width*.5,y,a[2]],width,abs(a[1]-b[1])+height,paint,role+' terminal return')
            return
        right=[-dz/length*width*.5,0,dx/length*width*.5]
        if paint=='cap':
            tangent=mul(right,2/width);bevel=min(.08,height*.3,width*.15)
            section=[[-width*.5+bevel,0],[width*.5-bevel,0],[width*.5,bevel],
                [width*.5,height-bevel],[width*.5-bevel,height],[-width*.5+bevel,height],
                [-width*.5,height-bevel],[-width*.5,bevel]]
            rings=[[add(p,add(mul(tangent,x),[0,y,0])) for x,y in section] for p in [a,b]]
            for i in range(8):face([rings[0][i],rings[1][i],rings[1][(i+1)%8],rings[0][(i+1)%8]],paint,role=role)
            for ring in rings:
                center=mul([sum(p[k] for p in ring) for k in range(3)],1/8)
                for i in range(8):face([center,ring[i],ring[(i+1)%8]],paint,role=role+' closed end')
            return
        corners=[add(a,right),subtract(a,right),subtract(b,right),add(b,right)]
        top=[add(p,[0,height,0]) for p in corners]
        face(top,paint,role=role);face(list(reversed(corners)),paint,role=role)
        for i in range(4):face([corners[i],corners[(i+1)%4],top[(i+1)%4],top[i]],paint,role=role)
    def post(at,height,width=.35,paint='stone'):
        beam(add(at,[-width*.5,0,0]),add(at,[width*.5,0,0]),width,height,paint,'source baluster rhythm; inferred section')
    # Keep the original visible floor paint. Only floor portions hidden by the
    # photographed rails/columns receive a simple continuation of its own stone.
    floor_mask=Image.new('L',native.size)
    ImageDraw.Draw(floor_mask).polygon([(58,306),(157,279),(296,180),(338,204),(349,279),
        (283,326),(232,370),(214,393),(176,415),(148,412),(59,365)],fill=255)
    occluders=Image.new('L',native.size)
    for name in ['right-post','left-post','right-half-arch']:
        occluders=ImageChops.lighter(occluders,Image.open(central.OUT/(name+'-mask.png')).convert('L'))
    floor_mask=ImageChops.subtract(floor_mask,occluders)
    paving=[(x,y,native.getpixel((x,y))) for y in range(205,326) for x in range(170,321)
            if floor_mask.getpixel((x,y)) and native.getpixel((x,y))[3] and
            60<native.getpixel((x,y))[0]<180 and max(native.getpixel((x,y))[:3])-min(native.getpixel((x,y))[:3])<14]
    assert len(paving)>1500
    target=statistics.median(q[2][0] for q in paving)
    representative=min(paving,key=lambda p:abs(p[2][0]-target))
    floor=Image.new('RGB',native.size,representative[2][:3])
    floor.paste(native.convert('RGB'),(0,0),floor_mask)
    floor.save(OUT/'floor-paint.png');floor_mask.save(OUT/'confirmed-floor-mask.png')
    native.save(OUT/'original-native.png')
    # The upper corridor contains a thin initial face plus twelve broad bands.
    runs=[]
    for i,value in enumerate(bands['upper']['median_red']):
        if value>=30:continue
        if runs and i-runs[-1][-1]<=4:runs[-1].append(i)
        else:runs.append([i])
    runs=[r for r in runs if len(r)>=3]
    assert len(runs)==13
    upper_t=[0]+[r[0]/bands['upper']['samples'] for r in runs[1:]]+[1.]
    lower_y=[638,657,674,692,709,726,744,761,779,796,814,831,849]
    lower_end=bands['lower']['bright_edges']+[865]
    assert len(lower_y)==len(lower_end)==13
    lower_rises=[(end-start)/VERTICAL for start,end in zip(lower_y,lower_end)]
    turn_height=sum(lower_rises);upper_rise=6/VERTICAL
    top_height=turn_height+len(runs)*upper_rise
    flights=[]
    def flight(name,left,right,edges,rises,top):
        current=top;centres=[]
        ends=[]
        for t,h in [(0,top),(1,top-sum(rises))]:
            ends.append([point(p[0]+central.ORIGIN[0],p[1]+central.ORIGIN[1],h) for p in [lerp(left[0],left[1],t),lerp(right[0],right[1],t)]])
        first=mul(add(*ends[0]),.5);last=mul(add(*ends[1]),.5)
        across=subtract(ends[0][1],ends[0][0]);forward=[-across[2],0,across[0]]
        denom=sum(a*b for a,b in zip(subtract(last,first),forward));assert abs(denom)>.01
        def under(p):
            t=sum(a*b for a,b in zip(subtract(p,first),forward))/denom
            return [p[0],top+(sum(rises)*-t)-1.2,p[2]]
        for i,rise in enumerate(rises):
            a=lerp(left[0],left[1],edges[i]);b=lerp(right[0],right[1],edges[i])
            high=current;current-=rise
            absolute=[[u+central.ORIGIN[0],v+central.ORIGIN[1]] for u,v in [a,b]]
            high_points=[point(u,v,high) for u,v in absolute]
            low_points=[add(p,[0,-rise,0]) for p in high_points]
            bottom_uv=[[a[0],a[1]+rise*VERTICAL],[b[0],b[1]+rise*VERTICAL]]
            face([high_points[0],high_points[1],low_points[1],low_points[0]],'native',
                 [a,b,bottom_uv[1],bottom_uv[0]],name+' original riser band')
            end_a=lerp(left[0],left[1],edges[i+1]);end_b=lerp(right[0],right[1],edges[i+1])
            end_points=[point(u+central.ORIGIN[0],v+central.ORIGIN[1],current) for u,v in [end_a,end_b]]
            top_points=[low_points[0],low_points[1],end_points[1],end_points[0]]
            offset=1.39 if name=='upper' else .65
            extended=[]
            for pair in [(0,1),(3,2)]:
                axis=subtract(top_points[pair[1]],top_points[pair[0]])
                axis=mul(axis,1/math.hypot(axis[0],axis[2]))
                extended.extend([subtract(top_points[pair[0]],mul(axis,offset)),add(top_points[pair[1]],mul(axis,offset))])
            outer=[extended[0],extended[1],extended[3],extended[2]]
            outer[0][1]=outer[1][1]=high
            face([outer[0],high_points[0],low_points[0]],'stone',role=name+' pale nosing return')
            face([high_points[1],outer[1],low_points[1]],'stone',role=name+' pale nosing return')
            # The final lower face is vertical, not an extra zero-width tread.
            if math.dist(low_points[0],end_points[0])>.01:
                face(top_points,'native',[bottom_uv[0],bottom_uv[1],end_b,end_a],name+' native tread')
                face([outer[0],top_points[0],top_points[3],outer[3]],'stone',role=name+' source pale stringer')
                face([top_points[1],outer[1],outer[2],top_points[2]],'stone',role=name+' source pale stringer')
                bottom=[under(p) for p in outer]
                face(list(reversed(bottom)),role=name+' continuous closed underside')
                for j,k in [(3,0),(1,2)]:face([bottom[j],bottom[k],outer[k],outer[j]],'stone',role=name+' side cheek')
            centres.append(dict(start=a,end=b,height=high))
        for end in ends:
            bottom=[under(p) for p in end]
            face([bottom[0],bottom[1],end[1],end[0]],role=name+' closed end')
        flights.append(dict(name=name,left=left,right=right,edges=edges,rises=rises,top=top,bottom=current,centres=centres))
        return current
    lower_t=[(y-638)/(865-638) for y in lower_y]+[1.]
    flight('lower',[[322,638],[322,865]],[[445,638],[445,865]],lower_t,lower_rises,turn_height)
    flight('upper',[[222,435],[345,615]],[[278,399],[410,571]],upper_t,[upper_rise]*13,top_height)
    tread_mask=Image.new('L',native.size);draw=ImageDraw.Draw(tread_mask)
    for fl in flights:draw.polygon([tuple(p) for p in [fl['left'][0],fl['right'][0],fl['right'][1],fl['left'][1]]],fill=255)
    tread_mask=ImageChops.subtract(tread_mask,occluders)
    seed=native.copy()
    for y in range(native.height):
        for x in range(native.width):
            r,g,b,a=seed.getpixel((x,y))
            if not tread_mask.getpixel((x,y)) or max(r,g,b)-min(r,g,b)>18 or b-r>=3 or max(r,g,b)<=3:
                seed.putpixel((x,y),(0,0,0,0));tread_mask.putpixel((x,y),0)
    from prepare_elsa_props import nearest_material_paint
    nearest_material_paint(seed).save(OUT/'native-paint.png')
    tread_mask.save(OUT/'confirmed-tread-mask.png')
    # A closed landing joins the two actual photographed flights. Hidden edge
    # continuation stays inside their existing architectural footprint.
    rail_height=2.08;rail_offset=1.39
    rail_paths=[[[21,284],[155,247],[296,143],[350,169],[370,289],[300,334],[294,368]],
                [[21,386],[143,431],[168,431],[207,415],[206,424]]]
    rail_controls=[]
    for path in rail_paths:
        for i,p in enumerate(path):
            choices=[]
            for y in range(max(0,p[1]-8),min(native.height,p[1]+9)):
                for x in range(max(0,p[0]-8),min(native.width,p[0]+9)):
                    r,g,b,a=native.getpixel((x,y))
                    if a and b-r>=3 and b-g>=3 and max(r,g,b)>24:choices.append(((x-p[0])**2+(y-p[1])**2,x,y))
            before=list(p)
            if choices:
                _,x,y=min(choices);path[i]=[x,y]
            rail_controls.append(dict(requested=before,native=path[i],inferred=not bool(choices)))
    floor_boundary=[[u,v+rail_height*VERTICAL] for u,v in rail_paths[0]]
    floor_boundary += [[278,399],[222,435]]
    floor_boundary += [[u,v+rail_height*VERTICAL] for u,v in reversed(rail_paths[1])]
    slabs=[dict(name='upper landing',height=top_height,polygon=floor_boundary),
        dict(name='turning landing',height=turn_height,polygon=[
            [345,615],[410,571],[445,608],[445,638],[322,638],[322,615]])]
    for slab in slabs:
        if slab['name']=='upper landing':
            indices=[i for i,p in enumerate(slab['polygon']) if i>8 and p[0] in [143,168]]
            slab['polygon']=rounded(slab['polygon'],indices)
        native_face(slab['polygon'],slab['height'],'floor',slab['name']+' native/inferred paving')
        absolute=[[u+central.ORIGIN[0],v+central.ORIGIN[1]] for u,v in slab['polygon']]
        top=[point(u,v,slab['height']) for u,v in absolute];bottom=[add(p,[0,-1.1,0]) for p in top]
        face(list(reversed(bottom)),role=slab['name']+' closed underside')
        for i in range(len(top)):face([bottom[i],bottom[(i+1)%len(top)],top[(i+1)%len(top)],top[i]],'stone',role=slab['name']+' fascia')
    # Estimate paired rail proportions from the source blue bands. The values
    # are an inferred fit, not an original3D measurement.
    for fl in flights:
        flight_rail_height=rail_height if fl['name']=='upper' else 1.
        left,right=fl['left'],fl['right'];h=fl['top'];paths=[[],[]]
        for i,t in enumerate(fl['edges']):
            l,r=lerp(left[0],left[1],t),lerp(right[0],right[1],t)
            lp=point(l[0]+central.ORIGIN[0],l[1]+central.ORIGIN[1],h)
            rp=point(r[0]+central.ORIGIN[0],r[1]+central.ORIGIN[1],h)
            across=subtract(rp,lp);length=math.hypot(across[0],across[2]);across=mul(across,1/length)
            offset=rail_offset if fl['name']=='upper' else .65
            paths[0].append(subtract(lp,mul(across,offset)));paths[1].append(add(rp,mul(across,offset)))
            if i<len(fl['rises']):h-=fl['rises'][i]
        for path in paths:
            for a,b in zip(path,path[1:]):
                beam(add(a,[0,-.2,0]),add(b,[0,-.2,0]),.75,.30,'stone',fl['name']+' source pale base course')
                beam(add(a,[0,flight_rail_height,0]),add(b,[0,flight_rail_height,0]),.65,.24,'cap',fl['name']+' bevelled blue coping')
            if fl['name']=='upper':
                cap=[]
                for p in path:
                    p=add(p,[0,rail_height,0]);cap.append([(p[0]+p[2])*32/3-central.ORIGIN[0],(p[2]-p[0])*8-p[1]*VERTICAL-central.ORIGIN[1]])
                for marker in source_markers(cap,100):
                    i,t=marker['segment'],marker['t'];at=lerp(path[i],path[i+1],t)
                    post(at,rail_height,.36)
                    post(add(at,[0,rail_height-.18,0]),.14,.18,'gold')
            else:
                for a,b in zip(path,path[1:]):beam(a,b,.32,flight_rail_height,'stone','lower source solid parapet; hidden right continuation inferred')
    # Recovered landing rail path; its concealed corners repeat the same native material.
    for path in rail_paths:
        if len(path)==5:path=rounded(path,[1,2])
        base=[point(u+central.ORIGIN[0],v+central.ORIGIN[1]+rail_height*VERTICAL,top_height) for u,v in path]
        for a,b in zip(base,base[1:]):
            beam(a,b,.75,.3,'stone','landing source base course')
            beam(add(a,[0,rail_height,0]),add(b,[0,rail_height,0]),.65,.24,'cap','landing blue coping')
        for marker in source_markers(path):
            i,t=marker['segment'],marker['t'];at=lerp(base[i],base[i+1],t)
            post(at,rail_height,.36);post(add(at,[0,rail_height-.18,0]),.14,.18,'gold')
    # Each constant surface colour is an actual pixel from the matching native material.
    selections={
        'cap':lambda p:p[2]-p[0]>=6 and p[2]-p[1]>=6 and 40<p[0]<110,
        'stone':lambda p:max(p[:3])-min(p[:3])<12 and 135<p[0]<185,
        'body':lambda p:max(p[:3])-min(p[:3])<12 and 65<p[0]<110,
        'gold':lambda p:p[0]>p[1]*1.15 and p[1]>p[2]*1.15 and 60<p[0]<150}
    colours={}
    for name,predicate in selections.items():
        pixels=[p for p in native.getdata() if p[3] and predicate(p)]
        assert pixels,name
        target=statistics.median(p[0] for p in pixels);colour=min(pixels,key=lambda p:abs(p[0]-target))
        Image.new('RGB',(1,1),colour[:3]).save(OUT/(name+'.png'));colours[name]=list(colour)
    # Original client/server agreement is direct evidence, not a new route assumption.
    width,height,planes=source.reference_map(59530);client=source.client_map(59530)[1];proofs=[]
    for x,y in [(107,84),(108,85),(109,86),(101,99),(105,94),(103,97)]:
        index=y*width+x;flag=client[4][index]
        assert flag&0xc000 and bool(flag&256)==bool(planes[2][index])
        proofs.append(dict(cell=[x,y],client_flag=flag,reference_flag=planes[2][index]))
    record=dict(map=59530,candidate_only=True,native_origin=list(central.ORIGIN),size=list(native.size),
        geometry_sha256=source.sha(json.dumps(surfaces,separators=(',',':')).encode()),
        paint_sha256=source.sha(b''.join((OUT/name).read_bytes() for name in ['native-paint.png','floor-paint.png','body.png','cap.png','stone.png','gold.png'])),
        native_rgba_sha256=source.sha(native.tobytes()),surfaces=surfaces,flights=flights,slabs=slabs,
        top_height=top_height,turn_height=turn_height,colours=colours,walkability_proofs=proofs,source_balusters=markers,rail_controls=rail_controls,
        inference=['The source projection is retained while decorative surface height/depth is inferred.',
            'Dark/bright source bands guide the visible faces; these are not verified original3D riser heights.',
            'No navigation, collision, original blocked/open cell or crossing is changed.',
            'Hidden paving and rear/underside material repeat original local stone. Rail sections and concealed corners are inferred.'])
    (OUT/'data.json').write_text(json.dumps(record,separators=(',',':'))+'\n')
    guide=native.copy();draw=ImageDraw.Draw(guide)
    for slab in slabs:draw.line([tuple(p) for p in slab['polygon']+[slab['polygon'][0]]],fill=(255,190,50,255))
    for fl in flights:
        for t in fl['edges']:draw.line([tuple(lerp(fl['left'][0],fl['left'][1],t)),tuple(lerp(fl['right'][0],fl['right'][1],t))],fill=(80,225,200,255))
    guide.save(OUT/'source-footprints-review.png')
    print('ELSA_CENTRAL_STEPS',len(surfaces),'surface polygons;',len(flights),'flights; levels',top_height,turn_height,'visual_only=true')


if __name__=='__main__':build()

"""Private source-painted BG staircase beside the central59530 assembly."""
import json
import math
import statistics
from PIL import Image,ImageDraw,ImageChops
import recover_elsa_island as source
import prepare_elsa_central_assembly as central
import prepare_elsa_central_portal as portal
from prepare_elsa_central_steps import VERTICAL,lerp,add,subtract,mul,detect_balusters
from prepare_elsa_hall_entry_floor import pack
from prepare_elsa_gate import native_layers
from prepare_elsa_props import nearest_material_paint

OUT=central.OUT/'Second Stair'
RECT=(6150,80,6460,464)
INFERRED_RISE_SCALE=.8


def point(u,v,height):
    # Walkable floors retain the archived map XZ, as the entry stairs do.
    return [u*3/64-v/16,height,u*3/64+v/16]


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    _,native=native_layers([],RECT,59530)
    probe=json.loads((central.OUT/'second-stair-lower-band-probe.json').read_text())
    rail_source=json.loads((central.OUT/'second-stair-source.json').read_text())
    assert source.sha(native.crop((0,0,310,360)).tobytes())==rail_source['native_rgba_sha256']
    surfaces=[];floor_mask=Image.new('L',native.size);floor_draw=ImageDraw.Draw(floor_mask)
    def face(points,paint='body',uv=None,role='inferred solid stair plinth'):
        coords=uv or [[.5,.5]]*len(points);kept=[];samples=[]
        for p,q in zip(points,coords):
            if kept and math.dist(p,kept[-1])<1e-9:continue
            kept.append(p);samples.append(q)
        if len(kept)>2 and math.dist(kept[0],kept[-1])<1e-9:kept.pop();samples.pop()
        if len(kept)>=3:surfaces.append(dict(points=kept,paint=paint,uv=samples,role=role))
    def painted(points,pixels,role):
        face(points,'native',[[u-RECT[0],v-RECT[1]] for u,v in pixels],role)
        floor_draw.polygon([(u-RECT[0],v-RECT[1]) for u,v in pixels],fill=255)
    # Eight lower dark bands; the median corridor is evidence, heights inferred.
    a,b=probe['native_start'],probe['native_end'];n=probe['samples'];starts=[];ends=[]
    for first,last in probe['dark_runs']:
        starts.append(lerp(a,b,first/n));ends.append(lerp(a,b,(last+1)/n))
    assert len(starts)==8
    source_riser_pixels=[q[1]-.75*q[0]-(p[1]-.75*p[0]) for p,q in zip(starts,ends)]
    rises=[width/VERTICAL*INFERRED_RISE_SCALE for width in source_riser_pixels]
    lower_top=sum(rises);upper_rises=[width/VERTICAL*INFERRED_RISE_SCALE for width in [8,9,8]];upper_top=lower_top+sum(upper_rises)
    # The sampled corridor is near the right tread edge, not its centre.
    # Shift along the observed .75 cross-band slope, preserving every riser.
    lower_centres=[[u-10,v-7.5] for u,v in starts+[[6256,396]]]
    lower_left=[[u-32,v-24] for u,v in lower_centres]
    lower_right=[[u+32,v+24] for u,v in lower_centres]
    upper_left=[[6332,v] for v in [130,147,165,182]]
    upper_right=[[6430,v] for v in [130,147,165,182]]
    flights=[]
    def flight(name,left,right,rises,source_widths,top):
        current=top;boundary=[]
        for i,rise in enumerate(rises):
            high=current;current-=rise
            l,r=left[i],right[i];el,er=left[i+1],right[i+1]
            high_points=[point(*p,high) for p in [l,r]]
            below=[[u,v+source_widths[i]] for u,v in [l,r]]
            low_points=[point(*p,current) for p in below]
            painted([high_points[0],high_points[1],low_points[1],low_points[0]],[l,r,below[1],below[0]],name+' observed riser')
            end=[point(*p,current) for p in [el,er]]
            painted([low_points[0],low_points[1],end[1],end[0]],[below[0],below[1],er,el],name+' original tread')
            # This BG source shows a solid plinth, not a hanging staircase.
            for side in [0,1]:
                p,q=high_points[side],end[side]
                face([[p[0],0,p[2]],[q[0],0,q[2]],q,p],role=name+' solid side cheek')
            boundary.append([high_points[0],high_points[1]])
        first=[point(*p,top) for p in [left[0],right[0]]]
        face([[first[0][0],0,first[0][2]],[first[1][0],0,first[1][2]],first[1],first[0]],role=name+' closed head')
        last=[point(*p,current) for p in [left[-1],right[-1]]]
        footprint=[first[0],first[1],last[1],last[0]]
        face([[p[0],0,p[2]] for p in reversed(footprint)],role=name+' closed ground underside')
        flights.append(dict(name=name,left=left,right=right,rises=rises,source_riser_pixels=source_widths,top=top,bottom=current))
    flight('lower',lower_left,lower_right,rises,source_riser_pixels,lower_top)
    flight('upper',upper_left,upper_right,upper_rises,[8,9,8],upper_top)
    landing=[[6332,182],[6430,182],[6420,205],[6400,220],lower_right[0],lower_left[0]]
    pts=[point(*p,lower_top) for p in landing];painted(pts,landing,'original turning landing')
    bottom=[[p[0],0,p[2]] for p in pts];face(list(reversed(bottom)),role='landing closed ground underside')
    for i in range(len(pts)):face([bottom[i],bottom[(i+1)%len(pts)],pts[(i+1)%len(pts)],pts[i]],role='landing closed plinth')
    # Retain only native floor/riser paint; hidden parts continue their own gray.
    seed=native.copy()
    for y in range(native.height):
        for x in range(native.width):
            r,g,b,a=seed.getpixel((x,y))
            if not floor_mask.getpixel((x,y)) or not a or max(r,g,b)<=3 or max(r,g,b)-min(r,g,b)>18 or b-r>=3:
                seed.putpixel((x,y),(0,0,0,0));floor_mask.putpixel((x,y),0)
    nearest_material_paint(seed).save(OUT/'native-paint.png');floor_mask.save(OUT/'confirmed-floor-mask.png')
    native.save(OUT/'original-background.png')
    rail_height=18/VERTICAL;paths=[];markers=[]
    top_d=starts[0][1]-.75*starts[0][0];bottom_d=396-.75*6256
    def floor_height(u,v):
        if v<182 and u>6320:return lower_top+sum(upper_rises)*max(0,min(1,(182-v)/(182-130)))
        d=v-.75*u
        return lower_top*max(0,min(1,(bottom_d-d)/(bottom_d-top_d)))
    def ribbon(path,width,height,paint,role):
        rings=[];bevel=min(.08,width*.15,height*.3)
        section=[[-width/2+bevel,0],[width/2-bevel,0],[width/2,bevel],[width/2,height-bevel],
                 [width/2-bevel,height],[-width/2+bevel,height],[-width/2,height-bevel],[-width/2,bevel]]
        for i,p in enumerate(path):
            before=path[max(0,i-1)];after=path[min(len(path)-1,i+1)];dx,dz=after[0]-before[0],after[2]-before[2]
            length=math.hypot(dx,dz);assert length>.0001
            across=[-dz/length,0,dx/length]
            rings.append([add(p,add(mul(across,x),[0,y,0])) for x,y in section])
        for a,b in zip(rings,rings[1:]):
            for i in range(8):face([a[i],b[i],b[(i+1)%8],a[(i+1)%8]],paint,role=role)
        for ring in [rings[0],list(reversed(rings[-1]))]:
            center=[sum(p[k] for p in ring)/8 for k in range(3)]
            for i in range(8):face([center,ring[i],ring[(i+1)%8]],paint,role=role+' closed end')
    post_profile=[(0,.64),(.10,.64),(.19,.42),(.42,.24),(.63,.24),(.82,.46),(.94,.62),(1.,.62)]
    def post(at,side):
        rings=[];paint='stone_shadow' if side else 'stone'
        for fraction,width in post_profile:
            rings.append([add(at,[math.cos(i*math.pi/4)*width*.5,fraction*rail_height,math.sin(i*math.pi/4)*width*.5]) for i in range(8)])
        face(list(reversed(rings[0])),paint,role='source baluster closed foot');face(rings[-1],paint,role='source baluster capital')
        for section,(low,high) in enumerate(zip(rings,rings[1:])):
            material=('charcoal' if side else 'gold') if section==0 else paint
            for i in range(8):face([low[i],low[(i+1)%8],high[(i+1)%8],high[i]],material,role='source corbel rhythm; inferred flared section')
    raw_markers=[]
    for side,component in enumerate(rail_source['blue_components']):
        cap=[[(a+c)/2,b] for a,b,c in component['source_rows']]
        # Keep native curve sampling, with continuous shared rings at its joins.
        path=[point(u,v+18,floor_height(u,v+18)+rail_height) for u,v in cap];paths.append(cap)
        ribbon(path,.7,.25,'cap','source blue coping with inferred bevel/depth')
        base=[add(p,[0,-rail_height,0]) for p in path]
        ribbon(base,.72,.25,'stone','source pale rail base course')
        local=[[u-RECT[0],v-RECT[1]] for u,v in cap]
        detected=detect_balusters(native,local,80);raw_markers.append(detected)
        # Gold at an end-cap stripe is not a baluster. The shadowed left
        # corbels are monochrome; keep their separately confirmed white pixels.
        used=[detected[i] for i in [0,1,2,3,5]] if side==0 else []
        white=[(6322,387)] if side==0 else [(6312,190),(6291,227),(6270,264),(6249,300),(6228,337)]
        for u,v in white:
            samples=[(native.getpixel((x-RECT[0],y-RECT[1]))[0],x,y) for y in range(v-2,v+3) for x in range(u-2,u+3)]
            _,u,v=max(samples)
            choices=[]
            for i,(a,b) in enumerate(zip(cap,cap[1:])):
                if abs(b[0]-a[0])<.1:continue
                t=(u-a[0])/(b[0]-a[0])
                if 0<=t<=1:choices.append((abs(v-(a[1]+(b[1]-a[1])*t)-20),i,t))
            assert choices,(u,v)
            _,i,t=min(choices);used.append(dict(native=[u-RECT[0],v-RECT[1]],segment=i,t=t,pixels=1,role='confirmed monochrome corbel witness'))
        used.sort(key=lambda row:(row['segment'],row['t']));markers.append(used)
        for marker in used:
            i,t=marker['segment'],marker['t'];post(lerp(base[i],base[i+1],t),side)
        # Original square charcoal end posts and their thin gold bands.
        # Join the post to the actual rail; the photographed lower/front
        # corner is not a second, independently inferred rail height.
        at=path[-1];height=at[1]
        square=[add(at,[x,0,z]) for x,z in [(-.7,-.7),(.7,-.7),(.7,.7),(-.7,.7)]]
        for low,high,paint in [(0,height-.35,'charcoal'),(height-.35,height-.19,'gold'),(height-.19,height,'charcoal'),(height,height+.18,'cap')]:
            below=[[p[0],low,p[2]] for p in square];above=[[p[0],high,p[2]] for p in square]
            face(list(reversed(below)),paint,role='end post closed base');face(above,paint,role='end post closed cap')
            for i in range(4):face([below[i],below[(i+1)%4],above[(i+1)%4],above[i]],paint,role='source charcoal end post and gold trim')
    pixels=list(native.getdata());colours={}
    for name,predicate in {
        'cap':lambda p:p[2]-p[0]>=6 and p[2]-p[1]>=6 and 40<p[0]<160,
        'stone':lambda p:max(p[:3])-min(p[:3])<10 and 130<p[0]<180,
        'body':lambda p:max(p[:3])-min(p[:3])<10 and 40<p[0]<75,
        'charcoal':lambda p:max(p[:3])-min(p[:3])<10 and 10<p[0]<30,
        'gold':lambda p:p[0]>p[1]*1.2 and p[1]>p[2]*1.15 and 65<p[0]<180}.items():
        found=[p for p in pixels if p[3] and predicate(p)];assert found
        target=statistics.median(p[0] for p in found);value=min(found,key=lambda p:abs(p[0]-target));colours[name]=list(value)
        Image.new('RGBA',(1,1),value).save(OUT/(name+'.png'))
    shadow=native.getpixel((6249-RECT[0],298-RECT[1]));colours['stone_shadow']=list(shadow)
    Image.new('RGBA',(1,1),shadow).save(OUT/'stone_shadow.png')
    # A confirmed plain gray side-wall patch supplies the concealed faces,
    # without carrying a facade fragment onto the back or stretching one pixel.
    witness_rect=[6400,304,6432,336]
    grain=native.crop(tuple(v-RECT[i%2] for i,v in enumerate(witness_rect)))
    assert all(a==255 and max(r,g,b)-min(r,g,b)<12 for r,g,b,a in grain.getdata())
    grain.save(OUT/'body-native-witness.png');tile=Image.new('RGBA',(512,512))
    for y in range(16):
        for x in range(16):
            patch=grain.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if x%2 else grain
            if y%2:patch=patch.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            tile.paste(patch,(x*32,y*32))
    tile.save(OUT/'body.png')
    # Keep the source tread centres flat, easing only the worn noses around
    # the existing collision ramp. This avoids a visible air gap at its crests.
    lower_head=next(f for f in surfaces if f['role']=='lower observed riser')['points'][0][0]
    lower_foot=min(p[0] for f in surfaces if f['role']=='lower original tread' for p in f['points'])
    relief=.15
    def ramp(x):return lower_top*max(0,min(1,(x-lower_foot)/(lower_head-lower_foot)))
    def worn(p):
        h=ramp(p[0]);return [p[0],h+max(-relief,min(relief,p[1]-h)),p[2]]
    fitted=[]
    for f in surfaces:
        if f['role']=='lower original tread':
            points=f['points'];uv=f['uv'];start=points[0][1]-ramp(points[0][0]);end=points[3][1]-ramp(points[3][0]);cuts=[0.,1.]
            if abs(end-start)>1e-9:
                for edge in [-relief,relief]:
                    t=(edge-start)/(end-start)
                    if 1e-7<t<1-1e-7:cuts.append(t)
            cuts.sort();strips=[]
            for a,b in zip(cuts,cuts[1:]):
                quad=[lerp(points[0],points[3],a),lerp(points[1],points[2],a),lerp(points[1],points[2],b),lerp(points[0],points[3],b)]
                coords=[lerp(uv[0],uv[3],a),lerp(uv[1],uv[2],a),lerp(uv[1],uv[2],b),lerp(uv[0],uv[3],b)]
                middle=points[0][1]-ramp((quad[0][0]+quad[3][0])*.5)
                row=dict(points=[worn(p) for p in quad],uv=coords,paint='native',role='lower original tread' if abs(middle)<=relief+1e-8 else 'lower inferred nosing bevel')
                strips.append(row)
            assert sum(s['role']=='lower original tread' for s in strips)==1
            fitted.extend(strips)
        elif f['role']=='lower observed riser':
            f['points']=[worn(p) for p in f['points']];fitted.append(f)
        elif f['paint']=='body' and f['role'].startswith('lower '):
            f['points']=[worn(p) if p[1]>1e-8 else p for p in f['points']];fitted.append(f)
        else:fitted.append(f)
    surfaces=fitted
    origin=[min(p[axis] for f in surfaces for p in f['points']) for axis in [0,2]]
    for f in surfaces:
        if f['paint']!='body':continue
        a,b,c=f['points'][:3];ab=subtract(b,a);ac=subtract(c,a)
        normal=[ac[1]*ab[2]-ac[2]*ab[1],ac[2]*ab[0]-ac[0]*ab[2],ac[0]*ab[1]-ac[1]*ab[0]]
        if abs(normal[1])>=max(abs(normal[0]),abs(normal[2])):
            f['uv']=[[(p[0]-origin[0])*VERTICAL,(p[2]-origin[1])*VERTICAL] for p in f['points']]
        else:
            axis=2 if abs(normal[0])>abs(normal[2]) else 0;offset=origin[1] if axis==2 else origin[0]
            f['uv']=[[(p[axis]-offset)*VERTICAL,256-p[1]*VERTICAL] for p in f['points']]
    mask=Image.new('L',native.size)
    ImageDraw.Draw(mask).polygon([(6380-6150,124-80),(6432-6150,124-80),(6452-6150,140-80),(6452-6150,355-80),
        (6300-6150,439-80),(6290-6150,452-80),(6273-6150,443-80),(6273-6150,412-80),(6222-6150,376-80),
        (6202-6150,386-80),(6187-6150,376-80),(6187-6150,349-80),(6187-6150,320-80),(6230-6150,244-80),(6285-6150,180-80)],fill=255)
    left_rows=rail_source['blue_components'][1]['source_rows']
    for y in range(left_rows[0][1],left_rows[-1][1]+1):
        a,b=next((a,b) for a,b in zip(left_rows,left_rows[1:]) if a[1]<=y<=b[1])
        bound=round(a[0]+(b[0]-a[0])*(y-a[1])/(b[1]-a[1]))
        for x in range(max(0,bound-RECT[0])):mask.putpixel((x,y-RECT[1]),0)
    # Relocate only actual non-matte BG paint in the inferred architectural role.
    for y in range(native.height):
        for x in range(native.width):
            c=native.getpixel((x,y))
            if not c[3] or max(c[:3])<=3:mask.putpixel((x,y),0)
    mask.save(OUT/'bg-photo-mask.png')
    guide=native.copy();tint=Image.new('RGBA',native.size,(230,80,80,0))
    tint.putalpha(mask.point(lambda p:90 if p else 0));guide.alpha_composite(tint)
    guide.resize((620,768),Image.Resampling.NEAREST).save(OUT/'photo-ownership-review.png')
    union_rect=(portal.RECT[0],portal.RECT[1],portal.RECT[2],max(portal.RECT[3],RECT[3]))
    combined=Image.new('L',(union_rect[2]-union_rect[0],union_rect[3]-union_rect[1]))
    previous=Image.open(central.OUT/'Wall/combined-bg-photo-mask.png').convert('L');combined.paste(previous,(0,0))
    overlay=Image.new('L',combined.size);overlay.paste(mask,(RECT[0]-union_rect[0],RECT[1]-union_rect[1]));combined=ImageChops.lighter(combined,overlay)
    combined.save(OUT/'combined-bg-photo-mask.png');packed,distinct=pack(combined,union_rect,OUT,1024)
    packed.update(map=59530,native_rect=list(union_rect),candidate_only=True)
    (OUT/'floor-data.json').write_text(json.dumps(packed,separators=(',',':'))+'\n')
    record=dict(map=59530,candidate_only=True,native_origin=list(RECT[:2]),size=list(native.size),surfaces=surfaces,flights=flights,
        geometry_sha256=source.sha(json.dumps(surfaces,separators=(',',':')).encode()),paint_sha256=source.sha(b''.join((OUT/name).read_bytes() for name in ['native-paint.png','cap.png','stone.png','stone_shadow.png','body.png','charcoal.png','gold.png'])),
        native_rgba_sha256=source.sha(native.tobytes()),inferred_rise_scale=INFERRED_RISE_SCALE,source_balusters=markers,raw_gold_markers=raw_markers,rail_paths=paths,colours=colours,lower_probe=probe,
        corbel_profile=post_profile,nosing_relief_limit=relief,body_paint=dict(native_rect=witness_rect,source_sha256=source.sha(grain.tobytes()),texels_per_world_unit=VERTICAL,repeat='mirrored native gray patch; concealed continuation inferred'),
        inference=['Observed eight lower and three upper dark riser bands; vertical heights inferred from their projected widths.',
            'Walkable floor XZ retains the original BG coordinates; its source art is sampled independently of inferred elevation, matching the entry-stair contract.',
            'Physical riser height uses0.8 of the sampled dark-band width: original3D height is unknown; original band UVs, floor XZ and eleven bands are unchanged.',
            'Worn nosing profiles retain flat source tread centres while easing the edges within0.15m of the existing collision ramp; these bevel sections are inferred.',
            'Clipped upper-left tread paint continues its own gray, not a new room or route. Hidden upper connection is unverified.',
            'Solid side plinth, rail sections, depth, concealed back and feet are inferred from visible local forms.',
            'Original walking bits, travel, safe-area ownership and music stay unchanged; support is supplied separately by the existing HallSteps height owner.'])
    (OUT/'data.json').write_text(json.dumps(record,separators=(',',':'))+'\n')
    print('ELSA_SECOND_STAIR',len(surfaces),'polygons;11 risers; balusters',[len(p) for p in markers],';',len(packed['placements']),'BG crops; top=',upper_top,flush=True)


if __name__=='__main__':build()

"""Separate the mapped59530 mixed architecture before fitting coherent geometry.

These report-only role boundaries are inferred. Native pixels, CUT placements
and the mixed unassigned roles remain intact; nothing is installed in play.
"""
import json
import math
import statistics
from collections import deque
from PIL import Image, ImageChops, ImageDraw
import recover_elsa_island as source
from prepare_elsa_props import nearest_material_paint

OUT=source.REPORT/'Temple Interior/Central Assembly Candidate'
PROPS=source.ROOT/'assets/maps/falan/elsa/props'
ORIGIN=(6009,-892)
SIZE=(513,912)
# Measured on the combined original414/422 canvas. Source silhouettes clip
# these semantic boundaries; the partition is not proof of original3D depth.
RIGHT_POST=[(448,280),(482,280),(512,296),(512,788),(445,788),
            (445,640),(435,620),(438,600),(432,552),(426,544),
            (433,512),(433,480),(438,472),(440,448),(434,440),
            (426,428),(426,416),(434,398),(434,374),(426,352),(424,296)]
LEFT_POST=[(256,609),(287,609),(320,625),(322,664),(317,679),
           (320,704),(318,717),(322,733),(321,864),(239,864),
           (239,738),(244,725),(240,713),(243,685),(239,670),(239,625)]
ARCH=[(262,0),(512,0),(512,432),(426,432),(416,422),
      (388,390),(356,366),(352,340),(349,308),(349,276),(348,244),
      (347,212),(344,184),(338,160),(329,138),(313,109),(295,80),(277,62),(262,53)]
POSTS={
    'right-post':dict(foot=[476,788],cap=[476,300],profile=[
        [476,788,64],[476,643,64],[476,628,83],[476,613,64],
        [476,563,64],[476,551,82],[476,539,64],[476,478,64],
        [476,468,75],[476,448,75],[476,435,80],[476,425,83],
        [476,410,64],[476,377,64],[476,365,75],[476,353,83],
        [476,298,83],[476,280,68]]),
    'left-post':dict(foot=[280,864],cap=[280,615],profile=[
        [280,864,69],[280,737,69],[280,729,84],[280,716,72],
        [280,704,68],[280,688,68],[280,678,81],[280,666,81],
        [280,653,67],[280,630,78],[280,620,84],[280,609,61]])}


def polygon(points):
    mask=Image.new('L',SIZE);ImageDraw.Draw(mask).polygon(points,fill=255)
    return mask


def right_post_mask(native):
    mask=polygon(RIGHT_POST)
    # The charcoal cap's native contour extends beyond the initial semantic
    # polygon. Follow only its connected dark paint, not the adjacent gray arch.
    pending=deque([(476,300)]);seen={(476,300)}
    while pending:
        x,y=pending.popleft();mask.putpixel((x,y),255)
        for dx,dy in [(a,b) for a in [-1,0,1] for b in [-1,0,1] if a or b]:
            u,v=x+dx,y+dy
            if not 420<=u<512 or not 270<=v<377 or (u,v) in seen:continue
            color=native.getpixel((u,v))
            if not color[3] or max(color[:3])>28:continue
            seen.add((u,v));pending.append((u,v))
    # Retain the cap's bright antialiased edge with its own charcoal core.
    # Otherwise those few edge pixels become disconnected arch fragments.
    for x,y in seen:
        for dy in range(-3,4):
            for dx in range(-3,4):
                u,v=x+dx,y+dy
                if 420<=u<512 and 270<=v<377 and native.getpixel((u,v))[3]:mask.putpixel((u,v),255)
    return mask


def measure_flights(native):
    """Keep observable pixel bands separate from an inferred3D stair height."""
    start=(249.5,417.5);end=(377.5,593.5);samples=520
    dx,dy=end[0]-start[0],end[1]-start[1];length=math.hypot(dx,dy)
    upper=[]
    for i in range(samples+1):
        t=i/samples
        upper.append(statistics.median(native.getpixel((round(start[0]+dx*t+k*dy/length),
                                                       round(start[1]+dy*t-k*dx/length)))[0]
                                       for k in range(-4,5)))
    runs=[]
    for i,value in enumerate(upper):
        if value>=30:continue
        if runs and i-runs[-1][-1]<=4:runs[-1].append(i)
        else:runs.append([i])
    runs=[r for r in runs if len(r)>=4]
    lower=[statistics.median(native.getpixel((x,y))[0] for x in range(340,429)) for y in range(630,866)]
    rising=[]
    for i in range(1,len(lower)):
        if lower[i]-lower[i-1]<=8:continue
        if rising and i-rising[-1][-1]<=4:rising[-1].append(i)
        else:rising.append([i])
    assert len(runs)==12 and len(rising)==12
    data=dict(native_rgba_sha256=source.sha(native.tobytes()),
        upper=dict(start=list(start),end=list(end),samples=samples,half_width=4,
                   median_red=upper,dark_runs=[[r[0],r[-1]] for r in runs],threshold=30),
        lower=dict(y_range=[630,866],x_range=[340,429],median_red=lower,
                   bright_edges=[630+max(r,key=lambda i:lower[i]-lower[i-1]) for r in rising],
                   terminal_front_native_bounds=[322,849,445,865]),
        limits=['Twelve sampled upper dark bands and twelve lower bright transitions are observed in these corridors.',
                'These samples do not establish a complete original step count or original3D heights.',
                'The lower terminal dark face and the turning landing need separate geometric interpretation.'])
    (OUT/'stair-source-bands.json').write_text(json.dumps(data,indent=2)+'\n')
    guide=native.copy();draw=ImageDraw.Draw(guide)
    for r in runs:
        t=r[0]/samples;x=start[0]+dx*t;y=start[1]+dy*t
        draw.line([(x-28*dy/length,y+28*dx/length),(x+28*dy/length,y-28*dx/length)],fill=(250,200,60,255))
    for y in data['lower']['bright_edges']:draw.line((340,y,428,y),fill=(90,230,170,255))
    guide.save(OUT/'stair-source-bands-review.png')


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    props=json.loads((PROPS/'data.json').read_text())
    native=Image.new('RGBA',SIZE);layers=[];proofs=[]
    for token in ['414','422']:
        row=props['groups'][token]
        placement,=[p for p in props['maps']['59530'] if p['group']==token]
        x,y,w,h=row['rect']
        art=Image.open(PROPS/f"atlas-{row['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
        assert source.sha(art.tobytes())==row['rgba_sha256']
        origin=[placement['anchor'][i]+row['origin'][i] for i in [0,1]]
        layer=Image.new('RGBA',SIZE);layer.paste(art,(origin[0]-ORIGIN[0],origin[1]-ORIGIN[1]))
        native.alpha_composite(layer);layers.append((token,layer))
        proofs.append(dict(group=token,master=row['master'],native_origin=origin,
                           size=[w,h],source_rgba_sha256=row['rgba_sha256'],
                           source_cells=placement['cells'],source_pieces=placement['pieces']))
    native.save(OUT/'414-422-native.png')
    measure_flights(native)
    claimed=Image.new('L',SIZE);roles=[]
    selections=[('right-post',right_post_mask(native),(82,176,255)),
                ('left-post',polygon(LEFT_POST),(218,148,55)),
                ('right-half-arch',polygon(ARCH),(203,112,218))]
    # The remainder explicitly stays mixed: do not flatten rails or stair risers.
    selections += [('landing-rails-upper-flight',layers[0][1].getchannel('A'),(121,207,127)),
                   ('lower-flights-rails',layers[1][1].getchannel('A'),(227,102,95))]
    review=Image.new('RGBA',SIZE,(34,43,50,255));review.alpha_composite(native)
    tint=Image.new('RGBA',SIZE)
    for name,selection,color in selections:
        mask=ImageChops.subtract(selection,claimed)
        mask=ImageChops.multiply(mask,native.getchannel('A').point(lambda a:255 if a else 0))
        claimed=ImageChops.lighter(claimed,mask)
        art=native.copy();art.putalpha(ImageChops.multiply(native.getchannel('A'),mask))
        art.save(OUT/(name+'.png'));mask.save(OUT/(name+'-mask.png'))
        paint=Image.new('RGBA',SIZE,(*color,0));paint.putalpha(mask.point(lambda a:90 if a else 0));tint.alpha_composite(paint)
        roles.append(dict(name=name,paint=name+'.png',mask=name+'-mask.png',
                          rgba_sha256=source.sha(art.tobytes()),selected_pixels=sum(bool(a) for a in mask.getdata()),
                          native_bounds=[ORIGIN[i%2]+v for i,v in enumerate(mask.getbbox())],
                          role_boundary='inferred; requires geometry and fixed-gameplay review'))
    columns=[]
    for role in roles:
        name=role['name']
        if name not in POSTS:continue
        art=Image.open(OUT/role['paint']).convert('RGBA');bounds=art.getbbox()
        crop=art.crop(bounds);crop.save(OUT/(name+'-source.png'))
        paint=nearest_material_paint(crop);paint.save(OUT/(name+'-solid.png'))
        post=POSTS[name]
        cap=[post['cap'][i]-bounds[i] for i in [0,1]]
        assert crop.getpixel(tuple(cap))[3]
        columns.append(dict(name=name,source=name+'-source.png',paint=name+'-solid.png',
            crop=list(bounds),origin=[ORIGIN[i]+bounds[i] for i in [0,1]],size=list(crop.size),
            shape=dict(foot=[post['foot'][i]-bounds[i] for i in [0,1]],
                       profile=[[x-bounds[0],y-bounds[1],diameter] for x,y,diameter in post['profile']],
                       sides=8,native_faces=True,cap_paint_pixel=cap),
            inference='Visible cap, collars and shaft guide this profile. Foot contact, octagonal depth, hidden rear paint and continuation behind rails are inferred; no collision or support is added.'))
    assert claimed.tobytes()==native.getchannel('A').point(lambda a:255 if a else 0).tobytes()
    review.alpha_composite(tint)
    ImageDraw.Draw(review).text((8,8),'SOURCE ROLE PARTITION / INFERRED BOUNDARIES',fill='white')
    review.save(OUT/'role-review.png')
    record=dict(schema=1,map=59530,candidate_only=True,native_origin=list(ORIGIN),size=list(SIZE),
                original_rgba_sha256=source.sha(native.tobytes()),sources=proofs,roles=roles,column_candidates=columns,
                limits=['The two mapped masters form one connected landing/stair/arch assembly.',
                        'Post and arch semantic boundaries are inferred from the original paint.',
                        'Unassigned landing, rails and flights remain mixed and must not be flattened.',
                        'No original3D heights, hidden contacts, collision or support are established here.',
                        'No runtime geometry, source archive, navigation, crossing, actor or music is changed.'])
    (OUT/'roles.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_CENTRAL_SOURCE_ROLES',[(r['name'],r['selected_pixels']) for r in roles])


if __name__=='__main__':build()

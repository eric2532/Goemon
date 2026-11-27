"""Stage the mapped BG wall behind the central59530 arch, with closed depth."""
import json
import math
from bisect import bisect_left
from collections import deque
from functools import lru_cache
from PIL import Image, ImageChops, ImageDraw
import recover_elsa_island as source
import prepare_elsa_central_assembly as central
import prepare_elsa_central_portal as portal
from prepare_elsa_gate import native_layers
from prepare_elsa_hall_entry_floor import pack
from prepare_elsa_central_steps import point, VERTICAL

OUT=central.OUT/'Wall'
RECT=(6080,-1024,6656,-192)
LEFT,RIGHT=6136,6580
TOP,FOOT=3973,4313
SLOPE=-.75
DEPTH=1.2


def source_roles(bg,excluded):
    """Keep the connected window wall and its source coping, not adjacent feet."""
    pixels=set()
    for y in range(bg.height):
        for x in range(bg.width):
            u,v=x+RECT[0],y+RECT[1];q=v-SLOPE*u;c=bg.getpixel((x,y))
            if LEFT<=u<=RIGHT and TOP<=q<=FOOT and c[3] and max(c[:3])>3 and not excluded.getpixel((x,y)):pixels.add((x,y))
    parts=[]
    while pixels:
        start=pixels.pop();pending=deque([start]);part={start}
        while pending:
            x,y=pending.popleft()
            for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
                point=(x+dx,y+dy)
                if point in pixels:pixels.remove(point);part.add(point);pending.append(point)
        parts.append(part)
    parts.sort(key=lambda p:(-len(p),min(p)))
    observed=Image.new('L',bg.size);other=Image.new('L',bg.size);coping=Image.new('L',bg.size);roles=[]
    seed=(6550-RECT[0],round(SLOPE*6550+4113)-RECT[1])
    witnesses={(6170-RECT[0],-334-RECT[1]):'FG422 continuation',(6363-RECT[0],-491-RECT[1]):'FG414 continuation'}
    for part in parts:
        q=[y+RECT[1]-SLOPE*(x+RECT[0]) for x,y in part]
        if seed in part:role='masonry/window';target=observed
        elif min(q)<=TOP+2 and max(q)<=TOP+60:role='wall coping';target=observed
        else:
            matches=[role for point,role in witnesses.items() if point in part]
            assert len(matches)==1,('Unclassified BG wall neighbour',len(part),min(q),max(q))
            role=matches[0];target=other
        for point in part:
            target.putpixel(point,255)
            if role=='wall coping':coping.putpixel(point,255)
        roles.append(dict(role=role,pixels=len(part),native_bounds=[min(x for x,y in part)+RECT[0],min(y for x,y in part)+RECT[1],max(x for x,y in part)+RECT[0]+1,max(y for x,y in part)+RECT[1]+1],q_range=[min(q),max(q)]))
    return observed,other,coping,roles


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    _,bg=native_layers([],RECT,59530)
    removed=Image.open(portal.OUT/'bg-photo-mask.png').convert('L')
    excluded=removed.transform(bg.size,Image.Transform.AFFINE,(1,0,RECT[0]-portal.RECT[0],0,1,RECT[1]-portal.RECT[1]))
    observed,other,coping,roles=source_roles(bg,excluded)
    paint=Image.new('RGBA',bg.size);rear=Image.new('RGBA',bg.size)
    def native(u,v):return bg.getpixel((round(u)-RECT[0],round(v)-RECT[1]))
    # Unoccluded original brick panel beside the window, below its header.
    brick=[]
    for h in range(95,215):
        row=[]
        for u in range(6500,6550):
            value=native(u,SLOPE*u+FOOT-h)
            assert value[3] and min(value[:3])>25,(u,h,value)
            row.append(value)
        brick.append(row)
    witness=Image.new('RGBA',(50,120));witness.putdata([p for row in brick for p in row]);witness.save(OUT/'native-brick-witness.png')
    cap_rows={};cap_palette=set()
    for q in range(TOP,TOP+95):
        samples=[]
        for u in range(LEFT,RIGHT+1):
            x,y=u-RECT[0],round(SLOPE*u+q)-RECT[1];c=bg.getpixel((x,y))
            if observed.getpixel((x,y)) and (coping.getpixel((x,y)) or u>=6500):samples.append((u,c));cap_palette.add(c)
        assert samples,('Missing source coping row',q)
        cap_rows[q]=samples
    @lru_cache(maxsize=None)
    def native_cap_colour(rgb):return min(cap_palette,key=lambda c:sum((c[k]-rgb[k])**2 for k in range(3)))
    def cap_colour(u,q):
        samples=cap_rows[max(TOP,min(TOP+94,round(q)))];xs=[p[0] for p in samples];i=bisect_left(xs,u)
        if i==0:return samples[0][1]
        if i==len(samples):return samples[-1][1]
        a,ca=samples[i-1];b,cb=samples[i];t=(u-a)/(b-a)
        return native_cap_colour(tuple(round(ca[k]*(1-t)+cb[k]*t) for k in range(3)))
    for y in range(bg.height):
        for x in range(bg.width):
            u,v=x+RECT[0],y+RECT[1]
            if not LEFT<=u<=RIGHT:continue
            h=SLOPE*u+FOOT-v
            if not 0<=h<=FOOT-TOP:continue
            if h>=FOOT-TOP-94:
                value=cap_colour(u,FOOT-h)
            elif h>=65:
                tx=(u-6500)%100;ty=(round(h)-95)%240
                value=brick[ty if ty<120 else 239-ty][tx if tx<50 else 99-tx]
            else:
                # Continue the matching original cap/plinth course, not window art.
                value=native(6530,SLOPE*6530+FOOT-h)
            rear.putpixel((x,y),value)
            original=bg.getpixel((x,y))
            if observed.getpixel((x,y)):
                paint.putpixel((x,y),original)
            else:paint.putpixel((x,y),value)
    paint.save(OUT/'native-paint.png');rear.save(OUT/'rear-paint.png');observed.save(OUT/'observed-wall-mask.png');bg.save(OUT/'original-background.png')
    other.save(OUT/'other-architecture-mask.png')
    # Body/rear uses a native neutral masonry colour, without facade fragments.
    colour=native(6530,SLOPE*6530+FOOT-50)
    Image.new('RGBA',(1,1),colour).save(OUT/'body.png')
    surfaces=[]
    def vertex(u,h):return point(u,SLOPE*u+FOOT-h,h/VERTICAL)
    def face(points,uv=None,role='inferred wall closure',name='body'):
        surfaces.append(dict(points=points,uv=uv or [[.5,.5]]*len(points),role=role,paint=name))
    front=[vertex(LEFT,0),vertex(RIGHT,0),vertex(RIGHT,FOOT-TOP),vertex(LEFT,FOOT-TOP)]
    # Project the original face exactly; inferred thickness goes behind it.
    along=[front[1][i]-front[0][i] for i in range(3)]
    length=math.hypot(along[0],along[2]);depth=[along[2]/length*DEPTH,0,-along[0]/length*DEPTH]
    back=[[p[i]+depth[i] for i in range(3)] for p in front]
    uv=[[u-RECT[0],SLOPE*u+FOOT-h-RECT[1]] for u,h in [(LEFT,0),(RIGHT,0),(RIGHT,FOOT-TOP),(LEFT,FOOT-TOP)]]
    # Only the two broad faces were inward; the four closures already point out.
    # Reverse point/UV pairs together so all original source projection stays exact.
    face(list(reversed(front)),list(reversed(uv)),'original visible masonry/window face; concealed continuation inferred','native')
    face(back,uv,role='closed inferred masonry rear; no repeated window',name='floor')
    for a,b in [(0,1),(1,2),(2,3),(3,0)]:face([front[a],front[b],back[b],back[a]])
    combined=removed.copy();wall_mask=Image.new('L',combined.size)
    wall_mask.paste(observed,(RECT[0]-portal.RECT[0],RECT[1]-portal.RECT[1]))
    combined=ImageChops.lighter(combined,wall_mask);combined.save(OUT/'combined-bg-photo-mask.png')
    packed,distinct=pack(combined,portal.RECT,OUT,1024)
    packed.update(map=59530,native_rect=list(portal.RECT),candidate_only=True)
    (OUT/'floor-data.json').write_text(json.dumps(packed,separators=(',',':'))+'\n')
    data=dict(map=59530,candidate_only=True,native_origin=list(RECT[:2]),size=list(bg.size),
        geometry_sha256=source.sha(json.dumps(surfaces,separators=(',',':')).encode()),
        paint_sha256=source.sha(paint.tobytes()+rear.tobytes()+bytes(colour)),surfaces=surfaces,
        rect=list(RECT),source_background_sha256=source.sha(bg.tobytes()),
        source_mask_sha256=source.sha(observed.tobytes()),observed_pixels=sum(bool(v) for v in observed.tobytes()),
        wall=dict(native_u=[LEFT,RIGHT],source_slope=SLOPE,top_intercept=TOP,foot_intercept=FOOT,inferred_depth=DEPTH),
        source_roles=roles,other_architecture_pixels=sum(bool(v) for v in other.tobytes()),
        foot_evidence=dict(corridor=[6525,6565],search_q=[4290,4343],contact_q=FOOT,tolerance_rgb=2,interpretation='The darkest plinth/floor contact band is4311..4315; centre4313. Original3D depth remains inferred.'),
        cap_continuation='Source coping and clean right cap samples interpolate across concealed spans at the same native q; quantized to the native cap palette. No window or column fragments supply hidden cap paint.',
        brick_witness=dict(u=[6500,6550],height=[95,215],rgba_sha256=source.sha(witness.tobytes())),
        inference=['Top line follows the confirmed diagonal BG coping through the arch; foot line is inferred from the visible plinth/floor junction.',
                   'Visible mapped BG masonry/window paint is exact. Occluded wall continues only the same brick/cap/plinth bands, without adding doors or windows.',
                   'Wall thickness/rear are inferred; original walking, collision, actors and travel are unchanged. Private candidate only.'])
    (OUT/'data.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    guide=bg.copy();draw=ImageDraw.Draw(guide)
    draw.line([tuple(p) for p in uv+[uv[0]]],fill=(255,185,20,255),width=2);guide.save(OUT/'source-wall-fit.png')
    print('ELSA_CENTRAL_WALL',data['observed_pixels'],'source pixels;',len(packed['placements']),'BG crops;',distinct,'distinct;',len(surfaces),'closed faces',flush=True)


if __name__=='__main__':build()

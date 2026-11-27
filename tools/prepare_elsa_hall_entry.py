"""Stage source-painted59530 treads; do not activate an incomplete support model."""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import recover_elsa_island as source
from prepare_elsa_gate import native_layers
from prepare_elsa_temple import VERTICAL
from prepare_elsa_temple_steps import inside
from prepare_elsa_props import nearest_material_paint

REPORT=source.REPORT/'Temple Interior/Entry Platform Source'
OUT=source.REPORT/'Temple Interior/Hall Entry Candidate'


def point(u,v,height):
    # Match the existing temple stair contract: preserve original XZ footprints.
    return [u*3/64-v/16,height,u*3/64+v/16]


def build():
    original=json.loads((REPORT/'data.json').read_text())
    joins=json.loads((REPORT/'right-joins.json').read_text())
    props=json.loads((source.ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
    rect=original['native_rect'];_,paint=native_layers(props['maps']['59530'],tuple(rect),59530)
    assert source.sha(paint.tobytes())==original['background_rgba_sha256']==joins['background_rgba_sha256']
    OUT.mkdir(exist_ok=True)
    def dark(u,v):
        if not rect[0]<=u<rect[2] or not rect[1]<=v<rect[3]:return False
        c=paint.getpixel((u-rect[0],v-rect[1]));return c[3]>200 and 8<=max(c[:3])<=40
    curves=[]
    for i,band in enumerate(original['dark_bands']):
        samples={int(u):float(top) for u,top,bottom in band['points']}
        # Keep the confirmed column contours; radial samples extend the steep left ends.
        for u,v in original['radial_bands'][i]['points']:
            u,v=round(u),round(v)
            if u>=min(samples):continue
            assert dark(u,v)
            top=v
            while top>v-16 and dark(u,top-1):top-=1
            samples[u]=float(top)
        if i:
            edge=joins['joins'][i-1]['vertical_edge']
            path=joins['joins'][i-1]['dark_source_path'];tail={}
            for u,v in path:
                if u>max(samples):tail.setdefault(u,[]).append(v)
            for u,values in tail.items():
                v=round(sum(values)/len(values));top=v
                while top>v-16 and dark(u,top-1):top-=1
                samples[u]=float(top)
            samples[edge['u']]=float(edge['top'])
        curve=[[u,v] for u,v in sorted(samples.items())]
        assert len(curve)>30 and all(dark(round(u),round(v)) for u,v in curve)
        curves.append(curve)
    # The shared pixel height follows four visible end faces. Original3D height is unknown.
    pixels=float(joins['inferred_riser_candidate']['native_pixels']);rise=pixels/VERTICAL
    tiers=[];mask=Image.new('L',paint.size);draw=ImageDraw.Draw(mask);native_polygons=[]
    repair=Image.new('L',paint.size);repair_draw=ImageDraw.Draw(repair)
    for i,curve in enumerate(curves):
        height=-i*rise
        back=[[u,v-8.] for u,v in reversed(curve)] if i==0 else list(reversed(curves[i-1]))
        # Confirmed visible tip of the first tread, beside the FG pedestal cutout.
        if i==1:
            c=paint.getpixel((5375-rect[0],760-rect[1]));assert c[3]>200 and max(c[:3])>8
            back.insert(0,[5375.,760.])
        polygon=curve+back
        draw.polygon([(u-rect[0],v-rect[1]) for u,v in polygon],fill=255)
        # The photographed riser is relocated too; keep it off the old flat surface.
        face=curve+[[u,v+pixels] for u,v in reversed(curve)]
        draw.polygon([(u-rect[0],v-rect[1]) for u,v in face],fill=255)
        repair_draw.polygon([(u-rect[0],v-rect[1]) for u,v in face],fill=255)
        native_polygons.append(polygon)
        tiers.append(dict(height=height,riser=rise,points=[point(u,v,height) for u,v in curve],back_points=[point(u,v,height) for u,v in back]))
    error=0.
    for tier,native in zip(tiers,native_polygons):
        for p,(u,v) in zip(tier['points']+tier['back_points'],native):
            error=max(error,math.hypot((p[0]+p[2])*32/3-u,(p[2]-p[0])*8-v))
    assert error<1e-8
    # This grid is staged, not active. The current flat physical box still requires a local hole.
    polygons=[[[p[0],p[2]] for p in t['points']+t['back_points']] for t in tiers]
    spacing=1.5
    low=[math.floor(min(p[a] for poly in polygons for p in poly)/spacing)*spacing-15 for a in [0,1]]
    high=[math.ceil(max(p[a] for poly in polygons for p in poly)/spacing)*spacing+15 for a in [0,1]]
    size=[round((b-a)/spacing)+1 for a,b in zip(low,high)];heights=[];fixed=[]
    # The original return event is just beyond the last visible riser, on an
    # original open cell with no floor picture. Continue support, never paint.
    front=[[p[0],p[2]] for p in tiers[-1]['points']]
    def lower_support(at):
        nearest=None
        for a,b in zip(front,front[1:]):
            dx,dz=b[0]-a[0],b[1]-a[1];length=dx*dx+dz*dz
            t=max(0.,min(1.,((at[0]-a[0])*dx+(at[1]-a[1])*dz)/length))
            x,z=a[0]+t*dx,a[1]+t*dz
            distance=math.hypot(at[0]-x,at[1]-z)
            side=dx*(at[1]-z)-dz*(at[0]-x)
            if nearest is None or distance<nearest[0]:nearest=(distance,side)
        distance,side=nearest
        return -5*rise*max(0.,min(1.,(12.-distance)/9.)) if side>=0 else 0.
    for z in range(size[1]):
        for x in range(size[0]):
            at=[low[0]+x*spacing,low[1]+z*spacing];value=lower_support(at);known=x in [0,size[0]-1] or z in [0,size[1]-1]
            for tier,poly in zip(tiers,polygons):
                if inside(*at,poly):value=float(tier['height']);known=True
            if at==[59*3,93*3]:value=-5*rise;known=True
            heights.append(value);fixed.append(known)
    # The visible stairs keep their authored heights. Their shared collision/nav
    # surface eases the risers so the existing native slope rule can traverse them.
    target_heights=heights.copy()
    fixed=[x in [0,size[0]-1] or z in [0,size[1]-1] or
           [low[0]+x*spacing,low[1]+z*spacing] in [[59*3,93*3],[69*3,92*3]]
           for z in range(size[1]) for x in range(size[0])]
    for iteration in range(1200):
        change=0.
        for z in range(1,size[1]-1):
            for x in range(1,size[0]-1):
                index=z*size[0]+x
                if fixed[index]:continue
                neighbors=[heights[index-1],heights[index+1],heights[index-size[0]],heights[index+size[0]]]
                lower=max(neighbors)-spacing*.38;upper=min(neighbors)+spacing*.38
                value=max(lower,min(upper,heights[index])) if lower<=upper else (lower+upper)*.5
                change=max(change,abs(value-heights[index]));heights[index]=value
        if change<1e-7:break
    edge_slope=max(abs(heights[z*size[0]+x]-heights[zz*size[0]+xx])/spacing
                   for z in range(size[1]) for x in range(size[0]) for xx,zz in [(x+1,z),(x,z+1)] if xx<size[0] and zz<size[1])
    assert edge_slope<.38001
    assert min(heights)<-3*rise and max(heights)==0.
    paint.save(OUT/'original-background.png');mask.save(OUT/'displaced-floor-mask.png')
    visible=Image.new('L',paint.size)
    for y in range(paint.height):
        for x in range(paint.width):
            c=paint.getpixel((x,y))
            if c[3]>200 and max(c[:3])>8:visible.putpixel((x,y),255)
    repair=ImageChops.multiply(repair,visible)
    # Original riser photographs belong on vertical faces, not on the tread tops.
    seeds=paint.copy();sp=seeds.load()
    for y in range(paint.height):
        for x in range(paint.width):
            r,g,b,a=sp[x,y]
            if not mask.getpixel((x,y)) or repair.getpixel((x,y)) or max(r,g,b)<=45 or max(r,g,b)-min(r,g,b)>40:sp[x,y]=(0,0,0,0)
    roof=paint.copy();continued=None;copied=0;fallback=0
    offsets=[(0,22),(-16,16),(-22,0),(0,-22),(16,-16),(22,0)]
    for y in range(paint.height):
        for x in range(paint.width):
            if not repair.getpixel((x,y)):continue
            color=None
            for dx,dy in offsets:
                u,v=x+dx,y+dy
                if not 0<=u<paint.width or not 0<=v<paint.height or repair.getpixel((u,v)):continue
                c=paint.getpixel((u,v))
                if c[3]>200 and max(c[:3])>45 and max(c[:3])-min(c[:3])<=40:color=c[:3];break
            if color is None:
                if continued is None:continued=nearest_material_paint(seeds)
                color=continued.getpixel((x,y));fallback+=1
            else:copied+=1
            roof.putpixel((x,y),(*color,paint.getpixel((x,y))[3]))
    for channel in ImageChops.difference(paint,roof).split():
        assert ImageChops.multiply(channel,ImageChops.invert(repair)).getbbox() is None, 'Unmasked native paint/alpha must remain exact'
    roof.save(OUT/'paint.png');repair.save(OUT/'inferred-under-riser-mask.png')
    floor=paint.copy();floor.putalpha(ImageChops.multiply(paint.getchannel('A'),ImageChops.invert(mask)));floor.save(OUT/'flat-floor.png')
    edge=joins['joins'][0]['vertical_edge'];strip=paint.crop((edge['u']-rect[0],edge['top']-rect[1],edge['u']-rect[0]+1,edge['bottom']-rect[1]+1))
    strip.crop((0,0,1,1)).save(OUT/'nosing.png');strip.crop((0,1,1,strip.height)).save(OUT/'riser.png')
    guide=paint.convert('RGB');annotation=ImageDraw.Draw(guide)
    for i,poly in enumerate(native_polygons):
        color=[(255,90,60),(100,255,100),(70,220,255),(255,220,50),(240,100,255)][i]
        annotation.line([(u-rect[0],v-rect[1]) for u,v in poly+[poly[0]]],fill=color,width=1)
    guide.save(OUT/'tier-footprints-review.png')
    width,height,_=source.reference_map(59530)
    links=json.loads((source.ROOT/'assets/maps/falan/elsa/links.json').read_text())
    incoming=[link for link in links if link['source']==59520 and link['cell']==[200,95] and link['target']==59530]
    assert len(incoming)==1 and incoming[0]['landing']==[59,93]
    result=dict(map=59530,rect=rect,source_curves=curves,steps=dict(tiers=tiers,grid=dict(origin=low,size=size,spacing=spacing,heights=heights),
        map_width=width,map_origin=[-(width//2)*3,-(height//2)*3],support_all_grid=True,sample_ground=True,riser_texture='riser.png',nosing_texture='nosing.png',riser_pixel_height=strip.height-1),
        inferred_support=dict(max_axis_slope=edge_slope,max_height_adjustment=max(abs(a-b) for a,b in zip(target_heights,heights)),iterations=iteration+1),
        material_sources=dict(nosing_native_rect=[edge['u'],edge['top'],1,1],riser_native_rect=[edge['u'],edge['top']+1,1,strip.height-1],
            inferred_paving_sample_offsets=offsets,direct_native_paving_pixels=copied,nearest_fallback_pixels=fallback),
        hashes=dict(background=source.sha(paint.tobytes()),paint=source.sha(roof.tobytes()),floor=source.sha(floor.tobytes()),mask=source.sha(mask.tobytes()),repair=source.sha(repair.tobytes())),source_ground_projection_error=error,candidate_only=True,
        incoming_corroborated_link=incoming[0],
        inferred=['The common11px riser height, crease positions inside dark bands, end closures, paving beneath relocated riser photos and local support interpolation are inferred; there is no original3D elevation data.',
                  'World XZ stays on the original tile footprint, as in the existing59520 stair owner. Top paint samples ground coordinates; actual3D camera projection shifts with inferred elevation. No height-dependent coordinate warp is introduced.',
                  'Invisible support continues below the last riser through already-open source cells, including the exact59,93 return event. It rejoins the existing floor with eased risers under the existing native slope rule. The visible stair mesh and endpoint heights stay fixed; intermediate collision heights are inferred ramps, not recovered elevation or new visible paving.'],
        limits=['Not activated. The source paint and geometry need actual fixed gameplay review.',
                'Support grid is preliminary: actor/native navigation, flat-ground cutout, corroborated landing/return event59,93 and adjacent walkable approaches need agreement before publication.',
                'Private BG tile derivatives must remove only the relocated photos. Preserve original void and repair the FG pedestal occlusion separately.',
                'Left end contacts, upper landing mass and BG architecture remain unfinished. No home/save/music/door changes.'])
    temporary=OUT/'data.json.tmp';temporary.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n');temporary.replace(OUT/'data.json')
    print('ELSA_HALL_ENTRY_CANDIDATE',len(tiers),'source-painted levels;',len(heights),'preliminary support samples; source XZ error',error,'not activated',flush=True)


if __name__=='__main__':build()

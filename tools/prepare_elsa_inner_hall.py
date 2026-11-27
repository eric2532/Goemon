"""Fit the original 59535 enclosure across its foreground and background layers."""
import json
import math
from PIL import Image, ImageDraw, ImageFilter
import recover_elsa_island as source
from prepare_elsa_gate import native_layers
from prepare_elsa_scenery import solid_pages

OUT = source.ROOT / 'assets/maps/falan/elsa/scenery/inner-hall'
# Eight repeated column caps and four visible bases establish the original octagon.
# The obscured rear feet use the same 276-pixel column height as the visible front.
FEET = [(139, 626), (406, 434), (785, 434), (1049, 626),
        (1049, 888), (785, 1076), (406, 1076), (139, 888)]
OBJECT_ORIGIN = (3200, -673)
PORTAL_INSET = 18  # Inferred panel setback within the original round-column radius.
# Original curved nosings, measured in the native composite. Half-metre risers
# follow the roughly five-pixel edge; hidden depth remains an explicit inference.
STEP_CURVES = [
    [(444,1100),(433,1114),(423,1136),(422,1161),(432,1186),(451,1210),(480,1233),(514,1248),(548,1254),(578,1250),(606,1239),(615,1230)],
    [(464,1115),(456,1130),(452,1152),(458,1174),(473,1195),(495,1213),(521,1225),(549,1231),(574,1227),(594,1217)],
    [(489,1133),(480,1148),(482,1164),(494,1182),(514,1197),(537,1205),(559,1205),(579,1196)]]
VERTICAL = math.sqrt(2*((32/3)**2-8**2))


def fit_steps(rect, size):
    tiers=[];mask=Image.new('L',size);draw=ImageDraw.Draw(mask)
    for i,curve in enumerate(STEP_CURVES):
        rise=(i+1)*.5;pixels=[]
        for k in range(len(curve)-1):
            a,b,c,d=[curve[max(0,min(len(curve)-1,j))] for j in [k-1,k,k+1,k+2]]
            for sample in range(4):
                t=sample/4
                pixels.append([.5*((2*b[axis])+(-a[axis]+c[axis])*t+(2*a[axis]-5*b[axis]+4*c[axis]-d[axis])*t*t+(-a[axis]+3*b[axis]-3*c[axis]+d[axis])*t*t*t) for axis in [0,1]])
        pixels.append(list(curve[-1]));draw.polygon([tuple(p) for p in pixels],fill=255)
        points=[]
        for u,v in pixels:
            u+=rect[0];v+=rect[1]+rise*VERTICAL
            points.append([u*3/64-v/16,rise,u*3/64+v/16])
        a,b=FEET[7],FEET[6];slope=(b[1]-a[1])/(b[0]-a[0]);back=[]
        for u,v in [pixels[-1],pixels[0]]:
            u+=rect[0]
            ground=OBJECT_ORIGIN[1]+a[1]+slope*(u-OBJECT_ORIGIN[0]-a[0])-PORTAL_INSET-1
            back.append([u*3/64-ground/16,rise,u*3/64+ground/16])
        tiers.append(dict(height=rise,points=points,back_points=back,native_curve=pixels))
    def inside(point,polygon):
        x,y=point;result=False
        for a,b in zip(polygon,polygon[1:]+polygon[:1]):
            if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:result=not result
        return result
    polygons=[[[p[0],p[2]] for p in tier['points']+tier['back_points']] for tier in tiers]
    spacing=1.5
    low=[math.floor(min(p[axis] for poly in polygons for p in poly)/spacing)*spacing-spacing for axis in [0,1]]
    high=[math.ceil(max(p[axis] for poly in polygons for p in poly)/spacing)*spacing+spacing for axis in [0,1]]
    dims=[round((b-a)/spacing)+1 for a,b in zip(low,high)];heights=[]
    for z in range(dims[1]):
        for x in range(dims[0]):
            p=[low[0]+x*spacing,low[1]+z*spacing];height=0
            for tier,poly in zip(tiers,polygons):
                if not inside(p,poly):continue
                distance=1e10
                for a,b in zip(poly,poly[1:]+poly[:1]):
                    dx,dy=b[0]-a[0],b[1]-a[1];length=dx*dx+dy*dy
                    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/length)) if length else 0
                    distance=min(distance,math.hypot(p[0]-a[0]-dx*t,p[1]-a[1]-dy*t))
                height=max(height,tier['height']*min(1,distance/.5))
            heights.append(height)
    return dict(tiers=tiers,grid=dict(origin=low,size=dims,spacing=spacing,heights=heights),
                map_origin=[-177,-177],map_width=119,
                inference='Three source nosings; 0.5 m risers inferred from native edge thickness. Hidden depth and smooth walkable support are inferred, with original blocked cells retained.'),mask


def object_mask(foreground,feet):
    pixels=foreground.load();mask=Image.new('L',foreground.size);target=mask.load()
    for x in range(feet[0][0],feet[3][0]+1):
        rows=[y for y in range(foreground.height) if pixels[x,y][3]]
        assert rows,x
        a,b=next((feet[i],feet[j]) for i,j in [(7,6),(6,5),(5,4)] if feet[i][0]<=x<=feet[j][0])
        bottom=a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0])
        for y in range(min(rows),round(bottom)+1):target[x,y]=255
    draw=ImageDraw.Draw(mask)
    for x,y in feet:
        draw.rectangle((x-27,y-300,x+27,y),fill=255)
        draw.ellipse((x-28,y-16,x+28,y+16),fill=255)
    return mask


def fit_room(background,rect,occlusion):
    # Column centers and floor contacts measured in the original background.
    feet=[(84,1250),(84,732),(487,444),(865,380),(1384,380),(1660,582),(1660,944)]
    heights=[370,340,338,360,360,375,340]
    mask=Image.new('L',background.size);draw=ImageDraw.Draw(mask)
    seed=Image.new('RGBA',background.size);pixels=seed.load();native=background.load();walls=[];columns=[]
    covered=occlusion.filter(ImageFilter.MaxFilter(9)).load()
    for start,end in [(1,2),(2,3),(3,4),(4,5)]:
        a,b=feet[start],feet[end];rows=[]
        for x in sorted({*range(a[0]+42,b[0]-41,4),b[0]-42}):
            footer=a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0])
            top=next(y for y in range(round(footer)) if native[x,y][3] and max(native[x,y][:3])>3)
            rows.append([x+rect[0],top+rect[1],footer+rect[1]])
            for xx in range(x-2,x+3):
                for y in range(top,round(footer)+1):
                    color=native[xx,y]
                    if not covered[xx,y] and color[3] and 3<max(color[:3]) and max(color[:3])-min(color[:3])<18 and y<footer-12 and (y<footer-48 or max(color[:3])<65):pixels[xx,y]=color
        left_top=a[1]-heights[start]+rect[1]
        right_top=b[1]-heights[end]+rect[1]
        rows=[[a[0]+rect[0],left_top,a[1]+rect[1]]]+rows+[[b[0]+rect[0],right_top,b[1]+rect[1]]]
        walls.append(dict(feet=[start,end],rows=rows))
        draw.polygon([(u-rect[0],top-rect[1]) for u,top,foot in rows]+
                     [(u-rect[0],foot-rect[1]) for u,top,foot in reversed(rows)],fill=255)
    for (x,y),height in zip(feet,heights):
        draw.rectangle((x-46,y-height-8,x+46,y+12),fill=255)
        columns.append(dict(foot=[x+rect[0],y+rect[1]],sides=8,paint_rows=True,
            profile=[[x+rect[0],y+rect[1]-dy,diameter] for dy,diameter in
                     [(0,65),(52,65),(65,76),(75,63),(height-135,61),(height-125,73),
                      (height-100,73),(height-90,63),(height-17,64),(height,80)]]))
    solid=solid_pages(dict(graphics={'room':dict(rect=[0,0,*background.size],page=0)}),[seed])[0]
    return dict(feet=[[x+rect[0],y+rect[1]] for x,y in feet],walls=walls,columns=columns,
                side_faces=[[0,1],[5,6]],
                inference='Four visible background wall spans and seven octagonal posts. Obscured floor contacts, wall thickness and edge-on side faces continue the measured architecture. Original walkability is retained; these visual walls add no new blocked cells.'),mask,solid


def portal_edges(art):
    """Continuous native contours, without the coarse photo-fragment grid caps."""
    alpha=art.getchannel('A');pixels=alpha.load()
    occupied={(x,y) for y in range(art.height) for x in range(art.width) if pixels[x,y]>=128}
    links={}
    for x,y in sorted(occupied):
        for neighbor,a,b in [((x,y-1),(x,y),(x+1,y)),((x+1,y),(x+1,y),(x+1,y+1)),
                             ((x,y+1),(x+1,y+1),(x,y+1)),((x-1,y),(x,y+1),(x,y))]:
            if neighbor not in occupied:links.setdefault(a,set()).add(b)
    def simplify(points):
        if len(points)<3:return points
        a,b=points[0],points[-1];dx,dy=b[0]-a[0],b[1]-a[1];length=dx*dx+dy*dy
        errors=[]
        for i,p in enumerate(points[1:-1],1):
            t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/length)) if length else 0
            errors.append((math.hypot(p[0]-a[0]-dx*t,p[1]-a[1]-dy*t),i))
        error,i=max(errors)
        return points[:1]+points[-1:] if error<=1 else simplify(points[:i+1])[:-1]+simplify(points[i:])
    directions={(1,0):0,(0,1):1,(-1,0):2,(0,-1):3};result=[]
    while links:
        start=min(links);point=start;previous=None;loop=[start]
        while True:
            choices=links[point]
            if previous is None:following=min(choices)
            else:
                heading=directions[(point[0]-previous[0],point[1]-previous[1])]
                following=min(choices,key=lambda p:([1,0,3,2].index((directions[(p[0]-point[0],p[1]-point[1])]-heading)%4),p))
            choices.remove(following)
            if not choices:del links[point]
            previous,point=point,following;loop.append(point)
            if point==start:break
        if abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(loop,loop[1:])))<16:continue
        split=max(range(1,len(loop)-1),key=lambda i:math.dist(start,loop[i]))
        path=simplify(loop[:split+1])[:-1]+simplify(loop[split:])
        for a,b in zip(path,path[1:]):
            center=((a[0]+b[0])*.5,(a[1]+b[1])*.5);x,y=round(center[0]),round(center[1]);samples=[]
            for radius in range(1,5):
                samples=[(xx,yy) for yy in range(y-radius,y+radius+1) for xx in range(x-radius,x+radius+1) if (xx,yy) in occupied]
                if samples:break
            assert samples,(a,b)
            sample=min(samples,key=lambda p:(p[0]+.5-center[0])**2+(p[1]+.5-center[1])**2)
            result.append([*a,*b,sample[0]+.5,sample[1]+.5])
    return result


def build():
    props = json.loads((source.ROOT / 'assets/maps/falan/elsa/props/data.json').read_text())
    members = props['maps']['59535']
    assert len(members) == 6
    assert {props['groups'][p['group']]['master'] for p in members} == {301052, 301053}
    width, height, planes = source.reference_map(59535)
    boxes = []
    for i, serial in enumerate(planes[0]):
        if serial < 1000:
            continue
        art, offset, _ = source.cut_image(59535, serial)
        u = (i % width + i // width) * 32 + offset[0]
        v = (i // width - i % width) * 24 + offset[1]
        boxes.append((u, v, u + art.width, v + art.height))
    rect = [min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes)]
    foreground, background = native_layers(members, rect, 59535)
    paint = Image.alpha_composite(background, foreground)
    steps,step_mask=fit_steps(rect,paint.size)
    ox, oy = OBJECT_ORIGIN[0] - rect[0], OBJECT_ORIGIN[1] - rect[1]
    feet = [(x + ox, y + oy) for x, y in FEET]
    fg = foreground.load(); bg = background.load()
    # Remove only the enclosure's projected silhouette from the old floor photo.
    # The entrance's semicircular ground steps remain outside the front foot line.
    mask=object_mask(foreground,feet)
    enclosure_mask=mask.copy()
    room,room_mask,room_paint=fit_room(background,rect,enclosure_mask)
    # Cover the original riser edges as well as the traced top nosings.
    mask=Image.composite(Image.new('L',paint.size,255),mask,step_mask.filter(ImageFilter.MaxFilter(25)))
    mask=Image.composite(Image.new('L',paint.size,255),mask,room_mask)
    m=mask.load()
    # Retain literal native paving and blue paint; only hidden continuation is inferred.
    blue_feet=feet[:7]+[(feet[6][0],feet[6][1]-PORTAL_INSET),(feet[7][0],feet[7][1]-PORTAL_INSET),feet[7]]
    physical = Image.new('L', paint.size); ImageDraw.Draw(physical).polygon(blue_feet, fill=255)
    inside = physical.load()
    candidates = []
    for y in range(0, paint.height-48, 24):
        for x in range(0, paint.width-64, 32):
            if mask.crop((x, y, x+64, y+48)).getbbox():
                continue
            patch = background.crop((x, y, x+64, y+48))
            samples = list(patch.getdata())
            if all(a == 255 and abs(r-g) < 8 and abs(g-b) < 8 and 70 < r < 200
                   for r, g, b, a in samples):
                candidates.append((abs(x-(ox+600))+abs(y-(oy+1170)), x, y))
    assert candidates, 'No original paving patch'
    _, px, py = min(candidates)
    patch = background.crop((px, py, px+64, py+48)); paving = patch.load()
    # A visible central sample is native blue floor, separate from the raised wall.
    blue_rect = (ox+500, oy+560, ox+564, oy+608)
    blue = paint.crop(blue_rect); blue_pixels = blue.load()
    assert all(a and (max(r,g,b) <= 3 or b > r*1.4 and b > g*1.25)
               for r, g, b, a in blue.getdata())
    blue_seed = Image.new('RGBA',paint.size); seeds=blue_seed.load()
    for y in range(paint.height):
        for x in range(paint.width):
            r,g,b,a=paint.getpixel((x,y))
            if inside[x,y] and a and (max(r,g,b)<=3 or r==0 and g==0 and b>0):
                seeds[x,y]=(r,g,b,a)
    extended_blue=solid_pages(dict(graphics={'floor':dict(rect=[0,0,*paint.size],page=0)}),[blue_seed])[0].convert('RGBA')
    blue_pixels=extended_blue.load()
    floor = background.copy(); pixels = floor.load()
    for y in range(floor.height):
        for x in range(floor.width):
            if m[x, y]:
                pixels[x, y] = (blue_pixels[x,y]
                                if inside[x, y] else paving[(x-px) % 64, (y-py) % 48])
    walls = []
    for start, end, front, lowest in [(0, 1, False, 0), (1, 2, False, 0), (2, 3, False, 0),
                                      (7, 6, True, 450), (6, 5, True, 650), (5, 4, True, 500)]:
        a, b = feet[start], feet[end]; rows = []
        for x in [*range(a[0], b[0], 4), b[0]]:
            footer = a[1] + (b[1]-a[1])*(x-a[0])/(b[0]-a[0])-(PORTAL_INSET if [start,end]==[7,6] else 0)
            if front:
                tops = [y for y in range(oy+lowest, round(footer))
                        if bg[x, y][3] and bg[x, y][0] >= bg[x, y][2]*.8
                        and bg[x, y][1] >= bg[x, y][2]*.8]
            else:
                tops = [y for y in range(round(footer)) if fg[x, y][3]]
            assert tops, (start, end, x)
            rows.append([x+rect[0], min(tops)+rect[1], footer+rect[1]])
        walls.append(dict(feet=[start, end], rows=rows, front=front,inset=PORTAL_INSET if [start,end]==[7,6] else 0))
    columns = []
    for i, (x, y) in enumerate(feet):
        # Original round cap, gilt collar, shaft and widened foot use one shared builder.
        columns.append(dict(foot=[x+rect[0], y+rect[1]], sides=12, paint_rows=True,
            profile=[[x+rect[0], y+rect[1]-dy, diameter] for dy, diameter in
                     [(0,49), (5,54), (12,43), (220,39), (235,42),
                      (264,43), (276,48), (290,36), (300,6)]]))
    OUT.mkdir(parents=True, exist_ok=True)
    enclosure_mask.save(OUT/'enclosure-mask.png')
    room_paint.save(OUT/'room-wall.png');room_mask.save(OUT/'room-mask.png')
    for name, image in [('original-background', background), ('original-foreground', foreground),
                        ('paint', paint), ('floor', floor), ('object-mask', mask)]:
        image.save(OUT / (name+'.png'))
    for name,layer in [('foreground',foreground),('background',background)]:
        solid_pages(dict(graphics={'hall':dict(rect=[0,0,*paint.size],page=0)}),[layer])[0].save(OUT/(name+'-solid.png'))
    # The native BG also bakes fragments of the inner enclosure across these
    # rear posts. Continue their own visible stone only where that enclosure hides them.
    room_columns=Image.open(OUT/'background-solid.png').convert('RGB')
    for index,patch_y in [(2,240),(3,230)]:
        column=room['columns'][index];x=round(column['foot'][0]-rect[0]);y=round(column['foot'][1]-rect[1])
        top=round(column['profile'][-1][1]-rect[1]);patch=background.crop((x-10,patch_y,x+10,patch_y+4)).convert('RGB')
        assert all(max(r,g,b)-min(r,g,b)<16 and 10<r<180 for r,g,b in patch.getdata())
        for yy in range(top,y+13):
            for xx in range(x-46,x+47):
                if enclosure_mask.getpixel((xx,yy)):
                    room_columns.putpixel((xx,yy),patch.getpixel(((xx-x+46)%20,(yy-top)%4)))
    room_columns.save(OUT/'room-columns.png')
    materials = {'room-wall':source.sha(room_paint.tobytes()),'room-columns':source.sha(room_columns.tobytes())}; bare_walls = {}
    for front,name,layer in [(False,'foreground',foreground),(True,'background',background)]:
        # Columns and portal fragments are occluders, not masonry painted onto walls.
        seed=Image.new('RGBA',paint.size); target=seed.load(); source_pixels=layer.load(); trim=[]
        for wall in walls:
            if wall['front']!=front:continue
            for u,top,foot in wall['rows']:
                x=round(u-rect[0]); first=round(top-rect[1]); last=round(foot-rect[1])
                for xx in range(max(0,x-2),min(paint.width,x+3)):
                    for y in range(first,last+1):
                        color=source_pixels[xx,y];r,g,b,a=color
                        if not a:continue
                        column=any(abs(xx-fx)<28 for fx,fy in feet)
                        end=last-24
                        if front and wall['feet']==[7,6] and STEP_CURVES[0][0][0]<=xx<=STEP_CURVES[0][-1][0]:
                            a,b=STEP_CURVES[-1][0],STEP_CURVES[-1][-1]
                            end=min(last,a[1]+(b[1]-a[1])*(xx-a[0])/(b[0]-a[0]))
                        if not column and (y<first+17 or front and y<end):trim.append((xx,y,color))
                        elif y<last-48 and abs(r-g)<12 and b>=r*.9 and max(r,g,b)<145:target[xx,y]=color
        wall_paint=solid_pages(dict(graphics={'wall':dict(rect=[0,0,*paint.size],page=0)}),[seed])[0]
        bare_walls[name]=wall_paint.copy()
        for x,y,color in trim:wall_paint.putpixel((x,y),color[:3])
        wall_paint.save(OUT/(name+'-wall.png')); materials[name+'-wall']=source.sha(wall_paint.tobytes())
    # The lower rear shafts are hidden by the front portal/caps in the source photo.
    # Continue their own visible dark stone at its original pixel scale; reuse a
    # confirmed front foot for the matching gilt base, instead of copying an orb.
    column_paint=Image.open(OUT/'foreground-solid.png').convert('RGB')
    shaft_rect=(ox+394,oy+265,ox+418,oy+269); shaft=paint.crop(shaft_rect).convert('RGB')
    base_rect=(ox+745,oy+1056,ox+825,oy+1100); base=background.crop(base_rect).convert('RGB')
    target=column_paint.load()
    for x,y in feet[:4]:
        for yy in range(y-210,y+25):
            for xx in range(x-40,x+41):
                target[xx,yy]=(base.getpixel((min(79,xx-x+40),min(43,yy-y+20))) if yy>=y-20 else
                               shaft.getpixel(((xx-x+40)%shaft.width,(yy-y+210)%shaft.height)))
    column_paint.save(OUT/'foreground-columns.png');materials['foreground-columns']=source.sha(column_paint.tobytes())
    portal=Image.new('RGBA',paint.size); target=portal.load()
    native_pixels=paint.load()
    for wall in walls:
        if wall['feet']!=[7,6]:continue
        for u,top,foot in wall['rows']:
            x=round(u-rect[0]);first=oy+450;last=round(foot-rect[1])
            if any(abs(x-fx)<28 for fx,fy in feet):continue
            for xx in range(x-2,x+3):
                for y in range(first,last-12):
                    r,g,b,a=native_pixels[xx,y]
                    if y>oy+780 and ox+240<xx<ox+320 and r<g and r<b:continue
                    if a and (r>g*1.08 and r>b*1.1 or g>r*1.1 and g>b*1.05 or y<oy+720 and b>g*1.2 and r>g*1.2 and r>20):
                        target[xx,y]=(r,g,b,a)
    coherent=portal.getchannel('A').filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    coherent=coherent.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9)).load()
    for y in range(portal.height):
        for x in range(portal.width):
            target[x,y]=native_pixels[x,y] if coherent[x,y] and native_pixels[x,y][3] else (0,0,0,0)
    # The raised frame owns this paint; retaining a second flat copy makes
    # displaced sprite fragments visible from a reachable side angle.
    wall_paint=Image.open(OUT/'background-wall.png').convert('RGB');undercoat=bare_walls['background'].load();pixels=wall_paint.load()
    for y in range(portal.height):
        for x in range(portal.width):
            if target[x,y][3]:pixels[x,y]=undercoat[x,y]
    wall_paint.save(OUT/'background-wall.png');materials['background-wall']=source.sha(wall_paint.tobytes())
    box=portal.getbbox();portal=portal.crop(box);portal.save(OUT/'portal-trim.png')
    solid_pages(dict(graphics={'trim':dict(rect=[0,0,*portal.size],page=0)}),[portal])[0].save(OUT/'portal-trim-solid.png')
    a,b=feet[7],feet[6];slope=(b[1]-a[1])/(b[0]-a[0])
    portal_fit=dict(origin=[rect[0]+box[0],rect[1]+box[1]],size=list(portal.size),edges=portal_edges(portal),
                    foot=[slope,a[1]+rect[1]-slope*(a[0]+rect[0])-PORTAL_INSET],depth=.3,rgba_sha256=source.sha(portal.tobytes()))
    data = dict(map=59535, rect=rect, feet=[[x+rect[0],y+rect[1]] for x,y in feet],
                members=members, walls=walls, columns=columns, side_faces=[[3,4],[7,0]],steps=steps,room=room,
                blue_footprint=[[x+rect[0],y+rect[1]] for x,y in blue_feet],
                paving_rect=[px,py,64,48], blue_rect=list(blue_rect),
                material_hashes=materials,shaft_rect=list(shaft_rect),base_rect=list(base_rect),portal=portal_fit,
                hashes={name:source.sha(image.tobytes()) for name,image in
                        [('background',background),('foreground',foreground),('paint',paint),
                         ('floor',floor),('mask',mask)]},
                limits=['Rear ground feet, wall thickness and hidden surfaces are inferred from the eight native column caps and four visible bases. Hidden paving/blue floor repeat original surface samples. Original walking data and source layers are unchanged. The surrounding room architecture remains a separate art pass.'])
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_INNER_HALL', len(walls), 'source-facing walls;',len(columns),'columns;',floor.size,'floor')


if __name__ == '__main__':
    build()

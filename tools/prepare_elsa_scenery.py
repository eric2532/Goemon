"""Prepare original PUK2 scenery animation and the assembled island tower paint."""
import argparse
import json
import math
import statistics
from collections import deque
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter, ImageDraw
import recover_elsa_island as source
from recover_original_crossgate_maps import solid_pages as extend_edges

OUT=source.ROOT/'assets/maps/falan/elsa/scenery'
TOWER_MASTERS={300780,300781,300782,300783,300784,300785,300787}


def solid_pages(catalog,pages):
    result=extend_edges(catalog,pages)
    for g in catalog['graphics'].values():
        x,y,w,h=g['rect'];art=pages[g['page']].crop((x,y,x+w,y+h))
        mask=art.getchannel('A').point(lambda value:255 if value else 0)
        result[g['page']].paste(art.convert('RGB'),(x,y),mask)
    return result


def prepare_solids():
    catalog=json.loads((source.OUTPUT/'catalog.json').read_text())
    solids=dict(graphics={key:dict(g,page=int(g['page'])-int(catalog['page_offset']))
                         for key,g in catalog['graphics'].items() if not g['ground'] and not g['animated']})
    pages=[Image.open(source.OUTPUT.parent/name).convert('RGBA') for name in catalog['pages']]
    for i,im in enumerate(solid_pages(solids,pages)):im.save(source.OUTPUT/f'solid-{i}.png')
    for name in ['tower','temple']:
        art=Image.open(OUT/f'{name}.png').convert('RGBA')
        solid_pages(dict(graphics={name:dict(rect=[0,0,*art.size],page=0)}),[art])[0].save(OUT/f'{name}-solid.png')
    prepare_tower_materials()
    print('ELSA_SOLID_PAINT',len(pages),'pages; every opaque source RGB value retained')


def prepare_return_stone():
    ident,pack,clips=source.cg.actor('puk2:66');assert ident==110500
    clip=next(c for c in clips if c['action']==0 and c['direction']==0)
    frames=[source.cg.frame_parts('puk2:66',clip['index'],i) for i in range(len(clip['frames']))]
    left=min(x for art,x,y in frames);top=min(y for art,x,y in frames)
    width=max(x+art.width for art,x,y in frames)-left;height=max(y+art.height for art,x,y in frames)-top
    atlas=Image.new('RGBA',(width*len(frames),height))
    for i,(art,x,y) in enumerate(frames):atlas.paste(art,(i*width+x-left,y-top))
    target=OUT/'return-stone';target.mkdir(parents=True,exist_ok=True);atlas.save(target/'atlas.png')
    data=dict(actor=ident,key='puk2:66',clip=clip['index'],duration=clip['duration'],frames=len(frames),size=[width,height],origin=[left,top],
              rgba_sha256=source.sha(atlas.tobytes()),source_frames=[dict(graphic=clip['frames'][i][0],origin=[x,y],size=list(art.size),rgba_sha256=source.sha(art.tobytes())) for i,(art,x,y) in enumerate(frames)])
    (target/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_RETURN_STONE',len(frames),'original idle frames',clip['duration'],'milliseconds')


def prepare_tower_profile():
    path=OUT/'data.json';data=json.loads(path.read_text());tower=data['tower']
    art=Image.open(OUT/'tower.png').convert('RGBA');pixels=art.load()
    axis=tower['anchor'][0]-tower['rect'][0];floor=tower['anchor'][1]-tower['rect'][1]
    coefficient=2*max(abs((x+z)/math.sqrt(2)) for x,z in tower['radial'])/18*(32/3*math.sqrt(2))
    body=[];first=round(floor-6*tower['height_factor']/.045)
    for row in [*range(first,-1,-8),0]:
        if body and row==0 and body[-1][3]==0:continue
        height=(floor-row)*.045/tower['height_factor'];spans=[]
        for yy in range(max(0,row-2),min(art.height,row+3)):
            marks=[]
            for x in range(art.width):
                r,g,b,a=pixels[x,yy]
                if a and (height>=24 or abs(x-axis)<art.width*.35 and b>r*1.25 and b>g*1.08):marks.append(x)
            if marks:spans.append((marks[0],marks[-1]))
        if not spans:continue
        left=statistics.median(s[0] for s in spans);right=statistics.median(s[1] for s in spans)
        body.append([(right-left+1)/coefficient,height,(left+right)*.5-axis,row])

    def simplify(points):
        if len(points)<3:return points
        a,b=points[0],points[-1];errors=[]
        for i,p in enumerate(points[1:-1],1):
            t=(p[1]-a[1])/(b[1]-a[1]);radius=a[0]+(b[0]-a[0])*t;center=a[2]+(b[2]-a[2])*t
            errors.append((abs(p[0]-radius)*coefficient*.5+abs(p[2]-center),i))
        error,index=max(errors)
        if error<=2:return [a,b]
        return simplify(points[:index+1])[:-1]+simplify(points[index:])

    body=simplify(body)
    garden=[[17.5,0,0],[17.5,.35,0],[18,1.7,0],[18,3.2,0],[15.5,3.4,0]]
    tower['profile']=garden+[[round(r,6),round(h,6),round(c,6)] for r,h,c,row in body]
    tower['profile_source']='Original alpha silhouette above the lower roots; original blue surface spans below. Native width/axis fit within two pixels; garden footprint unchanged. Hidden depth remains inferred.'
    tower['profile_rgba_sha256']=source.sha(art.tobytes())
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_TOWER_PROFILE',len(tower['profile']),'source-fitted levels; original garden footprint retained')


def prepare_tower_materials():
    path=OUT/'data.json';data=json.loads(path.read_text());tower=data['tower']
    art=Image.open(OUT/'tower.png').convert('RGBA');pixels=art.load();width,height=art.size
    gold=Image.new('L',art.size);marks=gold.load()
    for y in range(1400,height):
        for x in range(width):
            r,g,b,a=pixels[x,y]
            if a and r>5 and r>=g and r>b*1.2:marks[x,y]=255
    # Native image boundaries separate the buttresses from neighboring fences,
    # flowers and the shaft's narrow gilt ribs. Color alone joins those objects.
    front_left=[(253,1715),(261,1738),(266,1765),(272,1794),(283,1817),(300,1829),(329,1841),
                (287,1851),(267,1865),(245,1884),(221,1905),(204,1924),(190,1945),(176,1970),
                (164,2000),(157,2030),(158,2065),(166,2110),(187,2168),(141,2159),(27,2190),
                (39,2158),(55,2124),(73,2085),(91,2046),(111,2006),(130,1965),(153,1919),
                (175,1873),(195,1830),(217,1782),(238,1735)]
    front_right=[(764,1733),(791,1768),(822,1782),(864,1806),(824,1815),(805,1835),(801,1863),
                 (809,1886),(827,1912),(850,1946),(877,1988),(907,2040),(942,2104),(975,2164),
                 (991,2193),(923,2178),(886,2171),(838,2178),(851,2144),(864,2097),(868,2055),
                 (865,2021),(853,1980),(835,1944),(809,1912),(778,1888),(744,1867),(702,1851),
                 (736,1839),(755,1822),(763,1797),(762,1766)]
    back_left=[(244,1470),(259,1497),(260,1525),(262,1546),(274,1557),(294,1564),(315,1575),
               (286,1582),(269,1590),(255,1600),(241,1616),(226,1606),(211,1595),(197,1588),
               (180,1587),(164,1592),(148,1603),(132,1618),(116,1639),(104,1667),(91,1693),
               (82,1718),(78,1738),(21,1707),(65,1658),(107,1614),(146,1573),(188,1526),(225,1486)]
    contours=[front_left,front_right,back_left,[(1036-x,y) for x,y in back_left]]
    roots=[];root_mask=Image.new('L',art.size);anchor=[tower['anchor'][i]-tower['rect'][i] for i in range(2)]
    common_height=anchor[1]-statistics.mean(min(y for x,y in points) for points in contours)
    for i,points in enumerate(contours):
        mask=Image.new('L',art.size);ImageDraw.Draw(mask).polygon(points,fill=255)
        mask=trim_support_border(mask,gold)
        mask=ImageChops.multiply(mask,art.getchannel('A'));root_mask=ImageChops.lighter(root_mask,mask)
        box=mask.getbbox();piece=art.crop(box);piece.putalpha(mask.crop(box))
        piece.save(OUT/f'tower-root-{i}.png')
        solid_pages(dict(graphics={'root':dict(rect=[0,0,*piece.size],page=0)}),[piece])[0].save(OUT/f'tower-root-{i}-solid.png')
        top=box[1]-anchor[1];foot=box[3]-anchor[1];slope=1-common_height/(foot-top)
        edges=outline(piece);paint=piece.load()
        # A one-pixel antialiased silhouette may contain garden paint behind
        # the support. Its hidden side uses actual adjacent bronze, not grass.
        def bronze(x,y):
            r,g,b,a=paint[x,y]
            return a and r>g*1.04 and r>b*1.3
        for edge in edges:
            sx,sy=int(edge[4]),int(edge[5])
            if bronze(sx,sy):continue
            for radius in [2,4,8,16,32,64]:
                candidates=[(x,y) for y in range(max(0,sy-radius),min(piece.height,sy+radius+1))
                            for x in range(max(0,sx-radius),min(piece.width,sx+radius+1)) if bronze(x,y)]
                if candidates:
                    x,y=min(candidates,key=lambda point:(point[0]-sx)**2+(point[1]-sy)**2)
                    edge[4:]=[x+.5,y+.5];break
        roots.append(dict(rect=list(box),origin=[box[0]-anchor[0],box[1]-anchor[1]],foot=[0,(1-slope)*foot],vertical=slope,height_pixels=common_height,
                          edges=edges,rgba_sha256=source.sha(piece.tobytes())))
    assert len(roots)==4
    body=art.copy();garden=art.copy();ba=Image.new('L',art.size);ga=Image.new('L',art.size);blue_alpha=Image.new('L',art.size)
    envelope=Image.new('L',art.size);ImageDraw.Draw(envelope).polygon([(0,0),(width,0),(width,1400),(670,1400),(714,1660),(850,1820),(792,1944),(518,2010),(270,1944),(260,1840),(320,1700),(344,1400),(0,1400)],fill=255)
    em=envelope.load()
    bm=ba.load();gm=ga.load();rm=root_mask.load();blue_pixels=blue_alpha.load()
    for y in range(height):
        for x in range(width):
            r,g,b,a=pixels[x,y]
            if not a:continue
            blue=b>r*1.04 and b>g*1.01
            if blue and em[x,y] and not rm[x,y]:blue_pixels[x,y]=a
            if em[x,y] and not rm[x,y] and (y<1400 or blue or r>=g and r>b*1.2):bm[x,y]=255
            saturated=blue and (b-r>45 or b-g>35 or r<60)
            if y>=1400 and not saturated and not rm[x,y]:gm[x,y]=255
    # Preserve white highlights and narrow gilt edges beside the blue structure.
    ba=ImageChops.multiply(ba.filter(ImageFilter.MaxFilter(5)),art.getchannel('A'))
    ba=ImageChops.subtract(ba,root_mask)
    body.putalpha(ba);garden.putalpha(ga)
    # The source is a flattened photograph: supports hide portions of the blue
    # shaft. Those pixels need inferred blue paint behind the separate support,
    # rather than a physical hole through the tower at another gameplay angle.
    fill=Image.new('L',art.size);fm=fill.load();visible=ba.load()
    for y in range(1400,height):
        known=[x for x in range(width) if visible[x,y]]
        if not known:continue
        for x in range(known[0],known[-1]+1):
            if rm[x,y] and em[x,y]:fm[x,y]=rm[x,y]
    blue_art=art.copy();blue_art.putalpha(blue_alpha)
    hidden=solid_pages(dict(graphics={'blue':dict(rect=[0,0,*art.size],page=0)}),[blue_art])[0]
    body.paste(hidden.convert('RGBA'),(0,0),fill)
    fill.save(OUT/'tower-body-occluded.png')
    garden_solid=solid_pages(dict(graphics={'garden':dict(rect=[0,0,*art.size],page=0)}),[garden])[0]
    garden_solid.save(OUT/'tower-garden.png');body.save(OUT/'tower-body.png')
    # The two visible masonry bands and flower terrace are distinct surfaces.
    # Keep their original surface paint off the blue shaft and its gold supports.
    surfaces={'stone-lower':[450,2124,650,2184],'stone-upper':[450,2003,650,2063],
              'flowers':[900,1875,935,1910]}
    for name,box in surfaces.items():art.crop(box).save(OUT/f'tower-{name}.png')
    fence_box=[470,2050,515,2122];fence=art.crop(fence_box);paint=fence.load();mask=Image.new('L',fence.size);gold=mask.load()
    for y in range(fence.height):
        for x in range(fence.width):
            r,g,b,a=paint[x,y]
            if a and r>5 and r>=g and r>b*1.25:gold[x,y]=255
    # Remove isolated flower pixels; retain the original filigree connected to
    # the lower gold rail, including diagonal one-pixel strokes.
    bottom=mask.getbbox()[3];queue=deque((x,y) for y in range(max(0,bottom-3),bottom) for x in range(fence.width) if gold[x,y]);keep=set(queue)
    while queue:
        x,y=queue.popleft()
        for yy in range(max(0,y-1),min(fence.height,y+2)):
            for xx in range(max(0,x-1),min(fence.width,x+2)):
                if gold[xx,yy] and (xx,yy) not in keep:keep.add((xx,yy));queue.append((xx,yy))
    alpha=Image.new('L',fence.size);values=alpha.load()
    for x,y in keep:values[x,y]=255
    bounds=alpha.getbbox();fence.putalpha(alpha);fence=fence.crop(bounds);fence.save(OUT/'tower-fence.png')
    tower['fence']=dict(rect=[fence_box[0]+bounds[0],fence_box[1]+bounds[1],fence_box[0]+bounds[2],fence_box[1]+bounds[3]],
                        size=list(fence.size),rgba_sha256=source.sha(fence.tobytes()),source='Original lower-front gold filigree, repeated around both original garden terraces. Occluded rear repeats are inferred.')
    step=8;occupied=[];sections=[];mask=body.getchannel('A')
    for y in range(0,height,step):
        row=mask.crop((0,y,width,min(height,y+step))).getbbox()
        if row:
            for x in range(row[0]//step*step,row[2],step):
                if mask.crop((x,y,min(width,x+step),min(height,y+step))).getbbox():occupied.append([x,y,min(step,width-x),min(step,height-y)])
    for y in range(0,height+step,step):
        row=mask.crop((0,max(0,min(height-1,y)-2),width,min(height,max(0,min(height-1,y)-2)+5))).getbbox()
        sections.append([(row[0]+row[2])*.5-anchor[0],(row[2]-row[0])*.5] if row else [0,0])
    tower['shell']=dict(step=step,quads=occupied,sections=sections,
                        depth_ratio=.46875,source='Original front UV projection is preserved. Blue paint behind original support occlusion and mirrored rear depth are inferred.')
    tower['surfaces']=surfaces
    rays=[]
    for x,z in tower['radial']:
        across=(x+z)/math.sqrt(2);depth=(z-x)/math.sqrt(2);length=math.hypot(across,depth)
        rays.append((across/length,depth/length,length))
    best=(0,0,0)
    for ai in range(580,721):
        across=ai/20
        for bi in range(340,451):
            depth=bi/20
            if across*depth>best[0] and all(1/math.hypot(u/across,v/depth)<=radius for u,v,radius in rays):best=(across*depth,across,depth)
    terrace=[]
    for u,v,_ in rays:
        radius=1/math.hypot(u/best[1],v/best[2]);across=u*radius;depth=v*radius
        terrace.append([(across-depth)/math.sqrt(2),(across+depth)/math.sqrt(2)])
    tower['terrace_radial']=terrace
    tower['terrace_fit']='Smooth ellipse inside the original blocked footprint; original source apron retained. Hidden circular depth is inferred.'
    tower['roots']=roots
    tower['body_fill']=dict(mask='tower-body-occluded.png',sha256=source.sha(fill.tobytes()),
                           source='Only shaft pixels hidden by the four original support silhouettes receive adjacent original blue paint. Visible native RGB and the original tower master are unchanged.')
    tower['root_height_source']='One physical tip height inferred from the four original projected tips. Front/rear depth slopes differ; original front colors and projected silhouettes remain source-derived.'
    tower['material_source']='Visible native RGB retained on structural/garden masks and four traced supports. Occluded shaft/garden surfaces extend adjacent original paint; no new scenery or source colors.'
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_TOWER_MATERIALS four original gold roots; separate blue structure and garden paint')


def trim_support_border(mask,gold):
    # Hue helps find the outer metal edge, but it must not punch holes through
    # the support's blue/green reflections or split a complete original pose.
    box=mask.getbbox();pixels=mask.load();hue=gold.load();bounds=[]
    for y in range(box[1],box[3]):
        marks=[x for x in range(box[0],box[2]) if pixels[x,y]]
        if not marks:continue
        if not any(hue[x,y] for x in marks):continue
        left,right=marks[0],marks[-1]
        starts=[x for x in range(left,min(right+1,left+20)) if hue[x,y] and all(hue[min(right,x+k),y] for k in range(min(3,right-left+1)))]
        ends=[x for x in range(right,max(left-1,right-20),-1) if hue[x,y] and all(hue[max(left,x-k),y] for k in range(min(3,right-left+1)))]
        if starts:left=max(starts,key=lambda start:next((k for k in range(1,min(20,right-start)+1) if not hue[start+k,y]),min(20,right-start)+1))
        if ends:right=max(ends,key=lambda end:next((k for k in range(1,min(20,end-left)+1) if not hue[end-k,y]),min(20,end-left)+1))
        if left>right:left,right=marks[0],marks[-1]
        bounds.append((y,left,right))
    result=Image.new('L',mask.size);draw=ImageDraw.Draw(result)
    for i,(y,left,right) in enumerate(bounds):
        nearby=bounds[max(0,i-2):i+3]
        left=max(left,round(statistics.median(row[1] for row in nearby)))
        right=min(right,round(statistics.median(row[2] for row in nearby)))
        if left<=right:draw.line((left,y,right,y),fill=255)
    return ImageChops.multiply(result,mask)


def outline(art):
    width,height=art.size;sw=math.ceil(width/4);sh=math.ceil(height/4)
    mask=art.getchannel('A').resize((sw,sh),Image.Resampling.BOX);pixels=mask.load()
    occupied={(x,y) for y in range(sh) for x in range(sw) if pixels[x,y]>0}
    edges=[];alpha=art.getchannel('A').load()
    for x,y in sorted(occupied):
        corners=[(x*width/sw,y*height/sh),((x+1)*width/sw,y*height/sh),
                 ((x+1)*width/sw,(y+1)*height/sh),(x*width/sw,(y+1)*height/sh)]
        center=((x+.5)*width/sw,(y+.5)*height/sh)
        samples=[(xx,yy) for yy in range(math.floor(corners[0][1]),min(height,math.ceil(corners[2][1])))
                 for xx in range(math.floor(corners[0][0]),min(width,math.ceil(corners[2][0]))) if alpha[xx,yy]]
        sample=min(samples,key=lambda point:(point[0]+.5-center[0])**2+(point[1]+.5-center[1])**2)
        for side,(dx,dy) in enumerate([(0,-1),(1,0),(0,1),(-1,0)]):
            if (x+dx,y+dy) in occupied:continue
            edges.append([round(v,4) for p in [corners[side],corners[(side+1)%4],
                          (sample[0]+.5,sample[1]+.5)] for v in p])
    return edges


def profiles():
    catalog=json.loads((source.OUTPUT/'catalog.json').read_text());result={}
    for serial,g in catalog['graphics'].items():
        if g['ground'] or g['animated'] or g['family']=='void':continue
        result[serial]=outline(source.cut_image(int(g['cut_map']),int(g['cut_serial']))[0])
    (OUT/'profiles.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('ELSA_RELIEF_PROFILES',len(result),'original alpha silhouettes',sum(len(e) for e in result.values()),'edge quads')


def tower_fit(width,height,planes,top):
    cells={(138,85)};queue=deque(cells)
    while queue:
        x,y=queue.popleft()
        for cell in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if cell in cells or not(0<=cell[0]<width and 0<=cell[1]<height):continue
            if not planes[2][cell[1]*width+cell[0]]:continue
            cells.add(cell);queue.append(cell)
    center=[sum(p[axis] for p in cells)/len(cells) for axis in range(2)]
    anchor=[sum(center)*32,(center[1]-center[0])*24];radial=[]
    for i in range(128):
        angle=i*math.tau/128;across=(math.cos(angle)+math.sin(angle))/math.sqrt(2)*36
        depth=(math.sin(angle)-math.cos(angle))/math.sqrt(2)*22.5
        x=(across-depth)/math.sqrt(2);z=(across+depth)/math.sqrt(2)
        distance=math.hypot(x,z);ux=x/distance;uz=z/distance;safe=0.
        for step in range(int(distance*10)+1):
            radius=step*.1
            cell=(math.floor(center[0]+ux*radius/3+.5),math.floor(center[1]+uz*radius/3+.5))
            if cell not in cells:break
            safe=radius
        safe=max(0,safe-.65);radial.append([round(ux*safe,5),round(uz*safe,5)])
    return dict(anchor=anchor,radial=radial,height_factor=(anchor[1]-top)*.045/92.3,
                footprint_cells=sorted(cells),fit='Original connected blocked footprint; inferred depth within its boundary.')


def shore():
    width,height,planes=source.reference_map(59520);tiles={};profiles={};placements={}
    _,_,labels,_=source.components(59520)
    owned=set(json.loads((source.REPORT/'scope.json').read_text())['rooms']['59520']['components'])
    for i,serial in enumerate(planes[0]):
        if serial<1000:continue
        art,offset,_=source.cut_image(59520,serial)
        u=(i%width+i//width)*32+offset[0];v=(i//width-i%width)*24+offset[1]
        assert art.size==(64,48) and u%64==v%48==0
        tiles[(u//64,v//48)]=(art,u,v,i)
    def navy(u,v):
        tile=tiles.get((int(u//64),int(v//48)))
        if tile is None:return False
        r,g,b,a=tile[0].getpixel((int(u-tile[1]),int(v-tile[2])))
        if not(a and r<20 and g<10 and 45<=b<=65):return False
        x=u/64-v/48;y=u/64+v/48;cx=math.floor(x+.5);cy=math.floor(y+.5)
        for yy in range(max(0,cy-1),min(height,cy+2)):
            for xx in range(max(0,cx-1),min(width,cx+2)):
                if labels[yy*width+xx] in owned and abs(x-xx)<.67 and abs(y-yy)<.67:return False
        return True
    for art,u,v,i in tiles.values():
        mask=bytes(navy(u+x*4,v+y*4) for y in range(13) for x in range(17))
        if not any(mask):continue
        token=source.sha(mask)
        if token not in profiles:
            quads=[];used=set()
            for y in range(12):
                for x in range(16):
                    if (x,y) in used:continue
                    corners=[mask[y*17+x],mask[y*17+x+1],mask[(y+1)*17+x+1],mask[(y+1)*17+x]]
                    w=h=1
                    if len(set(corners))==1:
                        value=corners[0]
                        while x+w<16 and (x+w,y) not in used and all(mask[yy*17+x+w+1]==value for yy in [y,y+1]):w+=1
                        while y+h<12 and all((xx,y+h) not in used for xx in range(x,x+w)) and all(mask[(y+h+1)*17+xx]==value for xx in range(x,x+w+1)):h+=1
                    for yy in range(y,y+h):
                        for xx in range(x,x+w):used.add((xx,yy))
                    quads.append([x*4,y*4,w*4,h*4,*corners])
            profiles[token]=dict(vertices=list(mask),quads=quads)
        placements[str(i)]=token
    result=dict(placements=placements,profiles=profiles,depth=-2.1,
                source='Original navy sea pixels only; original walkable island ground and its rim stay at zero. Unreachable exterior water is not island ground.')
    print('ELSA_SHORE',len(placements),'native floor patches;',len(profiles),'shared height profiles;',sum(len(profiles[t]['quads']) for t in placements.values()),'quads')
    return result


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    catalog=json.loads((source.OUTPUT/'catalog.json').read_text())
    solid_catalog=dict(graphics={key:dict(g,page=int(g['page'])-int(catalog['page_offset']))
                                for key,g in catalog['graphics'].items() if not g['ground'] and not g['animated']})
    pages=[Image.open(source.OUTPUT.parent/name).convert('RGBA') for name in catalog['pages']]
    for i,im in enumerate(solid_pages(solid_catalog,pages)):im.save(source.OUTPUT/f'solid-{i}.png')
    catalog['solid_pages']=[f'elsa/solid-{i}.png' for i in range(len(pages))]
    (source.OUTPUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n')
    animations={}
    for graphic in catalog['graphics'].values():
        if not graphic['animated']:continue
        serial=graphic['cut'][0]
        if str(serial) in animations:continue
        _,_,_,clip=source.scenery_frame(serial)
        frames=[source.scenery_frame(serial,i)[:3] for i in range(len(clip['frames']))]
        left=min(x for a,x,y in frames);top=min(y for a,x,y in frames)
        width=max(x+a.width for a,x,y in frames)-left
        height=max(y+a.height for a,x,y in frames)-top
        columns=max(1,min(len(frames),int(math.sqrt(len(frames)*height/width))))
        columns=min(columns,8192//width);rows=math.ceil(len(frames)/columns)
        assert max(columns*width,rows*height)<=16384,(serial,width,height,len(frames))
        atlas=Image.new('RGBA',(columns*width,rows*height))
        for i,(art,x,y) in enumerate(frames):
            atlas.alpha_composite(art,(i%columns*width+x-left,i//columns*height+y-top))
        atlas.save(OUT/f'{serial}.png')
        animations[str(serial)]=dict(frames=len(frames),columns=columns,rows=rows,
            size=[width,height],origin=[left,top],duration=clip['duration'],opacity=clip['opacity'],flags=clip['flags'],
            sha256=source.sha(atlas.tobytes()),source_key=clip['key'])
    width,height,planes=source.reference_map(59520);items=[]
    for i,serial in enumerate(planes[1]):
        if serial<1000:continue
        record=source.cut_records(59520)[serial-1000]
        if record[0] not in TOWER_MASTERS:continue
        art,origin,_=source.cut_image(59520,serial)
        items.append(((i%width+i//width)*32+origin[0],(i//width-i%width)*24+origin[1],art,serial))
    left=min(x for x,y,a,s in items);top=min(y for x,y,a,s in items)
    right=max(x+a.width for x,y,a,s in items);bottom=max(y+a.height for x,y,a,s in items)
    art=Image.new('RGBA',(right-left,bottom-top))
    for x,y,im,s in sorted(items,key=lambda p:(p[1],p[0])):art.alpha_composite(im,(x-left,y-top))
    art.save(OUT/'tower.png')
    solid_pages(dict(graphics={'tower':dict(rect=[0,0,*art.size],page=0)}),[art])[0].save(OUT/'tower-solid.png')
    # The temple's visible facade is baked into the ground layer, not separate object sprites.
    facade_rect=(7104,-4800,12032,-2112)
    facade=Image.new('RGBA',(facade_rect[2]-facade_rect[0],facade_rect[3]-facade_rect[1]))
    for i,serial in enumerate(planes[0]):
        if serial<1000:continue
        im,offset,_=source.cut_image(59520,serial)
        x=(i%width+i//width)*32+offset[0];y=(i//width-i%width)*24+offset[1]
        if x+im.width<facade_rect[0] or x>=facade_rect[2] or y+im.height<facade_rect[1] or y>=facade_rect[3]:continue
        facade.alpha_composite(im,(x-facade_rect[0],y-facade_rect[1]))
    facade.save(OUT/'temple.png')
    solid_pages(dict(graphics={'temple':dict(rect=[0,0,*facade.size],page=0)}),[facade])[0].save(OUT/'temple-solid.png')
    structure=[]
    for y in range(height):
        for x in range(width):
            across=x+y;depth=x-y
            front=113.+(across-237.)*(100.-113.)/(356.-237.)
            inside=depth-front
            if not 235<=across<=361 or not 1.5<=inside<=12. or not planes[2][y*width+x]:continue
            high=18.+7.*math.sin(inside/12.*math.pi)
            spire=max(max(0.,1.-abs(across-center)/5.) for center in [237,295,356])
            high+=spire*15.
            structure.append([x,y,round(high,4)])
    visible={serial:list(source.cut_image(int(g['cut_map']),int(g['cut_serial']))[0].getbbox() or (0,0,0,0))
             for serial,g in catalog['graphics'].items() if 300795<=int(g['cut'][0])<=300804}
    result=dict(animations=animations,visible=visible,shore=shore(),temple=dict(rect=list(facade_rect),cells=structure,
        sha256=source.sha(facade.tobytes()),inferred_depth=True),tower=dict(rect=[left,top,right-left,bottom-top],
        **tower_fit(width,height,planes,top),source_pieces=sorted({s for x,y,a,s in items}),sha256=source.sha(art.tobytes())),
        limits=['The archive contains rendered art, not original meshes. Tower rear surfaces and depth are inferred from its visible circular profiles.'])
    (OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_SCENERY',len(animations),'complete original animation clips; assembled tower paint')
    prepare_tower_profile()
    prepare_tower_materials()
    prepare_return_stone()


def prepare_animation_flags():
    data=json.loads((OUT/'data.json').read_text())
    for serial,clip in data['animations'].items():
        _,_,_,native=source.scenery_frame(int(serial))
        assert clip['source_key']==native['key'] and clip['duration']==native['duration'] and clip['opacity']==native['opacity']
        clip['flags']=native['flags']
    temporary=OUT/'data.json.tmp';temporary.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');temporary.replace(OUT/'data.json')
    print('ELSA_ANIMATION_FLAGS',len(data['animations']),'native flags; source art unchanged')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--profiles-only',action='store_true')
    parser.add_argument('--shore-only',action='store_true')
    parser.add_argument('--solids-only',action='store_true')
    parser.add_argument('--return-stone-only',action='store_true')
    parser.add_argument('--tower-fit-only',action='store_true')
    parser.add_argument('--tower-materials-only',action='store_true')
    parser.add_argument('--animation-flags-only',action='store_true')
    args=parser.parse_args()
    if args.animation_flags_only:prepare_animation_flags()
    elif args.tower_materials_only:prepare_tower_materials()
    elif args.tower_fit_only:prepare_tower_profile()
    elif args.return_stone_only:prepare_return_stone()
    elif args.solids_only:prepare_solids()
    elif args.shore_only:
        data=json.loads((OUT/'data.json').read_text());data['shore']=shore()
        (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    else:
        if not args.profiles_only:build()
        profiles()

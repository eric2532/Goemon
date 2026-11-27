"""Source palettes and branch centerlines for the remaining continental trees.

The masters, map anchors and original images remain untouched. Fine twigs/moss
retain native alpha; compatible whole trees retain their existing mesh/UVs.
"""
import hashlib
from collections import deque
from PIL import Image,ImageFilter,ImageChops

SEASONAL={**{1233070+i:'crossgate_flora/'+('cg_silverleaf' if i in (0,2,5) else 'cg_woodland') for i in range(10)},
          1233210:'crossgate_flora/cg_evergreen'}
BARE=list(range(1233080,1233103))+list(range(1233211,1233216))
NEIGHBORS=[(0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1)]


def records():
    result={serial:dict(kind='native_canopy_tree',rejected_master=asset,
        inference='Whole Meadow masters were reviewed but obscured these sparse source branches/fruit silhouettes. Existing timber parts follow native woody limbs; original leaf/fruit alpha forms crossed thin crowns. Unseen limb sections and crown depth are inferred.') for serial,asset in SEASONAL.items()}
    result.update({serial:dict(kind='native_branch_tree',
        inference='Original branch topology and native fine-twig/moss alpha are retained. Existing round timber rods give thick observed limbs depth; their hidden circular sections and small shared depth curve are inferred.') for serial in BARE})
    return result


def leaf_colors(image):
    return [p[:3] for y in range(round(image.height*.78)) for x in range(image.width)
            if (p:=image.getpixel((x,y)))[3]>=128 and max(p[:3])>65 and p[1]>p[2]*1.10 and p[0]>p[2]*1.04]


def palette_transfer(master,source):
    colors=leaf_colors(source)
    if not colors:raise ValueError('Native tree has no foliage palette')
    luminance=lambda p:round(.2126*p[0]+.7152*p[1]+.0722*p[2])
    colors.sort(key=luminance)
    samples=sorted(luminance(p) for p in master.getdata() if p[3]>=128)
    counts=[0]*256
    for value in samples:counts[value]+=1
    total=max(1,len(samples));running=0;palette=[]
    for value in counts:
        running+=value;palette.append(colors[min(len(colors)-1,round((running-value*.5)/total*(len(colors)-1)))])
    result=master.copy()
    result.putdata([(*palette[luminance(p)],p[3]) if p[3] else p for p in master.getdata()])
    return result


def simplify(points,tolerance=1.25):
    if len(points)<3:return points
    a,b=points[0],points[-1];dx=b[0]-a[0];dy=b[1]-a[1];span=dx*dx+dy*dy
    def distance(p):
        t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/span)) if span else 0
        return (p[0]-a[0]-t*dx)**2+(p[1]-a[1]-t*dy)**2
    index=max(range(1,len(points)-1),key=lambda i:distance(points[i]))
    if distance(points[index])<=tolerance*tolerance:return [a,b]
    return simplify(points[:index+1],tolerance)[:-1]+simplify(points[index:],tolerance)


def branch_centerlines(clean,min_radius=3):
    w,h=clean.size
    wood=Image.frombytes('L',clean.size,bytes(255 if a>=128 and max(r,g,b)>45 and max(r,g,b)-min(r,g,b)>4 and not(g>r and g>b) else 0 for r,g,b,a in clean.getdata()))
    # Close single-pixel paint gaps only for the inferred rod centerline, never the visible art.
    closed=wood.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3));mask=set((x,y) for y in range(h) for x in range(w) if closed.getpixel((x,y)))
    if not mask:raise ValueError('Native bare tree has no wood pixels')
    # Native-width distance field; rods use only the thicker source limbs.
    distance={p:0 for p in mask};queue=deque()
    for x,y in mask:
        if any((x+dx,y+dy) not in mask for dx,dy in NEIGHBORS):distance[x,y]=1;queue.append((x,y))
    while queue:
        p=queue.popleft()
        for dx,dy in NEIGHBORS:
            q=(p[0]+dx,p[1]+dy)
            if q in mask and distance[q]==0:distance[q]=distance[p]+1;queue.append(q)
    thin=set(mask);changed=True
    while changed:
        changed=False
        for phase in (0,1):
            remove=[]
            for x,y in thin:
                n=[(x+dx,y+dy) in thin for dx,dy in NEIGHBORS];count=sum(n)
                if count<2 or count>6:continue
                if sum(not n[i] and n[(i+1)%8] for i in range(8))!=1:continue
                if phase==0 and (n[0] and n[2] and n[4] or n[2] and n[4] and n[6]):continue
                if phase==1 and (n[0] and n[2] and n[6] or n[0] and n[4] and n[6]):continue
                remove.append((x,y))
            if remove:thin.difference_update(remove);changed=True
    adjacent={p:[(p[0]+dx,p[1]+dy) for dx,dy in NEIGHBORS if (p[0]+dx,p[1]+dy) in thin] for p in thin}
    nodes={p for p,n in adjacent.items() if len(n)!=2};seen=set();paths=[]
    for start in sorted(nodes):
        for following in adjacent[start]:
            edge=tuple(sorted((start,following)))
            if edge in seen:continue
            seen.add(edge);path=[start,following];previous,current=start,following
            while current not in nodes:
                following=next(p for p in adjacent[current] if p!=previous);seen.add(tuple(sorted((current,following))))
                path.append(following);previous,current=current,following
            if len(path)<3 or max(distance[p] for p in path)<min_radius:continue
            paths.append([[x+.5,y+.5,float(distance[x,y])] for x,y in simplify(path)])
    colors=[clean.getpixel(p)[:3] for p in mask if wood.getpixel(p)]
    tone=[round(sum(p[c] for p in colors)/len(colors),3) for c in range(3)]
    return paths,tone


def bright_details(clean):
    pixels={(x,y) for y in range(round(clean.height*.78)) for x in range(clean.width)
            if (p:=clean.getpixel((x,y)))[3]>=128 and p[0]>100 and p[0]>p[1]*1.25 and p[0]>p[2]*1.45}
    boxes=[];mask=Image.new('L',clean.size)
    while pixels:
        start=pixels.pop();component=[start];queue=[start]
        while queue:
            x,y=queue.pop()
            for dx,dy in NEIGHBORS:
                q=(x+dx,y+dy)
                if q in pixels:pixels.remove(q);queue.append(q);component.append(q)
        x0=min(x for x,y in component);x1=max(x for x,y in component)+1;y0=min(y for x,y in component);y1=max(y for x,y in component)+1
        if len(component)<3 or max(x1-x0,y1-y0)>12:continue
        boxes.append([x0,y0,x1,y1])
        for p in component:mask.putpixel(p,255)
    detail=clean.copy();detail.putalpha(ImageChops.multiply(clean.getchannel('A'),mask))
    return detail,boxes


def prepare(spec,graphic,clean,out,root):
    serial=int(spec['graphic_id']);token=str(serial)
    spec['ground_offset']=float(graphic['origin'][1])+clean.getbbox()[3]-2
    if spec['kind']=='native_canopy_tree':
        wood=clean.copy();leaves=clean.copy();width,height=clean.size
        leaf_pixels=[(x,y) for y in range(round(height*.82)) for x in range(width)
            if (p:=clean.getpixel((x,y)))[3]>=128 and p[1]>p[2]*1.12 and p[0]>p[2]*1.05 and p[1]>p[0]*.70]
        crown_bottom=max(y for x,y in leaf_pixels)+2;top=max(height*.45,crown_bottom-height*.10)/height
        for y in range(height):
            for x in range(width):
                r,g,b,a=clean.getpixel((x,y))
                if not(y>=height*top and r>g*1.12 and r>b*1.25):wood.putpixel((x,y),(r,g,b,0))
                if y>crown_bottom:leaves.putpixel((x,y),(r,g,b,0))
        lines,tone=branch_centerlines(wood,1)
        if not lines:raise ValueError(f'No source trunk structure: {serial}')
        lines=[[[x,y,min(radius,3.5 if y<height*.70 else 6.)] for x,y,radius in line] for line in lines]
        spec.update(branches=lines,bark_color=tone,branch_depth=.65,branch_segments=sum(len(line)-1 for line in lines),crown_junction=[round(sum(x for x,y in leaf_pixels)/len(leaf_pixels),2),crown_bottom],removed_neutral_shadow_pixels=0)
        wood.save(out/f'{token}-branches.png');leaves.save(out/f'{token}-foliage.png')
        return
    if spec['kind']=='native_branch_tree':
        lines,tone=branch_centerlines(clean,float(spec.get("branch_min_radius",3)))
        if not lines:raise ValueError(f'No thick native branch structure: {serial}')
        spec.update(branches=lines,bark_color=tone,branch_depth=.45,branch_segments=sum(len(line)-1 for line in lines))
        fine=clean.copy();removed=0
        for y in range(fine.height):
            for x in range(fine.width):
                r,g,b,a=fine.getpixel((x,y))
                if a and max(r,g,b)<=100 and max(r,g,b)-min(r,g,b)<3:fine.putpixel((x,y),(r,g,b,0));removed+=1
        spec['removed_neutral_shadow_pixels']=removed;fine.save(out/f'{token}-branches.png')
    else:
        name=spec['asset'].split('/')[-1]
        path=root/'assets/models/environments/wind_meadow/crossgate_flora'/f'{name}_{name}.png'
        master=Image.open(path).convert('RGBA');spec['palette_master_rgba_sha256']=hashlib.sha256(master.tobytes()).hexdigest()
        spec['palette_master']=str(path.relative_to(root));palette_transfer(master,clean).save(out/f'{token}-leaves.png')
        detail,boxes=bright_details(clean);detail.save(out/f'{token}-details.png');spec['detail_boxes']=boxes

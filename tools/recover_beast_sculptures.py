"""Prepare native armor paint and bounded solid relief, without changing the client archive."""
import argparse
import base64
import hashlib
import json
import math
import struct
from pathlib import Path
import sys
import zlib
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from prepare_arena_carvings import shallow_depth
from recover_falan_architecture import opaque_paint

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/original_crossgate'
GEOMETRY=ROOT/'build/Other Files/Asset Toolkit/Jenova Beast Recovery/castle-visibility-geometry.json'
# Native body rectangles exclude the separate lance, not any part of the suit.
ARMOR={16193:((47,75,65,108),183,170),16196:((0,137,52,108),245,233),16194:((0,75,65,108),183,170),16195:((0,137,52,108),245,233)}
# The two front views see the west-facing suit from either side; rear views see its east side.
VIEWS={16193:0,16194:math.pi/2,16195:-math.pi/2,16196:math.pi}
PLATES={
 3:[(67,90),(101,90),(102,116),(67,116)],
 2:[(79,73),(97,73),(97,94),(79,94)],
 5:[(95,108),(110,115),(112,130),(98,127)],
 6:[(65,111),(76,116),(69,129),(56,130),(55,122)],
 7:[(46,121),(58,120),(64,134),(49,138)],
 8:[(99,126),(111,129),(112,156),(102,156),(96,145)],
 9:[(71,134),(102,133),(108,150),(93,160),(69,154)],
 10:[(69,149),(88,152),(88,167),(77,178),(62,177),(61,167)],
 11:[(87,151),(105,153),(104,167),(109,173),(100,183),(80,184),(81,170)],
}
OFFSETS={1:.35,2:0,3:0,4:0,5:-.1,6:.15,7:.35,8:-.05,9:.1,10:-.1,11:.15}
BANNERS=[{'part':'banner_left','quad':[(331,451),(349,438),(349,545),(331,558)],'tile':(0,128)},
         {'part':'banner','quad':[(460,363),(479,352),(479,461),(460,472)],'tile':(128,128)}]
COLUMNS=[{'foot':(365,527),'top':(365,449),'quad':[(356,454),(366,447),(366,524),(356,531)],
          'mask':[(351,455),(366,444),(376,447),(376,455),(369,462),(369,516),(377,514),(377,525),(360,536),(350,532)]},
         {'foot':(410,497),'top':(410,419),'quad':[(404,424),(414,417),(414,494),(404,501)],
          'mask':[(399,421),(414,411),(423,416),(423,424),(418,428),(418,486),(426,486),(426,497),(411,506),(399,501)]}]
CANOPY=[{'height':9.1,'pixels':[(390,421),(460,368),(414,338),(344,391)]},
        {'height':10.8,'pixels':[(390,402),(458,353),(413,323),(345,372)]},
        {'height':13.0,'pixels':[(390,370),(443,333),(402,306),(349,343)]},
        {'height':16.4,'pixels':[(390,338),(450,295),(405,265),(345,308)]}]
HALL=[{'height':25.08,'pixels':[(313,330),(383,281),(345,255),(275,304)]},
      {'height':30.38,'pixels':[(313,277),(383,228),(345,202),(275,251)]},
      {'height':33.08,'pixels':[(315,251),(385,201),(347,176),(277,226)]},
      {'height':35.7,'pixels':[(315,222),(376,180),(338,155),(277,197)]},
      {'height':39.4,'pixels':[(315,185),(376,143),(338,118),(277,160)]}]
CARVINGS={
 'keep_left':([(204,81),(253,113),(253,210),(204,178)],(64,128),.30),
 'keep_right':([(280,113),(320,85),(320,182),(280,210)],(64,128),.30),
 'keep_corner':([(254,108),(280,108),(280,210),(254,210)],(32,128),.22),
 'frieze_left':([(204,60),(253,92),(253,112),(204,80)],(112,32),.25),
 'frieze_right':([(280,92),(320,64),(320,84),(280,112)],(112,32),.25),
 'pier_scroll':([(128,350),(151,334),(151,397),(128,413)],(48,96),.18),
 'shield':([(36,337),(54,349),(54,370),(36,358)],(48,64),.10),
 'hall':([(313,277),(383,228),(383,281),(313,330)],(112,96),.25),
}

def castle_carvings(castle):
    atlas=Image.new('RGBA',(512,256));depth=Image.new('L',atlas.size);rows=[];proof={}
    for i,(name,(quad,size,rise)) in enumerate(CARVINGS.items()):
        ul,ur,lr,ll=quad
        paint=castle.transform(size,Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
        at=(i%4*128+8,i//4*144+8)
        atlas.paste(paint,at);depth.paste(shallow_depth(paint.convert('L')),at)
        rows.append(f' "{name}":[Rect2i({at[0]},{at[1]},{size[0]},{size[1]}),{rise}],')
        proof[name]={'quad':quad,'rect':[*at,*size],'rise':rise,'rgba_sha256':hashlib.sha256(paint.tobytes()).hexdigest()}
    script='\n'.join(['extends RefCounted','## Generated source-fitted castle carving surfaces.',
        'const ATLAS=preload("res://assets/maps/original_crossgate/beast-castle-carvings.png")',
        'const DEPTH=preload("res://assets/maps/original_crossgate/beast-castle-carvings-depth.png")',
        'const FEATURES={',*rows,'}'])+'\n'
    return atlas,depth,script,proof

def armor_core(images,lookup,labels):
    size=(64,116,64);step=.1;origin=(-3.2,0,-3.2);occupied=set()
    vertical=math.sqrt(2*((32/3)**2-64));views=[]
    for serial,angle in VIEWS.items():
        g=lookup[serial];im=images[serial];views.append((math.cos(angle),math.sin(angle),g['x'],g['y'],im.width,im.height,im.getchannel('A').tobytes()))
    for y in range(size[1]):
        py=(y+.5)*step
        for z in range(size[2]):
            pz=origin[2]+(z+.5)*step
            for x in range(size[0]):
                px=origin[0]+(x+.5)*step
                for c,s,ox,oy,w,h,alpha in views:
                    xx=c*px+s*pz;zz=-s*px+c*pz
                    u=math.floor((xx+zz)*32/3-ox);v=math.floor((zz-xx)*8-py*vertical-oy)
                    if not (0<=u<w and 0<=v<h and alpha[v*w+u]):break
                else:occupied.add((x,y,z))
    assert len(occupied)>3000,'Four native armor views must enclose a body'
    # Isolated source-pixel flecks do not become separate blocks floating around the suit.
    directions=[(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]
    remaining=occupied.copy();largest=set()
    while remaining:
        seed=remaining.pop();component={seed};todo=[seed]
        for x,y,z in todo:
            for dx,dy,dz in directions:
                p=(x+dx,y+dy,z+dz)
                if p in remaining:remaining.remove(p);component.add(p);todo.append(p)
        if len(component)>len(largest):largest=component
    faces=bytearray()
    for x,y,z in sorted(largest):
        for face,(dx,dy,dz) in enumerate(directions):
            if (x+dx,y+dy,z+dz) not in largest:faces.extend((x,y,z,face))
    proof={'size':size,'step':step,'origin':origin,'voxels':len(largest),'faces':len(faces)//4,'bytes':len(faces),'views':VIEWS,
           'method':'Largest connected intersection of all four original armor silhouettes; source-pixel relief retains the selected lance, crest and pose.'}
    for name,part,neighbors in [('crest',2,(3,)),('grip',7,(4,6,8))]:
        proof[name+'_anchors']={}
        for serial,angle in VIEWS.items():
            mask=labels[serial];roots=set();g=lookup[serial];offsets=[]
            for y in range(mask.height):
                for x in range(mask.width):
                    if mask.getpixel((x,y))!=part:continue
                    for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                        u,v=x+dx,y+dy
                        if 0<=u<mask.width and 0<=v<mask.height and mask.getpixel((u,v)) in neighbors:roots.add((u,v))
            for x,y,z in largest:
                px=origin[0]+(x+.5)*step;py=(y+.5)*step;pz=origin[2]+(z+.5)*step
                xx=math.cos(angle)*px+math.sin(angle)*pz;zz=-math.sin(angle)*px+math.cos(angle)*pz
                u=(xx+zz)*32/3-g['x'];v=(zz-xx)*8-py*vertical-g['y']
                if (math.floor(u),math.floor(v)) in roots:
                    offsets.append((py-(ARMOR[serial][1]-v)/vertical)/(math.sqrt(2)*8/vertical))
            assert offsets,f'Native {name} {serial} must join its adjacent plate inside the recovered solid'
            offsets.sort();proof[name+'_anchors'][serial]={'offset':offsets[len(offsets)//2],'samples':len(offsets)}
    return base64.b64encode(zlib.compress(faces,9)).decode(),proof

def castle_visibility(castle):
    width,height=castle.size;image=Image.new('RGB',castle.size)
    if not GEOMETRY.exists():return image,{'ready':False}
    geometry=json.loads(GEOMETRY.read_text());points=geometry['triangles']
    horizontal=32/3;vertical=math.sqrt(2*(horizontal**2-64))
    direction=(-1,1.603567,1);length=math.sqrt(sum(v*v for v in direction));direction=tuple(v/length for v in direction)
    distance=lambda p:sum(a*b for a,b in zip(p,direction))
    values=[distance(p) for p in points];minimum=min(values)-1;span=max(values)-minimum+1
    buffer=[-math.inf]*(width*height);ox,oy=geometry['origin']
    for i in range(0,len(points),3):
        world=points[i:i+3];projected=[((p[0]+p[2])*horizontal+ox,(p[2]-p[0])*8-p[1]*vertical+oy) for p in world]
        a,b,c=projected
        area=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
        if area<=1e-8:continue
        left=max(0,math.floor(min(p[0] for p in projected)));right=min(width-1,math.ceil(max(p[0] for p in projected)))
        top=max(0,math.floor(min(p[1] for p in projected)));bottom=min(height-1,math.ceil(max(p[1] for p in projected)))
        ax=(b[1]-c[1])/area;ay=(c[0]-b[0])/area;ac=(b[0]*c[1]-c[0]*b[1])/area
        bx=(c[1]-a[1])/area;by=(a[0]-c[0])/area;bc=(c[0]*a[1]-a[0]*c[1])/area
        da,db,dc=values[i:i+3]
        for y in range(top,bottom+1):
            aa=ay*(y+.5)+ac;bb=by*(y+.5)+bc
            for x in range(left,right+1):
                u=ax*(x+.5)+aa;v=bx*(x+.5)+bb;w=1-u-v
                if min(u,v,w)<-1e-6:continue
                index=y*width+x;z=u*da+v*db+w*dc
                if z>buffer[index]:buffer[index]=z
    covered=0
    for i,z in enumerate(buffer):
        if not math.isfinite(z):continue
        value=round((z-minimum)/span*65535);image.putpixel((i%width,i//width),(value>>8,value&255,0));covered+=1
    assert covered>width*height*.20,'The source view must contain the solid castle'
    return image,{'ready':True,'mesh_sha256':geometry['mesh_sha256'],'source_rgba_sha256':hashlib.sha256(castle.tobytes()).hexdigest(),
                  'depth_min':minimum,'depth_span':span,'covered_pixels':covered,'bias_metres':.20}

def prepare(source):
    sys.dont_write_bytecode=True
    sys.path.insert(0,str(source/'tools'))
    import cg_library as lib
    atlas=Image.new('RGBA',(256,1024));depth=Image.new('L',atlas.size)
    native=atlas.copy();solid=atlas.copy();parts=depth.copy();records={};rows=[];images={};label_images={};lances={};lookup=lib.serial_index()
    for i,(serial,(body,foot,shadow_start)) in enumerate(ARMOR.items()):
        g=lookup[serial];original=lib.image_from_record(g['pack'],g['row'])
        paint=original.copy();removed=0
        for y in range(shadow_start,paint.height):
            for x in range(paint.width):
                if paint.getpixel((x,y))==(71,71,71,255):
                    paint.putpixel((x,y),(71,71,71,0));removed+=1
        images[serial]=paint
        alpha=paint.getchannel('A');labels=alpha.point(lambda a:1 if a else 0)
        shaft=[(y,sum(xs)/len(xs)) for y in range(body[1]//2) if (xs:=[x for x in range(paint.width) if alpha.getpixel((x,y))])]
        mean_y=sum(y for y,x in shaft)/len(shaft);mean_x=sum(x for y,x in shaft)/len(shaft)
        slope=sum((y-mean_y)*(x-mean_x) for y,x in shaft)/sum((y-mean_y)**2 for y,x in shaft)
        intercept=mean_x-slope*mean_y
        # Body edges and boot soles belong to the solid suit, not floating lance relief.
        for y in range(body[1],paint.height):
            for x in range(paint.width):
                if alpha.getpixel((x,y)) and abs(x-(intercept+slope*y))>2:labels.putpixel((x,y),4)
        for part,polygon in PLATES.items():
            if serial==16196:polygon=[((1-(x-47)/65)*52,y-75+137) for x,y in polygon]
            elif serial==16194:polygon=[(112-x,y) for x,y in polygon]
            elif serial==16195:polygon=[((x-47)/65*52,y-75+137) for x,y in polygon]
            region=Image.new('L',paint.size);ImageDraw.Draw(region).polygon(polygon,fill=255)
            labels.paste(part,mask=ImageChops.multiply(region,alpha))
        remaining={(x,y) for y in range(paint.height) for x in range(paint.width) if labels.getpixel((x,y))==1}
        while remaining:
            seed=remaining.pop();component=[seed]
            for x,y in component:
                for dx,dy in [(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)]:
                    p=(x+dx,y+dy)
                    if p in remaining:remaining.remove(p);component.append(p)
            # Tiny isolated flecks near the boots are suit paint, not a continuation of the shaft.
            low=min(y for x,y in component);high=max(y for x,y in component)
            if low>=body[1] and high-low<7:
                for p in component:labels.putpixel(p,4)
        label_images[serial]=labels
        distance=Image.new('L',paint.size)
        for part in OFFSETS:
            erosion=labels.point(lambda value:255 if value==part else 0)
            for radius in range(1,33):
                if erosion.getbbox() is None:break
                distance.paste(radius,mask=erosion)
                erosion=erosion.filter(ImageFilter.MinFilter(3))
        detail=shallow_depth(paint.convert('L'))
        relief=Image.new('L',paint.size)
        for y in range(paint.height):
            for x in range(paint.width):
                # Silhouette distance supplies rounded volume; pale strokes retain small plate seams.
                metres=max(0,distance.getpixel((x,y))-.5)*3/(32*math.sqrt(2))*1.2
                metres+=detail.getpixel((x,y))/255*.025 if alpha.getpixel((x,y)) else 0
                relief.putpixel((x,y),min(255,round(metres/1.5*255)))
        at=(2,i*256+2);rect=[*at,*paint.size]
        native.paste(original,at);atlas.paste(paint,at);depth.paste(relief,at);solid.paste(opaque_paint(paint),at);parts.paste(labels,at)
        other={16193:16196,16196:16193,16194:16195,16195:16194}[serial]
        # Keep the established full-lance height while preserving the native suit proportions uniformly.
        visible=min(1,paint.width/64)
        height=(-g['y']-24*visible)*.045
        rows.append(f' {serial}:[Rect2i({",".join(map(str,rect))}),Vector2({g["x"]},{g["y"]}),Rect2i({",".join(map(str,body))}),{foot},{other},{height:.9f}],')
        records[serial]={'pack':g['pack'],'row':g['row'],'rgba_sha256':hashlib.sha256(original.tobytes()).hexdigest(),
                         'rect':rect,'origin':[g['x'],g['y']],'body':body,'foot':foot,'opposite':other,
                         'removed_ground_shadow_pixels':removed,'maximum_half_depth_metres':1.5,'height':height}
        records[serial]['plates']={'polygons_in_front_view':PLATES,'depth_offsets_metres':OFFSETS}
        records[serial]['lance_line']={'x_at_zero':intercept,'x_per_y':slope,'body_start_y':body[1]}
        end=max(y for y in range(paint.height) for x in range(paint.width) if labels.getpixel((x,y))==1)
        widths=sorted(sum(bool(alpha.getpixel((x,y))) for x in range(paint.width)) for y,x in shaft)
        lances[serial]={'top':(intercept,0),'bottom':(intercept+slope*end,end),
                        'paint_top':(intercept+slope*5,5),'paint_bottom':(intercept+slope*(body[1]//2),body[1]//2),
                        'radius':widths[len(widths)//2]*.5/(math.sqrt(2)*32/3)}
        assert removed>0 and relief.getextrema()[1]>20
        assert all(a[:3]==b[:3] for a,b in zip(original.getdata(),paint.getdata()))
    data='\n'.join(['extends RefCounted','## Generated by tools/recover_beast_sculptures.py; original pixels and rounded silhouette relief.',
        'const ATLAS=preload("res://assets/maps/original_crossgate/beast-sculptures.png")',
        'const SOLID=preload("res://assets/maps/original_crossgate/beast-sculptures-solid.png")',
        'const DEPTH=preload("res://assets/maps/original_crossgate/beast-sculptures-depth.png")','const ARMOR={',*rows,'}'])+'\n'
    data+='const PARTS=preload("res://assets/maps/original_crossgate/beast-sculptures-parts.png")\nconst OFFSETS='+str(OFFSETS)+'\n'
    data+='const LANCES='+json.dumps(lances)+'\n'
    core,core_proof=armor_core(images,lookup,label_images)
    data+='const CORE_FACES="'+core+'"\nconst CORE='+json.dumps(core_proof)+'\n'
    castle=Image.open(OUT/'beast-castle.png').convert('RGBA')
    carving_atlas,carving_depth,carving_script,carving_proof=castle_carvings(castle)
    columns=Image.new('RGBA',(256,256))
    for i,column in enumerate(COLUMNS):
        ul,ur,lr,ll=column['quad']
        columns.paste(castle.transform((128,256),Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC),(i*128,0))
    data+='const CASTLE_COLUMNS='+json.dumps(COLUMNS)+'\n'
    data+='const CASTLE_CANOPY='+json.dumps(CANOPY)+'\n'
    data+='const CASTLE_HALL='+json.dumps(HALL)+'\n'
    door=castle.transform((96,256),Image.Transform.QUAD,(375,450,375,516,399,498,399,432),Image.Resampling.BICUBIC)
    assert door.getchannel('A').getextrema()==(255,255),'The recovered door leaf must remain opaque'
    surfaces=Image.open(OUT/'beast-castle-surfaces.png').convert('RGBA')
    surfaces.paste(surfaces.crop((0,0,128,128)),(128,0))
    # A blue roof slope is a complete surface, not the old thin window-like crop.
    blue=castle.transform((111,111),Image.Transform.QUAD,(390,370,390,402,458,353,443,333),Image.Resampling.BICUBIC)
    padded=blue.resize((128,128),Image.Resampling.NEAREST);padded.paste(blue,(8,8));surfaces.paste(padded,(256,0))
    for tile,quad in [((0,256),[(116,299),(129,308),(129,329),(116,320)]),
                      ((128,256),[(28,440),(49,454),(49,472),(28,458)])]:
        ul,ur,lr,ll=quad
        patch=castle.transform((111,111),Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
        padded=patch.resize((128,128),Image.Resampling.NEAREST);padded.paste(patch,(8,8));surfaces.paste(padded,tile)
    # The lower half of the old window patch contains a foreground buttress, not window paint.
    window=castle.transform((111,111),Image.Transform.QUAD,(201,77,201,115,213,123,213,85),Image.Resampling.BICUBIC)
    padded=window.resize((128,128),Image.Resampling.NEAREST);padded.paste(window,(8,8))
    surfaces.paste(padded,(256,128))
    for banner in BANNERS:
        ul,ur,lr,ll=banner['quad']
        patch=castle.transform((111,111),Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
        padded=patch.resize((128,128),Image.Resampling.NEAREST);padded.paste(patch,(8,8));surfaces.paste(padded,banner['tile'])
    data+='const CASTLE_BANNERS=['+','.join('{"part":"'+b['part']+'","tile":Vector2'+str(b['tile'])+',"quad":['+','.join('Vector2'+str(p) for p in b['quad'])+']}' for b in BANNERS)+']\n'
    catalog=json.loads((OUT/'catalog.json').read_text());row=catalog['maps']['BlueCrossgate/map/0/400.dat']
    raw=zlib.decompress(base64.b64decode(row.get('restored_raw',row['raw'])))
    w,h=struct.unpack_from('<II',raw,12);floor=struct.unpack_from('<'+str(w*h)+'H',raw,20)
    foundation=[(i%w-135,i//w-333) for i,graphic in enumerate(floor) if 1600<=graphic<=1692]
    assert len(foundation)==70
    data+='const CASTLE_FOUNDATION=['+','.join(f'Vector2i({x},{z})' for x,z in foundation)+']\n'
    mask=Image.new('RGB',castle.size);mask.paste(castle.getchannel('A'))
    channels=list(mask.split());semantic=ImageDraw.Draw(channels[1])
    for banner in BANNERS:semantic.polygon(banner['quad'],fill=0)
    for column in COLUMNS:semantic.polygon(column['mask'],fill=0)
    mask=Image.merge('RGB',channels)
    visibility,proof=castle_visibility(castle)
    data+='const CASTLE_DEPTH=preload("res://assets/maps/original_crossgate/beast-castle-visibility.png")\nconst CASTLE_VISIBILITY='+json.dumps(proof)+'\n'
    return {'beast-sculptures.png':atlas,'beast-sculptures-native.png':native,'beast-sculptures-solid.png':solid,'beast-sculptures-depth.png':depth,'beast-sculptures-parts.png':parts,'beast-castle-mask.png':mask,'beast-castle-visibility.png':visibility,'beast-castle-sculpture-surfaces.png':surfaces,'beast-castle-door.png':door,'beast-castle-columns.png':columns,'beast-castle-carvings.png':carving_atlas,'beast-castle-carvings-depth.png':carving_depth},data,records,proof,core_proof,carving_script,carving_proof

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');parser.add_argument('--check',action='store_true')
    args=parser.parse_args();images,data,records,proof,core,carving_script,carving_proof=prepare(args.source.resolve())
    if args.check:
        for name,image in images.items():
            with Image.open(OUT/name) as actual:assert actual.tobytes()==image.tobytes(),name
        assert (OUT/'beast-sculptures.gd').read_text()==data
        assert json.loads((OUT/'beast-sculptures.json').read_text())==json.loads(json.dumps(records))
        assert json.loads((OUT/'beast-castle-visibility.json').read_text())==proof
        assert json.loads((OUT/'beast-sculptures-core.json').read_text())==json.loads(json.dumps(core))
        assert (OUT/'beast-castle-carvings.gd').read_text()==carving_script
        assert json.loads((OUT/'beast-castle-carvings.json').read_text())==json.loads(json.dumps(carving_proof))
        print('PASS: native armor pixels, curled crests, lance silhouettes and rounded relief reproduce')
    else:
        for name,image in images.items():image.save(OUT/name,optimize=True)
        (OUT/'beast-sculptures.gd').write_text(data)
        (OUT/'beast-sculptures.json').write_text(json.dumps(records,indent=2)+'\n')
        (OUT/'beast-castle-visibility.json').write_text(json.dumps(proof,indent=2)+'\n')
        (OUT/'beast-sculptures-core.json').write_text(json.dumps(core,indent=2)+'\n')
        (OUT/'beast-castle-carvings.gd').write_text(carving_script)
        (OUT/'beast-castle-carvings.json').write_text(json.dumps(carving_proof,indent=2)+'\n')
        print('Prepared four original armor views, solid body and castle paint; client pixels preserved')

if __name__=='__main__':main()

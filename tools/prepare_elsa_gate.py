"""Prepare the arrival gate's original foreground and lower background paint."""
import json
import statistics
from PIL import Image, ImageDraw
import recover_elsa_island as source
from prepare_elsa_scenery import solid_pages, outline

OUT=source.ROOT/'assets/maps/falan/elsa/scenery/gate'
RECT=(7072,-1056,7488,-320)


def native_layers(members,rect,ident=59520):
    left,top,right,bottom=rect
    foreground=Image.new('RGBA',(right-left,bottom-top));background=Image.new('RGBA',foreground.size)
    width,height,planes=source.reference_map(ident)
    member_cells={tuple(c) for p in members for c in p['cells']}
    for layer in range(2):
        for i,serial in enumerate(planes[layer]):
            if serial<1000 or layer==1 and (i%width,i//width) not in member_cells:continue
            if source.cut_records(ident)[serial-1000][4:6]==(0,0):continue
            art,origin,_=source.cut_image(ident,serial)
            u=(i%width+i//width)*32+origin[0]-left;v=(i//width-i%width)*24+origin[1]-top
            if u+art.width<=0 or v+art.height<=0 or u>=foreground.width or v>=foreground.height:continue
            (background if layer==0 else foreground).alpha_composite(art,(u,v))
    return foreground,background


def prepare_gate(members,rect,feet,folder='',panels=(),full_background=False):
    left,top,right,bottom=rect
    foreground,background=native_layers(members,rect)
    member_cells={tuple(c) for p in members for c in p['cells']}
    paint=background.copy() if full_background else Image.new('RGBA',foreground.size)
    paint.alpha_composite(foreground);a=paint.load();bg=background.load()
    for x,y in feet:
        u=(x+y)*32-left;v=(y-x)*24-top
        for py in range(max(0,int(v-80)),min(paint.height,int(v+35)+1)):
            for px in range(max(0,int(u-42)),min(paint.width,int(u+42)+1)):
                r,g,b,alpha=bg[px,py]
                if a[px,py][3]==0 and alpha and abs(r-g)<35 and abs(g-b)<70:
                    a[px,py]=(r,g,b,alpha)
    target=OUT/folder;target.mkdir(parents=True,exist_ok=True)
    foreground.save(target/'foreground.png');paint.save(target/'paint.png')
    solid_pages(dict(graphics={'gate':dict(rect=[0,0,*paint.size],page=0)}),[paint])[0].save(target/'solid.png')
    fitted=[]
    for native_rect in panels:
        x,y,w,h=native_rect;local=(int(x-left),int(y-top),int(x-left+w),int(y-top+h));art=foreground.crop(local);alpha=art.getchannel('A');pixels=alpha.load();samples=[]
        for col in range(w):
            rows=[row for row in range(h) if pixels[col,row]]
            if rows:samples.append((col,max(rows)+1))
        slopes=[(b[1]-a[1])/(b[0]-a[0]) for a in samples[::4] for b in samples[::4] if b[0]-a[0]>=w*.4]
        if not slopes:continue
        slope=statistics.median(slopes);base=statistics.median(row-slope*col for col,row in samples)
        fitted.append(dict(rect=[local[0],local[1],w,h],origin=[x,y],foot=[slope,y+base-slope*x],edges=outline(art)))
    result=dict(rect=list(rect),feet=feet,members=members,folder=folder,panels=fitted,
                foreground_sha256=source.sha(foreground.tobytes()),paint_sha256=source.sha(paint.tobytes()),
                limits=['Mesh depth is inferred. Upper art is native foreground; the two lower cylinder bases also use native background paint.'])
    heights=[];pixels=foreground.load()
    for x,y in feet:
        u=(x+y)*32-left;v=(y-x)*24-top
        pole=[yy for yy in range(foreground.height) for xx in range(max(0,int(u-6)),min(foreground.width,int(u+7))) if pixels[xx,yy][3]]
        roof=[yy for yy in range(foreground.height) if sum(pixels[xx,yy][3]>0 and pixels[xx,yy][2]>pixels[xx,yy][0]*1.25 and pixels[xx,yy][2]>pixels[xx,yy][1]*1.05
              for xx in range(max(0,int(u-22)),min(foreground.width,int(u+23))))>=12]
        heights.append(dict(pole=(v-min(pole))*.045,roof=(v-min(roof))*.045))
    result['heights']=heights
    print('ELSA_SOURCE_GATE',folder or 'arrival',len(member_cells),'native pieces; foreground and lower background preserved')
    return result


def side_gate(props,name,sources,rect,native_feet,levels,span_polygon,span_edge):
    members=[p for p in props['maps']['59520'] if (props['groups'][p['group']]['master'],tuple(p['anchor'])) in sources]
    assert len(members)==len(sources),(name,members)
    feet=[[u/64-v/48,u/64+v/48] for u,v in native_feet]
    result=prepare_gate(members,rect,feet,name+'/',full_background=True)
    result.update(name=name,radius_scale=1.12,arch_scale=1.1,
        heights=[dict(pole=(v-pole)*.045,roof=(v-roof)*.045,eave=(v-eave)*.045) for (u,v),(pole,roof,eave) in zip(native_feet,levels)])
    result['limits']=['Original foreground and background jointly contain the towers and portal. Native roof, eave and pole rows guide the fit; cylinder ground centers and hidden depth are inferred. Native navigation is unchanged.']
    foreground,background=native_layers(members,rect)
    mask=Image.new('L',foreground.size);ImageDraw.Draw(mask).polygon(span_polygon,fill=255)
    span=foreground.copy();span.putalpha(Image.composite(span.getchannel('A'),Image.new('L',span.size),mask))
    target=OUT/(name+'/');span.save(target/'span.png')
    quads=[];alpha=span.getchannel('A')
    for y in range(0,span.height,4):
        for x in range(0,span.width,4):
            if alpha.crop((x,y,x+4,y+4)).getbbox():quads.append([x,y,4,4])
    slope,intercept,footer=span_edge
    result['span']=dict(origin=list(rect[:2]),rect=[0,0,*span.size],edges=outline(span),
        shape=dict(edge=[slope,intercept],footer=footer,height_pixels=(footer-intercept)/-slope,depth_pixels=41,quads=quads,
                   interval=[min(p[1] for p in span_polygon),max(p[1] for p in span_polygon)],inner='res://assets/maps/falan/elsa/props/wall-inner.png'),
        rgba_sha256=source.sha(span.tobytes()),source='Original attached foreground wallwalk, separated from the cylinder. Its blue deck is raised; hidden inner wall repeats original surface paint.')
    return result


def build():
    props=json.loads((source.ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
    body=next(p for p in props['maps']['59520'] if props['groups'][p['group']]['master']==300806 and p['anchor']==[7267,-651])
    pole=next(p for p in props['maps']['59520'] if props['groups'][p['group']]['master']==300807 and p['anchor']==[7372,-831])
    result=prepare_gate([body,pole],RECT,[[123.,100.42],[124.64,106.39]])
    body=next(p for p in props['maps']['59520'] if props['groups'][p['group']]['master']==300811 and p['anchor']==[10284,-409])
    feet=[]
    for x,y in [(85,456),(383,396)]:
        u=10284-320+x;v=-409-240+y;feet.append([u/64-v/48,u/64+v/48])
    poles=[p for p in props['maps']['59520'] if props['groups'][p['group']]['master']==300811 and p['anchor'] in [[9822,-489],[10187,-496]]]
    assert len(poles)==2
    other=prepare_gate([body,*poles],(9964,-736,10604,-169),feet,'ferry/',[(9964,-649,32,480),(10396,-649,208,480)])
    other.update(name='ferry',radius_scale=1.16,arch_scale=1.1)
    forest=side_gate(props,'forest',[(300814,(5971,-2007)),(300814,(6133,-2479))],(5960,-2520,6440,-1540),[(6229,-1807),(6284,-1963)],
        [(-2270,-2168,-2055),(-2426,-2324,-2210)],[(139,598),(211,568),(262,606),(216,753),(139,753)],[-.352,478.,502.])
    east=side_gate(props,'east',[(300814,(12000,-1190)),(300814,(12058,-1190)),(300815,(11937,-1670)),(300815,(12085,-1670))],(11940,-2020,12300,-1040),[(12075,-1260),(12134,-1450)],
        [(-1752,-1645,-1536),(-1909,-1808,-1698)],[(0,680),(70,624),(155,598),(135,705),(60,782),(0,782)],[-.352,365.,389.])
    result['others']=[other,forest,east]
    (OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':build()

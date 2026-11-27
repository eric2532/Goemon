"""Source-guided closed blind recess; all concealed depth/continuation inferred."""
import math
import statistics
from PIL import Image
from prepare_elsa_props import nearest_material_paint

ROWS=[4072,4076,4080,4084,4088,4092,4096,4108,4140,4190,4220]


def fit(bg,rect):
    def sample(u,q):return bg.getpixel((round(u)-rect[0],round(q-.75*u)-rect[1]))
    traces=[]
    for q in ROWS:
        prediction=6443.5+25*math.sqrt(max(0,1-((4097-q)/30)**2)) if q<4097 else 6468.5
        candidates=[]
        for u in range(round(prediction)-7,round(prediction)+8):
            colors=[sample(u+d,q) for d in [-3,-2,-1,0,1,2]]
            if not all(c[3] for c in colors):continue
            contrast=statistics.median(max(c[:3]) for c in colors[:3])-statistics.median(max(c[:3]) for c in colors[3:])
            candidates.append((contrast,-abs(u-prediction),u))
        contrast,_,u=max(candidates)
        assert contrast>=15,(q,u,contrast)
        traces.append(dict(q=q,u=u-.5,contrast=contrast,sample_pixels=[[u+d,round(q-.75*(u+d))] for d in [-3,-2,-1,0,1,2]],rgba=[list(c) for c in [sample(u+d,q) for d in [-3,-2,-1,0,1,2]]]))
    jamb=statistics.median(p['u'] for p in traces if p['q']>=4100)
    best=None
    for cx in [6436+i*.25 for i in range(45)]:
        for spring in [4093+i*.25 for i in range(33)]:
            for top in [4068+i*.25 for i in range(13)]:
                rx=jamb-cx;ry=spring-top
                errors=[cx+rx*math.sqrt(max(0,1-((spring-p['q'])/ry)**2))-p['u'] for p in traces if p['q']<4096]
                result=(sum(e*e for e in errors),cx,rx,spring,ry)
                if best is None or result<best:best=result
    error,cx,rx,spring,ry=best
    assert math.sqrt(error/6)<1.1,best
    return dict(center_u=cx,radius_u=rx,spring_q=spring,radius_q=ry,bottom_q=4238.,
                bevel_pixels=1.5,bevel_depth=.08,recess_depth=.28,trace=traces,fit_rms_pixels=math.sqrt(error/6),
                inference=['Upper/right contour follows measured native dark edge; left contour mirrors it where original BG is occluded.',
                           'Bottom4238 is concealed continuation beside the last visible jamb, not an original door or room.',
                           'Bevel/recess depths are inferred; the opening is a closed blind panel without collision or travel changes.'])


def aperture(spec,u,q,expand=0):
    rx=spec['radius_u']+expand;ry=spec['radius_q']+expand
    if q>spec['bottom_q']+expand or q<spec['spring_q']-ry:return False
    if abs(u-spec['center_u'])>rx:return False
    return q>=spec['spring_q'] or ((u-spec['center_u'])/rx)**2+((q-spec['spring_q'])/ry)**2<=1


def prepare_paint(bg,paint,observed,spec,rect,out):
    seed=Image.new('RGBA',bg.size);mask=Image.new('L',bg.size);mirrored=Image.new('L',bg.size)
    cx=spec['center_u']
    for y in range(bg.height):
        for x in range(bg.width):
            u,v=x+rect[0],y+rect[1];q=v+.75*u;c=bg.getpixel((x,y))
            if aperture(spec,u,q,-2) and c[3] and 95<max(c[:3])<135 and max(c[:3])-min(c[:3])<15:
                seed.putpixel((x,y),c);mask.putpixel((x,y),255)
            if observed.getpixel((x,y)) or not 4001<=q<=4240 or not 2*cx-6510<=u<cx:continue
            su=round(2*cx-u);sv=round(q-.75*su)
            c=bg.getpixel((su-rect[0],sv-rect[1]))
            if c[3] and max(c[:3])>3:
                paint.putpixel((x,y),c);mirrored.putpixel((x,y),255)
    assert sum(bool(v) for v in mask.tobytes())>1000
    panel=nearest_material_paint(seed);panel.save(out/'window-paint.png');mask.save(out/'window-source-mask.png');mirrored.save(out/'window-inferred-frame-mask.png')
    edge=bg.getpixel((6469-rect[0],round(4140-.75*6469)-rect[1]))
    Image.new('RGBA',(1,1),edge).save(out/'reveal.png')
    return dict(source_pixels=sum(bool(v) for v in mask.tobytes()),mirrored_pixels=sum(bool(v) for v in mirrored.tobytes()),reveal_rgba=list(edge))


def geometry(spec,vertex,face,rect,left,right,top,foot):
    cx=spec['center_u'];expand=spec['bevel_pixels']
    def at(u,q,depth=0):
        p=vertex(u,foot-q);return [p[0],p[1],p[2]-depth]
    def native(points,role,paint='native'):
        # Project actual prepared geometry back into its original source canvas.
        # Depth changes only an inferred surface, never the wall's source frame.
        from prepare_elsa_central_steps import VERTICAL
        uv=[[(p[0]+p[2])*32/3-rect[0],(p[2]-p[0])*8-p[1]*VERTICAL-rect[1]] for p in points]
        face(points,uv,role,paint)
    def rows(extra=0):
        rx=spec['radius_u']+extra;ry=spec['radius_q']+extra
        result=[]
        for i in range(13):
            angle=i*math.pi/24;spread=rx*math.sin(angle);q=spec['spring_q']-ry*math.cos(angle)
            result.append((q,cx-spread,cx+spread))
        result.append((spec['bottom_q']+extra,cx-rx,cx+rx))
        return result
    outer=rows(expand);inner=rows()
    apex=outer[0][0]
    for a,b in [(left,cx),(cx,right)]:native([at(a,top),at(b,top),at(b,apex),at(a,apex)],'wall above blind recess')
    for (q,lo,hi),(nq,nlo,nhi) in zip(outer,outer[1:]):
        native([at(left,q),at(lo,q),at(nlo,nq),at(left,nq)],'wall beside blind recess')
        native([at(hi,q),at(right,q),at(right,nq),at(nhi,nq)],'wall beside blind recess')
    bottom,lo,hi=outer[-1]
    for a,b in [(left,lo),(lo,hi),(hi,right)]:native([at(a,bottom),at(b,bottom),at(b,foot),at(a,foot)],'wall beneath closed blind recess')
    for (q,lo,hi),(nq,nlo,nhi) in zip(inner,inner[1:]):
        native([at(lo,q,spec['recess_depth']),at(hi,q,spec['recess_depth']),at(nhi,nq,spec['recess_depth']),at(nlo,nq,spec['recess_depth'])],'closed original-gray blind panel','window')
    def loop(rows):
        return [(hi,q) for q,lo,hi in rows]+[(lo,q) for q,lo,hi in reversed(rows[1:])]
    outside=loop(outer);inside=loop(inner)
    for i in range(len(outside)):
        j=(i+1)%len(outside)
        face([at(*outside[i]),at(*outside[j]),at(*inside[j],spec['bevel_depth']),at(*inside[i],spec['bevel_depth'])],role='inferred source-edge bevel',name='reveal')
        face([at(*inside[i],spec['bevel_depth']),at(*inside[j],spec['bevel_depth']),at(*inside[j],spec['recess_depth']),at(*inside[i],spec['recess_depth'])],role='inferred closed recess return',name='reveal')

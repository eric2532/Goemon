"""Editable static concept interpretations. Blender 4.3+. No external geometry."""
import bpy, math, random, json, sys, os
from pathlib import Path
from mathutils import Vector
import numpy as np
from math import sin,cos,pi
ROOT=Path(__file__).resolve().parents[1]
random.seed(2104)
C=None; M={}; TAG=''; CFG={}
def mat(name,hexcol,metal=0,rough=.65):
    h=hexcol.lstrip('#'); rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in rgb]
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
def mesh(name,v,f,material,sub=0,solid=0):
    me=bpy.data.meshes.new(name); me.from_pydata(v,[],f);me.update();ob=bpy.data.objects.new(TAG+'__'+name,me);C.objects.link(ob)
    if material: me.materials.append(M.get(material,material))
    for p in me.polygons:p.use_smooth=True
    if sub:
        md=ob.modifiers.new('Editable smooth control cage','SUBSURF');md.levels=sub;md.render_levels=sub
    if solid:
        md=ob.modifiers.new('Cloth thickness','SOLIDIFY');md.thickness=solid
    return ob
def uvball(name,loc,scale,material,seg=24,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=loc);o=bpy.context.object;o.name=TAG+'__'+name
    for co in list(o.users_collection):co.objects.unlink(o)
    C.objects.link(o);o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M[material]);
    for p in o.data.polygons:p.use_smooth=True
    return o
def line(name,pts,r,material,cyclic=False):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=12;cu.bevel_depth=r;cu.bevel_resolution=2
    sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
    for p,co in zip(sp.points,pts):p.co=(*co,1)
    sp.use_cyclic_u=cyclic;o=bpy.data.objects.new(TAG+'__'+name,cu);C.objects.link(o);cu.materials.append(M[material]);return o
def bez(a,b,c,d,n=20):
    return [tuple((1-t)**3*a[j]+3*(1-t)**2*t*b[j]+3*(1-t)*t*t*c[j]+t**3*d[j] for j in range(3)) for t in [i/(n-1) for i in range(n)]]
def loft(name,rows,material,n=32,fold=0,sub=1):
    # rows = center xyz, width/depth, optional phase. Horizontal garment sections.
    v=[]
    for i,(x,y,z,rx,ry) in enumerate(rows):
        for k in range(n):
            a=2*pi*k/n; f=1+fold*(sin(8*a+.6*i)+.35*sin(13*a-1.1*i));v.append((x+rx*sin(a)*f,y+ry*cos(a)*f,z))
    f=[tuple(range(n-1,-1,-1))]
    for j in range(len(rows)-1):
        for k in range(n):f.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    f.append(tuple((len(rows)-1)*n+k for k in range(n)));return mesh(name,v,f,material,sub)
def tube(name,pts,widths,material,depths=None,n=12,sub=1):
    v=[];depths=depths or widths
    if len(pts)==2:
        a,b=map(Vector,pts);w0,w1=widths;d0,d1=depths
        pts=[a,a.lerp(b,.02),a.lerp(b,.98),b];widths=[w0,w0,w1,w1];depths=[d0,d0,d1,d1]
    for i,p in enumerate(pts):
        p=Vector(p); tangent=Vector(pts[min(i+1,len(pts)-1)])-Vector(pts[max(0,i-1)]);tangent.normalize()
        u=Vector((0,1,0)).cross(tangent).normalized()
        if u.length<.1:u=Vector((1,0,0))
        w=tangent.cross(u).normalized()
        for k in range(n):
            a=2*pi*k/n;fold=1+.06*sin(6*a+i*.7) if 'sleeve' in name.lower() else 1
            v.append(p+u*widths[i]*cos(a)*fold+w*depths[i]*sin(a)*fold)
    f=[tuple(range(n-1,-1,-1))]
    for j in range(len(pts)-1):
        for k in range(n):f.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    f.append(tuple((len(pts)-1)*n+k for k in range(n)))
    if 'sleeve' in name.lower():return mesh(name,v,f[1:-1],material,sub,.015)
    return mesh(name,v,f,material,sub)
def ribbon(name,pts,widths,material,thick=.013,axis=(1,0,0)):
    v=[]
    for i,p in enumerate(pts):
        for k in range(7):
            t=(k/6-.5)*2;wave=sin(i*.7+k*1.4)*.009
            v.append(tuple(p[j]+axis[j]*widths[i]*t+(wave if j==1 else 0) for j in range(3)))
    f=[]
    for i in range(len(pts)-1):
        for k in range(6):a=i*7+k;f.append((a,a+1,a+8,a+7))
    return mesh(name,v,f,material,1,thick)
def band(name,z,rx,ry,r,material,x=0,y=0):
    return line(name,[(x+rx*sin(2*pi*i/96),y+ry*cos(2*pi*i/96),z) for i in range(96)],r,material,True)
def rope(name,pts,r,material='rope',strands=3):
    for s in range(strands):
        out=[]
        for i,p in enumerate(pts):
            a=i*.8+2*pi*s/strands;out.append((p[0]+r*.47*cos(a),p[1]+r*.47*sin(a),p[2]+r*.47*sin(a)))
        line(name+f'_strand{s+1}',out,r*.53,material)
def disk(name,loc,r,depth,material):
    o=uvball(name,loc,(r,depth,r),material,32,16);return o
def clasp(name,loc,r,material='metal'):
    x,y,z=loc;disk(name,loc,r,.035,material);line(name+'_rim',[(x+r*.85*cos(a),y+.037,z+r*.85*sin(a)) for a in [2*pi*i/64 for i in range(64)]],.009,'gold',True)
    for a in [2*pi*i/5 for i in range(5)]:line(name+'_engraving',bez((x,y+.04,z),(x+.035*cos(a),y+.044,z+.035*sin(a)),(x+r*.6*cos(a+.5),y+.04,z+r*.6*sin(a+.5)),(x+r*.65*cos(a),y+.036,z+r*.65*sin(a))),.005,'dark')
def tassel(name,p,material='rope',size=1):
    x,y,z=p;disk(name+'_knot',(x,y,z),.035*size,.025*size,material)
    for k in range(8):
        a=k*pi/4;tube(name+'_fiber'+str(k),[(x+.013*cos(a)*size,y+.013*sin(a)*size,z-.02*size),(x+.02*cos(a)*size,y+.02*sin(a)*size,z-.07*size),(x+.038*cos(a)*size,y+.03*sin(a)*size,z-.15*size)],[.01*size,.012*size,.009*size],material,n=6)
def panel(name,outline,material,thick=.02):
    # convex front-facing custom cloth/armor shape, curved centre
    center=tuple(sum(p[j] for p in outline)/len(outline) for j in range(3));v=[center]+outline
    return mesh(name,v,[(0,i+1,(i+1)%len(outline)+1) for i in range(len(outline))],material,0,thick)
def hairlock(name,control,w,material='hair',depth=.28):
    pts=bez(*control,n=15); widths=[max(.001,w*(sin(pi*(i/14*.85+.08))**.8)*(1-i/14)**.45) for i in range(15)];widths[-1]=.001
    tube(name,pts,widths,material,[x*depth for x in widths],n=8,sub=1)
    # sculpted central strand highlight, follows the same swept lock
    ridge=[(p[0],p[1]+widths[i]*depth*.96,p[2]) for i,p in enumerate(pts)]
    line(name+'_strand',ridge,.0018,'hair_hi')
def setup(cfg):
    global C,M,TAG,CFG
    CFG=cfg;TAG=cfg['name'];bpy.ops.wm.read_factory_settings(use_empty=True)
    C=bpy.data.collections.new(TAG+' • editable character');bpy.context.scene.collection.children.link(C)
    cols=dict(skin=cfg.get('skin','DCA06D'),skin_shadow=cfg.get('shadow','A56746'),hair=cfg['hair'],hair_hi=cfg.get('hair_hi','6B4B35'),cloth=cfg['cloth'],pants=cfg['pants'],accent=cfg['accent'],cream='D9CEB6',dark='29292A',leather='4E3B2D',rope='AF803F',gold='AA813F',metal='8E8A78',white='F3E6CB',iris=cfg.get('iris','8F622C'),pupil='171413',lip='80513A',nail='C18B62')
    M={k:mat(TAG+' / '+k,v,.65 if k in ('gold','metal') else 0,.36 if k in ('gold','metal') else .67) for k,v in cols.items()}
    for material in M.values():
        material.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.25
    M['eye']=mat(TAG+' / eye whites','F4EBDC',0,.28)
    M['glint']=mat(TAG+' / eye catchlight','FFFFFF',0,.15)

def head(cfg):
    hw=cfg.get('head_width',1); hz=cfg.get('head_z',0); slim=cfg.get('slim',False)
    rows=[(0,0,1.95,.10,.12),(0,.015,1.98,.21,.22),(0,0,2.055,.33*hw,.29),(0,-.015,2.17,.425*hw,.345),(0,-.02,2.31,.455*hw,.362),(0,-.03,2.48,.452*hw,.36),(0,-.035,2.65,.424*hw,.345),(0,-.04,2.77,.31*hw,.27),(0,-.04,2.82,.13,.13)]
    if cfg['name'] in ('Shiro','Touma','Nagi'):
        rows=[(x,y,z,rx*(.90 if z<2.2 else 1),ry) for x,y,z,rx,ry in rows]
    if cfg['name'] in ('Gaku','Kuren'):
        rows=[(x,y,z,rx*(1.09 if z<2.2 else 1),ry) for x,y,z,rx,ry in rows]
    v=[];N=64
    for x,y,z,rx,ry in rows:
        for k in range(N):
            a=2*pi*k/N;c=cos(a);v.append((x+rx*sin(a),y+ry*math.copysign(abs(c)**.6,c),z+hz))
    f=[tuple(range(N-1,-1,-1))]
    for j in range(len(rows)-1):
        for k in range(N):f.append((j*N+k,j*N+(k+1)%N,(j+1)*N+(k+1)%N,(j+1)*N+k))
    f.append(tuple((len(rows)-1)*N+k for k in range(N)));mesh('Face_sculpt_cage',v,f,'skin',2)
    loft('Neck',[(0,0,1.73,.14,.13),(0,0,1.91,.17,.15),(0,0,2.07,.18,.15)],'skin',24,sub=1)
    for s in (-1,1):
        uvball('Ear_'+str(s),(s*.445*hw,0,2.27+hz),(.105,.065,.155),'skin')
        uvball('Ear_concha_'+str(s),(s*.473*hw,.054,2.28+hz),(.052,.016,.089),'skin_shadow')
        line('Ear_helix_'+str(s),[(s*(.463+.055*cos(a))*hw,.063,2.285+hz+.11*sin(a)) for a in [2*pi*i/40 for i in range(40)]],.016,'skin',True)
        uvball('Ear_tragus_'+str(s),(s*.445*hw,.065,2.25+hz),(.024,.022,.038),'skin')
    def fy(x,z):
        # Match the broad anterior face plane; eye corners wrap onto temples.
        ry=.352 if z>2.2 else .31
        return -.022+ry*max(.04,1-(x/(.465*hw))**2)**.30
    eyez=cfg.get('eye_z',2.385)+hz; ew=.126 if not slim else .115; eh=.060 if not slim else .049
    for s in (-1,1):
        cx=s*.207*hw;out=[]
        for i in range(33):
            a=2*pi*i/32;x=cx+ew*cos(a);z=eyez+eh*sin(a)+s*(x-cx)*.26
            out.append((x,fy(x,z)+.009,z))
        center=(cx,fy(cx,eyez)+.029,eyez)
        mesh('Eye_white_'+str(s),[center]+out,[(0,i+1,i+2) for i in range(32)],'eye',1)
        irisx=cx-.012; yy=fy(irisx,eyez)+.031
        disk('Iris_limbal_'+str(s),(irisx,yy,eyez),eh*.96,.016,'dark')
        disk('Iris_'+str(s),(irisx,yy+.012,eyez),eh*.84,.009,'iris')
        disk('Pupil_'+str(s),(irisx,yy+.021,eyez+.008),eh*.46,.006,'pupil')
        for a in [2*pi*i/16 for i in range(16)]:
            line('Iris_radial_'+str(s),[(irisx+eh*.52*cos(a),yy+.023,eyez+eh*.52*sin(a)),(irisx+eh*.75*cos(a),yy+.018,eyez+eh*.75*sin(a))],.002,'gold' if cfg['name'] in ('Sen','Banji') else 'skin_shadow')
        disk('Eye_glint_'+str(s),(irisx-.018,yy+.029,eyez+.028),.014,.004,'glint')
        top=out[:17];line('Upper_lid_'+str(s),top,.012 if not slim else .009,'dark');line('Lower_lid_'+str(s),out[16:],.0045,'skin_shadow')
        # tapered angular eyebrows, inner tips lower in a determined expression
        x0=s*.095*hw;x1=s*.21*hw;x2=s*.337*hw
        pts=[(x0,fy(x0,eyez)+.026,eyez+.106),(x1,fy(x1,eyez)+.02,eyez+.167),(x2,fy(x2,eyez)+.012,eyez+.17),(x1,fy(x1,eyez)+.025,eyez+.207),(x0,fy(x0,eyez)+.028,eyez+.137)]
        panel('Brow_'+str(s),[(x,y,z-.050) for x,y,z in pts],'dark',.009)
    # nose with shaped bridge, wings and tip; no spherical button
    vv=[(-.034,.331,2.37+hz),(.034,.331,2.37+hz),(-.041,.363,2.28+hz),(.041,.363,2.28+hz),(-.05,.366,2.25+hz),(0,.416,2.258+hz),(.05,.366,2.25+hz),(0,.353,2.223+hz)]
    mesh('Nose_bridge_tip',vv,[(0,1,3,2),(2,3,5),(2,5,4),(3,6,5),(4,5,7),(5,6,7)],'skin',2)
    for s in (-1,1):line('Nostril_'+str(s),[(s*.033,.371,2.242+hz),(s*.02,.39,2.239+hz)],.005,'skin_shadow')
    line('Mouth',bez((-.081,.307,2.133+hz),(-.027,.327,2.146+hz),(.034,.327,2.147+hz),(.081,.307,2.132+hz)),.006,'lip')
    line('Lower_lip',bez((-.035,.303,2.108+hz),(-.01,.314,2.102+hz),(.018,.314,2.102+hz),(.04,.301,2.109+hz)),.004,'skin_shadow')

def hair(cfg):
    style=cfg['style'];basez=cfg.get('head_z',0)
    # cap deliberately stops above ears / behind jaw
    v=[];n=64
    for j in range(9):
        t=(j+.05)/8.05;phi=t*pi/2
        for i in range(n):
            a=2*pi*i/n;front=max(0,cos(a))
            bottom=2.23+.43*(front**4)
            if style in ('crop','spikes'):bottom=2.38+.27*(front**4)
            rx=.477 if style in ('crop','spikes') else .505
            ry=.367 if style in ('crop','spikes') else .397
            v.append((rx*sin(phi)*sin(a),-.045+ry*sin(phi)*cos(a),2.91+(bottom-2.91)*(1-cos(phi))))
    faces=[]
    for j in range(8):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    mesh('Hair_scalp_contoured',v,faces,'hair',1,.018)

    if style=='sen':
        # Individual large wind-swept quills with hooked tips, combed across crown.
        locks=[((-.10,.05,2.79),(-.15,.07,3.0),(-.35,.09,3.15),(-.38,.12,3.27),.15),((-.10,.02,2.8),(.15,.05,3.13),(.28,.04,3.13),(.46,.04,3.16),.18),((0,-.05,2.79),(.35,-.09,3.02),(.52,-.02,3.15),(.45,.03,3.30),.20),((.08,.18,2.78),(.52,.25,3.02),(.60,.24,2.79),(.67,.19,2.64),.17),((.02,.33,2.8),(.38,.49,2.98),(.59,.47,2.65),(.50,.42,2.31),.16),((-.05,.35,2.78),(-.02,.47,2.96),(.38,.49,2.84),(.40,.43,2.44),.125),((-.07,.30,2.77),(-.32,.46,2.97),(-.43,.41,2.87),(-.67,.28,2.86),.13)]
        for i,(*cp,w) in enumerate(locks):
            hairlock('Crown_swept_lock_%02d'%i,cp,w)
            for j in (-1,1):
                mini=[(p[0]+j*.03,p[1]+.045,p[2]-.04) for p in cp]
                hairlock('Crown_layer_%s_%s'%(i,j),mini,w*.43)
        for i in range(7):
            hairlock('Swept_hairline_'+str(i),[(-.05+i*.044,.285,2.82),(-.2+i*.037,.39,2.80),(-.20+i*.043,.39,2.70),(-.25+i*.045,.335,2.61)],.036)

        for s in (-1,1):
            for i in range(6):
                z=2.69-i*.076
                hairlock('Temple_layer_%s_%s'%(s,i),[(s*.20,.10,z+.10),(s*.42,.24,z+.13),(s*.52,.12,z-.04),(s*(.57+.055*sin(i)),.02,z-.12)],.070)
        for i in range(7):hairlock('Low_ponytail_'+str(i),[(-.32,-.21,2.24),(-.55,-.23,2.22),(-.63,-.18,2.04-i*.017),(-.55+i*.023,-.15,1.94-i*.023)],.07)
        for z in (2.23,2.26):band('Ponytail_binding',z,.069,.058,.016,'dark',x=-.43,y=-.19)
    else:
        # styles specialized below after Sen quality gate
        generic_hair(cfg)

def body(cfg):
    bulky=cfg.get('bulk',1);upper=cfg.get('upper','sleeveless');pant=cfg.get('pant_style','baggy')
    loft('Under_kimono',[(0,0,1.02,.33,.21),(0,0,1.16,.38,.24),(0,0,1.38,.335,.245),(0,-.01,1.65,.46*bulky,.245),(0,-.025,1.78,.37,.20),(0,-.015,1.83,.19,.145)],'cloth',48,.025,2)
    # crossed cloth collars follow the torso rather than hanging in front
    ribbon('Kimono_lapel_under',bez((-.17,.145,1.83),(-.08,.285,1.70),(.17,.279,1.47),(.25,.253,1.40)),[.034]*20,'dark')
    ribbon('Kimono_lapel_cross',bez((.18,.145,1.82),(.18,.252,1.67),(-.14,.288,1.49),(-.27,.24,1.40)),[.058]*20,'cream')
    ribbon('Kimono_lapel_return',bez((-.19,.145,1.82),(-.16,.25,1.73),(-.04,.282,1.64),(.02,.293,1.58)),[.048]*20,'cream')
    # shorts use shaped pleated ring cages and a fitted lower opening
    for s in (-1,1):
        x=s*.255
        if pant=='hakama':rows=[(x,0,.48,.235,.235),(x,0,.52,.27,.25),(s*.24,0,.78,.25,.245),(s*.18,0,1.08,.24,.22),(s*.17,0,1.17,.20,.20)]
        else:rows=[(s*.29,0,.48,.145,.145),(s*.30,0,.55,.235,.23),(s*.29,-.015,.66,.285,.255),(s*.235,-.01,.89,.26,.25),(s*.175,0,1.14,.22,.205)]
        loft('Trousers_'+str(s),rows,'pants',48,.055 if pant=='baggy' else .035,2)
        for k in range(5):
            xx=x+(k-2)*.072
            line('Trouser_fold_'+str(s)+'_'+str(k),bez((xx*.80,.207,1.06),(xx,.23,.9),(xx+s*.025,.24,.68),(xx+s*.02,.20,.55)),.005,'pants')
        if pant=='hakama':
            for k in range(4):
                xx=x+(k-1.5)*.105
                ribbon('Hakama_pleat_%s_%s'%(s,k),[(xx*.7,.219,1.12),(xx,.26,.82),(xx+s*.03,.272,.51)],[.041,.052,.056],'pants',.008)
        loft('Calf_'+str(s),[(s*.30,0,.15,.117,.10),(s*.30,0,.35,.124,.12),(s*.29,0,.57,.148,.14)],'skin',24,sub=2)
        # wrap strips follow leg and taper
        for j in range(6):
            z=.225+j*.045;pts=[]
            for i in range(65):a=2*pi*i/64;pts.append((s*.30+(.122+.018*j/6)*sin(a),(.117+.012*j/6)*cos(a),z+.025*sin(a+.8)))
            line('Shin_wrap_%s_%s'%(s,j),pts,.024,'cream',True)
        band('Ankle_rope_'+str(s),.235,.135,.13,.021,'rope',x=s*.30)
        # feet are shaped shells with separated big toe / tabi split
        uvball('Foot_'+str(s),(s*.30,.093,.131),(.147,.228,.078),'dark' if cfg.get('tabi',False) else 'skin')
        loft('Sandal_sole_'+str(s),[(s*.30,.096,.02,.172,.26),(s*.30,.096,.055,.176,.265),(s*.30,.096,.076,.165,.253)],'rope' if cfg.get('rope_soles') else 'leather',36,sub=1)
        if cfg.get('tabi'):
            for j in (-1,1):uvball('Tabi_toe_%s_%s'%(s,j),(s*.30+j*.068,.275,.108),(.069,.079,.052),'dark' if cfg['name']=='Sen' else 'cream')
            line('Tabi_split_'+str(s),[(s*.30,.37,.07),(s*.30,.365,.14),(s*.30,.30,.20)],.009,'dark')
        else:
            for j in range(5):uvball('Toe_%s_%s'%(s,j),(s*.30+(j-2)*.052,.298-abs(j-1)*.008,.109),(.031 if j else .043,.065,.04),'skin',16,10)
        for j in range(2):
            pts=bez((s*.30-.143,.025+j*.12,.10),(s*.30-.10,.06+j*.13,.235),(s*.30+.10,.07+j*.13,.238),(s*.30+.145,.03+j*.12,.10))
            rope('Sandal_strap_%s_%s'%(s,j),pts,.025,'rope' if cfg['name']=='Sen' else 'dark')
        # arms: continuous shaped shoulder / bicep / elbow / forearm cage
        pts=[(s*.38,0,1.70),(s*.50,0,1.66),(s*.58,.005,1.49),(s*.64,.015,1.37),(s*.67,.06,1.20),(s*.70,.07,1.08)]
        raised=cfg.get('staff') and s==1
        carry=cfg['name']=='Nagi' and s==1
        if raised:pts=[(.38,0,1.70),(.50,0,1.62),(.60,.01,1.43),(.70,.015,1.42),(.82,.05,1.53),(.90,.075,1.55)]
        if carry:pts=[(.38,0,1.70),(.52,0,1.62),(.62,.04,1.43),(.61,.10,1.44),(.49,.22,1.59),(.43,.28,1.65)]
        tube('Arm_anatomy_'+str(s),pts,[.15,.168,.15,.125,.14,.115],'skin',n=20,sub=2)
        if upper!='sleeveless':
            tube('Kimono_sleeve_'+str(s),pts[:3]+[(s*.63,.0,1.43)],[.18,.215,.25,.255] if upper!='wide' else [.18,.25,.32,.33],'cloth',n=32,sub=2)
            # hollow-looking dark cuff facing forearm
            tube('Sleeve_inner_'+str(s),[(s*.614,0,1.449),(s*.632,0,1.422)],[.23,.23],'dark',n=32,sub=1)
        else:
            line('Armhole_binding_'+str(s),[(s*(.37+.10*cos(a)),.175*sin(a),1.67+.135*cos(a)) for a in [2*pi*i/64 for i in range(64)]],.023,'cream',True)
        for j in range(5):
            z=1.10+j*.041;cx=s*(.70-(z-1.08)*.19)
            if raised or carry:
                a=Vector(pts[-2]);b=Vector(pts[-1]);d=(b-a).normalized();mid=a.lerp(b,j/4);u=Vector((0,1,0));v=d.cross(u).normalized()
                line('Forearm_wrap_%s_%s'%(s,j),[mid+u*.125*sin(t)+v*.12*cos(t) for t in [2*pi*i/48 for i in range(48)]],.022,'cream',True)
            else:band('Forearm_wrap_%s_%s'%(s,j),z,.126,.132,.022,'cream',x=cx,y=.05)
        if cfg.get('bracer',True):
            outline=[(s*.57,.164,1.25),(s*.76,.167,1.26),(s*.81,.17,1.04),(s*.66,.179,1.00)]
            panel('Forearm_leather_guard_'+str(s),outline,'leather',.025)
            line('Bracer_edge_'+str(s),outline,.007,'metal',True)
            line('Bracer_lace_'+str(s),[(s*.59,.195,1.23),(s*.77,.19,1.07),(s*.64,.193,1.08),(s*.755,.19,1.22)],.010,'rope')
            for xx,z in ((.60,1.22),(.75,1.23),(.68,1.04),(.78,1.07)):disk('Bracer_rivet',(s*xx,.193,z),.015,.008,'gold')
        hand(s,(.91,.075,1.55) if raised else ((.43,.28,1.69) if carry else (s*.713,.075,.985)),cfg)
    # belt overlays waist seam
    loft('Sash_base',[(0,0,1.16,.36,.251),(0,0,1.21,.362,.264),(0,0,1.31,.365,.265),(0,0,1.345,.35,.245)],'accent',48,.015,1)

def hand(s,center,cfg):
    x,y,z=center
    # fused palm base plus bent finger cages, with real thumb opposition
    uvball('Palm_'+str(s),(x,y,z),(.137,.103,.137),'skin')
    for j in range(4):
        xx=x+(j-1.5)*.058
        pts=[(xx,y+.068,z+.016),(xx,y+.12,z-.037),(xx,y+.105,z-.093),(xx,y+.034,z-.095)]
        tube('Curled_finger_%s_%s'%(s,j),pts,[.032,.034,.032,.026],'skin',n=10,sub=2)
        line('Finger_crease',[(xx-.023,y+.134,z-.038),(xx+.022,y+.134,z-.043)],.0025,'skin_shadow')
    tube('Thumb_'+str(s),[(x-s*.115,y+.013,z+.065),(x-s*.131,y+.105,z+.038),(x-s*.078,y+.133,z-.005)],[.054,.048,.04],'skin',n=12,sub=2)

def sen_gear():
    # triple twisted ochre waist cord
    for j in range(3):
        pts=[(.371*sin(a),.28*cos(a),1.20+j*.047+.009*sin(3*a)) for a in [2*pi*i/120 for i in range(121)]];rope('Waist_braid_'+str(j),pts,.026)
    rope('Belt_knot',bez((.19,.29,1.28),(.43,.38,1.36),(.44,.38,1.11),(.24,.30,1.17)),.03)
    ribbon('Ochre_sash_tail',bez((.26,.286,1.23),(.34,.37,1.07),(.39,.37,.75),(.56,.30,.55)),[.08+.04*(i/19) for i in range(20)],'rope',.016)
    for i in range(11):line('Sash_fringe',[(.46+i*.02,.30,.58),(.47+i*.022,.31,.50-.035*sin(i))],.006,'rope')
    # shaped windborne shoulder scarf made from two irregular cloth sheets
    rows=[((-.35,.03,1.78),.16),((-.52,-.09,1.72),.20),((-.75,-.12,1.57),.24),((-1.01,-.08,1.46),.26),((-1.29,-.03,1.30),.23),((-1.40,.00,1.12),.01)]
    ribbon('Wind_scarf_lower',[p for p,w in rows],[w for p,w in rows],'cloth',.015,axis=(0,.3,1))
    rows2=[((-.35,.02,1.8),.13),((-.62,-.13,1.73),.16),((-.94,-.10,1.69),.19),((-1.21,.03,1.68),.13),((-1.51,.02,1.49),.007)]
    ribbon('Wind_scarf_upper',[p for p,w in rows2],[w for p,w in rows2],'cloth',.014,axis=(0,.3,1))
    clasp('Shoulder_wind_brooch',(-.33,.246,1.72),.092,'gold');tassel('Brooch_tassel',(-.36,.28,1.60),'rope',.8)
    # irregular free edges, with torn trailing yarns matching the windswept scarf
    for i in range(17):
        x=-.64-i*.045;z=1.58-(i/16)*.30+.04*sin(i*2)
        line('Scarf_torn_edge',[(x,-.04,z),(x-.06,-.025,z-.03),(x-.08,-.02,z-.08-.045*sin(i))],.004,'cloth')
    moon('Sash_moon',.37,.405,.91,.072,'cream')
    # pale moon/cloud embroideries sit on the cloth, not floating graphic planes
    line('Scarf_cloud_motif',[(-.92,.0,1.53),(-1.02,.03,1.55),(-1.08,.025,1.61),(-1.02,.01,1.67),(-.95,.0,1.66)],.016,'cream')
    # wooden short sword / training blade slanted at hip
    tube('Wood_sword_sheath',[(.36,.19,.91),(.41,.23,1.08),(.47,.24,1.31),(.51,.22,1.46)],[.045]*4,'leather',n=10)
    tube('Wood_sword_grip',[(.51,.22,1.43),(.58,.20,1.65)],[.042,.042],'rope',n=12)
    for i in range(5):line('Grip_binding',[(.47+i*.013,.262,1.43+i*.035),(.56+i*.013,.26,1.43+i*.035)],.014,'dark')

def generic_hair(cfg):
    st=cfg['style']
    if st in ('shag','curly','swept','wave'):
        for side in (-1,1):
            for j in range(6):
                z=2.80-j*.105
                hairlock('Layered_side_silhouette_%s_%s'%(side,j),[(side*.28,.04,z+.07),(side*.48,.30,z+.17),(side*.59,.29,z-.04),(side*(.64+.025*sin(j)),.17,z-.06)],.088 if st=='shag' else .077)
        for i in range(9):
            x=(i-4)*.085
            hairlock('Crown_volume_'+str(i),[(x*.65,-.06,2.84),(x-.045,.08,3.01),(x-.13,.06,3.05),(x-.14,-.03,3.08+.045*cos(i))],.088)
    if st=='bob':
        for side in (-1,1):
            for j in range(5):
                hairlock('Bob_outer_fan_%s_%s'%(side,j),[(side*.19,-.01-j*.05,2.81),(side*.51,-.015-j*.055,2.77),(side*.54,.07-j*.057,2.27),(side*.49,.13-j*.05,2.00+j*.012)],.072)
    if st=='crop':
        # close-cropped scalp grain, with an even hairline rather than big spikes
        for j in range(7):
            theta=.25+j*.19
            for i in range(18):
                a=2*pi*i/18+j*.2;x=.465*sin(theta)*sin(a);y=-.055+.36*sin(theta)*cos(a);z=2.43+.42*cos(theta)
                hairlock('Crop_grain_%s_%s'%(j,i),[(x,y,z),(x+.014,y,z+.027),(x+.029,y-.008,z+.026),(x+.034,y-.017,z+.02)],.014)
        return
    if st=='spikes':
        for j in range(4):
            for i in range(8):
                x=(i-3.5)*.098;y=.27-j*.15;z=2.75-.11*abs(x)/.4
                hairlock('Short_upswept_%s_%s'%(j,i),[(x,y,z),(x*.97,y-.06,z+.15),(x*.8-.05,y-.12,z+.21),(x*.75-.08,y-.18,z+.23)],.062)
        # fade panels lie tight to temples
        for s in (-1,1):
            for i in range(8):line('Temple_fade',[(s*.444,.11,2.37+i*.036),(s*.44,.06,2.40+i*.035)],.003,'hair_hi')
        return
    if st=='bob':
        # satin jaw-length bob, asymmetrical right curtain and exposed opposite ear
        for i in range(20):
            a=.42+(2*pi-.68)*i/19;x=.41*sin(a);y=-.045+.32*cos(a)
            endz=2.02+.045*sin(i*2);ex=x*1.29
            hairlock('Bob_panel_%02d'%i,[(x*.52,y*.55,2.79),(x*1.1,y*1.15,2.77),(ex,y*1.24,2.38),(ex*.92,y*1.19,endz)],.09,depth=.23)
        for i in range(6):
            hairlock('Asymmetric_bob_fringe_'+str(i),[(-.04+i*.035,.25,2.84),(-.24+i*.022,.42,2.80),(-.43+i*.03,.43,2.40),(-.43+i*.026,.35,2.17+i*.015)],.069,depth=.25)
        return
    if st=='bun':
        for i in range(7):
            x=(i-3)*.063
            hairlock('Blunt_fringe_'+str(i),[(x*.8,.23,2.78),(x,.345,2.71),(x,.375,2.64),(x+.014,.377,2.60)],.048,depth=.21)
        for s in (-1,1):
            for i in range(5):hairlock('Side_comb_%s_%s'%(s,i),[(s*.14,-.06,2.81),(s*.48,.05,2.71),(s*.47,.24,2.47),(s*.41,.24,2.19-i*.02)],.070)
        uvball('Topknot_core',(.10,-.10,3.03),(.165,.135,.20),'hair',24,16)
        for i in range(14):
            a=i*2*pi/14
            hairlock('Topknot_loop_'+str(i),[(.08+.12*sin(a),-.08+.10*cos(a),2.85),(.15+.19*sin(a),-.08+.20*cos(a),3.03),(.12+.19*sin(a),-.10+.19*cos(a),3.27),(.05+.11*sin(a),-.18+.1*cos(a),3.30)],.073)
        for z in (2.89,2.93):band('Bun_ribbon',z,.17,.15,.022,'accent',x=.10,y=-.08)
        tube('Brass_hairpin',[(-.15,-.08,2.96),(.41,-.13,3.02)],[.013,.013],'gold',n=12,sub=1);uvball('Hairpin_cap',(.42,-.13,3.023),(.035,.027,.036),'gold')
        return
    if st=='pony':
        for j in range(3):
            for i in range(12):
                a=2*pi*i/12+.12*j;x=.43*sin(a);y=-.05+.35*cos(a)
                hairlock('Swept_black_layer_%s_%s'%(j,i),[(x*.3,y*.3,2.85-j*.04),(x*.85,y,2.87-j*.06),(x*1.1,y*1.1,2.59-j*.08),(x*.93,y*.85,2.43-j*.11)],.082)
        for s in (-1,1):
            for i in range(4):hairlock('Long_face_lock_%s_%s'%(s,i),[(s*(.04+i*.04),.24,2.82),(s*.36,.43,2.86),(s*(.38+i*.017),.41,2.46),(s*(.31+i*.03),.33,2.19-i*.05)],.042)
        for i in range(9):
            hairlock('Low_tied_ponytail_'+str(i),[(.1,-.36,2.37),(.26,-.50,2.26),(.32+(i-4)*.02,-.52,1.98),(.24+(i-4)*.035,-.40,1.89)],.052)
        band('Ponytail_rope',2.35,.083,.069,.018,'rope',x=.10,y=-.35)
        return
    if st in ('shag','curly'):
        for j in range(4):
            for i in range(16):
                a=2*pi*i/16+.19*j
                x=.41*sin(a);y=-.065+.33*cos(a);z=2.75-j*.115
                out=1.14+(.14 if st=='shag' else .10)*sin(i*2)
                hairlock('Tumbled_layer_%s_%s'%(j,i),[(x*.68,y*.72,z+.11),(x*1.16,y*1.16,z+.17),(x*out,y*out,z-.05),(x*(out+.09),y*(out+.05),z+(.015 if st=='curly' else -.13))],.082 if st=='shag' else .074)
        for i in range(7):
            x=(i-3)*.103
            hairlock('Broken_fringe_'+str(i),[(x*.65,.25,2.86),(x,.40,2.77),(x-.025,.41,2.61),(x-.04,.36,2.54-.05*cos(i))],.07)
        if st=='curly':
            M['forelock']=mat('Roan / ivory forelock','DFD4B8')
            for i in range(4):hairlock('White_forelock_'+str(i),[(-.08+i*.033,.28,2.77),(-.22+i*.034,.39,2.99),(-.02+i*.033,.40,2.99),(.05+i*.025,.34,3.12)],.057,'forelock')
            for i in range(3):hairlock('White_falling_curl_'+str(i),[(-.055+i*.035,.34,2.91),(-.22+i*.035,.46,2.82),(-.20+i*.027,.45,2.62),(-.10+i*.024,.38,2.60)],.045,'forelock')
        return
    if st in ('swept','wave'):
        for j in range(3):
            for i in range(12):
                a=2*pi*i/12+.16*j;x=.40*sin(a);y=-.05+.31*cos(a)
                hairlock('Flow_layer_%s_%s'%(j,i),[(x*.4,y*.7,2.84-j*.07),(x*1.12-.10,y*1.1,2.90-j*.11),(x*1.28-.12,y*1.2,2.68-j*.1),(x*1.38-.14,y*1.13,2.70-j*.1)],.095 if st=='wave' else .08)
        for i in range(7):
            hairlock('Swept_fringe_'+str(i),[(.16-i*.042,.23,2.85),(-.22-i*.027,.40,2.97),(-.54-i*.02,.41,2.65),(-.45-i*.024,.31,2.27-i*.038)],.067)
        if st=='swept':
            for i in range(4):hairlock('Opposite_white_fringe_'+str(i),[(.07,.28,2.81),(.31+i*.024,.38,2.87),(.39+i*.024,.42,2.69),(.37+i*.025,.35,2.51)],.066)

# Additional garment / prop builders. Every visible part remains independently named.
def replace_material(part,material):
    for o in C.objects:
        if part in o.name and hasattr(o.data,'materials'):o.data.materials.clear();o.data.materials.append(M[material])
def border(name,pts,material='cream',r=.008):line(name,pts,r,material)
def diamond(name,x,y,z,r,material='metal'):
    line(name,[(x,y,z+r),(x+r*.8,y,z),(x,y,z-r),(x-r*.8,y,z)],.012,material,True)
    line(name+'_inner',[(x,y+.006,z+r*.55),(x+r*.4,y+.006,z),(x,y+.006,z-r*.55),(x-r*.4,y+.006,z)],.005,material,True)
def moon(name,x,y,z,r,material='cream'):
    v=[]
    for i in range(33):
        a=pi*.22+(2*pi-pi*.44)*i/32
        v.extend([(x+r*cos(a),y,z+r*sin(a)),(x+r*.57*cos(a)+r*.34,y+.001,z+r*.75*sin(a))])
    mesh(name,v,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(32)],material,0,.005)
def jacket(cfg,material='cloth',collar=False):
    for s in (-1,1):
        pts=[(s*.25,.20,1.78),(s*.34,.235,1.64),(s*.31,.255,1.46),(s*.31,.262,1.31)]
        ribbon('Open_jacket_front_'+str(s),pts,[.11,.12,.10,.11],material,.025)
        line('Jacket_front_piping_'+str(s),[(s*.14,.225,1.78),(s*.21,.264,1.62),(s*.21,.278,1.43),(s*.20,.283,1.31)],.008,'rope')
        if collar:
            ribbon('Standing_collar_'+str(s),[(s*.15,.12,1.78),(s*.23,.17,1.88),(s*.26,.16,1.99)],[.074,.085,.10],material,.023)
            line('Collar_edge_'+str(s),[(s*.16,.18,1.99),(s*.36,.18,1.99),(s*.33,.21,1.82)],.008,'gold' if cfg['name']=='Banji' else 'cream')
        # separate jacket hem flaps below belt
        ribbon('Jacket_hem_'+str(s),[(s*.28,.24,1.21),(s*.33,.26,1.09),(s*.40,.24,1.025)],[.09,.13,.14],material,.018)

def cloak(name,material,length=.45,one_side=False):
    n=40;v=[]
    amin=.58 if not one_side else .32;amax=2*pi-.58 if not one_side else 2.85
    for j in range(6):
        t=j/5
        for i in range(n+1):
            a=amin+(amax-amin)*i/n
            r=.20+.61*t
            x=r*sin(a);y=(.18+.38*t)*cos(a)-.005
            z=1.93-length*(t**1.65)+.025*sin(a*5)*t+.025*cos(a*9)*t*t
            v.append((x,y,z))
    f=[]
    for j in range(5):
        for i in range(n):k=j*(n+1)+i;f.append((k,k+1,k+n+2,k+n+1))
    mesh(name,v,f,material,2,.018)
    line(name+'_hem',v[-(n+1):],.009,'cream' if TAG!='Touma' else 'rope')
    return v[-(n+1):]

def belt_cords(material='cream',count=2):
    for j in range(count):
        pts=[(.374*sin(a),.281*cos(a),1.23+j*.046+.012*sin(2*a)) for a in [2*pi*i/100 for i in range(101)]];rope('Twisted_belt_'+str(j),pts,.02,material)

def pouch(name,x,y,z,material='leather',size=1):
    pts=[(x-.09*size,y,z-.10*size),(x+.09*size,y,z-.10*size),(x+.10*size,y,z+.08*size),(x-.10*size,y,z+.08*size)]
    panel(name+'_body',pts,material,.085*size)
    outline=[(x-.09*size,y+.052*size,z+.09*size),(x+.09*size,y+.052*size,z+.09*size),(x+.072*size,y+.07*size,z-.007*size),(x,y+.08*size,z-.037*size),(x-.07*size,y+.07*size,z-.007*size)]
    panel(name+'_flap',outline,material,.014)
    line(name+'_stitch',pts,.004,'rope',True);disk(name+'_snap',(x,y+.091*size,z+.006*size),.016*size,.008,'gold')

def buckle(name,x,y,z,w=.12,h=.075):
    line(name,[(x-w,y,z-h),(x+w,y,z-h),(x+w,y,z+h),(x-w,y,z+h)],.014,'gold',True)
    line(name+'_tongue',[(x,y+.008,z),(x+w*.85,y+.008,z)],.010,'gold')

def weapon(name,base,tip,material='leather',blade=False):
    a=Vector(base);b=Vector(tip);d=(b-a).normalized();mid=a+(b-a)*.72
    tube(name+'_sheath',[a,mid],[.047,.042],material,n=12)
    tube(name+'_grip',[mid,b],[.035,.035],'dark',n=12)
    for j in range(6):
        c=mid+(b-mid)*j/6;line(name+'_binding_'+str(j),[c+Vector((-.034,.031,0)),c+Vector((.034,.031,0))],.007,'cream')
    tube(name+'_guard',[mid-Vector((.07,0,0)),mid+Vector((.07,0,0))],[.02,.02],'metal',n=12)
    disk(name+'_pommel',b,.045,.04,'metal')

def staff(cfg):
    x=.91;y=.05
    tube('Pilgrim_staff' if TAG=='Gaku' else 'Bamboo_travel_staff',[(x,y,.035),(x,y,2.58 if TAG=='Gaku' else 2.08)],[.039,.039],'leather' if TAG=='Gaku' else 'rope',n=16,sub=1)
    for z in ([1.99,2.02,2.05,2.08] if TAG=='Gaku' else [.09,.40,.70,1.05,1.40,1.70,2.03]):band('Staff_node',z,.044,.045,.009,'rope' if TAG=='Gaku' else 'gold',x=x,y=y)
    for j in range(12):band('Staff_grip',1.33+j*.026,.043,.043,.008,'dark',x=x,y=y)
    if TAG=='Touma':
        line('Staff_charm_cord',[(x,0,1.33),(x-.1,.05,1.20),(x-.12,.09,1.11)],.008,'rope');uvball('Staff_jade_bead',(x-.12,.09,1.12),(.035,.032,.045),'accent');tassel('Staff_tassel',(x-.12,.09,1.06),'rope',.85)

def character_gear(cfg):
    name=cfg['name']
    if name=='Raku':
        M['inner']=mat('Raku / charcoal inner robe','302F2C');replace_material('Under_kimono','inner');jacket(cfg)
        replace_material('Forearm_wrap','dark');replace_material('Shin_wrap','dark')
        belt_cords('accent',2);buckle('Bronze_belt_plate',0,.302,1.255,.14,.062)
        panel('Belt_plate',[(-.14,.294,1.19),(.14,.294,1.19),(.14,.294,1.32),(-.14,.294,1.32)],'gold',.02)
        for x in (-.117,.117):
            for z in (1.212,1.296):disk('Buckle_rivet',(x,.325,z),.009,.005,'dark')
        for j in range(2):line('Brawler_crest',[(.065,.333,1.228+j*.025),(0,.335,1.25+j*.025),(-.065,.333,1.228+j*.025)],.009,'dark')
        pouch('Hip_pouch',-.34,.24,1.16,size=.85)
        ribbon('Indigo_sash_end',[(.06,.30,1.19),(.10,.31,1.01),(.07,.32,.91)],[.055]*3,'accent')
        for side in (-1,1):
            line('Sleeve_ember_emblem',[(side*.45,.19,1.56),(side*.54,.225,1.65),(side*.65,.19,1.56)],.019,'cream')
            line('Sleeve_ember_bar',[(side*.45,.22,1.53),(side*.67,.19,1.53)],.013,'cream')
    elif name=='Izumi':
        M['cloak']=mat('Izumi / frost blue cape','647E9A');cloak('Frost_shoulder_cape','cloak',.43)
        for side in (-1,1):
            ribbon('High_cape_collar_'+str(side),[(side*.18,.01,1.77),(side*.27,.035,1.92)],[.095,.105],'cloak',.016)
            diamond('Cloak_snow_glyph',side*.49,.175,1.57,.075,'cream')
            diamond('Bracer_snow_glyph',side*.70,.209,1.15,.050,'cream')
        diamond('Throat_clasp',0,.255,1.68,.080,'metal');clasp('Belt_swirl_medallion',(0,.307,1.26),.073,'metal');belt_cords('cream')
        tassel('Blue_braid_pendant',(.12,.32,1.16),'accent',1.0);tassel('White_belt_tassel',(.12,.33,1.04),'cream',.85)
        weapon('Scout_dagger',(-.37,.05,.95),(-.66,.02,1.42));tassel('Dagger_charm',(-.66,.03,1.35),'accent',.65)
        for x in (-.27,-.35):diamond('Trouser_snow',x,.251,.82,.07,'cream')
    elif name=='Gaku':
        # cloth headband wraps scalp, with two tails behind the ear
        loft('Ivory_headband',[(0,-.025,2.51,.504,.408),(0,-.025,2.56,.507,.412),(0,-.025,2.63,.493,.409)],'cream',64,sub=1)
        for i in range(2):ribbon('Headband_tail_'+str(i),[(.41,-.22,2.52),(.53,-.26,2.35),(.59+i*.04,-.23,2.19-i*.07)],[.045,.05,.038],'cream')
        replace_material('Kimono_lapel_cross','dark');belt_cords('cream');staff(cfg)
        panel('Pilgrim_front_apron',[(-.30,.281,1.2),(.27,.28,1.20),(.25,.29,.95),(-.28,.29,.92)],'dark',.015)
        ribbon('White_waist_tie',[(-.24,.30,1.25),(-.31,.32,1.04),(-.39,.31,.85)],[.042,.05,.046],'cream')
        line('Travel_ring',[(-.20+.065*cos(a),.33,1.11+.075*sin(a)) for a in [2*pi*i/48 for i in range(48)]],.018,'gold',True)
    elif name=='Shiro':
        cloak('Moon_shoulder_mantle','accent',.29,True)
        moon('Mantle_moon',.50,.176,1.63,.085,'cream');clasp('Moon_clasp',(.22,.29,1.76),.086,'metal');moon('Clasp_moon',.22,.333,1.76,.065,'dark')
        tassel('Shoulder_silver_tassel',(.31,.30,1.64),'cream',.75)
        for side in (-1,1):
            ribbon('Long_split_coat_'+str(side),[(side*.22,.26,1.20),(side*.27,.30,.98),(side*.39,.29,.67),(side*.51,.19,.37)],[.10,.13,.13,.07],'cream',.02)
            line('Coat_purple_piping_'+str(side),[(side*.32,.274,1.20),(side*.40,.317,.98),(side*.52,.307,.67),(side*.58,.20,.37)],.008,'accent')
            diamond('Wrist_silver_lozenge',side*.69,.21,1.15,.067)
            for j in range(2):band('Silver_bracer_band',1.08+j*.14,.138,.153,.012,'metal',x=side*.69,y=.05)
            moon('Coat_moon_'+str(side),side*.36,.329,.82,.077,'accent')
        replace_material('Forearm_wrap','accent');replace_material('Shin_wrap','accent');replace_material('Foot','accent');replace_material('Tabi_toe','accent')
        belt_cords('accent',2);diamond('Belt_diamond',0,.32,1.23,.055);tassel('Purple_belt_tassel',(0,.32,1.15),'accent',.8)
        weapon('Moon_duelist_sword',(-.70,.10,.51),(-.47,.16,1.10),'accent');tassel('Sword_tassel',(-.60,.13,.71),'accent',.8)
    elif name=='Banji':
        M['inner']=mat('Banji / forest inner shirt','2F4338');replace_material('Under_kimono','inner');jacket(cfg,collar=True)
        replace_material('Forearm_wrap','leather');replace_material('Shin_wrap','cream')
        ribbon('Diagonal_tool_harness',bez((.31,.24,1.80),(.24,.34,1.62),(-.14,.34,1.37),(-.32,.28,1.30)),[.059]*20,'leather',.022)
        for i in range(8):disk('Harness_stud',(.25-i*.071,.365,1.70-i*.049),.011,.006,'gold')
        buckle('Harness_buckle',.22,.377,1.66,.075,.061);buckle('Belt_buckle',.04,.30,1.26,.073,.055)
        clasp('Chest_clockwork',(-.27,.30,1.70),.076,'gold')
        for side in (-1,1):
            for j in range(2):band('Brass_wrist_cuff',1.08+j*.16,.14,.15,.021,'gold',x=side*.69,y=.055)
            clasp('Wrist_gear_'+str(side),(side*.70,.23,1.16),.055,'gold')
        pouch('Thigh_tool_satchel',.34,.20,.84,'pants',1.05)
        for j in range(2):
            x=-.25-j*.13;tube('Tool_holster',[(x,.30,1.12),(x,.31,1.35)],[.049,.051],'leather',n=12)
            tube('Brass_tool_handle',[(x,.30,1.28),(x,.31,1.51+j*.04)],[.022,.025],'gold',n=12)
            disk('Tool_top',(x,.31,1.51+j*.04),.043,.028,'metal')
        x=-.42;z=1.06;disk('Pocket_clock_body',(x,.30,z),.125,.055,'leather');disk('Pocket_clock_face',(x,.362,z),.108,.012,'gold')
        for a in [2*pi*i/12 for i in range(12)]:disk('Clock_hour_rivet',(x+.089*cos(a),.383,z+.089*sin(a)),.007,.004,'dark')
        line('Clock_hand',[(x-.053,.385,z+.035),(x,.386,z),(x+.019,.385,z+.075)],.008,'dark')
        for i in range(10):disk('Freckle_'+str(i),((-.29 if i<5 else .17)+(i%5)*.025,.324 if i%5<3 else .30,2.29+.032*sin(i)),.005,.002,'skin_shadow')
    elif name=='Touma':
        hem=cloak('Wanderer_moss_cloak','accent',1.06)
        for i,p in enumerate(hem[::2]):line('Cloak_fringe_'+str(i),[p,(p[0]+.013,p[1],p[2]-.05-.025*sin(i))],.006,'rope')
        # front draped shawl fold passes over one shoulder
        ribbon('Draped_shawl_front',[(.35,.18,1.82),(.16,.285,1.70),(-.21,.27,1.65),(-.55,.15,1.55)],[.085,.075,.13,.15],'accent')
        for j in range(12):line('Shawl_running_stitch',[(.28-j*.065,.33,1.66-j*.01),(.25-j*.065,.33,1.66-j*.01)],.004,'cream')
        staff(cfg);belt_cords('rope');pouch('Travel_flat_case',.26,.29,1.06,'leather',.8)
        uvball('Drawstring_gourd_bag',(-.24,.28,1.04),(.086,.060,.108),'rope');tassel('Bag_tie',(-.24,.34,1.15),'rope',.38)
        # straw hat hangs vertically at the hip; woven radial ribs and concentric hoops
        x=-.54;y=.13;z=1.12;r=.245
        v=[(x,y+.12,z)]+[(x+r*cos(a),y,z+r*sin(a)) for a in [2*pi*i/48 for i in range(48)]]
        mesh('Travel_straw_hat',v,[(0,i+1,(i+1)%48+1) for i in range(48)],'rope',0,.015)
        for j in range(1,8):
            rr=r*j/8;line('Hat_weave_ring',[(x+rr*cos(a),y+.12*(1-j/8)+.014,z+rr*sin(a)) for a in [2*pi*i/64 for i in range(64)]],.004,'cream',True)
        for a in [2*pi*i/24 for i in range(24)]:line('Hat_radial_rib',[(x,y+.132,z),(x+r*cos(a),y+.01,z+r*sin(a))],.004,'leather')
    elif name=='Roan':
        belt_cords('cream',3)
        # short ragged shearling edging follows lapels and shoulder openings
        for side in (-1,1):
            pts=bez((side*.18,.15,1.83),(side*.22,.26,1.70),(-side*.14,.30,1.48),(-side*.27,.24,1.40),25)
            for i,p in enumerate(pts):
                if i%2==0:hairlock('Shearling_lapel_%s_%s'%(side,i),[p,(p[0]+.017,p[1]+.018,p[2]-.016),(p[0]-.012,p[1]+.028,p[2]-.036),(p[0]+.018,p[1]+.02,p[2]-.05)],.028,'cream',.4)
            for i in range(12):
                x=side*(.37+.13*cos(i*pi/11));z=1.68+.12*sin(i*pi/11)
                hairlock('Shoulder_fur',[(x,.08,z),(x+side*.025,.10,z),(x+side*.04,.12,z-.015),(x+side*.04,.11,z-.055)],.03,'cream',.4)
            ribbon('Fur_vest_hem_'+str(side),[(side*.17,.22,1.2),(side*.22,.26,1.05),(side*.36,.25,.94)],[.13,.16,.16],'cloth')
            for i in range(10):line('Hem_fray',[(side*.17+side*i*.03,.267,.96),(side*.18+side*i*.03,.273,.92-.025*sin(i))],.009,'cream')
        ribbon('Rust_belt_tail',[(-.14,.32,1.27),(-.28,.35,1.08),(-.35,.31,.85)],[.06,.075,.074],'accent')
        rope('Rust_knot',bez((-.14,.32,1.30),(-.35,.39,1.35),(-.37,.39,1.15),(-.17,.32,1.23)),.029,'accent')
        for j in range(2):
            x=.37+j*.10;tube('Tonfa_shaft_'+str(j),[(x,.29,.96),(x+.045,.24,1.49)],[.038,.038],'leather',n=12)
            tube('Tonfa_cross_handle_'+str(j),[(x,.33,1.18),(x-.18,.33,1.18)],[.025,.025],'rope',n=12)
            for z in (.98,1.47):tube('Tonfa_steel_end',[(x,.29,z),(x,.29,z+.05)],[.042,.042],'metal',n=12)
        replace_material('Bracer_lace','accent')
    elif name=='Nagi':
        replace_material('Kimono_lapel_cross','accent');replace_material('Kimono_lapel_return','accent');replace_material('Forearm_wrap','pants');replace_material('Shin_wrap','pants')
        belt_cords('accent',2)
        ribbon('Seafoam_sash_streamer',bez((-.2,.25,1.25),(-.45,.20,1.04),(-1.0,-.04,1.12),(-1.32,.05,.58)),[.065+.06*sin(pi*i/19) for i in range(20)],'accent')
        ribbon('Front_seafoam_tie',[(-.19,.30,1.23),(-.23,.33,1.04),(-.27,.31,.84)],[.05,.066,.055],'accent')
        for side in (-1,1):
            ribbon('Hanging_kimono_sleeve_'+str(side),[(side*.48,.13,1.66),(side*.66,.19,1.44),(side*.70,.16,1.20)],[.12,.21,.16],'cloth',.017)
            line('Seafoam_sleeve_border',[(side*.58,.22,1.60),(side*.81,.22,1.38),(side*.85,.19,1.22),(side*.57,.19,1.21)],.018,'accent')
        # sealed scroll case across back, with dark end caps, ropes and jade charm
        a=Vector((.46,-.30,.99));b=Vector((.55,-.29,2.12));tube('Courier_scroll_case',[a,b],[.13,.13],'cream',n=32)
        for c in (a,b):tube('Scroll_case_cap',[c-Vector((0,0,.025)),c+Vector((0,0,.025))],[.145,.145],'dark',n=32)
        for z in (1.14,1.97):
            pts=[(.50+.147*sin(a),-.29+.145*cos(a),z) for a in [2*pi*i/80 for i in range(81)]];rope('Scroll_case_lashing',pts,.018,'rope')
        rope('Courier_shoulder_rope',bez((.48,-.31,1.97),(.49,.31,1.98),(.22,.37,1.54),(.21,.28,1.20)),.035,'rope')
        line('Jade_charm_rope',[(.66,-.27,1.98),(.76,-.23,1.79),(.76,-.22,1.63)],.008,'rope');uvball('Jade_charm_bead',(.76,-.22,1.69),(.047,.04,.052),'accent');tassel('Courier_jade_tassel',(.76,-.22,1.60),'accent',1.0)
        for side in (-1,1):
            for row in range(2):
                for j in range(3):
                    x=side*(.45+j*.065);z=1.43+row*.054
                    line('Sleeve_wave_pattern',[(x+.048*cos(a),.246,z+.037*sin(a)) for a in [pi*i/16 for i in range(17)]],.007,'accent')
    elif name=='Kuren':
        jacket(cfg,'accent',True);belt_cords('accent',3);replace_material('Forearm_wrap','dark');replace_material('Bracer_lace','accent');replace_material('Shin_wrap','dark')
        # overlapping rounded copper lamellar lappets, two staggered rows
        M['copper']=mat('Kuren / aged copper plates','91603A',.62,.43)
        for row in range(2):
            for i in range(9):
                a=-1.55+i*.39+(row*.13);x=.40*sin(a);y=.29*cos(a);z=1.17-row*.13
                w=.073;outline=[(x-w,y,z+.065),(x+w,y,z+.065),(x+w*.9,y+.022,z-.055),(x+w*.45,y+.035,z-.095),(x-w*.45,y+.035,z-.095),(x-w*.9,y+.022,z-.055)]
                panel('Copper_scale_%s_%s'%(row,i),outline,'copper',.018)
                line('Copper_scale_edge',outline,.004,'gold',True)
                for dx in (-.04,.04):disk('Scale_rivet',(x+dx,y+.024,z+.035),.008,.005,'gold')
        line('Bell_loop',[(-.27+.035*cos(a),.345,1.20+.04*sin(a)) for a in [2*pi*i/32 for i in range(32)]],.007,'gold',True)
        uvball('Festival_bell',(-.27,.35,1.10),(.067,.055,.069),'gold');line('Bell_slot',[(-.32,.40,1.1),(-.22,.40,1.1)],.005,'dark');disk('Bell_sound_hole',(-.27,.403,1.105),.012,.003,'dark');tassel('Festival_waist_tassel',(-.12,.34,1.20),'accent',1.15)
        for side in (-1,1):
            for j in range(2):
                rope('Frog_fastening',[(side*.23,.31,1.66),(side*.18,.33,1.70),(side*.14,.32,1.67),(side*.18,.33,1.63),(side*.23,.31,1.66)],.010,'accent')
            tassel('Vest_frog_tassel',(side*.22,.32,1.63),'accent',.48)
        # folded war fan in hip case
        pouch('Fan_holster',-.42,.12,1.18,'leather',.66)
        for i in range(7):tube('Folded_fan_rib_'+str(i),[(-.43+i*.017,.12,1.2),(-.46+i*.020,.12,1.56)],[.009,.012],'cream',n=6)


def surface_finish():
    # Small packed painted-fiber maps are exported, not Blender-only noise shaders.
    for key in ['cloth','pants','accent','cream','leather','hair','rope','gold']:
        material=M[key]; base=np.array(material.diffuse_color[:3]); n=256
        rng=np.random.default_rng(40+len(key)); yy,xx=np.mgrid[0:n,0:n]
        coarse=rng.normal(0,1,(32,32)); coarse=np.repeat(np.repeat(coarse,8,axis=0),8,axis=1)
        grain=rng.normal(0,1,(n,n))
        amt=.04 if key=='hair' else .075
        val=1+amt*(coarse*.6+grain*.35)+.018*np.sin(xx*2.7)+.012*np.sin(yy*2.3)
        arr=np.ones((n,n,4),dtype=np.float32);arr[:,:,:3]=np.clip(base[None,None,:]*val[:,:,None],0,1)
        im=bpy.data.images.new(TAG+'_'+key+'_painted_fiber',width=n,height=n);im.colorspace_settings.name='Linear Rec.709';im.pixels.foreach_set(arr.ravel());im.pack()
        nodes=material.node_tree.nodes;tex=nodes.new('ShaderNodeTexImage');tex.image=im;material.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    for ob in C.objects:
        if ob.type!='MESH':continue
        if ob.data.uv_layers:uv=ob.data.uv_layers.active
        else:uv=ob.data.uv_layers.new(name='Surface_UV')
        for poly in ob.data.polygons:
            ax=max(range(3),key=lambda j:abs(poly.normal[j]))
            axes=[j for j in range(3) if j!=ax]
            for li in poly.loop_indices:
                co=ob.matrix_world@ob.data.vertices[ob.data.loops[li].vertex_index].co
                uv.data[li].uv=(co[axes[0]]*2.0,co[axes[1]]*2.0)

def final_proportions(head_parts,cfg):
    for ob in list(C.objects):
        ishead=(ob in head_parts and not ob.name.endswith('__Neck')) or any(k in ob.name for k in ['Headband','headband','Freckle'])
        def transform(v):
            v=Vector(v)
            if ishead:return Vector((v.x*1.07,v.y*1.07,(v.z-1.95)*1.07+1.56))
            return Vector((v.x*(1.025 if cfg.get('slim') else 1.12)*(1+.12*max(0,min(1,(1.2-v.z)/.8))),v.y*1.04,v.z*.85))
        # control meshes and paths are edited in world space, preserving transforms
        inv=ob.matrix_world.inverted()
        if ob.type=='MESH':
            for v in ob.data.vertices:v.co=inv@transform(ob.matrix_world@v.co)
        elif ob.type=='CURVE':
            for sp in ob.data.splines:
                for p in sp.points:p.co=(*(inv@transform(ob.matrix_world@Vector(p.co[:3]))),1)

def studio(cfg):
    global C
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    C=bpy.data.collections.new('STUDIO • excluded from GLB');scene.collection.children.link(C)
    M['ground']=mat('Studio / warm ivory','E6DFCF',0,.85)
    mesh('Ground',[(-200,-200,-.011),(200,-200,-.011),(200,200,-.011),(-200,200,-.011)],[(0,1,2,3)],'ground')
    world=bpy.data.worlds.new('Studio world');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.60,.66,.74,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35;scene.world=world
    for name,loc,power,size in [('Key',(3,4,6),500,4),('Fill',(-4,3,3),180,4),('Rim',(0,-4,5),350,3)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);C.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()
    d=bpy.data.cameras.new('Portrait');o=bpy.data.objects.new('Portrait',d);C.objects.link(o);scene.camera=o;d.type='ORTHO';d.ortho_scale=3.5
    set_camera('three_quarter')
    scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False
    scene.render.resolution_x=800;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.render.image_settings.file_format='PNG'
    scene.render.film_transparent=False

def set_camera(view):
    o=bpy.context.scene.camera
    loc={'three_quarter':(3.1,8,2.95),'front':(0,9,2.7),'side':(9,0,2.7),'back':(0,-9,2.7)}[view];o.location=loc;o.rotation_euler=(Vector((0,0,1.47))-o.location).to_track_quat('-Z','Y').to_euler()

def save_export(cfg,render=True):
    scene=bpy.context.scene;name=cfg['name'].lower();path=ROOT/'blend'/f'{name}.blend'
    # presentation and naming stay editable; source reference stored as packed image.
    ref=next((ROOT/'references').glob('*-'+name+'-*.png'));im=bpy.data.images.load(str(ref));im.pack();im.use_fake_user=True
    scene['Source reference']=ref.name;scene['Status']='Static concept interpretation; no rig or animation';scene['Authoring units']='meters; +Y forward; origin at ground between feet'
    for o in bpy.data.collections[TAG+' • editable character'].objects:o['part']=o.name.split('__')[-1]
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.data.collections[TAG+' • editable character'].objects:o.select_set(True)
    bpy.context.view_layer.objects.active=next(o for o in bpy.context.selected_objects if o.type=='MESH')
    bpy.ops.object.convert(target='MESH')
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'glb'/f'{name}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
    if render:
        scene.render.filepath=str(ROOT/'previews'/f'{name}_three_quarter.png');bpy.ops.render.render(write_still=True)

CONFIGS=[
 dict(name='Sen',style='sen',hair='84351C',hair_hi='A44C28',cloth='31586B',pants='34343A',accent='AA7735',skin='C88753',pant_style='hakama',tabi=True),
 dict(name='Raku',style='shag',hair='7E211C',hair_hi='AC3524',cloth='B4452C',pants='D6C7A6',accent='333F57',skin='D99762',upper='short',bracer=False,bulk=1.09,head_width=1.04),
 dict(name='Izumi',style='swept',hair='C3C8D0',hair_hi='F0EBDD',cloth='DFD8C5',pants='35445E',accent='344D6C',skin='DDA879',iris='788697',tabi=True,upper='short',head_width=.97,slim=True),
 dict(name='Gaku',style='crop',hair='292725',hair_hi='56442E',cloth='C28A24',pants='656346',accent='373434',skin='B47139',shadow='794525',upper='short',head_width=1.08,bracer=False,staff=True,bulk=1.1),
 dict(name='Shiro',style='bob',hair='DAD0C5',hair_hi='F4E8D7',cloth='DDD2BC',pants='3A2E43',accent='413047',skin='D4A179',iris='594339',slim=True,head_width=.93,tabi=True,pant_style='baggy'),
 dict(name='Banji',style='spikes',hair='79421E',hair_hi='B36B31',cloth='B68428',pants='33483D',accent='52402E',skin='CB8D52',upper='short',iris='937032',head_width=1.0),
 dict(name='Touma',style='pony',hair='242626',hair_hi='53504A',cloth='D1C5A8',pants='333532',accent='676B4D',skin='C89865',upper='wide',iris='655B3E',slim=True,head_width=.93,staff=True,rope_soles=True,bracer=False),
 dict(name='Roan',style='curly',hair='2C2924',hair_hi='62503C',cloth='3F4E39',pants='883F28',accent='AF5937',skin='BA7845',head_width=1.02,rope_soles=True,bracer=False,bulk=1.1),
 dict(name='Nagi',style='wave',hair='9CAD9E',hair_hi='D3D8BD',cloth='BD6B53',pants='2E4357',accent='9CAFA0',skin='915D38',shadow='674127',iris='366D70',upper='wide',head_width=.94,slim=True,rope_soles=True,bracer=False),
 dict(name='Kuren',style='bun',hair='38292B',hair_hi='6E4A42',cloth='D1C3A2',pants='573843',accent='643747',skin='CE9A63',upper='short',head_width=1.05,bulk=1.12)
]

def build(cfg,render=True):
    setup(cfg);head(cfg);hair(cfg)
    head_parts=set(C.objects)
    body(cfg)
    if cfg['name']=='Sen':sen_gear()
    else:character_gear(cfg)
    surface_finish()
    final_proportions(head_parts,cfg)
    studio(cfg);save_export(cfg,render)
if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    names=args or ['Sen']
    for cfg in CONFIGS:
        if cfg['name'].lower() in [x.lower() for x in names] or 'all' in names:build(cfg)

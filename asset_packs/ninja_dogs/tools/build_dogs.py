"""Reference-led static canine sculptures. Blender 4.3.2; all geometry editable."""
import bpy,math,random,json,sys
from pathlib import Path
from mathutils import Vector, Matrix
P=Path(__file__).resolve().parents[1];TAU=math.tau
DOGS=[
 dict(id='01',name='Kogane',role='Shadow Scout',breed='shiba',body=(.67,.255,.32),hip=(-.49,0,.78),chest=(.30,0,.91),head=(.82,0,1.24),hs=(.31,.30,.30),muzzle=.20,ear=.29,leg=.11,fur=.032,coat=(.42,.105,.020),cream=(.80,.69,.50),scarf=(.006,.012,.035),tail='curl',gear='scout',pose='crouch',scale=.54),
 dict(id='02',name='Daigo',role='Iron Guardian',breed='akita',body=(.72,.39,.44),hip=(-.54,0,.91),chest=(.34,0,1.08),head=(.78,0,1.54),hs=(.38,.35,.36),muzzle=.21,ear=.27,leg=.175,fur=.060,coat=(.39,.19,.068),cream=(.87,.76,.57),scarf=(.014,.017,.020),tail='curl',gear='armor',pose='stand',scale=.64),
 dict(id='03',name='Kage',role='Bramble Ambusher',breed='shepherd',body=(.78,.25,.30),hip=(-.58,0,.90),chest=(.33,0,1.00),head=(.91,0,1.30),hs=(.30,.235,.29),muzzle=.34,ear=.43,leg=.098,fur=.034,coat=(.052,.043,.033),cream=(.25,.19,.115),scarf=(.085,.035,.060),tail='low',gear='leaves',pose='crouch',scale=.62),
 dict(id='04',name='Arashi',role='Storm Tracker',breed='shikoku',body=(.70,.26,.32),hip=(-.50,0,.91),chest=(.30,0,1.08),head=(.77,0,1.58),hs=(.285,.235,.28),muzzle=.29,ear=.34,leg=.105,fur=.041,coat=(.21,.105,.035),cream=(.82,.73,.57),scarf=(.030,.090,.100),tail='curl',gear='tracker',pose='lift',scale=.61),
 dict(id='05',name='Haku',role='Blade Guard',breed='kishu',body=(.72,.24,.30),hip=(-.52,0,.91),chest=(.31,0,1.08),head=(.76,0,1.52),hs=(.28,.23,.28),muzzle=.28,ear=.36,leg=.097,fur=.026,coat=(.86,.81,.69),cream=(.96,.90,.78),scarf=(.021,.035,.074),tail='curl',gear='blade',pose='stand',scale=.61),
 dict(id='06',name='Suzu',role='Ward Keeper',breed='spitz',body=(.56,.29,.34),hip=(-.39,0,.71),chest=(.28,0,.88),head=(.65,0,1.24),hs=(.30,.265,.30),muzzle=.15,ear=.29,leg=.12,fur=.100,coat=(.89,.82,.70),cream=(.98,.92,.82),scarf=(.008,.013,.035),tail='plume',gear='ward',pose='stand',scale=.43),
 dict(id='07',name='Maboro',role='Mirage Weaver',breed='chin',body=(.47,.23,.28),hip=(-.34,0,.62),chest=(.25,0,.72),head=(.56,0,1.08),hs=(.29,.27,.28),muzzle=.075,ear=.34,leg=.070,fur=.085,coat=(.020,.018,.023),cream=(.91,.85,.73),scarf=(.080,.043,.13),tail='silk',gear='mirage',pose='stand',scale=.38),
 dict(id='08',name='Iwa',role='Shield Breaker',breed='mastiff',body=(.85,.43,.47),hip=(-.60,0,.93),chest=(.35,0,1.12),head=(.88,0,1.57),hs=(.38,.35,.39),muzzle=.22,ear=.38,leg=.19,fur=.013,coat=(.40,.22,.095),cream=(.46,.28,.14),scarf=(.023,.033,.079),tail='straight',gear='shield',pose='stand',scale=.69),
 dict(id='09',name='Mine',role='Cliff Runner',breed='husky',body=(.75,.30,.35),hip=(-.52,0,.96),chest=(.34,0,1.10),head=(.84,0,1.51),hs=(.32,.275,.30),muzzle=.25,ear=.33,leg=.115,fur=.069,coat=(.17,.18,.19),cream=(.89,.82,.65),scarf=(.032,.048,.075),tail='curl',gear='climber',pose='rock',scale=.63),
 dict(id='10',name='Hayate',role='Wind Striker',breed='sighthound',body=(.90,.205,.275),hip=(-.64,0,1.10),chest=(.40,0,1.06),head=(1.02,0,1.39),hs=(.285,.18,.235),muzzle=.44,ear=.30,leg=.072,fur=.037,coat=(.023,.020,.025),cream=(.89,.85,.74),scarf=(.020,.035,.075),tail='flow',gear='wind',pose='run',scale=.67),
]
def mat(name,col,metal=0,rough=.7,vertex=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*col,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal
 if vertex:n=m.node_tree.nodes.new('ShaderNodeVertexColor');n.layer_name='FurColor';m.node_tree.links.new(n.outputs['Color'],b.inputs['Base Color'])
 return m

def mesh(name,vs,fs,m,smooth=True,cols=None):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 if m:me.materials.append(m)
 for f in me.polygons:f.use_smooth=smooth
 if cols:
  a=me.color_attributes.new(name='FurColor',type='FLOAT_COLOR',domain='POINT')
  for v,c in zip(a.data,cols):v.color=(*c,1)
 return o

def uv(name,c,s,m=None,seg=32,rings=20):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=c);o=bpy.context.object;o.name=name;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if m:o.data.materials.append(m)
 for f in o.data.polygons:f.use_smooth=True
 return o

def tube(name,ps,rs,m,n=12,sub=0):
 ps=list(map(Vector,ps));rs=[rs]*len(ps) if isinstance(rs,(int,float)) else rs;vs=[];fs=[]
 for j,p in enumerate(ps):
  a=(ps[min(j+1,len(ps)-1)]-ps[max(0,j-1)]).normalized();u=a.cross(Vector((0,0,1)))
  if u.length<.01:u=a.cross(Vector((0,1,0)))
  u.normalize();v=a.cross(u).normalized()
  for k in range(n):vs.append(p+rs[j]*(u*math.cos(k/n*TAU)+v*math.sin(k/n*TAU)))
 for j in range(len(ps)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;fs.append((a,b,b+n,a+n))
 fs+=[tuple(reversed(range(n))),tuple((len(ps)-1)*n+k for k in range(n))];o=mesh(name,vs,fs,m)
 if sub:mo=o.modifiers.new('Flow smoothing','SUBSURF');mo.levels=sub
 return o

def curve(name,ps,m,r=.007):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=2;cu.bevel_depth=r;cu.bevel_resolution=2;sp=cu.splines.new('POLY');sp.points.add(len(ps)-1)
 for v,p in zip(sp.points,ps):v.co=(*p,1)
 o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);cu.materials.append(m);return o

def ribbon(name,ps,width,m,across=(0,0,1),thick=.008):
 ps=list(map(Vector,ps));vs=[];fs=[]
 for i,p in enumerate(ps):
  a=Vector(across);w=width*(1 if i<len(ps)-1 else .78)
  for k in range(5):t=k/4-.5;vs.append(p+a*w*t+Vector((0,.007*math.cos(t*math.pi*2),0)))
 for j in range(len(ps)-1):
  for k in range(4):a=j*5+k;fs.append((a,a+1,a+6,a+5))
 o=mesh(name,vs,fs,m);mo=o.modifiers.new('Woven cloth thickness','SOLIDIFY');mo.thickness=thick;mo=o.modifiers.new('Fabric surface','SUBSURF');mo.levels=1;return o

def band(name,center,rx,ry,width,m,axis='X',start=0,end=TAU):
 c=Vector(center);vs=[];fs=[];n=64
 for j in range(3):
  for k in range(n+1):
   a=start+(end-start)*k/n;off=(j/2-.5)*width
   p=Vector((off,rx*math.cos(a),ry*math.sin(a))) if axis=='X' else Vector((rx*math.cos(a),ry*math.sin(a),off))
   vs.append(c+p)
 for j in range(2):
  for k in range(n):a=j*(n+1)+k;fs.append((a,a+1,a+n+2,a+n+1))
 o=mesh(name,vs,fs,m);mo=o.modifiers.new('Leather thickness','SOLIDIFY');mo.thickness=.014;mo=o.modifiers.new('Softened cut edge','BEVEL');mo.width=.005;mo.segments=2;return o

def torus(name,c,major,minor,m,normal=(0,-1,0)):
 bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=36,minor_segments=10,location=c);o=bpy.context.object;o.name=name;o.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler();o.data.materials.append(m)
 for f in o.data.polygons:f.use_smooth=True
 return o

def box(name,c,s,m,bev=.02):
 bpy.ops.mesh.primitive_cube_add(size=1,location=c);o=bpy.context.object;o.name=name;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 mo=o.modifiers.new('Rounded sewn or forged edges','BEVEL');mo.width=bev;mo.segments=3;mo=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o

def color_at(p,r,noise=True):
 hc=Vector(r['head']);p=hc+Matrix.Rotation(math.radians(8 if r['breed']=='sighthound' else 35),3,'Z')@(Vector(p)-hc) if Vector(p).x>hc.x-.29 and Vector(p).z>hc.z-.28 else Vector(p);x,y,z=p;hs=r['hs'];base=r['coat'];cream=r['cream'];breed=r['breed'];v=0
 if breed in ['shiba','akita','shikoku','husky','shepherd']:
  # Urajiro cheeks, muzzle, chest, belly and stockings; separate dark dorsal saddle.
  chin=hc.z-.07-.18*max(0,(hc.x+.05-x)/.35)
  if x>hc.x-.22 and z<chin and z>hc.z-.43:v=1
  if x>hc.x+.12 and z<hc.z+.025:v=1
  if x>.18 and z<r['chest'][2]+.11 and x<.68 and abs(y)<.22:v=.95
  if z<.28:v=.97
  if -.65<x<.38 and z<r['hip'][2]-.17:v=.9
  for sy in [-1,1]:
   q=(x-(hc.x+.17))**2/(.07**2)+(y-sy*.145)**2/.08**2+(z-(hc.z+.16))**2/.055**2
   if q<1:v=max(v,.95)
  if breed=='akita' and ((x>.15 and z<.98) or z<.53):v=.97
  if breed=='shepherd':
   v*=.55;stripe=math.sin(x*24+z*17+math.sin(z*25)*.7+math.sin(y*30));base=tuple(a*(.65 if stripe>.25 else 2.2) for a in base)
  if breed in ['shikoku','husky'] and z>r['chest'][2]-.02 and x<hc.x-.05:base=tuple(a*.45 for a in base)
 elif breed in ['kishu','spitz']:v=.4+.3*max(0,z/1.8)
 elif breed=='chin':
  v=1 if (abs(y)<.09 and x>hc.x-.10) or (x>hc.x+.11 and z<hc.z-.09) or z<.58 or (.0<x<.46) else 0
 elif breed=='sighthound':
  v=1 if z<.38 or (x>.25 and z<1.0) or (x>hc.x+.12 and z<hc.z+.045) else 0
 elif breed=='mastiff':
  if x>hc.x+.08 and z<hc.z+.09-.20*(abs(y)/hs[1])**1.7:base=(.055,.040,.029)
 col=[a*(1-v)+b*v for a,b in zip(base,cream)]
 if noise:
  g=1+.045*math.sin(x*231+y*173+z*317)+.025*math.sin(x*581-y*473+z*173)
  col=[min(.99,max(.002,c*g)) for c in col]
 # Color the recessed inner ear directly on its sculpted surface.
 if breed not in ['chin','mastiff']:
  t=(z-(hc.z+hs[2]*.64))/r['ear']
  for sign in [-1,1]:
   ey=sign*(hs[1]*.67+.095*t)
   if .08<t<.86 and abs(y-ey)<.085*(1-t) and x>hc.x+.027-.22*t:
    col=[.38,.23,.15]
 return tuple(col)

def sculpt_body(r,M):
 parts=[];hc=Vector(r['head']);hs=r['hs'];bc=(Vector(r['hip'])+Vector(r['chest']))*.5
 if r['breed']=='sighthound':
  rings=[(-.94,1.11,.08,.12),(-.64,1.13,.205,.24),(-.30,1.18,.15,.15),(0,1.11,.19,.22),(.32,1.04,.24,.35),(.58,1.07,.12,.25)];vs=[];fs=[]
  for x,z,ry,rz in rings:
   for k in range(32):a=k/32*TAU;vs.append((x,ry*math.cos(a),z+rz*math.sin(a)))
  for j in range(len(rings)-1):
   for k in range(32):a=j*32+k;b=j*32+(k+1)%32;fs.append((a,b,b+32,a+32))
  fs.extend([tuple(reversed(range(32))),tuple((len(rings)-1)*32+k for k in range(32))]);parts.append(mesh('SCULPT | tucked sighthound torso',vs,fs,None))
 else:parts.append(uv('SCULPT | ribcage',bc,r['body']))
 parts.append(uv('SCULPT | chest',r['chest'],(.35,r['body'][1]*1.05,r['body'][2]*1.12)))
 parts.append(uv('SCULPT | rump',r['hip'],(.34,r['body'][1]*.94,r['body'][2]*.90)))
 neckstart=Vector(r['chest'])+Vector((.09,0,.07));neckend=hc+Vector((-.06,0,-.09))
 parts.append(tube('SCULPT | sloping canine neck',[neckstart,neckstart.lerp(neckend,.5),neckend],[hs[1]*1.15,hs[1]*.99,hs[1]*.85],None,24))
 if r['breed']=='spitz':parts.append(uv('SCULPT | full spitz ruff',hc+Vector((-.13,0,-.18)),(.34,.34,.40)))
 parts.append(uv('SCULPT | skull',hc,hs))
 for sy in [-1,1]:parts.append(uv('SCULPT | cheek',(hc.x+.08,sy*hs[1]*.49,hc.z-.06),(hs[0]*.78,hs[1]*.66,hs[2]*.67)))
 mu=r['muzzle'];parts.append(uv('SCULPT | tapered muzzle',(hc.x+hs[0]*.70+mu*.25,0,hc.z-.07),(mu*.79+.04,hs[1]*.62,hs[2]*.37)))
 parts.append(uv('SCULPT | lower jaw',(hc.x+hs[0]*.65+mu*.19,0,hc.z-(.26 if r['breed']=='husky' else .15)),(mu*.75+.05,hs[1]*.55,(.040 if r['breed']=='husky' else .065) if r['breed']!='mastiff' else .13)))
 limbs=[]
 for back in [False,True]:
  for sy in [-1,1]:
   thick=r['leg'];y=sy*(r['body'][1]*.74);x=-.51 if back else .36;top=r['hip'][2] if back else r['chest'][2]
   if back:ps=[(x,y,top), (x+.14,y,.56), (x-.12,y,.29),(x-.14,y,.14)]
   else:ps=[(x,y,top),(x-.075,y,.58),(x+.04,y,.23),(x+.075,y,.13)]
   if r['pose']=='crouch':
    if back:ps[-2]=(-.80,y,.28);ps[-1]=(-.87,y,.12)
    else:ps[-2]=(.70,y,.23);ps[-1]=(.81,y,.13)
   if r['pose']=='crouch' and not back:
    ps[-2]=(.70 if sy==-1 else .55,y*1.15,.23);ps[-1]=(.81 if sy==-1 else .63,y*1.22,.13)
   if r['pose']=='lift' and not back and sy==1:ps=[(.37,y,top),(.55,y,.76),(.83,y,.61),(.76,y,.46)]
   if r['pose']=='rock' and not back and sy==-1:ps=[(.39,y,top),(.54,y,.83),(.82,y,.57),(.90,y,.46)]
   if r['pose']=='run':
    if not back and sy==-1:ps=[(.40,y,1.05),(.68,y,.69),(1.19,y,.38),(1.42,y,.20)]
    elif not back:ps=[(.39,y,1.05),(.76,y,.83),(.98,y,.72),(.84,y,.56)]
    elif sy==-1:ps=[(-.61,y,1.04),(-.41,y,.78),(-1.11,y,.40),(-1.40,y,.21)]
    else:ps=[(-.60,y,1.04),(-.25,y,.74),(-.56,y,.47),(-.41,y,.35)]
   parts.append(tube('SCULPT | shaped leg',ps,[thick*1.55,thick,thick*.60,thick*.63],None,20))
   parts.append(uv('SCULPT | shoulder or thigh',ps[0],(thick*1.65,thick*1.18,thick*2.1)))
   paw=Vector(ps[-1])+Vector((.06,0,-.028));parts.append(uv('SCULPT | padded paw',paw,(thick*1.2,thick*.98,thick*.70)))
   for k in range(4):parts.append(uv('SCULPT | toe',paw+Vector((thick*.66,(k-1.5)*thick*.43,-.025)),(thick*.66,thick*.31,thick*.48),seg=16,rings=12))
   limbs.append((back,sy,ps,paw))
 if r['breed']=='mastiff':
  for sy in [-1,1]:parts.append(uv('SCULPT | heavy jowl',hc+Vector((hs[0]*.70,sy*.12,-.18)),(.16,.14,.22)))
 # Ear volumes are joined into the head; inner panels remain separate editable meshes.
 for sy in [-1,1]:
  if r['breed'] not in ['chin','mastiff','sighthound']:
   c=hc+Vector((-.055,sy*hs[1]*.67,hs[2]*.64));height=r['ear'];vs=[c+Vector((.11,-sy*.115,-.03)),c+Vector((-.13,-sy*.085,0)),c+Vector((-.12,sy*.105,0)),c+Vector((.09,sy*.12,-.02)),c+Vector((-.11,sy*.095,height))];parts.append(mesh('SCULPT | alert ear',vs,[(0,1,2,3),(0,4,1),(1,4,2),(2,4,3),(3,4,0)],None))
  elif r['breed']=='chin':
   c=hc+Vector((-.045,sy*hs[1]*.84,hs[2]*.37));ps=[c,c+Vector((.015,sy*.11,-.14)),c+Vector((.025,sy*.10,-r['ear']))];parts.append(tube('SCULPT | drooping ear',ps,[.13,.145,.065] if r['breed']=='mastiff' else [.10,.12,.07],None,16))
 # Turn the head toward the viewer while keeping the torso in its reference stance.
 R=Matrix.Rotation(math.radians(-8 if r['breed']=='sighthound' else -35),3,'Z')
 for ob in parts:
  if any(n in ob.name for n in ['skull','cheek','muzzle','jaw','ear','jowl']):
   for v in ob.data.vertices:
    world=ob.matrix_world@v.co;v.co=ob.matrix_world.inverted()@(hc+R@(world-hc))
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name='ANATOMY | unified canine skin';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 mo=o.modifiers.new('Sculpt union','REMESH');mo.mode='VOXEL';mo.voxel_size=.013 if r['breed']!='mastiff' else .017;mo.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=mo.name)
 mo=o.modifiers.new('Relax anatomical transitions','SMOOTH');mo.factor=1.0;mo.iterations=5;bpy.ops.object.modifier_apply(modifier=mo.name)
 mo=o.modifiers.new('Sculpt surface economy','DECIMATE');mo.ratio=.48;bpy.ops.object.modifier_apply(modifier=mo.name)
 o.data.materials.clear();o.data.materials.append(M['fur']);a=o.data.color_attributes.new(name='FurColor',type='FLOAT_COLOR',domain='POINT')
 for v,c in zip(o.data.vertices,a.data):c.color=(*color_at(v.co,r),1)
 for f in o.data.polygons:f.use_smooth=True
 return o,limbs

def fur_groom(body,r,M):
 random.seed(230+int(r['id']));vs=[];fs=[];cols=[];body.data.calc_loop_triangles();tris=list(body.data.loop_triangles);weights=[max(t.area,0) for t in tris];count=19000 if r['fur']>.05 else 15000
 if r['breed']=='mastiff':count=4500
 for tri in random.choices(tris,weights=weights,k=count):
  a,b,c=[body.data.vertices[i].co for i in tri.vertices];u=random.random();v=random.random()
  if u+v>1:u=1-u;v=1-v
  p=a+(b-a)*u+(c-a)*v;n=tri.normal
  # Short facial fur keeps the eyes, nose and muzzle readable.
  h=Vector(r['head']);face=p.x>h.x+.12 and p.z>h.z-.20
  length=r['fur']*random.uniform(.6,1.4)*(.25 if face else 1)
  if p.z<.24:length*=.35
  flow=Vector((-.65,0,-.55)) if p.z>.65 else Vector((.02,0,-1))
  if p.x>h.x-.15:flow=Vector((-.3,.25*(1 if p.y>0 else -1),-.7))
  tang=flow-n*flow.dot(n)
  if tang.length<.1:tang=Vector((1,0,0))-n*n.x
  tang.normalize();wide=n.cross(tang).normalized();width=length*random.uniform(.065,.13);start=len(vs);shade=random.uniform(.90,1.09)
  # A curved, tapered surface clump; surface-facing base avoids stacked spikes.
  for j in range(4):
   t=j/3;cen=p+tang*length*t+n*(.002+length*.15*math.sin(t*math.pi*.75));w=width*(1-t)**.75
   for s in [-1,0,1]:
    q=cen+wide*w*s+n*(length*.025*(1-abs(s))*math.sin(t*math.pi));vs.append(q);cols.append(tuple(min(.99,c*shade) for c in color_at(p,r)))
  for j in range(3):
   for k in range(2):a=start+j*3+k;fs.append((a,a+1,a+4,a+3))
 return mesh('FUR | groomed tapered surface clumps',vs,fs,M['fur'],True,cols)

def face(r,M):
 h=Vector(r['head']);sx,sy,sz=r['hs'];breed=r['breed'];mu=r['muzzle']
 # Fine inner ears fit inside actual ear volumes.
 if False:
  for s in [-1,1]:
   c=h+Vector((-.055,s*sy*.67,sz*.64));pts=[c+Vector((.102,-s*.077,.018)),c+Vector((.093,s*.080,.010)),c+Vector((-.080,s*.074,r['ear']*.82))];o=mesh('FACE | velvet inner ear',pts,[(0,1,2)],M['inner'],True);mo=o.modifiers.new('Inner ear soft thickness','SOLIDIFY');mo.thickness=.012;mo=o.modifiers.new('Inner ear softened corners','BEVEL');mo.width=.016;mo.segments=3
 body=bpy.data.objects['ANATOMY | unified canine skin'];R=Matrix.Rotation(math.radians(-8 if r['breed']=='sighthound' else -35),3,'Z');Ri=R.inverted()
 def project(p):
  wp=h+R@(Vector(p)-h);ok,hit,n,index=body.closest_point_on_mesh(wp)
  return (h+Ri@(hit-h),Ri@n) if ok else (Vector(p),Vector((1,0,0)))
 # One continuous colored corneal cap per eye prevents stacked-disc artifacts.
 eye_mat=mat('Corneal color', (1,1,1),0,.36,True);eye_mat.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.20
 stern=breed in ['akita','shepherd','kishu','mastiff','sighthound'];eyeh=.65 if stern else (.99 if breed=='chin' else .87)
 for sign in [-1,1]:
  c=h+Vector((sx*.64,sign*sy*.69,sz*.26));c,n=project(c);c+=n*.001
  side=Vector((0,0,1)).cross(n).normalized();up=n.cross(side).normalized();size=.066 if breed!='chin' else .083;vs=[];fs=[];cols=[]
  rings=[.0,.40,.46,.70,.87,.96,1.0]
  iris=(.105,.032,.008) if breed!='chin' else (.11,.035,.22)
  for j,rr in enumerate(rings):
   for k in range(40):
    ang=k/40*TAU;vs.append(c+side*(size*.86*rr*math.cos(ang))+up*(size*eyeh*rr*math.sin(ang))+n*(.003+.010*(1-rr*rr)))
    if rr<=.40 or rr>=.96:col=(.006,.004,.003)
    else:
     shade=1+.22*math.sin(ang*21)+.10*math.cos(ang*37);col=tuple(v*shade for v in iris)
    cols.append(col)
  for j in range(len(rings)-1):
   for k in range(40):a=j*40+k;b=j*40+(k+1)%40;fs.append((a,b,b+40,a+40))
  mesh('FACE | integrated cornea '+str(sign),vs,fs,eye_mat,True,cols)
  # A skin-colored socket rim blends the eye into the sculpted face.
  rvs=[];rfs=[];rcols=[]
  for k in range(40):
   ang=k/40*TAU
   for rr in [.995,1.24]:
    q=c+side*(size*.86*rr*math.cos(ang))+up*(size*eyeh*rr*math.sin(ang));qq,nn=project(q);q=qq+nn*.002 if rr>1 else q+n*.002;rvs.append(q);rcols.append(color_at(h+R@(q-h),r))
  for k in range(40):a=k*2;b=((k+1)%40)*2;rfs.append((a,b,b+1,a+1))
  mesh('FACE | natural fur eyelid rim '+str(sign),rvs,rfs,M['fur'],True,rcols)
  uv('FACE | tiny eye glint',c+n*.016+up*.017-side*.013,(.004,.004,.004),M['glint'],12,8)
 nose=h+Vector((sx*.70+mu*.91,0,-.052));o=uv('FACE | shaped leather nose',nose,(.065 if breed!='mastiff' else .085,sy*.38,.057 if breed!='mastiff' else .072),M['nose'])
 for s in [-1,1]:
  uv('FACE | nostril',nose+Vector((.058,s*sy*.19,.005)),(.009,.018,.012),M['ink'],20,12)
  ps=[]
  mcx=sx*.70+mu*.25;rx=mu*.79+.04;ry=sy*.62;rz=sz*.37
  for k in range(18):
   t=k/17;dx=mcx+rx*.92-t*rx*1.20;dz=-.14+(.014 if stern else .055)*t*t;yy=ry*math.sqrt(max(.025,1-((dx-mcx)/rx)**2-((dz+.07)/rz)**2))+.005
   q,qn=project(h+Vector((dx,s*yy,dz)));ps.append(q+qn*.005)
  if breed!='husky':curve('FACE | closed mouth crease',ps,M['ink'],.006 if breed!='mastiff' else .010)
  for k in range(6):
   x=sx*.72+mu*(.2+.1*(k%3));y=s*(sy*.49+.005*(k//3));z=-.077-.022*(k//3);uv('FACE | whisker follicle',h+Vector((x,y,z)),(.003,.003,.003),M['nose'],10,6)
 if breed=='mastiff':
  ear_mat=mat('Mastiff soft ear',(.25,.115,.045),0,.88)
  fold_mat=mat('Mastiff wrinkle',tuple(v*.83 for v in r['coat']),0,.86)
  for sign in [-1,1]:
   vs=[];fs=[]
   for j in range(12):
    t=j/11;w=.17*math.sin(math.pi*(.20+.77*t));cx=h.x-.10+.12*t;zz=h.z+.23-.64*t
    for k in range(7):
     u=k/6*2-1;vs.append((cx+u*w,sign*(sy*.86+.075*math.sin(t*math.pi)+.025*(1-u*u)),zz))
   for j in range(11):
    for k in range(6):a=j*7+k;fs.append((a,a+1,a+8,a+7))
   o=mesh('FACE | broad dropped mastiff ear',vs,fs,ear_mat);mo=o.modifiers.new('Soft ear flesh','SOLIDIFY');mo.thickness=.030;mo=o.modifiers.new('Ear flow','SUBSURF');mo.levels=2
   for k in range(3):
    pts=[]
    for j in range(9):
     t=j/8;p=h+Vector((.24-.07*t-k*.012,sign*(.06+.20*t),.25+.055*math.sin(t*math.pi)-k*.043));q,nn=project(p);pts.append(q+nn*.003)
    tube('FACE | soft brow fold',pts,[.009]+[.016]*7+[.005],fold_mat,10,1)
 if breed=='sighthound':
  for sign in [-1,1]:
   ps=[h+Vector((-.08,sign*.15,.10)),h+Vector((-.29,sign*.21,.18)),h+Vector((-.46,sign*.23,.20))];o=tube('FACE | folded swept ear',ps,[.062,.051,.003],M['fur'],12,1);ca=o.data.color_attributes.new(name='FurColor',type='FLOAT_COLOR',domain='POINT')
   for c in ca.data:c.color=(*r['coat'],1)
 if breed=='husky':
  uv('FACE | open mouth shadow',h+Vector((sx*.72+mu*.32,0,-.202)),(.18,.165,.047),M['ink']);uv('FACE | pink tongue',h+Vector((sx*.75+mu*.40,-.015,-.221)),(.10,.090,.022),M['tongue'])


def turn_face(r):
 h=Vector(r['head']);R=Matrix.Rotation(math.radians(-8 if r['breed']=='sighthound' else -35),4,'Z');T=Matrix.Translation(h)@R@Matrix.Translation(-h)
 for o in bpy.context.scene.objects:
  if o.name.startswith('FACE |'):o.matrix_world=T@o.matrix_world

def tail(r,M):
 hip=Vector(r['hip']);style=r['tail'];ps=[];rs=[]
 if style=='silk':
  p0=hip+Vector((-.16,0,.06));p1=Vector((-.64,.02,1.42));p2=Vector((-1.15,.03,1.21));p3=Vector((-1.08,.03,.31))
  for k in range(40):
   t=k/39;ps.append((1-t)**3*p0+3*(1-t)**2*t*p1+3*(1-t)*t*t*p2+t**3*p3);rs.append(.095*(1-.65*t))
 elif style in ['curl','plume']:
  radius=.235 if style=='curl' else .27;thick=.155 if r['breed'] not in ['akita','spitz','husky'] else (.23 if r['breed']=='spitz' else .19)
  for k in range(45):
   t=k/44;a=-math.pi*.42+t*math.pi*2.02;ps.append(Vector((hip.x-.22-radius*math.cos(a),.05+math.sin(t*math.pi)*.045,hip.z+.49+radius*math.sin(a))));rs.append(thick*(.92-.70*t**3))
  ps[0]=hip+Vector((-.20,0,.10));rs[0]=thick*.72
 else:
  end={'low':(-1.37,.02,.52),'straight':(-1.60,.02,1.05),'flow':(-2.02,.02,1.35)}[style]
  for k in range(28):
   t=k/27;c=(hip+Vector((-.16,0,.06))).lerp(Vector(end),t);c.z+=.15*math.sin(t*math.pi)*(1 if style!='low' else -1);ps.append(c);rs.append((.09 if style!='flow' else .07)*(1-t*.83))
 o=tube('ANATOMY | sculpted tail',ps,rs,M['fur'],20,1)
 bpy.context.view_layer.objects.active=o
 for mo in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mo.name)
 ca=o.data.color_attributes.new(name='FurColor',type='FLOAT_COLOR',domain='POINT')
 for v,c in zip(o.data.vertices,ca.data):
  t=(v.co.z-hip.z)/.6;white=(t>.95 or v.co.x<hip.x-.55) if r['breed']=='shiba' else t>.54;col=r['cream'] if white or r['breed'] in ['kishu','spitz','chin'] else r['coat'];c.color=(*col,1)
 # Flowing pointed tufts follow the tail's curve, not a smooth torus silhouette.
 random.seed(400+int(r['id']));vs=[];fs=[];cols=[]
 for j in range(2,len(ps)-2):
  tangent=(ps[j+1]-ps[j-1]).normalized();u=tangent.cross(Vector((0,1,0))).normalized();v=tangent.cross(u).normalized()
  for k in range(18):
   a=k/18*TAU+random.uniform(-.12,.12);n=u*math.cos(a)+v*math.sin(a);c=ps[j]+n*rs[j]*.92;length=(.085 if style=='curl' else (.24 if style=='silk' else .15))*(1-j/len(ps)*.4);w=length*.105;side=tangent.cross(n).normalized();base=len(vs)
   for t in [0,.45,1]:
    center=c+tangent*length*t+n*length*.40*math.sin(t*math.pi*.6)
    for s in [-1,0,1]:vs.append(center+side*w*(1-t)*s)
   for q in range(2):
    for a2 in range(2):i=base+q*3+a2;fs.append((i,i+1,i+4,i+3))
   white=(c.z>hip.z+.63 or c.x<hip.x-.55) if r['breed']=='shiba' else c.z>hip.z+.30;col=r['cream'] if white or r['breed'] in ['kishu','spitz','chin'] else r['coat'];cols.extend([col]*9)
 mesh('FUR | directional tail plume',vs,fs,M['fur'],True,cols)

def tassel(name,c,M,color='cloth',length=.16):
 c=Vector(c);torus(name+' tied loop',c+.025*Vector((0,0,1)),.029,.009,M[color]);uv(name+' knot',c,(.027,.021,.025),M[color],20,12);tube(name+' brass ferrule',[c+Vector((0,0,-.025)),c+Vector((0,0,-.047))],.023,M['gold'],16)
 for k in range(12):a=k/12*TAU;ps=[c+Vector((.016*math.cos(a),.016*math.sin(a),-.04)),c+Vector((.021*math.cos(a),.021*math.sin(a),-.09)),c+Vector((.032*math.cos(a),.032*math.sin(a),-length))];curve(name+' silk strand',ps,M[color],.006)

def rope(name,ps,M,r=.014,color='rope'):
 ps=list(map(Vector,ps));curve(name+' core',ps,M[color],r)
 # Helical cords give rope actual geometry in exports.
 dense=[]
 for a,b in zip(ps[:-1],ps[1:]):
  for k in range(8):dense.append(a.lerp(b,k/8))
 dense.append(ps[-1])
 for strand in range(3):
  points=[]
  for j,p in enumerate(dense):
   a=(dense[min(j+1,len(dense)-1)]-dense[max(0,j-1)]).normalized();u=a.cross(Vector((0,0,1)))
   if u.length<.01:u=a.cross(Vector((0,1,0)))
   u.normalize();v=a.cross(u).normalized();ang=j*.8+strand*TAU/3;points.append(p+(u*math.cos(ang)+v*math.sin(ang))*r*.65)
  curve(name+' twisted ply',points,M[color],r*.48)

def scarf(r,M):
 h=Vector(r['head']);axis=(h-Vector(r['chest'])).normalized();c=h-axis*.25;rad=r['hs'][1]*1.13;u=Vector((0,1,0));v=axis.cross(u).normalized()
 for j in range(3):
  ps=[]
  for k in range(65):
   a=k/64*TAU;ps.append(c-axis*j*.045+u*rad*math.sin(a)+v*(rad*.98)*math.cos(a))
  ribbon('CLOTH | layered neck scarf',ps,.09,M['cloth'],across=axis)
 # Wind-carried fabric tails are modeled surfaces with real thickness and folds.
 count=3 if r['gear'] in ['mirage','wind'] else 2
 for j in range(count):
  start=c+Vector((-.15,(-.06 if j%2 else .10),.07));length=1.65 if r['gear']=='wind' else (1.0 if r['gear'] in ['scout','mirage'] else .48);ps=[]
  for k in range(20):
   t=k/19;ps.append(start+Vector((-length*t,.15*math.sin(t*math.pi*2+j)+j*.09,.13*math.sin(t*math.pi*2.4+j)+.21*t)))
  ribbon('CLOTH | trailing scarf panel '+str(j),ps,.20 if r['gear']!='wind' else .14,M['cloth'],across=(0,.2,1),thick=.007)
  # Thin stitched wave accents follow selected folds in the fabric.
  for k in range(3,17,4):
   q=ps[k];curve('CLOTH | wave embroidery',[q+Vector((.025*math.cos(t/12*math.pi),-.008,.025*math.sin(t/12*math.pi))) for t in range(13)],M['thread'],.0025)


def harness(r,M):
 if r['gear']=='wind':
  band('TACK | light racing girth',(.12,0,1.08),.235,.275,.045,M['leather']);box('TACK | light harness buckle',(.12,-.25,1.11),(.06,.025,.07),M['gold'],.007)
  for sign in [-1,1]:ribbon('TACK | diagonal light breast strap',[(.12,sign*.15,1.34),(.43,sign*.23,1.11),(.64,sign*.11,.91)],.043,M['leather'],across=(0,0,1))
  return
 z=(r['hip'][2]+r['chest'][2])*.5;ry=r['body'][1]+.035;rz=r['body'][2]+.025
 for x in [-.25,.12]:
  band('TACK | shaped belly girth',(x,0,z),ry,rz,.075,M['leather']);box('TACK | brass strap buckle',(x,-ry-.018,z+.10),(.10,.025,.11),M['gold'],.01);box('TACK | buckle opening',(x,-ry-.034,z+.10),(.061,.014,.066),M['leather'],.005)
  for k in range(5):uv('TACK | strap rivet',(x,-ry-.018,z-.16+k*.055),(.009,.007,.009),M['gold'],12,8)
 # Front Y harness shaped to the chest rather than a square vest.
 for sy in [-1,1]:
  ps=[(.16,sy*ry*.68,z+.27),(.39,sy*ry*.94,z+.06),(.58,sy*ry*.55,z-.16),(.44,0,z-.28)]
  ribbon('TACK | chest harness strap',ps,.075,M['leather'],across=(0,0,1));torus('TACK | front harness ring',(.56,sy*ry*.60,z-.14),.040,.009,M['gold'],normal=(.5,sy,.1))
 ribbon('TACK | dorsal spine strap',[(-.52,0,z+.28),(-.25,0,z+.34),(.13,0,z+.36),(.42,0,z+.24)],.11,M['leather'],across=(0,1,0))

def scroll(c,M,axis=(1,0,0),length=.46,radius=.075):
 c=Vector(c);a=Vector(axis).normalized();tube('KIT | rolled parchment',[c-a*length/2,c+a*length/2],radius,M['parchment'],32)
 for s in [-1,1]:
  end=c+a*s*(length*.5+.008);tube('KIT | scroll rim',[end-a*.018,end+a*.018],radius*1.09,M['gold'],32)
  torus('KIT | visible paper spiral',end+a*s*.022,radius*.71,.005,M['leather'],normal=a)
  torus('KIT | inner scroll roll',end+a*s*.025,radius*.42,.004,M['leather'],normal=a)
 for t in [-.08,.08]:
  q=c+a*t;u=a.cross(Vector((0,0,1))).normalized();v=a.cross(u);ps=[q+(u*math.cos(k/36*TAU)+v*math.sin(k/36*TAU))*radius*1.1 for k in range(37)];rope('KIT | scroll cord',ps,M,.009,color='cloth')

def scout_gear(r,M):
 y=-r['body'][1]-.105;z=r['chest'][2]+.09
 scroll((-.10,y,z),M,length=.48)
 for i in range(2):
  c=Vector((-.32+i*.24,y-.02,z-.27));uv('KIT | lacquer smoke bomb',c,(.095,.074,.102),M['bomb']);tube('KIT | bomb neck',[c+Vector((0,0,.09)),c+Vector((0,0,.13))],.024,M['gold'],16);rope('KIT | hanging bomb cord',[c+Vector((0,0,.13)),c+Vector((.02,0,.21)),Vector((-.12+i*.18,y,z+.05))],M,.011,color='cloth');tassel('KIT | bomb tassel',c+Vector((-.005,-.01,-.10)),M,length=.13)
 tassel('KIT | front blue tassel',(.40,y,r['chest'][2]-.10),M,length=.20)


def equipment(r,M,limbs):
 gear=r['gear'];harness(r,M)
 if gear not in ['armor','ward']:scarf(r,M)
 if gear=='scout':scout_gear(r,M)
 # Additional archetype-specific equipment is authored below after the first fidelity gate.


def studio(r):
 s=bpy.context.scene;s.world=bpy.data.worlds.new('Warm studio world');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.60,.64,.72,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.35
 for name,loc,power,size in [('Key',(3,-4,6),650,4),('Fill',(-3,-1,3),220,3),('Rim',(0,4,4),450,3)]:
  ob=bpy.data.objects.new('STUDIO | '+name,bpy.data.lights.new(name,'AREA'));bpy.context.collection.objects.link(ob);ob.location=loc;ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size;ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
 floor=mat('Studio parchment',(.72,.67,.56),0,.95);bpy.ops.mesh.primitive_plane_add(size=200);o=bpy.context.object;o.name='STUDIO | ground';o.data.materials.append(floor)
 ob=bpy.data.objects.new('STUDIO | Camera',bpy.data.cameras.new('Camera'));bpy.context.collection.objects.link(ob);s.camera=ob;ob.data.type='ORTHO';ob.data.ortho_scale=3.2 if r['id']!='10' else 4.4
 s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=False;s.render.resolution_x=1100;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.render.image_settings.file_format='PNG';s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
 return s

def render(r,view='threequarter'):
 s=bpy.context.scene;target=Vector((0,0,1.00));pos={'threequarter':(4.1,-7,3.0),'front':(7,0,1.9),'side':(0,-8,2.0),'rear':(-7,0,2.0),'backthreequarter':(-4,7,3.0),'portrait':(4,-6,2.3)}[view]
 if view=='portrait':target=Vector(r['head']);s.camera.data.ortho_scale=1.25 if r['id']!='08' else 1.4
 else:s.camera.data.ortho_scale=3.2 if r['id']!='10' else 4.4
 s.camera.location=pos;s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(P/'renders'/f"{r['id']}_{view}.png");bpy.ops.render.render(write_still=True)

def save_export(r):
 s=bpy.context.scene;s['character']=r['name'];s['reference']='references/'+next((P/'references').glob(r['id']+'-*.png')).name;s['scope']='Static reference-led sculptural model; no armature or animation';s['scale_note']='Model units are meters; design-space proportions preserved for sculpting.'
 bpy.ops.object.select_all(action='DESELECT')
 for o in s.objects:
  if not o.name.startswith('STUDIO'):o.select_set(True)
 deps=bpy.context.evaluated_depsgraph_get();copies=[]
 for ob in list(s.objects):
  if ob.type=='CURVE' and ob.select_get():
   me=bpy.data.meshes.new_from_object(ob.evaluated_get(deps));cp=bpy.data.objects.new('EXPORT | '+ob.name,me);s.collection.objects.link(cp);cp.matrix_world=ob.matrix_world.copy();cp.select_set(True);ob.select_set(False);copies.append(cp)
 bpy.ops.export_scene.gltf(filepath=str(P/'exports'/f"{r['id']}_{r['name']}.glb"),export_format='GLB',use_selection=True,export_animations=False)
 for cp in copies:bpy.data.objects.remove(cp,do_unlink=True)
 s.camera.location=(4.1,-7,3);s.camera.rotation_euler=(Vector((0,0,1))-s.camera.location).to_track_quat('-Z','Y').to_euler();bpy.ops.wm.save_as_mainfile(filepath=str(P/'sources'/f"{r['id']}_{r['name']}.blend"),compress=True)

def build(r):
 for folder in ["sources","exports","renders","previews"]:(P/folder).mkdir(parents=True,exist_ok=True)
 bpy.ops.wm.read_factory_settings(use_empty=True)
 M={k:mat(k,*v) for k,v in {'fur':((1,1,1),0,.92,True),'inner':((.29,.13,.09),0,.95),'cloth':(r['scarf'],0,.89),'thread':((.29,.28,.25),0,.85),'leather':((.055,.034,.023),0,.65),'gold':((.40,.24,.075),.70,.34),'ink':((.004,.003,.004),0,.25),'nose':((.018,.014,.011),0,.32),'eye_white':((.23,.17,.10),0,.35),'iris':(((.13,.043,.014) if r['breed']!='chin' else (.085,.035,.15)),0,.20),'glint':((.95,.96,1),0,.10),'parchment':((.49,.40,.20),0,.8),'bomb':((.028,.033,.035),.40,.28),'rope':((.40,.27,.13),0,.9),'metal':((.052,.060,.067),.75,.38),'red':((.25,.034,.018),0,.82),'jowl':((.063,.044,.031),0,.75),'tongue':((.35,.085,.08),0,.65)}.items()}
 body,limbs=sculpt_body(r,M)
 for back,sy,ps,paw in limbs:
  for k in range(4):
   thick=r['leg'];c=paw+Vector((thick*1.18,(k-1.5)*thick*.43,-.018));tube('ANATOMY | short dark claw',[c,c+Vector((thick*.20,0,-.018)),c+Vector((thick*.25,0,-.041))],[thick*.13,thick*.11,.001],M['nose'],10,1)
 fur_groom(body,r,M);face(r,M);turn_face(r);tail(r,M)
 import importlib.util
 spec=importlib.util.spec_from_file_location('dog_gear',str(P/'tools/gear.py'));g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g);g.install(globals());g.equipment_full(r,M,limbs)
 studio(r);save_export(r);render(r);render(r,'portrait');print('BUILT',r['id'],r['name'],flush=True)
if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [];ids=[a for a in args if a.isdigit()]
 for r in DOGS:
  if not ids or r['id'] in ids:build(r)

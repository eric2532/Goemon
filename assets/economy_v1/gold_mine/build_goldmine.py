import bpy, math, random, json, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree
random.seed(73)
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for x in list(bpy.data.collections):
 if x.name!='Collection': bpy.data.collections.remove(x)
basecol=bpy.data.collections.get('Collection'); basecol.name='GOLDMINE_ASSET'
scene=bpy.context.scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
scene.render.fps=24
M={}
def mat(name,col,metal=0,rough=.7,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*col,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*col,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 if emit: p.inputs['Emission Color'].default_value=(*col,1); p.inputs['Emission Strength'].default_value=emit
 M[name]=m; return m
mat('FS_Wood_Cedar',(0.30,.135,.055));mat('FS_Wood_Honey',(0.48,.25,.095));mat('FS_Wood_Light',(0.61,.35,.14));mat('FS_Wood_Grain',(0.19,.075,.027));mat('FS_Iron',(0.105,.13,.15),.62,.4);mat('FS_Iron_Edge',(.2,.24,.26),.62,.4)
for i,c in enumerate([(.34,.365,.39),(.43,.455,.47),(.29,.32,.35),(.51,.52,.50),(.39,.415,.44)]): mat('FS_Stone_%02d'%i,c)
mat('FS_Gold',(1,.60,.075),.63,.28);mat('FS_Gold_Light',(1,.79,.23),.58,.23);mat('FS_Earth',(.28,.24,.185));mat('FS_Dirt_Light',(.40,.35,.265));mat('FS_Tunnel',(.052,.062,.06));mat('FS_Rope',(.52,.43,.25));mat('FS_Roof_Slate',(.10,.16,.185));mat('FS_Lantern',(1,.48,.085),.1,.4,2.8)
def coll(name):
 c=bpy.data.collections.new(name);basecol.children.link(c);return c
C={x:coll(x) for x in ['00_SHARED_ROCK_SITE','01_UNBUILT_MARKERS','02_BUILD_FOUNDATION','03_BUILD_POSTS','04_BUILD_LINTEL','05_BUILD_DETAILS','06_TEMP_CONSTRUCTION','07_WORKING_CART','08_WORKING_PICK','09_OPTIONAL_REINFORCEMENT','99_SOCKETS']}
def link(o,c):
 for x in list(o.users_collection):x.objects.unlink(o)
 c.objects.link(o)
def empty(name,c,parent=None,loc=(0,0,0)):
 o=bpy.data.objects.new(name,None);c.objects.link(o);o.parent=parent;o.location=loc;o.empty_display_type='PLAIN_AXES';o.empty_display_size=.22;return o
root=empty('GoldMine_Root',basecol)
root['asset']='FireSiege gold mine v1';root['units']='meters';root['forward']='-Y in Blender; +Z in glTF';root['base_build_cost_gold']=10;root['base_income_gold_per_second']=2;root['economy_note']='Reference metadata only; no game behavior implemented';root['income_phase']='combat_only';root['setup_income_gold_per_second']=0;root['pause_income_gold_per_second']=0;root['cleanup_combat_status']='undecided';root['initial_state']='unbuilt';root['upgrade_note']='Visual proposal only; no tier prices or rates assumed'
R={n:empty(n+'_Root',c,root) for n,c in C.items() if n!='99_SOCKETS'}
cur='00_SHARED_ROCK_SITE'
def finish(o,name,ma=None,parent=None):
 o.name=name;link(o,C[cur]);o.parent=parent or R[cur]
 if ma:o.data.materials.append(M[ma] if isinstance(ma,str) else ma)
 return o
def apply(o,bevel=.0):
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Soft hand-hewn edges','BEVEL');mod.width=bevel;mod.segments=1;mod.affect='EDGES'
  bpy.ops.object.modifier_apply(modifier=mod.name)
 o.select_set(False)
 return o
def box(name,loc,size,ma='FS_Wood_Cedar',bev=.03,rot=None,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1, location=loc);o=bpy.context.object;o.dimensions=size
 if rot:o.rotation_euler=rot
 apply(o,bev);return finish(o,name,ma,parent)
def cyl(name,loc,radius,depth,ma='FS_Iron',verts=12,rot=None,parent=None):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
 o=bpy.context.object
 if rot:o.rotation_euler=rot
 return finish(o,name,ma,parent)
def rod(name,a,b,w,ma='FS_Wood_Cedar',bev=.015,parent=None,depth=None):
 a,b=Vector(a),Vector(b);o=box(name,(a+b)/2,(w,depth or w,(b-a).length),ma,bev,parent=parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def mesh(name,verts,faces,ma,parent=None):
 me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);C[cur].objects.link(o);o.parent=parent or R[cur];me.materials.append(M[ma]);return o
def rock(name,loc,scale,seed,ma=None):
 rnd=random.Random(seed);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc);o=bpy.context.object
 for v in o.data.vertices:
  d=rnd.uniform(.88,1.13);v.co*=d
 o.scale=scale;o.rotation_euler=(rnd.uniform(-.25,.25),rnd.uniform(-.2,.2),rnd.uniform(-.6,.6));apply(o)
 mod=o.modifiers.new('Faceted silhouette','DECIMATE');mod.ratio=.42;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 finish(o,name,ma or 'FS_Stone_00')
 if not ma:
  for i in range(1,5):o.data.materials.append(M['FS_Stone_%02d'%i])
  for p in o.data.polygons:p.material_index=rnd.choices(range(5),[5,2,1,1,3])[0]
 return o
# A low, irregular terrain skirt closes the mesh against the game ground.
N=20;verts=[(0,0,.07)]+[(2.22*math.cos(i*math.tau/N)*(1+random.uniform(-.06,.06)),.02+2.3*math.sin(i*math.tau/N)*(1+random.uniform(-.05,.05)),.055+random.uniform(-.014,.014)) for i in range(N)]
verts += [(x,y,-.04) for x,y,z in verts[1:]]
faces=[(0,1+i,1+(i+1)%N) for i in range(N)]+[(1+i,1+N+i,1+N+(i+1)%N,1+(i+1)%N) for i in range(N)]+[tuple(range(N+1,2*N+1))]
mesh('Shared_earth_skirt',verts,faces,'FS_Earth')
# Recessed tunnel: an actual opening, with an irregular dark end wall.
mesh('Shared_tunnel_inner', [(-.73,-1.00,.07),(-.68,-.98,1.18),(-.43,-.95,1.56),(.43,-.95,1.56),(.70,-.98,1.18),(.73,-1,.07),(-.55,.76,.07),(-.53,.76,1.05),(-.31,.76,1.29),(.31,.76,1.29),(.53,.76,1.05),(.55,.76,.07)],[(0,6,7,1),(1,7,8,2),(2,8,9,3),(3,9,10,4),(4,10,11,5),(6,11,10,9,8,7)],'FS_Tunnel')
rocks=[]
specs=[(-1.14,-.59,.64,.67,.70,.83),(1.12,-.52,.63,.66,.71,.81),(-.9,-.27,1.35,.58,.73,.80),(.96,-.11,1.36,.67,.68,.84),(-.34,.01,1.96,.66,.76,.60),(.58,.42,2.08,.70,.70,.62),(-1.31,.63,.82,.67,.77,.83),(1.35,.61,.81,.62,.75,.9),(-.51,1.1,1.14,.80,.74,.94),(.64,1.12,1.02,.75,.7,.86),(-1.6,-.34,.26,.44,.49,.40),(1.57,-.22,.30,.46,.46,.43),(-1.51,1.21,.32,.48,.5,.41),(1.56,1.14,.35,.44,.56,.45),(-.02,1.55,.41,.70,.44,.43),(.0,-.45,1.71,.48,.46,.35)]
for i,(x,y,z,sx,sy,sz) in enumerate(specs):rocks.append(rock('Shared_rock_%02d'%i,(x,y,z),(sx,sy,sz),i+101))
# Thin polygonal ribbons conform to the boulder faces, not floating billboards.
def vein_on_rock(obj,name,pts,width=.037):
 world=[obj.matrix_world @ v.co for v in obj.data.vertices];bv=BVHTree.FromPolygons(world,[list(p.vertices) for p in obj.data.polygons])
 vv=[]
 for x,z in pts:
  for side in [-1,1]:
   loc,n,_,_=bv.ray_cast(Vector((x+side*width,-5,z)),Vector((0,1,0)))
   if loc is None:return
   vv.append(tuple(loc+n*.009))
 fs=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(pts)-1)]
 o=mesh(name,vv,fs,'FS_Gold');o.data.materials.append(M['FS_Gold_Light'])
 for i,p in enumerate(o.data.polygons):p.material_index=i%2
bpy.context.view_layer.update()
vein_on_rock(rocks[0],'Gold_vein_left_main',[(-1.30,.19),(-1.38,.40),(-1.19,.57),(-1.27,.78),(-1.1,1.02)],.04)
vein_on_rock(rocks[0],'Gold_vein_left_branch',[(-1.20,.57),(-.99,.65),(-.91,.84)],.025)
vein_on_rock(rocks[1],'Gold_vein_right_main',[(1.06,.12),(1.25,.35),(1.10,.57),(1.23,.84),(1.12,1.10)],.045)
vein_on_rock(rocks[4],'Gold_vein_crown',[(-.54,1.83),(-.39,2.03),(-.59,2.19),(-.34,2.31)],.05)
vein_on_rock(rocks[5],'Gold_vein_upper_right',[(.58,1.80),(.73,1.99),(.53,2.20),(.67,2.41)],.04)
for i in range(33):
 a=random.uniform(0,math.tau);r=random.uniform(1.7,2.12);x,y=math.cos(a)*r, math.sin(a)*r*.94
 if y<-.85 and abs(x)<.81:continue
 s=random.uniform(.07,.19);rock('Shared_gravel_%02d'%i,(x,y,.1),(s*1.2,s,s*.7),600+i)
# Small ore strata glint from inside the recess.
for i in range(7):
 x=random.choice([-.53,.52])+random.uniform(-.04,.04);z=random.uniform(.25,1.1)
 rock('Gold_interior_ore_%02d'%i,(x,.15+random.uniform(0,.30),z),(.075,.07,.13),700+i,'FS_Gold')
# Purchase site markers. Their caps make the unbuilt state readable at gameplay scale.
cur='01_UNBUILT_MARKERS'
for i,(x,y) in enumerate([(-1.86,-1.72),(1.86,-1.72),(-1.98,.88),(1.98,.88)]):
 box('Unbuilt_survey_stake_%d'%i,(x,y,.23),(.16,.16,.44),'FS_Wood_Cedar',.01)
 cyl('Unbuilt_gold_cap_%d'%i,(x,y,.463),.13,.07,'FS_Gold',4,rot=(0,0,math.pi/4))
# Foundations and tracks.
cur='02_BUILD_FOUNDATION'
for x in [-.84,.84]:box('Build_stone_foot_L' if x<0 else 'Build_stone_foot_R',(x,-.98,.15),(.48,.50,.28),'FS_Stone_02',.045)
for i in range(9):box('Build_track_sleeper_%02d'%i,(0,-2.15+i*.31,.115),(1.17,.15,.12),'FS_Wood_Cedar',.023)
for x in [-.43,.43]:
 box('Build_rail_L' if x<0 else 'Build_rail_R',(x,-.91,.225),(.08,2.84,.10),'FS_Iron',.014)
 for y in [-2.15,-1.53,-.91,-.29,.33]:cyl('Rail_spike', (x,y,.283),.032,.025,'FS_Iron_Edge',8)
# Hand-hewn pillars with lighter edge planks and bolts.
cur='03_BUILD_POSTS'
for x in [-.84,.84]:
 box('Build_main_post_L' if x<0 else 'Build_main_post_R',(x,-.98,.96),(.30,.35,1.61),'FS_Wood_Honey',.028)
 box('Post_front_highlight',(x-.055,-1.163,.98),(.052,.013,1.38),'FS_Wood_Light',.003)
 for j in range(3):
  xx=x+random.uniform(-.10,.10);rod('Post_carved_grain',(xx,-1.163,.35),(xx+random.uniform(-.023,.023),-1.169,1.62),.009,'FS_Wood_Grain',.001)
# The lintel has softly rising corners, a Japanese timber reference without a full temple roof.
cur='04_BUILD_LINTEL'
box('Build_lintel_main',(0,-.99,1.83),(2.32,.51,.30),'FS_Wood_Honey',.035)
box('Build_lintel_upper',(0,-.99,2.026),(2.51,.56,.11),'FS_Wood_Light',.025)
for side in [-1,1]:
 box('Lintel_turned_end', (side*1.20,-.99,2.064),(.22,.56,.115),'FS_Wood_Honey',.02,rot=(0,side*-.14,0))
 rod('Inner_diagonal_brace',(side*.78,-1.04,1.34),(side*.36,-1.04,1.76),.13,'FS_Wood_Cedar',.016)
for j in range(4):rod('Lintel_carved_grain',(-1.03,-1.253,1.74+j*.047),(1.03,-1.253,1.755+j*.045),.009,'FS_Wood_Grain',.002)
# Iron joinery, ropes, entrance lantern and tools.
cur='05_BUILD_DETAILS'
for x in [-.84,.84]:
 for z in [.34,1.59,1.87]:
  box('Working_post_iron_strap',(x,-1.184,z),(.355,.055,.13),'FS_Iron',.014)
  for dx in [-.11,.11]:cyl('Iron_rivet',(x+dx,-1.222,z),.030,.032,'FS_Iron_Edge',8,rot=(math.pi/2,0,0))
 for z in [1.16,1.19,1.22]:
  # Squared cord loops in portable mesh form.
  for xx in [-.163,.163]:rod('Post_rope_vertical',(x+xx,-1.175,z),(x+xx,-.785,z),.024,'FS_Rope',.006)
  rod('Post_rope_front',(x-.163,-1.175,z),(x+.163,-1.175,z),.024,'FS_Rope',.006)
rod('Lantern_hanger',(1.12,-1.03,1.39),(1.12,-1.30,1.39),.044,'FS_Iron',.004)
rod('Lantern_chain',(1.12,-1.30,1.39),(1.12,-1.30,1.21),.022,'FS_Iron',.002)
box('Lantern_glow',(1.12,-1.30,1.055),(.16,.15,.24),'FS_Lantern',.016)
for z in [.91,1.19]:box('Lantern_frame',(1.12,-1.30,z),(.23,.22,.045),'FS_Iron',.009)
for dx in [-.095,.095]:
 for dy in [-.09,.09]:rod('Lantern_corner',(1.12+dx,-1.30+dy,.93),(1.12+dx,-1.30+dy,1.18),.021,'FS_Iron',.003)
# Temporary side scaffolding and stored timber disappear at completion.
cur='06_TEMP_CONSTRUCTION'
for x in [-1.40,1.40]:
 for y in [-.7,.55]:rod('Construction_scaffold_pole',(x,y,.10),(x,y,1.80),.105,'FS_Wood_Cedar',.01)
 rod('Construction_scaffold_rail',(x,-.80,1.51),(x,.66,1.51),.11,'FS_Wood_Honey',.01)
 rod('Construction_scaffold_diagonal',(x,-.68,.45),(x,.52,1.5),.08,'FS_Wood_Honey',.01)
for j in range(4):box('Construction_spare_timber_%d'%j,(1.48,-1.17,.17+j*.11),(.70,.23,.105),'FS_Wood_Honey',.015)
# Ore cart: open, tapered body made of discrete planks; rig root is centered on axle.
cur='07_WORKING_CART';cart=R[cur];cart.location=(0,-1.56,0)
box('Cart_chassis',(0,0,.45),(.85,.94,.13),'FS_Wood_Cedar',.015,parent=cart)
# A proper open box with sloped sides.
for j in range(3):
 z=.56+j*.137;w=.85+j*.065;l=.94+j*.07
 for side in [-1,1]:
  box('Cart_side_plank',(side*w/2,0,z),(.075,l,.123),'FS_Wood_Honey' if j%2 else 'FS_Wood_Cedar',.012,rot=(0,side*-.22,0),parent=cart)
  box('Cart_end_plank',(0,side*l/2,z),(w,.075,.123),'FS_Wood_Honey',.012,rot=(side*.22,0,0),parent=cart)
for x in [-.50,.50]:
 for y in [-.51,.51]:
  box('Cart_iron_corner',(x,y,.70),(.075,.075,.49),'FS_Iron',.01,parent=cart)
  for z in [.51,.85]:cyl('Cart_corner_rivet',(x,y-.044,z),.026,.025,'FS_Iron_Edge',8,rot=(math.pi/2,0,0),parent=cart)
wheelroots=[]
for x in [-.51,.51]:
 for y in [-.31,.31]:
  wh=empty('CartWheel_Root_%s_%s'%(x,y),C[cur],cart,(x,y,.33));wheelroots.append(wh)
  cyl('Cart_wheel',(0,0,0),.188,.085,'FS_Iron',16,rot=(0,math.pi/2,0),parent=wh)
  cyl('Cart_wheel_hub',(math.copysign(.055,x),0,0),.075,.035,'FS_Iron_Edge',12,rot=(0,math.pi/2,0),parent=wh)
  for a in [0,math.pi/2]:
   rod('Wheel_spoke',(math.copysign(.06,x),math.cos(a)*-.143,math.sin(a)*-.143),(math.copysign(.06,x),math.cos(a)*.143,math.sin(a)*.143),.027,'FS_Iron_Edge',.004,parent=wh)
for y in [-.31,.31]:rod('Cart_axle',(-.58,y,.33),(.58,y,.33),.075,'FS_Iron',.007,parent=cart)
# Low-poly ore load, deliberately golden enough for the resource silhouette.
ore=[]
for i in range(15):
 x=random.uniform(-.32,.32);y=random.uniform(-.35,.35);z=.81+(.1 if i>8 else 0)+random.uniform(-.02,.1)
 o=rock('Cart_ore_%02d'%i,(x,y,z),(.12+random.random()*.06,.13,.10+random.random()*.06),850+i,'FS_Gold' if i%3 else 'FS_Gold_Light');o.parent=cart;ore.append(o)
# A mining pick in the recess adds a readable working animation without a character.
cur='08_WORKING_PICK';pick=R[cur];pick.location=(-.42,.07,.93)
rod('Working_pick_handle',(0,0,-.35),(0,0,.29),.055,'FS_Wood_Cedar',.008,parent=pick)
rod('Working_pick_head',(-.24,0,.25),(.24,0,.25),.070,'FS_Iron',.01,parent=pick)
# Optional, unpriced visual upgrade: a small dark canopy and strengthened side braces.
cur='09_OPTIONAL_REINFORCEMENT'
for s in [-1,1]:
 rod('Upgrade_diagonal_support',(s*1.48,-.92,.18),(s*.91,-.94,1.77),.21,'FS_Wood_Honey',.025)
 for z in [.32,1.55]:box('Upgrade_support_iron',(s*(1.42 if z<1 else .97),-1.055,z),(.26,.04,.13),'FS_Iron',.01)
# Two real sloped roof surfaces, with thick cedar perimeter and slate battens.
for s in [-1,1]:
 for i in range(6):
  y=-1.29+i*.125
  rod('Upgrade_roof_slat',(s*.01,y,2.21),(s*1.31,y,2.04),.12,'FS_Roof_Slate',.012,depth=.10)
 rod('Upgrade_roof_front_eave',(s*.02,-1.39,2.245),(s*1.37,-1.39,2.074),.10,'FS_Wood_Light',.015)
 rod('Upgrade_roof_back_eave',(s*.02,-.59,2.245),(s*1.37,-.59,2.074),.10,'FS_Wood_Honey',.015)
box('Upgrade_roof_ridge',(0,-.99,2.26),(.15,.98,.105),'FS_Wood_Honey',.02)
# Exported attachment sockets are empty nodes only.
for n,loc in [('socket_build_fx',(0,0,3.2)),('socket_income_fx',(0,-1.3,2.4)),('socket_entrance',(0,-1.25,0))]:empty(n,C['99_SOCKETS'],root,loc)
# Root transforms are animated; discrete mesh objects remain editable and exportable.
anim_roots=list(R.values())+wheelroots
base={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in anim_roots}
A={}
def track_action(o,clip,frames):
 a=bpy.data.actions.new(clip+'__'+o.name);o.animation_data_create();o.animation_data.action=a
 for f,loc,rot,scale in frames:
  o.location=loc;o.rotation_euler=rot;o.scale=tuple(max(float(x),1e-5) for x in scale)
  for p in ['location','rotation_euler','scale']:o.keyframe_insert(data_path=p,frame=f)
 for fc in a.fcurves:
  for kp in fc.keyframe_points:kp.interpolation='LINEAR'
 tr=o.animation_data.nla_tracks.new();tr.name=clip;st=tr.strips.new(clip,1,a);st.blend_type='REPLACE';tr.mute=True
 o.animation_data.action=None;A[(o.name,clip)]=a
 o.location,o.rotation_euler,o.scale=base[o.name]
def default_scale(o,working=True):
 n=o.name
 if n.startswith(('01_UNBUILT','06_TEMP','09_OPTIONAL')):return Vector((0,0,0))
 return Vector((1,1,1))
def build_keys(o,reverse=False):
 loc,rot,sc=base[o.name];n=o.name;keys=[]
 stages={'02_BUILD':(3,15),'03_BUILD':(12,30),'04_BUILD':(26,39),'05_BUILD':(33,46),'07_WORKING':(37,49),'08_WORKING':(37,49)}
 if n.startswith('01_UNBUILT'):vals=[(1,1),(8,1),(16,0),(49,0)]
 elif n.startswith('06_TEMP'):vals=[(1,0),(5,0),(13,1),(37,1),(46,0),(49,0)]
 elif n.startswith('09_OPTIONAL'):vals=[(1,0),(49,0)]
 else:
  stage=next((v for k,v in stages.items() if n.startswith(k)),None)
  vals=[(1,0),(stage[0],0),(stage[1],1),(49,1)] if stage else [(1,1),(49,1)]
 # Wheel roots stay at their own scale; cart parent handles build visibility.
 for f,s in vals:
  l=loc.copy();scale=Vector((s,s,s))
  if n.startswith(('03_BUILD','04_BUILD')) and s==0:l.z-=.5
  keys.append((50-f if reverse else f,l,rot.copy(),scale))
 return sorted(keys,key=lambda x:x[0])
for o in anim_roots:
 track_action(o,'build',build_keys(o));track_action(o,'reverse_build',build_keys(o,True))
 loc,rot,sc=base[o.name];scale=default_scale(o)
 frames=[]
 for f in [1,13,25,37,49,61,73,85,97]:
  t=(f-1)/96; l=loc.copy(); rr=rot.copy(); ss=scale.copy()
  if o==cart:l.y=loc.y+.48*(1-math.cos(t*math.tau))/2
  if o in wheelroots:rr.x=2.55*(1-math.cos(t*math.tau))/2
  if o==pick:rr.y=math.radians(-12)+math.radians(42)*max(0,math.sin(t*math.tau*2))
  frames.append((f,l,rr,ss))
 track_action(o,'work_loop',frames)
 frames=[]
 for f in [1,17,37,49]:
  ss=scale.copy()
  if o==R['09_OPTIONAL_REINFORCEMENT']:ss=Vector((1,1,1))*(max(0,min(1,(f-9)/28)))
  if o==cart:ss=Vector((1,1,1))*(1+.13*max(0,min(1,(f-9)/28)))
  frames.append((f,loc.copy(),rot.copy(),ss))
 track_action(o,'upgrade_preview',frames)
def pose(clip,f):
 for o in anim_roots:
  o.animation_data.action=A[(o.name,clip)];o.animation_data.use_nla=False
 scene.frame_set(f);bpy.context.view_layer.update()
pose('work_loop',1)
scene.frame_start=1;scene.frame_end=97
# Metrics include all authored mesh triangles; stage roots at 0 do not remove data.
metrics={'asset':'FireSiege Gold Mine v1','units':'meters','blender_up':'+Z','blender_forward':'-Y','gltf_up':'+Y','gltf_forward':'+Z','pivot':'ground center','base_cost_gold':10,'base_income_gold_per_second':2,'implementation':'asset metadata only; no game code','clips_seconds':{'build':2,'reverse_build':2,'work_loop':4,'upgrade_preview':2},'collections':list(C),'mesh_objects':sum(o.type=='MESH' for o in bpy.data.objects),'triangles_authored':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.data.objects if o.type=='MESH'),'materials':len(M),'sockets':{'socket_build_fx':[0,0,3.2],'socket_income_fx':[0,-1.3,2.4]}}
metrics.update({'income_phase':'combat_only','setup_income_gold_per_second':0,'pause_income_gold_per_second':0,'cleanup_combat_status':'undecided'})
pts=[o.matrix_world@Vector(c) for o in bpy.data.objects if o.type=='MESH' and not o.name.startswith('Upgrade_') for c in o.bound_box]
metrics['working_bounds_min']=[min(p[i] for p in pts) for i in range(3)];metrics['working_bounds_max']=[max(p[i] for p in pts) for i in range(3)]
with open(os.path.join(OUT,'goldmine_metrics.json'),'w') as f:json.dump(metrics,f,indent=2)
# Export only the authored asset, no presentation lights or ground.
bpy.ops.object.select_all(action='DESELECT')
for o in basecol.all_objects:o.select_set(True)
for o in anim_roots:o.animation_data.action=None;o.animation_data.use_nla=True
scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'goldmine_v1.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_frame_range=False,export_anim_slide_to_zero=True,export_force_sampling=True,export_optimize_animation_size=True,export_optimize_animation_keep_anim_object=True,export_extras=True,export_yup=True)
pose('work_loop',1)
# Presentation-only scene objects are not part of exported asset.
pres=bpy.data.collections.new('PRESENTATION_ONLY');scene.collection.children.link(pres)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.07));floor=bpy.context.object;floor.name='Presentation_floor';link(floor,pres);floor.data.materials.append(mat('Presentation_sand',(.64,.62,.565)))
def point(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(6,-8,5.3));cam=bpy.context.object;link(cam,pres);cam.name='Presentation_camera';point(cam,(0,-.15,1.08));cam.data.type='ORTHO';cam.data.ortho_scale=6.45;scene.camera=cam
for name,loc,energy,size,col in [('Key',(-3,-5,7),750,5,(1,.86,.67)),('Fill',(4,-2,4.5),450,4,(.73,.84,1)),('Rim',(0,4,6),950,3,(1,.89,.69))]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;link(o,pres);o.name='Presentation_'+name;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.data.color=col;point(o,(0,0,1))
scene.world.color=(.22,.22,.22);scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
scene.view_settings.view_transform='AgX';scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
# Save in a readable working pose with usable named action library.
pose('work_loop',1);scene.frame_end=97
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_distance=7
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'goldmine_v1.blend'),compress=True)
# Three real perspective renders plus state comparison sources.
views=[('front_three_quarter',(6,-8,5.3)),('rear_three_quarter',(-6,7,4.6)),('front',(0,-9,4.3))]
for name,loc in views:
 cam.location=loc;point(cam,(0,-.15,1.08));pose('work_loop',1);scene.render.filepath=os.path.join(OUT,'renders',name+'.png');bpy.ops.render.render(write_still=True)
cam.location=(6,-8,5.3);point(cam,(0,-.15,1.08))
for name,clip,f in [('unbuilt','build',1),('construction','build',29),('reinforced_proposal','upgrade_preview',49)]:
 pose(clip,f);scene.render.filepath=os.path.join(OUT,'renders',name+'.png');bpy.ops.render.render(write_still=True)
# Animation preview uses the same authored actions as the GLB; no composited fake movement.
scene.render.resolution_x=800;scene.render.resolution_y=660;scene.cycles.samples=8
sequence=[('build',1,49),('work_loop',1,97),('upgrade_preview',1,49),('reverse_build',1,49)]
k=0
for clip,start,end in sequence:
 for f in range(start,end+1,2):
  pose(clip,f);scene.render.filepath=os.path.join(OUT,'preview_frames','%04d.png'%k);bpy.ops.render.render(write_still=True);k+=1
with open(os.path.join(OUT,'preview_sequence.json'),'w') as f:json.dump({'fps':12,'frames':k,'sections':['build','work_loop','upgrade_preview','reverse_build']},f,indent=2)
print('GOLDMINE_BUILD_FINISHED',json.dumps(metrics))

"""EDO_EMBER_V01: isolated original visual redesign, exact shipped rig retained."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/blender/enemies/musashi/Redesign_v01';OUT.mkdir(exist_ok=True)
EXPORT=ROOT/'assets/characters/musashi/preview';EXPORT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/musashi/model/edo_refined.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
old=next(o for o in bpy.data.objects if o.name.startswith('Edo_'))
for o in list(bpy.data.objects):
 if o not in [rig,old]:bpy.data.objects.remove(o,do_unlink=True)
rest={b.name:[list(row) for row in b.matrix_local] for b in rig.data.bones}
old.name='BEFORE_Edo_Refined';old.hide_render=True;old.hide_set(True)
geo=[]
def mat(n,c,metal=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.78;p.inputs['Specular IOR Level'].default_value=.08;p.inputs['Metallic'].default_value=metal;return m
skin=mat('Warm copper skin',(.64,.32,.17));light=mat('Face warm planes',(.82,.46,.25));hair=mat('Ink black hair',(.012,.021,.023));hairlit=mat('Hair jade facets',(.026,.049,.048));red=mat('Oxblood jacket',(.34,.018,.037));redlit=mat('Vermilion tailored edges',(.58,.046,.038));dark=mat('Charcoal vest',(.036,.044,.051));gold=mat('Ember orange applique',(.98,.32,.028));wrap=mat('Ivory linen wraps',(.64,.59,.43));blue=mat('Indigo shoe uppers',(.031,.068,.13));sole=mat('Rubber charcoal soles',(.017,.023,.027));white=mat('Eye ivory',(.92,.83,.61));iris=mat('Amber iris',(.40,.17,.018))
def bind(o,n,m,weights):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
 o.name=n;o.data.materials.append(m);bpy.context.view_layer.objects.active=o
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for v in o.data.vertices:
  p=o.matrix_world@v.co;ws=weights(p) if callable(weights) else {weights:1}
  for bn,w in ws.items():
   g=o.vertex_groups.get(bn) or o.vertex_groups.new(name=bn)
   if w>0:g.add([v.index],w,'REPLACE')
 mod=o.modifiers.new('Existing_Edo_skin','ARMATURE');mod.object=rig;o.parent=rig
 for p in o.data.polygons:p.use_smooth=True
 geo.append(o);o.select_set(False);return o
def ell(n,p,s,m,b):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=p);o=bpy.context.object;o.scale=s;return bind(o,n,m,b)
def loft(n,rings,m,b,N=16):
 vs=[]
 for x,y,z,rx,ry in rings:
  vs += [(x+rx*math.cos(i*2*math.pi/N),y+ry*math.sin(i*2*math.pi/N),z) for i in range(N)]
 fs=[tuple(reversed(range(N)))]
 for j in range(len(rings)-1):
  for i in range(N):a=j*N+i;bb=j*N+(i+1)%N;fs.append((a,bb,bb+N,a+N))
 fs.append(tuple(range((len(rings)-1)*N,len(rings)*N)))
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new(n,mesh);bpy.context.collection.objects.link(o);return bind(o,n,m,b)
def patch(n,pts,m,b):
 if 'orange flame' in n:
  side=n[0];hand=rig.data.bones['Hand_'+side].head_local;elbow=rig.data.bones['Forearm_'+side].head_local;arm=rig.data.bones['Arm_'+side].head_local;sgn=-1 if side=='L' else 1
  mapped=[]
  for x,y,z in pts:
   t=max(0,min(1,(z-.98)/.24));cx=elbow.x*(1-t)+(arm.x+sgn*.035)*t;rx=.12+.025*t;ry=.125+.015*t
   xx=max(-rx*.9,min(rx*.9,x-cx));mapped.append((cx+xx,-.025+ry*math.sqrt(1-(xx/rx)**2)+.006,z))
  pts=mapped
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(pts,[],[tuple(range(len(pts)))]);mesh.update();o=bpy.data.objects.new(n,mesh);bpy.context.collection.objects.link(o);return bind(o,n,m,b)
def line(n,pts,r,m,b):
 cu=bpy.data.curves.new(n,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=2;sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
 for p,co in zip(sp.points,pts):p.co=(*co,1)
 o=bpy.data.objects.new(n,cu);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o=bpy.context.object;o.select_set(False);return bind(o,n,m,b)
def blend(a,b,t):t=max(0,min(1,t));return {a:1-t,b:t}
body=lambda p:blend('Hips','Chest',(p.z-.85)/.27)
# Tailored cropped jacket: broad shoulder, clear tapered waist; layered Mandarin vest.
loft('Cropped jacket body',[(.03,-.055,.84,.22,.145),(.025,-.055,.91,.23,.15),(.02,-.06,1.16,.265,.155),(.02,-.06,1.29,.28,.14),(.01,-.045,1.35,.18,.11)],red,body)
loft('Charcoal vest',[(.025,.005,.86,.145,.135),(.02,.004,1.12,.18,.145),(.01,-.01,1.31,.17,.14)],dark,body)
loft('Mandarin collar',[(0,-.025,1.29,.115,.115),(0,-.025,1.40,.108,.105)],dark,'Chest')
line('Jacket left piping',[(-.12,.125,.87),(-.16,.138,1.12),(-.145,.13,1.30)],.012,redlit,body)
line('Jacket right piping',[(.17,.125,.87),(.20,.138,1.12),(.17,.13,1.30)],.012,redlit,body)
for z in [.96,1.08,1.20]:
 line('Frog closure', [(-.095,.156,z),(.075,.163,z)],.012,sole,body);ell('Brass frog knot',(.075,.17,z),(.019,.013,.018),gold,body)
loft('Waist ivory binding',[(.025,-.045,.82,.218,.15),(.025,-.045,.875,.223,.153)],wrap,'Hips')
for side in ['L','R']:
 s=-1 if side=='L' else 1
 arm=rig.data.bones['Arm_'+side].head_local;elbow=rig.data.bones['Forearm_'+side].head_local;hand=rig.data.bones['Hand_'+side].head_local
 aw=lambda p,side=side:blend('Forearm_'+side,'Arm_'+side,(p.z-.95)/.18)
 sleeve_rings=[]
 anchors=[(hand.x,0,.83,.105,.11),(elbow.x,-.02,.98,.12,.125),(arm.x+s*.035,-.035,1.22,.145,.14),(arm.x,-.04,1.30,.13,.12)]
 for j in range(25):
  z=.83+j*(1.30-.83)/24
  a,b=next((a,b) for a,b in zip(anchors,anchors[1:]) if a[2]-1e-6<=z<=b[2]+1e-6)
  t=(z-a[2])/(b[2]-a[2]);sleeve_rings.append(tuple(a[k]*(1-t)+b[k]*t for k in range(5)))
 sleeve=loft(side+' articulated sleeve',sleeve_rings,red,aw,32);sleeve.data.materials.append(gold)
 for poly in sleeve.data.polygons:
  if len(poly.vertices)!=4:continue
  p=sum((sleeve.data.vertices[i].co for i in poly.vertices),Vector())/len(poly.vertices)
  ring=min(sleeve_rings,key=lambda r:abs(r[2]-p.z));u=(p.x-ring[0])/ring[3]
  knots=[(-1,.86),(-.8,.90),(-.55,1.10),(-.32,1.02),(-.1,1.20),(.16,1.07),(.43,1.14),(.67,.99),(1,.86)]
  a,b=next(((a,b) for a,b in zip(knots,knots[1:]) if a[0]<=u<=b[0]),(knots[0],knots[1]))
  h=a[1]+(b[1]-a[1])*(u-a[0])/(b[0]-a[0])
  if p.y>ring[1]+.045 and p.z<h:poly.material_index=1
 loft(side+' flame cuff',[(hand.x,0,.82,.11,.115),(hand.x,0,.86,.113,.118)],gold,'Forearm_'+side)
 # Broad three-pronged flame applique, front and outer shoulder-facing silhouette.
 x=elbow.x

 ell(side+' palm',(hand.x,.025,.735),(.076,.068,.105),light,'Hand_'+side)
 ell(side+' thumb',(hand.x-s*.066,.071,.755),(.038,.046,.056),skin,'Hand_'+side)
 for k in range(3):line(side+' knuckle crease',[(hand.x-.044+k*.034,.086,.69),(hand.x-.044+k*.034,.09,.73)],.003,skin,'Hand_'+side)
 hip=rig.data.bones['Leg_'+side].head_local;ank=rig.data.bones['Foot_'+side].head_local
 legw=lambda p,side=side:blend('Shin_'+side,'Leg_'+side,(p.z-.49)/.18)
 loft(side+' cropped balloon trousers',[(ank.x,-.052,.39,.096,.11),(ank.x,-.055,.48,.145,.15),(hip.x,-.06,.65,.185,.177),(hip.x*.83,-.06,.84,.16,.155)],red,legw)
 line(side+' trouser folded seam',[(hip.x+s*.1,.066,.79),(hip.x+s*.135,.08,.64),(ank.x+s*.06,.06,.43)],.013,redlit,legw)
 loft(side+' wrapped shin',[(ank.x,-.055,.18,.077,.087),(ank.x,-.055,.39,.086,.097)],wrap,'Shin_'+side)
 for z in [.215,.257,.299,.341,.382]:
  loft(side+' wrap overlap',[(ank.x,-.055,z,.081,.092),(ank.x,-.055,z+.012,.084,.095)],wrap,'Shin_'+side)
 ell(side+' dark sole',(ank.x,.06,.055),(.123,.212,.055),sole,'Foot_'+side)
 ell(side+' blue shoe',(ank.x,.05,.125),(.111,.184,.083),blue,'Foot_'+side)
 line(side+' shoe welt',[(ank.x-.105,.18,.09),(ank.x,.253,.09),(ank.x+.105,.18,.09)],.012,dark,'Foot_'+side)
# Strong cheek/jaw planes and compact head: 4.5-head silhouette including hair.
ell('Neck',(0,-.02,1.41),(.083,.082,.13),skin,'Head')
loft('Sculpted facial planes',[(0,.015,1.43,.075,.07),(0,.025,1.47,.135,.10),(0,.01,1.56,.185,.136),(0,-.005,1.72,.197,.158),(0,-.025,1.85,.18,.135),(0,-.03,1.91,.115,.09)],light,'Head',24)
for s in [-1,1]:
 ell('Ear', (s*.194,-.002,1.655),(.047,.036,.071),skin,'Head');ell('Ear inner',(s*.207,.027,1.655),(.02,.008,.038),redlit,'Head')
 # slanted almond eyes, lids and clear amber gaze
 x=s*.085
 patch('Almond ivory eye',[(x-s*.067,.149,1.702),(x+s*.066,.132,1.731),(x+s*.056,.142,1.66),(x-s*.05,.153,1.661)],white,'Head')
 ell('Amber iris',(x,.157,1.689),(.027,.009,.031),iris,'Head');ell('Black pupil',(x,.165,1.69),(.012,.006,.025),hair,'Head');ell('Eye glint',(x-.009,.17,1.702),(.006,.003,.008),white,'Head')
 line('Angular eyebrow',[(x-s*.07,.157,1.747),(x+s*.061,.14,1.78)],.016,hair,'Head')
 line('Upper eyelid',[(x-s*.067,.154,1.702),(x+s*.066,.14,1.731)],.006,hair,'Head')
ell('Nose bridge',(0,.143,1.648),(.028,.039,.055),light,'Head')
patch('Nose shadow',[(-.021,.167,1.625),(.025,.164,1.625),(0,.189,1.64)],skin,'Head')
line('Confident mouth',[(-.067,.141,1.554),(-.01,.154,1.547),(.054,.145,1.563)],.006,dark,'Head')
# Interlocking swept locks, a broad black cap and asymmetric flame-like hair silhouette.
ell('Black hair cap',(0,-.051,1.834),(.213,.179,.206),hair,'Head')
def tuft(n,base,tip,rx,ry,m):
 mid=Vector(base).lerp(Vector(tip),.56)
 o=loft(n,[(*base,rx,ry),(*mid,rx*.70,ry*.68),(*tip,.004,.004)],m,'Head',6)
 for p in o.data.polygons:p.use_smooth=False
for i,(base,tip,rx,ry) in enumerate([
 ((-.14,-.06,1.90),(-.27,-.07,2.12),.11,.115),((-.06,-.05,1.96),(-.16,-.045,2.198),.125,.12),((.06,-.075,1.97),(.035,-.07,2.15),.13,.13),((.15,-.075,1.91),(.27,-.08,2.085),.105,.11),((.16,-.13,1.83),(.29,-.16,1.95),.09,.09),((-.16,-.13,1.82),(-.28,-.17,1.94),.09,.09),((-.13,.066,1.9),(-.185,.148,1.718),.079,.067),((-.04,.099,1.96),(-.065,.174,1.764),.076,.061),((.05,.095,1.94),(.055,.18,1.79),.069,.056),((.13,.067,1.90),(.176,.126,1.744),.067,.067)]):tuft('Swept hair lock %02d'%i,base,tip,rx,ry,hairlit if i in [1,3] else hair)
# Pack UVs for editing/painting; materials remain portable metallic/roughness.
bpy.ops.object.select_all(action='DESELECT')
for o in geo:o.select_set(True)
bpy.context.view_layer.objects.active=geo[0];bpy.ops.object.join();new=bpy.context.object;new.name='EDO_EMBER_V01_Surface'
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
new['asset_id']='EDO_EMBER_V01';rig['asset_id']='EDO_EMBER_V01';rig.animation_data_clear()
bpy.ops.object.select_all(action='DESELECT');new.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(EXPORT/'edo_ember_v01.glb'),export_format='GLB',use_selection=True,export_skins=True,export_animations=False,export_yup=True)
# A studio comparison scene also retains the unmodified shipped surface.
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=False;s.render.resolution_x=900;s.render.resolution_y=1000;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('Cool studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.19,.24,1)
for loc,power,size in [((3,4,6),600,5),((-3,2,3),350,4),((1,-4,5),700,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Studio floor';floor.location.z=-.015;floor.data.materials.append(mat('Studio slate',(.065,.083,.107)))
bpy.ops.object.camera_add();cam=bpy.context.object;s.camera=cam
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Edo_Ember_v01.blend'))
report={'asset_id':'EDO_EMBER_V01','base_commit':'65fa8b1','rig_rest_unchanged':rest=={b.name:[list(row) for row in b.matrix_local] for b in rig.data.bones},'bone_count':len(rest),'vertices':len(new.data.vertices),'triangles':sum(len(p.vertices)-2 for p in new.data.polygons),'source_note':'Blender 5.2 original unreadable by installed Blender 4.3; shipped GLB imported for exact skeleton and before surface. Original source preserved.','reference':'Ed, Brave Fencer Musashi artwork; user-facing name Edo','preview_only':True}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
for name,loc in [('front',(0,7,2.1)),('threequarter',(3.5,7,3.0)),('side',(7,0,2.1)),('rear',(0,-7,2.1))]:
 cam.location=loc;cam.rotation_euler=(Vector((0,0,1.10))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.65
 for variant in ['before','after']:
  if variant=='before' and (OUT/'Previews'/f'{name}_{variant}.png').exists():continue
  old.hide_render=variant!='before';new.hide_render=variant!='after';s.render.filepath=str(OUT/'Previews'/f'{name}_{variant}.png');bpy.ops.render.render(write_still=True)
old.hide_render=True;new.hide_render=False
cam.location=(3.5,7,3);cam.rotation_euler=(Vector((0,0,1.1))-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Edo_Ember_v01.blend'))

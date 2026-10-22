"""Blender-only Samurai katana draft. Never writes runtime assets or the source model."""
from pathlib import Path
import bpy,bmesh,math,json,hashlib
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
SOURCE=ROOT/'assets/blender/characters/goemon_cosplay/samurai.blend'
TARGET=OUT/'Samurai_Weapon_Workbench.blend'
if TARGET.exists():raise RuntimeError('Preserve edited workbench; do not overwrite it with the generator.')
(OUT/'.gdignore').write_text('\n')
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.name='01 — Samurai with maroon katana'
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
rig=bpy.data.objects['Reference_Rig'];weapon=bpy.data.objects['Weapon_Cutlass']
bpy.context.view_layer.update()
body_names=['Skin','Hair_Normal','Costume_samurai','ScarfTail_Geometry']
def mesh_digest(obj):
 d={'vertices':[list(v.co) for v in obj.data.vertices],'faces':[list(p.vertices) for p in obj.data.polygons], 'uv':[[list(v.uv) for v in layer.data] for layer in obj.data.uv_layers]}
 return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
body_before={n:mesh_digest(bpy.data.objects[n]) for n in body_names}
bones_before={b.name:[list(row) for row in b.matrix_local] for b in rig.data.bones}
source_points=[]
for ob in [weapon]+list(weapon.children_recursive):
 if ob.type=='MESH':
  rel=weapon.matrix_world.inverted()@ob.matrix_world
  source_points.extend(rel@v.co for v in ob.data.vertices)
# Start with the old sleeve frame; the final refit below fits it to the new blade.
G_AXIS=Vector((-.44,1.08,.006)).normalized();G_FRAME=Vector((0,1,0)).rotation_difference(G_AXIS).to_matrix()
B_AXIS=Vector((G_AXIS.x,-G_AXIS.z,G_AXIS.y));B_FRAME=Vector((0,0,1)).rotation_difference(B_AXIS).to_matrix()
def to_g(v):return Vector((v.x,v.z,-v.y))
def to_b(v):return Vector((v.x,-v.z,v.y))
points=[G_FRAME.inverted()@to_g(p) for p in source_points]
old_extent=max(p.y for p in points);radius=Vector((.052,.034))
for p in points:
 if p.y>=.23:radius.x=max(radius.x,max(abs(p.x),abs(p.x+.045))+.022);radius.y=max(radius.y,abs(p.z-.005)+.020)
margin=1.0
for p in points:
 if p.y>=.23:margin=max(margin,Vector((max(abs(p.x),abs(p.x+.045))/radius.x,abs(p.z-.005)/radius.y)).length*1.05)
radius*=margin
blade_start=.23;new_extent=blade_start+(old_extent-blade_start)*1.55
print('KATANA_DIMENSIONS old_tip=',old_extent,'new_tip=',new_extent,'sheath_radius=',tuple(radius),flush=True)
# Original model remains in its own hidden collection, available for comparison.
archive=bpy.data.collections.new('Archive — original katana (unchanged)');scene.collection.children.link(archive);archive.hide_render=True;archive.hide_viewport=True
old=bpy.data.objects['Weapon_Cutlass_Geometry']
for collection in list(old.users_collection):collection.objects.unlink(old)
archive.objects.link(old);old.hide_select=True
bow=bpy.data.objects.get('Weapon_Pistol_Geometry')
if bow:bow.hide_render=True;bow.hide_set(True)
art=bpy.data.collections.new('Katana — editable blade, guard, grip and chain');scene.collection.children.link(art)
sheath_collection=bpy.data.collections.new('Sheath — frozen original size');scene.collection.children.link(sheath_collection)
presentation=bpy.data.collections.new('Presentation — lights and floor');scene.collection.children.link(presentation)
def mat(name,hex_,metal=0,rough=.45):
 m=bpy.data.materials.new(name);m.use_nodes=True
 values=[int(hex_[i:i+2],16)/255 for i in (0,2,4)];linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values]
 m.diffuse_color=(*linear,1);p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*linear,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 return m
wine=mat('Katana • deep maroon steel','79172c',.68,.32)
edge=mat('Katana • honed ruby cutting bevel','ce4855',.78,.27)
ridge=mat('Katana • oxblood spine','380f1d',.7,.38)
iron=mat('Katana • dark warm iron','29212b',.72,.34)
red=mat('Katana • maroon rayskin grip','7e182a',.02,.67)
wrap=mat('Katana • charcoal braid','17151d',.06,.64)
trim=mat('Katana • burgundy metal fittings','5c1828',.7,.33)
oldred=mat('Original sheath • existing vermilion lacquer','b82032',0,.48)
olddark=mat('Original sheath • existing dark mouth','241922',0,.7)
parts=[]
def mesh(name,verts,faces,materials,indices=None,collection=art,parent=None,bevel=0):
 me=bpy.data.meshes.new(name+' • mesh');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(name,me);collection.objects.link(ob)
 for m in materials:me.materials.append(m)
 if indices:
  for p,i in zip(me.polygons,indices):p.material_index=i
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
 if parent:ob.parent=parent
 if bevel:
  mod=ob.modifiers.new('Small machined edge bevel','BEVEL');mod.width=bevel;mod.segments=2
  mod=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 return ob
model=bpy.data.objects.new('Katana_Design — grip origin + original blade axis',None);art.objects.link(model);model.parent=weapon;model.rotation_mode='QUATERNION';model.rotation_quaternion=B_FRAME.to_quaternion()
# Long solid blade, broad maroon flats and a real narrow cutting bevel.
verts=[];sections=22;cross_count=7
for i in range(sections):
 t=i/(sections-1)*.955;z=blade_start+.065+(new_extent-blade_start-.065)*t
 curve=-.075*t*t;width=.137*(1-.12*t)
 if t>.86:width*=1-.24*(t-.86)/.095
 cutting=curve-width/2;back=curve+width/2;depth=.015*(1-.4*t)
 verts += [(back,-depth*.3,z),(back-.012,-depth,z),(cutting+.028,-depth*.85,z),(cutting,0,z),(cutting+.028,depth*.85,z),(back-.012,depth,z),(back,depth*.3,z)]
faces=[tuple(reversed(range(cross_count)))];indices=[2]
for i in range(sections-1):
 for j in range(cross_count):faces.append((i*7+j,i*7+(j+1)%7,(i+1)*7+(j+1)%7,(i+1)*7+j));indices.append([2,0,1,1,0,2,2][j])
tip=len(verts);verts.append((-.115,0,new_extent))
for j in range(7):faces.append(((sections-1)*7+j,(sections-1)*7+(j+1)%7,tip));indices.append([2,0,1,1,0,2,2][j])
blade=mesh('Katana_Blade — enlarged maroon steel',verts,faces,[wine,edge,ridge],indices,parent=model);parts.append(blade)
blade['blade_length_multiplier']=1.55;blade['edit_note']='Independent blade mesh. The original-size sheath must NOT follow its scale.'
# Geometric open guard: central rectangular ring and four stepped iron hooks.
def box(name,center,size,material,parent=model,collection=art,bevel=.003):
 x,y,z=center;a,b,c=[v/2 for v in size];vs=[(x+sx*a,y+sy*b,z+sz*c) for sx,sy,sz in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
 return mesh(name,vs,[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)],[material],collection=collection,parent=parent,bevel=bevel)
guard=bpy.data.objects.new('Katana_Guard — open stepped iron',None);art.objects.link(guard);guard.parent=model;parts.append(guard)
# Bars are separate editable pieces with hollow negative spaces.
for name,center,size in [('north',(0,.079,.23),(.19,.031,.032)),('south',(0,-.079,.23),(.19,.031,.032)),('east',(.079,0,.23),(.031,.128,.032)),('west',(-.079,0,.23),(.031,.128,.032))]:box('Guard inner ring '+name,center,size,iron,parent=guard)
for i in range(4):
 angle=i*math.pi/2;R=Matrix.Rotation(angle,3,'Z')
 for j,(center,size) in enumerate([((.138,-.082,.23),(.029,.199,.034)),((.085,-.166,.23),(.135,.029,.034))]):
  p=Vector(center);p.z=.23;ob=box('Guard stepped arm %d.%d'%(i+1,j+1),p,size,iron,parent=guard);ob.rotation_euler.z=angle
# Oval grip and collars; the grip's red lozenges show between crossed black braids.
def oval_loft(name,rings,material,parent=model):
 v=[];n=12
 for z,rx,ry in rings:
  v.extend((math.cos(j*math.tau/n)*rx,math.sin(j*math.tau/n)*ry,z) for j in range(n))
 f=[tuple(reversed(range(n))),tuple((len(rings)-1)*n+j for j in range(n))]
 for k in range(len(rings)-1):
  for j in range(n):f.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
 ob=mesh(name,v,f,[material],parent=parent);parts.append(ob);return ob
oval_loft('Katana_Grip — maroon rayskin',[(-.285,.048,.031),(-.25,.052,.034),(.17,.053,.034),(.205,.052,.033)],red)
oval_loft('Katana_Fuchi — collar',[(.19,.059,.039),(.226,.059,.039)],iron)
oval_loft('Katana_Habaki — maroon blade collar',[(.25,.073,.027),(.315,.073,.027)],trim)
oval_loft('Katana_Kashira — capped pommel',[(-.318,.055,.038),(-.282,.055,.038)],iron)
# Two counterwound low-poly wrap ribbons. Their spacing leaves real diamonds.
for handedness in [-1,1]:
 v=[];f=[];steps=144;turns=7.4
 for i in range(steps+1):
  t=i/steps;angle=t*turns*math.tau*handedness
  for dz in [-.009,.009]:v.append((math.cos(angle)*.056,math.sin(angle)*.038,.19-.46*t+dz))
 for i in range(steps):f.append((2*i,2*i+1,2*i+3,2*i+2))
 ob=mesh('Katana_Wrap — '+('clockwise' if handedness==1 else 'counterclockwise'),v,f,[wrap],parent=model);solid=ob.modifiers.new('Braided cord thickness','SOLIDIFY');solid.thickness=.003;parts.append(ob)
# Short interlocking iron chain; all links remain one editable low-poly mesh.
chain_v=[];chain_f=[]
for link in range(12):
 theta=link*.25;center=Vector((.022+.15*(1-math.cos(theta)),0,-.335-.15*math.sin(theta)))
 tangent=Vector((math.sin(theta),0,-math.cos(theta)));side=Vector((math.cos(theta),0,math.sin(theta))) if link%2==0 else Vector((0,1,0))
 normal=side.cross(tangent).normalized();base=len(chain_v)
 for j in range(12):
  a=j*math.tau/12;radial=(side*math.cos(a)+tangent*math.sin(a)).normalized();mid=center+side*(.019*math.cos(a))+tangent*(.027*math.sin(a))
  for k in range(4):chain_v.append(mid+.004*(radial*math.cos(k*math.tau/4)+normal*math.sin(k*math.tau/4)))
 for j in range(12):
  for k in range(4):chain_f.append((base+j*4+k,base+((j+1)%12)*4+k,base+((j+1)%12)*4+(k+1)%4,base+j*4+(k+1)%4))
chain=mesh('Katana_Chain — twelve interlocking pommel links',chain_v,chain_f,[iron],parent=model);parts.append(chain)
# Initial sleeve in the existing native coordinate system; refitted below.
sheath_root=bpy.data.objects.new('Sheath_ORIGINAL_SIZE — independent from katana scale',None);sheath_collection.objects.link(sheath_root)
def sleeve(name,centers,radii,material):
 v=[];n=12;f=[]
 for p,r in zip(centers,radii):
  for j in range(n):
   a=j*math.tau/n;v.append(to_b(G_FRAME@(p+Vector((math.cos(a)*r.x,0,math.sin(a)*r.y)))))
 for k in range(len(centers)-1):
  for j in range(n):f.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
 ob=mesh(name,v,f,[material],parent=sheath_root,collection=sheath_collection);sol=ob.modifiers.new('Existing thin sleeve wall','SOLIDIFY');sol.thickness=.004;return ob
centers=[Vector((-.045*math.sin(math.pi*i/16),.23+(old_extent+.028-.23)*i/16,.005)) for i in range(17)]
sleeve('Sheath_Shell — frozen existing profile',centers,[radius]*17,oldred)
sleeve('Sheath_Mouth — existing dark lip',[centers[0],centers[0]+Vector((0,.045,0))],[radius*1.12]*2,olddark)
sheath_root['frozen_source_tip_extent']=old_extent;sheath_root['do_not_scale_with_katana']=True
# Readable display-only relaxed arms; original rest rig and all body data stay intact.
for name,angle in [('Arm_R',math.radians(50)),('Arm_L',math.radians(-48))]:
 pb=rig.pose.bones[name];head=rig.data.bones[name].head_local.copy();pb.matrix=Matrix.Translation(head)@Matrix.Rotation(angle,4,'Y')@Matrix.Translation(-head)@rig.data.bones[name].matrix_local
bpy.context.view_layer.update()
for name,angle in [('Forearm_R',math.radians(12)),('Forearm_L',math.radians(-8))]:
 pb=rig.pose.bones[name];head=pb.matrix.translation.copy();pb.matrix=Matrix.Translation(head)@Matrix.Rotation(angle,4,'Y')@Matrix.Translation(-head)@pb.matrix
bpy.context.view_layer.update()
right=rig.matrix_world@rig.pose.bones['Hand_R'].head;left=rig.matrix_world@rig.pose.bones['Hand_L'].head
D=Vector((-.39,-.10,.915)).normalized();desired=Vector((0,0,1)).rotation_difference(D).to_matrix()
weapon.parent=rig;weapon.parent_type='BONE';weapon.parent_bone='Hand_R';weapon.matrix_world=Matrix.Translation(right)@(desired@B_FRAME.inverted()).to_4x4()@Matrix.Scale(1.15,4)
SD=Vector((.08,.97,-.16)).normalized();SR=Vector((0,0,1)).rotation_difference(SD).to_matrix()
sheath_root.matrix_world=Matrix.Translation(left)@(SR@B_FRAME.inverted()).to_4x4()@Matrix.Scale(1.15,4)
rig.show_in_front=True;rig.hide_render=True;rig.hide_set(True)
scene['draft_scope']='BLENDER ONLY — new katana; fixed-size original sheath. Game files and build are unchanged.'
# Neutral art-review lights and floor, kept separate from asset geometry.
floor_mat=mat('Studio • midnight slate','242934',0,.82)
def studio(sc,collection):
 sc.render.engine='CYCLES';sc.cycles.samples=40;sc.cycles.use_denoising=True
 sc.render.resolution_x=1200;sc.render.resolution_y=1400;sc.render.resolution_percentage=100
 sc.world=bpy.data.worlds.new(sc.name+' • studio world');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.16,.18,.23,1);sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
 for name,pos,power,size,color in [('Key',(3,-5,6),1300,4.0,(1,.86,.79)),('Fill',(-4,-3,3),1000,4.0,(.78,.85,1)),('Rim',(1,3,5),1600,3.0,(1,.60,.50))]:
  data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color;ob=bpy.data.objects.new(name,data);collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,1.5))-ob.location).to_track_quat('-Z','Y').to_euler()
 floor=box('Studio_Floor',(0,0,-.08),(200,200,.1),floor_mat,parent=None,collection=collection,bevel=0)
 cam_data=bpy.data.cameras.new(sc.name+' • Camera');cam=bpy.data.objects.new('Camera — '+sc.name,cam_data);collection.objects.link(cam);cam_data.type='ORTHO';sc.camera=cam
 sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast'
 return cam
cam=studio(scene,presentation);cam.location=(4.5,-8,4.0);cam.rotation_euler=(Vector((-.1,0,1.55))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=4.35
# Second scene puts actual editable weapon data beside the original-size sheath.
detail=bpy.data.scenes.new('02 — Katana and unchanged sheath');dc=bpy.data.collections.new('Weapon detail — linked meshes');detail.collection.children.link(dc)
dp=bpy.data.collections.new('Detail studio — lights, camera and labels');detail.collection.children.link(dp)
bpy.context.view_layer.update()
canonical_root=bpy.data.objects.new('Katana detail root',None);dc.objects.link(canonical_root);canonical_root.location=(-.28,0,.74)
for ob in [model]+list(model.children_recursive):
 if ob.type!='MESH':continue
 clone=ob.copy();clone.data=ob.data;dc.objects.link(clone);clone.parent=canonical_root;clone.matrix_parent_inverse=Matrix.Identity(4)
 clone.matrix_basis=model.matrix_world.inverted()@ob.matrix_world
 clone.name='Detail • '+ob.name
sr=bpy.data.objects.new('Sheath detail — original size',None);dc.objects.link(sr);sr.location=(.38,.06,.74);sr.rotation_mode='QUATERNION';sr.rotation_quaternion=B_FRAME.inverted().to_quaternion()
for ob in sheath_root.children:
 clone=ob.copy();clone.data=ob.data;dc.objects.link(clone);clone.parent=sr;clone.matrix_parent_inverse=Matrix.Identity(4);clone.matrix_basis=ob.matrix_local;clone.name='Detail • '+ob.name
# Reference board is packed in the blend and available in the image editor.
ref=bpy.data.images.load(str(OUT/'reference-katana.png'));ref.pack();ref.use_fake_user=True;ref.name='REFERENCE — user katana (maroon adaptation)'
dcam=studio(detail,dp);detail.render.resolution_x=1300;detail.render.resolution_y=1600
dcam.location=(.5,-7,2.45);dcam.rotation_euler=(Vector((0,0,1.3))-dcam.location).to_track_quat('-Z','Y').to_euler();dcam.data.ortho_scale=max(2.95,new_extent+1.1)
# Fit the independent scabbard to the final blade geometry (current user direction).
import runpy
scabbard_fit=runpy.run_path(str(OUT/'fit_scabbard.py'),run_name='scabbard_geometry')['refit']()
# Clean editable modeling layout, with the blade selected and frame fitted.
for workspace in bpy.data.workspaces:
 for screen in workspace.screens:
  for area in screen.areas:
   if area.type=='VIEW_3D':
    space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_world=False;space.shading.use_scene_lights=False
    space.overlay.show_floor=False;space.overlay.show_axis_x=False;space.overlay.show_axis_y=False;space.overlay.show_extras=False
    space.region_3d.view_perspective='ORTHO';space.region_3d.view_location=Vector((-.15,0,1.55));space.region_3d.view_distance=4.8;space.region_3d.view_rotation=Vector((-.35,1,-.2)).to_track_quat('-Z','Y')
   if area.type=='PROPERTIES':area.spaces.active.context='MATERIAL'
for ob in bpy.context.selected_objects:ob.select_set(False)
blade.select_set(True);bpy.context.view_layer.objects.active=blade
# Verify that body and the original rest rig remain exactly unchanged.
body_after={n:mesh_digest(bpy.data.objects[n]) for n in body_names};assert body_before==body_after
assert bones_before=={b.name:[list(row) for row in b.matrix_local] for b in rig.data.bones}
report={'scope':'Blender-only design draft; no runtime assets exported','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'body_meshes_unchanged':body_before==body_after,'rest_bones_unchanged':True,'old_source_tip_extent':old_extent,'new_source_tip_extent':new_extent,'blade_length_multiplier':1.55,'scabbard_fit':scabbard_fit,'sheath_follows_new_blade_scale':False,'weapon_mesh_objects':len([o for o in art.objects if o.type=='MESH']),'weapon_triangles_estimate':sum(len(p.vertices)-2 for o in art.objects if o.type=='MESH' for p in o.data.polygons),'scenes':[scene.name,detail.name]}
(OUT/'verification.json').write_text(json.dumps(report,indent=2))
guide=(OUT/'START_HERE.txt').read_text()
bpy.data.texts.new('START HERE — Samurai katana draft').write(guide);(OUT/'START_HERE.txt').write_text(guide)
bpy.ops.file.pack_all();bpy.context.window.scene=scene
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
scene.render.filepath=str(OUT/'samurai-preview.png');bpy.ops.render.render(write_still=True,scene=scene.name)
detail.render.filepath=str(OUT/'katana-detail.png');bpy.ops.render.render(write_still=True,scene=detail.name)
print('SAMURAI_WORKBENCH_OK',json.dumps(report),flush=True)

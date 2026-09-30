"""One-time import of the user-supplied Goemon OBJ. No remeshing or UV changes.
Normal future editing: assets/blender/characters/kai.blend + export_blender.py.
"""
import bpy, math, ast, json, shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/references/goemon_original/Goe'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=str(SOURCE/'goe.obj'),forward_axis='NEGATIVE_Z',up_axis='Y')
obj=bpy.context.object
# Source Y up, +Z facing forward. Uniform transform only; retain original asymmetry.
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
scale=3.3/(194.5236+.2312)
for v in obj.data.vertices:
    p=v.co.copy();v.co=Vector((-p.x,-p.y,p.z+.2312))*scale
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
texture_dir=ROOT/'assets/textures/characters';texture_dir.mkdir(parents=True,exist_ok=True)
shutil.copy2(SOURCE/'goe128_2.png',texture_dir/'goemon_original.png')
material=obj.data.materials[0];material.name='Goemon_Original_Atlas'
bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=1;bsdf.inputs['Specular IOR Level'].default_value=0
for n in material.node_tree.nodes:
    if n.type=='TEX_IMAGE':
        n.image.filepath=str(texture_dir/'goemon_original.png');n.interpolation='Closest';n.image.pack()
# Connected source islands allow rigid weights without altering original geometry.
adj={v.index:set() for v in obj.data.vertices}
for poly in obj.data.polygons:
    for i in poly.vertices:adj[i].update(poly.vertices)
seen=set();islands=[]
for i in adj:
    if i in seen:continue
    q=[i];seen.add(i);c=[]
    while q:
        j=q.pop();c.append(j)
        for k in adj[j]-seen:seen.add(k);q.append(k)
    islands.append(c)
hair_ids=set()
for c in islands:
    points=[obj.data.vertices[i].co for i in c];lo=min(p.z for p in points)/scale-.2312;hi=max(p.z for p in points)/scale-.2312
    center=sum(points,Vector())/len(points)
    if lo>120:bone='Head';hair_ids.update(c)
    elif lo>85:bone='Head'
    elif lo>62 and abs(center.x)>.5:bone='Arm_L' if center.x<0 else 'Arm_R'
    elif hi<63:bone='Leg_L' if center.x<0 else 'Leg_R'
    else:bone='Root'
    group=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone);group.add(c,1,'REPLACE')
# Split only the existing hair triangles to support the existing R material switch.
bpy.context.view_layer.objects.active=obj
for v in obj.data.vertices:v.select=v.index in hair_ids
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_mode(type='VERT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
hair=max(meshes,key=lambda o:min(v.co.z for v in o.data.vertices));hair.name='Hair_Normal';obj.name='Skin'
gold=hair.copy();gold.data=hair.data.copy();bpy.context.collection.objects.link(gold);gold.name='Hair_Gold'
goldmat=bpy.data.materials.new('Surge_Gold');goldmat.use_nodes=True
p=goldmat.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(1,.72,.015,1);p.inputs['Roughness'].default_value=.65;p.inputs['Emission Color'].default_value=(1,.45,.005,1);p.inputs['Emission Strength'].default_value=.22
gold.data.materials.clear();gold.data.materials.append(goldmat)
# Reuse the established 13 editable actions, now with source-specific joint positions.
BONES={'Root':(0,0,0),'Head':(0,85.5*scale,0),'Arm_L':(-24*scale,77*scale,0),'Arm_R':(24*scale,77*scale,0),'Leg_L':(-15*scale,57*scale,0),'Leg_R':(15*scale,57*scale,0),'Sash':(0,55*scale,-20*scale)}
def cv(p):return Vector((p[0],-p[2],p[1]))
tree=ast.parse((ROOT/'tools/build_blender_assets.py').read_text())
fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='rig_model')
# Add the T-pose-to-gameplay arm lowering before authored keys, without changing bind geometry.
code=ast.get_source_segment((ROOT/'tools/build_blender_assets.py').read_text(),fn)
code=code.replace("b.keyframe_insert('rotation_euler'", "\n                if b.name=='Arm_L':b.rotation_euler.z+=math.pi/2\n                if b.name=='Arm_R':b.rotation_euler.z-=math.pi/2\n                b.keyframe_insert('rotation_euler'")
exec(code)
bpy.ops.object.select_all(action='DESELECT')
rig=rig_model([obj,hair,gold]);rig.name='Reference_Rig'
gold.hide_set(True);gold.hide_render=True
scene=bpy.context.scene;scene['asset_id']='characters/kai';scene['source']='User-supplied Goemon.zip / Goe/goe.obj + goe128_2.png';scene['geometry_policy']='Original vertices, faces and UVs. Uniform scale and orientation only. Gold uses identical mesh.'
scene['source_height']=194.7548;scene['game_height']=3.3;scene['godot_forward']='-Z'
# Persistent matching-reference camera and portable studio, excluded from GLB by exporter.
collection=bpy.data.collections.new('REFERENCE_STUDIO');scene.collection.children.link(collection)
def studio_obj(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o);o['export_exclude']=True
bpy.ops.object.camera_add(location=(3.5,7.4,2.15));cam=bpy.context.object;cam.name='Reference_Camera';studio_obj(cam);cam.data.type='PERSP';cam.data.lens=70;cam.data.ortho_scale=4.15;cam.rotation_euler=(Vector((0,0,1.65))-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
for loc,power,size in [(( -3,4,7),500,5),((3,1,4),120,4)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;studio_obj(o);o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,1.6))-o.location).to_track_quat('-Z','Y').to_euler()
scene.world=bpy.data.worlds.new('Reference_White');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(1,1,1,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=480;scene.render.resolution_y=416;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True
# Source opens at its untouched T pose; gameplay applies arm offsets via the wrapper.
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/characters/kai.blend'))
for name,pos in [('reference',(3.5,7.4,2.15)),('front',(0,8,1.65)),('back',(0,-8,1.65)),('left',(8,0,1.65)),('right',(-8,0,1.65))]:
    cam.location=pos;cam.rotation_euler=(Vector((0,0,1.65))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(ROOT/'tests'/('reference-source-'+name+'.png'));bpy.ops.render.render(write_still=True)
print('SOURCE_JOINTS',json.dumps(BONES));print('REFERENCE_IMPORTED',sum(len(o.data.polygons) for o in [obj,hair]),'faces')

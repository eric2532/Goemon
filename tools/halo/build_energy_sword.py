"""Build an editable CE sword viewmodel using recovered native disc geometry.

Blender --background --python tools/halo/build_energy_sword.py
Native CE has no usable sword FP asset. The actual campaign sword mesh and UVs
are attached to native Chief right-hand pistol idle/ready/melee clips. No weapon
geometry is invented. Only the right arm is shown, keeping a one-handed grip.
Source coordinates: X forward/Y left/Z up; 100 JMS units = 3.048 meters.
"""
import bpy,json,math,shutil,sys
from pathlib import Path
from mathutils import Matrix,Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_master_chief as chief
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'assets/blender/master_chief/energy_sword'
OUT=ROOT/'assets/characters/master_chief'
D=json.loads((SRC/'decoded_energy_sword.json').read_text())
bpy.context.preferences.filepaths.save_version=0

# Preserve original atlas and UVs. glTF emission is a portable preview of the
# retail Chicago additive shader; Godot may replace these named blade materials
# with an additive unshaded material for the same native effect.
def sword_material(name):
 if name in bpy.data.materials:return bpy.data.materials[name]
 m=bpy.data.materials.new(name);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF')
 tex=m.node_tree.nodes.new('ShaderNodeTexImage')
 tex.image=bpy.data.images.load(str(SRC/'source_data/weapons/energy sword/bitmaps/energy sword.png'),check_existing=True)
 tex.image.pack();m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
 if 'blade' in name:
  m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=2.7
  m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);bs.inputs['Roughness'].default_value=1
  m.surface_render_method='DITHERED';m.use_backface_culling=False
 else:bs.inputs['Metallic'].default_value=.65;bs.inputs['Roughness'].default_value=.4
 return m

for animation in D['adapted_first_person_animations'].values():chief.ensure_parents(animation['nodes'])
base=D['sword'];chief.ensure_parents(base['nodes'])
root=chief.new_scene()
animations=D['adapted_first_person_animations'];nodes=[dict(n) for n in animations['idle']['nodes']]
# Grip axis remains across the palm. Raise the real blade diagonally and roll
# its broad faces toward the camera so both original plasma prongs are readable.
attachment=Matrix.Translation(Vector((-1.25,0,-2.5))) @ Matrix.Rotation(math.radians(-26),4,'Y') @ Matrix.Rotation(math.radians(70),4,'X')
weapon_bind=chief.worlds(base['nodes']);offset=len(nodes)
remap={n['name']:'sword '+n['name'] for n in base['nodes']}
gun_index=next(i for i,n in enumerate(nodes) if n['name']=='frame gun')
for n in base['nodes']:
 nn=dict(n);nn['name']=remap[n['name']];nn['parent']=offset+n['parent'] if n['parent']>=0 else gun_index;nodes.append(nn)
def posed(a,frame):
 result=chief.worlds(a['nodes'],frame);attach=result['frame gun']@attachment
 for n in base['nodes']:result[remap[n['name']]]=attach@weapon_bind[n['name']]
 return result
idle=posed(animations['idle'],animations['idle']['frames'][0]);rig=chief.create_rig(root,nodes,idle,'EnergySwordRig')
arms=json.loads(json.dumps(chief.D['arms']));chief.ensure_parents(arms['nodes'])
# Native arm surfaces are separate islands. Retain the authored right-arm
# triangles; omitting the cupped support hand avoids an empty gun support pose.
arms['triangles']=[t for t in arms['triangles'] if any(' r ' in arms['nodes'][bi]['name'] for vi in t['indices'] for bi,w in zip(arms['vertices'][vi]['bones'],arms['vertices'][vi]['weights']) if bi>=0 and w>.01)]
used=sorted({i for t in arms['triangles'] for i in t['indices']});reindex={old:new for new,old in enumerate(used)}
arms['vertices']=[arms['vertices'][i] for i in used]
for triangle in arms['triangles']:triangle['indices']=[reindex[i] for i in triangle['indices']]
chief.create_mesh(root,rig,arms,chief.worlds(arms['nodes']),idle,'MasterChiefRightArm')
# create_mesh uses chief's factory; intercept only the three sword materials.
original_material=chief.material
chief.material=lambda name,index=0:sword_material(name) if name.startswith('es ') else original_material(name,index)
chief.create_mesh(root,rig,base,weapon_bind,idle,'NativeEnergySword',remap)
chief.animate(rig,nodes,animations,posed)
# Runtime anchors follow the actual sword bone and remain available in glTF.
for name,position in [('BladeBase',(0,0,.8)),('BladeTip',(35,0,.8)),('Muzzle',(30,0,.8))]:
 marker=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(marker)
 marker.parent=rig;marker.parent_type='BONE';marker.parent_bone=remap['frame handle']
 bpy.context.view_layer.update();marker.matrix_world=root.matrix_world@idle[remap['frame handle']]@Matrix.Translation(Vector(position))
glow_anchors=[]
for chain in (1,2):
 for index,native in enumerate(m for m in base['markers'] if m['name']=='glow '+str(chain)):
  name=f'SwordGlow{chain}_{index}';glow_anchors.append(name)
  marker=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(marker)
  marker.parent=rig;marker.parent_type='BONE';marker.parent_bone=remap['frame handle']
  native_bone=base['nodes'][native['parent']]['name']
  bpy.context.view_layer.update();marker.matrix_world=root.matrix_world@idle[remap['frame handle']]@weapon_bind[native_bone]@chief.local(native)
chief.SRC=SRC
chief.export('energy_sword_fp',root,rig)
# Keep one original decoded animation cue as the attack sample. This is the
# Elite's native sword animation foley; it is not a newly synthesized hum.
sample=SRC/'source_data/sound/sfx/impulse/animations/elite/stand_sword_melee/stand_sword_melee_uh.wav'
shutil.copy2(sample,OUT/'energy_sword_swing.wav')
shutil.copy2(SRC/'source_data/weapons/energy sword/bitmaps/energy sword.png',OUT/'energy_sword_texture.png')
shutil.copy2(SRC/'source_data/rasterizer/glow sprite.png',OUT/'energy_sword_glow.png')
metadata=json.loads((SRC/'energy_sword_fp_metadata.json').read_text())
metadata.update({'native_source':'User-supplied Halo Combat Evolved Xbox disc, maps/a50.map','native_mesh_tag':'weapons\\energy sword\\energy sword','materials':base['materials'],'native_bitmap':'source_data/weapons/energy sword/bitmaps/energy sword.png','adaptation':D['provenance']['first_person'],'grip':'Chief native right-hand pistol grip, left support arm omitted; sword model rigidly follows frame gun','sword_attachment_jms':list(map(list,attachment)),'swing_sound_native_tag':'sound\\sfx\\impulse\\animations\\elite\\stand_sword_melee.mov','retail_blade_shader':'shader_transparent_chicago framebuffer_blend_function=add','native_melee_damage':151,'native_damage_radius_m':1.524,'native_glow_anchors':glow_anchors,'native_glow_markers':base['markers'],'original_model_vertices':len(base['vertices']),'original_model_triangles':len(base['triangles']),'first_person_clip_seconds':{k:(len(a['frames'])-1)/a['fps'] for k,a in animations.items()}})
(SRC/'energy_sword_fp_metadata.json').write_text(json.dumps(metadata,indent=2))
print('Sword complete',OUT/'energy_sword_fp.glb')

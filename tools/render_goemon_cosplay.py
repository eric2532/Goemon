"""Render the editable Goemon cosplay assets with shared cameras and lighting."""
import bpy
import math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/goemon-cosplay'
HEROES = ['goemon', 'edo', 'pirate', 'samurai', 'ninja', 'mage', 'knight', 'dragoon',
          'magic-swordsman', 'ranger', 'explorer', 'master-thief']
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 2400
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.world = bpy.data.worlds.new('Cosplay studio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.10, .13, .17, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .7
scene.view_settings.view_transform = 'Standard'
roots = []
for index, hero in enumerate(HEROES):
    with bpy.data.libraries.load(str(ROOT / 'assets/blender/characters/goemon_cosplay' / (hero + '.blend')), link=False) as (src, dst):
        dst.objects = src.objects
    objects = [ob for ob in dst.objects if ob]
    wrapper = bpy.data.objects.new(hero + '_review', None)
    scene.collection.objects.link(wrapper)
    for ob in objects:
        scene.collection.objects.link(ob)
        if not ob.parent:
            ob.parent = wrapper
    rig = next(ob for ob in objects if ob.type == 'ARMATURE')
    if hero in ['goemon', 'edo']:
        rig.rotation_euler.z = math.pi
    for side, sign in [('L', -1), ('R', 1)]:
        bone = rig.pose.bones['Arm_' + side]
        point = bone.bone.head_local
        turn = Matrix.Translation(point) @ Matrix.Rotation(sign * math.radians(75), 4, 'Y') @ Matrix.Translation(-point)
        bone.matrix = turn @ bone.bone.matrix_local
    wrapper.location = ((index % 6 - 2.5) * 3.85, 0, 5 if index < 6 else 0)
    roots.append(wrapper)
    label = bpy.data.curves.new(hero + '_label', 'FONT')
    label.body = hero.replace('-', ' ').title()
    label.align_x = 'CENTER'
    label.size = .25
    text = bpy.data.objects.new(hero + '_label', label)
    scene.collection.objects.link(text)
    text.location = (wrapper.location.x, -.7, wrapper.location.z - .38)
    text.rotation_euler = (math.pi / 2, 0, 0)
    mat = bpy.data.materials.new('label_' + hero)
    mat.diffuse_color = (.86, .88, .92, 1)
    label.materials.append(mat)
for loc, power, size in [((-8, -8, 12), 3000, 10), ((10, -4, 9), 2000, 10), ((0, 5, 12), 2400, 9)]:
    bpy.ops.object.light_add(type='AREA', location=loc)
    light = bpy.context.object
    light.data.energy = power
    light.data.shape = 'DISK'
    light.data.size = size
    light.rotation_euler = (Vector((0, 0, 4)) - light.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(0, -35, 4.4))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 4.4)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 24
scene.camera = camera
for name, angle in [('front', 0), ('three-quarter', math.pi / 5), ('side', math.pi / 2), ('back', math.pi)]:
    for wrapper in roots:
        wrapper.rotation_euler.z = angle
    scene.render.filepath = str(OUT / ('roster-' + name + '.png'))
    bpy.ops.render.render(write_still=True)
print('COSPLAY_REVIEW_RENDERED', OUT)

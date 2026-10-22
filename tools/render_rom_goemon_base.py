"""Render saved Blender master or --pilot with reproducible studio lighting."""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/blender/characters/rom_goemon_base'
OUT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/ROM Goemon Blender Base')
PILOT = '--pilot' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(DEST / ('master_thief.blend' if PILOT else 'goemon.blend')))
scene = bpy.context.scene
scene.render.engine = 'CYCLES';scene.cycles.samples = 24
scene.render.resolution_x = 640;scene.render.resolution_y = 640;scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG';scene.view_settings.view_transform = 'Standard'
scene.world = bpy.data.worlds.new('Preview world');scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.12, .15, .19, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .6
for location, energy, size in [((3, 4, 7), 650, 5), ((-4, 1, 4), 400, 4), ((0, -4, 5), 500, 3)]:
    bpy.ops.object.light_add(type='AREA', location=location);light = bpy.context.object
    light.data.energy = energy;light.data.shape = 'DISK';light.data.size = size
    light.rotation_euler = (Vector((0, 0, 1.5)) - light.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add();camera = bpy.context.object;scene.camera = camera
camera.data.type = 'ORTHO';camera.data.ortho_scale = 4.35
rig = bpy.data.objects['ROM_Goemon_Rig']
prefix = 'master-thief' if PILOT else 'base'
def render(action_id, index, angle, name):
    action = next(a for a in bpy.data.actions if a.get('rom_action') == action_id)
    rig.animation_data.action = action;frame = 1 + index / action['rom_rate']
    scene.frame_set(int(frame), subframe=frame % 1)
    camera.location = (math.sin(angle) * 8, math.cos(angle) * 8, 2.4)
    camera.rotation_euler = (Vector((0, 0, 1.5)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(OUT / (prefix + '-' + name + '.png'))
    bpy.ops.render.render(write_still=True)
for name, angle in [('front', 0), ('side', math.pi / 2), ('three-quarter', math.pi / 5), ('back', math.pi)]:render(0, 0, angle, name)
if '--motion' in sys.argv:
    run = next(a for a in bpy.data.actions if a.get('rom_action') == 15)
    for i in range(run['rom_frame_count']):render(15, i, math.pi / 3, 'run-%02d' % i)
    for action_id, name in [(24, 'jump'), (26, 'land'), (104, 'attack')]:
        action = next(a for a in bpy.data.actions if a.get('rom_action') == action_id)
        for i in [0, action['rom_frame_count'] // 2, action['rom_frame_count'] - 1]:render(action_id, i, math.pi / 5, name + '-%02d' % i)
print('ROM_GOEMON_RENDER_COMPLETE', prefix)

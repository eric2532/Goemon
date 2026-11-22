"""Bake the saved Aoi master to eight-direction sprites; never rebuild geometry."""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / 'assets/blender/characters/aoi/aoi.blend'
OUT = ROOT / 'build/Other Files/Asset Toolkit/Aoi'
FRAMES = OUT / 'Frames'
SOURCE = ROOT / 'assets/characters/crossgate/kazi/motions.json'
SIZE = 512
PREVIEW = '--preview' in sys.argv
master_sha = hashlib.sha256(MASTER.read_bytes()).hexdigest()
clock_bytes = SOURCE.read_bytes()

bpy.ops.wm.open_mainfile(filepath=str(MASTER))
scene = bpy.context.scene
rig = bpy.data.objects['Reference_Rig']
for track in rig.animation_data.nla_tracks:
    track.mute = True
for ob in list(scene.objects):
    if ob.type in ['LIGHT', 'CAMERA']:
        bpy.data.objects.remove(ob, do_unlink=True)
scene.render.engine = 'BLENDER_EEVEE'
scene.eevee.taa_render_samples = 16
scene.render.resolution_x = SIZE * 3 // 2
scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.render.image_settings.color_depth = '8'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'Medium High Contrast' if 'Medium High Contrast' in [i.name for i in scene.bl_rna.properties] else 'None'
scene.world = bpy.data.worlds.new('Aoi sprite ambient')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.65, .70, .80, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .55
for location, power, size in [((-4, 6, 9), 1000, 6), ((4, 1, 5), 400, 5)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.data.energy = power
    light.data.shape = 'DISK'
    light.data.size = size
    light.rotation_euler = (Vector((0, 0, 1.5)) - light.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(0, 12, 8.25))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 1.5)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 13.8
camera.data.lens = 50
scene.camera = camera
FRAMES.mkdir(parents=True, exist_ok=True)
source = json.loads(clock_bytes)
clips = {}
actions = {0: 'Idle', 1: 'Walk', 3: 'Run', 5: 'Attack_Left',
           6: 'Throw', 8: 'Hit', 9: 'JumpStart', 10: 'Death'}
pipe_parts = [o for o in scene.objects if o.name.startswith('Pipe_')]
pipe_rest = {part: part.matrix_basis.copy() for part in pipe_parts}
pipe_modifiers = {m: (m.show_render, m.show_viewport) for part in pipe_parts
                  for m in part.modifiers if m.type == 'ARMATURE'}


def pose(action, progress):
    for part in pipe_parts:
        part.matrix_basis = pipe_rest[part]
    for modifier, (render, viewport) in pipe_modifiers.items():
        modifier.show_render, modifier.show_viewport = render, viewport
    animation = bpy.data.actions[actions[action]]
    # Two existing articulated swings, fitted to Kaz's two contact markers.
    if action == 5:
        first_contact, second_contact = 5 / 11, 6 / 11
        if progress <= first_contact:
            frame = 28 * progress / first_contact
        elif progress <= second_contact:
            animation = bpy.data.actions['Attack_Right']
            frame = 16 + 12 * (progress - first_contact) / (second_contact - first_contact)
        else:
            animation = bpy.data.actions['Attack_Right']
            frame = 28 + 32 * (progress - second_contact) / (1 - second_contact)
    else:
        frame = progress * (30 if action in [8, 9] else 60)
    rig.animation_data.action = animation
    if animation.slots:
        rig.animation_data.action_slot = animation.slots[0]
    scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    if action == 10:
        # The longer pipe rests beside the fallen body instead of entering the floor.
        hand = rig.pose.bones['Hand_R']
        deform = hand.matrix @ hand.bone.matrix_local.inverted()
        shaft = (deform.to_3x3() @ Vector((0, 1, 0))).normalized()
        if shaft.z < 0:
            flat = Vector((shaft.x, shaft.y, 0))
            if flat.length < .001:
                flat = Vector((0, 1, 0))
            turn = shaft.rotation_difference(flat.normalized()).to_matrix().to_4x4()
            grip = deform @ Vector((1.22, .02, 1.305))
            deform = Matrix.Translation(grip) @ turn @ Matrix.Translation(-grip) @ deform
        for part in pipe_parts:
            part.matrix_basis = deform @ pipe_rest[part]
            for modifier in part.modifiers:
                if modifier.type == 'ARMATURE':
                    modifier.show_render = modifier.show_viewport = False
        bpy.context.view_layer.update()


jobs = [(action, direction) for action in actions for direction in range(8)]
if '--actions' in sys.argv:
    selected = [int(value) for value in sys.argv[sys.argv.index('--actions') + 1:]]
    assert selected and all(action in actions for action in selected)
    saved = json.loads((OUT / 'render.json').read_text())
    assert saved['master_sha256'] == hashlib.sha256(MASTER.read_bytes()).hexdigest(), 'Render all actions after master changes'
    assert saved['clock_sha256'] == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    old_width = saved.get('width', saved['canvas'])
    assert saved['canvas'] == SIZE and abs(saved['ortho_scale'] / old_width - camera.data.ortho_scale / scene.render.resolution_x) < 1e-6
    bpy.context.view_layer.update()
    assert saved['camera_matrix'] == [list(row) for row in camera.matrix_world], 'Render all actions after camera changes'
    clips = saved['clips']
    jobs = [(a, d) for a, d in jobs if a in selected]
if PREVIEW:
    jobs = [(0, d) for d in range(8)] + [(5, 4), (3, 4)]
for action, direction in jobs:
    template = source['clips'].get(f'{action}:{direction}', {'duration': .2, 'frames': [None]})
    count = len(template['frames'])
    if PREVIEW:
        count = 1 if action == 0 else 6
    clip = {'duration': template['duration'], 'frames': [], 'sounds': []}
    if action == 5:
        clip['contacts'] = [.6 * 5 / 11, .6 * 6 / 11]
        clip['sounds'] = [{'id': 103, 'frame': 3, 'atMs': .6 * 3 / 11 * 1000},
                          {'id': 103, 'frame': 6, 'atMs': .6 * 6 / 11 * 1000}]
    # Source slots NW,N,NE,E,SE,S,SW,W; the unturned master faces south.
    rig.rotation_euler.z = (5 - direction) * math.tau / 8
    for index in range(count):
        progress = index / count if action in [0, 1, 3, 5] else index / max(1, count - 1)
        pose(action, progress)
        filename = f'{action}-{direction}-{index:02d}.png'
        scene.render.filepath = str(FRAMES / filename)
        bpy.ops.render.render(write_still=True)
        clip['frames'].append(filename)
    clips[f'{action}:{direction}'] = clip
    print('AOI_RENDERED', action, direction, count, flush=True)
rig.rotation_euler.z = 0
pose(0, 0)
pipe_parts = [o for o in scene.objects if o.name.startswith('Pipe_')]
for ob in pipe_parts:
    ob.hide_render = True
scene.render.filepath = str(OUT / 'body-ruler.png')
bpy.ops.render.render(write_still=True)
for ob in pipe_parts:
    ob.hide_render = False
assert master_sha == hashlib.sha256(MASTER.read_bytes()).hexdigest(), 'Master changed during render'
assert clock_bytes == SOURCE.read_bytes(), 'Source clock changed during render'
metadata = {'clips': clips, 'master_sha256': master_sha,
            'clock_sha256': hashlib.sha256(clock_bytes).hexdigest(),
            'canvas': SIZE, 'width': scene.render.resolution_x, 'ortho_scale': camera.data.ortho_scale,
            'camera_matrix': [list(row) for row in camera.matrix_world],
            'origin': [world_to_camera_view(scene, camera, Vector((0, 0, 0))).x * scene.render.resolution_x,
                       (1 - world_to_camera_view(scene, camera, Vector((0, 0, 0))).y) * SIZE],
            'pipe_length': float(scene['pipe_length']), 'pipe_multiplier': float(scene['pipe_length_multiplier'])}
(OUT / ('preview-render.json' if PREVIEW else 'render.json')).write_text(json.dumps(metadata, indent=2) + '\n')
print('AOI_SPRITES_RENDERED', len(clips), flush=True)

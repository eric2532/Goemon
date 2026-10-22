"""Fit a copy of Master Thief's existing costume/weapon onto the ROM base."""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/blender/characters/rom_goemon_base'
SOURCE = ROOT / 'assets/blender/characters/goemon_cosplay/master-thief.blend'
sys.path.insert(0, str(ROOT / 'tools'))
from build_rom_goemon_base import native
from rom_goemon_thief_palette import apply_palette


def build():
    bpy.ops.wm.open_mainfile(filepath=str(DEST / 'goemon.blend'))
    bpy.context.preferences.filepaths.save_version = 0
    rig = bpy.data.objects['ROM_Goemon_Rig']
    with bpy.data.libraries.load(str(SOURCE), link=False) as (source, target):
        target.objects = [name for name in source.objects if name in ['Costume_master_thief', 'Reference_Rig', 'Weapon_Cutlass_Geometry', 'Weapon_Cutlass']]
    imported = {obj.name:obj for obj in target.objects}
    old_rig = imported['Reference_Rig'];costume = imported['Costume_master_thief']
    old_weights = [{costume.vertex_groups[g.group].name:g.weight for g in v.groups} for v in costume.data.vertices]
    # The source costume is authored in Kai's +Y-forward body coordinates;
    # its old180-degree Rogue wrapper is deliberately excluded from the fit.
    local = costume.matrix_local.copy();costume.data = costume.data.copy()
    for v in costume.data.vertices:
        v.co = local @ v.co
        if 'Head' in old_weights[v.index]:
            # The N64 head/hair is fuller than Kai's. Refit the existing band
            # and coin together, keeping their topology and material artwork.
            v.co.x *= 1.38;v.co.y = (v.co.y + .055) * 1.48 - .055;v.co.z += .12
    costume.parent = rig;costume.matrix_parent_inverse = Matrix.Identity(4);costume.matrix_basis = Matrix.Identity(4)
    costume.name = 'MasterThief_Costume';bpy.context.collection.objects.link(costume)
    costume.modifiers.clear();costume.vertex_groups.clear()
    mapping = {'Neck':'Chest','Pelvis':'Pelvis','Chest':'Chest','Head':'Head'}
    groups = {name:costume.vertex_groups.new(name=name) for name in sorted(set(mapping.values()))}
    for index, weights in enumerate(old_weights):
        combined = {}
        for name, weight in weights.items():combined[mapping[name]] = combined.get(mapping[name], 0) + weight
        for name, weight in combined.items():groups[name].add([index], weight, 'REPLACE')
    mod = costume.modifiers.new('ROM Goemon costume rig', 'ARMATURE');mod.object = rig
    costume['source_costume'] = str(SOURCE.relative_to(ROOT));costume['fit'] = 'Source costume geometry fitted in the new base rest space; source file retained.'

    body = json.loads((ROOT / 'assets/characters/recovered_goemon/body/body.json').read_text())
    motion = json.loads((ROOT / 'assets/characters/recovered_goemon/motion.json').read_text())
    clip = motion['clips'][motion['actions']['0']];poses = dict(zip(clip['pointers'], map(native, clip['frames'][0])))
    pointer = '0x9005868';manifest = json.loads((DEST / 'manifest.json').read_text());scale = manifest['source_scale']
    points = [poses[p] @ Vector(v['position']) for p, part in body['parts'].items() for v in part['vertices']]
    axes = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    conversion = Matrix.Translation((0, 0, -min(p.y for p in points) * scale)) @ Matrix.Diagonal((scale, scale, scale, 1)) @ axes
    ready_clip = motion['clips'][motion['actions']['104']]
    ready = dict(zip(ready_clip['pointers'], map(native, ready_clip['frames'][0])))
    # Native display-list names use the opposite side convention from Kai.
    # The ROM pipe is mounted to0x9005868, with its own authored wrist offset
    # and orientation. Align the custom shaft to the original weapon's +Z.
    mount = ready[pointer].inverted() @ ready['0x9002518']
    target = conversion @ poses[pointer] @ mount
    grip_frame = target.to_quaternion().to_matrix().to_4x4()
    grip_frame.translation = target.translation
    weapon = imported['Weapon_Cutlass_Geometry'];grip = imported['Weapon_Cutlass'].matrix_world.translation.copy()
    original_matrix = weapon.matrix_world.copy();weapon.data = weapon.data.copy()
    offsets = [original_matrix @ v.co - grip for v in weapon.data.vertices]
    shaft = max(offsets, key=lambda p:p.length_squared).normalized()
    side = Vector((0, 0, 1)).cross(shaft).normalized()
    up = shaft.cross(side).normalized()
    canonical = Matrix((side, up, shaft))
    # Retain enough narrow stem behind the grip to balance the bowl and keep
    # the standing carry clear of the ground without moving the ROM hand.
    handle_grip = max(offset.length for offset in offsets) - .44
    for v, offset in zip(weapon.data.vertices, offsets):
        local = canonical @ offset
        # Turn it end for end about the stem's holding point. The wrist stays
        # in the same frame, gripping the thin stem just ahead of the mouthpiece;
        # the bowl leads the swing and keeps its original upward orientation.
        v.co = grip_frame @ Vector((-local.x, local.y, handle_grip - local.z))
    weapon.parent = rig;weapon.matrix_parent_inverse = Matrix.Identity(4);weapon.matrix_basis = Matrix.Identity(4)
    weapon.name = 'MasterThief_Weapon';bpy.context.collection.objects.link(weapon);weapon.modifiers.clear();weapon.vertex_groups.clear()
    group = weapon.vertex_groups.new(name='Forearm_L');group.add(list(range(len(weapon.data.vertices))), 1, 'REPLACE')
    mod = weapon.modifiers.new('ROM Goemon hand follow', 'ARMATURE');mod.object = rig;weapon['thief_weapon'] = True
    weapon['rom_grip_frame'] = [grip_frame[row][column] for row in range(4) for column in range(4)]
    weapon['rom_hand_pointer'] = pointer
    weapon['pipe_direction'] = 'Narrow stem held; bowl points outward'
    for name in ['Reference_Rig', 'Weapon_Cutlass']:
        bpy.data.objects.remove(imported[name], do_unlink=True)
    for image in bpy.data.images:
        if image.type == 'IMAGE' and not image.packed_file:image.pack()
    apply_palette()
    bpy.context.scene['pilot'] = 'Master Thief costume/weapon copied onto the ROM Goemon Blender base; preview only.'
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active = rig
    bpy.ops.wm.save_as_mainfile(filepath=str(DEST / 'master_thief.blend'))
    print('ROM_MASTER_THIEF_PILOT_BUILT', DEST / 'master_thief.blend')


if __name__ == '__main__':build()

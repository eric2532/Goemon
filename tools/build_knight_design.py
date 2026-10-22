"""Install the approved editable Knight kit without changing Goemon's rig/geometry.

Blender -b --python tools/build_knight_design.py
Also called by build_goemon_cosplay.py after building Knight's base costume.
"""
from pathlib import Path
import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/characters/goemon_cosplay/knight-design/approved-kit.blend'


def apply_approved_design():
    rig = bpy.data.objects['Reference_Rig']
    skin = bpy.data.objects['Skin']
    protected = {name: [(tuple(v.co), [(g.group, g.weight) for g in v.groups])
                        for v in bpy.data.objects[name].data.vertices]
                 for name in ['Skin', 'Hair_Normal']}
    for name in ['Costume_knight', 'Knight_Long_Dark_Navy_Cape', 'Weapon_Cutlass', 'Weapon_Pistol']:
        ob = bpy.data.objects.get(name)
        if ob:
            for child in list(ob.children_recursive):
                bpy.data.objects.remove(child, do_unlink=True)
            bpy.data.objects.remove(ob, do_unlink=True)
    existing = set(bpy.data.objects)
    with bpy.data.libraries.load(str(SOURCE), link=False) as (src, dst):
        dst.objects = src.objects
    loaded = [ob for ob in dst.objects if ob]
    approved_skin = next(ob for ob in loaded if ob.name.startswith('Skin'))
    assert [tuple(v.co) for v in skin.data.vertices] == [tuple(v.co) for v in approved_skin.data.vertices]
    skin.data.materials.clear()
    for mat in approved_skin.data.materials:
        skin.data.materials.append(mat)
    for live, approved in zip(skin.data.polygons, approved_skin.data.polygons):
        live.material_index = approved.material_index
    def weapon_root(ob):
        while ob:
            if ob.name in ['Weapon_Cutlass', 'Weapon_Pistol']:
                return ob
            ob = ob.parent
        return None
    keep = {ob for ob in loaded if ob.name in ['Costume_knight', 'Knight_Long_Dark_Navy_Cape'] or weapon_root(ob)}
    for ob in keep:
        bpy.context.scene.collection.objects.link(ob)
        ob.animation_data_clear()
        if ob.name in ['Costume_knight', 'Knight_Long_Dark_Navy_Cape']:
            ob.parent = rig
            ob.matrix_parent_inverse = Matrix.Identity(4)
            ob.matrix_basis = Matrix.Identity(4)
            for mod in ob.modifiers:
                if mod.type == 'ARMATURE':
                    mod.object = rig
            if ob.data.shape_keys:
                ob.data.shape_keys.animation_data_clear()
                for key in ob.data.shape_keys.key_blocks:
                    key.value = 0
        elif ob.name in ['Weapon_Cutlass', 'Weapon_Pistol']:
            world = ob.matrix_world.copy()
            side = 'R' if ob.name == 'Weapon_Cutlass' else 'L'
            ob.parent = bpy.data.objects['Driver_Arm_' + side]
            ob.matrix_parent_inverse = Matrix.Identity(4)
            ob.matrix_world = world
            # The approved preview already fixes the final physical dimensions.
            # Actor's common 15% readability multiplier must not enlarge them again.
            ob.scale *= 1 / 1.15
    # Library loading brings in the preview armature as a mesh dependency.
    for ob in list(bpy.data.objects):
        if ob not in existing and ob not in keep:
            bpy.data.objects.remove(ob, do_unlink=True)
    for name in ['Weapon_Cutlass', 'Weapon_Pistol']:
        root = bpy.data.objects[name]
        parts = [ob for ob in root.children_recursive if ob.type == 'MESH']
        bpy.ops.object.select_all(action='DESELECT')
        for ob in parts:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        bpy.context.object.name = name + '_Geometry'
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    rig.animation_data_clear()
    for name, data in protected.items():
        assert [(tuple(v.co), [(g.group, g.weight) for g in v.groups])
                for v in bpy.data.objects[name].data.vertices] == data
    bpy.context.scene['knight_design'] = 'Approved claymore, centered lion wall shield, silver boots, long navy cloth'
    bpy.context.view_layer.update()


if __name__ == '__main__':
    live = ROOT / 'assets/blender/characters/goemon_cosplay/knight.blend'
    bpy.ops.wm.open_mainfile(filepath=str(live))
    apply_approved_design()
    bpy.ops.wm.save_as_mainfile(filepath=str(live))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(ROOT / 'assets/models/characters/goemon_cosplay/knight.glb'),
                             export_format='GLB', use_selection=True, export_animations=False,
                             export_yup=True, export_skins=True, export_materials='EXPORT', export_extras=True)
    print('KNIGHT_APPROVED_DESIGN_EXPORTED')

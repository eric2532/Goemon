"""Goemon cosplaying the complete playable roster.

Blender -b --python tools/build_goemon_cosplay.py -- [hero ...]
The original Skin/Hair_Normal vertices, UVs and weights remain untouched.
Costumes use the same skeleton; native Rogue weapons retain their geometry.
"""
import bpy
import bmesh
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/characters/kai.blend'
OUT = ROOT / 'assets/models/characters/goemon_cosplay'
EDIT = ROOT / 'assets/blender/characters/goemon_cosplay'
DOC = ROOT / 'docs/goemon-cosplay'
for directory in [OUT, EDIT, DOC]:
    directory.mkdir(parents=True, exist_ok=True)

# Primary cloth / secondary cloth / trim / hair. The face always uses Goemon's atlas.
PALETTES = {
    'edo': ('b52631', '273444', 'e8b351', '171c26'),
    'pirate': ('6c202b', '242c40', 'd8b261', '362132'),
    'samurai': ('9d2430', '202e4e', 'e9c67d', '192433'),
    'ninja': ('32304e', '171e32', 'af8cde', '232139'),
    'mage': ('274c8a', 'e6d9b5', 'daa957', 'd0d9f4'),
    'knight': ('8295aa', '26374e', 'd9b558', 'bbb9c4'),
    'dragoon': ('26758c', '1d354d', 'bce2e4', '86b9d4'),
    'magic-swordsman': ('624783', '25253f', 'cfc6ea', 'c2c4df'),
    'ranger': ('326947', '523e29', 'cfb677', 'c79542'),
    'explorer': ('b57936', '326d70', 'e9d1a1', '8b452c'),
    'master-thief': ('722f3e', '253344', 'd5ad58', 'e2dde0'),
}


def material(name, color):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    rgb = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = .92
    bsdf.inputs['Specular IOR Level'].default_value = .12
    return mat


def mesh(name, points, faces, mat, bone='Chest'):
    data = bpy.data.meshes.new(name)
    data.from_pydata(points, [], faces)
    data.update()
    ob = bpy.data.objects.new('Costume_' + name, data)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = rig
    data.materials.append(mat)
    uv = data.uv_layers.new(name='UVMap')
    for loop in uv.data:
        loop.uv = (.5, .5)
    group = ob.vertex_groups.new(name=bone)
    group.add(list(range(len(points))), 1.0, 'REPLACE')
    mod = ob.modifiers.new('Goemon skeleton', 'ARMATURE')
    mod.object = rig
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data)
    bm.free()
    extras.append(ob)
    return ob


def loft(name, rings, mat, bone='Chest', count=12):
    # Rings: height, x center, y center, x radius, y radius.
    points = [(cx + rx * math.sin(i * math.tau / count),
               cy + ry * math.cos(i * math.tau / count), z)
              for z, cx, cy, rx, ry in rings for i in range(count)]
    faces = [(j * count + i, j * count + (i + 1) % count,
              (j + 1) * count + (i + 1) % count, (j + 1) * count + i)
             for j in range(len(rings) - 1) for i in range(count)]
    faces += [tuple(reversed(range(count))), tuple(range(len(points) - count, len(points)))]
    return mesh(name, points, faces, mat, bone)


def plate(name, points, mat, bone='Chest', thickness=.025):
    points = [Vector(p) for p in points]
    normal = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
    verts = points + [p - normal * thickness for p in points]
    n = len(points)
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, verts, faces, mat, bone)


def tube(name, a, b, radius, mat, bone='Chest', count=8):
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    u = axis.cross(Vector((0, 0, 1)))
    if u.length < .1:
        u = axis.cross(Vector((0, 1, 0)))
    u.normalize()
    v = axis.cross(u).normalized()
    points = [p + radius * (math.cos(i * math.tau / count) * u + math.sin(i * math.tau / count) * v)
              for p in [a, b] for i in range(count)]
    faces = [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    faces += [tuple(reversed(range(count))), tuple(range(count, 2 * count))]
    return mesh(name, points, faces, mat, bone)


def gem(name, center, size, mat, bone='Chest'):
    x, y, z = center
    w, d, h = size
    return mesh(name, [(x, y, z + h), (x - w, y, z), (x, y + d, z),
                       (x + w, y, z), (x, y - d, z), (x, y, z - h)],
                [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1),
                 (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)], mat, bone)


def cape(mat, length=.90, side=0):
    # Short angular cloth with an intentionally full rear silhouette.
    w = .50 if not side else .27
    x = side * .30
    plate('shoulder_cape', [(x - w * .62, -.32, 1.50), (x + w * .62, -.32, 1.50),
                           (x + w, -.57, 1.50 - length), (x, -.63, 1.43 - length),
                           (x - w, -.57, 1.50 - length)], mat)


def sash(mat):
    loft('waist_sash', [(1.01, 0, .05, .40, .39), (1.15, 0, .05, .43, .41)], mat, 'Pelvis')
    gem('sash_knot', (.24, .45, 1.07), (.12, .055, .11), mat, 'Pelvis')


def collar(mat):
    loft('collar', [(1.44, 0, .00, .31, .27), (1.53, 0, .00, .28, .27)], mat, 'Neck')


def armor(primary, trim):
    for i in range(3):
        z = 1.17 + i * .105
        loft('cuirass_lame_' + str(i), [(z, 0, .055, .425, .393), (z + .08, 0, .055, .45, .402)], primary)
        tube('cuirass_trim_' + str(i), (-.30, .455, z + .08), (.30, .455, z + .08), .018, trim)
    for sign, side in [(-1, 'L'), (1, 'R')]:
        # Shoulder armor follows the unmodified T-pose, then the arm animation.
        plate('pauldron_' + side, [(sign * .45, .24, 1.48), (sign * .78, .21, 1.47),
                                   (sign * .88, .18, 1.19), (sign * .51, .23, 1.16)], primary, 'Arm_' + side)
        tube('pauldron_edge_' + side, (sign * .51, .255, 1.17), (sign * .87, .20, 1.20), .025, trim, 'Arm_' + side)


def chest_strap(mat):
    plate('diagonal_baldric', [(-.36, .34, 1.48), (-.24, .37, 1.48),
                              (.33, .44, 1.07), (.18, .46, 1.06)], mat)
    gem('baldric_buckle', (.09, .465, 1.23), (.09, .025, .07), gold)


def costume(hero, colors):
    global gold
    primary, secondary, gold, hair = [material(hero + '_' + role, color)
                                      for role, color in zip(['cloth', 'secondary', 'trim', 'hair'], colors)]
    body.data.materials.append(primary)
    body.data.materials.append(secondary)
    body.data.materials.append(gold)
    # Face, undercut and bare palms keep the exact original atlas and UVs.
    for poly in body.data.polygons:
        p = poly.center
        if all(i < 33 for i in poly.vertices) or abs(p.x) > 1.09:
            continue
        poly.material_index = 2 if p.z < 1.03 or abs(p.x) > .78 else 1
    hair_ob.data.materials.clear()
    hair_ob.data.materials.append(hair)
    collar(secondary)
    sash(secondary)
    if hero in ['samurai', 'knight', 'dragoon', 'magic-swordsman']:
        armor(primary, gold)
    if hero in ['pirate', 'ranger', 'explorer', 'master-thief']:
        chest_strap(secondary)
    if hero == 'edo':
        cape(primary, .65, -1)
        for s in [-1, 1]:
            plate('jacket_gold_lapel_' + str(s), [(s * .12, .37, 1.47), (s * .17, .41, 1.43),
                                                (s * .08, .47, 1.17), (s * .045, .47, 1.18)], gold)
        plate('ember_emblem', [(-.08, .46, 1.26), (-.14, .44, 1.34), (-.05, .46, 1.32),
                               (0, .46, 1.42), (.12, .44, 1.32), (.06, .46, 1.25)], gold)
        for side, sign in [('L', -1), ('R', 1)]:
            for i in range(3):
                tube('forearm_wrap', (sign * (.90 + i * .06), 0, 1.305), (sign * (.945 + i * .06), 0, 1.305), .16, gold, 'Forearm_' + side)
    elif hero == 'pirate':
        cape(primary, .95)
        # A little tricorne perched over the original spiky crown.
        loft('tricorne_brim', [(3.02, 0, -.14, .61, .43), (3.10, 0, -.14, .68, .47)], secondary, 'Head', 3)
        loft('tricorne_crown', [(3.08, 0, -.14, .42, .33), (3.40, 0, -.14, .26, .22)], secondary, 'Head', 6)
        gem('hat_insignia', (0, .20, 3.22), (.085, .03, .09), gold, 'Head')
        tube('gold_earring', (-.55, .04, 1.81), (-.55, .04, 1.65), .04, gold, 'Head')
        for x in [-.19, .19]:
            for z in [1.22, 1.35]:
                gem('coat_button', (x, .453, z), (.035, .018, .035), gold)
    elif hero == 'samurai':
        scarf = material('Samurai_vermilion_scarf', 'd13d39')
        collar(scarf)
        # Open crescent crest leaves the face and signature hair visible.
        plate('kabuto_crescent', [(-.43, .61, 2.39), (-.40, .62, 2.68), (-.27, .62, 2.53),
                                 (0, .65, 2.39), (.27, .62, 2.53), (.40, .62, 2.68),
                                 (.43, .61, 2.39), (0, .65, 2.23)], gold, 'Head')
        for s in [-1, 1]:
            plate('hip_lamella', [(s * .10, .46, 1.04), (s * .39, .40, 1.04),
                                  (s * .46, .38, .72), (s * .13, .47, .74)], primary, 'Pelvis')
    elif hero == 'ninja':
        loft('shinobi_headband', [(2.09, 0, -.06, .55, .48), (2.19, 0, -.06, .54, .48)], secondary, 'Head')
        plate('forehead_plate', [(-.21, .445, 2.10), (.21, .445, 2.10), (.21, .445, 2.20), (-.21, .445, 2.20)], gold, 'Head')
        cape(secondary, .60, 1)
        for s in [-1, 1]:
            tube('back_sword_sheath', (s * .34, -.35, 1.45), (-s * .35, -.41, .73), .055, secondary)
        gem('violet_knot', (0, .445, 1.06), (.09, .035, .08), gold, 'Pelvis')
    elif hero == 'mage':
        cape(primary, 1.14)
        loft('wizard_hat_brim', [(3.02, 0, -.14, .59, .48), (3.08, 0, -.14, .61, .50)], primary, 'Head')
        loft('wizard_hat', [(3.06, 0, -.14, .37, .32), (3.40, -.04, -.12, .26, .23),
                            (3.73, -.16, -.10, .11, .10), (3.85, -.35, -.08, .015, .015)], primary, 'Head')
        loft('hat_band', [(3.08, 0, -.14, .375, .327), (3.20, -.015, -.13, .337, .30)], gold, 'Head')
        for x in [-.28, .28]:
            plate('robe_stole', [(x - .06, .37, 1.48), (x + .06, .37, 1.48),
                                 (x + .08, .47, .70), (x - .08, .47, .70)], secondary)
        gem('arcane_brooch', (0, .46, 1.35), (.10, .05, .13), gold)
    elif hero == 'knight':
        cape(secondary, 1.03)
        # Open ceremonial visor: Goemon remains recognizable under the armor.
        loft('open_helmet_rim', [(2.15, 0, -.04, .57, .51), (2.25, 0, -.04, .57, .51)], primary, 'Head')
        for s in [-1, 1]:
            plate('helmet_cheek_guard', [(s * .52, .15, 2.18), (s * .60, .09, 2.10),
                                        (s * .57, .14, 1.65), (s * .49, .24, 1.69)], primary, 'Head')
        gem('royal_crest', (0, .53, 2.22), (.11, .05, .15), gold, 'Head')
        plate('chest_cross', [(-.04, .48, 1.42), (.04, .48, 1.42), (.04, .48, 1.34),
                              (.14, .48, 1.34), (.14, .48, 1.28), (.04, .48, 1.28),
                              (.04, .48, 1.18), (-.04, .48, 1.18), (-.04, .48, 1.28),
                              (-.14, .48, 1.28), (-.14, .48, 1.34), (-.04, .48, 1.34)], gold)
    elif hero == 'dragoon':
        cape(secondary, .83)
        for s in [-1, 1]:
            loft('dragon_swept_horn', [(2.35, s * .50, -.15, .14, .12),
                                      (2.77, s * .76, -.26, .10, .08),
                                      (3.12, s * .85, -.46, .005, .005)], gold, 'Head', 6)
            for i in range(3):
                plate('dragon_temple_fin', [(s * .50, -.03, 2.16 - i * .11),
                                            (s * .93, -.18, 2.34 - i * .13),
                                            (s * .62, -.24, 1.98 - i * .10)], primary, 'Head')
        gem('dragon_crown', (0, .53, 2.27), (.13, .065, .20), gold, 'Head')
    elif hero == 'magic-swordsman':
        cape(secondary, 1.1, -1)
        for s in [-1, 1]:
            plate('demon_crown_horn', [(s * .40, .24, 2.21), (s * .65, .15, 2.68),
                                      (s * .87, .04, 2.93), (s * .68, -.06, 2.36)], primary, 'Head')
        gem('amethyst_focus', (0, .53, 2.29), (.12, .08, .21), gold, 'Head')
        # Mask worn at the temple preserves the approved Goemon face.
        plate('temple_demon_mask', [(-.55, .30, 2.09), (-.82, .20, 2.04),
                                    (-.84, .20, 1.78), (-.68, .29, 1.66),
                                    (-.53, .34, 1.84)], primary, 'Head')
        gem('demon_mask_eye', (-.70, .323, 1.95), (.09, .025, .035), gold, 'Head')
    elif hero == 'ranger':
        cape(primary, .85)
        loft('forest_cap', [(3.02, 0, -.14, .47, .37), (3.26, -.09, -.12, .34, .27),
                            (3.42, -.34, -.10, .06, .05)], primary, 'Head')
        plate('forest_cap_brim', [(-.51, .22, 3.02), (.48, .22, 3.02), (.43, .54, 3.00), (-.47, .49, 3.00)], secondary, 'Head')
        plate('ivory_feather', [(-.29, -.04, 3.21), (-.35, -.04, 3.61),
                                (-.22, -.04, 3.73), (-.15, -.04, 3.51)], gold, 'Head')
        loft('quiver', [(.85, .30, -.48, .12, .12), (1.63, .30, -.48, .14, .14)], secondary)
        for i in range(3):
            x = .23 + i * .07
            tube('arrow_shaft', (x, -.48, 1.35), (x, -.48, 1.91), .012, gold)
            plate('arrow_fletching', [(x - .04, -.48, 1.80), (x, -.48, 1.94),
                                     (x + .04, -.48, 1.80), (x, -.48, 1.75)], gold)
    elif hero == 'explorer':
        collar(secondary)
        # Goggles rest on the hair, leaving the original eyes visible.
        for s in [-1, 1]:
            gem('goggle_frame', (s * .25, .56, 2.41), (.19, .04, .14), gold, 'Head')
            gem('goggle_lens', (s * .25, .608, 2.41), (.14, .025, .10), secondary, 'Head')
        tube('goggle_bridge', (-.08, .57, 2.41), (.08, .57, 2.41), .025, gold, 'Head')
        loft('travel_pack', [(.95, 0, -.45, .28, .19), (1.52, 0, -.45, .30, .20)], secondary)
        for s in [-1, 1]:
            loft('belt_pouch', [(.87, s * .43, .21, .10, .09), (1.07, s * .43, .21, .105, .095)], secondary, 'Pelvis')
    elif hero == 'master-thief':
        cape(primary, .88)
        loft('thief_head_wrap', [(2.10, 0, -.055, .56, .48), (2.23, 0, -.055, .55, .48)], secondary, 'Head')
        gem('head_wrap_coin', (0, .48, 2.18), (.11, .045, .10), gold, 'Head')
        for i in range(5):
            gem('coin_belt_' + str(i), (-.28 + i * .14, .46, 1.08), (.047, .02, .047), gold, 'Pelvis')
        loft('loot_pouch', [(.75, -.42, -.28, .16, .13), (1.06, -.42, -.28, .14, .12)], secondary, 'Pelvis')


def empty(name, world, parent=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.matrix_world = Matrix.Translation(Vector(world))
    bpy.context.view_layer.update()
    return ob


def attach_native_weapons(hero):
    # Append only weapon subtrees from the previous editable source.
    source = ROOT / 'assets/blender/rogue' / (hero + '.blend')
    with bpy.data.libraries.load(str(source), link=False) as (src, dst):
        dst.objects = src.objects
    appended = [o for o in dst.objects if o]
    def weapon_root(ob):
        while ob:
            if ob.name.split('.')[0] in ['Weapon_Cutlass', 'Weapon_Pistol', 'Flask']:
                return ob
            ob = ob.parent
        return None
    keep = [o for o in appended if weapon_root(o)]
    for ob in appended:
        bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    saved = {o: o.matrix_world.copy() for o in keep}
    roots = [o for o in keep if weapon_root(o) == o]
    for ob in roots:
        if ob.name.split('.')[0] == 'Flask':
            # The drinking animation positions the flask relative to Body,
            # independently of either weapon hand. Keep that contract intact.
            local = ob.parent.matrix_world.inverted() @ saved[ob]
            ob.parent = drivers['Body']
            ob.matrix_world = drivers['Body'].matrix_world @ local
            bpy.context.view_layer.update()
            continue
        side = 'L' if ob.name.startswith('Weapon_Pistol') else 'R'
        # Goemon's palm in the 75-degree lowered-arm pose, with no limb scaling.
        sign = 1 if side == 'L' else -1
        target = Vector((sign * .638, -.015, .440))
        delta = target - saved[ob].translation
        ob.parent = drivers['Arm_' + side]
        ob.matrix_world = saved[ob].copy()
        ob.matrix_world.translation += delta
        bpy.context.view_layer.update()
    for ob in appended:
        if ob not in keep:
            bpy.data.objects.remove(ob, do_unlink=True)
    # Existing class UV materials are retained, then batching keeps draw calls bounded.
    batches = [(root, [o for o in keep if o.type == 'MESH' and weapon_root(o) == root]) for root in roots]
    for root, parts in batches:
        if not parts:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in parts:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        bpy.context.object.name = root.name + '_Geometry'


def build(hero):
    global rig, body, hair_ob, extras, drivers
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig = bpy.data.objects['Reference_Rig']
    body = bpy.data.objects['Skin']
    hair_ob = bpy.data.objects['Hair_Normal']
    initial = {o.name: ([tuple(v.co) for v in o.data.vertices],
                        [tuple(u.uv) for u in o.data.uv_layers.active.data]) for o in [body, hair_ob]}
    for ob in list(bpy.data.objects):
        if ob not in [rig, body, hair_ob]:
            bpy.data.objects.remove(ob, do_unlink=True)
    rig.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    for im in bpy.data.images:
        if im.name == 'goe128_2.png':
            im.filepath = str(ROOT / 'assets/textures/characters/goemon_original.png')
            im.reload()
            im.pack()
    extras = []
    if hero != 'goemon':
        costume(hero, PALETTES[hero])
    # Consolidate costume geometry without changing the shared body or face.
    if extras:
        bpy.ops.object.select_all(action='DESELECT')
        for ob in extras:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = extras[0]
        bpy.ops.object.join()
        bpy.context.object.name = 'Costume_' + hero.replace('-', '_')
    if hero not in ['goemon', 'edo']:
        rig.rotation_euler.z = math.pi
        root = empty('Cosplay', (0, 0, 0))
        drivers = {'Body': empty('Driver_Body', (0, 0, .966), root)}
        for name, loc in [('Head', (0, 0, 1.54)), ('Arm_L', (.406665, 0, 1.304718)),
                          ('Arm_R', (-.406665, 0, 1.304718)), ('Leg_L', (.254166, 0, .965830)),
                          ('Leg_R', (-.254166, 0, .965830))]:
            drivers[name] = empty('Driver_' + name, loc, root if name.startswith('Leg') else drivers['Body'])
        attach_native_weapons(hero)
        if hero == 'samurai':
            tail = empty('ScarfTail', (.35, .30, 1.49), drivers['Head'])
            # Runtime scarf wind expects a strip laid out along local Blender +Y.
            verts = [(s * (.105 - i * .002), i * .065, 0) for i in range(21) for s in [-1, 1]]
            faces = [(2*i, 2*i+1, 2*i+3, 2*i+2) for i in range(20)]
            me = bpy.data.meshes.new('ScarfTail_Geometry'); me.from_pydata(verts, [], faces)
            ob = bpy.data.objects.new('ScarfTail_Geometry', me); bpy.context.scene.collection.objects.link(ob)
            ob.parent = tail; me.materials.append(material('Scarf_tail_red', 'd13d39'))
            me.materials[0].use_backface_culling = False
    if hero == 'knight':
        import importlib.util
        spec = importlib.util.spec_from_file_location('knight_design', ROOT / 'tools/build_knight_design.py')
        kit = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(kit)
        kit.apply_approved_design()
    if hero == 'ninja':
        import importlib.util
        spec = importlib.util.spec_from_file_location('ninja_weapon', ROOT / 'tools/build_ninja_weapon.py')
        kit = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(kit)
        kit.apply_design()
    if hero == 'pirate':
        import importlib.util
        spec = importlib.util.spec_from_file_location('pirate_weapon', ROOT / 'tools/build_pirate_design.py')
        kit = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(kit)
        kit.apply_design()
    # This is an asset invariant, evaluated before saving or exporting anything.
    for ob in [body, hair_ob]:
        assert [tuple(v.co) for v in ob.data.vertices] == initial[ob.name][0]
        assert [tuple(u.uv) for u in ob.data.uv_layers.active.data] == initial[ob.name][1]
    bpy.context.scene['design'] = 'Goemon cosplaying: exact body, painted face and spiky hair; class costume and kit'
    bpy.ops.wm.save_as_mainfile(filepath=str(EDIT / (hero + '.blend')))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT / (hero + '.glb')), export_format='GLB',
                             use_selection=True, export_animations=False, export_yup=True,
                             export_skins=True, export_materials='EXPORT', export_extras=True)
    print('COSPLAY_BUILT', hero)


before = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
requested = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else ['goemon', *PALETTES]
for hero in requested:
    build(hero)
if 'samurai' in requested:
    # Retain the approved enlarged maroon katana when rebuilding the roster.
    import importlib.util
    spec = importlib.util.spec_from_file_location('samurai_approved_export', ROOT / 'tools/export_samurai_animations.py')
    samurai_export = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(samurai_export)
    samurai_export.export()
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == before, 'Master changed'
(DOC / 'source-preservation.json').write_text(json.dumps({'master_sha256': before,
    'source': str(SOURCE.relative_to(ROOT)), 'exact_geometry_and_uvs': True,
    'built': requested}, indent=2) + '\n')

"""Reference-inspired silver curved blade with a purple sculpted grip.

Blender -b --python tools/build_ninja_weapon.py
Keeps Ninja's grip origin, blade-tip contract, rig, off-hand and body intact.
Also used by build_goemon_cosplay.py, so a roster rebuild retains the design.
"""
import bpy
import bmesh
import hashlib
import json
import math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/ninja-purple-weapon'
LIVE = ROOT / 'assets/blender/characters/goemon_cosplay/ninja.blend'
GLB = ROOT / 'assets/models/characters/goemon_cosplay/ninja.glb'
TIP = Vector((-.375, -.015, .806))  # Actor.WEAPON_AXES.ninja in Blender coordinates.
CANONICAL_TIP = Vector((-.17, 0, .89))
ORIENTATION = CANONICAL_TIP.rotation_difference(TIP).to_matrix()
SIZE = TIP.length / CANONICAL_TIP.length


def material(name, color, metallic=0, roughness=.48):
    name = 'Ninja_Violet_' + name
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    srgb = [int(color[i:i+2], 16)/255 for i in (0, 2, 4)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in srgb]
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    return mat


def mesh(name, points, faces, materials, indices=None):
    data = bpy.data.meshes.new(name)
    # Every part shares the existing hand-root origin and exact blade-tip axis.
    data.from_pydata([ORIENTATION @ (Vector(p)*SIZE) for p in points], [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    for mat in materials:
        data.materials.append(mat)
    if indices:
        for face, index in zip(data.polygons, indices):
            face.material_index = index
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data); bm.free()
    ob['part'] = name
    return ob


def plate(name, outline, y, depth, mat, bevel=0):
    n = len(outline)
    points = [(x, y-depth/2, z) for x, z in outline] + [(x, y+depth/2, z) for x, z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    ob = mesh(name, points, faces, [mat])
    if bevel:
        mod = ob.modifiers.new('Machined edge bevel', 'BEVEL')
        mod.width = bevel*SIZE; mod.segments = 2
        mod.affect = 'EDGES'
    return ob


def pin(name, x, y, z, mat, radius=.006):
    points = [(x+radius*math.cos(i*math.tau/12), y+s*.0013, z+radius*math.sin(i*math.tau/12)) for s in [-1, 1] for i in range(12)]
    faces = [tuple(reversed(range(12))), tuple(range(12, 24))]
    faces += [(i, (i+1)%12, (i+1)%12+12, i+12) for i in range(12)]
    return mesh(name, points, faces, [mat])


def create_parts():
    steel = material('Satin_silver', 'a8b4c0', .62, .37)
    edge = material('Honed_edge', 'e4ebee', .72, .27)
    spine = material('Spine_steel', '677788', .52, .43)
    purple = material('Purple_handle', '633a9b', .17, .45)
    violet = material('Violet_panel', '8254be', .22, .4)
    dark = material('Graphite_inset', '231c30', .1, .56)
    accent = material('Lavender_seam', 'bd99f1', .3, .33)
    parts = []
    # Cross sections contain a broad satin face and a real tapered cutting bevel.
    profile = []
    for i in range(32):
        t = i/32
        cutting = -.052-.118*t**2.4
        width = .104*(1-.10*t)
        if t>.72:
            width *= 1-((t-.72)/.28)**1.5
        profile.append((.155+.735*t, cutting, cutting+width))
    points = []
    for z, cutting, back in profile:
        width = back-cutting
        bevel = min(.029, width*.40)
        thickness = .0105*(1-.48*(z/.89)**3)
        points += [(back, -thickness*.25, z), (back-min(.010, width*.14), -thickness, z),
                   (cutting+bevel, -thickness*.82, z), (cutting, 0, z),
                   (cutting+bevel, thickness*.82, z), (back-min(.010, width*.14), thickness, z),
                   (back, thickness*.25, z)]
    faces = [tuple(reversed(range(7)))]; indices = [2]
    strip_materials = [2, 0, 1, 1, 0, 2, 2]
    for ring in range(len(profile)-1):
        for j in range(7):
            faces.append((ring*7+j, ring*7+(j+1)%7, (ring+1)*7+(j+1)%7, (ring+1)*7+j))
            indices.append(strip_materials[j])
    tip_index = len(points); points.append(tuple(CANONICAL_TIP))
    last = (len(profile)-1)*7
    for j in range(7):
        faces.append((last+j, last+(j+1)%7, tip_index)); indices.append(strip_materials[j])
    parts.append(mesh('Blade_Curved_Silver', points, faces, [steel, edge, spine], indices))
    parts.append(plate('Blade_Collar', [(-.054,.142),(.054,.142),(.050,.197),(-.056,.197)], 0, .029, steel, .002))
    # Low compact oval guard: no oversized katana tsuba.
    parts.append(plate('Guard_Silver', [(-.075,.103),(-.087,.117),(-.080,.146),(-.052,.156),(.071,.150),(.080,.133),(.070,.109)], 0, .071, edge, .004))
    points = []
    rings = [(-.284,.018,.038,.025),(-.268,.014,.049,.033),(-.219,.009,.048,.036),
             (-.13,.004,.039,.032),(-.045,-.003,.040,.033),(.035,-.003,.048,.037),(.103,0,.057,.037),(.122,0,.054,.033)]
    octagon = [(-.72,-1),(.72,-1),(1,-.65),(1,.65),(.72,1),(-.72,1),(-1,.65),(-1,-.65)]
    for z, cx, width, depth in rings:
        points += [(cx+x*width, y*depth, z) for x, y in octagon]
    faces = [tuple(reversed(range(8))), tuple(range(len(points)-8, len(points)))]
    faces += [(r*8+j, r*8+(j+1)%8, (r+1)*8+(j+1)%8, (r+1)*8+j) for r in range(len(rings)-1) for j in range(8)]
    parts.append(mesh('Handle_Purple_Sculpted', points, faces, [purple]))
    for sign, side in [(-1,'Front'), (1,'Back')]:
        inset = [(-.034,.086),(.030,.073),(.025,.005),(.011,-.035),(.020,-.102),(.043,-.219),(.031,-.251),(-.016,-.238),(-.028,-.153),(-.029,-.058)]
        parts.append(plate('Handle_Graphite_Inset_'+side, inset, sign*.041, .003, dark, .0018))
        facet = [(-.039,.096),(-.022,.080),(-.022,-.042),(-.012,-.12),(.022,-.258),(.002,-.245),(-.030,-.137),(-.040,-.020)]
        parts.append(plate('Handle_Violet_Facet_'+side, facet, sign*.044, .003, violet, .001))
        seam = [(-.026,.045),(.014,.033),(.016,.026),(-.025,.036)]
        parts.append(plate('Handle_Lavender_Seam_'+side, seam, sign*.046, .003, accent, .001))
        for index, (x,z) in enumerate([(.014,-.066),(.024,-.223)]):
            parts.append(pin('Flush_Fastener_%s_%d'%(side,index),x,sign*.044,z,spine))
            parts.append(pin('Fastener_Core_%s_%d'%(side,index),x,sign*.046,z,dark,.0027))
    parts.append(plate('Pommel_Graphite', [(-.022,-.268),(.052,-.267),(.049,-.280),(.018,-.294),(-.018,-.285)], 0, .059, dark, .003))
    parts.append(plate('Pommel_Violet_Accent', [(-.017,-.286),(.018,-.296),(.046,-.284),(.045,-.279),(.017,-.288),(-.017,-.280)], 0, .063, accent, .001))
    return parts


def protected_state():
    result = {}
    for ob in bpy.data.objects:
        if ob.name.startswith('Weapon_Cutlass'):
            continue
        state = {'parent':ob.parent.name if ob.parent else None,'matrix':[list(row) for row in ob.matrix_local]}
        if ob.type == 'MESH':
            state['vertices'] = [list(v.co) for v in ob.data.vertices]
            state['polygons'] = [list(p.vertices) for p in ob.data.polygons]
            state['uv'] = [[list(v.uv) for v in layer.data] for layer in ob.data.uv_layers]
            state['weights'] = [[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices]
            state['materials'] = [m.name for m in ob.data.materials]
        if ob.type == 'ARMATURE':
            state['bones'] = [(b.name,list(b.head_local),list(b.tail_local)) for b in ob.data.bones]
        result[ob.name] = hashlib.sha256(json.dumps(state,sort_keys=True).encode()).hexdigest()
    return result


def apply_design():
    before = protected_state()
    root = bpy.data.objects['Weapon_Cutlass']
    root_state = (root.parent, root.matrix_local.copy())
    for ob in list(root.children_recursive):
        bpy.data.objects.remove(ob, do_unlink=True)
    parts = create_parts()
    for part in parts:
        part.parent = root
        part.matrix_parent_inverse = Matrix.Identity(4)
        part.matrix_basis = Matrix.Identity(4)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    # Apply small hardware bevels, then batch only the weapon for the game asset.
    for ob in parts:
        bpy.context.view_layer.objects.active = ob
        for mod in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    bpy.context.object.name = 'Weapon_Cutlass_Geometry'
    assert protected_state() == before, 'Non-weapon character data changed'
    assert root.parent == root_state[0] and root.matrix_local == root_state[1], 'Grip moved'
    assert any((v.co-TIP).length < .00001 for v in bpy.context.object.data.vertices), 'Blade tip no longer matches the combat axis'
    approved = ROOT / 'assets/animations/ninja_approved.json'
    if approved.exists():
        bpy.context.object.matrix_basis = Matrix(json.loads(approved.read_text())['weapon_mesh_transform_blender'])
    root['design'] = 'Curved satin silver blade; purple sculpted handle, graphite insets and lavender seams'
    bpy.context.view_layer.update()


def studio():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = create_parts()
    root = bpy.data.objects.new('Ninja_Purple_Blade',None); bpy.context.scene.collection.objects.link(root)
    for ob in parts:
        ob.parent = root
    root.rotation_mode = 'QUATERNION'
    root.rotation_quaternion = (Matrix.Rotation(math.radians(-43),3,'Y') @ ORIENTATION.inverted()).to_quaternion()
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1400; scene.render.resolution_y = 1400; scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.world = bpy.data.worlds.new('Cool neutral studio'); scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.07,.085,.105,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .7
    scene.view_settings.view_transform = 'AgX'
    for name,location,power,size in [('Softbox',(-1,-2,2.8),170,2.5),('Fill',(1.6,-1,1),100,2),('Edge',(0,1,1.7),150,1.4)]:
        bpy.ops.object.light_add(type='AREA',location=location)
        light=bpy.context.object; light.name=name; light.data.energy=power; light.data.shape='DISK'; light.data.size=size
        light.rotation_euler=(Vector((-.15,0,.25))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(-.2,-3,.35))
    camera=bpy.context.object; camera.name='Weapon_Review_Camera';camera.data.type='ORTHO';camera.data.ortho_scale=1.36
    camera.rotation_euler=(Vector((-.21,0,.245))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts:part.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active;space.shading.type='MATERIAL';space.overlay.show_overlays=False
                space.region_3d.view_distance=1.5;space.region_3d.view_location=Vector((-.21,0,.245))
                space.region_3d.view_rotation=camera.rotation_euler.to_quaternion();space.clip_start=.001
    scene['design_brief']='User reference curved silver blade with purple handle. Separate editable blade, handle, guard, insets and fasteners.'
    bpy.ops.wm.save_as_mainfile(filepath=str(DOC/'ninja-purple-weapon.blend'))
    scene.render.filepath=str(DOC/'weapon-front.png');bpy.ops.render.render(write_still=True)
    camera.location=(.9,-3,.65);camera.rotation_euler=(Vector((-.21,0,.245))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(DOC/'weapon-three-quarter.png');bpy.ops.render.render(write_still=True)
    camera.location=(-.2,3,.35);camera.rotation_euler=(Vector((-.21,0,.245))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(DOC/'weapon-back.png');bpy.ops.render.render(write_still=True)
    print('NINJA_WEAPON_STUDIO_RENDERED', DOC)


if __name__ == '__main__':
    DOC.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(LIVE))
    apply_design()
    bpy.context.scene['ninja_weapon_design']='Purple reference blade, 2026-10-17'
    bpy.ops.wm.save_as_mainfile(filepath=str(LIVE))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(GLB),export_format='GLB',use_selection=True,
                             export_animations=False,export_yup=True,export_skins=True,
                             export_materials='EXPORT',export_extras=True)
    print('NINJA_PURPLE_WEAPON_EXPORTED')
    studio()

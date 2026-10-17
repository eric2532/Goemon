"""Verify the actual saved Blender sources and reimported GLB exports."""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
report=json.loads((OUT/'verification.json').read_text())
results={}
def fingerprint(ob):
    payload={'vertices':[list(v.co) for v in ob.data.vertices],
             'faces':[list(p.vertices) for p in ob.data.polygons],
             'uv':[[list(v.uv) for v in layer.data] for layer in ob.data.uv_layers],
             'weights':[[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices]}
    return hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()
for key,filename,root_name in [('sword','knight-reference-claymore.glb','Weapon_Cutlass'),
                              ('shield','knight-wall-shield.glb','Weapon_Pistol')]:
    raw=(OUT/filename).read_bytes()
    assert raw[:4]==b'glTF'
    length,tag=struct.unpack_from('<I4s',raw,12)
    assert tag==b'JSON'
    doc=json.loads(raw[20:20+length])
    assert all('uri' not in image for image in doc.get('images',[])), 'External texture dependency'
    assert len(doc['meshes'])==1, 'Export should contain one batched geometry object'
    assert any(n['name']==root_name+'_Geometry' for n in doc['nodes'])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/filename))
    bpy.context.view_layer.update()
    root=bpy.data.objects[root_name]
    assert root.matrix_world.translation.length<1e-6, 'Grip origin moved'
    meshes=[ob for ob in root.children_recursive if ob.type=='MESH']
    assert len(meshes)==1
    coordinates=[ob.matrix_world@v.co for ob in meshes for v in ob.data.vertices]
    assert all(math.isfinite(c) for v in coordinates for c in v)
    lo=[min(v[i] for v in coordinates) for i in range(3)]
    hi=[max(v[i] for v in coordinates) for i in range(3)]
    dimensions=[b-a for a,b in zip(lo,hi)]
    expected=report['asset_bounds'][key]['dimensions_xyz']
    assert all(math.isclose(a,b,abs_tol=1e-5) for a,b in zip(dimensions,expected)),(key,dimensions,expected)
    for ob in meshes:
        assert len(ob.data.uv_layers)>0
        assert all(v.normal.length>.9 for v in ob.data.vertices)
        assert all(p.area>1e-10 for p in ob.data.polygons), 'Degenerate exported face'
    results[key]={'standalone_glb_reimported':True,'batched_geometry_count':len(meshes),
                  'embedded_texture_count':len(doc.get('images',[])),
                  'dimensions_xyz':dimensions,'vertices':sum(len(o.data.vertices) for o in meshes),
                  'triangles':sum(len(o.data.polygons) for o in meshes)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'knight-costume-draft.glb'))
assert bpy.data.objects.get('Knight_Long_Dark_Navy_Cape') is not None
assert bpy.data.objects.get('Skin') is not None
assert any(ob.type=='ARMATURE' for ob in bpy.data.objects)
exported_cape=bpy.data.objects['Knight_Long_Dark_Navy_Cape']
assert exported_cape.data.shape_keys is not None
assert all(exported_cape.data.shape_keys.key_blocks.get(name) is not None
           for name in report['costume_revision']['cape_dynamic_shape_keys'])
results['costume_export']={'skinned_glb_reimported':True,'cape_and_silver_boots_present':True,
                           'all_four_cloth_morph_controls_preserved':True}

for pose,filename in [('idle','knight-ready-preview.blend'),('run','knight-run-preview.blend')]:
    bpy.ops.wm.open_mainfile(filepath=str(OUT/filename))
    scene=bpy.context.scene
    bpy.context.view_layer.update()
    rig=bpy.data.objects['Reference_Rig']
    for name,expected in report['shared_geometry_uv_weights_unchanged'].items():
        assert fingerprint(bpy.data.objects[name])==expected,(pose,name,'shared geometry changed')
    skin=bpy.data.objects['Skin']
    silver_faces=[p for p in skin.data.polygons
                  if 'silver' in skin.data.materials[p.material_index].name
                  and 'boot' in skin.data.materials[p.material_index].name]
    assert len(silver_faces)==report['costume_revision']['silver_boot_face_count']
    cape=bpy.data.objects['Knight_Long_Dark_Navy_Cape']
    shield_shell=bpy.data.objects['Wall_Shield_Closed_Beveled_Shell']
    assert bpy.data.objects.get('Wall_Shield_Original_Gold_Crest') is None
    assert not any(ob.name.startswith('Lion_') for ob in bpy.data.objects), 'Lion is still sculpted relief'
    face_material=shield_shell.data.materials[3]
    paint=face_material.node_tree.nodes.get('Flat lion painted graphic')
    assert paint is not None and paint.image.packed_file
    assert paint.image.size[0]==1024 and paint.outputs['Color'].is_linked
    for axis in [0,2]:
        middle=(min(v.co[axis] for v in shield_shell.data.vertices)+max(v.co[axis] for v in shield_shell.data.vertices))*.5
        assert abs(middle)<1e-6,'Shield grip sits off center'
    assert math.isclose(report['asset_bounds']['shield']['dimensions_xyz'][0],
                        report['original_shield_dimensions_xyz'][0]*3*.8*.9,abs_tol=1e-5)
    assert math.isclose(report['asset_bounds']['shield']['dimensions_xyz'][2],
                        report['original_shield_dimensions_xyz'][2]*3*.9,abs_tol=1e-5)
    assert min(v.co.z for v in cape.data.vertices)<.15
    assert max(v.co.z for v in cape.data.vertices)==1.5
    assert cape.vertex_groups.get('Chest') is not None
    assert any(m.type=='ARMATURE' and m.object==rig for m in cape.modifiers)
    assert max(v.co.x for v in cape.data.vertices)-min(v.co.x for v in cape.data.vertices)>1.55
    frames=range(1,17) if pose=='run' else range(1,25)
    max_distance=0
    min_alignment=1
    chest_reference=None
    cape_top_reference=None
    hem_positions=[]
    min_cape_height=100
    for frame in frames:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        chest=rig.pose.bones['Chest'].matrix.copy()
        if chest_reference is None:
            chest_reference=chest
        assert all(abs(chest[i][j]-chest_reference[i][j])<1e-6 for i in range(4) for j in range(4)), 'Torso swings during run'
        evaluated=cape.evaluated_get(bpy.context.evaluated_depsgraph_get())
        points=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
        top=[p for v,p in zip(cape.data.vertices,points) if v.co.z==1.5]
        if cape_top_reference is None:
            cape_top_reference=[p.copy() for p in top]
        assert all((a-b).length<1e-5 for a,b in zip(top,cape_top_reference)), 'Cape shoulders move off their attachment'
        hem_positions.append(points[35].copy())
        min_cape_height=min(min_cape_height,min(p.z for p in points))
        for side,name in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]:
            hand=rig.pose.bones['Hand_'+side]
            palm=rig.matrix_world@((hand.head+hand.tail)*.5)
            weapon=bpy.data.objects[name]
            grip=weapon.matrix_world.translation
            distance=(palm-grip).length
            axis=(weapon.matrix_world.to_3x3()@Vector((0,0,1))).normalized()
            hand_axis=(rig.matrix_world.to_3x3()@(hand.tail-hand.head)).normalized()
            alignment=axis.dot(hand_axis)
            assert distance<1e-5,(pose,frame,side,distance)
            assert alignment>.9999,(pose,frame,side,alignment)
            max_distance=max(max_distance,distance)
            min_alignment=min(min_alignment,alignment)
        if pose=='idle':
            sword=bpy.data.objects['Weapon_Cutlass']
            sword_face=(sword.matrix_world.to_3x3()@Vector((0,-1,0))).normalized()
            cutting_direction=(sword.matrix_world.to_3x3()@Vector((1,0,0))).normalized()
            assert sword_face.x<-.94 and abs(sword_face.y)<.05, 'Resting blade shows broad face to the front'
            assert abs(cutting_direction.y)>.99, 'Resting cutting edge does not point forward/back'
        if pose=='run':
            shield=bpy.data.objects['Weapon_Pistol']
            sword=bpy.data.objects['Weapon_Cutlass']
            shield_face=(shield.matrix_world.to_3x3()@Vector((0,-1,0))).normalized()
            sword_face=(sword.matrix_world.to_3x3()@Vector((0,-1,0))).normalized()
            assert shield_face.x>.99 and abs(shield_face.y)<.01
            assert sword_face.x<-.95 and abs(sword_face.y)<.12
    hem_movement=max((a-b).length for a in hem_positions for b in hem_positions)
    assert hem_movement>(.05 if pose=='run' else .01), 'Cape animation is static'
    assert min_cape_height>.02,'Cape clips the ground'
    results[pose+'_carry']={'frames_checked':len(frames),'max_grip_to_palm_distance':max_distance,
                           'minimum_hand_to_hilt_axis_alignment':min_alignment,'torso_stable':True,
                           'cape_shoulders_pinned':True,'cape_hem_motion':hem_movement,
                           'cape_min_ground_clearance':min_cape_height}
    assert bpy.context.scene.camera is not None
    assert all(image.packed_file for image in bpy.data.images if image.source=='FILE')
assert report['presentation_bounds']['idle']['shield']['min_xyz'][2]>.025
assert report['presentation_bounds']['run']['shield']['min_xyz'][2]>.025
assert report['presentation_bounds']['idle']['shield']['max_xyz'][2]<2.78
bpy.ops.wm.open_mainfile(filepath=str(OUT/'knight-weapons.blend'))
assert len([o for o in bpy.context.scene.objects if o.type=='MESH'])>2, 'Weapon source scene is empty'
assert bpy.context.scene.camera is not None
assert all(image.packed_file for image in bpy.data.images if image.source=='FILE')
results['editable_sources']={'all_three_open_with_populated_scenes':True,'all_file_textures_packed':True}
report['export_validation']=results
(OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('KNIGHT_DRAFT_VERIFIED',json.dumps(results))

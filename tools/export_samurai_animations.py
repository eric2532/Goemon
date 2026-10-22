"""Export approved evaluated Samurai poses and its sharp maroon katana.

Blender -b --python tools/export_samurai_animations.py [-- --source=ABS_BLEND]
Never saves over either the editable workbench or the original character source.
The original rest character remains the runtime skeleton/skin/texture baseline.
"""
from pathlib import Path
import bpy, json, hashlib, sys
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/samurai-weapon-workbench/Samurai_Weapon_Workbench.blend'
for arg in sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []:
    if arg.startswith('--source='): SOURCE=Path(arg.split('=',1)[1])
C=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1))); CI=C.inverted()
def pack(m):
    q=m.to_quaternion();return [*m.translation,q.x,q.y,q.z,q.w,*m.to_scale()]
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def export():
    original=ROOT/'assets/blender/characters/goemon_cosplay/samurai.blend'
    source_hash=digest(SOURCE); original_hash=digest(original)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    clips={}; names=None
    for key,scene_name,end,period in [('idle','01 — Idle',61,60),('run','02 — Run',25,24),('combo','03 — Five-hit combo',105,0)]:
        scene=bpy.data.scenes[scene_name];bpy.context.window.scene=scene
        rig=next(o for o in scene.objects if o.type=='ARMATURE')
        if names is None:
            # Keep original deform hierarchy, including its Root ancestor.
            names=[b.name for b in rig.data.bones if b.name=='Root' or b.use_deform]
        frames=[]
        weapon=next(o for o in scene.objects if o.name.startswith('Weapon_Cutlass') and o.type=='EMPTY')
        for f in range(1,end+1):
            scene.frame_set(f);bpy.context.view_layer.update()
            dg=bpy.context.evaluated_depsgraph_get();evaluated=rig.evaluated_get(dg)
            bones=[]
            for name in names:
                pb=evaluated.pose.bones[name];m=C@pb.matrix@CI;rest=C@pb.bone.matrix_local@CI
                delta=m.copy();delta.translation=(0,0,0)
                delta=delta@rest.to_3x3().inverted().to_4x4();delta.translation=m.translation
                bones.append(pack(delta))
            transform=evaluated.matrix_world.inverted()@weapon.evaluated_get(dg).matrix_world
            frames.append({'bones':bones,'weapon':pack(C@transform@CI)})
        clips[key]={'action':rig.animation_data.action.name,'fps':30,'period_frames':period,'frames':frames}
    bpy.context.window.scene=bpy.data.scenes['01 — Idle'];bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
    weapon=bpy.data.objects['Weapon_Cutlass'];design=next(o for o in weapon.children if o.name.startswith('Katana_Design'))
    # Bake bevels and the approved +20% design scale once, in weapon-local axes.
    parts=[];materials={}
    for ob in design.children_recursive:
        if ob.type!='MESH':continue
        evaluated=ob.evaluated_get(dg);me=evaluated.to_mesh()
        transform=weapon.matrix_world.inverted()@ob.matrix_world
        parts.append({'name':ob.name,'blade':ob.name.startswith('Katana_Blade'),'vertices':[list(transform@v.co) for v in me.vertices],
            'faces':[list(p.vertices) for p in me.polygons],
            'smooth':[p.use_smooth for p in me.polygons],
            'slots':[m.name for m in me.materials], 'indices':[p.material_index for p in me.polygons]})
        for mat in me.materials:
            bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            materials[mat.name]={'color':list(bsdf.inputs['Base Color'].default_value),
                'metallic':bsdf.inputs['Metallic'].default_value,'roughness':bsdf.inputs['Roughness'].default_value}
        evaluated.to_mesh_clear()
    blade=next(o for o in design.children_recursive if o.type=='MESH' and o.name.startswith('Katana_Blade'))
    tip_vertex=max(blade.data.vertices,key=lambda v:v.co.z)
    tip=C@(weapon.matrix_world.inverted()@blade.matrix_world@tip_vertex.co)
    blade_base=min((C@(weapon.matrix_world.inverted()@blade.matrix_world@v.co)).y for v in blade.data.vertices)
    data={'source':'docs/samurai-weapon-workbench/Samurai_Weapon_Workbench.blend','source_sha256':source_hash,
          'original_character_sha256':original_hash,'bones':names,'weapon_tip':list(tip),'blade_base':[0,blade_base,0],
          'combo_starts':[1,20,38,56,74],'combo_contacts':[12,30,48,66,87],
          'combo_ends':[20,38,56,74,105],'clips':clips}
    out=ROOT/'assets/animations/samurai_approved.json';out.write_text(json.dumps(data,separators=(',',':'))+'\n')

    bpy.ops.wm.open_mainfile(filepath=str(original))
    if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    weapon=bpy.data.objects['Weapon_Cutlass']
    for child in list(weapon.children_recursive):bpy.data.objects.remove(child,do_unlink=True)
    mats={}
    for name,value in materials.items():
        mat=bpy.data.materials.new(name);mat.use_nodes=True
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value=value['color'];bsdf.inputs['Metallic'].default_value=value['metallic'];bsdf.inputs['Roughness'].default_value=value['roughness']
        mats[name]=mat
    # Two meshes instead of 20 objects. The hilt stays fixed when reach extends
    # the blade, keeping both hands on the approved grip at every supported size.
    for is_blade,name in [(True,'Katana_Blade_Maroon'),(False,'Katana_Hilt')]:
        vertices=[];faces=[];indices=[];smooth=[];slots=list(mats)
        for part in parts:
            if part['blade']!=is_blade:continue
            offset=len(vertices);vertices.extend(part['vertices'])
            faces.extend([v+offset for v in face] for face in part['faces'])
            indices.extend(slots.index(part['slots'][i]) for i in part['indices']);smooth.extend(part['smooth'])
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        for mat_name in slots:mesh.materials.append(mats[mat_name])
        for polygon,index,shade in zip(mesh.polygons,indices,smooth):polygon.material_index=index;polygon.use_smooth=shade
        ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ob.parent=weapon;ob.matrix_basis=Matrix.Identity(4)
    bpy.ops.object.select_all(action='SELECT')
    target=ROOT/'assets/models/characters/goemon_cosplay/samurai.glb'
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_animations=False,export_yup=True,export_skins=True,export_materials='EXPORT',export_extras=True)
    assert digest(SOURCE)==source_hash and digest(original)==original_hash, 'Read-only Blender sources changed'
    print('SAMURAI_APPROVED_EXPORT_OK',json.dumps({'frames':{k:len(v['frames']) for k,v in clips.items()},'weapon_tip':list(tip),'weapon_parts_baked':len(parts),'source_sha256':source_hash}))
if __name__=='__main__':export()

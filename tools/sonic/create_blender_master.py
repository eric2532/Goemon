"""One-time import into the established Blender template; refuses to overwrite edits.

Blender --background --python tools/sonic/create_blender_master.py
Subsequent edits: Blender <master.blend> --background --python tools/export_blender.py
"""
import bpy
import math
from pathlib import Path
import sys
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from recovered_enemy_blender import fingerprint

def main():
    folder=ROOT/'assets/blender/characters/sonic';folder.mkdir(parents=True,exist_ok=True)
    for name in ('sonic','ball','curled','effect_trail','effect_ball'):
        if (folder/(name+'.blend')).exists():
            print('PRESERVED_EXISTING_MASTER',name);continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene=bpy.context.scene;scene.render.fps=60;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
        source=ROOT/'build/Other Files/Asset Toolkit/Sonic/Research/sonic-prepared.glb' if name=='sonic' else ROOT/f'assets/characters/recovered_sonic/{name}.glb'
        bpy.ops.import_scene.gltf(filepath=str(source))
        remove_import_gizmos()
        scene.render.fps=60
        roots=[o for o in scene.objects if o.parent is None]
        wrapper=bpy.data.objects.new('Sonic_UnitAndFacing',None);scene.collection.objects.link(wrapper)
        wrapper.scale=(.2,.2,.2);wrapper.rotation_euler.z=-math.pi/2;wrapper.location.z=1.08
        for ob in roots:ob.parent=wrapper
        for ob in scene.objects:
            if ob.animation_data:
                ob.animation_data.action=None
                for track in ob.animation_data.nla_tracks:track.mute=name=='sonic' and track.name!='Sonic Stand'
            if ob.type=='MESH':ob['source_geometry_fingerprint']=fingerprint(ob)
        scene.frame_set(1)
        scene['source_game']='GXSP8P revision 1; original geometry, textures, poses and type-2 welds'
        scene['source_unit_metres']=.2
        scene['normal_exporter']='tools/export_blender.py'
        bpy.ops.wm.save_as_mainfile(filepath=str(folder/(name+'.blend')))
        # The existing exporter preserves edited meshes/UVs and NLA clips.
        exec(compile((ROOT/'tools/export_blender.py').read_text(),str(ROOT/'tools/export_blender.py'),'exec'),{'__file__':str(ROOT/'tools/export_blender.py')})
        if name=='sonic':portrait(scene)

def remove_import_gizmos():
    shapes=set()
    for ob in bpy.context.scene.objects:
        if ob.type!='ARMATURE':continue
        for bone in ob.pose.bones:
            if bone.custom_shape:shapes.add(bone.custom_shape);bone.custom_shape=None
    for shape in shapes:bpy.data.objects.remove(shape,do_unlink=True)

def portrait(scene):
    scene.frame_set(1);depsgraph=bpy.context.evaluated_depsgraph_get();depsgraph.update()
    evaluated=[o.evaluated_get(depsgraph) for o in scene.objects if o.type=='MESH']
    coords=[o.matrix_world@v.co for o in evaluated for v in o.data.vertices]
    lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)));hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
    center=(lo+hi)/2;extent=max(hi-lo)
    bpy.ops.object.camera_add(location=center+Vector((.8,2.0,.3))*extent)
    camera=bpy.context.object;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=extent*1.35;scene.camera=camera
    for location,power in [((1,2,3),750),((-2,1,2),500)]:
        bpy.ops.object.light_add(type='AREA',location=center+Vector(location)*extent)
        light=bpy.context.object;light.data.energy=power;light.data.size=extent*2;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene.world=bpy.data.worlds.new('Preview World');scene.world.color=(.25,.25,.25)
    scene.render.engine='BLENDER_EEVEE';scene.render.film_transparent=True
    scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.render.filepath=str(ROOT/'assets/characters/recovered_sonic/portrait.png');bpy.ops.render.render(write_still=True)
    center=Vector((0,0,1.55));camera.location=center+Vector((.2,4,.12));camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=1.2
    scene.render.resolution_x=512;scene.render.resolution_y=512
    scene.render.filepath=str(ROOT/'assets/characters/recovered_sonic/hud_portrait.png');bpy.ops.render.render(write_still=True)

if __name__=='__main__':main()

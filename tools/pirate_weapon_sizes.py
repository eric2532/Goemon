"""Shared, grip-centered Blender review sizing and camera framing."""
import bpy
from mathutils import Matrix, Vector

SIZES={'Weapon_Cutlass':('Sword_Size_Control',2.2),'Weapon_Pistol':('Gun_Size_Control',1.8)}

def apply_scene_sizes(scene):
    result={}
    for prefix,(label,size) in SIZES.items():
        root=next(ob for ob in scene.objects if ob.type=='EMPTY' and (ob.name==prefix or ob.name.startswith(prefix+'.')))
        group=next((ob for ob in root.children if ob.name==label or ob.name.startswith(label+'.')),None)
        if group is None:
            children=list(root.children)
            group=bpy.data.objects.new(label,None);scene.collection.objects.link(group)
            group.parent=root;group.empty_display_type='PLAIN_AXES';group.empty_display_size=.12
            for ob in children:
                local=ob.matrix_local.copy();ob.parent=group
                ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=local
        group.scale=(size,)*3
        group['size_multiplier']=size;group['pivot']='Native weapon grip; hand and animation controls remain unchanged.'
        root['review_weapon_scale']=size
        result[prefix]=size
    bpy.context.view_layer.update()
    return result

def fit_camera(scene,frames=None):
    bpy.context.window.scene=scene
    old_frame=scene.frame_current
    cam=scene.camera
    rotation=cam.rotation_euler.to_quaternion().to_matrix()
    inverse=rotation.inverted()
    points=[]
    for frame in frames or [old_frame]:
        scene.frame_set(frame);bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get()
        for ob in scene.objects:
            if ob.type not in ['MESH','CURVE'] or ob.hide_render:continue
            evaluated=ob.evaluated_get(dg)
            points.extend(inverse@(evaluated.matrix_world@Vector(p)) for p in evaluated.bound_box)
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=rotation@((lo+hi)/2)
    aspect=scene.render.resolution_x/scene.render.resolution_y
    scale=max(hi.x-lo.x,(hi.y-lo.y)*aspect)*1.18
    cam.location=center+rotation@Vector((0,0,10))
    cam.data.ortho_scale=scale
    scene.frame_set(old_frame)
    return center,scale

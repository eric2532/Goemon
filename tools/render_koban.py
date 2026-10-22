"""Render the saved coin for source inspection; does not modify the source file."""
import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24
s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100
s.world.color=(.14,.14,.14)
s.view_settings.view_transform='Standard'
for pos,power,size in [((1,3,4),350,3),((-3,1,2),160,2),((0,-3,3),220,2)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.70,2.6,1.1));cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.15
for name,pos in [('front',(0,3,0)),('back',(0,-3,0)),('three-quarter',(.7,2.6,1.1))]:
 cam.location=pos;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
 s.render.filepath=str(ROOT/'tests'/('koban-source-'+name+'.png'));bpy.ops.render.render(write_still=True)

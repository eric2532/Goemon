import bpy, os, sys, json
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,'goldmine_v1.blend'))
scene=bpy.context.scene;scene.cycles.use_denoising=False
scene.cycles.samples=32
cam=scene.camera
anim=[o for o in bpy.data.objects if o.animation_data and o.animation_data.nla_tracks]
def pose(clip,f):
 for o in anim:
  a=bpy.data.actions.get(clip+'__'+o.name)
  if a:o.animation_data.action=a;o.animation_data.use_nla=False
 scene.frame_set(f);bpy.context.view_layer.update()
def point(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
pose('work_loop',1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'goldmine_v1.blend'),compress=True)
mode=sys.argv[-1]
if mode=='hero':
 scene.render.filepath=os.path.join(OUT,'renders','front_three_quarter.png');bpy.ops.render.render(write_still=True)
else:
 for name,loc in [('rear_three_quarter',(-6,7,4.6)),('front',(0,-9,4.3))]:
  cam.location=loc;point(cam,(0,-.15,1.08));pose('work_loop',1);scene.render.filepath=os.path.join(OUT,'renders',name+'.png');bpy.ops.render.render(write_still=True)
 cam.location=(6,-8,5.3);point(cam,(0,-.15,1.08))
 for name,clip,f in [('unbuilt','build',1),('construction','build',29),('reinforced_proposal','upgrade_preview',49)]:
  pose(clip,f);scene.render.filepath=os.path.join(OUT,'renders',name+'.png');bpy.ops.render.render(write_still=True)
 scene.render.resolution_x=640;scene.render.resolution_y=528;scene.cycles.samples=4
 sequence=[('build',1,49),('work_loop',1,97),('upgrade_preview',1,49),('reverse_build',1,49)];k=0
 for clip,start,end in sequence:
  for f in range(start,end+1,2):
   pose(clip,f);scene.render.filepath=os.path.join(OUT,'preview_frames','%04d.png'%k);bpy.ops.render.render(write_still=True);k+=1
 with open(os.path.join(OUT,'preview_sequence.json'),'w') as f:json.dump({'fps':12,'frames':k,'sections':['build','work_loop','upgrade_preview','reverse_build']},f,indent=2)
print('RENDER_COMPLETE')

import bpy,os
from pathlib import Path
OUT=Path('/workspace/scratch/23f1a29e8f92/construction_fx_v1')
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE_NEXT';s.eevee.taa_render_samples=48
s.render.resolution_x=1152;s.render.resolution_y=720;s.render.resolution_percentage=100
for f,name in [(59,'build'),(91,'release_decay'),(130,'resume'),(165,'completion')]:
 s.frame_set(f);s.render.filepath=str(OUT/'previews'/('demo_'+name+'.png'));bpy.ops.render.render(write_still=True)
# 12 authored samples per second, encoded as 24 fps with repeated frames.
frames=OUT/'qa'/'render_frames';frames.mkdir(exist_ok=True)
s.eevee.taa_render_samples=16;s.render.resolution_x=960;s.render.resolution_y=600
for index,f in enumerate(range(1,194,2)):
 s.frame_set(f);s.render.filepath=str(frames/f'{index:04d}.png');bpy.ops.render.render(write_still=True)
print('PREVIEWS_RENDERED')

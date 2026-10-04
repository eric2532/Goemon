"""Final source edits after concept/render review, then exact mesh GLB export."""
import bpy, math, sys, runpy
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
g=runpy.run_path(str(R/'tools'/'build_characters.py'));ctx=g['mesh'].__globals__
for cfg in g['CONFIGS']:
 name=cfg['name'];stem=name.lower();bpy.ops.wm.open_mainfile(filepath=str(R/'blend'/f'{stem}.blend'))
 C=next(c for c in bpy.data.collections if 'editable character' in c.name)
 M={m.name.split(' / ',1)[1]:m for m in bpy.data.materials if m.name.startswith(name+' / ')}
 if name=='Izumi':M['cloak']=bpy.data.materials[name+' / frost blue cape']
 ctx.update(C=C,M=M,TAG=name,CFG=cfg)
 # The close scalp must sit outside each character's own head width.
 scalp=next(o for o in C.objects if 'Hair_scalp_contoured' in o.name)
 for v in scalp.data.vertices:v.co.x*=max(1,cfg.get('head_width',1))+.025
 if name=='Gaku':
  for o in list(C.objects):
   if 'Ivory_headband' in o.name:bpy.data.objects.remove(o,do_unlink=True)
  verts=[];n=96
  for z in (2.51,2.517,2.639,2.646):
   for i in range(n):
    a=2*math.pi*i/n;verts.append((.514*math.sin(a)*1.07,(-.025+.421*math.cos(a))*1.07,(z-1.95)*1.07+1.56))
  faces=[]
  for j in range(3):
   for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
  g['mesh']('Broad_woven_headband',verts,faces,'cream',1,.008)
 if name in ('Izumi','Touma','Shiro'):
  material='cloak' if name=='Izumi' else 'accent'
  for side in ((1,) if name=='Shiro' else (-1,1)):
   pts=[(side*.18,.245,1.88),(side*.34,.345,1.79),(side*.51,.35,1.63),(side*.66,.305,1.48)]
   if name=='Touma':pts[-1]=(side*.67,.30,1.39)
   # geometry is authored in the same existing proportional space
   pts=[(x*1.025,y*1.04,z*.85) for x,y,z in pts]
   o=g['ribbon']('Front_mantle_drape_'+str(side),pts,[.075,.145,.17,.13],material,.013)
   border=[(x+side*w,y+.012,z) for (x,y,z),w in zip(pts,[.075,.145,.17,.13])]
   g['line']('Mantle_front_hem_'+str(side),border,.006,'cream')
   if name=='Izumi':g['diamond']('Frost_mantle_glyph_'+str(side),side*.51,.384,1.38,.051,'cream')
   if name=='Shiro':g['moon']('Mantle_visible_crescent',.51,.384,1.40,.062,'cream')
 for ob in C.objects:
  if ob.type=='MESH' and not ob.data.uv_layers:
   uv=ob.data.uv_layers.new(name='Surface_UV')
   for lp in ob.data.loops:
    co=ob.data.vertices[lp.vertex_index].co;uv.data[lp.index].uv=(co.x*2,co.z*2)
 # Roots make collection placement/scale convenient without joining editable parts.
 root=bpy.data.objects.new(name+'_Root',None);C.objects.link(root);root.empty_display_type='PLAIN_AXES';root.empty_display_size=.1
 for o in list(C.objects):
  if o!=root:o.parent=root
 # Keep source camera framing entirely inside the safe margin.
 bpy.context.view_layer.update()
 cam=bpy.context.scene.camera; inv=cam.matrix_world.inverted();points=[]
 for o in C.objects:
  if o.type in ('MESH','CURVE'):
   points += [inv@(o.matrix_world@Vector(v)) for v in o.bound_box]
 lo=[min(p[j] for p in points) for j in (0,1)];hi=[max(p[j] for p in points) for j in (0,1)]
 shift=cam.matrix_world.to_quaternion()@Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,0));cam.location+=shift
 aspect=bpy.context.scene.render.resolution_x/bpy.context.scene.render.resolution_y;cam.data.ortho_scale=max((hi[1]-lo[1])*1.12,(hi[0]-lo[0])/aspect*1.12)
 bpy.ops.wm.save_as_mainfile(filepath=str(R/'blend'/f'{stem}.blend'),compress=True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in C.objects:o.select_set(True)
 bpy.context.view_layer.objects.active=next(o for o in C.objects if o.type=='MESH');bpy.ops.object.convert(target='MESH')
 bpy.ops.export_scene.gltf(filepath=str(R/'glb'/f'{stem}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
 print('POLISH_SAVED',stem,flush=True)

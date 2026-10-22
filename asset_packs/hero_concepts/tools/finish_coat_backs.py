"""Complete the rear fabric panels of the three open-front outer jackets."""
import bpy,math,runpy
from pathlib import Path
R=Path(__file__).resolve().parents[1];g=runpy.run_path(str(R/'tools'/'build_characters.py'));ctx=g['mesh'].__globals__
for cfg in g['CONFIGS']:
 name=cfg['name']
 if name not in ('Raku','Banji','Kuren'):continue
 stem=name.lower();bpy.ops.wm.open_mainfile(filepath=str(R/'blend'/f'{stem}.blend'));C=next(c for c in bpy.data.collections if 'editable character' in c.name);root=bpy.data.objects[name+'_Root'];M={m.name.split(' / ',1)[1]:m for m in bpy.data.materials if m.name.startswith(name+' / ')};ctx.update(C=C,M=M,TAG=name,CFG=cfg)
 for o in list(C.objects):
  if 'Outer_jacket_back' in o.name:bpy.data.objects.remove(o,do_unlink=True)
 rows=[(1.30,.365,.277),(1.315,.37,.28),(1.50,.443,.279),(1.67,.48*cfg.get('bulk',1),.275),(1.79,.40,.23)]
 n=32;verts=[]
 for z,rx,ry in rows:
  for i in range(n+1):
   a=math.pi/2+math.pi*i/n;verts.append((rx*math.sin(a)*1.12,ry*math.cos(a)*1.04,z*.85))
 faces=[]
 for j in range(len(rows)-1):
  for i in range(n):k=j*(n+1)+i;faces.append((k,k+1,k+n+2,k+n+1))
 ob=g['mesh']('Outer_jacket_back',verts,faces,'accent' if name=='Kuren' else 'cloth',1,.014);ob.parent=root
 uv=ob.data.uv_layers.new(name='Surface_UV')
 for lp in ob.data.loops:
  co=ob.data.vertices[lp.vertex_index].co;uv.data[lp.index].uv=(co.x*2,co.z*2)
 bpy.ops.wm.save_as_mainfile(filepath=str(R/'blend'/f'{stem}.blend'),compress=True)
 bpy.ops.object.select_all(action='DESELECT')
 for ob in C.objects:ob.select_set(True)
 bpy.context.view_layer.objects.active=next(o for o in C.objects if o.type=='MESH');bpy.ops.object.convert(target='MESH')
 bpy.ops.export_scene.gltf(filepath=str(R/'glb'/f'{stem}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
 print('COAT_BACK_SAVED',stem,flush=True)

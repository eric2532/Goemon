"""Fit scalp control cages to actual head profiles after turnaround review."""
import bpy, math, runpy, sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
g=runpy.run_path(str(R/'tools'/'build_characters.py'));ctx=g['mesh'].__globals__
rows=[(2.00,.24,.245,-.005),(2.055,.33,.29,0),(2.17,.425,.345,-.015),(2.31,.455,.362,-.02),(2.48,.452,.36,-.03),(2.65,.424,.345,-.035),(2.77,.31,.27,-.04),(2.82,.13,.13,-.04),(2.89,.006,.006,-.04)]
def profile(z):
 for a,b in zip(rows,rows[1:]):
  if a[0]<=z<=b[0]:
   t=(z-a[0])/(b[0]-a[0]);return tuple(a[i]*(1-t)+b[i]*t for i in (1,2,3))
 return rows[-1][1:]
names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['all']
for cfg in g['CONFIGS']:
 name=cfg['name'];stem=name.lower()
 if 'all' not in names and stem not in names:continue
 bpy.ops.wm.open_mainfile(filepath=str(R/'blend'/f'{stem}.blend'))
 C=next(c for c in bpy.data.collections if 'editable character' in c.name);root=bpy.data.objects[name+'_Root']
 M={m.name.split(' / ',1)[1]:m for m in bpy.data.materials if m.name.startswith(name+' / ')};ctx.update(C=C,M=M,TAG=name,CFG=cfg)
 if name in ('Raku','Gaku','Roan','Kuren'):
  color={'Raku':'3B3025','Gaku':'34291F','Roan':'51432D','Kuren':'55412C'}[name];rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)];rgb=[((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in rgb]
  M['iris'].diffuse_color=(*rgb,1);M['iris'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*rgb,1)
 for o in list(C.objects):
  if any(x in o.name for x in ('Hair_scalp_contoured','Fitted_scalp','Occipital_lock')):bpy.data.objects.remove(o,do_unlink=True)
 verts=[];n=96;m=15
 for j in range(m):
  t=j/(m-1)
  for i in range(n):
   a=2*math.pi*i/n;c=math.cos(a);front=max(0,c)
   bottom=2.13+.13*abs(math.sin(a))**2+.52*front**.35
   if cfg['style'] in ('crop','spikes'):bottom=2.20+.12*abs(math.sin(a))**2+.40*front**.35
   z=bottom+(2.885-bottom)*t;rx,ry,cy=profile(z)
   x=(rx*cfg.get('head_width',1)+.03)*math.sin(a);y=cy+(ry+.03)*math.copysign(abs(c)**.6,c)
   verts.append((x*1.07,y*1.07,(z-1.95)*1.07+1.56))
 faces=[]
 for j in range(m-1):
  for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 faces.append(tuple((m-1)*n+i for i in range(n)))
 ob=g['mesh']('Fitted_scalp',verts,faces,'hair',1,.012);ob.parent=root
 # Layer the back silhouette, which has no supplied rear drawing.
 if cfg['style'] not in ('crop','spikes','bun'):
  old=set(C.objects)
  for i in range(15):
   a=math.pi*.52+math.pi*.96*i/14
   x=math.sin(a);y=math.cos(a)
   endz=2.12 if cfg['style']!='bob' else 2.00
   g['hairlock']('Occipital_lock_%02d'%i,[(x*.23,-.045+y*.24,2.85),(x*.49,-.055+y*.405,2.76),(x*.51,-.045+y*.41,2.35),(x*.47,-.045+y*.35,endz)],.061,'hair',.28)
  for ob in set(C.objects)-old:
   if ob.type=='MESH':
    for v in ob.data.vertices:v.co=Vector((v.co.x*1.07,v.co.y*1.07,(v.co.z-1.95)*1.07+1.56))
   elif ob.type=='CURVE':
    for sp in ob.data.splines:
     for p in sp.points:p.co=(p.co.x*1.07,p.co.y*1.07,(p.co.z-1.95)*1.07+1.56,1)
   ob.parent=root
 for ob in C.objects:
  if ob.type=='MESH' and not ob.data.uv_layers:
   uv=ob.data.uv_layers.new(name='Surface_UV')
   for lp in ob.data.loops:
    co=ob.data.vertices[lp.vertex_index].co;uv.data[lp.index].uv=(co.x*2,co.z*2)
 bpy.ops.wm.save_as_mainfile(filepath=str(R/'blend'/f'{stem}.blend'),compress=True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in C.objects:o.select_set(True)
 bpy.context.view_layer.objects.active=next(o for o in C.objects if o.type=='MESH');bpy.ops.object.convert(target='MESH')
 bpy.ops.export_scene.gltf(filepath=str(R/'glb'/f'{stem}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
 print('HAIR_REPAIR_SAVED',stem,flush=True)

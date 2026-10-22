from pathlib import Path
import bpy,bmesh,math
from mathutils import Vector
folder=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(folder/'Samurai_Weapon_Workbench.blend'));bpy.context.preferences.filepaths.save_version=0
verts=[];faces=[]
for link in range(12):
 theta=link*.25;center=Vector((.022+.15*(1-math.cos(theta)),0,-.335-.15*math.sin(theta)))
 tangent=Vector((math.sin(theta),0,-math.cos(theta)));side=Vector((math.cos(theta),0,math.sin(theta))) if link%2==0 else Vector((0,1,0))
 normal=side.cross(tangent).normalized();base=len(verts)
 for j in range(12):
  a=j*math.tau/12;radial=(side*math.cos(a)+tangent*math.sin(a)).normalized();mid=center+side*(.019*math.cos(a))+tangent*(.027*math.sin(a))
  for k in range(4):verts.append(mid+.004*(radial*math.cos(k*math.tau/4)+normal*math.sin(k*math.tau/4)))
 for j in range(12):
  for k in range(4):faces.append((base+j*4+k,base+((j+1)%12)*4+k,base+((j+1)%12)*4+(k+1)%4,base+j*4+(k+1)%4))
ob=bpy.data.objects['Katana_Chain — twelve interlocking pommel links'];me=ob.data;me.clear_geometry();me.from_pydata(verts,[],faces);me.update()
bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
bpy.context.window.scene=bpy.data.scenes['01 — Samurai with maroon katana'];bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Samurai_Weapon_Workbench.blend'))
for name,filename in [('01 — Samurai with maroon katana','samurai-preview.png'),('02 — Katana and unchanged sheath','katana-detail.png')]:
 sc=bpy.data.scenes[name];sc.render.filepath=str(folder/filename);bpy.ops.render.render(write_still=True,scene=sc.name)
print('CHAIN_CONTINUITY_OK',flush=True)

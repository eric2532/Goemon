"""Shared rounded modeling/export helpers for the concept-only enemy asset set."""
import bpy,math,json,bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/enemy-concepts/3d-v01'
EDIT=ROOT/'assets/blender/enemies/forest_redesign_v01'
EXPORT=ROOT/'assets/models/enemies/forest_redesign_v01'
TEX=ROOT/'assets/textures/enemies/forest_redesign_v01'
for p in [DOC,EDIT,EXPORT,TEX]:p.mkdir(parents=True,exist_ok=True)
GOEMON=json.loads((DOC/'goemon-reference.json').read_text())
HEIGHT=GOEMON['height']
PALETTE={'ink':'22262b','indigo':'344252','moss':'68744a','red':'aa3e30','cream':'e6d5a8','wood':'735039','rope':'b8a174','iron':'464750','stone':'505760','skin':'bb8b60','straw':'c4a15f','tongue':'b44c40','amber':'edac48'}
def reset():bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,roughness=.8,metallic=0):
 color=PALETTE.get(color,color);rgb=[int(color[i:i+2],16)/255 for i in [0,2,4]]
 rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
 b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*rgb,1);b.inputs['Roughness'].default_value=roughness;b.inputs['Metallic'].default_value=metallic
 return m

def texture_mat(name,path,emission=0):
 m=mat(name,'cream');b=m.node_tree.nodes.get('Principled BSDF');t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(path),check_existing=True);t.image.pack();t.interpolation='Linear'
 m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
 if emission:
  m.node_tree.links.new(t.outputs['Color'],b.inputs['Emission Color']);b.inputs['Emission Strength'].default_value=emission
 return m

def finish(o,name,material,smooth=True):
 o.name=name;o['enemy_asset']=True
 if material:o.data.materials.append(material)
 if o.type=='MESH':
  for p in o.data.polygons:p.use_smooth=smooth
  if not o.data.uv_layers:
   uv=o.data.uv_layers.new(name='UVMap')
   for l in uv.data:l.uv=(.5,.5)
 return o

def mesh(name,verts,faces,material,uvs=None,smooth=True):
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
 bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(m);bm.free()
 finish(o,name,material,smooth)
 if uvs:
  layer=m.uv_layers.active
  for l in m.loops:layer.data[l.index].uv=uvs[l.vertex_index]
 return o

def uv_sphere(name,center,size,material,segments=32,rings=20):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=center)
 o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,material)

def box(name,center,size,material,bevel=.06):
 bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 finish(o,name,material,False)
 if bevel:
  mod=o.modifiers.new('Soft rounded edges','BEVEL');mod.width=bevel;mod.segments=3
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
  # Keep broad flat faces, but smoothly shade the bevel bands.
  for p in o.data.polygons:p.use_smooth=p.area<max(size)*max(size)*.12
 return o

def loft(name,rings,material,count=40,smooth=True):
 # z, x center, y center, x radius, y radius; front faces +Y.
 verts=[];uvs=[]
 for k,(z,cx,cy,rx,ry) in enumerate(rings):
  for j in range(count+1):
   a=-math.pi+j*math.tau/count;verts.append((cx+rx*math.sin(a),cy+ry*math.cos(a),z));uvs.append((j/count,k/(len(rings)-1)))
 faces=[]
 for k in range(len(rings)-1):
  for j in range(count):
   i=k*(count+1)+j;faces.append((i,i+1,i+count+2,i+count+1))
 faces.extend([tuple(reversed(range(count))),tuple((len(rings)-1)*(count+1)+j for j in range(count))])
 return mesh(name,verts,faces,material,uvs,smooth)

def tube(name,a,b,radius,material,radius2=None,count=16):
 a,b=Vector(a),Vector(b);axis=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=count,radius1=radius,radius2=radius if radius2 is None else radius2,depth=axis.length,location=(a+b)*.5)
 o=bpy.context.object;o.rotation_euler=axis.to_track_quat('Z','Y').to_euler();return finish(o,name,material)

def curve(name,points,radius,material,resolution=3):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=2;c.bevel_depth=radius;c.bevel_resolution=resolution
 s=c.splines.new('POLY');s.points.add(len(points)-1)
 for p,co in zip(s.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o=bpy.context.object
 finish(o,name,material);o.select_set(False);return o

def ellipse(name,center,rx,ry,radius,material,count=48,twist=0):
 x,y,z=center;return curve(name,[(x+rx*math.sin(j*math.tau/count),y+ry*math.cos(j*math.tau/count),z+twist*math.sin(j*math.tau/count)) for j in range(count+1)],radius,material)

def cloth(name,rows,material,thickness=.025):
 # rows of ordered cross-sections of a garment or paper strip.
 verts=[p for row in rows for p in row];n=len(rows[0]);faces=[]
 for i in range(len(rows)-1):
  for j in range(n-1):
   a=i*n+j;faces.append((a,a+1,a+n+1,a+n))
 o=mesh(name,verts,faces,material)
 mod=o.modifiers.new('Cloth has thickness','SOLIDIFY');mod.thickness=thickness;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('Soft garment edges','BEVEL');mod.width=.012;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def surface(name,fn,material,cols=40,rows=32):
 verts=[];uv=[]
 for i in range(rows+1):
  v=i/rows
  for j in range(cols+1):
   u=j/cols;verts.append(fn(u,v));uv.append((u,v))
 faces=[]
 for i in range(rows):
  for j in range(cols):
   a=i*(cols+1)+j;faces.append((a,a+1,a+cols+2,a+cols+1))
 return mesh(name,verts,faces,material,uv)

def material_set():return {k:mat(k,k,metallic=.25 if k=='iron' else 0) for k in PALETTE}
def asset_meshes():return [o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('enemy_asset')]
def bounds(objects=None):
 points=[o.matrix_world@Vector(v) for o in objects or asset_meshes() for v in o.bound_box]
 return [min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]
def rescale_to_height(target):
 objects=asset_meshes();lo,hi=bounds(objects);scale=target/(hi[2]-lo[2])
 for o in objects:
  o.location*=scale;o.location.z-=lo[2]*scale;o.scale*=scale
  bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.context.view_layer.update();return scale

def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def studio():
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
 scene.world=bpy.data.worlds.new('Neutral art review');scene.world.use_nodes=True;scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.18,.20,.23,1);scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.35
 scene.render.resolution_x=800;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
 scene.render.threads_mode='FIXED';scene.render.threads=4;scene.view_settings.view_transform='AgX'
 lo,hi=bounds();height=hi[2]-lo[2];focus=Vector((0,0,height*.51))
 bpy.ops.object.camera_add();camera=bpy.context.object;camera.name='Preview_Camera';camera['export_exclude']=True;camera.data.type='ORTHO';camera.data.ortho_scale=max(height*1.2,(hi[0]-lo[0])*1.28);scene.camera=camera
 for index,(loc,power,size) in enumerate([((height*1.5,height*2,height*2.5),900,5),((-height*1.4,height,height*1.3),650,4),((0,-height*1.5,height*1.9),1100,4)]):
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name='Studio_'+str(index);o.data.energy=power;o.data.shape='DISK';o.data.size=size;o['export_exclude']=True;aim(o,focus)
 return camera,focus,height

def export_asset(slug,role,notes):
 bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
 meshes=asset_meshes();bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 output=EXPORT/(slug+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(output),use_selection=True,export_format='GLB',export_yup=True,export_animations=False,export_skins=False,export_cameras=False,export_lights=False)
 camera,focus,height=studio()
 camera.location=focus+Vector((7,10,1.7));aim(camera,focus)
 source=EDIT/(slug+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
 directions={'front':(0,10,0),'side':(-10,0,0),'back':(0,-10,0),'three-quarter':(7,10,1.7)}
 for view,offset in directions.items():
  camera.location=focus+Vector(offset);aim(camera,focus);bpy.context.scene.render.filepath=str(DOC/(slug+'-'+view+'.png'));bpy.ops.render.render(write_still=True)
 # Face-detail review uses the front-facing artwork-bearing mesh bounds.
 faces=[o for o in meshes if o.get('face_artwork')]
 if faces:
  flo,fhi=bounds(faces);camera.location=Vector((0,10,(flo[2]+fhi[2])*.5));aim(camera,(0,0,(flo[2]+fhi[2])*.5));camera.data.ortho_scale=max(fhi[0]-flo[0],fhi[2]-flo[2])*1.45
  bpy.context.scene.render.filepath=str(DOC/(slug+'-face-detail.png'));bpy.ops.render.render(write_still=True)
 lo,hi=bounds(meshes)
 report={'asset':slug,'role':role,'source':str(source.relative_to(ROOT)),'export':str(output.relative_to(ROOT)),'bounds_min':lo,'bounds_max':hi,'height':height,'height_vs_goemon':height/HEIGHT,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'meshes':len(meshes),'materials':len({m.name for o in meshes for m in o.data.materials if m}),'face_meshes':[o.name for o in faces],'notes':notes,'rigging':'Named separate rigid parts; no gameplay integration or skeletal animation supplied.'}
 (DOC/(slug+'-report.json')).write_text(json.dumps(report,indent=2)+'\n');print('ENEMY_ASSET_COMPLETE',json.dumps(report))
 return report

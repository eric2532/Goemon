"""Chibi rival revision. Original Goemon body/rig; new face, hair and accents.
Blender --background --python tools/build_ren_rival.py
"""
import bpy, math, hashlib, json, bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'assets/blender/characters/kai.blend'
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=bpy.data.objects['Skin'];original_vertices=[tuple(v.co) for v in body.data.vertices]
original_weights=[[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]
rests=[b.matrix_local.copy() for b in rig.data.bones]
for name in ['Hair_Normal','Hair_Gold']:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)

def material(name,color):
    c=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=1;p.inputs['Specular IOR Level'].default_value=0
    m.diffuse_color=(*c,1);return m
blue=[material('Rival_Cobalt','2634dc'),material('Rival_Blue_Ridge','4059f3'),material('Rival_Blue_Shade','17228d')]
gold=[material('Rival_Surge','f5d233'),material('Rival_Surge_Ridge','fff285'),material('Rival_Surge_Shade','cf981c')]
cloth=material('Rival_Headband_Ivory','fff6db');navy=material('Rival_Indigo','172954');gold_trim=material('Rival_Gold','ffd04b')
face=material('Rival_Expression','ffffff');p=face.node_tree.nodes.get('Principled BSDF')
image=bpy.data.images.load(str(ROOT/'assets/textures/characters/ren_rival/face.png'));image.pack()
n=face.node_tree.nodes.new('ShaderNodeTexImage');n.image=image;face.node_tree.links.new(n.outputs['Color'],p.inputs['Base Color'])
face_id=len(body.data.materials);body.data.materials.append(face)
for poly in body.data.polygons:
    if not all(v<33 for v in poly.vertices):continue
    if poly.center.y>0:
        poly.material_index=face_id
        for li in poly.loop_indices:
            v=body.data.vertices[body.data.loops[li].vertex_index].co
            body.data.uv_layers.active.data[li].uv=(max(0,min(1,.5+(v.x+.022)/1.16)),max(0,min(1,.55+(v.z-1.985)/1.05)))

extras=[]
def mesh_object(name,verts,faces,mats,weights='Head',indices=None,extra=False):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ob.parent=rig
    for m in mats:mesh.materials.append(m)
    uv=mesh.uv_layers.new()
    for poly in mesh.polygons:
        poly.use_smooth=True
        if indices:poly.material_index=indices[poly.index]
    groups={}
    for i,v in enumerate(verts):
        ws=weights(v) if callable(weights) else {weights:1}
        for bone,w in ws.items():
            if w<=0:continue
            if bone not in groups:groups[bone]=ob.vertex_groups.new(name=bone)
            groups[bone].add([i],w,'REPLACE')
    mod=ob.modifiers.new('Reference_Rig','ARMATURE');mod.object=rig
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    if extra:extras.append(ob)
    return ob

def cubic(points,t):
    p=[Vector(v) for v in points]
    return p[0]*(1-t)**3+p[1]*3*(1-t)**2*t+p[2]*3*(1-t)*t*t+p[3]*t**3

def lock(points,width,thickness):
    verts=[];faces=[];indices=[];steps=12;N=8
    for j in range(steps+1):
        t=j/steps;p=cubic(points,t)
        tangent=(cubic(points,min(1,t+.015))-cubic(points,max(0,t-.015))).normalized()
        normal=(p-Vector((0,-.06,2.38))).normalized()
        across=tangent.cross(normal).normalized();normal=across.cross(tangent).normalized()
        if normal.dot(p-Vector((0,-.06,2.38)))<0:normal=-normal
        w=width*(.70+.30*math.sin(math.pi*t))*max(.004,1-t**1.5)
        h=thickness*(.7+.3*math.sin(math.pi*t))*max(.01,1-t**1.2)
        for k in range(N):
            a=k*math.tau/N
            verts.append(tuple(p+across*math.cos(a)*w+normal*math.sin(a)*h))
    for j in range(steps):
        for k in range(N):
            faces.append((j*N+k,j*N+(k+1)%N,(j+1)*N+(k+1)%N,(j+1)*N+k))
            indices.append(1 if k in [1,2] else (2 if k in [5,6] else 0))
    return mesh_object('Sculpted_Lock',verts,faces,blue,indices=indices)

# A compact covered scalp underneath a small number of broad, purposeful locks.
verts=[];faces=[];N=48;R=16
for j in range(R+1):
    for i in range(N):
        a=math.tau*i/N;front=(math.cos(a)+1)/2
        bottom=1.94+.38*front**2
        theta=.01+(1.86-.01)*(1-j/R)
        x=.72*math.sin(theta)*math.sin(a)
        y=.60*math.sin(theta)*math.cos(a)-.12
        z=bottom+(2.93-bottom)*math.cos(theta*.80)
        verts.append((x,y,z))
for j in range(R):
    for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
hair_parts=[mesh_object('Scalp',verts,faces,[blue[0]])]
locks=[
    # Rising asymmetric crown; thick S curves, not a radial ring of cones.
    ([(-.13,-.02,2.73),(-.38,-.10,3.02),(-.36,-.08,3.40),(-.04,-.03,3.49)],.31,.14),
    ([(.09,-.16,2.74),(.24,-.21,3.04),(.55,-.19,3.21),(.78,-.12,3.19)],.32,.14),
    ([(-.27,-.25,2.67),(-.53,-.31,2.96),(-.82,-.22,3.07),(-.94,-.09,3.00)],.27,.13),
    ([(.12,-.42,2.60),(.26,-.64,2.91),(.44,-.73,3.00),(.67,-.68,2.92)],.28,.12),
    ([(-.20,-.39,2.57),(-.48,-.59,2.86),(-.66,-.70,2.89),(-.84,-.66,2.75)],.27,.12),
    # Three chunky foreground locks frame a visible headband and eyebrows.
    ([(-.13,.10,2.94),(-.41,.47,2.98),(-.71,.57,2.60),(-.67,.42,2.23)],.27,.135),
    ([(.12,.14,2.94),(.39,.40,2.88),(.46,.56,2.52),(.32,.51,2.31)],.285,.14),
    ([(-.03,.20,2.96),(-.07,.51,2.84),(.11,.61,2.62),(.03,.54,2.44)],.24,.13),
    # Swept outward side locks, separated from the face and broad at the root.
    ([(-.45,-.04,2.64),(-.71,.14,2.68),(-.92,.20,2.51),(-1.04,.22,2.41)],.27,.12),
    ([(.43,-.03,2.64),(.68,.14,2.73),(.92,.19,2.57),(1.04,.15,2.49)],.26,.12),
    ([(-.52,-.31,2.39),(-.77,-.37,2.40),(-.91,-.30,2.18),(-.91,-.16,2.05)],.22,.11),
    ([(.52,-.30,2.39),(.77,-.34,2.45),(.91,-.24,2.22),(.87,-.10,2.09)],.22,.11),
    ([(0,-.45,2.51),(0,-.73,2.56),(.05,-.90,2.25),(.06,-.82,2.00)],.36,.14),
]
hair_parts.extend(lock(*entry) for entry in locks)
# Visible ivory forehead wrap, with dark blue lower edging.
def headband(z0,z1,mat):
    verts=[];faces=[];N=48
    for z in [z0,z1]:
        for i in range(N+1):
            a=-math.pi+math.tau*i/N
            verts.append((.686*math.sin(a),.542*math.cos(a)-.026,z+.025*math.cos(a)))
    for i in range(N):faces.append((i,i+1,N+2+i,N+1+i))
    return mesh_object('Ivory_Headband',verts,faces,[mat],extra=True)
headband(2.245,2.335,cloth);headband(2.228,2.248,navy)
# Small storm diamond at the center of the headband.
mesh_object('Band_Crest',[(-.044,.527,2.292),(0,.533,2.332),(.044,.527,2.292),(0,.533,2.257)],[(0,1,2,3)],[gold_trim],extra=True)
# Two cloth ties behind the left temple; broad enough to read from gameplay.
for points in [
    [(-.53,-.48,2.29),(-.80,-.65,2.25),(-1.04,-.61,2.02),(-1.05,-.52,1.94)],
    [(-.52,-.49,2.29),(-.63,-.85,2.18),(-.71,-.93,1.95),(-.65,-.92,1.84)],
]:
    verts=[];faces=[]
    for j in range(10):
        t=j/9;p=cubic(points,t);w=.066*(1-.5*t)
        for side in [-1,1]:verts.append(tuple(p+Vector((0,0,side*w))))
    for j in range(9):faces.append((2*j,2*j+1,2*j+3,2*j+2))
    ob=mesh_object('Headband_Tie',verts,faces,[cloth],extra=True)
    solid=ob.modifiers.new('ClothThickness','SOLIDIFY');solid.thickness=.014
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=solid.name)

# An indigo shoulder sash changes the costume's visual identity without
# rebuilding Goemon's well-proportioned hands, sleeves, trousers or shoes.
from mathutils.bvhtree import BVHTree
surface=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
def surface_hit(x,z):return surface.ray_cast(Vector((x,2,z)),Vector((0,-1,0)))
def torso_weights(v):
    location,normal,index,distance=surface_hit(v[0],v[2])
    if index is None:return {'Chest':1}
    ids=list(body.data.polygons[index].vertices)[:3]
    a,b,c=[body.data.vertices[i].co for i in ids]
    d0=b-a;d1=c-a;d2=location-a
    aa=d0.dot(d0);ab=d0.dot(d1);bb=d1.dot(d1);da=d2.dot(d0);db=d2.dot(d1)
    denominator=aa*bb-ab*ab
    if abs(denominator)<1e-10:return {'Chest':1}
    u=(bb*da-ab*db)/denominator;w=(aa*db-ab*da)/denominator
    bary=[max(0,1-u-w),max(0,u),max(0,w)];total=sum(bary);weights={}
    for index,amount in zip(ids,bary):
        for g in body.data.vertices[index].groups:
            name=body.vertex_groups[g.group].name;weights[name]=weights.get(name,0)+g.weight*amount/total
    return weights
verts=[];faces=[]
for j in range(14):
    t=j/13
    x=-.30+.46*t;z=1.40-.41*t
    for d in [-1,1]:
        xx=x+d*.050;zz=z+d*.043
        location,normal,index,distance=surface_hit(xx,zz)
        y=location.y+.035 if location is not None else .36
        verts.append((xx,y,zz))
for j in range(13):faces.append((2*j,2*j+1,2*j+3,2*j+2))
sash=mesh_object('Rival_Sash',verts,faces,[navy],torso_weights,extra=True)
# Thin golden sash seam along one edge.
verts2=[]
for j in range(14):
    a=Vector(verts[j*2+1])
    verts2.extend([tuple(a+Vector((-.010,.003,-.010))),tuple(a+Vector((.005,.003,.005)))])
mesh_object('Sash_Edge',verts2,faces,[gold_trim],torso_weights,extra=True)

assert original_vertices==[tuple(v.co) for v in body.data.vertices]
assert original_weights==[[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]
def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=name;return ob
body=join([body]+extras,'Skin')
hair=join(hair_parts,'Hair_Normal')
gold_hair=hair.copy();gold_hair.data=hair.data.copy();bpy.context.collection.objects.link(gold_hair);gold_hair.name='Hair_Gold'
for i,m in enumerate(gold_hair.data.materials):gold_hair.data.materials[i]=gold[blue.index(m)]
for v in gold_hair.data.vertices:
    t=max(0,v.co.z-2.40);v.co.z+=t*.20;v.co.x*=1-.07*min(1,t)
gold_hair.hide_set(True);gold_hair.hide_render=True
assert all(a==b.matrix_local for a,b in zip(rests,rig.data.bones))
for ob in [body,hair,gold_hair]:
    assert all(abs(sum(g.weight for g in v.groups)-1)<.001 for v in ob.data.vertices),ob.name
scene=bpy.context.scene;scene['asset_id']='characters/ren_rival';scene['art_direction']='Chibi storm rival: original compact body, expressive painted grin, ivory headband and broad swept cobalt locks. Same game lighting as Goemon.'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/characters/ren_rival.blend'))
for o in [body,hair,gold_hair]:o.hide_set(False)
bpy.ops.object.select_all(action='DESELECT')
for o in [body,hair,gold_hair,rig]:o.select_set(True)
for t in rig.animation_data.nla_tracks:t.mute=False
out=ROOT/'assets/models/characters/ren_rival.glb'
bpy.ops.export_scene.gltf(filepath=str(out),use_selection=True,export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_apply=False,export_cameras=False,export_lights=False)
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash
report={'source_sha256':source_hash,'original_unchanged':True,'base_body_vertices_identical':True,'base_body_weights_identical':True,'bones':len(rig.data.bones),'animations':len(rig.animation_data.nla_tracks),'hair_locks':len(locks),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in [body,hair,gold_hair])}
(ROOT/'docs/goemon-skins/rival/validation.json').write_text(json.dumps(report,indent=2)+'\n')
manifest=ROOT/'assets/models/manifest.json';entries=json.loads(manifest.read_text())
entry={'asset':'characters/ren_rival','triangles':report['triangles'],'meshes':3,'surfaces':sum(len(o.data.materials) for o in [body,hair,gold_hair]),'bytes':out.stat().st_size}
entries=[e for e in entries if e['asset']!=entry['asset']]+[entry];manifest.write_text(json.dumps(sorted(entries,key=lambda e:e['asset']),indent=2)+'\n')
print('RIVAL_VALIDATED',json.dumps(report))

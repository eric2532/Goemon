"""Edo anime refinement on a separate playable copy, preserving the V05 rig/body.
Run with Blender --background --python tools/build_edo_anime.py.
"""
import bpy, math, json, hashlib, bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'assets/blender/enemies/musashi/Redesign_v05_Posture/Edo_Posture_Shoulders_v05.blend'
MASTER = ROOT/'assets/blender/enemies/musashi/Final/Musashi_Final.blend'
hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [SOURCE, MASTER]}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rests = {b.name: [list(r) for r in b.matrix_local] for b in rig.data.bones}
body = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('V05 ') and any(s in o.name for s in ['pelvis', 'jacket', 'hand'])]
baseline = {o.name: {'vertices': [tuple(v.co) for v in o.data.vertices], 'weights': [[(g.group,g.weight) for g in v.groups] for v in o.data.vertices]} for o in body}
for o in list(bpy.data.objects):
    if o not in body and o != rig: bpy.data.objects.remove(o, do_unlink=True)
for o in body:
    o.hide_set(False); o.hide_render = False

def material(name, color):
    m = bpy.data.materials.new(name); m.use_nodes = True; m.diffuse_color = (*color,1)
    p = m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value = (*color,1)
    p.inputs['Roughness'].default_value = .94; p.inputs['Specular IOR Level'].default_value = .03
    return m

# Exact existing linear albedo values, also used by the V05 runtime mapper.
colors = {
    'skin': (.82,.46,.25), 'hands': (.64,.32,.17), 'hair': (.012,.021,.023),
    'hair_ridge': (.026,.049,.048), 'hair_shade': (.007,.012,.014),
    'red': (.34,.018,.037), 'red_edge': (.58,.046,.038), 'vest': (.036,.044,.051),
    'orange': (.98,.32,.028), 'wrap': (.64,.59,.43), 'shoe': (.031,.068,.13), 'sole': (.017,.023,.027)
}
mats = {n: material('Edo_'+n,c) for n,c in colors.items()}
def region(name,p):
    if 'pelvis' in name:
        if p.z < .075: return 'sole'
        if p.z < .19: return 'shoe'
        if p.z < .39: return 'wrap'
        return 'red'
    if 'hand' in name: return 'hands'
    if p.z < .81: return 'red_edge'
    if abs(p.x) < .17 and p.y > .055 and p.z > .86:
        return 'red_edge' if abs(p.x) > .145 else 'vest'
    if p.z > 1.31 and abs(p.x) < .135: return 'vest'
    if abs(p.x) > .27 and p.y > .035 and .88 < p.z < 1.12: return 'orange'
    return 'red'
for ob in body:
    ob.data.materials.clear()
    keys = list(mats)
    for key in keys: ob.data.materials.append(mats[key])
    for poly in ob.data.polygons:
        center = sum((ob.matrix_world @ ob.data.vertices[i].co for i in poly.vertices), Vector())/len(poly.vertices)
        poly.material_index = keys.index(region(ob.name,center))
    # Rest positions in UV2 let the runtime draw smooth tailored color edges.
    if not ob.data.uv_layers: ob.data.uv_layers.new(name='UVMap')
    base_uv = ob.data.uv_layers[0]
    rest_uv = ob.data.uv_layers.new(name='GarmentRest')
    for loop in ob.data.loops:
        p = ob.matrix_world @ ob.data.vertices[loop.vertex_index].co
        base_uv.data[loop.index].uv = (p.y,0)
        rest_uv.data[loop.index].uv = (p.x,p.z)

parts = []
def mesh(name, verts, faces, materials, indices=None):
    data = bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    ob = bpy.data.objects.new(name,data); bpy.context.collection.objects.link(ob); ob.parent = rig
    for m in materials: data.materials.append(m)
    for p in data.polygons:
        p.use_smooth = True
        if indices is not None: p.material_index = indices[p.index]
    group = ob.vertex_groups.new(name='Head'); group.add(list(range(len(verts))),1,'REPLACE')
    mod = ob.modifiers.new('Existing_Edo_Rig','ARMATURE'); mod.object = rig
    bm = bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(data); bm.free()
    parts.append(ob); return ob

face = material('Edo_Anime_Face',(1,1,1))
im = bpy.data.images.load(str(ROOT/'assets/textures/characters/edo_anime/face.png')); im.pack()
tex = face.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = im
face.node_tree.links.new(tex.outputs['Color'],face.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

# Broader, gently tapered anime jaw; eyes are painted on the actual curved head.
rings = [(1.285,.075,.070),(1.31,.128,.095),(1.36,.200,.130),(1.43,.242,.154),
         (1.52,.269,.178),(1.62,.275,.187),(1.73,.266,.187),(1.83,.222,.161),(1.90,.115,.085),(1.915,.012,.012)]
N=64; verts=[]; faces=[]
for z,rx,ry in rings:
    for i in range(N):
        a=math.tau*i/N
        verts.append((rx*math.sin(a), -.028+ry*math.cos(a), z))
for j in range(len(rings)-1):
    for i in range(N): faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
faces.extend([tuple(reversed(range(N))),tuple(range((len(rings)-1)*N,len(rings)*N))])
head=mesh('Edo_Anime_Head',verts,faces,[face,mats['skin']])
uv=head.data.uv_layers.new()
for p in head.data.polygons:
    p.material_index=0 if p.center.y>-.03 else 1
    for li in p.loop_indices:
        v=head.data.vertices[head.data.loops[li].vertex_index].co
        uv.data[li].uv=(max(.001,min(.999,.5+v.x/.60)),max(.001,min(.999,.5+(v.z-1.565)/.56)))

def ellipsoid(name,center,scale,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=center)
    ob=bpy.context.object; ob.name=name; ob.scale=scale
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    ob.data.materials.append(mat); ob.parent=rig
    g=ob.vertex_groups.new(name='Head');g.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    mod=ob.modifiers.new('Existing_Edo_Rig','ARMATURE');mod.object=rig
    for p in ob.data.polygons:p.use_smooth=True
    parts.append(ob);return ob
ellipsoid('Edo_Neck',(0,-.035,1.325),(.095,.086,.12),mats['skin'])
for sign in [-1,1]:
    ellipsoid('Edo_Ear',(sign*.271,-.025,1.51),(.053,.041,.082),mats['skin'])
    ellipsoid('Edo_Ear_Inner',(sign*.295,.011,1.51),(.021,.012,.045),mats['hands'])

# The same tall black swept crest, broken into broad sculpted locks.
hair_mats=[mats['hair'],mats['hair_ridge'],mats['hair_shade']]
verts=[];faces=[];N=64;R=20
for j in range(R+1):
    for i in range(N):
        a=math.tau*i/N
        theta=.015+(1.87-.015)*j/R
        x=.292*math.sin(theta)*math.sin(a)
        y=-.064+.215*math.sin(theta)*math.cos(a)
        z=1.78+.258*math.cos(theta)
        # A raised hairline in front keeps both eyes and brows visible.
        z+=.11*max(0,math.cos(a))**3*(j/R)**4
        z-=.19*(1-max(0,math.cos(a)))*(j/R)**4
        verts.append((x,y,z))
for j in range(R):
    for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
mesh('Edo_Hair_Scalp',verts,faces,[mats['hair']])

def cubic(points,t):
    a,b,c,d=[Vector(p) for p in points]
    return a*(1-t)**3+3*b*(1-t)**2*t+3*c*(1-t)*t*t+d*t**3
def lock(name,points,width,depth):
    vs=[];fs=[];indices=[];steps=16;N=10
    for j in range(steps+1):
        t=j/steps;p=cubic(points,t)
        tangent=(cubic(points,min(1,t+.01))-cubic(points,max(0,t-.01))).normalized()
        radial=(p-Vector((0,-.055,1.74))).normalized()
        across=tangent.cross(radial).normalized();normal=across.cross(tangent).normalized()
        if normal.dot(radial)<0:normal=-normal
        w=width*(.75+.25*math.sin(math.pi*t))*max(.003,1-t**1.8)
        h=depth*(.8+.2*math.sin(math.pi*t))*max(.004,1-t**1.35)
        for k in range(N):
            a=math.tau*k/N;vs.append(tuple(p+across*math.cos(a)*w+normal*math.sin(a)*h))
    for j in range(steps):
        for k in range(N):
            fs.append((j*N+k,j*N+(k+1)%N,(j+1)*N+(k+1)%N,(j+1)*N+k))
            indices.append(1 if k in [1,2] else (2 if k in [6,7] else 0))
    fs.append(tuple(reversed(range(N))));indices.append(0)
    mesh(name,vs,fs,hair_mats,indices)

# One dominant swept crest keeps Edo's recognizable tall silhouette.
crest=[(1.76,0,-.08,.264,.21),(1.87,-.008,-.075,.292,.224),
       (1.99,-.027,-.08,.264,.213),(2.10,-.060,-.10,.205,.18),
       (2.20,-.106,-.145,.131,.13),(2.28,-.14,-.19,.062,.067),
       (2.335,-.178,-.205,.001,.001)]
vs=[];fs=[];ids=[];N=64
for z,cx,cy,rx,ry in crest:
    for i in range(N):
        a=math.tau*i/N
        ridge=1+.045*math.cos(5*a)
        vs.append((cx+rx*math.sin(a)*ridge,cy+ry*math.cos(a)*ridge,z))
for j in range(len(crest)-1):
    for i in range(N):
        fs.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
        ids.append(1 if i in range(4,9) or i in range(39,42) else 0)
mesh('Edo_Hair_Tall_Swept_Crest',vs,fs,hair_mats,ids)
locks=[
    ('Left crest accent',[(-.21,-.13,1.87),(-.31,-.17,1.97),(-.28,-.29,2.09),(-.20,-.34,2.15)],.12,.059),
    ('Right crest accent',[(.20,-.12,1.87),(.32,-.18,1.95),(.31,-.31,2.07),(.24,-.35,2.11)],.12,.059),
    ('Signature swept fringe',[(-.085,.065,2.035),(-.19,.225,1.985),(-.26,.233,1.745),(-.215,.182,1.525)],.13,.061),
    ('Short forehead lock',[(.005,.075,2.02),(.105,.225,1.97),(.105,.239,1.86),(.03,.211,1.76)],.124,.061),
    ('Right temple lock',[(.17,.024,1.92),(.285,.106,1.87),(.298,.108,1.69),(.278,.065,1.535)],.115,.058),
    ('Left swept side',[(-.22,-.10,1.85),(-.35,-.16,1.88),(-.36,-.23,1.76),(-.365,-.25,1.69)],.12,.065),
    ('Right swept side',[(.23,-.10,1.84),(.34,-.15,1.87),(.35,-.24,1.75),(.35,-.28,1.68)],.12,.060),
    ('Nape',[(0,-.22,1.81),(.01,-.33,1.77),(.05,-.32,1.51),(.05,-.265,1.43)],.20,.067)
]
for entry in locks:lock('Edo_Hair_'+entry[0],*entry[1:])

# Native source, standalone export, and explicit audit of the preserved gameplay rig.
assert rests=={b.name:[list(r) for r in b.matrix_local] for b in rig.data.bones}
for ob in body:
    assert baseline[ob.name]['vertices']==[tuple(v.co) for v in ob.data.vertices]
    assert baseline[ob.name]['weights']==[[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices]
for ob in body+parts:
    assert all(abs(sum(g.weight for g in v.groups)-1)<.002 for v in ob.data.vertices),ob.name
bpy.context.scene['art_direction']='Edo anime refinement: expressive amber eyes, swept black crest, original crimson/orange costume.'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/characters/edo_anime.blend'))
bpy.ops.object.select_all(action='DESELECT')
for ob in body+parts+[rig]:ob.hide_set(False);ob.select_set(True)
bpy.context.view_layer.objects.active=rig
out=ROOT/'assets/models/characters/edo_anime.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_skins=True,export_animations=False,export_yup=True,export_cameras=False,export_lights=False)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
report={'protected_sources_sha256':hashes,'sources_unchanged':True,'body_vertices_unchanged':True,'body_weights_unchanged':True,'bone_rest_unchanged':True,'bones':len(rests),'hair_locks':len(locks),'triangles':sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in body+parts),'palette_linear':colors}
(ROOT/'docs/edo-anime/validation.json').write_text(json.dumps(report,indent=2)+'\n')
manifest=ROOT/'assets/models/manifest.json'
entries=json.loads(manifest.read_text())
entry={'asset':'characters/edo_anime','triangles':report['triangles'],'meshes':len(body+parts),'surfaces':sum(len(set(p.material_index for p in ob.data.polygons)) for ob in body+parts),'bytes':out.stat().st_size}
entries=[e for e in entries if e['asset']!=entry['asset']]+[entry]
manifest.write_text(json.dumps(sorted(entries,key=lambda e:e['asset']),indent=2)+'\n')
print('EDO_ANIME_VALIDATED',json.dumps(report))

"""Ren v2: anime silhouette on the compatible Goemon animation rig.
Blender --background --python tools/build_ren_anime.py
The original and the first attempt remain independent source files.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/blender/characters/kai.blend'
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
bone_matrices=[b.matrix_local.copy() for b in rig.data.bones]
for o in list(bpy.data.objects):
    if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
body_parts=[]
def mat(name,hexcolor):
    c=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
    c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    m=bpy.data.materials.new('Anime_'+name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1)
    p.inputs['Roughness'].default_value=1;p.inputs['Specular IOR Level'].default_value=0
    m.diffuse_color=(*c,1);return m
skin=mat('Skin','f6cfad');earinner=mat('Ear','dba386');red=mat('Crimson','c93639');redlight=mat('RedFold','e14b46');reddark=mat('RedShade','902b37')
navy=mat('Indigo','233957');gold=mat('Gold','e9b958');white=mat('Ivory','fff2db');wrapshade=mat('WrapSeam','dfd9cd');sole=mat('SandalSole','ad8255')
haircols=[mat('HairBlue','2359b6'),mat('HairLight','3474ce'),mat('HairShade','18397d')]
goldcols=[mat('SurgeGold','f8cd47'),mat('SurgeLight','fff18c'),mat('SurgeShade','d29424')]
face=mat('Face','ffffff');im=bpy.data.images.load(str(ROOT/'assets/textures/characters/ren_anime/face.png'));im.pack()
p=face.node_tree.nodes.get('Principled BSDF');n=face.node_tree.nodes.new('ShaderNodeTexImage');n.image=im
face.node_tree.links.new(n.outputs['Color'],p.inputs['Base Color'])

def objmesh(name,verts,faces,mats,weights=None,uvs=None,indices=None,body=True,smooth=True):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob)
    for m in mats:mesh.materials.append(m)
    uv=mesh.uv_layers.new()
    for p in mesh.polygons:
        p.use_smooth=smooth
        if indices:p.material_index=indices[p.index]
        for li in p.loop_indices:
            vi=mesh.loops[li].vertex_index
            uv.data[li].uv=uvs[vi] if uvs else (0,0)
    groups={}
    for i,v in enumerate(verts):
        ws=weights(v) if callable(weights) else {weights or 'Head':1}
        for bone,w in ws.items():
            if w<=0:continue
            if bone not in groups:groups[bone]=ob.vertex_groups.new(name=bone)
            groups[bone].add([i],w,'REPLACE')
    ob.parent=rig;mod=ob.modifiers.new('Reference_Rig','ARMATURE');mod.object=rig
    if body:body_parts.append(ob)
    return ob

def torso_weights(p):
    z=p[2]
    nodes=[(.966,'Pelvis'),(1.04,'Spine'),(1.19,'SpineMid'),(1.34,'Chest'),(1.449,'Neck')]
    if z<=nodes[0][0]:return {'Pelvis':1}
    for (a,an),(b,bn) in zip(nodes,nodes[1:]):
        if z<=b:
            t=(z-a)/(b-a);return {an:1-t,bn:t}
    return {'Neck':1}

def arm_weights(p):
    x=abs(p[0]);s='L' if p[0]<0 else 'R'
    if x<.50:
        t=max(0,min(1,(x-.30)/.20));return {'Chest':1-t,'Arm_'+s:t}
    if x<.72:return {'Arm_'+s:1}
    if x<.87:
        t=(x-.72)/.15;return {'Arm_'+s:1-t,'Forearm_'+s:t}
    if x<1.03:return {'Forearm_'+s:1}
    if x<1.13:
        t=(x-1.03)/.1;return {'Forearm_'+s:1-t,'Hand_'+s:t}
    return {'Hand_'+s:1}

def leg_weights(p):
    z=p[2];s='L' if p[0]<0 else 'R'
    if z>.60:return {'Leg_'+s:1}
    if z>.39:
        t=(z-.39)/.21;return {'Leg_'+s:t,'Shin_'+s:1-t}
    if z>.28:return {'Shin_'+s:1}
    if z>.18:
        t=(z-.18)/.10;return {'Shin_'+s:t,'Foot_'+s:1-t}
    return {'Foot_'+s:1}

def ellipsoid(name,center,radii,material,weights='Head',seg=24,rings=16):
    verts=[];faces=[]
    for j in range(rings+1):
        t=.001+(math.pi-.002)*j/rings
        for i in range(seg):
            a=math.tau*i/seg
            verts.append((center[0]+radii[0]*math.sin(t)*math.sin(a),center[1]+radii[1]*math.sin(t)*math.cos(a),center[2]+radii[2]*math.cos(t)))
    for j in range(rings):
        for i in range(seg):faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
    return objmesh(name,verts,faces,[material],weights)

def loft(name,rings,mats,weights,segments=32,folds=0):
    verts=[];faces=[];indices=[]
    for cx,cy,z,rx,ry in rings:
        for i in range(segments):
            a=math.tau*i/segments;wave=1+folds*math.cos(a*6)
            verts.append((cx+rx*math.sin(a)*wave,cy+ry*math.cos(a)*wave,z))
    for j in range(len(rings)-1):
        for i in range(segments):
            faces.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
            indices.append(1 if len(mats)>1 and i%8 in [2,3] else 0)
    faces.extend([tuple(range(segments-1,-1,-1)),tuple((len(rings)-1)*segments+i for i in range(segments))]);indices.extend([0,0])
    return objmesh(name,verts,faces,mats,weights,indices=indices)

def ribbon(name,points,width,material,weights,depth=.006):
    verts=[];faces=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        axis=Vector((tangent.z,0,-tangent.x)).normalized()*width/2
        for d in [-1,1]:verts.append(tuple(Vector(p)+axis*d+Vector((0,depth,0))))
    for i in range(len(points)-1):faces.append((2*i,2*i+1,2*i+3,2*i+2))
    ob=objmesh(name,verts,faces,[material],weights)
    # Thin modeled cloth edges are visible from both sides in glTF.
    material.surface_render_method='DITHERED'
    material.use_backface_culling=False
    return ob

# Smooth tapered jaw; the UV face is mapped only to the forward hemisphere.
verts=[];faces=[];uvs=[];indices=[]
rows=[(1.50,.075,.085),(1.54,.16,.16),(1.62,.25,.23),(1.72,.32,.265),(1.84,.345,.275),(1.95,.34,.28),(2.08,.31,.255),(2.17,.245,.21),(2.23,.10,.09)]
seg=64
for z,rx,ry in rows:
    for i in range(seg):
        a=-math.pi+math.tau*i/seg;x=rx*math.sin(a);y=ry*math.cos(a)
        # Slightly flatter front for readable eyes, rounded temples and cranium.
        if y>0:y=ry*(.45+.55*math.cos(a))
        verts.append((x,y,z));uvs.append((.5+x/.70,(z-1.49)/.75))
for j in range(len(rows)-1):
    for i in range(seg):
        faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
        a=-math.pi+math.tau*(i+.5)/seg;indices.append(0 if abs(a)<math.pi/2 else 1)
objmesh('Anime_Head',verts,faces,[face,skin],'Head',uvs,indices)
for s in [-1,1]:
    ellipsoid('Ear',(s*.342,.005,1.81),(.073,.055,.11),skin)
    ellipsoid('EarFold',(s*.378,.048,1.813),(.027,.015,.058),earinner)
ellipsoid('Neck',(0,-.025,1.47),(.105,.10,.19),skin,'Neck')
loft('WhiteCrossShirt',[(0,0,.87,.265,.16),(0,0,1.03,.285,.17),(0,0,1.18,.33,.185),(0,0,1.32,.395,.19),(0,0,1.41,.29,.155),(0,0,1.47,.11,.09)],[white],torso_weights)
# Red vest, cut open at the front, with a shaped V collar and gold edging.
verts=[];faces=[]
levels=[(.88,.30,.18,.18),(.99,.31,.19,.24),(1.15,.345,.20,.38),(1.30,.405,.205,.52),(1.40,.33,.18,.70),(1.445,.20,.135,.85)]
N=48
for z,rx,ry,gap in levels:
    for i in range(N+1):
        a=gap+(math.tau-2*gap)*i/N
        verts.append((rx*math.sin(a),ry*math.cos(a),z))
for j in range(len(levels)-1):
    for i in range(N):faces.append((j*(N+1)+i,j*(N+1)+i+1,(j+1)*(N+1)+i+1,(j+1)*(N+1)+i))
objmesh('CrimsonOpenVest',verts,faces,[red],torso_weights)
for s in [-1,1]:
    ribbon('GoldLapel',[(s*rx*math.sin(gap),ry*math.cos(gap)+.005,z) for z,rx,ry,gap in levels],.025,gold,torso_weights)
# Crossed white collar, edged in navy.
ribbon('InnerCollar',[(.12,.095,1.47),(.10,.18,1.38),(-.03,.204,1.20),(-.15,.18,1.06)],.045,navy,torso_weights)
ribbon('FoldedCollar',[(.07,.104,1.47),(.05,.188,1.38),(-.08,.208,1.20),(-.20,.17,1.06)],.070,white,torso_weights)
ribbon('LeftCollar',[(-.12,.097,1.47),(-.09,.185,1.37),(.02,.212,1.23)],.034,navy,torso_weights)
# Waist sash and longer layered jacket hem.
loft('TrouserYoke',[(0,0,.745,.19,.135),(0,0,.82,.285,.17),(0,0,.95,.308,.187)],[red], 'Pelvis')
loft('GoldenSash',[(0,0,.935,.31,.20),(0,0,.97,.323,.211),(0,0,1.025,.32,.205),(0,0,1.065,.305,.198)],[gold],'Pelvis')
for s in [-1,1]:
    ribbon('JacketTail',[(s*.22,.195,.96),(s*.25,.19,.86),(s*.29,.175,.75)],.21,red,'Pelvis')
    ribbon('TailGoldHem',[(s*.20,.202,.735),(s*.29,.196,.73),(s*.38,.18,.748)],.016,gold,'Pelvis')
ellipsoid('SashKnot',(.205,.226,.996),(.062,.04,.053),gold,'Pelvis',16,10)
for s in [-1,1]:
    ribbon('SashLoop',[(.205,.245,1.0),(.205+s*.12,.245,1.055),(.205+s*.14,.242,.98),(.205,.245,1.0)],.033,gold,'Pelvis')
ribbon('GoldRibbonTail',[(.2,.246,.98),(.20,.26,.86),(.28,.265,.70),(.31,.24,.60)],.075,gold,'Pelvis')
# Slim bare arms with fitted indigo wraps and rounded hands.
for s in [-1,1]:
    verts=[];faces=[]
    arm_sections=[(.30,.09),(.35,.105),(.405,.115),(.49,.105),(.60,.095),(.72,.081),(.80,.078),(.89,.088),(.98,.078),(1.10,.067),(1.15,.065)]
    for x,r in arm_sections:
        for j in range(24):
            a=math.tau*j/24;verts.append((s*x,r*math.sin(a),1.30+r*math.cos(a)))
    for j in range(len(arm_sections)-1):
        for k in range(24):faces.append((j*24+k,j*24+(k+1)%24,(j+1)*24+(k+1)%24,(j+1)*24+k))
    objmesh('ContinuousArm',verts,faces,[skin],arm_weights)
    ellipsoid('Shoulder',(s*.395,0,1.30),(.125,.11,.11),skin,arm_weights)
    ellipsoid('WristWrap',(s*1.055,0,1.30),(.115,.092,.105),navy,arm_weights)
    for j in range(4):
        # Narrow fabric binding seams around the wrist.
        x=s*(.98+j*.044)
        verts=[];faces=[]
        for dx in [-.004,.004]:
            for k in range(24):
                a=k*math.tau/24;verts.append((x+dx,.094*math.sin(a),1.30+.107*math.cos(a)))
        for k in range(24):faces.append((k,(k+1)%24,24+(k+1)%24,24+k))
        objmesh('WrapSeam',verts,faces,[wrapshade],arm_weights)
    ellipsoid('Palm',(s*1.226,.01,1.30),(.127,.075,.09),skin,arm_weights)
    ellipsoid('Thumb',(s*1.20,.05,1.235),(.070,.050,.049),skin,arm_weights,16,10)
    for j in range(3):
        ellipsoid('Finger',(s*1.335,-.04+j*.037,1.30),(.035,.024,.061),skin,arm_weights,12,8)
    x=s*.29
    loft('CrimsonTrousers',[(x,0,.36,.115,.10),(x,0,.46,.17,.155),(x,0,.62,.196,.17),(s*.27,0,.80,.18,.17),(s*.245,0,.95,.16,.15)],[red,redlight],leg_weights,32,.055)
    loft('ShinWrap',[(s*.315,.005,.17,.100,.092),(s*.31,0,.27,.11,.10),(s*.30,0,.37,.12,.105),(s*.30,0,.42,.116,.10)],[white],leg_weights)
    for j in range(5):
        z=.19+j*.046
        loft('ShinBinding',[(s*.31,0,z,.113,.105),(s*.31,0,z+.008,.113,.105)],[wrapshade],leg_weights,24)
    ellipsoid('SandalSole',(s*.315,.115,.045),(.14,.242,.040),sole,'Foot_'+('L' if s<0 else 'R'))
    ellipsoid('WhiteTabi',(s*.315,.10,.095),(.126,.205,.078),white,'Foot_'+('L' if s<0 else 'R'))
    ribbon('SandalStrap',[(s*.315-.115,.13,.13),(s*.315,.21,.187),(s*.315+.115,.13,.13)],.055,navy,'Foot_'+('L' if s<0 else 'R'))

# Solid curved leaf-shaped hair locks: broad roots, rounded ridges, tapered tips.
def bezier(points,t):
    p=[Vector(v) for v in points];return (1-t)**3*p[0]+3*(1-t)**2*t*p[1]+3*(1-t)*t*t*p[2]+t**3*p[3]

def hair_lock(points,width,thickness,materials):
    verts=[];faces=[];indices=[];steps=10;sides=8
    center=Vector((0,0,1.96))
    for j in range(steps+1):
        t=j/steps;p=bezier(points,t)
        tangent=(bezier(points,min(1,t+.01))-bezier(points,max(0,t-.01))).normalized()
        normal=(p-center).normalized();axis=tangent.cross(normal).normalized();normal=axis.cross(tangent).normalized()
        if normal.dot(p-center)<0:normal=-normal
        w=width*(.52+.48*math.sin(math.pi*t*.8))*max(.007,(1-t)**.70)
        d=thickness*max(.009,(1-t)**.68)
        for k in range(sides):
            a=k*math.tau/sides
            verts.append(tuple(p+axis*math.cos(a)*w+normal*math.sin(a)*d))
    for j in range(steps):
        for k in range(sides):
            faces.append((j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k));indices.append(1 if k in [1,2] else (2 if k in [5,6] else 0))
    return objmesh('HairLock',verts,faces,materials,'Head',indices=indices,body=False)

locks=[
    # Crown to bangs, with visible separations and forehead gaps.
    ([(-.08,.02,2.29),(-.16,.30,2.31),(.01,.37,2.08),(.15,.33,1.93)],.12,.048),
    ([(-.11,.02,2.30),(-.29,.19,2.30),(-.31,.35,2.08),(-.30,.32,1.91)],.11,.046),
    ([(-.07,.04,2.31),(.13,.25,2.26),(.25,.35,2.14),(.27,.29,1.97)],.12,.045),
    ([(-.14,-.02,2.30),(-.36,.13,2.24),(-.44,.24,2.05),(-.43,.15,1.86)],.105,.05),
    ([(.02,-.02,2.32),(.28,.10,2.28),(.41,.20,2.07),(.41,.14,1.86)],.11,.05),
    ([(-.21,.12,2.20),(-.39,.21,2.06),(-.40,.20,1.82),(-.33,.18,1.72)],.073,.030),
    ([(.25,.08,2.19),(.41,.18,2.02),(.37,.20,1.84),(.36,.13,1.72)],.073,.030),
    # Signature upward curl and swept crown.
    ([(-.13,-.04,2.27),(-.34,-.03,2.56),(-.06,-.04,2.62),(.09,-.03,2.53)],.056,.031),
    ([(.02,-.10,2.28),(.24,-.10,2.46),(.35,-.07,2.48),(.43,-.10,2.46)],.10,.045),
    ([(-.04,-.17,2.27),(-.29,-.26,2.43),(-.45,-.23,2.43),(-.48,-.23,2.40)],.13,.052),
]
# Layer the silhouette around the temples and back, not radial pyramids.
for j in range(12):
    a=math.pi*.48+j*math.pi*1.04/11
    dx,dy=math.sin(a),math.cos(a)
    root=(dx*.22,dy*.19,2.20+(j%3)*.022)
    p1=(dx*.40,dy*.30,2.24)
    p2=(dx*.51,dy*.40,2.11-(j%2)*.09)
    tip=(dx*(.55 if j%2 else .49),dy*.45,2.03-(j%3)*.08)
    locks.append(([root,p1,p2,tip],.11,.041))
for j in range(9):
    a=math.pi*.49+j*math.pi*1.02/8;dx,dy=math.sin(a),math.cos(a)
    locks.append(([(dx*.28,dy*.22,2.02),(dx*.42,dy*.32,1.93),(dx*.42,dy*.36,1.78),(dx*.38,dy*.35,1.69+(j%2)*.035)],.091,.035))
# Hair shell is hidden beneath layered locks, stopping above the eyebrows.
def hair_cap(materials):
    verts=[];faces=[];seg=64;rings=18
    profile=rows+[(2.25,.025,.025)]
    def radii(z):
        for a,b in zip(profile,profile[1:]):
            if a[0]<=z<=b[0]:
                t=(z-a[0])/(b[0]-a[0]);return (a[1]*(1-t)+b[1]*t+.018,a[2]*(1-t)+b[2]*t+.020)
        return (.025,.025)
    for j in range(rings+1):
        for i in range(seg):
            a=math.tau*i/seg;front=(1+math.cos(a))/2
            bottom=1.565+.46*front**1.5
            z=bottom+(2.25-bottom)*j/rings;rx,ry=radii(z)
            x=rx*math.sin(a);y=ry*math.cos(a)
            if y>0:y=ry*(.45+.55*math.cos(a))
            verts.append((x,y,z))
    for j in range(rings):
        for i in range(seg):faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
    return objmesh('HairCap',verts,faces,[materials[0]],'Head',body=False)

def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;o.data.name=name+'_Anime';return o
body=join(body_parts,'Skin')
hair_objects=[hair_cap(haircols)]+[hair_lock(*lock,haircols) for lock in locks]
hair=join(hair_objects,'Hair_Normal')
goldhair=hair.copy();goldhair.data=hair.data.copy();bpy.context.collection.objects.link(goldhair);goldhair.name='Hair_Gold'
for i,m in enumerate(goldhair.data.materials):goldhair.data.materials[i]=goldcols[haircols.index(m)]
# Transformation adds lift and directional sweep without changing the face.
for v in goldhair.data.vertices:
    h=max(0,(v.co.z-1.9)/.7);v.co.z+=.15*h;v.co.x+=.06*h
# A smaller tapered head gives the model anime proportions; the whole visual
# is presented at 1.3x in Godot, retaining roughly the original world height.
for ob in [body,hair,goldhair]:
    head_group=ob.vertex_groups.get('Head')
    if head_group:
        for v in ob.data.vertices:
            if any(g.group==head_group.index and g.weight>.99 for g in v.groups):
                v.co=Vector((0,0,1.54))+(v.co-Vector((0,0,1.54)))*.75
# Correct outward winding independently of loft construction direction.
import bmesh
for ob in [body,hair,goldhair]:
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(ob.data);bm.free()
    ob['skin_revision']='anime_v2'
    assert all(abs(sum(g.weight for g in v.groups)-1)<.001 for v in ob.data.vertices)
goldhair.hide_set(True);goldhair.hide_render=True
assert all(a==b.matrix_local for a,b in zip(bone_matrices,rig.data.bones))
scene=bpy.context.scene;scene['asset_id']='characters/ren_anime';scene['art_direction']='Anime Ren: tapered face, painted eyes, layered curved locks, open crimson vest, white crossover shirt and gold sash. Compatible rig; new geometry and proportions.'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/characters/ren_anime.blend'))
for ob in [body,hair,goldhair]:ob.hide_set(False)
bpy.ops.object.select_all(action='DESELECT')
for ob in [body,hair,goldhair,rig]:ob.select_set(True)
for track in rig.animation_data.nla_tracks:track.mute=False
out=ROOT/'assets/models/characters/ren_anime.glb'
bpy.ops.export_scene.gltf(filepath=str(out),use_selection=True,export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_apply=False,export_cameras=False,export_lights=False)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
report={'source_sha256':source_hash,'original_unchanged':True,'rig_rest_matrices_identical':True,'bones':len(rig.data.bones),'animations':len(rig.animation_data.nla_tracks),'new_geometry':True,'meshes':{ob.name:{'vertices':len(ob.data.vertices),'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons)} for ob in [body,hair,goldhair]},'hair_locks':len(locks)}
(ROOT/'docs/goemon-skins/anime/validation.json').write_text(json.dumps(report,indent=2)+'\n')
manifest=ROOT/'assets/models/manifest.json';entries=json.loads(manifest.read_text())
entry={'asset':'characters/ren_anime','triangles':sum(v['triangles'] for v in report['meshes'].values()),'meshes':3,'surfaces':sum(len(ob.data.materials) for ob in [body,hair,goldhair]),'bytes':out.stat().st_size}
entries=[e for e in entries if e['asset']!=entry['asset']]+[entry];manifest.write_text(json.dumps(sorted(entries,key=lambda e:e['asset']),indent=2)+'\n')
print('ANIME_SKIN_VALIDATED',json.dumps(report))

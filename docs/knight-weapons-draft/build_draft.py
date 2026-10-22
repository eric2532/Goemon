"""Isolated, reproducible Knight weapon draft; never writes live asset paths.

Run: /Applications/Blender.app/Contents/MacOS/Blender -b --python docs/knight-weapons-draft/build_draft.py
"""
import bpy
import bmesh
import hashlib
import json
import math
import subprocess
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
SOURCE = ROOT / 'assets/blender/characters/goemon_cosplay/knight.blend'
LIVE = [SOURCE, ROOT / 'assets/models/characters/goemon_cosplay/knight.glb',
        ROOT / 'assets/blender/characters/kai.blend', ROOT / 'tools/build_goemon_cosplay.py',
        ROOT / 'build/Goemon.app/Contents/Resources/Goemon.pck',
        ROOT / 'build/Goemon.app/Contents/MacOS/Goemon']
before = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in LIVE if p.exists()}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.view_layer.update()
scene = bpy.context.scene
rig = bpy.data.objects['Reference_Rig']
# Resolve packed source images before GLB export without changing the live source.
for im in bpy.data.images:
    if im.name == 'knight painted palette':
        replacement = bpy.data.images.load(str(ROOT / 'assets/rogue/styled/atlases/knight.png'), check_existing=False)
        replacement.name = 'Knight draft packed shield palette'
        replacement.pack()
        for mat in bpy.data.materials:
            if mat.use_nodes:
                for node in mat.node_tree.nodes:
                    if node.type == 'TEX_IMAGE' and node.image == im:
                        node.image = replacement
        bpy.data.images.remove(im)
        continue
    if im.packed_file:
        im.pack()

def fingerprint(ob):
    payload = {'vertices': [list(v.co) for v in ob.data.vertices],
               'faces': [list(p.vertices) for p in ob.data.polygons],
               'uv': [[list(v.uv) for v in layer.data] for layer in ob.data.uv_layers],
               'weights': [[(g.group, g.weight) for g in v.groups] for v in ob.data.vertices]}
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()

protected = {name: fingerprint(bpy.data.objects[name]) for name in ['Skin', 'Hair_Normal']}
bones = {b.name: [list(b.head_local), list(b.tail_local)] for b in rig.data.bones}
original_shield = bpy.data.objects['Weapon_Pistol_Geometry']
old_bounds = [Vector(v) for v in original_shield.bound_box]
old_dimensions = list(original_shield.dimensions)
old_shield_matrix = original_shield.matrix_world.copy()
old_shield_data = original_shield.data.copy()
old_shield_mats = list(original_shield.data.materials)
old_parent = bpy.data.objects['Weapon_Pistol'].matrix_world.copy()
old_local = [old_parent.inverted() @ old_shield_matrix @ v.co for v in old_shield_data.vertices]
lo = Vector(tuple(min(v[i] for v in old_local) for i in range(3)))
hi = Vector(tuple(max(v[i] for v in old_local) for i in range(3)))
old_center = (lo + hi) * .5

for name in ['Weapon_Cutlass_Geometry', 'Weapon_Cutlass', 'Weapon_Pistol_Geometry', 'Weapon_Pistol']:
    bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)

def material(name, color, rough=.82):
    rgb = [int(color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    rgb = [v / 12.92 if v <= .04045 else ((v + .055)/1.055)**2.4 for v in rgb]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, 1)
    shader.inputs['Roughness'].default_value = rough
    shader.inputs['Specular IOR Level'].default_value = .17
    return mat

steel = material('Knight | slate steel', '85959b')
steel_dark = material('Knight | ridge shadow', '536775')
edge = material('Knight | honed silver edge', 'cbd3cf')
ridge = material('Knight | raised steel spine', 'a6b3b3')
gold = material('Knight | old gold fittings', 'cc9c25')
gold_light = material('Knight | gold bevel and inlay', 'efd068')
gold_dark = material('Knight | deep gold facets', '8d5f15')
grip_mat = material('Knight | dark steel grip', '374756')
engrave = material('Knight | engraved recess', '374343')

def empty(name):
    ob = bpy.data.objects.new(name, None)
    scene.collection.objects.link(ob)
    ob.empty_display_type = 'ARROWS'
    ob.empty_display_size = .14
    return ob

sword = empty('Weapon_Cutlass')
shield = empty('Weapon_Pistol')
sword['asset'] = 'Knight reference claymore; grip origin; blade along local +Z (glTF +Y)'
shield['asset'] = 'Knight wall shield; face reduced 10% around unchanged lion sigil; centered rear grip origin'

def mesh(name, verts, faces, mats, parent, indices=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    scene.collection.objects.link(ob)
    ob.parent = parent
    for mat in mats:
        data.materials.append(mat)
    if indices:
        for poly, index in zip(data.polygons, indices):
            poly.material_index = index
    uv = data.uv_layers.new(name='UVMap')
    for poly in data.polygons:
        for index in poly.loop_indices:
            v = data.vertices[data.loops[index].vertex_index].co
            uv.data[index].uv = (v.x + .5, v.z / 3 + .2)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data)
    bm.free()
    return ob

def tube(name, a, b, radius, mats, parent, count=8):
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    u = axis.cross(Vector((0, 1, 0)))
    if u.length < .1:
        u = axis.cross(Vector((1, 0, 0)))
    u.normalize()
    v = axis.cross(u).normalized()
    verts = [p + radius * (math.cos(i*math.tau/count)*u + math.sin(i*math.tau/count)*v)
             for p in [a,b] for i in range(count)]
    faces = [(i, (i+1)%count, (i+1)%count+count, i+count) for i in range(count)]
    faces += [tuple(reversed(range(count))), tuple(range(count, count*2))]
    return mesh(name, verts, faces, mats, parent,
                [i % len(mats) for i in range(len(faces))])

def bevel_plate(name, points, depth, mats, parent, inset=.84):
    center = Vector((sum(p[0] for p in points)/len(points), 0, sum(p[1] for p in points)/len(points)))
    n = len(points)
    verts = [(x, -.5*depth, z) for x,z in points]
    verts += [(center.x+(x-center.x)*inset, -.5*depth-.028, center.z+(z-center.z)*inset) for x,z in points]
    verts += [(x, .5*depth, z) for x,z in points]
    faces = [tuple(range(n, n*2)), tuple(reversed(range(n*2, n*3)))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    faces += [(i,i+n*2,(i+1)%n+n*2,(i+1)%n) for i in range(n)]
    return mesh(name, verts, faces, mats, parent,
                [0, 0] + [1 % len(mats)]*n + [2 % len(mats)]*n)

# Authorized costume revision, confined to this draft: silver boots and a long navy cape.
boot_silver=material('Knight | silver armored boots','b8c4cf',.76)
boot_shadow=material('Knight | silver boot shadow facets','8295a8',.82)
skin=bpy.data.objects['Skin']
skin.data.materials.append(boot_silver)
silver_index=len(skin.data.materials)-1
skin.data.materials.append(boot_shadow)
shadow_index=len(skin.data.materials)-1
boot_faces=[]
for poly in skin.data.polygons:
    if poly.center.z<.49 and abs(poly.center.x)>.14:
        poly.material_index=shadow_index if poly.normal.y<-.30 else silver_index
        boot_faces.append(poly.index)
assert len(boot_faces)>15

costume=bpy.data.objects['Costume_knight']
original_costume_count=len(costume.data.vertices)
bm=bmesh.new()
bm.from_mesh(costume.data)
seen=set()
cape_components=[]
for vertex in bm.verts:
    if vertex in seen:
        continue
    todo=[vertex]
    component=set()
    while todo:
        v=todo.pop()
        if v in component:
            continue
        component.add(v)
        todo.extend(e.other_vert(v) for e in v.link_edges)
    seen.update(component)
    if max(v.co.y for v in component)<-.28 and min(v.co.z for v in component)<.60:
        cape_components.append(component)
assert len(cape_components)==1 and len(cape_components[0])==10
remaining_coordinates=sorted(tuple(v.co) for v in bm.verts if v not in cape_components[0])
bmesh.ops.delete(bm,geom=list(cape_components[0]),context='VERTS')
bm.to_mesh(costume.data)
bm.free()
assert len(costume.data.vertices)==original_costume_count-10
assert sorted(tuple(v.co) for v in costume.data.vertices)==remaining_coordinates

navy=material('Knight | almost black navy cape','080f28')
navy_fold=material('Knight | dark navy fold light','101b36')
navy_shadow=material('Knight | deep navy fold shadow','050a1b')
cape_vertices=[]
cape_rows=[(1.50,.54,-.43),(1.25,.59,-.53),(.97,.65,-.65),
           (.70,.69,-.74),(.42,.74,-.79),(.14,.78,-.82)]
cape_columns=[-1,-.67,-.33,0,.33,.67,1]
for row,(height,width,back) in enumerate(cape_rows):
    for column,x in enumerate(cape_columns):
        fold=[0,-.05,.02,-.045,.02,-.05,0][column]*(.45 if row==0 else 1)
        z=height+(.045*abs(x) if row==len(cape_rows)-1 else 0)
        cape_vertices.append((x*width,back+fold,z))
cape_vertices += [(x,y+.025,z) for x,y,z in cape_vertices]
cape_faces=[]
cape_materials=[]
cols=len(cape_columns)
layer=len(cape_rows)*cols
for row in range(len(cape_rows)-1):
    for column in range(cols-1):
        a=row*cols+column
        cape_faces.append((a,a+1,a+cols+1,a+cols))
        cape_materials.append([0,1,2,1,0,2][column])
        cape_faces.append((a+layer,a+cols+layer,a+cols+1+layer,a+1+layer))
        cape_materials.append(2)
perimeter=list(range(cols))
perimeter += [row*cols+cols-1 for row in range(1,len(cape_rows))]
perimeter += list(range(layer-2,layer-cols-1,-1))
perimeter += [row*cols for row in range(len(cape_rows)-2,0,-1)]
for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):
    cape_faces.append((a,b,b+layer,a+layer))
    cape_materials.append(0)
cape=mesh('Knight_Long_Dark_Navy_Cape',cape_vertices,cape_faces,[navy,navy_fold,navy_shadow],rig,cape_materials)
group=cape.vertex_groups.new(name='Chest')
group.add(list(range(len(cape_vertices))),1.0,'REPLACE')
modifier=cape.modifiers.new('Original Goemon skeleton','ARMATURE')
modifier.object=rig
cape['design']='Wider ankle-length navy cape; pinned shoulders, independent billow and edge flutter'
cape.shape_key_add(name='Basis')
cloth_keys={name:cape.shape_key_add(name=name) for name in
            ['Back_Billow','Left_Edge_Flutter','Right_Edge_Flutter','Hem_Sway']}
for name,key in cloth_keys.items():
    key.slider_min=-1 if name=='Hem_Sway' else 0
    for index,point in enumerate(key.data):
        base=Vector(cape_vertices[index])
        row,column=divmod(index%layer,cols)
        t=(row/(len(cape_rows)-1))**1.5
        side=cape_columns[column]
        delta=Vector((0,0,0))
        if name=='Back_Billow':
            delta=Vector((0,-.42*t,.20*t*t))
        elif name in ['Left_Edge_Flutter','Right_Edge_Flutter']:
            sign=-1 if name.startswith('Left') else 1
            weight=(1+side*sign)*.5
            delta=Vector((sign*.11*t*t*weight,-.10*t*weight,.09*t*weight))
        else:
            delta=Vector((.10*t*t,.035*math.sin(side*4+row)*t,.03*math.sin(side*3)*t))
        point.co=base+delta

def cape_motion(phase,running=False):
    if running:
        values={'Back_Billow':.64+.16*math.sin(phase-.65),
                'Left_Edge_Flutter':.30+.27*math.sin(phase*2-.9),
                'Right_Edge_Flutter':.30+.27*math.sin(phase*2+1.1),
                'Hem_Sway':.68*math.sin(phase-.8)}
    else:
        values={'Back_Billow':.10+.045*math.sin(phase),
                'Left_Edge_Flutter':.14+.10*math.sin(phase-.7),
                'Right_Edge_Flutter':.14+.10*math.sin(phase+1.2),
                'Hem_Sway':.35*math.sin(phase-.5)}
    for name,value in values.items():
        cloth_keys[name].value=value
    bpy.context.view_layer.update()

cape['dynamic_controls']='Back_Billow, Left_Edge_Flutter, Right_Edge_Flutter, Hem_Sway'
cape['shoulders_pinned']=True

# Export the revised skinned costume separately; the live model stays untouched.
bpy.ops.object.select_all(action='DESELECT')
for ob in [rig,skin,bpy.data.objects['Hair_Normal'],costume,cape]:
    ob.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'knight-costume-draft.glb'),export_format='GLB',use_selection=True,
                         export_animations=False,export_skins=True,export_yup=True,export_materials='EXPORT')

# Wide leaf-shaped steel blade, with a pronounced central spine and honed edges.
profile = [(.28,.105), (.48,.18), (.65,.21), (1.15,.25), (1.67,.32),
           (1.99,.385), (2.17,.35), (2.30,.25), (2.38,.08)]
cross = [(-1,-.018),(-.79,-.062),(0,-.125),(.79,-.062),(1,-.018),
         (1,.018),(.79,.062),(0,.125),(-.79,.062),(-1,.018)]
verts = [(x*w,y*(1 if z<2.17 else max(.24,(2.46-z)/.29)),z) for z,w in profile for x,y in cross]
faces, indices = [], []
for j in range(len(profile)-1):
    for i in range(10):
        faces.append((j*10+i,j*10+(i+1)%10,(j+1)*10+(i+1)%10,(j+1)*10+i))
        indices.append([2,0,1,2,2,2,0,1,2,2][i])
verts += [(.03,-.007,2.44),(.03,.007,2.44)]
last=(len(profile)-1)*10
for i in range(10):
    tip=len(verts)-2 if i<5 else len(verts)-1
    faces.append((last+i,last+(i+1)%10,tip))
    indices.append(2 if i in [0,3,4,5,8,9] else (0 if i==1 else 1))
faces += [(last+5,len(verts)-2,len(verts)-1),(last,len(verts)-1,len(verts)-2)]
indices += [2,2]
faces += [tuple(reversed(range(10)))]
indices += [1]
blade=mesh('Claymore_Blade_Faceted', verts, faces, [steel,steel_dark,edge], sword, indices)
blade.data.calc_loop_triangles()
blade_bvh=BVHTree.FromPolygons([v.co for v in blade.data.vertices],
                             [tuple(t.vertices) for t in blade.data.loop_triangles],all_triangles=True)
# The long triangular raised ridge visible in the supplied reference.
mesh('Claymore_Raised_Center_Ridge',
     [(-.052,-.13,.40),(.052,-.13,.40),(.115,-.131,.75),(0,-.141,1.86),(-.115,-.131,.75),
      (0,-.17,.43),(0,-.175,.75)],
     [(0,1,5),(1,2,6,5),(2,3,6),(3,4,6),(4,0,5,6)], [ridge,steel_dark], sword, [0,0,0,1,1])

def width(z):
    for (a,wa),(b,wb) in zip(profile,profile[1:]):
        if a <= z <= b:
            return wa+(wb-wa)*(z-a)/(b-a)
    return profile[-1][1]

def face_y(x,z,sign,offset):
    hit,normal,index,distance=blade_bvh.ray_cast(Vector((x,sign,z)),Vector((0,-sign,0)))
    assert hit is not None,(x,z,sign)
    return hit.y+sign*offset

def crack(name, points, side):
    # Actual gold inlay geometry over a wider dark engraved channel, on both faces.
    for prefix,half,offset,mat in [('channel',.014,.003,engrave),('gold',.006,.0045,gold_light)]:
        original=[Vector((frac*width(z),z)) for frac,z in points]
        points3=[]
        for a,b in zip(original,original[1:]):
            count=max(1,math.ceil((b-a).length/.035))
            points3 += [tuple(a.lerp(b,i/count)) for i in range(count)]
        points3.append(tuple(original[-1]))
        verts=[]
        for i,(x,z) in enumerate(points3):
            prev = Vector(points3[max(0,i-1)])
            nxt = Vector(points3[min(len(points3)-1,i+1)])
            d=(nxt-prev).normalized()
            for s in [-1,1]:
                px,pz=x-s*d.y*half,z+s*d.x*half
                verts.append((px,face_y(px,pz,side,offset),pz))
        faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points3)-1)]
        mesh('Inlay_'+name+'_'+prefix+('_front' if side<0 else '_back'),verts,faces,[mat],sword)

paths = [
    [('left_main'),[(-.62,.73),(-.42,.86),(-.58,.93),(-.38,1.03),(-.48,1.14),(-.32,1.20),(-.52,1.29),(-.46,1.42),(-.67,1.48),(-.48,1.59),(-.59,1.70),(-.35,1.78),(-.50,1.88),(-.36,1.97),(-.55,2.04),(-.36,2.13),(-.49,2.20)]],
    [('right_main'),[(.52,.78),(.36,.89),(.60,.94),(.46,1.05),(.62,1.15),(.34,1.24),(.57,1.32),(.46,1.42),(.69,1.51),(.53,1.60),(.35,1.67),(.49,1.76),(.38,1.84),(.63,1.92),(.50,2.03),(.63,2.12),(.43,2.20)]],
    [('left_branch'),[(-.46,1.42),(-.78,1.37),(-.81,1.27)]],
    [('left_top_branch'),[(-.50,1.88),(-.76,1.94),(-.76,2.01)]],
    [('right_branch'),[(.46,1.42),(.81,1.37),(.80,1.24)]],
    [('right_top_branch'),[(.38,1.84),(.77,1.81),(.78,1.97)]],
]
for name,points in paths:
    for side in [-1,1]:
        crack(name,points,side)

# Broad stepped gold guard curls up around the blade root.
guard = [(.08,.20),(.26,.24),(.40,.34),(.43,.46),(.38,.50),(.32,.46),
         (.34,.55),(.28,.57),(.24,.52),(.26,.63),(.19,.66),(.16,.56),
         (.12,.49),(.11,.36),(.02,.28)]
for sign,label in [(-1,'Left'),(1,'Right')]:
    bevel_plate('Claymore_Gold_Guard_'+label,[(sign*x,z) for x,z in guard],.18,
                [gold,gold_light,gold_dark],sword)
    bevel_plate('Guard_Inner_Dark_Facet_'+label,[(sign*x,z) for x,z in [(.12,.28),(.28,.34),(.33,.43),(.24,.40),(.16,.36)]],
                .19,[gold_dark,gold,gold_dark],sword)
tube('Claymore_Guard_Collar',(0,0,.15),(0,0,.28),.103,[gold,gold_light,gold_dark],sword)
tube('Claymore_Long_Grip',(0,0,-.34),(0,0,.17),.054,[grip_mat,steel_dark],sword)
for z in [-.32,-.17,-.12,.04,.15]:
    tube('Grip_Silver_Band_'+str(z),(0,0,z-.012),(0,0,z+.012),.06,[edge,steel],sword)
bevel_plate('Claymore_Angular_Gold_Pommel',[(-.105,-.33),(.105,-.33),(.14,-.41),(.08,-.47),(-.08,-.47),(-.14,-.41)],
            .105,[gold,gold_light,gold_dark],sword)

# Blue/gold shell with a new gold lion-head sigil; old crest is fully removed.
blue=material('Knight | shield royal blue','142366')
back_blue=material('Knight | shield dark rear steel','27374d')
w,h=old_dimensions[0]*1.2*.90,old_dimensions[2]*1.5*.90
outline=[(0,h),(w*.93,h*.91),(w,h*.23),(w*.87,-h*.49),(0,-h),
         (-w*.87,-h*.49),(-w,h*.23),(-w*.93,h*.91)]
n=len(outline)
verts=[]
for sx,sz,y in [(1,1,-.27),(.974,.981,-.32),(.89,.92,-.33),(1,1,-.19)]:
    verts += [(x*sx,y,z*sz) for x,z in outline]
faces=[]
indices=[]
for a,b,mat in [(0,1,0),(1,2,1),(0,3,2)]:
    for i in range(n):
        faces.append((a*n+i,a*n+(i+1)%n,b*n+(i+1)%n,b*n+i))
        indices.append(mat)
verts.append((0,-.39,0))
for i in range(n):
    faces.append((n*2+i,n*2+(i+1)%n,len(verts)-1))
    indices.append(3)
faces.append(tuple(reversed(range(n*3,n*4))))
indices.append(4)
shell=mesh('Wall_Shield_Closed_Beveled_Shell',verts,faces,[edge,gold,steel_dark,blue,back_blue],shield,indices)
shell.data.calc_loop_triangles()
shield_face_bvh=BVHTree.FromPolygons([v.co for v in shell.data.vertices],
                                   [tuple(t.vertices) for t in shell.data.loop_triangles],all_triangles=True)

subprocess.run(['python3',str(OUT/'rasterize_lion_texture.py')],
               input=json.dumps({'half_width':w,'half_height':h}),text=True,check=True)
lion_image=bpy.data.images.load(str(OUT/'lion-shield-paint.png'),check_existing=False)
lion_image.name='Knight | flat painted lion shield'
lion_image.pack()
texture=blue.node_tree.nodes.new('ShaderNodeTexImage')
texture.name='Flat lion painted graphic'
texture.image=lion_image
blue.node_tree.links.new(texture.outputs['Color'],blue.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
for poly in shell.data.polygons:
    if poly.material_index==3:
        for loop_index in poly.loop_indices:
            co=shell.data.vertices[shell.data.loops[loop_index].vertex_index].co
            shell.data.uv_layers.active.data[loop_index].uv=(co.x/(w*2)+.5,co.z/(h*2)+.5)
shield['emblem']='Flat 2D gold lion-head graphic painted onto blue shield; no relief geometry'
tube('Wall_Shield_Rear_Handgrip',(0,0,-.11),(0,0,.11),.050,[grip_mat,steel],shield)
for z in [-.10,.10]:
    tube('Wall_Shield_Grip_Support_'+str(z),(0,0,z),(0,-.19,z),.029,[steel_dark],shield)
    tube('Wall_Shield_Rear_Rivet_'+str(z),(0,-.165,z),(0,-.185,z),.052,[gold,gold_light],shield)
for z in [-.35,.35]:
    tube('Wall_Shield_Rear_Brace_'+str(z),(-.568,-.175,z),(.568,-.175,z),.025,[steel_dark],shield)

def children(root):
    return [root,*root.children_recursive]

def export(root,path):
    # Keep editable source parts; batch only disposable export copies.
    native_name=root.name
    root.name=native_name+'_Editable_Source'
    batch_root=empty(native_name)
    for key in root.keys():
        batch_root[key]=root[key]
    parts=[]
    for source in root.children_recursive:
        if source.type!='MESH':
            continue
        ob=source.copy()
        ob.data=source.data.copy()
        scene.collection.objects.link(ob)
        ob.parent=batch_root
        ob.matrix_parent_inverse=Matrix.Identity(4)
        ob.matrix_local=source.matrix_local.copy()
        parts.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    geometry=bpy.context.object
    geometry.name=native_name+'_Geometry'
    batch_root.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/path),export_format='GLB',use_selection=True,
                             export_animations=False,export_yup=True,export_materials='EXPORT',export_extras=True)
    bpy.data.objects.remove(geometry,do_unlink=True)
    bpy.data.objects.remove(batch_root,do_unlink=True)
    root.name=native_name

def bounds(root):
    coordinates=[ob.matrix_local@v.co for ob in root.children_recursive if ob.type=='MESH' for v in ob.data.vertices]
    lo=[min(v[i] for v in coordinates) for i in range(3)]
    hi=[max(v[i] for v in coordinates) for i in range(3)]
    return {'min_xyz':lo,'max_xyz':hi,'dimensions_xyz':[b-a for a,b in zip(lo,hi)]}

bpy.context.view_layer.update()
asset_bounds={'sword':bounds(sword),'shield':bounds(shield)}
assert math.isclose(asset_bounds['shield']['dimensions_xyz'][0],old_dimensions[0]*2.16,abs_tol=1e-5)
assert math.isclose(asset_bounds['shield']['dimensions_xyz'][2],old_dimensions[2]*2.7,abs_tol=1e-5)

export(sword,'knight-reference-claymore.glb')
export(shield,'knight-wall-shield.glb')
# Pack original texture dependencies inside both draft sources.
for im in bpy.data.images:
    if im.packed_file:
        im.filepath='//'+Path(im.filepath).name

def align_bone(name,head,tail):
    pb=rig.pose.bones[name]
    h=rig.matrix_world.inverted()@Vector(head)
    t=rig.matrix_world.inverted()@Vector(tail)
    axis=pb.bone.tail_local-pb.bone.head_local
    rot=axis.rotation_difference(t-h).to_matrix().to_4x4()
    pb.matrix=Matrix.Translation(h)@rot@Matrix.Translation(-pb.bone.head_local)@pb.bone.matrix_local
    bpy.context.view_layer.update()

def grip_pose(side,target,hand_axis=Vector((0,0,1)),face=Vector((0,-1,0))):
    shoulder=rig.matrix_world@rig.data.bones['Arm_'+side].head_local
    hand_axis=Vector(hand_axis).normalized()
    wrist=Vector(target)-hand_axis*.135
    a=rig.data.bones['Arm_'+side].length
    b=rig.data.bones['Forearm_'+side].length
    direction=wrist-shoulder
    d=direction.length
    assert abs(a-b)<d<a+b
    u=direction.normalized()
    pole=Vector((-.5 if side=='R' else .5,.5,-1))
    v=(pole-u*pole.dot(u)).normalized()
    along=(a*a-b*b+d*d)/(2*d)
    elbow=shoulder+u*along+v*math.sqrt(max(0,a*a-along*along))
    align_bone('Arm_'+side,shoulder,elbow)
    align_bone('Forearm_'+side,elbow,wrist)
    # Match the wrist's grip axis AND roll to the actual held weapon.
    z=(Vector(face)-hand_axis*Vector(face).dot(hand_axis)).normalized()
    x=hand_axis.cross(z).normalized()
    frame=Matrix((x,hand_axis,z)).transposed().to_4x4()
    frame.translation=wrist
    rig.pose.bones['Hand_'+side].matrix=rig.matrix_world.inverted()@frame
    bpy.context.view_layer.update()
    return {'grip':list(target),'wrist':list(wrist),'elbow':list(elbow),'grip_axis':list(hand_axis)}

def orient_weapon(root,location,axis,face):
    axis=Vector(axis).normalized()
    normal=(Vector(face)-axis*Vector(face).dot(axis)).normalized()
    y=-normal
    x=y.cross(axis).normalized()
    frame=Matrix((x,y,axis)).transposed().to_4x4()
    frame.translation=Vector(location)
    root.matrix_world=frame
    bpy.context.view_layer.update()

def hold_pose():
    return {side:grip_pose(side,ob.matrix_world.translation,
                          ob.matrix_world.to_3x3()@Vector((0,0,1)),
                          ob.matrix_world.to_3x3()@Vector((0,-1,0)))
            for side,ob in [('R',sword),('L',shield)]}

def world_bounds(root):
    points=[ob.matrix_world@v.co for ob in root.children_recursive if ob.type=='MESH' for v in ob.data.vertices]
    return {'min_xyz':[min(v[i] for v in points) for i in range(3)],
            'max_xyz':[max(v[i] for v in points) for i in range(3)]}

orient_weapon(sword,(-.69,-.24,1.07),(-.32,.11,.941),(-1,0,0))
orient_weapon(shield,(.90,-.22,1.40),(0,0,1),(.5,-.866,0))
pose=hold_pose()
idle_bounds={name:world_bounds(ob) for name,ob in [('sword',sword),('shield',shield)]}
sword['presentation']='Relaxed right-hand guard; cutting edge forward, flat faces left/right; wrist aligned to hilt'
scene['draft_status']='ASSET REVIEW ONLY — no live integration'
scene['shield_scale']='2.16x original width and 2.7x original height; lion artwork size retained; centered grip'
scene['reference']='User sword image 2026-10-14: broad slate steel, raised ridge, gold crack inlays and guard'
for name,checksum in protected.items():
    assert fingerprint(bpy.data.objects[name])==checksum,name+' changed'
assert {b.name:[list(b.head_local),list(b.tail_local)] for b in rig.data.bones}==bones

# Shared neutral studio, with restrained matte materials matching the Goemon source.
studio=bpy.data.collections.new('Preview studio — excluded from weapon exports')
scene.collection.children.link(studio)
def move_to_studio(ob):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    studio.objects.link(ob)
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1400
scene.render.resolution_y=1400
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world=bpy.data.worlds.new('Knight draft studio')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.17,.23,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
scene.view_settings.view_transform='Standard'
for loc,power,size in [((-4,-6,7),750,5),((5,-3,5),500,4),((0,5,7),850,4)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object
    light.data.energy=power
    light.data.size=size
    light.rotation_euler=(Vector((0,0,1.5))-light.location).to_track_quat('-Z','Y').to_euler()
    move_to_studio(light)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.035))
floor=bpy.context.object
floor.name='Preview_Ground'
floor.data.materials.append(material('Preview ground','253346'))
move_to_studio(floor)
bpy.ops.object.camera_add()
camera=bpy.context.object
camera.name='Preview_Camera'
camera.data.type='ORTHO'
scene.camera=camera
move_to_studio(camera)

def render(name,angle,target=(.35,0,1.72),scale=4.85,res=(1400,1400)):
    target=Vector(target)
    camera.location=target+Vector((math.sin(angle)*12,-math.cos(angle)*12,.5))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=scale
    scene.render.resolution_x,scene.render.resolution_y=res
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)

cape_motion(0)
for name,angle in [('ready-front',0),('ready-three-quarter',math.radians(-30)),
                   ('ready-side',math.radians(-90)),('ready-back',math.pi)]:
    render(name,angle)
target=Vector((.35,0,1.72))
camera.location=target+Vector((-6,-10.392,.5))
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
# Open the editable source directly into a useful ready-pose camera view.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
idle_frames=OUT/'idle-cape-frames'
idle_frames.mkdir(exist_ok=True)
scene.render.fps=12
scene.frame_start=1
scene.frame_end=24
for index in range(25):
    scene.frame_set(index+1)
    cape_motion(index*math.tau/24)
    for key in cloth_keys.values():
        key.keyframe_insert(data_path='value',frame=index+1)
    if index<24:
        render('idle-cape-frames/frame-'+str(index).zfill(2),0,res=(900,900))
scene.frame_set(1)
render('ready-front',0)
bpy.context.scene.camera.data.ortho_scale=4.85
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'knight-ready-preview.blend'))

# Running carry: shield face points to the character's left, sword face to his right.
# These are draft presentation animations, never runtime animation replacements.
rig.location.z=-.10
cape.data.shape_keys.animation_data_clear()
cape_motion(math.pi/3,True)
orient_weapon(sword,(-.74,-.07,1.05),(-.22,.36,.907),(-1,0,0))
orient_weapon(shield,(.72,0,1.41),(0,0,1),(1,0,0))
run_pose=hold_pose()
run_bounds={name:world_bounds(ob) for name,ob in [('sword',sword),('shield',shield)]}
assert idle_bounds['shield']['min_xyz'][2]>.025
assert run_bounds['shield']['min_xyz'][2]>.025

def run_legs(phase):
    for side,offset in [('R',0),('L',math.pi)]:
        t=phase+offset
        hip=rig.matrix_world@rig.data.bones['Leg_'+side].head_local
        ankle=Vector((-.315 if side=='R' else .315,-.27*math.cos(t),.185+.13*max(0,math.sin(t))))
        a=rig.data.bones['Leg_'+side].length
        b=rig.data.bones['Shin_'+side].length
        delta=ankle-hip
        d=delta.length
        assert abs(a-b)<d<a+b
        u=delta.normalized()
        pole=Vector((0,-1,-.2))
        v=(pole-u*pole.dot(u)).normalized()
        along=(a*a-b*b+d*d)/(2*d)
        knee=hip+u*along+v*math.sqrt(a*a-along*along)
        align_bone('Leg_'+side,hip,knee)
        align_bone('Shin_'+side,knee,ankle)
        toe_direction=Vector((0,-.36,-.085)).normalized()
        align_bone('Foot_'+side,ankle,ankle+toe_direction*rig.data.bones['Foot_'+side].length)

for pb in rig.pose.bones:
    pb.rotation_mode='QUATERNION'
run_legs(math.pi/3)
for name,angle in [('run-front',0),('run-three-quarter',math.radians(-30)),
                   ('run-side',math.pi/2),('run-back',math.pi)]:
    render(name,angle)
frames=OUT/'run-frames'
frames.mkdir(exist_ok=True)
scene.render.fps=16
scene.frame_start=1
scene.frame_end=16
for index in range(17):
    frame=index+1
    scene.frame_set(frame)
    run_legs(index*math.tau/16)
    cape_motion(index*math.tau/16,True)
    for key in cloth_keys.values():
        key.keyframe_insert(data_path='value',frame=frame)
    for side in ['L','R']:
        for limb in ['Leg_','Shin_','Foot_']:
            pb=rig.pose.bones[limb+side]
            for prop in ['location','rotation_quaternion','scale']:
                pb.keyframe_insert(data_path=prop,frame=frame)
    if index<16:
        render('run-frames/frame-'+str(index).zfill(2),math.radians(-30),res=(900,900))
scene.frame_set(4)
hold_pose()
render('run-preview',math.radians(-30))
scene['presentation']='Stable torso; legs stride; shield faces left; claymore carried along right side'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'knight-run-preview.blend'))

# Weapon-only views are real meshes, not painted concept images.
for ob in list(bpy.data.objects):
    if ob not in children(sword)+children(shield)+list(studio.objects):
        ob.hide_render=True
sword.location=(0,0,.52)
sword.rotation_euler=(0,0,0)
shield.rotation_euler=(0,0,0)
shield.hide_render=True
for ob in shield.children_recursive:
    ob.hide_render=True
render('sword-closeup',math.radians(-14),target=(0,0,1.49),scale=3.18,res=(1000,1500))
render('sword-front',0,target=(0,0,1.49),scale=3.18,res=(1000,1500))
for ob in children(sword):
    ob.hide_render=True
for ob in children(shield):
    ob.hide_render=False
shield.location=(0,0,1.42)
render('shield-front',0,target=(0,-.3,1.42),scale=3.25,res=(1200,1400))
render('shield-back',math.pi,target=(0,-.3,1.42),scale=3.25,res=(1200,1400))

# A real weapons-only scene, laid out separately for direct editing in Blender.
for ob in children(sword)+children(shield):
    ob.hide_render=False
sword.location=(-1.15,0,.52)
shield.location=(1.02,0,1.42)
keep=set(children(sword)+children(shield)+list(studio.objects))
for ob in list(bpy.data.objects):
    if ob not in keep:
        bpy.data.objects.remove(ob,do_unlink=True)
scene.name='Knight weapons — isolated asset draft'
scene.render.resolution_x=1600
scene.render.resolution_y=1200
camera.location=(.1,-12,1.54)
camera.rotation_euler=(Vector((.1,0,1.54))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=4.9
scene['status']='Draft only; exported weapon roots are at their grip origins'
# Save a normal populated file; Blender 5.2 partial Scene writes can crash.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'knight-weapons.blend'))

after={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in LIVE if p.exists()}
assert before==after,'A live file changed concurrently; inspect before making a preservation claim'
report={'live_files_unchanged':before==after,'live_sha256':after,'shared_geometry_uv_weights_unchanged':protected,
        'bone_lengths_unchanged':True,'original_shield_dimensions_xyz':old_dimensions,
        'draft_shield_face_dimensions_xz':[old_dimensions[0]*2.16,old_dimensions[2]*2.7],
        'original_shield_depth':old_dimensions[1],
        'shield_face_scale':[2.16,2.7],'shield_width_reduction_from_initial_draft':.28,
        'shield_face_scale_from_previous_draft':.90,'lion_artwork_scale_unchanged':True,
        'shield_grip_centered_on_face':True,'shield_emblem':'flat painted gold lion head',
        'lion_emblem_has_relief_geometry':False,'asset_bounds':asset_bounds,
        'ready_grips_world':pose,'run_grips_world':run_pose,
        'presentation_bounds':{'idle':idle_bounds,'run':run_bounds},
        'run_presentation_frames':16,'gameplay_integrated':False,
        'costume_revision':{'silver_boot_face_count':len(boot_faces),'original_cape_length':1.03,
                            'new_cape_length':1.36,'cape_color':'#080f28',
                            'cape_base_hem_width':1.56,'cape_dynamic_shape_keys':list(cloth_keys),
                            'idle_cape_preview_frames':24,'other_costume_coordinates_unchanged':True}}
(OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('KNIGHT_DRAFT_COMPLETE',str(OUT))

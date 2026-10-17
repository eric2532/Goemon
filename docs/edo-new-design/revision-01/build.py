"""Fresh Edo art prototype. Blender --background --python tools/edo_new_design/build.py.

Creates an independent, unrigged review model. No gameplay assets are replaced.
The companion is appended from the approved Goemon master without saving it.
"""
import bpy, bmesh, math, json, hashlib, base64
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'assets/blender/characters/edo_new_design'
MODEL=ROOT/'assets/models/characters/edo_new_design'
DOC=ROOT/'docs/edo-new-design'
for p in [ART,MODEL,DOC]:p.mkdir(parents=True,exist_ok=True)
protected=[ROOT/'assets/blender/characters/kai.blend', ROOT/'assets/blender/characters/edo_anime.blend', ROOT/'assets/models/characters/edo_anime.glb']
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
edo=bpy.data.collections.new('EDO / CINDER DUELIST / prototype 01');scene.collection.children.link(edo)
parts=[]

def srgb(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
def mat(name,hex):
    rgb=tuple(srgb(int(hex[i:i+2],16)/255) for i in [0,2,4])
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=.88;p.inputs['Specular IOR Level'].default_value=.12
    return m
M={k:mat(k,h) for k,h in {
 'Skin':'e6ac79','Skin warm shadow':'bb784e','Crimson':'a82d3c','Crimson lit edge':'cd4c4d',
 'Crimson fold':'7e2435','Charcoal':'29373d','Charcoal edge':'415055','Hair':'18282b',
 'Hair planes':'293e40','Hair dark':'111d23','Old gold':'e9ac4f','Amber':'ee7838',
 'Ivory wraps':'d6c6a5','Wrap shadow':'afa58c','Boot blue':'34434d','Soles':'1b282d'
}.items()}
face=mat('Edo painted expression','ffffff')
im=bpy.data.images.load(str(ART/'face.png'));im.pack()
tex=face.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
face.node_tree.links.new(tex.outputs['Color'],face.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

def mesh(name,verts,faces,mats,smooth=True,ids=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);edo.objects.link(ob)
    for m in mats:me.materials.append(M[m] if isinstance(m,str) else m)
    for p in me.polygons:p.use_smooth=smooth;p.material_index=ids[p.index] if ids else 0
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    parts.append(ob);return ob

def loft(name,rings,material,n=16,smooth=True,power=1.0):
    # z, center x, center y, radius x, radius y. Shaped sections avoid capsule anatomy.
    v=[];f=[]
    for z,cx,cy,rx,ry in rings:
        for i in range(n):
            a=math.tau*i/n;s=math.sin(a);c=math.cos(a)
            v.append((cx+rx*math.copysign(abs(s)**power,s),cy+ry*math.copysign(abs(c)**power,c),z))
    for j in range(len(rings)-1):
        for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    f.extend([tuple(reversed(range(n))),tuple(range((len(rings)-1)*n,len(rings)*n))])
    return mesh(name,v,f,[material],smooth)

def orb(name,loc,scale,material,n=16,r=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n,ring_count=r,location=loc)
    ob=bpy.context.object;ob.name=name;ob.scale=scale
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for c in list(ob.users_collection):c.objects.unlink(ob)
    edo.objects.link(ob);ob.data.materials.append(M[material])
    for p in ob.data.polygons:p.use_smooth=True
    parts.append(ob);return ob

def panel(name,points,material,thickness=.014,bevel=.008):
    ob=mesh(name,points,[tuple(range(len(points)))],[material],False)
    sol=ob.modifiers.new('Cloth thickness','SOLIDIFY');sol.thickness=thickness
    if bevel:be=ob.modifiers.new('Soft cloth edge','BEVEL');be.width=bevel;be.segments=2
    return ob

def tube(name,coords,radius,material):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=radius;cu.bevel_resolution=1
    sp=cu.splines.new('POLY');sp.points.add(len(coords)-1)
    for p,co in zip(sp.points,coords):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);edo.objects.link(ob);cu.materials.append(M[material]);parts.append(ob);return ob

# Athletic torso, short waist and layered short coat. Designed freely in 3D.
loft('Vest / shaped ribcage',[(1.46,0,0,.29,.19),(1.64,0,0,.31,.21),(1.92,0,-.015,.44,.235),(2.10,0,-.03,.43,.22),(2.17,0,-.015,.22,.155)],'Charcoal',24,power=.86)
loft('Neck',[(2.10,0,0,.15,.13),(2.28,0,0,.15,.14)],'Skin',20)
loft('Split standing collar',[(2.10,0,-.015,.205,.17),(2.23,0,-.025,.19,.16)],'Crimson',20)
loft('Sash / broad waist',[(1.44,0,0,.32,.205),(1.57,0,0,.34,.22),(1.61,0,0,.33,.216)],'Crimson fold',24,power=.85)
tube('Sash / upper piping',[(-.3,.095,1.601),(-.21,.203,1.601),(0,.225,1.601),(.21,.203,1.601),(.3,.095,1.601)],.011,'Old gold')
for side in [-1,1]:
    # Jacket panels open around the dark chest, cut shorter on the right.
    edge=.15 if side==-1 else .20
    panel('Jacket / front '+str(side),[(side*.13,.184,2.145),(side*.43,.14,2.09),(side*.47,.13,1.86),(side*.36,.185,1.60),(side*edge,.224,1.66),(side*.235,.23,1.98)],'Crimson',.035,.014)
    tube('Jacket / gold lapel '+str(side),[(side*.13,.197,2.14),(side*.235,.245,1.98),(side*edge,.24,1.67)],.012,'Old gold')
    panel('Jacket / side '+str(side),[(side*.43,.13,2.09),(side*.40,-.16,2.08),(side*.39,-.215,1.67),(side*.36,.185,1.60)],'Crimson fold',.027)
panel('Jacket / back', [(-.4,-.17,2.10),(.4,-.17,2.10),(.38,-.233,1.61),(0,-.252,1.55),(-.38,-.233,1.61)],'Crimson',.034,.015)
panel('Jacket / long left skirt',[(-.29,.195,1.49),(-.40,.10,1.47),(-.49,.07,1.13),(-.38,.17,1.05),(-.26,.243,1.20)],'Crimson',.027)
panel('Jacket / rear split left',[(-.30,-.20,1.48),(-.39,-.12,1.45),(-.45,-.17,1.09),(-.26,-.24,1.17),(-.08,-.25,1.45)],'Crimson fold',.027)
# Left shoulder mantle creates an intentional asymmetric outline.
loft('Left shoulder / crimson mantle',[(1.91,-.58,-.02,.235,.23),(2.06,-.52,-.025,.265,.25),(2.17,-.43,-.035,.225,.21),(2.205,-.33,-.015,.10,.13)],'Crimson',16,smooth=False)
tube('Mantle / hem gold',[(-.80,.02,1.94),(-.75,.17,1.94),(-.59,.217,1.94),(-.43,.16,1.94)],.013,'Old gold')
# Distinct forearms, wraps and palms instead of mitten-like round fists.
for side in [-1,1]:
    sx=lambda x:side*x
    loft('Sleeve '+str(side),[(1.69,sx(.62),.005,.15,.155),(1.88,sx(.56),-.015,.185,.19),(2.06,sx(.46),-.02,.195,.205),(2.135,sx(.39),-.02,.145,.18),(2.165,sx(.30),-.025,.06,.10)],'Crimson' if side==1 else 'Charcoal',16,power=.9)
    loft('Forearm '+str(side),[(1.31,sx(.70),.065,.105,.115),(1.48,sx(.69),.045,.125,.135),(1.70,sx(.63),.005,.13,.135)],'Skin',16)
    loft('Forearm wrap '+str(side),[(1.30,sx(.706),.069,.117,.124),(1.41,sx(.698),.055,.128,.138),(1.57,sx(.67),.025,.145,.145)],'Ivory wraps',16)
    for j in range(4):
        z=1.34+j*.056;x=sx(.701-(z-1.34)*.13);y=.06-(z-1.34)*.15
        rx=.125+(z-1.30)/.27*.028;ry=.133+(z-1.30)/.27*.021
        coords=[(x+rx*math.sin(a),y+ry*math.cos(a),z+.013*math.sin(a)) for a in [i*math.tau/24 for i in range(25)]]
        tube('Wrap overlap '+str(side)+' '+str(j),coords,.009,'Wrap shadow')
    loft('Palm '+str(side),[(1.08,sx(.733),.09,.078,.068),(1.12,sx(.734),.105,.103,.084),(1.23,sx(.728),.10,.112,.082),(1.31,sx(.707),.074,.088,.075)],'Skin',16,power=.76)
    orb('Thumb '+str(side),(sx(.63),.105,1.207),(.07,.065,.11),'Skin')
    for j in range(2):tube('Finger crease '+str(side)+' '+str(j),[(sx(.683+j*.051),.185,1.11),(sx(.684+j*.051),.189,1.17)],.004,'Skin warm shadow')
    # Leg volume has a clear thigh -> knee -> boot transition.
    loft('Tapered trouser '+str(side),[(.48,sx(.30),-.03,.13,.14),(.69,sx(.31),-.045,.145,.16),(.86,sx(.33),-.028,.19,.205),(1.13,sx(.27),-.035,.24,.245),(1.40,sx(.20),-.026,.24,.23),(1.49,sx(.18),-.02,.195,.20)],'Charcoal',20,power=.83)
    loft('Boot cuff '+str(side),[(.44,sx(.30),-.002,.18,.215),(.51,sx(.30),-.018,.165,.19),(.70,sx(.31),-.04,.158,.18)],'Crimson fold',20,power=.8)
    loft('Boot upper '+str(side),[(.17,sx(.31),.14,.22,.31),(.32,sx(.31),.10,.205,.28),(.47,sx(.30),-.01,.15,.18),(.54,sx(.30),-.02,.14,.155)],'Boot blue',20,power=.65)
    loft('Boot sole '+str(side),[(.035,sx(.31),.15,.228,.338),(.10,sx(.31),.15,.235,.347),(.17,sx(.31),.15,.225,.328)],'Soles',20,power=.62,smooth=False)
    loft('Boot cuff / wrap '+str(side),[(.57,sx(.303),-.025,.173,.201),(.615,sx(.306),-.032,.172,.198)],'Ivory wraps',20,power=.8)
# New emblem: a split ember on the vest and a restrained flame on the mantle.
panel('Chest / ember emblem',[(-.045,.244,1.91),(-.105,.24,1.85),(-.072,.242,1.77),(0,.244,1.74),(.082,.243,1.81),(.064,.243,1.86),(.015,.245,1.83)],'Old gold',.008,0)
panel('Mantle / rising ember',[(-.66,.236,2.015),(-.64,.244,2.077),(-.60,.243,2.041),(-.56,.246,2.113),(-.53,.247,2.055),(-.49,.237,2.072),(-.50,.243,2.00),(-.57,.249,1.985)],'Old gold',.005,0)
panel('Sash / hanging tie',[(-.27,.232,1.53),(-.14,.239,1.51),(-.12,.278,1.24),(-.19,.284,1.13),(-.28,.273,1.25)],'Crimson lit edge',.023)
panel('Sash / tie tip',[(-.125,.29,1.28),(-.17,.29,1.17),(-.195,.29,1.145),(-.235,.29,1.20),(-.255,.285,1.27)],'Old gold',.005,0)

# Full skull and integrated nose. Painted eyes/eyebrows follow the head surface.
rings=[(2.205,.085,.10,.115),(2.24,.18,.16,.17),(2.30,.285,.225,.235),(2.40,.355,.278,.295),(2.51,.402,.297,.322),(2.63,.421,.298,.336),(2.75,.428,.294,.346),(2.87,.407,.28,.33),(2.98,.34,.228,.265),(3.055,.21,.15,.17),(3.08,.025,.022,.023)]
v=[];f=[];n=40
for z,rx,front,back in rings:
    for i in range(n):
        a=math.tau*i/n;x=rx*math.sin(a);c=math.cos(a)
        y=(front if c>=0 else back)*c-.02
        if c>0:
            # Brow, muzzle and short nose are continuous head geometry.
            y+=.017*math.exp(-((z-2.72)/.10)**2)*c**5
            y+=.074*math.exp(-(x/.062)**2-((z-2.51)/.10)**2)*c**8
            y+=.018*math.exp(-(x/.19)**2-((z-2.37)/.07)**2)*c**5
        v.append((x,y,z))
for j in range(len(rings)-1):
    for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
f.extend([tuple(reversed(range(n))),tuple(range((len(rings)-1)*n,len(rings)*n))])
head=mesh('Head / sculpted cheeks jaw nose',v,f,[face,M['Skin']])
uv=head.data.uv_layers.new(name='Face artwork')
for p in head.data.polygons:
    p.material_index=0 if p.center.y>-.019 else 1
    for li in p.loop_indices:
        co=head.data.vertices[head.data.loops[li].vertex_index].co
        uv.data[li].uv=(max(.001,min(.999,.5+co.x/.98)),max(.001,min(.999,.5+(co.z-2.62)/.88)))
for s in [-1,1]:
    orb('Ear '+str(s),(s*.424,-.025,2.54),(.085,.065,.128),'Skin')
    orb('Ear inset '+str(s),(s*.456,.026,2.548),(.040,.015,.075),'Skin warm shadow',12,8)
tube('Ear / single gold cuff',[(.487,-.035,2.57),(.497,.005,2.57),(.48,.043,2.57)],.017,'Old gold')

# Broad swept locks with faceted planes. No tall central crest.
loft('Hair / fitted skull',[(2.65,0,-.135,.34,.235),(2.82,0,-.07,.441,.325),(2.99,-.025,-.075,.42,.31),(3.115,-.02,-.10,.26,.22),(3.14,-.015,-.11,.045,.035)],'Hair',24)
def bez(points,t):
    a,b,c,d=[Vector(x) for x in points];return a*(1-t)**3+3*b*t*(1-t)**2+3*c*t*t*(1-t)+d*t**3
def blade(name,points,width,depth):
    v=[];f=[];ids=[];steps=7;n=6
    for j in range(steps+1):
        t=j/steps;p=bez(points,t);tan=(bez(points,min(1,t+.01))-bez(points,max(0,t-.01))).normalized()
        dep=Vector((0,1,0));across=tan.cross(dep).normalized();dep=across.cross(tan).normalized()
        w=width*(.84+.32*math.sin(t*math.pi))*max(.004,1-t**1.1)
        h=depth*max(.012,1-t**1.6)
        for k in range(n):
            a=math.tau*k/n;v.append(tuple(p+across*math.cos(a)*w+dep*math.sin(a)*h))
    for j in range(steps):
        for k in range(n):f.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k));ids.append(1 if k in [0,1] else (2 if k==4 else 0))
    f.append(tuple(reversed(range(n))));ids.append(0)
    f.append(tuple(range(steps*n,(steps+1)*n)));ids.append(0)
    return mesh(name,v,f,['Hair','Hair planes','Hair dark'],False,ids)
for name,points,w,h in [
 ('Crown / sweep left',[(.22,-.055,2.995),(-.02,-.055,3.17),(-.31,-.045,3.24),(-.56,-.005,3.28)],.225,.14),
 ('Crown / low side spike',[(-.17,-.13,2.995),(-.4,-.14,3.1),(-.58,-.12,3.11),(-.70,-.10,3.07)],.20,.14),
 ('Crown / right rake',[(.15,-.15,2.96),(.42,-.19,3.11),(.50,-.18,3.20),(.46,-.17,3.26)],.18,.14),
 ('Fringe / diagonal broad lock',[(.23,.19,3.02),(.02,.38,3.02),(-.20,.39,2.88),(-.32,.30,2.69)],.20,.10),
 ('Fringe / short central tooth',[(.31,.13,3.01),(.29,.37,2.99),(.18,.38,2.87),(.12,.312,2.785)],.15,.085),
 ('Fringe / left temple',[(-.20,.13,2.98),(-.42,.20,2.94),(-.49,.15,2.73),(-.43,.10,2.55)],.16,.10),
 ('Right temple / sideburn',[(.35,.035,2.90),(.46,.075,2.86),(.46,.10,2.64),(.397,.105,2.58)],.145,.085),
 ('Left / swept side',[(-.29,-.17,2.86),(-.48,-.24,2.85),(-.58,-.25,2.73),(-.61,-.22,2.69)],.17,.11),
 ('Right / swept side',[(.29,-.19,2.85),(.47,-.24,2.87),(.53,-.27,2.77),(.60,-.24,2.75)],.16,.11),
 ('Rear / crown rake',[(.04,-.22,2.99),(-.04,-.42,3.09),(-.22,-.51,3.12),(-.37,-.52,3.09)],.21,.16),
 ('Rear / left nape',[(-.19,-.29,2.82),(-.34,-.43,2.74),(-.39,-.41,2.58),(-.43,-.38,2.52)],.18,.12),
 ('Rear / right nape',[(.15,-.29,2.83),(.30,-.45,2.76),(.35,-.42,2.60),(.41,-.39,2.53)],.18,.12),
 ('Rear / centre nape',[(0,-.33,2.80),(-.04,-.43,2.68),(-.08,-.40,2.55),(-.03,-.35,2.47)],.21,.10)
]:blade(name,points,w,h)

# Apply prototype modifiers and convert curves so both exports share exact geometry.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.convert(target='MESH')
parts=list(edo.objects)
scene['stage']='Design prototype 01. Unrigged. Not integrated into the game.'
scene['direction']='Cinder duelist: swept asymmetrical hair, cropped crimson mantle, charcoal tapered trousers, substantial blue boots.'

# Export the exact review model, plus a compact material/mesh payload for the inline viewer.
def serialize(objects):
    meshes=[];materials={};textures={}
    for ob in objects:
        if ob.type!='MESH':continue
        me=ob.data;me.calc_loop_triangles();uv=me.uv_layers.active
        batches={}
        for tri in me.loop_triangles:
            mi=tri.material_index
            if mi>=len(me.materials):continue
            m=me.materials[mi]
            if m.name not in materials:
                bs=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
                color=list(bs.inputs['Base Color'].default_value[:3]) if bs else list(m.diffuse_color[:3])
                entry={'color':[round(c,5) for c in color]}
                nodes=[n for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image] if m.use_nodes else []
                if nodes:
                    img=nodes[0].image
                    if img.name not in textures:
                        if img.packed_file:
                            raw=img.packed_file.data
                        else:
                            raw=Path(bpy.path.abspath(img.filepath)).read_bytes()
                        textures[img.name]='data:image/png;base64,'+base64.b64encode(raw).decode()
                    entry['texture']=img.name;entry['color']=[1,1,1]
                materials[m.name]=entry
            b=batches.setdefault(m.name,{'name':ob.name,'material':m.name,'p':[],'n':[],'uv':[]})
            for li in tri.loops:
                loop=me.loops[li];co=ob.matrix_world@me.vertices[loop.vertex_index].co
                no=ob.matrix_world.to_3x3()@(me.vertices[loop.vertex_index].normal if me.polygons[tri.polygon_index].use_smooth else tri.normal)
                b['p'].extend(round(x,4) for x in [co.x,co.z,-co.y]);b['n'].extend(round(x,3) for x in [no.x,no.z,-no.y])
                b['uv'].extend(round(x,4) for x in (uv.data[li].uv if uv else [0,0]))
        meshes.extend(batches.values())
    return {'meshes':meshes,'materials':materials,'textures':textures}

payload={'edo':serialize(parts)}
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'edo_cinder_duelist.blend'))
bpy.ops.export_scene.gltf(filepath=str(MODEL/'edo_cinder_duelist.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)

# Append the genuine Goemon geometry and pose its arms down for a useful comparison.
with bpy.data.libraries.load(str(protected[0]),link=False) as (src,dst):dst.objects=src.objects
goemon=[];rig=None
for ob in dst.objects:
    if not ob:continue
    if ob.type=='ARMATURE':rig=ob
    if ob.name.startswith('Hair_Gold') or ob.type not in ['ARMATURE','MESH']:continue
    scene.collection.objects.link(ob);goemon.append(ob)
if rig:
    for name,sign in [('Arm_L',-1),('Arm_R',1)]:
        pb=rig.pose.bones[name];basis=pb.bone.matrix_local.to_quaternion()
        pb.rotation_mode='QUATERNION'
        pb.rotation_quaternion=basis.inverted() @ Quaternion(Vector((0,1,0)),sign*1.05) @ basis
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get();gstatic=[]
for ob in goemon:
    if ob.type!='MESH':continue
    ev=ob.evaluated_get(deps);me=bpy.data.meshes.new_from_object(ev)
    copy=bpy.data.objects.new('Comparison / '+ob.name,me);scene.collection.objects.link(copy);copy.matrix_world=ob.matrix_world.copy();gstatic.append(copy)
for ob in goemon:ob.hide_render=True;ob.hide_set(True)
payload['goemon']=serialize(gstatic)
(DOC/'viewer-data.json').write_text(json.dumps(payload,separators=(',',':')))
for ob in gstatic:ob.location.x+=2.0

# Shared studio lighting, modelled perspective, and a grounded presentation.
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Soft studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.30,.34,.38,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='Standard'
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
def aim(ob,at):ob.rotation_euler=(Vector(at)-ob.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,size,color):
    dat=bpy.data.lights.new(name,'AREA');dat.energy=power;dat.shape='DISK';dat.size=size;dat.color=color
    ob=bpy.data.objects.new(name,dat);scene.collection.objects.link(ob);ob.location=loc;aim(ob,(0,0,1.7))
area('Key',(-3,4,6),450,5,(1,.9,.80));area('Fill',(4,2,4),220,4,(.79,.89,1));area('Rim',(1,-4,5),550,3,(1,.78,.56))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0));floor=bpy.context.object;floor.name='Studio ground';floor.data.materials.append(mat('Studio neutral','d5d5cf'))
dat=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new('Review camera',dat);scene.collection.objects.link(cam);scene.camera=cam;dat.type='ORTHO';dat.ortho_scale=3.9
for ob in gstatic:ob.hide_render=True
for name,loc in [('three-quarter',(4,7,3.3)),('front',(0,8,2.45)),('side',(8,0,2.45)),('back',(3,-8,2.7))]:
    cam.location=loc;aim(cam,(0,0,1.63));scene.render.filepath=str(DOC/(name+'.png'));bpy.ops.render.render(write_still=True)
for ob in gstatic:ob.hide_render=False
for ob in parts:ob.location.x-=1.10
for ob in gstatic:ob.location.x-=.90
dat.ortho_scale=5.5;scene.render.resolution_x=1500;scene.render.resolution_y=1000
cam.location=(2.4,9,3.0);aim(cam,(0,0,1.57));scene.render.filepath=str(DOC/'goemon-comparison.png');bpy.ops.render.render(write_still=True)
# Save review scene separately; asset source stays an uncluttered model-only scene.
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'edo_goemon_review.blend'))
assert hashes=={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
report={'stage':'unrigged visual prototype','protected_sha256':hashes,'protected_unchanged':True,'edo_meshes':len(parts),'edo_triangles':sum(len(o.data.loop_triangles) for o in parts),'viewer_bytes':(DOC/'viewer-data.json').stat().st_size,'renders':['front','three-quarter','side','back','goemon-comparison']}
(DOC/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('EDO_PROTOTYPE_COMPLETE',json.dumps(report))

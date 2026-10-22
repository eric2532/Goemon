"""Editable Blender-first pirate weapon draft. Does not modify live game assets.

Blender -b --python tools/build_pirate_weapons.py
"""
import bpy
import bmesh
import hashlib
import importlib.util
import json
import math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/characters/goemon_cosplay/pirate.blend'
OUT = ROOT / 'assets/blender/weapons/pirate'
QA = ROOT / 'build/Other Files/Pirate Weapons'
OUT.mkdir(parents=True, exist_ok=True)
QA.mkdir(parents=True, exist_ok=True)
LIVE = [SOURCE, ROOT / 'assets/models/characters/goemon_cosplay/pirate.glb',
        ROOT / 'assets/blender/characters/kai.blend']
BEFORE = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in LIVE}
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new('Midnight navy studio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.024, .035, .055, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .65
scene.view_settings.view_transform = 'AgX'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1800
scene.render.resolution_y = 1200
scene.render.filepath = str(QA / 'pirate-weapons.png')
scene.render.fps = 24
scene.unit_settings.system = 'METRIC'
scene['brief'] = 'Blender-first pirate weapon redesign from supplied flintlock and ornate octopus cutlass references.'
scene['status'] = 'Editable art review draft; live pirate and game build untouched.'

def color(hex):
    values = [int(hex[i:i+2], 16)/255 for i in (0, 2, 4)]
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values)

def material(name, base, metal=0, rough=.45, variation=None, grain=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color(base), 1)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    shader = nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color(base), 1)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = rough
    if variation:
        coord = nodes.new('ShaderNodeTexCoord')
        mapping = nodes.new('ShaderNodeVectorMath'); mapping.operation = 'MULTIPLY'
        mapping.inputs[1].default_value = (2, 95, 40) if grain else (90, 90, 90)
        links.new(coord.outputs['Generated'], mapping.inputs[0])
        noise = nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 1.8
        noise.inputs['Detail'].default_value = 3.5
        links.new(mapping.outputs['Vector'], noise.inputs['Vector'])
        ramp = nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = .20
        ramp.color_ramp.elements[0].color = (*color(variation), 1)
        ramp.color_ramp.elements[1].position = .82
        ramp.color_ramp.elements[1].color = (*color(base), 1)
        links.new(noise.outputs['Fac'], ramp.inputs[0])
        links.new(ramp.outputs[0], shader.inputs['Base Color'])
        bump = nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .16 if grain else .1
        bump.inputs['Distance'].default_value = .007 if grain else .0015
        links.new(noise.outputs['Fac'], bump.inputs['Height'])
        links.new(bump.outputs['Normal'], shader.inputs['Normal'])
    return mat

gold = material('01 | weathered captain brass', 'c79a47', .78, .34, '755020')
gold_light = material('02 | polished brass edges', 'e7c77e', .76, .28)
gold_dark = material('03 | recessed gold engraving', '66431d', .64, .5)
steel = material('04 | cool forged steel', '9aabbf', .78, .32, '69798e')
edge = material('05 | honed silver cutting edge', 'd7e2ee', .83, .24)
dark = material('06 | darkened steel recess', '27313c', .7, .47)
wood = material('07 | oiled walnut grain', '82462b', 0, .42, '28150f', True)
leather = material('08 | oxblood wrapped leather', '4c2920', 0, .63, '1e1010', True)
teal = material('09 | sea glass eyes', '319d92', .3, .22)
black = material('10 | black bore and eye pupils', '080e13', .15, .6)
parts = []
current = None

def add(ob, mat=None):
    if mat:
        ob.data.materials.append(mat)
    for coll in list(ob.users_collection):
        coll.objects.unlink(ob)
    current.objects.link(ob)
    parts.append(ob)
    return ob

def mesh(name, points, faces, mat, indices=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(points, [], faces); data.update()
    ob = bpy.data.objects.new(name, data); current.objects.link(ob)
    for m in mat if isinstance(mat, list) else [mat]: data.materials.append(m)
    if indices:
        for p, i in zip(data.polygons, indices): p.material_index = i
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data); bm.free()
    parts.append(ob)
    return ob

def bevel(ob, width=.008, segments=3):
    mod = ob.modifiers.new('Soft forged edges | editable', 'BEVEL')
    mod.width = width; mod.segments = segments
    return ob

def plate(name, outline, depth, mat, y=0, rounding=.004):
    n = len(outline)
    points = [(x,y-depth/2,z) for x,z in outline]+[(x,y+depth/2,z) for x,z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    ob = mesh(name,points,faces,mat)
    if rounding: bevel(ob,rounding)
    return ob

def path(name, points, radius, mat, smooth=True):
    data = bpy.data.curves.new(name, 'CURVE'); data.dimensions='3D'
    data.resolution_u=10; data.bevel_depth=radius; data.bevel_resolution=3; data.use_fill_caps=True
    spline=data.splines.new('BEZIER' if smooth else 'POLY')
    if smooth:
        spline.bezier_points.add(len(points)-1)
        for p,v in zip(spline.bezier_points, points):
            p.co=v[:3]; p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
            if len(v)>3: p.radius=v[3]
    else:
        spline.points.add(len(points)-1)
        for p,v in zip(spline.points,points): p.co=(*v[:3],1)
    ob=bpy.data.objects.new(name,data); current.objects.link(ob)
    data.materials.append(mat); parts.append(ob)
    return ob

def ellipsoid(name, loc, scale, mat, segments=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=12,location=loc)
    ob=bpy.context.object; ob.name=name; ob.scale=scale
    add(ob,mat)
    for p in ob.data.polygons:p.use_smooth=True
    return ob

def cylinder(name,a,b,radius,mat,vertices=32):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=(b-a).length,location=(a+b)/2)
    ob=bpy.context.object; ob.name=name
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    add(ob,mat); bevel(ob,.002,2)
    for p in ob.data.polygons:p.use_smooth=True
    return ob

def screw(name,x,y,z,mat=steel,size=.014):
    ob=cylinder(name,(x,y-.003,z),(x,y+.003,z),size,mat,16)
    side=1 if y>0 else -1
    path(name+' | slot',[(x-size*.62,y+side*.004,z),(x+size*.62,y+side*.004,z)],.0016,dark,False)
    return ob

def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c)
    return c

current=collection('CUTLASS | silver tide and brass kraken')
sword_start=len(parts)
# Seven points per blade section: a true cutting edge, broad face and dark spine.
sections=[(-.14,-.10,.13),(-.34,-.17,.15),(-.59,-.225,.145),
          (-.88,-.245,.15),(-1.16,-.22,.18),(-1.35,-.16,.30),
          (-1.48,-.08,.225),(-1.65,.015,.16),(-1.79,.12,.155)]
control=sections
sections=[]
for k in range(len(control)-1):
    p0=control[max(0,k-1)][1];p1=control[k][1]
    p2=control[k+1][1];p3=control[min(len(control)-1,k+2)][1]
    for j in range(5):
        t=j/5
        bottom=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
        sections.append((control[k][0]*(1-t)+control[k+1][0]*t,bottom,control[k][2]*(1-t)+control[k+1][2]*t))
sections.append(control[-1])
verts=[]
for x,bottom,top in sections:
    w=top-bottom
    verts += [(x,0,bottom),(x,-.023,bottom+min(.075,w*.34)),(x,-.031,top-.018),
              (x,-.012,top),(x,.012,top),(x,.031,top-.018),(x,.023,bottom+min(.075,w*.34))]
faces=[tuple(reversed(range(7)))]; indices=[2]
bands=[1,0,2,2,2,0,1]
for i in range(len(sections)-1):
    for j in range(7):
        faces.append((i*7+j,i*7+(j+1)%7,(i+1)*7+(j+1)%7,(i+1)*7+j)); indices.append(bands[j])
tip=len(verts);verts.append((-1.94,0,.205))
for j in range(7):faces.append(((len(sections)-1)*7+j,(len(sections)-1)*7+(j+1)%7,tip));indices.append(bands[j])
mesh('Cutlass | swept forged blade and real edge bevel',verts,faces,[steel,edge,dark],indices)
inset=[(-.18,-.045),(-.43,-.10),(-.72,-.13),(-1.01,-.11),(-1.27,-.045),
       (-1.44,.095),(-1.20,.045),(-.93,.015),(-.63,.015),(-.36,.035),(-.18,.08)]
for sign in [-1,1]:
    y=sign*.033
    plate('Cutlass | dark engraved fuller '+str(sign),inset,.004,dark,y, .003)
    path('Cutlass | raised gold fuller border '+str(sign),[(x,y+sign*.004,z) for x,z in inset+[inset[0]]],.007,gold)
    wave=[]
    for i in range(60):
        t=i/59; wave.append((-.24-1.05*t,y+sign*.007,-.018-.04*math.sin(math.pi*t)+.022*math.sin(t*math.tau*8)))
    path('Cutlass | eight wave gold engraving '+str(sign),wave,.005,gold_light)
    for i in range(10):
        x=-.30-i*.105
        path('Cutlass | edge wear '+str(sign)+' '+str(i),[(x,y-sign*.009,-.17+(.018 if i<3 else .012)),(x-.022,y-sign*.009,-.115)],.0014,edge,False)
# Compact handgrip behind the octopus guard; central palm area remains usable.
cylinder('Cutlass | tang',(-.15,0,0),(.52,0,0),.040,dark)
cylinder('Cutlass | oxblood grip',(.07,0,0),(.46,0,0),.058,leather)
for x in [.065,.46]:cylinder('Cutlass | grip brass ferrule',(x-.018,0,0),(x+.018,0,0),.069,gold)
coil=[]
for i in range(220):
    t=i/219;a=t*math.tau*10
    coil.append((.092+.338*t,.060*math.cos(a),.060*math.sin(a)))
path('Cutlass | spiral brass grip binding',coil,.009,gold_light,False)
ellipsoid('Cutlass | swept pommel',(.51,0,.015),(.064,.070,.086),gold)
path('Cutlass | sculpted knuckle bow',[(-.065,0,-.055),(-.005,0,-.25),(.18,0,-.30),(.40,0,-.25),(.51,0,-.04)],.030,gold)
path('Cutlass | knuckle bow highlight',[(-.055,-.024,-.07),(.015,-.024,-.247),(.20,-.024,-.275),(.40,-.024,-.226),(.50,-.024,-.035)],.006,gold_light)
path('Cutlass | upper quillon',[(-.07,0,.02),(-.06,0,.15),(.0,0,.26),(-.07,0,.29)],.026,gold)
ellipsoid('Cutlass | octopus mantle',(-.105,0,.060),(.113,.080,.110),gold)
ellipsoid('Cutlass | mantle crown',(-.145,0,.135),(.087,.066,.112),gold)
for sign in [-1,1]:
    ellipsoid('Cutlass | eye brass socket '+str(sign),(-.15,sign*.075,.095),(.026,.013,.026),gold_dark)
    ellipsoid('Cutlass | sea glass eye '+str(sign),(-.15,sign*.086,.095),(.019,.008,.021),teal)
    ellipsoid('Cutlass | eye pupil '+str(sign),(-.156,sign*.092,.095),(.006,.003,.014),black)
    tentacles=[
      [(-.15,.035),(-.29,-.04),(-.35,-.16),(-.49,-.23),(-.51,-.17),(-.46,-.145)],
      [(-.105,.015),(-.16,-.12),(-.25,-.245),(-.34,-.28),(-.36,-.24)],
      [(-.03,.035),(.025,-.06),(.02,-.16),(-.045,-.205),(-.08,-.175)],
      [(-.19,.09),(-.32,.12),(-.44,.095),(-.47,.16),(-.415,.18)],
    ]
    for k,coords in enumerate(tentacles):
        pts=[(x,sign*(.075+.005*k),z,1-.78*i/(len(coords)-1)) for i,(x,z) in enumerate(coords)]
        path('Cutlass | curling tentacle %s %s'%(sign,k),pts,.026,gold)
        # Individually editable suction cups on visible surfaces.
        for a,b in zip(coords[:-1],coords[1:]):
            for f in [.25,.65]:
                x=a[0]*(1-f)+b[0]*f;z=a[1]*(1-f)+b[1]*f
                ellipsoid('Cutlass | tentacle sucker', (x,sign*(.097+.005*k),z),(.009,.004,.009),gold_dark,12)
sword_parts=parts[sword_start:]

current=collection('FLINTLOCK | walnut brass and forged lock')
gun_start=len(parts)
# Sculpted continuous stock: elliptical sections along the curved pistol grip.
stock_rings=[(-.23,-.46,.070,.060),(-.265,-.41,.085,.080),(-.26,-.30,.078,.088),
             (-.20,-.17,.066,.085),(-.09,-.065,.061,.088),(.07,-.025,.064,.083),
             (.30,-.016,.061,.070),(.58,-.011,.052,.057),(.88,-.008,.042,.047),(1.025,.005,.039,.043)]
verts=[];N=20
for k,(x,z,ry,rz) in enumerate(stock_rings):
    previous=stock_rings[max(0,k-1)];following=stock_rings[min(len(stock_rings)-1,k+1)]
    tangent=Vector((following[0]-previous[0],0,following[1]-previous[1])).normalized()
    normal=Vector((-tangent.z,0,tangent.x))
    for i in range(N):
        angle=i*math.tau/N
        verts.append(tuple(Vector((x,ry*math.cos(angle),z))+normal*(rz*math.sin(angle))))
faces=[tuple(reversed(range(N))),tuple(range(len(verts)-N,len(verts)))]
faces += [(k*N+i,k*N+(i+1)%N,(k+1)*N+(i+1)%N,(k+1)*N+i) for k in range(len(stock_rings)-1) for i in range(N)]
stock=mesh('Flintlock | continuous sculpted walnut stock',verts,faces,wood)
mod=stock.modifiers.new('Hand carved stock smoothing','SUBSURF');mod.levels=2
for p in stock.data.polygons:p.use_smooth=True
ellipsoid('Flintlock | brass butt cap',(-.235,0,-.457),(.079,.066,.057),gold)
for sign in [-1,1]:
    path('Flintlock | butt cap rim '+str(sign),[(-.305,sign*.035,-.423),(-.265,sign*.073,-.41),(-.203,sign*.065,-.434)],.006,gold_light)
    plate('Flintlock | engraved steel lockplate '+str(sign),[(-.18,-.072),(-.13,.035),(.02,.082),(.37,.051),(.43,.005),(.36,-.043),(.0,-.10)],.012,steel,sign*.066,.009)
    path('Flintlock | lockplate raised rim '+str(sign),[(-.165,sign*.074,-.07),(-.105,sign*.074,.028),(.045,sign*.074,.062),(.35,sign*.074,.037),(.397,sign*.074,.004),(.34,sign*.074,-.027),(.0,sign*.074,-.080),(-.165,sign*.074,-.07)],.0035,dark)
    for x,z in [(-.11,-.045),(.32,.005)]:screw('Flintlock | lockplate screw',x,sign*.079,z)
    for i in range(4):
        x=.025+i*.065
        path('Flintlock | steel lock scroll',[(x-.025,sign*.075,-.028),(x,sign*.077,-.007),(x+.026,sign*.075,-.027),(x+.01,sign*.076,-.043)],.0022,gold_dark)
    screw('Flintlock | grip pin',-.23,sign*.076,-.275,gold,.012)
# Barrel is a lathed hollow mesh; the muzzle opening has real wall thickness.
barrel_sections=[(-.07,.070),(.02,.066),(.20,.061),(.51,.054),(.80,.051),(1.05,.052),(1.11,.064),(1.16,.064)]
verts=[];N=48;zc=.092
for x,r in barrel_sections:verts += [(x,r*math.cos(i*math.tau/N),zc+r*math.sin(i*math.tau/N)) for i in range(N)]
faces=[tuple(reversed(range(N)))];ids=[0]
for j in range(len(barrel_sections)-1):
    for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i));ids.append(0)
start=len(verts)
for x in [1.16,.90]:verts += [(x,.042*math.cos(i*math.tau/N),zc+.042*math.sin(i*math.tau/N)) for i in range(N)]
last=(len(barrel_sections)-1)*N
for i in range(N):
    faces.append((last+i,last+(i+1)%N,start+(i+1)%N,start+i));ids.append(1)
    faces.append((start+i,start+(i+1)%N,start+N+(i+1)%N,start+N+i));ids.append(2)
faces.append(tuple(range(start+N,start+2*N)));ids.append(2)
ob=mesh('Flintlock | tapered brass barrel with open bore',verts,faces,[gold,gold_light,black],ids)
for p in ob.data.polygons:p.use_smooth=True
for x in [-.055,.045,.25,.89,1.07,1.145]:
    r=.073 if x<.07 else (.064 if x>1.05 else .060 if x<.4 else .058)
    cylinder('Flintlock | barrel turned band',(x-.009,0,zc),(x+.009,0,zc),r,gold_light)
for sign in [-1,1]:
    for i in range(7):
        x=.28+i*.095
        path('Flintlock | barrel vine engraving',[(x-.028,sign*.052,.105),(x,sign*.055,.122),(x+.025,sign*.052,.101)],.0019,gold_dark)
# Ramrod is tucked beneath the forestock; fittings have real separate meshes.
cylinder('Flintlock | walnut ramrod',(.26,0,-.078),(1.045,0,-.078),.013,wood,20)
for x in [.33,.81]:cylinder('Flintlock | ramrod brass pipe',(x-.018,0,-.078),(x+.018,0,-.078),.022,gold)
cylinder('Flintlock | ramrod tip',(.99,0,-.078),(1.06,0,-.078),.015,gold_dark)
# Visible traditional lock mechanism, shaped as separate editable steel plates.
y=-.097
plate('Flintlock | S shaped cock',[(-.095,-.018),(-.145,.035),(-.13,.105),(-.075,.162),(-.081,.24),(-.055,.275),(-.012,.265),(.006,.231),(-.028,.207),(-.026,.158),(-.055,.105),(-.060,.049),(-.024,.013)],.030,steel,y,.006)
screw('Flintlock | cock pivot',-.075,y-.024,.001,steel,.035)
screw('Flintlock | upper jaw screw',-.042,y-.023,.246,steel,.013)
plate('Flintlock | flint jaw',[(-.048,.181),(.035,.19),(.032,.213),(-.048,.204)],.038,dark,y,.003)
plate('Flintlock | flint stone',[(.006,.185),(.069,.193),(.048,.21),(.012,.211)],.029,steel,y,.001)
plate('Flintlock | frizzen steel',[ (.16,.065),(.18,.12),(.155,.195),(.16,.26),(.19,.282),(.205,.271),(.184,.243),(.185,.197),(.21,.12),(.205,.07)],.041,steel,-.065,.005)
ellipsoid('Flintlock | powder pan',(.105,-.069,.092),(.063,.035,.021),gold_dark)
path('Flintlock | frizzen spring',[(.155,-.097,.007),(.23,-.098,.012),(.268,-.095,.047),(.22,-.092,.068)],.008,steel)
path('Flintlock | brass trigger guard',[(-.14,0,-.10),(-.11,0,-.24),(.015,0,-.26),(.16,0,-.205),(.17,0,-.081)],.014,gold)
path('Flintlock | curved steel trigger',[(.035,0,-.086),(.026,0,-.14),(-.005,0,-.195),(.017,0,-.203)],.010,steel)
gun_parts=parts[gun_start:]

def root_for(name, objects):
    ob=bpy.data.objects.new(name,None);scene.collection.objects.link(ob)
    ob.empty_display_type='ARROWS';ob.empty_display_size=.12
    for part in objects:part.parent=ob
    return ob

sword=root_for('Cutlass | editable assembly',sword_parts)
gun=root_for('Flintlock | editable assembly',gun_parts)
sword['design_grip_point']=(.26,0,0)
gun['design_grip_point']=(-.20,0,-.22)
sword.location=(.35,0,.83)
gun.location=(-.50,0,-.28)
gun.rotation_euler.y=math.radians(-7)

# Studio objects live separately from weapon collections for clean editing/export.
current=collection('STUDIO | cameras and lighting')
for name,loc,power,size,tint in [
    ('Key | large warm softbox',(-2,-4,5),800,5,(1,.87,.70)),
    ('Fill | cool silver',(3,-2,2),600,4,(.69,.82,1)),
    ('Rim | gold backlight',(-.2,3,3.5),1100,3,(1,.77,.47))]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object;light.name=name;add(light)
    light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.data.color=tint
    light.rotation_euler=(Vector((0,0,.4))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(-.25,-6,2.0))
cam=bpy.context.object;cam.name='Camera | weapon presentation';add(cam)
cam.data.type='ORTHO';scene.camera=cam

def camera(target,location,scale,width=1800,height=1200):
    cam.location=location;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=scale;scene.render.resolution_x=width;scene.render.resolution_y=height

def render(name,target,location,scale,width=1800,height=1200):
    camera(target,location,scale,width,height)
    if scene.get('idle_arm_pose_source'):size_module.fit_camera(scene)
    scene.render.filepath=str(QA/name);bpy.ops.render.render(write_still=True)

def viewport():
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.shading.type='MATERIAL'
    bpy.ops.object.select_all(action='DESELECT')
    sword.select_set(True);gun.select_set(True);bpy.context.view_layer.objects.active=sword

camera((-.30,0,.27),(-.50,-7,1.6),3.3,1800,1500)
notes=bpy.data.texts.new('START HERE | Pirate weapon draft')
notes.write('PIRATE WEAPONS | Blender-first art review\n\n'
            'CUTLASS: swept silver blade, gold wave inlay, brass octopus guard, leather grip.\n'
            'FLINTLOCK: curved walnut stock, brass barrel with hollow muzzle, forged steel lock.\n\n'
            'Parts, curves, materials, and bevel modifiers remain editable in named collections.\n'
            'The companion pirate_equipped_preview.blend shows the weapons at native hand sockets.\n'
            'Standalone studio scale differs from the character fit; grip points are custom properties.\n'
            'Live character assets and Goemon.app are untouched.\n\n'
            'Rebuild: Blender -b --python tools/build_pirate_weapons.py\n'
            'Renders and verification: build/Other Files/Pirate Weapons/\n')
viewport()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pirate_weapons.blend'))
render('pirate-weapons.png',(-.30,0,.27),(-.50,-7,1.6),3.3,1800,1500)
bpy.data.collections['FLINTLOCK | walnut brass and forged lock'].hide_render=True
render('cutlass-detail.png',(-.34,0,.87),(-.45,-6,2),2.75,1800,1050)
bpy.data.collections['FLINTLOCK | walnut brass and forged lock'].hide_render=False
bpy.data.collections['CUTLASS | silver tide and brass kraken'].hide_render=True
render('flintlock-detail.png',(.0,0,-.30),(.15,-5,1.15),2.0,1800,1100)
bpy.data.collections['CUTLASS | silver tide and brass kraken'].hide_render=False

def fingerprint(ob):
    data={'parent':ob.parent.name if ob.parent else None,'matrix':[list(r) for r in ob.matrix_local]}
    if ob.type=='MESH':
        data.update(vertices=[list(v.co) for v in ob.data.vertices],faces=[list(p.vertices) for p in ob.data.polygons],
                    uv=[[list(v.uv) for v in layer.data] for layer in ob.data.uv_layers],
                    weights=[[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices])
    if ob.type=='ARMATURE':data['bones']=[(b.name,list(b.head_local),list(b.tail_local)) for b in ob.data.bones]
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()

# Append the existing pirate for a fit preview; retain all non-weapon objects exactly.
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.objects=src.objects
character=[ob for ob in dst.objects if ob]
char_collection=collection('PIRATE | original character with draft equipment')
for ob in character:char_collection.objects.link(ob)
bpy.context.view_layer.update()
protected={ob.name:fingerprint(ob) for ob in character if not ob.name.startswith('Weapon_')}
roots={name:bpy.data.objects[name] for name in ['Weapon_Cutlass','Weapon_Pistol']}
grips={name:[list(r) for r in ob.matrix_world] for name,ob in roots.items()}
for name in ['Weapon_Cutlass_Geometry','Weapon_Pistol_Geometry']:
    bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
# Transform design geometry into existing native local weapon axes.
blade_axis=Vector((-.48,0,.877)).normalized()
sx=-blade_axis
sy=Vector((0,1,0));sz=sx.cross(sy)
sword_basis=Matrix(((sx.x,sy.x,sz.x,0),(sx.y,sy.y,sz.y,0),(sx.z,sy.z,sz.z,0),(0,0,0,1)))
gun_basis=Matrix(((0,1,0,0),(-1,0,0,0),(0,0,1,0),(0,0,0,1)))
for parent,objects,basis,size,grip in [(roots['Weapon_Cutlass'],sword_parts,sword_basis,.39,(.26,0,0)),
                                      (roots['Weapon_Pistol'],gun_parts,gun_basis,.47,(-.20,0,-.22))]:
    for ob in objects:
        local=ob.matrix_basis.copy()
        ob.parent=parent
        ob.matrix_basis=basis @ Matrix.Scale(size,4) @ Matrix.Translation(-Vector(grip)) @ local
bpy.data.objects.remove(sword,do_unlink=True);bpy.data.objects.remove(gun,do_unlink=True)
assert {name:fingerprint(bpy.data.objects[name]) for name in protected}==protected,'Non-weapon pirate data changed'
assert all([list(r) for r in roots[name].matrix_world]==m for name,m in grips.items()),'Native grip moved'
# The character source stores the arm mesh in a T-pose while native equipment
# sockets use the standard 75-degree lowered-arm pose (same as roster reviews).
rig=bpy.data.objects['Reference_Rig']
for side,sign in [('L',-1),('R',1)]:
    bone=rig.pose.bones['Arm_'+side]
    point=bone.bone.head_local
    turn=Matrix.Translation(point) @ Matrix.Rotation(sign*math.radians(75),4,'Y') @ Matrix.Translation(-point)
    bone.matrix=turn @ bone.bone.matrix_local
bpy.context.view_layer.update()
spec=importlib.util.spec_from_file_location('pirate_idle',ROOT/'tools/pose_pirate_explorer_idle.py')
idle_module=importlib.util.module_from_spec(spec);spec.loader.exec_module(idle_module)
idle_report=idle_module.apply_idle_arm_pose(rig,roots)
spec=importlib.util.spec_from_file_location('pirate_sizes',ROOT/'tools/pirate_weapon_sizes.py')
size_module=importlib.util.module_from_spec(spec);spec.loader.exec_module(size_module)
size_module.apply_scene_sizes(scene)
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:
        try: im.pack()
        except RuntimeError:pass
camera((0,0,1.65),(4,-7,3.5),4.4,1500,1500)
size_module.fit_camera(scene)
scene['status']='Character fit preview only; original pirate geometry, UVs, skeleton and native grip transforms preserved.'
bpy.ops.object.select_all(action='DESELECT')
for ob in sword_parts+gun_parts:ob.select_set(True)
bpy.context.view_layer.objects.active=sword_parts[0]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pirate_equipped_preview.blend'))
render('pirate-equipped-three-quarter.png',(0,0,1.65),(4,-7,3.5),4.4,1500,1500)
render('pirate-equipped-front.png',(0,0,1.65),(0,-7,2.3),4.3,1500,1500)
render('pirate-equipped-side.png',(0,0,1.65),(7,0,2.3),4.3,1500,1500)
render('pirate-equipped-back.png',(0,0,1.65),(0,7,2.3),4.3,1500,1500)
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in BEFORE.items()),'Live assets changed'
report={'live_asset_hashes_unchanged':True,'character_geometry_uv_weights_and_bones_unchanged':True,
        'native_grip_transforms_preserved':True,'editable_weapon_objects':len(sword_parts)+len(gun_parts),
        'idle_arms':idle_report,
        'weapon_sizes':{'sword':size_module.SIZES['Weapon_Cutlass'][1],'gun':size_module.SIZES['Weapon_Pistol'][1]},
        'cutlass_objects':len(sword_parts),'flintlock_objects':len(gun_parts),
        'sources':[str(OUT/'pirate_weapons.blend'),str(OUT/'pirate_equipped_preview.blend')],
        'status':'Blender draft only; no game integration or app export.'}
(QA/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('PIRATE_WEAPONS_VERIFIED',json.dumps(report))

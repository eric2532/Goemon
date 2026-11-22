"""Initial solid travel-stone kit. Refuses to overwrite the editable master.
Edit the saved .blend and use tools/export_blender.py for subsequent exports.
"""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import build_wind_meadow_buildings as kit

SOURCE = ROOT/'assets/blender/environments/wind_meadow/travel_stones/travel_stone_kit.blend'
assert not SOURCE.exists(), 'Preserve artist edits: export the saved master instead of rebuilding it.'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1
image = bpy.data.images.load(str(ROOT/'assets/textures/wind_meadow/travel_stones/surface_paint.png'))
image.pack()
material = kit.painted_material(image)
material.name = 'Recovered bronze, stone and inscriptions'
material.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value = .32
material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .72
kit.MATERIAL = material
kit.groups.clear()
# The shared helper uses a four-by-four atlas. Remap its V coordinates to two rows.
def finish(obj):
    for uv in obj.data.uv_layers.active.data:
        uv.uv.y = 1-uv.uv.y*2
    return obj

def box(name,p,size,slot,group,bevel=.025):
    return finish(kit.box(name,p,size,slot,bevel,group))

def custom(name,verts,faces,slot,group):
    return finish(kit.custom(name,verts,faces,slot,group))

def cylinder(name,p,radius,height,slot,group,top=None,sides=24):
    bpy.ops.mesh.primitive_cone_add(vertices=sides,radius1=radius,radius2=radius if top is None else top,depth=height,location=p)
    return finish(kit.finish(bpy.context.object,name,slot,group))

def profile(name,levels,slot,group):
    verts=[(x*w/2,y*w/2,z) for z,w in levels for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    faces=[(3,2,1,0)]
    for j in range(len(levels)-1):
        for i in range(4):faces.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
    faces.append(tuple(range((len(levels)-1)*4,len(levels)*4)))
    return custom(name,verts,faces,slot,group)

def pedestal(group,width=1.4,height=1.25,offset=(0,0),carving=0):
    obj=profile('Flared carved pedestal',[(0,width),(.09*height,width),(.16*height,width*.90),(.23*height,width*.82),(.38*height,width*.65),(.68*height,width*.58),(.81*height,width*.78),(.89*height,width*.96),(height,width)],carving,group)
    obj.location.x,obj.location.y=offset
    for z,w,h,slot in [(.05,1,.06,2),(.15,.92,.045,1),(.81,.79,.055,1),(.95,1.07,.10,1)]:
        box('Molded gold course',(offset[0],offset[1],z*height),(width*w,width*w,height*h),slot,group)
    # Raised corner straps make the carved pedestal read in profile as well as from the source view.
    for x in [-1,1]:
        for y in [-1,1]:
            for z,r in [(.28,.075),(.36,.065),(.72,.055)]:
                cylinder('Corner scroll',(offset[0]+x*width*.32,offset[1]+y*width*.32,height*z),width*r,height*.10,1,group,sides=12)

# One solid crescent shared by all four original orientations.
pedestal('Crescent')
cylinder('Lower collar',(0.22,0,1.30),.43,.12,2,'Crescent')
cylinder('Gold collar',(0.22,0,1.38),.46,.09,1,'Crescent',top=.40)
cylinder('Stone seat',(0.22,0,1.46),.37,.12,3,'Crescent')
verts=[];faces=[]
sections=64
cross=[(0,0),(.10,-.16),(.48,-.24),(.90,-.11),(1,0),(.90,.11),(.48,.24),(.10,.16)]
for i in range(sections+1):
    t=i/sections
    angle=math.radians(72+216*t)
    z=2.05*math.sin(angle)
    outer=1.45*math.cos(angle)
    inner=.90-1.46*math.sqrt(max(0,1-(z/2.05)**2))
    width=max(.002,inner-outer)
    taper=max(.015,math.sin(math.pi*t)**.55)
    for u,y in cross:verts.append((outer+u*width,y*taper,z+3.47))
for j in range(sections):
    for k in range(8):faces.append((j*8+k,j*8+(k+1)%8,(j+1)*8+(k+1)%8,(j+1)*8+k))
faces.extend([tuple(reversed(range(8))),tuple(range(sections*8,(sections+1)*8))])
moon=custom('Thick curved stone crescent',verts,faces,3,'Crescent')
for face in moon.data.polygons:face.use_smooth=True

# The corner post has a carved square foot, a ringed stem and a hollow cup, not a ball finial.
pedestal('Post',.76,.80,carving=4)
cylinder('Post shoulder',(0,0,.88),.25,.17,1,'Post',top=.21)
for z,r,h,top in [(.99,.20,.12,.18),(1.13,.18,.17,.16),(1.34,.16,.28,.145),(1.57,.145,.18,.16),(1.75,.16,.18,.19),(1.94,.19,.19,.24)]:
    cylinder('Turned bronze stem',(0,0,z),r,h,7,'Post',top=top,sides=16)
for z,r in [(.94,.245),(1.07,.21),(1.23,.19),(1.48,.175),(1.64,.20),(1.87,.22)]:
    cylinder('Gold stem band',(0,0,z),r,.055,1,'Post',sides=24)
# Closed manifold rim with an actual recessed opening.
rv=[];rf=[]
for z,r in [(1.99,.24),(2.13,.26),(2.19,.22),(2.19,.135),(2.08,.12),(2.045,.01)]:
    for i in range(24):
        a=2*math.pi*i/24;rv.append((r*math.cos(a),r*math.sin(a),z))
for j in range(5):
    for i in range(24):rf.append((j*24+i,j*24+(i+1)%24,(j+1)*24+(i+1)%24,(j+1)*24+i))
rf.extend([tuple(reversed(range(24))),tuple(range(120,144))])
custom('Open cup crown',rv,rf,1,'Post')

# Original paired inscription stands, with separately pitched carved stone tablets.
for x,y,w,h,slot in [(.30,.20,1.22,1.40,5),(-.40,-.10,.82,.83,6)]:
    pedestal('Lectern',w,h,(x,y))
    cap=box('Sloped tablet surround',(x,y,h+.06),(w*1.12,w*.82,.23),1,'Lectern')
    cap.rotation_euler.x=math.radians(12)
    plate=box('Original inscription tablet',(x,y,h+.20),(w*.92,w*.66,.12),3,'Lectern',.018)
    plate.rotation_euler.x=math.radians(12)
    for face in plate.data.polygons:
        if face.normal.z>.9:
            for li in face.loop_indices:
                uv=plate.data.uv_layers.active.data[li]
                co=plate.data.vertices[plate.data.loops[li].vertex_index].co
                u=co.x/(w*.92)+.5;v=co.y/(w*.66)+.5
                uv.uv=((slot%4+.03+u*.94)/4,1-(slot//4+.03+v*.94)/2)

# Opaque square bipyramid; the game rotates the existing vertices/normals in its shared material.
cv=[(0,0,1.30),(1.18,0,0),(0,1.18,0),(-1.18,0,0),(0,-1.18,0),(0,0,-1.23)]
cf=[]
for i in range(4):cf.extend([(0,1+i,1+(i+1)%4),(5,1+(i+1)%4,1+i)])
crystal=custom('Crystal',cv,cf,3,'Crystal')
crystal_material=bpy.data.materials.new('Cyan crystal facets');crystal_material.diffuse_color=(.35,.78,1,1)
crystal_material.use_nodes=True
bs=crystal_material.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.35,.78,1,1);bs.inputs['Roughness'].default_value=.25
crystal.data.materials.clear();crystal.data.materials.append(crystal_material)

# Each named part is a single editable, closed 3D mesh; repeated city placements share its export.
for group,objects in kit.groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();obj=bpy.context.object;obj.name=group
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    obj['source_graphics']='17235-17241' if group!='Crystal' else 'original:3171 action 0'
    obj['contract']='metres; ground pivot; crescent opens +X; crystal belt pivot'
    # Inspect one component collection at a time in Blender; all are exported.
    collection=bpy.data.collections.new(group);bpy.context.scene.collection.children.link(collection)
    for original in list(obj.users_collection):original.objects.unlink(obj)
    collection.objects.link(obj)
SOURCE.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
exec(compile((ROOT/'tools/export_blender.py').read_text(),str(ROOT/'tools/export_blender.py'),'exec'),{'__name__':'__main__','__file__':str(ROOT/'tools/export_blender.py')})

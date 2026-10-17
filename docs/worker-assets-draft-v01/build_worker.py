"""Editable isolated Worker asset. Never loads/writes the live worker or app.
Run Blender -b --python docs/worker-assets-draft-v01/build_worker.py
"""
from pathlib import Path
import bpy,sys,math,json,hashlib
from mathutils import Vector,Matrix
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[1]
sys.path.insert(0,str(ROOT/'tools/enemy_redesign'))
import common as c
c.reset()
scene=bpy.context.scene
parts={}
group='Body'
def register(ob):
    parts.setdefault(group,[]).append(ob)
    ob['worker_asset']=True
    return ob
def sphere(name,center,size,mat,seg=28,rings=18):
    return register(c.uv_sphere(name,center,size,mat,seg,rings))
def loft(name,rings,mat,count=40):return register(c.loft(name,rings,mat,count))
def tube(name,a,b,r,mat,r2=None,count=16):return register(c.tube(name,a,b,r,mat,r2,count))
def curve(name,points,r,mat,res=2):return register(c.curve(name,points,r,mat,res))
def ellipse(name,center,rx,ry,r,mat,count=40,twist=0):
    return register(c.ellipse(name,center,rx,ry,r,mat,count,twist))
def cloth(name,rows,mat,t=.025):return register(c.cloth(name,rows,mat,t))
def box(name,center,size,mat,bevel=.025):return register(c.box(name,center,size,mat,bevel))
M={
    'skin':c.mat('Worker | warm tan skin','ca9d70'),
    'hair':c.mat('Worker | charcoal brown hair','302c26'),
    'teal':c.texture_mat('Worker | painted woven teal',OUT/'textures/worker-teal-cloth.png'),
    'dark_teal':c.mat('Worker | shaded collar edge','36595c'),
    'trousers':c.texture_mat('Worker | woven brown trousers',OUT/'textures/worker-trouser-cloth.png'),
    'linen':c.texture_mat('Worker | natural linen wraps',OUT/'textures/worker-linen.png'),
    'rope':c.mat('Worker | twisted golden flax rope','bda273'),
    'rope_light':c.mat('Worker | rope raised braid','d1bb8d'),
    'straw':c.texture_mat('Worker | straw fibers',OUT/'textures/worker-woven-straw.png'),
    'straw_edge':c.mat('Worker | bound straw hat rim','ccb383'),
    'basket':c.texture_mat('Worker | woven bamboo strips',OUT/'textures/worker-basket-weave.png'),
    'basket_dark':c.mat('Worker | basket interior','765734'),
    'wood':c.mat('Worker | tool handle wood','785940'),
    'leather':c.mat('Worker | brown waist pouch','79624b'),
    'gold':c.mat('Worker | ochre gold cargo','c8a340',.75,.08),
    'gold_light':c.mat('Worker | pale gold facets','e1c36a',.75,.08),
}

# Compact torso with depth, a short neck, and an actual split-hem work jacket.
sphere('Torso rounded volume',(0,0,2.15),(.66,.405,.53),M['teal'])
sphere('Pelvis under tunic',(0,-.015,1.53),(.56,.35,.30),M['trousers'])
loft('Teal working tunic',[(1.40,0,0,.66,.42),(1.54,0,0,.69,.43),
     (1.87,0,0,.61,.39),(2.22,0,0,.64,.41),(2.54,0,0,.61,.37),
     (2.63,0,0,.32,.235)],M['teal'],48)
sphere('Short neck',(0,0,2.65),(.205,.205,.22),M['skin'])
cloth('Cream crossed undershirt',[[(-.265,.335,2.65),(0,.39,2.67),(.265,.335,2.65)],
     [(-.18,.415,2.45),(0,.445,2.44),(.18,.415,2.45)],
     [(-.03,.44,2.28),(0,.445,2.25),(.03,.44,2.28)]],M['linen'],.025)
cloth('Left folded teal lapel',[[(-.41,.31,2.63),(-.27,.37,2.63)],
     [(-.22,.43,2.30),(-.08,.46,2.31)],[(.04,.43,1.97),(.22,.43,1.99)]],M['teal'],.038)
cloth('Right crossing teal lapel',[[(.41,.31,2.63),(.25,.37,2.63)],
     [(.15,.45,2.26),(-.02,.465,2.27)],[(-.33,.42,1.83),(-.48,.36,1.85)]],M['teal'],.038)
curve('Visible collar folded seam',[(.265,.392,2.62),(.10,.472,2.35),(-.10,.477,2.12),(-.40,.407,1.84)],.015,M['dark_teal'])
cloth('Split hem left panel',[[(-.63,.18,1.70),(-.36,.40,1.70),(-.045,.437,1.70)],
     [(-.67,.18,1.39),(-.39,.425,1.37),(-.045,.445,1.40)]],M['teal'])
cloth('Split hem right panel',[[(.045,.437,1.70),(.36,.40,1.70),(.63,.18,1.70)],
     [(.045,.445,1.40),(.39,.425,1.37),(.67,.18,1.39)]],M['teal'])

# Rounded closed skull. All eyes, brows, creases and the frown are UV paint.
group='Head'
face=c.texture_mat('Worker | stern angry painted face',OUT/'textures/worker-angry-face.png')
rings=[]
for i in range(33):
    t=i/32
    rx=math.sin(math.pi*t)**.34*.73
    if t<.30:rx*=.80+.20*t/.30
    ry=math.sin(math.pi*t)**.49*.56
    cy=.015+.055*math.exp(-((t-.38)/.24)**2)
    rings.append((2.55+1.40*t,0,cy,max(.012,rx),max(.012,ry)))
head=loft('Worker_Head_Painted',rings,face,80)
head['face_artwork']=True
for vert in head.data.vertices:
    x,y,z=vert.co;t=(z-2.55)/1.40
    if y>0:
        vert.co.y+=.070*math.exp(-(x/.115)**2-((t-.43)/.085)**2)
        vert.co.y+=.016*math.exp(-(x/.35)**2-((t-.61)/.14)**2)
head.data.update()
for s in [-1,1]:
    sphere('Ear_'+str(s),(s*.69,-.015,3.18),(.13,.105,.185),M['skin'],24,16)
    sphere('Ear inner shade_'+str(s),(s*.724,.064,3.18),(.060,.031,.105),M['leather'],20,12)
    sphere('Hair temple lock_'+str(s),(s*.625,.025,3.39),(.16,.25,.345),M['hair'])
sphere('Hair nape',(0,-.375,3.26),(.635,.235,.47),M['hair'])
sphere('Hair crown',(0,-.07,3.68),(.70,.515,.34),M['hair'])
cloth('Swept forehead hair left',[[(-.61,.325,3.78),(-.34,.52,3.84),(-.05,.56,3.85)],
     [(-.58,.40,3.59),(-.38,.58,3.57),(-.12,.61,3.68)],
     [(-.55,.41,3.54),(-.37,.58,3.56),(-.14,.60,3.67)]],M['hair'],.055)
cloth('Swept forehead hair right',[[(.02,.55,3.84),(.34,.50,3.83),(.59,.32,3.77)],
     [(.11,.60,3.71),(.37,.57,3.57),(.56,.40,3.61)],
     [(.13,.60,3.69),(.38,.56,3.54),(.57,.40,3.57)]],M['hair'],.05)

# Broad but practical conical kasa, with modeled radial reeds and bound edge.
group='Hat'
hatrings=[]
for i in range(13):
    t=i/12
    hatrings.append((3.81+.53*t,0,-.04,1.37*(1-t)+.055*t,1.17*(1-t)+.05*t))
loft('Hat woven conical crown',hatrings,M['straw'],80)
loft('Hat underside',[(3.78,0,-.04,1.36,1.16),(3.81,0,-.04,1.37,1.17)],M['basket_dark'],80)
ellipse('Hat bound brim',(0,-.04,3.795),1.368,1.168,.032,M['straw_edge'],80)
for j in range(36):
    a=j*math.tau/36
    points=[]
    for r in [.09,.29,.54,.82,1.08,1.36]:
        points.append((math.sin(a)*r,math.cos(a)*r*1.17/1.37-.04,3.813+.53*(1-r/1.37)))
    curve('Hat radial straw rib_%02d'%j,points,.007,M['straw_edge'],1)
for t in [.21,.42,.65,.86]:
    r=1.37*(1-t)+.055*t
    ellipse('Hat circular reed stitching',(0,-.04,3.817+.53*t),r,r*1.17/1.37,.008,M['rope'],80)
for s in [-1,1]:
    curve('Hat side tie_'+str(s),[(s*.55,.12,3.70),(s*.67,.08,3.30),(s*.56,.18,2.95)],.014,M['rope'],1)

# Exposed sturdy hands, rolled sleeves and layered linen forearm bindings.
for s,side in [(-1,'L'),(1,'R')]:
    group='Arm_'+side
    a=Vector((s*.60,0,2.43));b=Vector((s*.83,.08,2.04));w=Vector((s*.94,.17,1.68))
    sphere('Teal shoulder_'+side,a,(.29,.30,.32),M['teal'])
    tube('Short work sleeve_'+side,a,b,.27,M['teal'],.25,28)
    arm_axis=(b-a).normalized()
    tube('Sleeve folded cream edge_'+side,b-arm_axis*.105,b+arm_axis*.105,.279,M['linen'],.279,32)
    ring_x=arm_axis.cross(Vector((0,1,0))).normalized()
    ring_y=arm_axis.cross(ring_x).normalized()
    for offset in [-.075,.075]:
        center=b+arm_axis*offset
        curve('Rolled cuff seam_'+side,[tuple(center+.281*(ring_x*math.sin(j*math.tau/40)+ring_y*math.cos(j*math.tau/40))) for j in range(41)],.017,M['linen'],1)
    sphere('Forearm exposed skin_'+side,tuple(b.lerp(w,.42)),(.207,.21,.27),M['skin'])
    tube('Forearm linen wrap_'+side,b.lerp(w,.45),w,.211,M['linen'],.185,24)
    for t in [.47,.61,.75,.89]:
        p=b.lerp(w,t)
        axis=(w-b).normalized();ux=axis.cross(Vector((0,1,0))).normalized();uy=axis.cross(ux).normalized()
        radius=.235-.046*t
        curve('Forearm wrap ridge_'+side,[tuple(p+radius*(ux*math.sin(j*math.tau/32)+uy*math.cos(j*math.tau/32))) for j in range(33)],.014,M['linen'],1)
    sphere('Hand palm_'+side,(s*.95,.23,1.51),(.24,.22,.26),M['skin'])
    for k in range(4):
        sphere('Hand finger_%s_%d'%(side,k),(s*.95-.15+k*.10,.375,1.445),(.064,.083,.117),M['skin'],16,12)
    sphere('Hand thumb_'+side,(s*.77,.32,1.57),(.105,.13,.16),M['skin'],20,14)
    # A small stitched sleeve patch, never armor.
    if s==-1:
        patch=box('Sleeve sewn patch',(s*.85,.185,2.24),(.17,.025,.19),M['dark_teal'],.02)
        patch.rotation_euler.y=-.25
        for k in [-1,0,1]:
            curve('Sleeve patch stitch',[(s*.85+k*.058,.207,2.32),(s*.85+k*.058+.02,.21,2.35)],.007,M['linen'],1)

# Rope waist tie, a small pouch and carefully readable jacket repairs.
group='Body'
for dz in [-.035,.035]:
    ellipse('Double flax waist belt',(0,0,1.83+dz),.665,.445,.045,M['rope'],64,twist=.014)
for strand in range(2):
    points=[]
    for j in range(145):
        a=j*math.tau/144
        points.append((math.sin(a)*(.665+.008*math.cos(a*30+strand*math.pi)),
                       math.cos(a)*(.445+.008*math.cos(a*30+strand*math.pi)),
                       1.83+.040*math.sin(a*30+strand*math.pi)))
    curve('Twisted waist rope braid',points,.011,M['rope_light'],1)
sphere('Waist rope knot',(.13,.472,1.82),(.105,.082,.112),M['rope'])
curve('Hanging belt rope left',[(.10,.48,1.82),(.06,.52,1.62),(.08,.51,1.43)],.034,M['rope'])
curve('Hanging belt rope right',[(.18,.47,1.82),(.28,.51,1.64),(.26,.50,1.51)],.032,M['rope'])
box('Leather belt pouch',(-.48,.40,1.63),(.31,.16,.35),M['leather'],.055)
box('Pouch folded lid',(-.48,.493,1.76),(.30,.045,.12),M['leather'],.023)
for coords in [[(-.51,.523,1.74),(-.46,.526,1.67)],[(-.46,.523,1.74),(-.51,.526,1.67)]]:
    curve('Pouch X stitch',coords,.008,M['linen'],1)
for cx,z,y in [(.42,1.55,.38),(-.36,2.07,.412)]:
    for k in range(4):
        curve('Jacket repair stitch',[(cx-.08+k*.045,y+.025,z-.016),(cx-.055+k*.045,y+.027,z+.031)],.0065,M['linen'],1)

for s,side in [(-1,'L'),(1,'R')]:
    group='Leg_'+side
    sphere('Rounded trouser thigh_'+side,(s*.345,0,1.19),(.335,.33,.40),M['trousers'])
    sphere('Work trouser knee_'+side,(s*.365,.015,.99),(.282,.285,.24),M['trousers'])
    loft('Sturdy linen shin_'+side,[(.34,s*.37,.015,.20,.22),(.43,s*.37,.015,.235,.245),
         (.64,s*.37,.015,.23,.23),(.85,s*.37,.015,.22,.23),(.94,s*.37,.015,.20,.22)],M['linen'],32)
    for z in [.40,.52,.64,.76,.86]:
        rx=.236 if z<.66 else .225
        ellipse('Shin wrap ridge_'+side,(s*.37,.015,z),rx,.245 if z<.55 else .237,.017,M['linen'],32,twist=s*.012)
    sphere('Sandal woven sole_'+side,(s*.39,.16,.105),(.345,.455,.085),M['basket'],32,16)
    sphere('Bare foot_'+side,(s*.39,.18,.25),(.285,.365,.17),M['skin'])
    for k in range(4):
        sphere('Toe_%s_%d'%(side,k),(s*.39-.165+k*.11,.47,.25),(.069,.10,.09),M['skin'],16,10)
    curve('Sandal flax V strap_'+side,[(s*.39-.24,.07,.37),(s*.39,.44,.33),(s*.39+.24,.07,.37)],.042,M['rope'])
    for j in range(16):
        a=j*math.tau/16
        x=s*.39+.326*math.sin(a);y=.16+.432*math.cos(a)
        curve('Sandal edge reed stitch',[(x,y,.075),(x,y,.139)],.012,M['rope'],1)
    # Rounded-cloth patches with actual stitch threads.
    patch=box('Trouser knee patch_'+side,(s*.46,.284,1.13),(.145,.025,.17),M['leather'],.02)
    patch.rotation_euler.y=-s*.2
    for k in range(3):
        curve('Trouser patch stitch',[(s*.46-.045+k*.045,.304,1.20),(s*.46-.03+k*.045,.308,1.23)],.006,M['linen'],1)

# A hollow basket, physically woven ribs, shoulder ropes and separate gold cargo.
group='Basket'
loft('Bamboo basket closed base',[(1.31,0,-.72,.53,.295),(1.38,0,-.72,.56,.315)],M['basket_dark'],48)
def basket_shell(u,v):
    a=u*math.tau
    rx=.53+.13*v;ry=.30+.08*v
    return (math.sin(a)*rx,-.72+math.cos(a)*ry,1.35+1.36*v)
shell=register(c.surface('Woven basket shell',basket_shell,M['basket'],56,12))
mod=shell.modifiers.new('Bamboo wall thickness','SOLIDIFY');mod.thickness=.035
bpy.context.view_layer.objects.active=shell;bpy.ops.object.modifier_apply(modifier=mod.name)
for z,rx,ry in [(1.37,.55,.32),(1.80,.59,.343),(2.24,.63,.367),(2.70,.668,.388)]:
    ellipse('Basket horizontal bound cane',(0,-.72,z),rx,ry,.029 if z<2.65 else .040,M['rope'],56)
for j in range(20):
    a=j*math.tau/20
    points=[]
    for t in [0,.25,.50,.75,1]:
        points.append((math.sin(a)*(.548+.126*t),-.72+math.cos(a)*(.316+.075*t),1.36+1.35*t))
    curve('Basket raised vertical bamboo rib_%02d'%j,points,.016,M['straw_edge'],1)
ellipse('Basket open inner rim',(0,-.72,2.68),.625,.345,.022,M['basket_dark'],56)
for s in [-1,1]:
    curve('Basket front shoulder rope_'+str(s),[(s*.49,-.64,2.62),(s*.50,-.24,2.66),
          (s*.48,.26,2.55),(s*.49,.43,2.25),(s*.54,.415,1.94),(s*.60,.13,1.72),
          (s*.57,-.45,1.50)],.047,M['rope'],2)
    for k in range(9):
        t=k/8
        sphere('Strap rope twist', (s*(.485+.045*t),.439,2.46-.44*t),(.048,.027,.037),M['rope_light'],12,8)
    curve('Basket back vertical rope_'+str(s),[(s*.37,-1.12,2.72),(s*.35,-1.10,2.19),
          (s*.31,-1.07,1.71),(s*.29,-1.04,1.35)],.035,M['rope'],1)
group='Gold_Cargo'
for i,(x,y,z,s) in enumerate([(-.35,-.72,2.70,.20),(-.08,-.75,2.77,.23),(.24,-.70,2.71,.20),
         (-.23,-.91,2.78,.20),(.12,-.96,2.83,.21),(.35,-.83,2.73,.17),(-.04,-.56,2.73,.16)]):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,z))
    ob=bpy.context.object;ob.scale=(s,s*.85,s*.65);ob.rotation_euler=(i*.37,i*.22,i*.71)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    c.finish(ob,'Cargo_gold_nugget_%02d'%i,M['gold'] if i%2 else M['gold_light'],False)
    register(ob)

# Standalone pickaxe for later posing. Stored separately, not held in the review.
group='Pickaxe'
tube('Pickaxe wood shaft',(1.5,.15,.12),(1.5,.15,1.67),.047,M['wood'],.05,16)
iron=c.mat('Worker | worn pick iron','626b69',.87,.15)
curve('Pickaxe forged curved head',[(1.08,.15,1.56),(1.28,.15,1.69),(1.50,.15,1.73),
      (1.77,.15,1.68),(1.98,.15,1.55)],.055,iron,2)
for z in [1.53,1.59,1.65]:
    ellipse('Pickaxe bound socket',(1.5,.15,z),.067,.067,.017,M['rope'],24)

# Optimize rounded sculpt tessellation, then batch by actual movable part.
for key,objects in parts.items():
    for ob in objects:
        tri=sum(len(p.vertices)-2 for p in ob.data.polygons)
        if tri>180:
            mod=ob.modifiers.new('Game asset tessellation','DECIMATE')
            mod.ratio=.75 if ob==head else (.65 if ob.name.startswith('Hat woven') else .40)
            bpy.context.view_layer.objects.active=ob
            bpy.ops.object.modifier_apply(modifier=mod.name)
# One draft root and practical rigid-part pivots, preserving editable materials/UVs.
root=bpy.data.objects.new('Worker_Draft',None);scene.collection.objects.link(root)
root['status']='ASSET DRAFT ONLY; NO GAME IMPLEMENTATION'
root['face']='Painted angry brows, narrowed eyes, furrow lines and downturned mouth'
pivots={'Body':(0,0,1.85),'Head':(0,0,2.65),'Hat':(0,0,3.78),
        'Arm_L':(-.60,0,2.43),'Arm_R':(.60,0,2.43),
        'Leg_L':(-.345,0,1.45),'Leg_R':(.345,0,1.45),
        'Basket':(0,-.72,1.35),'Gold_Cargo':(0,-.72,2.70),'Pickaxe':(1.5,.15,.92)}
meshes=[]
for key,objects in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    ob=bpy.context.object;ob.name='Worker_'+key+'_Geometry'
    scene.cursor.location=pivots[key];bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    pivot=bpy.data.objects.new('Worker_'+key,None);scene.collection.objects.link(pivot)
    pivot.location=pivots[key];pivot.parent=root
    bpy.context.view_layer.update()
    world=ob.matrix_world.copy();ob.parent=pivot;ob.matrix_world=world
    bpy.context.view_layer.update()
    ob['worker_asset']=True;ob['draft_group']=key
    if 'enemy_asset' in ob:del ob['enemy_asset']
    meshes.append(ob)
scene.cursor.location=(0,0,0)
character=[ob for ob in meshes if ob['draft_group']!='Pickaxe']
lo,hi=c.bounds(character);target=3.0;scale=target/(hi[2]-lo[2])
root.scale=(scale,)*3;root.location.z=-lo[2]*scale
bpy.context.view_layer.update()
# Pickaxe is a separate optional prop. Export it independently at the same scale.
pick=next(ob for ob in meshes if ob['draft_group']=='Pickaxe')
pick_root=pick.parent
bpy.ops.object.select_all(action='DESELECT');pick_root.select_set(True);pick.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'export/worker-pickaxe.glb'),export_format='GLB',
    use_selection=True,export_animations=False,export_skins=False,export_extras=True)
pick_root.hide_render=True;pick.hide_render=True
pick_root.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
for ob in character:ob.parent.select_set(True);ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'export/worker-angry-draft.glb'),export_format='GLB',
    use_selection=True,export_animations=False,export_skins=False,export_extras=True)
# Clean studio, equal cameras and scale for all requested views.
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world=bpy.data.worlds.new('Worker neutral studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.32,.30,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
scene.view_settings.view_transform='AgX'
floor_mat=c.mat('Studio | warm light gray','cfcec6')
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.008))
floor=bpy.context.object;floor.name='Preview_Ground';floor.data.materials.append(floor_mat)
for i,(loc,power,size) in enumerate([((4,5,7),500,5),((-4,3,4),350,4),((0,-4,6),600,4)]):
    bpy.ops.object.light_add(type='AREA',location=loc);ob=bpy.context.object;ob.name='Preview_Light_'+str(i)
    ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size;c.aim(ob,(0,0,1.5))
bpy.ops.object.camera_add();camera=bpy.context.object;camera.name='Preview_Camera'
camera.data.type='ORTHO';camera.data.ortho_scale=3.56;scene.camera=camera
focus=Vector((0,-.07,1.50))
views={'front':(0,10,0),'side':(-10,0,0),'back':(0,-10,0),'three-quarter':(7,10,1.0)}
for view,offset in views.items():
    camera.location=focus+Vector(offset);c.aim(camera,focus)
    scene.render.filepath=str(OUT/'renders'/('worker-'+view+'.png'))
    bpy.ops.render.render(write_still=True)
camera.location=Vector((0,9,2.24));c.aim(camera,(0,0,2.24));camera.data.ortho_scale=1.30
scene.render.filepath=str(OUT/'renders/worker-angry-face-detail.png');bpy.ops.render.render(write_still=True)
camera.location=focus+Vector((7,10,1.0));c.aim(camera,focus);camera.data.ortho_scale=3.56
for im in bpy.data.images:
    if im.source=='FILE':
        im.pack();im.filepath='//../textures/'+Path(im.filepath).name
scene['worker_review']='Approved straw-hat/teal worker with sterner painted face. Draft assets only.'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/worker-angry-draft.blend'))
lo,hi=c.bounds(character)
report={'status':'ASSET DRAFT ONLY — NOT IMPLEMENTED','height':hi[2]-lo[2],
        'bounds_min':lo,'bounds_max':hi,'height_vs_goemon':(hi[2]-lo[2])/c.HEIGHT,
        'source':'source/worker-angry-draft.blend','export':'export/worker-angry-draft.glb',
        'optional_prop':'export/worker-pickaxe.glb','rigging':'Named rigid-part pivots, no skeletal animation',
        'mesh_groups':[ob.name for ob in character],
        'triangles':sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in character),
        'face':'Angry eyebrows, narrowed eyes and frown painted directly on closed 3D skull; integrated nose',
        'live_implementation':False}
(OUT/'asset-report.json').write_text(json.dumps(report,indent=2))
print('WORKER_DRAFT_COMPLETE',json.dumps(report))

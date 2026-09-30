"""Original N64-inspired environment kit. Never touches character or legacy sources.
Blender --background --python tools/build_edo_environment.py
Existing authored sources require --replace to regenerate; normal edits use export_blender.py.
"""
import bpy, math, random, sys, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/blender/edo'; OUT=ROOT/'assets/models/edo'; TEX=ROOT/'assets/textures/edo'
for p in (SRC,OUT,TEX):p.mkdir(parents=True,exist_ok=True)
if list(SRC.glob('*.blend')) and '--replace' not in sys.argv:raise RuntimeError('Authored sources exist. Use export_blender.py, or explicitly pass --replace.')
R=random.Random(641997)
COLORS={'wood':'96532d','plaster':'e8ddb6','tile':'354e70','stone':'ac9469','grass':'72ad3f','sand':'dcc184','cherry':'ed91bd','leaf':'539238','palm':'70a541','paper':'ffe0a0','red':'d74632','blue':'315d9a','jade':'5caeae','ochre':'bd8449','rock':'a58b60','crag':'668c85'}
textures={}; mats={}
def field(x,y,cell,seed):
    gx,gy=int(x//cell),int(y//cell);fx=(x%cell)/cell;fy=(y%cell)/cell
    fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
    def at(a,b):return random.Random(((a%(128//cell))*73856093)^((b%(128//cell))*19349663)^seed).uniform(-1,1)
    return (at(gx,gy)*(1-fx)+at(gx+1,gy)*fx)*(1-fy)+(at(gx,gy+1)*(1-fx)+at(gx+1,gy+1)*fx)*fy
fields={(x,y):(.10*field(x,y,16,17)+.055*field(x,y,8,93)+.025*field(x,y,4,287)) for y in range(128) for x in range(128)}
for name,h in COLORS.items():
    base=[int(h[i:i+2],16)/255 for i in (0,2,4)]; pixels=[]
    for y in range(128):
        for x in range(128):
            grain=R.uniform(-.035,.035)
            v=1+grain
            if name=='wood':
                v+=.11*math.sin(x*.7+math.sin(y*.12)*1.3)+.04*math.sin(x*2.3+y*.04)
                if x%32<2:v-=.24
                if (x+int(2*math.sin(y*.1)))%31==3:v+=.13
            elif name=='tile':
                v+=.19*math.sin((x%16)/16*math.pi)
                if x%16<2 or y%32<3:v-=.25
                if y%32==4:v+=.32
            elif name in ('stone','jade','ochre'):
                row=y//32;xx=(x+(row%2)*16)%64
                v+=.06*math.sin(x*.17+y*.24)
                if y%32<2 or xx<2:v-=.26
                elif y%32<5 or xx<5:v+=.15
            elif name in ('leaf','cherry','palm'):
                v+=fields[x,y]*2.0
                if R.random()<.10:v+=.13
            elif name=='grass':v+=fields[x,y]+R.uniform(-.025,.025)
            elif name=='sand':v+=fields[x,y]*.65
            elif name in ('rock','crag'):v+=fields[x,y]*2+.03*math.sin(x*.14+y*.21)
            elif name=='paper':
                if y%16<2:v-=.12
            elif name=='blue':
                if x%32 in (0,1):v-=.18
            else:v+=.02*math.sin(x*.22+y*.3)
            values=[max(0,min(1,c*v)) for c in base]
            pixels.extend([c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in values]+[1])
    img=bpy.data.images.new('Edo_'+name,128,128,alpha=True);img.pixels=pixels
    img.filepath_raw=str(TEX/(name+'.png'));img.file_format='PNG';img.save();img.pack();textures[name]=img

def mat(name):
    if name in mats:return mats[name]
    m=bpy.data.materials.new('Edo_'+name);m.use_nodes=True
    n=m.node_tree.nodes;bs=n.get('Principled BSDF');bs.inputs['Roughness'].default_value=.95
    tx=n.new('ShaderNodeTexImage');tx.image=textures[name];tx.interpolation='Closest'
    m.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color']);mats[name]=m
    return m

def cv(p):return Vector((p[0],-p[2],p[1]))
def finish(o,name,material):
    o.name=name;o.data.materials.append(mat(material))
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return o

def box(name,p,size,m):
    bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);return finish(o,name,m)
def beam(name,a,b,r,m,r2=None):
    a,b=cv(a),cv(b);bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=r,radius2=r if r2 is None else r2,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=(b-a).to_track_quat('Z','Y');return finish(o,name,m)
def ell(name,p,size,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=.5,location=cv(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);return finish(o,name,m)
def mesh(name,verts,faces,m):
    d=bpy.data.meshes.new(name);d.from_pydata([cv(v) for v in verts],[],faces);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.data.materials.append(mat(m));return o

def start():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1

def save(name):
    # Two mesh groups for trees retain the game's existing canopy fade/wind hook.
    for group in ('Body','Canopy'):
        obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and (o.name.startswith('Canopy') if group=='Canopy' else not o.name.startswith('Canopy'))]
        if not obs:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs:o.select_set(True)
        bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=group
        bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        # Box projection at metre scale produces legible painted repeats instead of tiny islands.
        uv=o.data.uv_layers.new(name='UVMap') if not o.data.uv_layers else o.data.uv_layers.active
        for p in o.data.polygons:
            axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=axis]
            for li in p.loop_indices:
                co=o.matrix_world @ o.data.vertices[o.data.loops[li].vertex_index].co
                uv.data[li].uv=(co[axes[0]]*.65,co[axes[1]]*.65)
    bpy.context.scene['authoring_note']='Original environmental art, metres, Godot Y-up export. Character sources excluded.'
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False)
    manifest=ROOT/'assets/models/manifest.json'
    entries=json.loads(manifest.read_text()) if manifest.exists() else []
    entries=[e for e in entries if e['asset']!='edo/'+name]
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    entries.append({'asset':'edo/'+name,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs),'meshes':len(obs),'surfaces':sum(len(o.data.materials) for o in obs),'bytes':(OUT/(name+'.glb')).stat().st_size})
    manifest.write_text(json.dumps(sorted(entries,key=lambda e:e['asset']),indent=2))
    print('EDO_EXPORT',name)

start()
# Normalized 10m hipped roof, broad upturned eaves with painted tile sheets.
verts=[];N=16
for scale,height in [(1,0),(.82,.22),(.48,1.12),(.12,2.65)]:
    for i in range(N):
        a=i*math.tau/N;x,z=math.cos(a),math.sin(a);den=max(abs(x),abs(z));x/=den;z/=den
        verts.append((x*5*scale,height+(.4*abs(x*z) if scale==1 else 0),z*5*scale))
faces=[]
for r in range(3):
    for i in range(N):faces.append((r*N+i,r*N+(i+1)%N,(r+1)*N+(i+1)%N,(r+1)*N+i))
faces.append(tuple(range(3*N,4*N)))
mesh('Indigo tiled roof',verts,faces,'tile')
for i in range(N):beam('Timber eave',verts[i],verts[(i+1)%N],.10,'wood')
beam('Ceramic ridge',(-1.2,2.7,0),(1.2,2.7,0),.15,'tile')
for s in [-1,1]:beam('Upturned ridge',(s,2.7,0),(s*1.65,3.05,0),.12,'tile')
save('roof')
start()
for s in [-1,1]:
    beam('Vermilion pillar',(s*2.88,.3,0),(s*2.88,5.4,0),.34,'red')
    beam('Stone shoe',(s*2.88,0,0),(s*2.88,.6,0),.44,'tile')
box('Crossbar',(0,4.4,0),(7.6,.32,.44),'red')
pts=[(-4.9,5.62,0),(-3.8,5.37,0),(0,5.26,0),(3.8,5.37,0),(4.9,5.62,0)]
for a,b in zip(pts,pts[1:]):beam('Swept crown',a,b,.25,'tile')
box('Crest plaque',(0,4.8,.30),(.65,1,.14),'wood');ell('Sun crest',(0,4.8,.39),(.38,.38,.05),'paper');save('torii')
start()
ell('Ribbed paper',(0,0,0),(.58,.7,.58),'paper')
for y in [-.35,.35]:beam('Lacquer cap',(0,y-.035,0),(0,y+.035,0),.22,'red')
for z in [-.29,.29]:box('Red seal',(0,0,z),(.13,.3,.012),'red')
save('lantern')
for name,foliage in [('cherry_tree','cherry'),('green_tree','leaf'),('palm','palm')]:
    start();beam('Textured trunk',(0,0,0),(.3,5.2,.2),.37 if name!='palm' else .22,'wood',.20)
    if name=='palm':
        for i in range(9):
            a=i*math.tau/9;dx,dz=math.cos(a),math.sin(a)
            verts=[(.3,5.9,.2),(.3+dx*1.6-dz*.55,6.15,.2+dz*1.6+dx*.55),(.3+dx*3.5,4.8,.2+dz*3.5),(.3+dx*1.6+dz*.55,6.15,.2+dz*1.6-dx*.55)]
            mesh('Canopy leaf',verts,[(0,1,2),(0,2,3),(2,1,0),(3,2,0)],foliage)
    elif name=='cherry_tree':
        for i in range(7):
            a=i*2.399;p=(math.cos(a)*1.65,4.8+(i%3)*.48,math.sin(a)*1.55)
            beam('Branch',(.2,2.8,0),p,.16,'wood',.07);ell('Canopy blossom',p,(3.1,1.9,2.8),foliage)
        ell('Canopy crown',(.1,6.15,0),(3.5,1.7,3.1),foliage)
    else:
        for i in range(6):
            a=i*2.4;p=(math.cos(a)*1.3,3.7+i*.38,math.sin(a)*1.2)
            beam('Pine branch',(.2,2.6,0),p,.16,'wood',.06);ell('Canopy pine cloud',p,(3.1,1.1,2.6),foliage)
        ell('Canopy crown',(.3,6.1,.2),(2.8,1.3,2.6),foliage)
    save(name)
start()
for p,size in [((0,.65,0),(2.1,1.6,1.6)),((.7,.35,.35),(1.2,.9,1.3)),((-.6,.3,.4),(1.1,.8,1))]:
    ell('Weathered rock',p,size,'rock');ell('Moss patch',(p[0],p[1]+size[1]*.39,p[2]),(size[0]*.82,.2,size[2]*.7),'leaf')
save('moss_rock')
start()
# Flat dressing for an existing solid wall: normalized width/height 1, depth .05.
box('Warm paper',(0,.5,0),(1,1,.025),'plaster')
for x in [-.5,-.25,0,.25,.5]:box('Shoji muntin',(x,.5,.023),(.026,1,.025),'wood')
for y in [0,.25,.5,.75,1]:box('Shoji rail',(0,y,.025),(1,.022,.025),'wood')
save('shoji')
start()
# An overhead split curtain: remains above the existing traversable doorway.
beam('Curtain rod',(-1.5,0,0),(1.5,0,0),.055,'wood')
for i in range(5):
    x=-1.2+i*.6;box('Indigo noren',(x,-.43,0),(.56,.8,.025),'blue')
    if i in [1,2,3]:ell('Shop mon',(x,-.37,.025),(.22,.22,.025),'paper')
save('noren')
start()
for i in range(5):
    x=(i%3-.8)*.55;z=(i//3)*.5;h=3.8+(i%3)*.6
    beam('Bamboo culm',(x,0,z),(x,h,z),.10,'leaf')
    for j in range(1,7):beam('Bamboo joint',(x,j*h/7,z),(x,j*h/7+.07,z),.12,'palm')
    for s in [-1,1]:
        mesh('Bamboo leaves',[(x,h-.5,z),(x+s*1.3,h-.2,z+.15),(x+s*.5,h-.7,z+.4)],[(0,1,2),(2,1,0)],'leaf')
save('bamboo')
start()
# Unit deck overlay retains the established bridge's dimensions and tilt.
box('Deck timber',(0,0,0),(1,1,1),'wood')
for z in [-.375,-.125,.125,.375]:box('Plank seam',(0,.505,z),(1,.008,.012),'tile')
save('bridge_deck')
start()
for a in [0,2.1,4.2]:
    dx,dz=math.cos(a),math.sin(a)
    mesh('Bent grass blade',[(-dz*.08,0,dx*.08),(dz*.08,0,-dx*.08),(dx*.12,.43,dz*.12),(dx*.24,.65,dz*.24)],[(0,1,2),(0,2,3),(2,1,0),(3,2,0)],'grass')
save('grass_tuft')
start()
for side in [-1,1]:ell('Cavern shoulder',(side*4.4,2,0),(4.5,6,4.2),'crag')
box('Rock lintel',(0,5,0),(10,1.8,3),'crag')
save('grotto_bay')
print('EDO_ENVIRONMENT_COMPLETE')

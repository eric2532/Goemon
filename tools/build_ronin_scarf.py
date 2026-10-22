"""Author an independent, battle-worn Goemon cloak in Blender; keep kai.blend intact."""
import bpy, math, random, hashlib, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/blender/characters/kai.blend'
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene
# Keep the approved character in the editable scene for fitting and previews only.
rig=next(o for o in scene.objects if o.type=='ARMATURE')
if rig.animation_data:rig.animation_data.action=None
for b in rig.pose.bones:
 b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0);b.scale=(1,1,1)
for side,angle in [('L',math.radians(74)),('R',math.radians(-74))]:rig.pose.bones['Arm_'+side].rotation_euler.z=angle
bpy.context.view_layer.update()
collection=bpy.data.collections.new('Ronin Scarf - garment only');scene.collection.children.link(collection)
cloth=bpy.data.materials.new('Weathered crimson - faded weave and charcoal damage');cloth.use_nodes=True
bs=cloth.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.94
bs.inputs['Specular IOR Level'].default_value=.16
attr=cloth.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Color'
cloth.node_tree.links.new(attr.outputs['Color'],bs.inputs['Base Color'])
cloth.diffuse_color=(.48,.018,.027,1)
verts=[];faces=[];uvs=[];colors=[];zones=[]
region=0.0
random.seed(913)
def vertex(p,uv=(0,0),color=(.42,.016,.024,1)):
 verts.append(tuple(p));uvs.append(uv);colors.append(color);zones.append((region,0));return len(verts)-1
def quad(points,uv,color):
 ids=[vertex(p,u,color) for p,u in zip(points,uv)];faces.append(tuple(ids))
def finish(name):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 uv=mesh.uv_layers.new(name='ClothFlow');zone=mesh.uv_layers.new(name='GarmentRegion');col=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
 for p in mesh.polygons:
  p.use_smooth=True
  for li in p.loop_indices:
   vi=mesh.loops[li].vertex_index;uv.data[li].uv=uvs[vi];zone.data[li].uv=zones[vi];col.data[li].color=colors[vi]
 obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);mesh.materials.append(cloth)
 verts.clear();faces.clear();uvs.clear();colors.clear();zones.clear();return obj
# A thick, overlapping neck wrap: sculpted concentric fabric folds, with a low front opening.
N=72;R=14
for j in range(R+1):
 v=j/R
 for i in range(N):
  a=i/N*math.tau
  fold=math.sin(v*math.pi*5+a*.45)*.018
  radius=.39+math.sin(v*math.pi)*.065+fold
  x=math.cos(a)*radius*1.18
  y=math.sin(a)*radius
  z=1.35+v*.24+.028*math.cos(a*2+v*1.5)-max(0,math.sin(a))*.035
  c=(.40+.09*math.sin(v*math.pi),.013+.01*v,.023+.013*v,1)
  vertex((x,y,z),(i/N,0),c)
for j in range(R):
 for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
wrap=finish('Scarf_Neck_Wrap')
# Shoulder knot; pointed folded cloth, deliberately not a metal accessory.
for k in range(3):
 center=Vector((-.37-k*.025,-.31-k*.022,1.47-k*.035));size=(.17-k*.02,.12,.10)
 for a,b,c in [(0,1,2),(0,2,3),(4,2,1),(4,3,2),(0,3,5),(4,5,3),(0,5,1),(4,1,5)]:
  pts=[center+Vector(v) for v in [(size[0],0,0),(0,size[1],0),(0,0,size[2]),(0,-size[1],0),(-size[0],0,0),(0,0,-size[2])]]
  faces.append(tuple(vertex(pts[i],(0,0),(.5-k*.07,.02,.032,1)) for i in [a,b,c]))
knot=finish('Scarf_Hand_Tied_Knot')
# Full wraparound travelling cloak: shoulders to ankles, overlapping front, real ragged hem.
region=1.0
CLOAK_HOLES=[(.17,.83,.014,.045),(.32,.92,.022,.038),(.53,.80,.016,.034),(.68,.90,.02,.035),(.85,.77,.014,.04)]
def mantle_point(u,t,layer=False):
 a=.16+u*(math.tau-.32)
 shoulder=min(1,t/.22);shoulder=shoulder*shoulder*(3-2*shoulder)
 rx=.43+.31*shoulder+.25*t
 ry=.40+.16*shoulder+.13*t
 pleat=(.035*math.sin(a*9+t*1.5)+.022*math.cos(a*15-t*2))*math.sin(t*math.pi*.85)
 rx+=pleat;ry+=pleat
 z=1.47-1.23*t
 if layer:
  rx+=.045;ry+=.04;z+=.035
 return Vector((math.sin(a)*rx,math.cos(a)*ry,z))
for layer in [False,True]:
 rows=48 if not layer else 16;cols=112
 grid={}
 for j in range(rows+1):
  t=j/rows*(.37 if layer else 1)
  for i in range(cols+1):
   u=i/cols;tt=t
   if not layer and t>.84:
    notch=.025+.06*(.5+.5*math.sin(i*1.97))+.12*math.exp(-((u-.25)/.012)**2)+.10*math.exp(-((u-.73)/.016)**2)
    tt-=notch*((t-.84)/.16)**2
   if layer:tt+=.028*math.sin(u*math.tau*3)*(j/rows)**2
   pos=mantle_point(u,tt,layer)
   # Front edges overlap below the clasp, so the chest is covered while standing.
   if not layer and (u<.02 or u>.98):pos.x*=.4
   fade=.04*tt+.012*math.sin(i*.43+j*.27)
   scorch=0
   for hu,ht,hw,hh in CLOAK_HOLES:
    d=math.sqrt(((u-hu)/hw)**2+((tt-ht)/hh)**2)
    scorch=max(scorch,max(0,1-abs(d-1)*1.5)*.65)
   color=(max(.045,.34+fade-scorch*.30),max(.006,.011+fade*.12-scorch*.014),max(.011,.023+fade*.16-scorch*.026),1)
   grid[j,i]=vertex(pos,(u,tt),color)
 for j in range(rows):
  for i in range(cols):
   u=(i+.5)/cols;t=(j+.5)/rows*(.37 if layer else 1)
   hole=not layer and any(((u-hu)/hw)**2+((t-ht)/hh)**2<1 for hu,ht,hw,hh in CLOAK_HOLES)
   if not hole:faces.append((grid[j,i],grid[j+1,i],grid[j+1,i+1],grid[j,i+1]))
 # Discreet old repairs near the lower side/back panels.
 if not layer:
  for u0,t0 in [(.24,.62),(.72,.55)]:
   for j in range(6):
    u=u0+j*.008;t=t0+j*.006
    points=[mantle_point(uu,tt)+Vector((0,0,.005)) for uu,tt in [(u-.002,t-.012),(u+.002,t-.012),(u+.002,t+.015),(u-.002,t+.015)]]
    quad(points,[(u-.002,t-.012),(u+.002,t-.012),(u+.002,t+.015),(u-.002,t+.015)],(.40,.18,.10,1))
 finish('Cloak_Shoulder_Mantle' if layer else 'Cloak_Body_Wrap')
region=0.0

# Two asymmetrical, pleated tails. Holes are real topology; frayed tips are individual cuts.
TAILS=[(-.23,.87,3.20,1.16),(.27,.46,2.45,1.02)]
HOLES=[(-.29,.41,.14,.052),(.20,.64,.09,.05),(-.24,.76,.1,.025)]
def point(u,t,tail):
 cx,w,length,drop=TAILS[tail]
 width=w*(1-.21*t+.13*math.sin(t*math.pi))
 x=cx+u*width+.10*math.sin(t*5+tail*1.3)*t
 y=-.40-length*t
 z=1.43-drop*t+.13*math.sin(t*math.pi)+.045*math.sin(u*13+t*7)*math.sin(t*math.pi)
 return Vector((x,y,z))
for tail in range(2):
 rows=70;cols=24
 grid={}
 for j in range(rows+1):
  t=j/rows
  for i in range(cols+1):
   u=i/cols-.5
   tt=t
   if j>=rows-7:
    tear=(.028+.045*(.5+.5*math.sin(i*2.7+tail))+.12*math.exp(-((u-.12)/.08)**2))
    tt-=tear*((j-(rows-7))/7)**2
   p=point(u,tt,tail)
   # Ragged selvage, with a few bites removed from the edges.
   edge=max(0,(abs(u)-.40)/.10)
   p.x+=edge*(.014*math.sin(j*1.2+tail)+.009*math.sin(j*2.17)+.006*math.sin(j*.7))*(1 if u>0 else -1)
   fade=.04+.09*tt+.018*math.sin(i*1.7+j*2.3)
   scorch=0
   for hx,ht,hw,hh in HOLES:
    d=math.sqrt(((u-hx)/hw)**2+((tt-ht)/hh)**2)
    scorch=max(scorch,max(0,1-abs(d-1)*1.8)*.7)
   color=(max(.07,.44+fade-scorch*.40-edge*.065),max(.008,.018+fade*.20-scorch*.035),max(.012,.029+fade*.20-scorch*.036),1)
   grid[j,i]=vertex(p,(u+.5,tt),color)
 for j in range(rows):
  for i in range(cols):
   u=(i+.5)/cols-.5;t=(j+.5)/rows
   hole=any(((u-hx)/hw)**2+((t-ht)/hh)**2<1 for hx,ht,hw,hh in HOLES)
   # Irregular slash bites opening into the outer edge.
   bite=(u<-.38 and .55<t<.59) or (u>.39 and .82<t<.87)
   if not hole and not bite:faces.append((grid[j,i],grid[j,i+1],grid[j+1,i+1],grid[j+1,i]))
 # A faded longitudinal seam; use the same UVs so stitches flow with the cloth.
 for side in [-.43,.43]:
  for j in range(3,rows-8):
   t=j/rows;tt=(j+.7)/rows
   points=[point(u,v,tail)+Vector((0,0,.005)) for u,v in [(side-.007,t),(side+.007,t),(side+.007,tt),(side-.007,tt)]]
   quad(points,[(side+.5,t),(side+.5,t),(side+.5,tt),(side+.5,tt)],(.30,.046,.042,1))
 # Hand repair: a diagonal closed cut with contrasting, irregular cross stitches.
 for j in range(7):
  t=.25+j*.012;u=.03+(t-.25)*1.3
  points=[point(uu,tt,tail)+Vector((0,0,.007)) for uu,tt in [(u-.06,t),(u+.055,t+.014),(u+.05,t+.018),(u-.065,t+.004)]]
  quad(points,[(u+.44,t),(u+.555,t+.014),(u+.55,t+.018),(u+.435,t+.004)],(.56,.30,.18,1))
 finish('Scarf_Long_Tail' if tail==0 else 'Scarf_Split_Tail')
# Cloth motion is handled by the game shader; UV.y is attachment-to-tip weight.
scene['asset_id']='costumes/ronin_scarf'
scene['art_direction']='Full body ronin wrap inspired by the supplied reference. Years away: deep crimson, uneven split tails, charred holes, frayed selvage and hand repairs. Original Goemon geometry is untouched.'
scene['runtime']='UV.y flow weight; UV2.x distinguishes full body cloak (1) from scarf (0). Vertex colors supply weathering. Torso attachment; export only garment.'
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.world.color=(.12,.12,.12)
for o in scene.objects:
 if o.type=='LIGHT':o.hide_render=True
for name,loc,power,size in [('Key',(3,4,7),950,5),('Rim',(-3,-4,5),1100,4),('Fill',(-4,3,3),600,5)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
 obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,0,1.4))-obj.location).to_track_quat('-Z','Y').to_euler()
if not scene.camera:
 data=bpy.data.cameras.new('Scarf portrait');cam=bpy.data.objects.new('Scarf portrait',data);scene.collection.objects.link(cam);scene.camera=cam
cam=scene.camera;cam.data.type='ORTHO';cam.data.ortho_scale=5.2
cam.location=(5,7,3.4);cam.rotation_euler=(Vector((0,-.3,1.6))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=-1.0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/costumes/goemon_ronin_scarf.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/costumes/ronin_scarf.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False,export_all_vertex_colors=True)
scene.render.filepath=str(ROOT/'tests/ronin-cloak/blender-outfit.png');bpy.ops.render.render(write_still=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
report={'source_unchanged':True,'source_sha256':source_hash,'garment_meshes':{o.name:len(o.data.polygons) for o in collection.objects},'actual_torn_holes':11,'tail_lengths':[3.2,2.45]}
(ROOT/'tests/ronin-cloak/blender-report.json').write_text(json.dumps(report,indent=2));print(report)

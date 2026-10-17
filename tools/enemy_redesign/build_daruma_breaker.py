"""Concept-only Daruma Breaker, from the approved four-view turnaround."""
import sys, math, random
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
reset();M=material_set();random.seed(71)
M['shell']=texture_mat('Daruma lacquer with painted face and fortune emblem',TEX/'daruma_breaker_shell.png')
M['stone_dark']=mat('Basalt shadow facets','494c50');M['stone_light']=mat('Basalt warm raised facets','626363')
M['rope_light']=mat('Rope raised fibers','c7ad7c');M['rope_dark']=mat('Rope recessed strands','8c704e')
M['bronze']=mat('Worn iron edges','81704e',metallic=.45)
# Whole body UV surface, +Y front, rear seam. No projected face panel.
def shell(u,v):
 a=math.pi-u*math.tau;p=-math.pi*.5+v*math.pi
 return (2.10*math.cos(p)*math.sin(a),1.76*math.cos(p)*math.cos(a),2.83+2.25*math.sin(p))
body=surface('Body_round_daruma_painted_shell',shell,M['shell'],cols=96,rows=64);body['face_artwork']=True
body['uv_description']='u=.5 front center, v=.5 body equator; true latitude/longitude shell UV, face painted on upper front only'
# Stone helpers with softly faceted rock planes, never cube silhouettes.
def stone(name,center,size,sub=2):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=center);o=bpy.context.object
 for v in o.data.vertices:
  n=v.co.normalized();v.co*=1+random.uniform(-.035,.035)
 o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 finish(o,name,M['stone'],sub>=2);o.data.materials.append(M['stone_dark']);o.data.materials.append(M['stone_light'])
 for f in o.data.polygons:
  n=f.center.normalized();f.material_index=1 if n.x*n.z>.32 else 2 if n.y+n.z>1.10 else 0
 return o
# Controlled braided geometry: continuous three-strand twist, closed tube cross sections.
def braid(name,points,r=.12,steps=60,turns=12):
 # Interpolate sampled path and stable local frames.
 path=[]
 for i in range(steps+1):
  t=i/steps*(len(points)-1);k=min(int(t),len(points)-2);path.append(Vector(points[k]).lerp(Vector(points[k+1]),t-k))
 for strand in range(3):
  vs=[];fs=[]
  for i,p in enumerate(path):
   tangent=(path[min(i+1,steps)]-path[max(0,i-1)]).normalized();ref=Vector((0,0,1))
   if abs(tangent.dot(ref))>.94:ref=Vector((0,1,0))
   n=tangent.cross(ref).normalized();b=tangent.cross(n).normalized();angle=i/steps*math.tau*turns+strand*math.tau/3
   c=p+(n*math.cos(angle)+b*math.sin(angle))*r*.46
   for j in range(6):
    a=j*math.tau/6;vs.append(c+(n*math.cos(a)+b*math.sin(a))*r*.61)
  for i in range(steps):
   for j in range(6):
    a=i*6+j;q=i*6+(j+1)%6;fs.append((a,q,q+6,a+6))
  mesh(name+'_strand_'+str(strand),vs,fs,M['rope_light'] if strand==0 else M['rope'] if strand==1 else M['rope_dark'])
def ring(name,center,rx,rz,wire=.11):
 x,y,z=center;return curve(name,[(x+rx*math.sin(i*math.tau/40),y,z+rz*math.cos(i*math.tau/40)) for i in range(41)],wire,M['iron'],resolution=2)
# Squat feet and visible individual blunt toes.
for s in [-1,1]:
 side='L' if s<0 else 'R'
 stone('Foot_'+side+'_rock_base',(s*1.15,.10,.31),(.69,.64,.31),sub=3)
 stone('Ankle_'+side+'_compact',(s*1.15,0,.63),(.43,.43,.29))
 for k in range(3):stone('Foot_'+side+'_toe_'+str(k),(s*1.15+(k-1)*.37,.55,.23),(.23,.27,.23),sub=1)
 wristpath=[(s*1.15+.47*math.sin(i*math.tau/40),.39*math.cos(i*math.tau/40),.69) for i in range(41)]
 braid('Ankle_'+side+'_rope',wristpath,r=.095,steps=40,turns=10)
 # Compact thick arms hidden partially inside the reinforced shell and fists.
 stone('Arm_'+side+'_short_boulder',(s*2.06,.06,2.07),(.52,.46,.64))
 stone('Fist_'+side+'_main_boulder',(s*2.63,.25,1.72),(.78,.66,.87),sub=3)
 # Four finger fronts and large tucked thumb make unmistakable clenched fists.
 for k in range(4):
  cx=s*2.63+(k-1.5)*.31
  stone('Fist_'+side+'_finger_'+str(k),(cx,.78,1.58),(.235,.265,.50))
  stone('Fist_'+side+'_knuckle_'+str(k),(cx,.75,1.98),(.23,.23,.235),sub=1)
 stone('Fist_'+side+'_thumb',(s*2.14,.66,1.84),(.31,.35,.48))
 # Broken mineral seams on the fist remain dark narrow stone cracks.
 for k in range(3):
  cx=s*2.63+(k-1)*.35
  curve('Fist_'+side+'_mineral_seam_'+str(k),[(cx-.05,.984,1.75),(cx+.02,1.005,1.62),(cx-.08,.973,1.49)],.012,M['stone_dark'],resolution=1)
 # Wrist braid lies above fists and encloses the short forearm.
 wristpath=[(s*2.55+.63*math.sin(i*math.tau/40),.20+.50*math.cos(i*math.tau/40),2.36+.06*math.sin(i*math.tau/40)) for i in range(41)]
 braid('Wrist_'+side+'_heavy_binding',wristpath,r=.115,steps=40,turns=12)
 # Two vertical iron reinforcement rings linked along each shoulder flank.
 for j,z in enumerate([3.63,2.88]):
  cx=s*(1.89 if j==0 else 2.10)
  ring('Shoulder_'+side+'_iron_ring_'+str(j),(cx,.31,z),.33,.41,.12)
  box('Shoulder_'+side+'_ring_keeper_'+str(j),(cx,.31,z+.36),(.25,.22,.28),M['iron'],bevel=.06)
  uv_sphere('Shoulder_'+side+'_rivet_'+str(j),(cx,.465,z+.34),(.075,.045,.075),M['bronze'],segments=12,rings=8)
 # Rope descends outer shoulder with a recognizably heavy, curved link to the fist.
 braid('Shoulder_'+side+'_front_rope',[(s*1.67,.48,3.82),(s*2.02,.52,3.44),(s*2.25,.51,3.05),(s*2.43,.30,2.45)],r=.13,steps=40,turns=11)
# Back ring and rope cradle. Rear is plain red with only structural bindings.
ring('Rear_central_iron_harness_ring',(0,-1.75,2.79),.44,.47,.13)
for s in [-1,1]:
 side='L' if s<0 else 'R'
 braid('Rear_'+side+'_diagonal_harness',[(s*1.91,-.57,3.55),(s*1.65,-1.16,3.32),(s*1.11,-1.58,3.02),(s*.43,-1.80,2.79)],r=.115,steps=45,turns=12)
# Vertical back rope follows the whole curved rear shell, concealed behind face.
backpath=[]
for i in range(45):
 p=-1.32+i/44*2.72
 backpath.append((0,-(1.76*math.cos(p)+.07),2.83+2.25*math.sin(p)))
braid('Rear_vertical_crown_to_base_binding',backpath,r=.11,steps=55,turns=16)
box('Rear_ring_top_keeper',(0,-1.78,3.21),(.26,.22,.37),M['iron'],bevel=.06)
box('Rear_ring_bottom_keeper',(0,-1.78,2.37),(.26,.22,.37),M['iron'],bevel=.06)
for z in [2.43,3.15]:uv_sphere('Rear_harness_rivet_'+str(z),(0,-1.924,z),(.075,.045,.075),M['bronze'],segments=12,rings=8)
# Round iron-and-rope cap with a central stone knot, as on the concept.
ellipse('Crown_iron_anchor',(0,0,5.08),.59,.48,.10,M['iron'],count=48)
caploop=[(.61*math.sin(i*math.tau/45),.49*math.cos(i*math.tau/45),5.18) for i in range(46)]
braid('Crown_rope_binding',caploop,r=.12,steps=45,turns=12)
stone('Crown_central_stone_knot',(0,0,5.45),(.29,.27,.26),sub=1)
box('Crown_iron_clamp',(0,.23,5.14),(.59,.34,.18),M['iron'],bevel=.065)
# Tiny solid metal shoulder plates support the side rings without flat frontal mask geometry.
for s in [-1,1]:
 for z in [3.6,2.88]:stone('Side_'+str(s)+'_iron_seat_'+str(z),(s*1.91,.01,z),(.25,.31,.41),sub=1).data.materials[0]=M['iron']
rescale_to_height(HEIGHT*1.75)
export_asset('daruma_breaker','Siege / heavy stone-fist breaker',[
 'Approved turnaround interpreted as a broad spherical red daruma, with compact feet, massive rounded stone fists and reinforced braided-rope harness.',
 'Entire face, eyebrows, eyes, moustache, nose and 福 belly glyph are pigment on the curved body shell; no separate face planes or raised facial parts.',
 'Full shell UV atlas wraps through a plain-red rear; back contains only iron hardware and rope bindings.',
 'Height 1.75 times approved Goemon master; all rigid meshes are individually named for later motion work.',
 'Concept-only asset kit: no gameplay wiring, collision shapes, skeleton or animations.'
])
# The artwork-bearing mesh is the entire shell, so explicitly frame its upper
# painted region for a useful close-up rather than using whole-shell bounds.
camera=bpy.context.scene.camera
camera.data.ortho_scale=4.05
camera.location=(0,10,4.10)
aim(camera,(0,0,4.10))
bpy.context.scene.render.filepath=str(DOC/'daruma_breaker-face-detail.png')
bpy.ops.render.render(write_still=True)
report_path=DOC/'daruma_breaker-report.json'
report=json.loads(report_path.read_text());lo,hi=bounds()
report.update(width=hi[0]-lo[0],depth=hi[1]-lo[1],face_texture=str((TEX/'daruma_breaker_shell.png').relative_to(ROOT)),face_mapping='Full shell latitude/longitude UV with horizontally correct front-facing 福 emblem; no geometry overlay.')
report_path.write_text(json.dumps(report,indent=2)+'\n')

"""Lantern Runner: curved painted paper, rounded ribs, single crooked wooden leg."""
import math,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import common as c
import bpy
c.reset();m=c.material_set()
# Softly shaped oval shell, 56 radial samples and 32 vertical rings.
def radii(z):
 t=(z-1.05)/1.86
 return .32+.39*max(0,math.sin(math.pi*t))**.65, .30+.32*max(0,math.sin(math.pi*t))**.65
rings=[]
for i in range(33):
 z=1.05+1.86*i/32;rx,ry=radii(z);rings.append((z,0,0,rx,ry))
paper=c.loft('Root_paper_shell',rings,m['cream'],count=56)
bs=m['cream'].node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(.8,.48,.12,1);bs.inputs['Emission Strength'].default_value=.075
face_mat=c.texture_mat('Lantern curved painted face',c.TEX/'lantern_runner_face.png',emission=.075)
def face(u,v):
 z=1.28+1.38*v;rx,ry=radii(z);a=(.5-u)*1.95
 return ((rx+.009)*math.sin(a),(ry+.009)*math.cos(a),z)
face_ob=c.surface('Root_painted_face',face,face_mat,cols=48,rows=40);face_ob['face_artwork']=True
for i,z in enumerate([1.10,1.29,1.48,1.67,1.86,2.05,2.24,2.43,2.62,2.82]):
 rx,ry=radii(z);c.ellipse('Root_bamboo_rib_%02d'%i,(0,0,z),rx+.012,ry+.012,.012,m['straw'],count=56)
# Dark round collars have substantial thickness, never cube caps.
for name,z in [('base',1.01),('top',2.94)]:
 c.loft('Root_'+name+'_rim',[(z-.06,0,0,.345,.325),(z-.03,0,0,.375,.355),(z+.04,0,0,.375,.355),(z+.07,0,0,.345,.325)],m['iron'],count=48)
 for j in range(8):
  a=j*math.tau/8;c.uv_sphere('Root_'+name+'_rivet_'+str(j),(.375*math.sin(a),.355*math.cos(a),z),(.024,.024,.024),m['rope'],segments=12,rings=8)
# Single crooked wooden support limb with rounded dark joint collars.
leg_nodes=[(0,0,.97),(.10,0,.79),(-.17,.025,.53),(.07,.06,.24)]
for i,(a,b) in enumerate(zip(leg_nodes,leg_nodes[1:])):
 c.tube('Leg_L_branch_'+str(i),a,b,.070,m['wood'],radius2=.057,count=18)
for i,p in enumerate(leg_nodes):c.uv_sphere('Leg_L_knuckle_'+str(i),p,(.083,.072,.083),m['iron'],segments=18,rings=12)
foot=c.box('Leg_L_wood_sandal',(.07,.13,.12),(.45,.66,.15),m['wood'],bevel=.055)
for x in [-.095,.235]:c.box('Leg_L_sandal_tooth',(x,.13,.036),(.09,.47,.07),m['wood'],bevel=.025)
c.curve('Leg_L_sandal_strap',[(-.10,.17,.22),(.07,.32,.225),(.24,.16,.22)],.023,m['rope'])
# Bent suspension loop, ropes and fluttering paper strips.
handle=[(-.16,0,3.01),(-.24,0,3.23),(-.13,0,3.49),(.13,0,3.58),(.25,0,3.20),(.19,0,3.02)]
c.curve('Root_crooked_bamboo_handle',handle,.054,m['wood'])
for p in [handle[0],handle[1],handle[-2],handle[-1]]:
 c.uv_sphere('Root_handle_binding',p,(.08,.065,.058),m['rope'],segments=18,rings=12)
# Two visibly thick paper streamers lie off to one side/back, outside face.
for j in range(2):
 rows=[]
 for i in range(18):
  t=i/17;cx=-.17-.60*t-j*.20+.08*math.sin(t*math.tau);cy=-.12-.30*t+j*.07;z=3.37-(.93+j*.24)*t
  width=.105*(1-.28*t)
  rows.append([(cx-width,cy,z),(cx,cy+.02*math.sin(t*math.pi*3),z+.01),(cx+width,cy,z-.018*math.sin(t*math.pi*5))])
 c.cloth('Root_paper_streamer_'+str(j),rows,m['cream'],thickness=.012)
 # Red circular seal painted-like wide small geometry follows only ribbon surface.
 for k in range(2):
  t=.35+.3*k;cx=-.17-.60*t-j*.20+.08*math.sin(t*math.tau);cy=-.12-.30*t+j*.07;z=3.37-(.93+j*.24)*t
  c.uv_sphere('Root_streamer_seal_'+str(j)+'_'+str(k),(cx,cy+.018,z),(.070,.008,.070),m['red'],segments=16,rings=10)
# Solid elliptical tongue follows a smooth curl and starts inside the painted mouth.
# A surface-only ribbon previously left a visible attachment gap in profile.
verts=[];uv=[];faces=[];centers=[];N=32;K=14
p0=(.53,1.68);p1=(.96,1.39);p2=(1.24,1.00);p3=(1.10,1.45)
for i in range(N+1):
 t=i/N;q=1-t
 y=q**3*p0[0]+3*q*q*t*p1[0]+3*q*t*t*p2[0]+t**3*p3[0]
 z=q**3*p0[1]+3*q*q*t*p1[1]+3*q*t*t*p2[1]+t**3*p3[1]
 dy=3*q*q*(p1[0]-p0[0])+6*q*t*(p2[0]-p1[0])+3*t*t*(p3[0]-p2[0])
 dz=3*q*q*(p1[1]-p0[1])+6*q*t*(p2[1]-p1[1])+3*t*t*(p3[1]-p2[1])
 length=math.hypot(dy,dz);ny=dz/length;nz=-dy/length
 width=.132*(1-.50*t**5);thickness=.039*(1-.35*t)
 centers.append((0,y,z))
 for j in range(K+1):
  a=j*math.tau/K;verts.append((width*math.cos(a),y+ny*thickness*math.sin(a),z+nz*thickness*math.sin(a)));uv.append((j/K,t))
for i in range(N):
 for j in range(K):
  a=i*(K+1)+j;faces.append((a,a+1,a+K+2,a+K+1))
faces += [tuple(reversed(range(K))),tuple(N*(K+1)+j for j in range(K))]
c.mesh('Root_solid_curled_tongue',verts,faces,m['tongue'],uv)
# Plain rear seam and two repair patches conform to shell curvature.
c.curve('Root_rear_paper_seam',[(0,-radii(1.15+i*.05)[1]-.012,1.15+i*.05) for i in range(34)],.006,m['straw'])
for j,z in enumerate([1.82,2.15]):
 def patch(u,v,z=z):
  zz=z+(v-.5)*.19;rx,ry=radii(zz);a=math.pi+(u-.5)*.26
  return ((rx+.013)*math.sin(a),(ry+.013)*math.cos(a),zz)
 c.surface('Root_rear_patch_'+str(j),patch,m['straw'],cols=8,rows=8)
c.rescale_to_height(c.HEIGHT*1.55)
c.export_asset('lantern_runner','Shrine rusher','Rounded oval paper shell; UV-painted face follows shell curvature; single articulated wooden leg; physical curved tongue; smooth rounded bamboo ribs. Asset-only, no gameplay integration.')

"""Convert locally extracted Halo CE JMS/JMA data into a Blender-neutral JSON.
Requires reclaimer==2.11.2. Inputs are proprietary assets from the user's disc.
This writes data only; it does not incorporate the Reclaimer implementation.
"""
import argparse,json,shutil
from pathlib import Path
from reclaimer.model.jms import read_jms
from reclaimer.animation.jma import read_jma

def node(n):
 return dict(name=n.name,parent=n.parent_index,child=n.first_child,sibling=n.sibling_index,position=[n.pos_x,n.pos_y,n.pos_z],rotation=[n.rot_i,n.rot_j,n.rot_k,n.rot_w])
def model(path):
 m=read_jms(path.read_text())
 return dict(nodes=[node(n) for n in m.nodes],materials=[s.name for s in m.materials],vertices=[dict(position=[v.pos_x,v.pos_y,v.pos_z],normal=[v.norm_i,v.norm_j,v.norm_k],uv=[v.tex_u,v.tex_v],bones=[v.node_0,v.node_1],weights=[1-v.node_1_weight,v.node_1_weight]) for v in m.verts],triangles=[dict(material=t.shader,indices=[t.v0,t.v1,t.v2]) for t in m.tris],markers=[dict(name=s.name,parent=s.parent,position=[s.pos_x,s.pos_y,s.pos_z],rotation=[s.rot_i,s.rot_j,s.rot_k,s.rot_w]) for s in m.markers])
def anim(path):
 a=read_jma(path.read_text(),anim_name=path.name)
 return dict(nodes=[node(n) for n in a.nodes],fps=a.frame_rate,frames=[[dict(position=[s.pos_x,s.pos_y,s.pos_z],rotation=[s.rot_i,s.rot_j,s.rot_k,s.rot_w],scale=s.scale) for s in f] for f in a.frames])
def main():
 p=argparse.ArgumentParser();p.add_argument('data',type=Path);p.add_argument('destination',type=Path);args=p.parse_args();d=args.data
 out={'body':model(d/'characters/cyborg/models/__base superhigh.jms'),'arms':model(d/'characters/cyborg/fp/models/__base superhigh.jms'),'rifle_fp':model(d/'weapons/assault rifle/fp/models/assault rifle fp superhigh.jms'),'rifle':model(d/'weapons/assault rifle/models/__base superhigh.jms')}
 out['fp_animations']={key:anim(d/f'weapons/assault rifle/fp/animations/first-person {fname}.jmm') for key,fname in [('idle','idle'),('firing','firing'),('reload','reload-full'),('ready','ready'),('melee','melee'),('throw_grenade','throw-grenade')]}
 out['weapons']={}
 for key,path,mesh in [('rocket_launcher','rocket launcher','rocketlauncher'),('pistol','pistol','pistol fp'),('shotgun','shotgun','shotgun fp')]:
  base=d/'weapons'/path/'fp'
  out['weapons'][key]={'model':model(base/f'models/{mesh} superhigh.jms'),'animations':{name:anim(base/f'animations/first-person {clip}.jmm') for name,clip in [('idle','idle'),('firing','fire-1'),('ready','ready')]}}
 out['rocket']=model(d/'weapons/rocket launcher/projectile/models/rocket superhigh.jms')
 out['body_animations']={key:anim(d/f'characters/cyborg/animations/stand rifle {fname}.jma') for key,fname in [('idle','idle'),('walk','move-front'),('airborne','airborne')] if (d/f'characters/cyborg/animations/stand rifle {fname}.jma').is_file()}
 args.destination.mkdir(parents=True,exist_ok=True)
 (args.destination/'decoded_assets.json').write_text(json.dumps(out,separators=(',',':')))
 shutil.copytree(d,args.destination/'source_data',dirs_exist_ok=True)
 print('Decoded assets',args.destination)
if __name__=='__main__':main()

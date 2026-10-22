"""Recover ROM-native ordinary Thirstquencher soldiers and full source motion streams.

Source engine: func_80020A28 packed rigid transforms; func_8012AAAC pose streams.
No original assets are modified. Blender companion builds editable rigid part rigs.
"""
from pathlib import Path
import json,struct,hashlib,argparse
BASE=0x80128158
SOURCE='raw/SC01.CD.dir/FILE_077.dir/0.4.dec'
LISTS={1:0x801a0058,2:0x8019b314,3:0x801aef38}
COLORS={1:'red',2:'blue',3:'green'}
SEMANTICS={'idle':'Source__801afdd0','walk':'Source__801aff18','run':'Source__801affc0','alert':'Source__801b0048','combo_prepare':'Source__801afd28','attack':['Source__801b0118','Source__801b01e0'],'hurt':['Source__801b02a8','Source__801b0908','Source__801b06e8'],'death':'Source__801b09d0','fire':'Source__801b0d50','reload':'Source__801b0e48'}
LABELS={'0x801afdd0':'idle_approximate','0x801aff18':'patrol','0x801affc0':'pursuit','0x801b0048':'alert','0x801afd28':'combo_prepare','0x801b0118':'melee_a','0x801b01e0':'melee_b','0x801b02a8':'hurt','0x801b09d0':'death_tumble','0x801b0908':'special_hurt','0x801b06e8':'special_hurt','0x801b0330':'special_state','0x801b0d50':'gunfire','0x801b0e48':'reload'}
GAMEPLAY_EVENTS={'0x801b0118':[{'tick':13,'kind':'melee_contact','timer_initial':20,'timer_value':7,'source':'overlay meleeA state'}],'0x801b01e0':[{'tick':14,'kind':'melee_contact','timer_initial':24,'timer_value':10,'source':'overlay meleeB state'}],'0x801b0d50':[{'tick':15,'kind':'muzzle_effect','timer_initial':30,'timer_value':15,'source':'func_80181BE4'},{'tick':18,'kind':'projectile','timer_initial':30,'timer_value':12,'source':'func_80181BE4'}]}


def main():
 ap=argparse.ArgumentParser();ap.add_argument('--recovery-root',type=Path,required=True);ap.add_argument('--output',type=Path,default=Path('assets/characters/thirstquencher'));a=ap.parse_args();r=a.recovery_root;out=a.output;out.mkdir(parents=True,exist_ok=True)
 d=(r/SOURCE).read_bytes();v=json.loads((r/'visual_manifest.json').read_text());mods={m['id']:m for m in v['models']};occ={BASE+o['offset']:o for o in v['model_occurrences'] if o['source']==SOURCE}
 def word(p):return struct.unpack_from('<I',d,p-BASE)[0]
 clips=[];poses={};start=0x801afd28
 while start<0x801b1178:
  pos=start;ticks=0;frames=[];events=[]
  while True:
   pointer,hold,flags=struct.unpack_from('<IhH',d,pos-BASE)
   if hold<0:
    assert hold==-1 and pointer==0,(hex(pos),hex(pointer),hold)
    break
   assert 0x811a0088<=pointer<0x811afdd0 and hold>0,(hex(pos),hex(pointer),hold)
   addr=pointer&~0x1000000;key=hex(addr)
   if key not in poses:
    parts=[]
    for i in range(11):
     b0,b1,b2,x,y,z,rx=struct.unpack_from('<3B3bh',d,addr-BASE+8*i)
     parts.append({'position':[x,y,z],'angles':[rx&4095,b1|((b0&15)<<8),b2|((b0&240)<<4)]})
    poses[key]={'address':key,'sha256':hashlib.sha256(d[addr-BASE:addr-BASE+88]).hexdigest(),'parts':parts}
   frames.append({'tick':ticks,'hold_ticks':hold,'pose':key,'command_address':hex(pos),'tagged_pose_pointer':hex(pointer),'flags':flags});ticks+=hold;pos+=8
  if frames:
   clips.append({'name':'Source__'+format(start,'08x'),'source_address':hex(start),'ticks':ticks,'terminal':'loop','frames':frames,'events':events,'semantic':LABELS.get(hex(start),'unmapped'),'gameplay_events':GAMEPLAY_EVENTS.get(hex(start),[]),'stream_sha256':hashlib.sha256(d[start-BASE:pos-BASE+8]).hexdigest()})
  start=pos+8
 manifest={'schema_version':1,'source':SOURCE,'source_base':hex(BASE),'source_sha256':hashlib.sha256(d).hexdigest(),'source_units_to_meters':.01,'fps':30,'facing_note':'Source front -Z maps through Blender C=(x,z,-y), then glTF export to Godot +Z. Rotate Y by PI for Godot -Z controller.','timing_note':'Held discrete source poses; one tick presented at nominal30Hz. Source stream duration is signed16; -1 loops. Event/combat gating is in overlay code, not pose stream.','transform_note':'Packed8byte perpart actor-space XYZ; position signed8, Euler angles12bits. Blender transform C*EulerXYZ*C^-1, C=(x,z,-y), translation=C*position*.01. glTF Y-up conversion is applied by exporter. Flat part bones deliberately preserve baked actor-space transforms.','variants':[]}
 for ident,table in LISTS.items():
  parts=[]
  for i in range(11):
   p=word(table+4*i);o=occ[p];m=mods[o['model']]
   parts.append({'index':i,'bone_name':f'Part_{i:02d}','source_address':hex(p),'source_model':o['model'],'glb':str(r/m['path']),'tmd':str(r/m['tmd'])})
  assert word(table+44)==0
  # Ordinary red/blue share original motion data; green additionally has its
  # own source actions and uses common soldier body actions through code.
  selected=[c for c in clips if ident==3 or all(int(f['pose'],16)<0x801aef68 for f in c['frames'])]
  used={f['pose'] for c in selected for f in c['frames']}
  item={'id':ident,'name':f'Thirstquencher Soldier {ident}','color':COLORS[ident],'glb':f'res://assets/characters/thirstquencher/soldier_{ident}.glb','model_list_address':hex(table),'parts':parts,'clips':selected,'semantics':SEMANTICS.copy(),'semantic_note':'Idle/walk/run are approximate animation aliases inferred from visible motion and AI roles; numeric action addresses are authoritative. Gameplay event ticks describe source AI state timers separately from stream durations.','motion_sources':f'res://assets/characters/thirstquencher/soldier_{ident}_motion.json'}
  if ident==2:item['semantics']['attack']=['Source__801b0d50']
  if ident==3:item['semantics']['attack']=['Source__801b0118']
  side={**{k:v for k,v in manifest.items() if k!='variants'},**item,'poses':{p:poses[p] for p in sorted(used)}}
  (out/f'soldier_{ident}_motion.json').write_text(json.dumps(side,indent=2))
  manifest['variants'].append({**item,'clips':[{k:v for k,v in c.items() if k!='frames'} for c in selected]})
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2));print('Recovered',len(clips),'streams',len(poses),'poses',[(x['id'],len(x['clips'])) for x in manifest['variants']])
if __name__=='__main__':main()

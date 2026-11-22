"""Verify Cursed Maze status/arena effects by executing archived client setup bytes."""
import argparse, hashlib, json, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PROOF=ROOT/'assets/references/cursed_maze/effect-factories.json'

def recover(source):
 sys.path.insert(0,str(source/'research/spell-animations-20261031'))
 import recover_spell_visuals as n
 from unicorn import UC_HOOK_CODE
 from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBP,UC_X86_REG_EBX,UC_X86_REG_ESP,UC_X86_REG_EIP
 def run(protocol,arena=False):
  c=n.setup();objects=[];sounds=[];clocks=[]
  n.put(c,n.DATA+0x103c,protocol);n.put(c,0x5987cc,n.ACTOR)
  n.put(c,0x54368c,0);n.put(c,0x543664,1)
  for at,value in [(0x5436b0,100),(0x5436b4,200),(0x5436c0,500),(0x5436c4,400)]:n.put(c,at,value)
  def hook(u,pc,size,data):
   if pc in [n.STOP,0x40dc11,0x40e8cb]:u.emu_stop();return
   if pc not in [0x404ae0,0x50dbf0,0x530c78,0x521d00]:return
   sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:n.get(u,sp+4+4*i)
   value=0
   if pc==0x404ae0:
    assert [arg(0),arg(1)]==[2,0]
    value=0x21000000+len(objects)*0x4000;objects.append(value);n.put(u,value+12,value+0x800)
   elif pc==0x50dbf0:clocks.append(arg(1))
   elif pc==0x521d00:sounds.append(arg(0))
   u.reg_write(UC_X86_REG_EAX,value);u.reg_write(UC_X86_REG_EIP,n.get(u,sp));u.reg_write(UC_X86_REG_ESP,sp+4)
  c.hook_add(UC_HOOK_CODE,hook)
  c.reg_write(UC_X86_REG_ESP,0x20008000);c.reg_write(UC_X86_REG_EBP,n.DATA);c.reg_write(UC_X86_REG_EBX,n.ACTOR);c.reg_write(UC_X86_REG_EAX,protocol)
  c.emu_start(0x40db91 if arena else 0x40e888,n.STOP,count=5000)
  assert len(objects)==1
  obj=objects[0]
  row={'protocol':protocol,'resource':n.get(c,obj+0x2a8),'callback':hex(n.get(c,obj+8)),
       'position':[n.float_get(c,obj+0x40),n.float_get(c,obj+0x44)],'flags':hex(n.get(c,obj+0x24)),
       'field_2a4':n.get(c,obj+0x2a4),'clocks':clocks.copy(),'sounds':sounds,
       'status_bits':n.get(c,n.DATA+0xfdc),'status_index':n.get(c,n.DATA+0x13bc)}
  # The original owner slot prevents a second object allocation.
  n.put(c,0x20008000,n.STOP);n.put(c,0x20008004,110155 if arena else n.ACTOR)
  if not arena:n.put(c,0x20008008,row['resource'])
  c.reg_write(UC_X86_REG_ESP,0x20008000);c.emu_start(0x41d790 if arena else 0x41ce70,n.STOP,count=5000)
  assert len(objects)==1 and c.reg_read(UC_X86_REG_EAX)==0
  row['one_owner_slot']=True
  # Follow a moved actor (status) or keep the arena midpoint fixed (seal).
  n.float_put(c,n.ACTOR+0x40,500);n.float_put(c,n.ACTOR+0x44,360)
  n.put(c,0x20008000,n.STOP);n.put(c,0x20008004,obj);c.reg_write(UC_X86_REG_ESP,0x20008000)
  c.emu_start(int(row['callback'],16),n.STOP,count=5000)
  row['after_owner_move']=[n.float_get(c,obj+0x40),n.float_get(c,obj+0x44)]
  row['update_clocks']=clocks[len(row['clocks']):]
  return row
 cases=[run(p) for p in range(44,50)]+[run(88,True)]
 for i,row in enumerate(cases[:6]):
  assert row['resource']==110075+i and row['status_bits']==16<<i and row['status_index']==i+1
  assert row['position']==[457.5,331.0] and row['after_owner_move']==[500.0,361.0]
 assert cases[6]['resource']==110155 and cases[6]['sounds']==[275]
 assert cases[6]['position']==cases[6]['after_owner_move']==[300.0,300.0]
 c=n.setup();queue=[];kinds=[]
 n.put(c,0x5977b0,86);n.put(c,0x59176c,8652);n.put(c,0x597778,0)
 def death_hook(u,pc,size,data):
  sp=u.reg_read(UC_X86_REG_ESP)
  if pc==0x435140:
   queue.append(n.get(u,sp+12));u.reg_write(UC_X86_REG_EIP,n.get(u,sp));u.reg_write(UC_X86_REG_ESP,sp+4)
  elif pc==0x41a600:kinds.append(n.get(u,sp+12));u.emu_stop()
  elif pc==0x431966:u.emu_stop()
 c.hook_add(UC_HOOK_CODE,death_hook)
 c.emu_start(0x431911,n.STOP,count=5000)
 assert queue==[132]
 c.reg_write(UC_X86_REG_EAX,queue[0]);c.reg_write(UC_X86_REG_EBX,n.ACTOR);c.reg_write(UC_X86_REG_ESP,0x20008000)
 c.emu_start(0x40d861,n.STOP,count=5000)
 assert kinds==[25]
 sys.path.insert(0,str(source/'research/all-skills-20261031'))
 import probe_factories
 death=probe_factories.factory(86,0,kinds[0])
 assert death['objects'][0]['resource']==110156 and death['objects'][0]['position']==[457.5,290.0]
 death.update(tech=8652,queued_state=queue[0])
 spans=[(0x40e888,0x40e8cb),(0x41ce10,0x41d008),(0x40db91,0x40dc11),(0x41d740,0x41d8ad),(0x431911,0x431966),(0x40d861,0x40d873)]
 return {'snapshot_sha256':n.EXPECTED,'code_sha256':{hex(lo):hashlib.sha256(n.IMAGE[lo-0x400000:hi-0x400000]).hexdigest() for lo,hi in spans},'cases':cases,'death':death,
         'limits':'Native resource selection, setup and following callback bytes. Synthetic actors, arena corners and allocation; sprite clock, float-to-screen conversion and audio submission are inert fixtures. Death general factory uses the existing documented EAX=2 tier-initializer repair; status and seal execute without it. No server or Windows executable is run. Real-time duration and 3D floor projection remain adaptations.'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');a=p.parse_args()
 proof=recover(a.source.resolve())
 if a.check:assert json.loads(PROOF.read_text())==proof
 else:PROOF.parent.mkdir(parents=True,exist_ok=True);PROOF.write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
 print('CURSED_EFFECT_FACTORIES six statuses, Magic Seal arena/audio and Death skill-to-skull dispatch verified')
if __name__=='__main__':main()

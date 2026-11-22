"""Recover the client's default GMN battle reinforcement entry, without running its EXE."""
import argparse,hashlib,json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PROOF=ROOT/'assets/references/cursed_maze/napa-summon.json'

def recover(source):
 sys.dont_write_bytecode=True
 sys.path.insert(0,str(source/'research/all-skills-20261031'))
 import probe_factories as p
 n=p.n
 from unicorn import UC_HOOK_CODE
 from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP
 word=lambda at:struct.unpack_from('<I',n.IMAGE,at-0x400000)[0]
 assert n.IMAGE[word(0x543cf4+21*4)-0x400000:word(0x543cf4+21*4)-0x400000+4]==b'GMN\0'
 assert word(0x433980+21*4)==0x4330ad and word(0x415544+52*4)==0x409ee3
 cases=[]
 for mode in [0,1]:
  c=n.setup();queue=[];kinds=[];frees=[];done=[];clocks=[]
  obj=0x21000000
  def hook(u,pc,size,data):
   if pc not in [0x435140,0x446a00,0x416120,0x41a600,0x404d00,0x4351e0,0x50dbf0]:return
   sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:n.get(u,sp+4+i*4);value=0
   if pc==0x435140:queue.append(arg(2))
   elif pc==0x446a00:value=mode
   elif pc==0x41a600:
    kinds.append(arg(2));assert [arg(i) for i in range(5)]==[n.ACTOR,0,22,0,1]
    n.put(u,n.DATA+0x1024,1);value=obj
   elif pc==0x404d00:frees.append(arg(0))
   elif pc==0x4351e0:done.append(arg(0))
   elif pc==0x50dbf0:clocks.append(arg(1))
   u.reg_write(UC_X86_REG_EAX,value);u.reg_write(UC_X86_REG_EIP,n.get(u,sp));u.reg_write(UC_X86_REG_ESP,sp+4)
  c.hook_add(UC_HOOK_CODE,hook)
  # GMN's default arrival branch initializes both body scales to zero and queues state 52.
  c.reg_write(UC_X86_REG_ESI,n.ACTOR);c.reg_write(UC_X86_REG_EBX,0x58c6c4);c.reg_write(UC_X86_REG_ESP,0x20008000)
  c.emu_start(0x433598,0x4335ae,count=2000)
  assert queue==[52] and n.float_get(c,n.ACTOR+0x5c)==n.float_get(c,n.ACTOR+0x60)==0
  scales=[0.0];flags=[]
  for i in range(100):
   c.reg_write(UC_X86_REG_EBX,n.ACTOR);c.reg_write(UC_X86_REG_EBP,n.DATA);c.reg_write(UC_X86_REG_ESP,0x20008000)
   c.emu_start(0x409ee3,0x4154a2,count=2000)
   scales.append(struct.unpack('<f',c.mem_read(n.ACTOR+0x5c,4))[0]);flags.append(n.get(c,n.ACTOR+0x24))
   assert n.float_get(c,n.ACTOR+0x5c)==n.float_get(c,n.ACTOR+0x60)
   if done:break
  assert len(scales)==52 and scales[-2]<1 and scales[-1]==1 and kinds==[22] and frees==[obj] and done==[n.ACTOR]
  assert n.get(c,n.DATA+0x1024)==0 and n.get(c,n.ACTOR+0x10)==0
  factory=p.factory(93,0,22,mode)
  assert factory['objects'][0]['resource']==110096 and factory['objects'][0]['parent']=='actor'
  n.put(c,n.ACTOR+0x24,flags[0]);c.mem_write(0x2000601f,b'\xff')
  c.reg_write(UC_X86_REG_ESI,n.ACTOR);c.reg_write(UC_X86_REG_EDI,0x20006000)
  c.emu_start(0x517a05,0x517a12,count=2000)
  alpha=c.mem_read(0x2000601f,1)[0];assert alpha==(128 if mode else 255)
  cases.append({'video_mode':mode,'queued_states':queue,'factory':factory,'scales':scales,'flags':flags,'rgba_alpha':alpha,'effect_allocations':len(kinds),'effect_deletions':len(frees),'body_clock_modes':clocks})
 assert cases[0]['scales']==cases[1]['scales']
 sys.path.insert(0,str(source/'tools'))
 import cg_assets as cg
 cg.SOURCE=source/'research/newclient20261030/source/bin'
 key='original:'+str(cg.latest_animation_rows('original')[110096]);clip=cg.metadata(key)['clips'][0]
 spans=[(0x543cf4,0x543d58),(0x433980,0x4339e4),(0x4334a9,0x4335b2),(0x409ee3,0x409fa5),(0x41a784,0x41a7ba),(0x417ac0,0x417afe),(0x517a05,0x517a12)]
 return {'snapshot_sha256':n.EXPECTED,'command':'GMN','command_index':21,'command_handler':'0x4330ad','arrival_state':52,'arrival_handler':'0x409ee3',
  'resource':'110096','key':key,'frames':clip['frameCount'],'duration_ms':clip['duration'],'source_updates':len(cases[0]['scales'])-1,'cases':cases,
  'code_sha256':{hex(lo):hashlib.sha256(n.IMAGE[lo-0x400000:hi-0x400000]).hexdigest() for lo,hi in spans},
  'limits':'Default GMN reinforcement entry, not a recovered BlueCG server packet for Napa. The server can choose alternate walk/fly entry variants. Native scale/cleanup handlers execute with inert geometry, clock, allocator and queue fixtures; general effect setup retains the existing labeled EAX=2 tier repair. Mapping 51 source updates to the game 60 Hz clock and battle slots to the original exploration positions are adaptations.'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');a=p.parse_args();data=recover(a.source.resolve())
 if a.check:assert json.loads(PROOF.read_text())==data
 else:PROOF.parent.mkdir(parents=True,exist_ok=True);PROOF.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 print('CURSED_SUMMON_SOURCE GMN state 52, original 110096, 51 growth updates and single effect cleanup verified')
if __name__=='__main__':main()

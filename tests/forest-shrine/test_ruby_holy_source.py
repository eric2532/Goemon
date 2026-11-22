import sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT.parent/'Magic Power/research/spell-animations-20261031'))
import recover_spell_visuals as n
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP

def probe(flags,upper):
 c=n.setup();n.put(c,n.DATA+0xc9c,0);n.put(c,n.DATA+32,flags);n.put(c,n.DATA+28,0)
 c.reg_write(UC_X86_REG_EBP,n.DATA);c.reg_write(UC_X86_REG_EDI,n.ACTOR);c.reg_write(UC_X86_REG_EBX,n.TARGET)
 row={'flags':flags,'upper_sound_fixture':upper,'protocol_queries':[],'resources':[],'sounds':[],'random_ranges':[]}
 def observe(u,pc,size,data):
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:n.get(u,sp+4+i*4)
  if pc==0x437c10:row['protocol_queries'].append(arg(0));return
  if pc not in [0x4178c0,0x41e0a0,0x468850,0x521d00]:return
  result=0
  if pc==0x4178c0:row['resources'].append(arg(1))
  elif pc==0x468850:
   low,high=arg(0),arg(1);row['random_ranges'].append([low,high]);result=high if upper else low
  elif pc==0x521d00:row['sounds'].append(arg(0))
  u.reg_write(UC_X86_REG_EAX,result);u.reg_write(UC_X86_REG_EIP,n.get(u,sp));u.reg_write(UC_X86_REG_ESP,sp+4)
 c.hook_add(UC_HOOK_CODE,observe,begin=0x400000,end=0x540000)
 c.emu_start(0x40b0ec,0x40b16f,count=20000)
 return row
import unittest
class HolyShieldSource(unittest.TestCase):
 def test_native_holy_shield_contact(self):
  proof=json.loads((ROOT/'assets/references/black_prayer/holy-shield-factory.json').read_text())
  self.assertEqual(proof['snapshot_sha256'],n.EXPECTED)
  for row in proof['cases']:
   with self.subTest(flags=row['flags'],upper=row['upper_sound_fixture']):
    self.assertEqual(probe(row['flags'],row['upper_sound_fixture']),row)
if __name__=='__main__':unittest.main()

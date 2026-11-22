"""Verify Ruby's original ward/Confusion resource dispatch against archived client bytes."""
import json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT.parent/'Magic Power'
sys.path.insert(0,str(SOURCE/'research/all-skills-20261031'))
import probe_factories as native
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_ESP

class RubyEffectFactory(unittest.TestCase):
 def test_original_resource_dispatch(self):
  proof=json.loads((ROOT/'assets/references/black_prayer/spell-effect-factory.json').read_text())
  self.assertEqual(proof['snapshot_sha256'],native.n.EXPECTED)
  original=native.n.setup;queries=[]
  def setup():
   machine=original()
   def observe(cpu,pc,size,data):
    stack=cpu.reg_read(UC_X86_REG_ESP);queries.append(native.n.get(cpu,stack+4))
   machine.hook_add(UC_HOOK_CODE,observe,begin=0x437c10,end=0x437c10)
   return machine
  native.n.setup=setup
  try:
   for row in proof['cases']:
    with self.subTest(action=row['action']):
     queries.clear()
     actual=native.factory(row['protocolType'],row['sublevel'],row['kind'])
     self.assertEqual(dict(action=row['action'],skill_queries=list(queries),**actual),row)
  finally:native.n.setup=original

if __name__=='__main__':unittest.main()

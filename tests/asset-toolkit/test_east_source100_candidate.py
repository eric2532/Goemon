"""Private East field input must never replace recorded or neighboring data."""
import hashlib,json,struct,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];F=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Candidate'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def planes(raw):
 w,h=struct.unpack_from('<II',raw,12);n=w*h;return w,h,struct.unpack_from('<'+str(n*3)+'H',raw,20)
class East100Candidate(unittest.TestCase):
 def test_unknown_only_and_all_excluded_cells_preserved(self):
  proof=json.loads((F/'preservation.json').read_text());old=(ROOT/'assets/maps/falan/freyja_source/100.dat').read_bytes();new=(F/'100.dat').read_bytes();self.assertEqual(sha(old),proof['source_active_sha256']);self.assertEqual(sha(new),proof['candidate_sha256']);w,h,a=planes(old);nw,nh,b=planes(new);self.assertEqual((w,h),(nw,nh));n=w*h;allowed={y*w+x for r in proof['changed_raw_cells']for x,y in[r['cell']]};self.assertEqual(len(allowed),42662);self.assertEqual(a[2*n:],b[2*n:])
  for i in range(n):
   if i not in allowed or a[2*n+i]&0xc000:self.assertEqual((a[i],a[n+i]),(b[i],b[n+i]))
 def test_native_index_is_scoped_and_atlas_is_identical(self):
  proof=json.loads((F/'preservation.json').read_text());a=Image.open(ROOT/'assets/maps/falan/freyja_ground_index.png').convert('RGBA');b=Image.open(F/'freyja_ground_index.png').convert('RGBA');self.assertEqual(a.size,b.size);allowed={tuple(r['cell'])for r in proof['changed_raw_cells']};self.assertEqual(sha(a.tobytes()),proof['protected_index_rgba_sha256']);self.assertEqual(sha(b.tobytes()),proof['candidate_index_rgba_sha256'])
  for i,(old,new)in enumerate(zip(a.getdata(),b.getdata())):
   if (i%a.width,i//a.width)not in allowed:self.assertEqual(old,new)
  old=Image.open(ROOT/'assets/maps/falan/freyja_ground_atlas.png').convert('RGB');new=Image.open(F/'freyja_ground_atlas.png').convert('RGB');self.assertEqual(old.size,new.size);self.assertEqual(old.tobytes(),new.tobytes())
if __name__=='__main__':unittest.main()

"""BG-house cells and component ownership stay pinned to original source art."""
import hashlib,json,sys,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from review_east_backgrounds import decode
FOLDER=ROOT/'assets/maps/falan/east_region/kanabella_bg'
def sha(raw):return hashlib.sha256(raw).hexdigest()
class KanabellaSource(unittest.TestCase):
 def test_all45_anchors_and_gold_component_pixels(self):
  data=json.loads((FOLDER/'data.json').read_text());catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
  self.assertEqual(sum(len(r['groups']) for r in data['maps'].values()),45);self.assertEqual(len(data['models']),7)
  for mid,context in data['maps'].items():
   row=next(r for r in catalog['maps'].values() if r['id']==int(mid));w,h,raw,values,bits,aliases=decode(row);self.assertEqual(sha(raw),context['source_raw_sha256'])
   for group in context['groups']:
    for cell in group['exact_bg_cells']:
     x,y=cell['cell'];i=y*w+x;self.assertEqual(values[i],cell['native_graphic']);self.assertEqual(bool(bits[i>>3]&(1<<(i&7))),cell['original_open'])
  spec=json.loads((FOLDER/'prototype.json').read_text());token=spec['model'];source=Image.open(FOLDER/f'{token}-native.png').convert('RGBA');self.assertEqual(sha(source.tobytes()),spec['source_rgba_sha256'])
  parts=[Image.open(FOLDER/f'{token}-{part}.png').convert('RGBA') for part in spec['derivatives']]
  for name,image in zip(spec['derivatives'],parts):self.assertEqual(sha(image.tobytes()),spec['derivatives'][name])
  for pixels in zip(source.getdata(),*(image.getdata() for image in parts)):
   self.assertEqual(sum(p[3] for p in pixels[1:]),pixels[0][3])
   for p in pixels[1:]:self.assertEqual(p[:3],pixels[0][:3])
if __name__=='__main__':unittest.main()

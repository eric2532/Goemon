"""Independent source-plane, furnishing and preserved-runtime contracts."""
import hashlib,json,re,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import review_kili_ghana as review
from build_freyja_destinations import KILI_ROOMS,GHANA_ROOMS,GHANA_HOMES,interior_links
from prepare_kili_ghana_rooms import prepared
class Villages(unittest.TestCase):
 def test_original_housing_identity(self):
  manifest=json.loads((ROOT/'assets/references/crossgate_ghana_houses/provenance.json').read_text());plans=set()
  for row in manifest['files']:
   raw=(ROOT/'assets/references/crossgate_ghana_houses'/row['name']).read_bytes()
   self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
   self.assertEqual(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest(),row['sha'])
   n=int(row['name'].split('_')[0]);d=review.decode(n);plans.add(tuple(d['floor'])+tuple(d['objects']))
  self.assertEqual(len(plans),3)
  p,data=prepared();self.assertEqual(p.read_text(),data)
 def test_all_native_room_placements(self):
  blocks=(ROOT/'assets/maps/falan/coastal_room_props.gd').read_text().split('const ROOMS={')[1]
  for n in sorted((KILI_ROOMS|GHANA_ROOMS)-{3200,3000}):
   d=review.decode(n);block=re.search(rf' {n}:\[(.*?)\n \],',blocks,re.S)[1]
   rows=re.findall(r'Vector2i\((\d+),(-?\d+)\),Vector2i\((\d+),(\d+)\),"[^"]+",(\d+)',block)
   actual=sorted((int(x),int(y)+int(depth)-1,int(s)) for x,y,width,depth,s in rows)
   expected=sorted((i%d['width'],i//d['width'],s) for i,s in enumerate(d['objects']) if s>=1000 and s not in [12000,12001,12002])
   self.assertEqual(actual,expected,n)
 def test_unrelated_masks_doors_and_prior_art_preserved(self):
  baseline=review.OUT/'Source baseline/assets/maps/falan'
  old=(baseline/'freyja_destinations_data.gd').read_text();new=(ROOT/'assets/maps/falan/freyja_destinations_data.gd').read_text()
  def normalize(text):
   return re.sub(r'^ (?:3000|3804|3805|3806):.*\n','',text,flags=re.M)
  self.assertEqual(normalize(old),normalize(new))
  # Repacking may change atlas coordinates, but never an old graphic's native pixels or origin.
  from PIL import Image
  def graphics(path):return {int(s):(tuple(map(int,r.split(','))),origin) for s,r,origin in re.findall(r'^ (\d+):\[Rect2\(([^)]+)\),Vector2\(([^)]+)\)',path.read_text(),re.M)}
  before=graphics(baseline/'coastal_room_props.gd');after=graphics(ROOT/'assets/maps/falan/coastal_room_props.gd')
  self.assertTrue(before.keys()<=after.keys())
  atlas=Image.open(ROOT/"assets/maps/falan/coastal_room_props.png")
  for serial,(rect,origin) in before.items():
   self.assertEqual(origin,after[serial][1],serial)
   x,y,w,h=after[serial][0];e=review.source.review.lib.serial_index()[serial]
   native=review.source.review.lib.image_from_record(e["pack"],e["row"])
   self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),native.tobytes(),serial)
 def test_every_source_housing_threshold_is_open(self):
  for row in interior_links(ROOT.parent/'Magic Power'):
   if row[0] not in GHANA_HOMES:continue
   d=review.decode(row[0]);self.assertTrue(d['walk'][row[2]*d['width']+row[1]],row)
if __name__=='__main__':unittest.main()

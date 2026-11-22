"""Original pixels and native anchors for the recovered solid fort pieces."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image, ImageOps, ImageStat

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT.parent/'Magic Power'
if not(SOURCE/'tools/cg_library.py').is_file():raise unittest.SkipTest('Needs original archive')
sys.path.insert(0,str(SOURCE/'tools'))
import cg_library as library

class FortArt(unittest.TestCase):
 def test_spur_cap_and_foot_faces_keep_native_detail(self):
  sys.path.insert(0,str(ROOT/'tools'))
  from recover_falan_architecture import opaque_paint
  from recover_falan_forts import native_stone
  rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  with Image.open(ROOT/'assets/maps/falan/city_fort_spur_ends.png')as atlas:
   self.assertEqual(atlas.size,(272,204))
   for serial in [10640,10641]:
    e=library.serial_index()[serial];im=opaque_paint(library.image_from_record(e['pack'],e['row']).convert('RGBA'));ends=rows[str(serial)]['spur_ends'];self.assertEqual(len(ends),2)
    for row in ends:
     for quad,rect in zip([row['source_quad'],*row['source_side_quads']],[row['paint'],*row['side_paint']]):
      expected=native_stone(im.transform((64,64),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC),.55);x,y,w,h=rect;self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),expected.tobytes());self.assertEqual(atlas.getpixel((x-2,y-2)),expected.getpixel((0,0)));self.assertEqual(atlas.getpixel((x+w+1,y+h+1)),expected.getpixel((63,63)))

 def test_foundation_spur_faces_recover_the_original_stone(self):
  sys.path.insert(0,str(ROOT/'tools'))
  from recover_falan_architecture import opaque_paint
  from recover_falan_forts import native_stone
  rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  with Image.open(ROOT/'assets/maps/falan/city_fort_wall_spurs.png')as atlas:
   self.assertEqual(atlas.size,(136,196))
   for serial in [10640,10641]:
    e=library.serial_index()[serial];im=opaque_paint(library.image_from_record(e['pack'],e['row']).convert('RGBA'));row=rows[str(serial)]['wall_spur'];expected=native_stone(im.transform((64,192),Image.Transform.QUAD,row['source_quad'],Image.Resampling.BICUBIC),.55);x,y,w,h=row['paint']
    self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),expected.tobytes());self.assertEqual(atlas.getpixel((x-2,y-2)),expected.getpixel((0,0)));self.assertEqual(atlas.getpixel((x+w+1,y+h+1)),expected.getpixel((63,191)))
    differences=[r-g for r,g,b,a in expected.getdata()];self.assertLessEqual(max(differences)-min(differences),1)

 def test_wall_crown_exposed_native_anchor_pixels(self):
  for serial in [10640,10641]:
   e=library.serial_index()[serial];alpha=library.image_from_record(e['pack'],e['row']).convert('RGBA').getchannel('A')
   for x,y in [(47,0),(26,16),(70,16),(102,41),(143,71)]:
    self.assertGreaterEqual(alpha.getpixel((143-x if serial==10641 else x,y)),200,(serial,x,y))

 def test_wall_support_profiles_and_detail_crops_are_native(self):
  sys.path.insert(0,str(ROOT/'tools'))
  from recover_falan_architecture import opaque_paint
  from recover_falan_forts import native_stone
  rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  with Image.open(ROOT/'assets/maps/falan/city_fort_wall_supports.png')as atlas:
   self.assertEqual(atlas.size,(204,136))
   for serial in [10640,10641]:
    e=library.serial_index()[serial];original=library.image_from_record(e['pack'],e['row']).convert('RGBA');source=opaque_paint(original);row=rows[str(serial)];slots=row['wall_supports'];self.assertEqual(len(slots),3)
    for slot in slots:
     expected=native_stone(source.crop(slot['source_crop']).resize((64,64),Image.Resampling.BICUBIC),.55);x,y,w,h=slot['paint'];self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),expected.tobytes());self.assertEqual(atlas.getpixel((x-2,y-2)),expected.getpixel((0,0)));self.assertEqual(atlas.getpixel((x+w+1,y+h+1)),expected.getpixel((63,63)))
     points=[(u+row['origin'][0],v+row['origin'][1])for u,v in slot['profile']];self.assertGreaterEqual(len(points),3)
     # Profile vertices lie on texel boundaries, including the exposed silhouette edge.
     for u,v in points:self.assertGreaterEqual(max(original.getpixel((u+dx,v+dy))[3]for dx in [-1,0]for dy in [-1,0]),200)
     differences=[r-g for r,g,b,a in expected.getdata()];self.assertLessEqual(max(differences)-min(differences),1)

 def test_curtain_wall_openings_keep_both_original_facings(self):
  sys.path.insert(0,str(ROOT/'tools'))
  from recover_falan_architecture import opaque_paint
  from recover_falan_forts import native_stone
  rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  with Image.open(ROOT/'assets/maps/falan/city_fort_wall_openings.png')as atlas:
   self.assertEqual(atlas.size,(216,392))
   for serial in [10640,10641]:
    e=library.serial_index()[serial];source=opaque_paint(library.image_from_record(e['pack'],e['row']).convert('RGBA'));slots=rows[str(serial)]['wall_slits'];self.assertEqual(len(slots),6)
    for row in slots:
     expected=native_stone(source.transform((32,192),Image.Transform.QUAD,row['source_quad'],Image.Resampling.BICUBIC),.85);x,y,w,h=row['paint']
     self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),expected.tobytes());self.assertEqual(atlas.getpixel((x-2,y-2)),expected.getpixel((0,0)));self.assertEqual(atlas.getpixel((x+w+1,y+h+1)),expected.getpixel((31,191)))
     differences=[r-g for r,g,b,a in expected.getdata()];self.assertLessEqual(max(differences)-min(differences),1)

 def test_square_belt_faces_retain_the_original_stone_detail(self):
  sys.path.insert(0,str(ROOT/'tools'))
  from recover_falan_architecture import opaque_paint
  from recover_falan_forts import native_stone
  e=library.serial_index()[10650];source=opaque_paint(library.image_from_record(e['pack'],e['row']).convert('RGBA'));rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())['10650']['square_courses']
  self.assertEqual(len(rows),4)
  with Image.open(ROOT/'assets/maps/falan/city_fort_square_courses.png')as atlas:
   self.assertEqual(atlas.size,(520,72))
   for row in rows:
    expected=native_stone(source.transform((256,32),Image.Transform.QUAD,row['source_quad'],Image.Resampling.BICUBIC),.55);x,y,w,h=row['paint']
    self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),expected.tobytes());self.assertEqual(atlas.getpixel((x-2,y-2)),expected.getpixel((0,0)));self.assertEqual(atlas.getpixel((x+w+1,y+h+1)),expected.getpixel((255,31)))
    differences=[r-g for r,g,b,a in expected.getdata()];self.assertLessEqual(max(differences)-min(differences),1)

 def test_round_shaft_has_a_straight_native_envelope(self):
  e=library.serial_index()[10657];alpha=library.image_from_record(e['pack'],e['row']).convert('RGBA').getchannel('A')
  for y in range(110,211):
   xs=[x for x in range(alpha.width)if alpha.getpixel((x,y))>=200]
   self.assertEqual((min(xs),max(xs)),(12,147),y)

 def test_arrow_atlas_and_foundation_feet_use_original_face_details(self):
  sys.path.insert(0,str(ROOT/'tools'))
  from recover_falan_architecture import opaque_paint
  rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  with Image.open(ROOT/'assets/maps/falan/city_fort_arrow_details.png')as atlas:
   self.assertEqual(atlas.size,(544,216))
   for serial,count in [(10650,6),(10657,7)]:
    e=library.serial_index()[serial];im=opaque_paint(library.image_from_record(e['pack'],e['row']).convert('RGBA'));row=rows[str(serial)];self.assertEqual(len(row['lower_slits']),count)
    for slot in row['lower_slits']:
     expected=im.transform((32,192),Image.Transform.QUAD,slot['source_quad'],Image.Resampling.BICUBIC);x,y,w,h=slot['paint']
     self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),expected.tobytes());self.assertEqual(atlas.getpixel((x-2,y-2)),expected.getpixel((0,0)))
    if serial!=10657:continue
    ox,oy=row['origin']
    for foot in row['feet']:
     q=[v+(ox if i%2==0 else oy)for i,v in enumerate(foot['quad'])];x,y,w,h=foot['paint']
     self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),im.transform((64,64),Image.Transform.QUAD,q,Image.Resampling.BICUBIC).tobytes())
    line=row['course']['points']
    for (u,v),(uu,vv)in zip(line,line[1:]):
     q=(u+ox,v-1.5+oy,u+ox,v+2.5+oy,uu+ox,vv+2.5+oy,uu+ox,vv-1.5+oy);expected=im.transform(((uu-u)*4,16),Image.Transform.QUAD,q,Image.Resampling.BICUBIC);x=2+(u-line[0][0])*4
     self.assertEqual(atlas.crop((x,198,x+expected.width,214)).tobytes(),expected.tobytes())

 def test_native_support_curves(self):
  samples={10651:[(175,100),(200,102),(225,98),(250,94),(275,89),(300,85),(310,84)],10655:[(180,115),(200,118),(215,120),(240,116),(270,111),(300,106),(325,102),(330,101),(335,99)]}
  for serial,controls in samples.items():
   e=library.serial_index()[serial];alpha=library.image_from_record(e['pack'],e['row']).convert('RGBA').getchannel('A')
   for y,outer in controls:
    runs=[]
    for x in range(alpha.width):
     if alpha.getpixel((x,y))<200:continue
     if not runs or x>runs[-1][-1]+1:runs.append([])
     runs[-1].append(x)
    self.assertEqual(max(runs,key=len)[-1],outer,(serial,y))

 def test_paired_tower_support_caps_follow_the_original_variants(self):
  sides={10648:[1],10649:[-1],10651:[-1,1],10652:[-1],10653:[1],10655:[1],10656:[-1],10658:[-1,1],10659:[-1],10660:[1]}
  rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  for serial,facings in sides.items():
   e=library.serial_index()[serial];im=library.image_from_record(e['pack'],e['row']).convert('RGBA');ox,oy=rows[str(serial)]['origin']
   controls=[(27,-114),(56,-132)]if serial<10655 else[(33,-114),(57,-132)]
   for side in facings:
    for u,v in controls:
     x,y=ox+(u if side>0 else 2-u),oy+v
     bright=[im.getpixel((x+dx,y+dy))for dx in [-1,0,1]for dy in [-1,0,1]]
     self.assertGreaterEqual(sum(a>=200 and min(r,g,b)>130 for r,g,b,a in bright),3,(serial,x,y))

 def test_round_tower_hoods_preserve_both_original_drawings(self):
  rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  for serial,feature,box in [(10655,'hood_left',(23,117,54,175)),(10656,'hood_right',(94,117,125,175))]:
   e=library.serial_index()[serial];original=library.image_from_record(e['pack'],e['row']).convert('RGBA')
   self.assertEqual(tuple(rows[str(serial)]['hood']['crop']),box)
   expected=original.crop(box).resize((124,232),Image.Resampling.BICUBIC)
   self.assertEqual(expected.getchannel('A').getextrema(),(255,255))
   with Image.open(ROOT/f'assets/maps/falan/city_fort_{feature}.png')as actual:self.assertEqual(actual.tobytes(),expected.tobytes())

 def test_native_gate_coping_edge_and_step(self):
  e=library.serial_index()[10646];alpha=library.image_from_record(e['pack'],e['row']).convert('RGBA').getchannel('A')
  for x,y in [(145,48),(148,50),(151,52),(154,54),(157,57),(160,59),(163,61),(166,63),(169,66),(172,68),(174,69),(175,74),(176,75)]:
   self.assertEqual(min(v for v in range(30,100)if alpha.getpixel((x,v))>=200),y)

 def test_gate_paving_uses_original_walkway_pixels(self):
  e=library.serial_index()[10662];original=library.image_from_record(e['pack'],e['row']).convert('RGBA')
  patch=original.transform((128,64),Image.Transform.QUAD,(26,59,18,65,42,83,50,77),Image.Resampling.BICUBIC)
  self.assertEqual(patch.getchannel('A').getextrema(),(255,255))
  tone=ImageStat.Stat(patch).mean[:3];luma=ImageOps.grayscale(patch);average=ImageStat.Stat(luma).mean[0]
  channels=[luma.point(lambda v,c=c:round(max(0,min(255,c+(v-average)*.85))))for c in tone]
  expected=Image.merge('RGBA',(*channels,patch.getchannel('A')))
  with Image.open(ROOT/'assets/maps/falan/city_fort_gate_paving.png')as actual:self.assertEqual(actual.tobytes(),expected.tobytes())

 def test_south_jamb_has_a_straight_native_outer_edge(self):
  e=library.serial_index()[10646];original=library.image_from_record(e['pack'],e['row']).convert('RGBA')
  for y in range(195,217):self.assertEqual(min(x for x in range(30,61)if original.getpixel((x,y))[3]>=200),45)

 def test_variant_window_paint_matches_each_original(self):
  rows=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  expected={10647:['arch','arch'],10648:['arch','shutter'],10649:['shutter','arch'],10650:['arch','arch'],10651:['shutter','shutter'],10652:['shutter','arch'],10653:['arch','shutter'],10661:['arch']}
  count=0
  with Image.open(ROOT/'assets/maps/falan/city_fort_windows.png')as atlas:
   for serial,kinds in expected.items():
    windows=rows[str(serial)]['windows'];self.assertEqual([w['kind']for w in windows],kinds)
    e=library.serial_index()[serial];original=library.image_from_record(e['pack'],e['row']).convert('RGBA')
    for window in windows:
     patch=original.transform((64,128),Image.Transform.QUAD,window['source_quad'],Image.Resampling.BICUBIC)
     x,y,w,h=window['paint'];self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),patch.tobytes())
     self.assertEqual(atlas.getpixel((x-2,y-2)),patch.getpixel((0,0)))
     self.assertEqual(atlas.getpixel((x+w+1,y+h+1)),patch.getpixel((w-1,h-1)));count+=1
  self.assertEqual(count,15)

 def test_iron_picket_phase_and_tip_art_are_native(self):
  tips={10646:[(63,199),(71,193),(79,187),(88,186),(128,156),(143,139)],10662:[(2+8*i,117+6*i)for i in range(8)]}
  for serial,points in tips.items():
   row=library.serial_index()[serial];original=library.image_from_record(row['pack'],row['row']).convert('RGBA')
   for point in points:
    r,g,b,a=original.getpixel(point)
    self.assertGreaterEqual(a,200,(serial,point));self.assertLess(max(r,g,b),100,(serial,point))

 def test_tower_crowns_have_one_source_frame_despite_clipped_lower_sprites(self):
  records=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  for serial in [*range(10647,10654),10661,*range(10655,10661)]:
   e=library.serial_index()[serial];original=library.image_from_record(e['pack'],e['row']).convert('RGBA');row=records[str(serial)]
   crop=original.crop(row['crop']);bounds=crop.crop((0,0,crop.width,100)).getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox()
   square=serial in [*range(10647,10654),10661]
   self.assertEqual([row['reference'][0]+bounds[0],row['reference'][1]+bounds[1],bounds[2]-bounds[0]],[-63,-260,128] if square else [-68,-283,137],serial)

 def test_rectified_windows_and_heraldry_use_original_surfaces(self):
  sys.path.insert(0,str(ROOT/'tools'))
  from recover_falan_architecture import opaque_paint
  for name,serial,quad in [('gate_window',10646,(47,170,47,186,55,181,55,165)),('gate_badge',10646,(107,84,107,96,116,90,116,78)),('window',10652,(104,106,104,150,121,140,121,96)),('base',10640,(15,148,15,167,36,183,36,164)),('paving',10657,(65,45,49,57,65,69,81,57)),('leaf',10661,(112,161,112,290,130,279,130,172)),('leaf_front',10647,(1,128,1,255,39,278,39,151)),('banner',10646,(88,125,88,156,99,149,99,118)),('blue_banner',10646,(100,115,100,148,109,143,109,110))]:
   e=library.serial_index()[serial];original=library.image_from_record(e['pack'],e['row']).convert('RGBA')
   expected=opaque_paint(original).transform((128 if name in ['leaf_front','paving','base'] else 64,256 if name.startswith('leaf') else 96 if name=='gate_badge' else 128),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC)
   if name in ['paving','base']:
    tone=ImageStat.Stat(expected).mean[:3];luma=ImageOps.grayscale(expected);average=ImageStat.Stat(luma).mean[0]
    strength=.85 if name=='paving' else .55
    channels=[luma.point(lambda value,c=c:round(max(0,min(255,c+(value-average)*strength))))for c in tone]
    expected=Image.merge('RGBA',(*channels,expected.getchannel('A')))
   with Image.open(ROOT/f'assets/maps/falan/city_fort_{name}.png')as actual:self.assertEqual(actual.tobytes(),expected.tobytes())

 def test_unseen_faces_reuse_native_masonry(self):
  e=library.serial_index()[10640]
  original=library.image_from_record(e['pack'],e['row']).convert('RGBA')
  patch=original.transform((64,64),Image.Transform.QUAD,(45,130,45,139,52,144,52,135),Image.Resampling.BICUBIC)
  tone=ImageStat.Stat(patch).mean[:3];luma=ImageOps.grayscale(patch);average=ImageStat.Stat(luma).mean[0]
  channels=[luma.point(lambda value,c=c:round(max(0,min(255,c+(value-average)*.28))))for c in tone]
  patch=Image.merge('RGBA',(*channels,patch.getchannel('A')))
  with Image.open(ROOT/'assets/maps/falan/city_fort_masonry.png')as actual:
   self.assertEqual(actual.crop((0,0,64,64)).tobytes(),patch.tobytes())
   self.assertEqual(actual.crop((64,0,128,64)).tobytes(),ImageOps.mirror(patch).tobytes())
   self.assertEqual(actual.crop((0,64,128,128)).tobytes(),ImageOps.flip(actual.crop((0,0,128,64))).tobytes())
   self.assertEqual(actual.getchannel('A').getextrema(),(255,255))

 def test_all_original_fort_paint_and_projection_anchors_are_preserved(self):
  records=json.loads((ROOT/'assets/maps/falan/city_fort_paint.json').read_text())
  self.assertEqual(set(map(int,records)),set(range(10640,10654))|set(range(10655,10663)))
  with Image.open(ROOT/'assets/maps/falan/city_fort_paint.png')as atlas,Image.open(ROOT/'assets/maps/falan/city_fort_mask.png')as mask:
   for key,row in records.items():
    e=library.serial_index()[int(key)];original=library.image_from_record(e['pack'],e['row']).convert('RGBA')
    self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),row['rgba_sha256'])
    box=original.getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox()
    origin=[-e['x']+(e['east']-e['south'])*16,-e['y']-(e['east']+e['south']-2)*12]
    self.assertEqual(row['reference'],[box[0]-origin[0],box[1]-origin[1],box[2]-box[0],box[3]-box[1]])
    x,y,w,h=row['paint'];rect=(x,y,x+w,y+h);native=original.crop(box);prepared=atlas.crop(rect)
    self.assertEqual(mask.crop(rect).tobytes(),native.getchannel('A').tobytes())
    self.assertEqual(prepared.getchannel('A').getextrema(),(255,255))
    for before,after in zip(native.getdata(),prepared.getdata()):
     if before[3]>=128:self.assertEqual(before[:3],after[:3],key)

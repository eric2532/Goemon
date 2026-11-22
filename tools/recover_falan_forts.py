"""Preserve original Falan fort paint and native camera measurements."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image, ImageOps, ImageStat
from recover_falan_architecture import opaque_paint

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan'
REVIEW=ROOT/'build/Other Files/Asset Toolkit/Falan Exterior Fidelity'
SERIALS=tuple(range(10640,10654))+tuple(range(10655,10663))
FEATURES={'window':(10652,(104,106,104,150,121,140,121,96),(64,128)),
          'base':(10640,(15,148,15,167,36,183,36,164),(128,128)),
          'gate_window':(10646,(47,170,47,186,55,181,55,165),(64,128)),
          'gate_badge':(10646,(107,84,107,96,116,90,116,78),(64,96)),
          'paving':(10657,(65,45,49,57,65,69,81,57),(128,128)),
          'gate_paving':(10662,(26,59,18,65,42,83,50,77),(128,64)),
          'leaf':(10661,(112,161,112,290,130,279,130,172),(64,256)),
          'leaf_front':(10647,(1,128,1,255,39,278,39,151),(128,256)),
          'banner':(10646,(88,125,88,156,99,149,99,118),(64,128)),
          'blue_banner':(10646,(100,115,100,148,109,143,109,110),(64,128))}
HOODS={
 10655:{'feature':'hood_left','crop':(23,117,54,175),
        'profile':[(24,134),(24,130),(26,126),(29,123),(32,122),(35,123),(39,128),(43,136),(47,147),(47,151)],
        'window':[(28,139),(39,147),(39,165),(37,170),(34,174),(30,171),(28,165)]},
 10656:{'feature':'hood_right','crop':(94,117,125,175),
        'profile':[(124,134),(124,130),(122,126),(119,123),(116,122),(113,123),(109,128),(105,136),(101,147),(101,151)],
        'window':[(119,139),(108,147),(108,165),(110,170),(113,174),(117,171),(119,165)]}}
WINDOW_KINDS={10647:('arch','arch'),10648:('arch','shutter'),10649:('shutter','arch'),10650:('arch','arch'),10651:('shutter','shutter'),10652:('shutter','arch'),10653:('arch','shutter'),10661:('arch',None)}
WINDOW_QUADS={
 ('left','arch'):(-40,-164,-40,-120,-23,-110,-23,-154),
 ('right','arch'):(25,-154,25,-110,42,-120,42,-164),
 ('left','shutter'):(-39,-157,-39,-135,-23,-122,-23,-144),
 ('right','shutter'):(25,-144,25,-122,41,-135,41,-157)}
SQUARE_SLITS=[(-51,-86,-51,-48,-44,-42.75,-44,-80.75),(-34,-73,-34,-35,-27,-29.75,-27,-67.75),(-18,-60,-18,-22,-11,-16.75,-11,-54.75)]
SQUARE_SLITS += [tuple(v for i in [3,2,1,0]for v in (1-q[2*i],q[2*i+1]))for q in SQUARE_SLITS[:]]
ROUND_SLITS=[(-65,-91,-65,-52,-60,-50.5,-60,-89.5),(-53,-72,-53,-31,-47,-29,-47,-70),(-30,-57,-30,-16,-23,-15,-23,-56),(-3,-50,-3,-6,4,-6,4,-50),(24,-56,24,-15,31,-16,31,-57),(48,-70,48,-29,54,-31,54,-72),(65,-89.5,65,-50.5,68,-52,68,-91)]
ROUND_COURSE=[(-67,-98),(-65,-96),(-51,-82),(-27,-71),(1,-66),(29,-71),(53,-82),(67,-96),(68,-98)]
ROUND_FEET=[(-79,-19,-73,-23.5,-63,-16,-69,-11.5),(65,-12,75,-19.5,81,-15,71,-7.5)]
SQUARE_COURSES=[(-63,-112,-63,-104,0,-56.75,0,-64.75),(0,-64.75,0,-56.75,63,-104,63,-112),(-63,-44,-63,-38,0,9.25,0,3.25),(0,3.25,0,9.25,63,-38,63,-44)]

WALL_SLITS={
 10640:[
  (-52.390055, -118.342541, -59.328177, -78.696133, -54.090608, -74.767956, -47.152486, -114.414365),
  (-36.274033, -107.005525, -43.444199, -66.033149, -37.919337, -61.889503, -30.749171, -102.861878),
  (-20.274033, -95.005525, -27.444199, -54.033149, -21.919337, -49.889503, -14.749171, -90.861878),
  (-4.428729, -83.121547, -11.598895, -42.149171, -5.919337, -37.889503, 1.250829, -78.861878),
  (11.532597, -70.900552, 4.401105, -30.149171, 10.080663, -25.889503, 17.212155, -66.640884),
  (27.609945, -59.342541, 20.401105, -18.149171, 26.080663, -13.889503, 33.289503, -55.082873),
 ],
 10641:[
  (-32.289503, -55.082873, -25.080663, -13.889503, -19.401105, -18.149171, -26.609945, -59.342541),
  (-16.250829, -66.861878, -9.080663, -25.889503, -3.401105, -30.149171, -10.571271, -71.121547),
  (-0.250829, -78.861878, 6.919337, -37.889503, 12.598895, -42.149171, 5.428729, -83.121547),
  (15.749171, -90.861878, 22.919337, -49.889503, 28.908287, -54.381215, 21.738122, -95.353591),
  (31.749171, -102.861878, 38.919337, -61.889503, 44.908287, -66.381215, 37.738122, -107.353591),
  (48.064088, -114.348066, 55.00221, -74.701657, 60.328177, -78.696133, 53.390055, -118.342541),
 ],
}

WALL_SUPPORTS={
 10640:[[(28, 46), (31, 43), (32, 43), (35, 44), (40, 48), (43, 51), (43, 52), (42, 57), (41, 59), (35, 60), (33, 60), (28, 51)], [(59, 65), (60, 64), (61, 64), (72, 70), (75, 73), (75, 77), (74, 81), (72, 83), (69, 83), (66, 82), (64, 81), (61, 76), (60, 74), (59, 66)], [(92, 90), (94, 89), (95, 89), (108, 97), (108, 99), (105, 107), (97, 107), (92, 99)]],
 10641:[[(33, 103), (36, 97), (49, 89), (50, 89), (52, 90), (54, 99), (54, 109), (51, 110), (47, 111), (38, 112), (37, 112), (35, 111), (33, 108)], [(66, 81), (68, 74), (72, 70), (83, 64), (86, 64), (87, 66), (88, 74), (88, 75), (80, 85), (69, 88), (66, 88)], [(100, 50), (101, 49), (112, 41), (116, 39), (120, 39), (122, 48), (122, 49), (121, 55), (120, 57), (116, 62), (114, 63), (109, 64), (108, 64), (101, 58), (100, 51)]],
}

WALL_SPURS={10640:(45,186.5,39,218.25,44,222,50,190.25),10641:(98,186.5,104,218.25,99,222,93,190.25)}
SPUR_ENDS=[((48,183.5,45.5,185.5,51,189.625,53.5,187.625),3.1,.4),((39,214,35.5,216.5,42,221.375,45.5,218.875),.25,.25)]

def native_stone(patch,strength):
 tone=ImageStat.Stat(patch).mean[:3];luma=ImageOps.grayscale(patch);average=ImageStat.Stat(luma).mean[0]
 # Keep native tone and stone relief without magnifying palette-dither chroma into repeating rainbows.
 channels=[luma.point(lambda value,c=c:round(max(0,min(255,c+(value-average)*strength))))for c in tone]
 return Image.merge('RGBA',(*channels,patch.getchannel('A')))

def recover(source):
 sys.path.insert(0,str(source/'tools'))
 import cg_library as library
 lookup=library.serial_index();records={};images=[];x=y=tallest=0;masonry=None;features={};window_atlas=Image.new('RGBA',(272,528));window_slot=0
 arrow_atlas=Image.new('RGBA',(544,216));slits={};arrow_slot=0;courses=Image.new('RGBA',(520,72));course_rows=[];wall_atlas=Image.new('RGBA',(216,392));wall_rows={};support_atlas=Image.new('RGBA',(204,136));support_rows={};spur_atlas=Image.new('RGBA',(136,196));spur_rows={};end_atlas=Image.new('RGBA',(272,204));end_rows={}
 REVIEW.mkdir(parents=True,exist_ok=True)
 for serial in SERIALS:
  e=lookup[serial];original=library.image_from_record(e['pack'],e['row']).convert('RGBA')
  original.save(REVIEW/f'original-fort-{serial}.png')
  for name,(owner,quad,size)in FEATURES.items():
   if serial==owner:
    patch=opaque_paint(original).transform(size,Image.Transform.QUAD,quad,Image.Resampling.BICUBIC)
    features[name]=native_stone(patch,.85 if name in ('paving','gate_paving') else .55) if name in ('paving','gate_paving','base') else patch
  if serial==10640:
   patch=original.transform((64,64),Image.Transform.QUAD,(45,130,45,139,52,144,52,135),Image.Resampling.BICUBIC)
   assert patch.getchannel('A').getextrema()==(255,255)
   patch=native_stone(patch,.28)
   masonry=Image.new('RGBA',(128,128));masonry.paste(patch,(0,0));masonry.paste(ImageOps.mirror(patch),(64,0));masonry.paste(ImageOps.flip(masonry.crop((0,0,128,64))),(0,64))
  box=original.getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox();assert box
  crop=original.crop(box)
  origin=[-e['x']+(e['east']-e['south'])*16,-e['y']-(e['east']+e['south']-2)*12]
  if serial in [10650,10657]:
   family='square'if serial==10650 else'round';slits[family]=[]
   for quad in SQUARE_SLITS if serial==10650 else ROUND_SLITS:
    source_quad=[v+origin[i%2]for i,v in enumerate(quad)];patch=opaque_paint(original).transform((32,192),Image.Transform.QUAD,source_quad,Image.Resampling.BICUBIC)
    wx=arrow_slot*36;arrow_slot+=1;arrow_atlas.paste(patch,(wx+2,2))
    arrow_atlas.paste(patch.crop((0,0,1,192)).resize((2,192)),(wx,2));arrow_atlas.paste(patch.crop((31,0,32,192)).resize((2,192)),(wx+34,2))
    arrow_atlas.paste(arrow_atlas.crop((wx,2,wx+36,3)).resize((36,2)),(wx,0));arrow_atlas.paste(arrow_atlas.crop((wx,193,wx+36,194)).resize((36,2)),(wx,194))
    slits[family].append({'paint':[wx+2,2,32,192],'quad':quad,'source_quad':source_quad})
   if serial==10657:
    for (u,v),(uu,vv)in zip(ROUND_COURSE,ROUND_COURSE[1:]):
     quad=(u+origin[0],v-1.5+origin[1],u+origin[0],v+2.5+origin[1],uu+origin[0],vv+2.5+origin[1],uu+origin[0],vv-1.5+origin[1])
     patch=opaque_paint(original).transform(((uu-u)*4,16),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC);arrow_atlas.paste(patch,((u-ROUND_COURSE[0][0])*4+2,198))
    arrow_atlas.paste(arrow_atlas.crop((2,198,3,214)).resize((2,16)),(0,198));arrow_atlas.paste(arrow_atlas.crop((541,198,542,214)).resize((2,16)),(542,198))
    arrow_atlas.paste(arrow_atlas.crop((0,198,544,199)).resize((544,2)),(0,196));arrow_atlas.paste(arrow_atlas.crop((0,213,544,214)).resize((544,2)),(0,214))
    for i,quad in enumerate(ROUND_FEET):
     source_quad=[v+origin[j%2]for j,v in enumerate(quad)];patch=opaque_paint(original).transform((64,64),Image.Transform.QUAD,source_quad,Image.Resampling.BICUBIC);wy=2+i*68;arrow_atlas.paste(patch,(474,wy))
     arrow_atlas.paste(patch.crop((0,0,1,64)).resize((2,64)),(472,wy));arrow_atlas.paste(patch.crop((63,0,64,64)).resize((2,64)),(538,wy))
     arrow_atlas.paste(arrow_atlas.crop((472,wy,540,wy+1)).resize((68,2)),(472,wy-2));arrow_atlas.paste(arrow_atlas.crop((472,wy+63,540,wy+64)).resize((68,2)),(472,wy+64))
  if serial in WALL_SLITS:
   wall_rows[serial]=[]
   for i,quad in enumerate(WALL_SLITS[serial]):
    source_quad=[v+origin[j%2]for j,v in enumerate(quad)];patch=native_stone(opaque_paint(original).transform((32,192),Image.Transform.QUAD,source_quad,Image.Resampling.BICUBIC),.85);wx=i*36;wy=0 if serial==10640 else 196
    wall_atlas.paste(patch,(wx+2,wy+2));wall_atlas.paste(patch.crop((0,0,1,192)).resize((2,192)),(wx,wy+2));wall_atlas.paste(patch.crop((31,0,32,192)).resize((2,192)),(wx+34,wy+2))
    wall_atlas.paste(wall_atlas.crop((wx,wy+2,wx+36,wy+3)).resize((36,2)),(wx,wy));wall_atlas.paste(wall_atlas.crop((wx,wy+193,wx+36,wy+194)).resize((36,2)),(wx,wy+194))
    wall_rows[serial].append({'paint':[wx+2,wy+2,32,192],'quad':quad,'source_quad':source_quad})
  if serial in WALL_SPURS:
   quad=WALL_SPURS[serial];patch=native_stone(opaque_paint(original).transform((64,192),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC),.55);wx=0 if serial==10640 else 68
   spur_atlas.paste(patch,(wx+2,2));spur_atlas.paste(patch.crop((0,0,1,192)).resize((2,192)),(wx,2));spur_atlas.paste(patch.crop((63,0,64,192)).resize((2,192)),(wx+66,2))
   spur_atlas.paste(spur_atlas.crop((wx,2,wx+68,3)).resize((68,2)),(wx,0));spur_atlas.paste(spur_atlas.crop((wx,193,wx+68,194)).resize((68,2)),(wx,194))
   spur_rows[serial]={'paint':[wx+2,2,64,192],'quad':[v-origin[i%2]for i,v in enumerate(quad)],'source_quad':quad}
   end_rows[serial]=[]
   for i,(quad,height,depth)in enumerate(SPUR_ENDS):
    quad=[143-v if serial==10641 and j%2==0 else v for j,v in enumerate(quad)];sides=[]
    for a,b in [(1,2),(2,3)]:sides.append([quad[a*2],quad[a*2+1],quad[a*2],quad[a*2+1]+depth*(2*((32/3)**2-8**2))**.5,quad[b*2],quad[b*2+1]+depth*(2*((32/3)**2-8**2))**.5,quad[b*2],quad[b*2+1]])
    regions=[]
    for face,face_quad in enumerate([quad,*sides]):
     slot=(0 if serial==10640 else 6)+i*3+face;wx=slot%4*68;wy=slot//4*68;patch=native_stone(opaque_paint(original).transform((64,64),Image.Transform.QUAD,face_quad,Image.Resampling.BICUBIC),.55)
     padded=Image.new('RGBA',(68,68));padded.paste(patch,(2,2))
     for edge,at,size in [((0,0,1,64),(0,2),(2,64)),((63,0,64,64),(66,2),(2,64)),((0,0,64,1),(2,0),(64,2)),((0,63,64,64),(2,66),(64,2)),((0,0,1,1),(0,0),(2,2)),((63,0,64,1),(66,0),(2,2)),((0,63,1,64),(0,66),(2,2)),((63,63,64,64),(66,66),(2,2))]:padded.paste(patch.crop(edge).resize(size),at)
     end_atlas.paste(padded,(wx,wy));regions.append([wx+2,wy+2,64,64])
    end_rows[serial].append({'paint':regions[0],'quad':[v-origin[j%2]for j,v in enumerate(quad)],'source_quad':quad,'height':height,'depth':depth,'side_paint':regions[1:],'side_quads':[[v-origin[j%2]for j,v in enumerate(q)]for q in sides],'source_side_quads':sides})
  if serial in WALL_SUPPORTS:
   support_rows[serial]=[]
   for i,profile in enumerate(WALL_SUPPORTS[serial]):
    left=min(x for x,y in profile);top=min(y for x,y in profile);right=max(x for x,y in profile);bottom=max(y for x,y in profile)
    patch=native_stone(opaque_paint(original).crop((left,top,right,bottom)).resize((64,64),Image.Resampling.BICUBIC),.55);wx=i*68;wy=0 if serial==10640 else 68
    support_atlas.paste(patch,(wx+2,wy+2));support_atlas.paste(patch.crop((0,0,1,64)).resize((2,64)),(wx,wy+2));support_atlas.paste(patch.crop((63,0,64,64)).resize((2,64)),(wx+66,wy+2))
    support_atlas.paste(support_atlas.crop((wx,wy+2,wx+68,wy+3)).resize((68,2)),(wx,wy));support_atlas.paste(support_atlas.crop((wx,wy+65,wx+68,wy+66)).resize((68,2)),(wx,wy+66))
    support_rows[serial].append({'paint':[wx+2,wy+2,64,64],'source_crop':[left,top,right,bottom],'bounds':[left-origin[0],top-origin[1],right-left,bottom-top],'profile':[[x-origin[0],y-origin[1]]for x,y in profile]})
  if serial==10650:
   for i,quad in enumerate(SQUARE_COURSES):
    source_quad=[v+origin[j%2]for j,v in enumerate(quad)];patch=native_stone(opaque_paint(original).transform((256,32),Image.Transform.QUAD,source_quad,Image.Resampling.BICUBIC),.55);wx=i%2*260;wy=i//2*36
    courses.paste(patch,(wx+2,wy+2));courses.paste(patch.crop((0,0,1,32)).resize((2,32)),(wx,wy+2));courses.paste(patch.crop((255,0,256,32)).resize((2,32)),(wx+258,wy+2))
    courses.paste(courses.crop((wx,wy+2,wx+260,wy+3)).resize((260,2)),(wx,wy));courses.paste(courses.crop((wx,wy+33,wx+260,wy+34)).resize((260,2)),(wx,wy+34))
    course_rows.append({'paint':[wx+2,wy+2,256,32],'quad':quad,'source_quad':source_quad})
  if serial in HOODS:
   hood=HOODS[serial];left,top,right,bottom=hood['crop']
   features[hood['feature']]=original.crop(hood['crop']).resize(((right-left)*4,(bottom-top)*4),Image.Resampling.BICUBIC)
  if x+crop.width+4>2048:x=0;y+=tallest;tallest=0
  at=[x+2,y+2,crop.width,crop.height]
  records[str(serial)]={'paint':at,'reference':[box[0]-origin[0],box[1]-origin[1],crop.width,crop.height],'origin':origin,'crop':box,'footprint':[e['south'],e['east']],'rgba_sha256':hashlib.sha256(original.tobytes()).hexdigest()}
  if serial in HOODS:records[str(serial)]['hood']=HOODS[serial]
  if serial in [10650,10657]:records[str(serial)]['lower_slits']=slits[family]
  if serial in WALL_SLITS:records[str(serial)]['wall_slits']=wall_rows[serial]
  if serial in WALL_SUPPORTS:records[str(serial)]['wall_supports']=support_rows[serial]
  if serial in WALL_SPURS:records[str(serial)]['wall_spur']=spur_rows[serial]
  if serial in end_rows:records[str(serial)]['spur_ends']=end_rows[serial]
  if serial==10650:records[str(serial)]['square_courses']=course_rows
  if serial==10657:records[str(serial)]['course']={'points':ROUND_COURSE,'paint':[2,198,540,16]}
  if serial==10657:records[str(serial)]['feet']=[{'paint':[474,2+i*68,64,64],'quad':q}for i,q in enumerate(ROUND_FEET)]
  for face,kind in zip(('left','right'),WINDOW_KINDS.get(serial,())):
   if kind is None:continue
   quad=WINDOW_QUADS[face,kind];source_quad=[value+origin[i%2]for i,value in enumerate(quad)]
   patch=opaque_paint(original).transform((64,128),Image.Transform.QUAD,source_quad,Image.Resampling.BICUBIC)
   wx=window_slot%4*68;wy=window_slot//4*132
   padded=Image.new('RGBA',(68,132));padded.paste(patch,(2,2))
   for edge,edge_at,edge_size in [((0,0,1,128),(0,2),(2,128)),((63,0,64,128),(66,2),(2,128)),((0,0,64,1),(2,0),(64,2)),((0,127,64,128),(2,130),(64,2)),((0,0,1,1),(0,0),(2,2)),((63,0,64,1),(66,0),(2,2)),((0,127,1,128),(0,130),(2,2)),((63,127,64,128),(66,130),(2,2))]:padded.paste(patch.crop(edge).resize(edge_size,Image.Resampling.NEAREST),edge_at)
   window_atlas.paste(padded,(wx,wy))
   records[str(serial)].setdefault('windows',[]).append({'face':face,'kind':kind,'quad':quad,'source_quad':source_quad,'paint':[wx+2,wy+2,64,128]});window_slot+=1
  for name,(owner,quad,size)in FEATURES.items():
   if serial==owner:records[str(serial)].setdefault('features',{})[name]={'quad':quad,'size':size}
  images.append((opaque_paint(crop),crop.getchannel('A'),at));x+=crop.width+4;tallest=max(tallest,crop.height+4)
 atlas=Image.new('RGBA',(2048,y+tallest));mask=Image.new('L',atlas.size)
 for im,alpha,at in images:atlas.paste(im,at[:2]);mask.paste(alpha,at[:2])
 rows=['extends RefCounted','## Original native fort measurements; generated by tools/recover_falan_forts.py.','const PARTS={']
 for serial,r in records.items():rows.append(' %s:[Rect2(%s),Rect2(%s)],'%(serial,','.join(map(str,r['paint'])),','.join(map(str,r['reference']))))
 rows+=['}','const WINDOWS={']
 for serial,r in records.items():
  if 'windows'not in r:continue
  items=[]
  for window in r['windows']:
   quad=window['quad'];points=','.join('Vector2(%s,%s)'%(quad[i],quad[i+1])for i in range(0,8,2))
   items.append('[%s,%s,Rect2(%s),[%s]]'%('true'if window['face']=='right'else'false','true'if window['kind']=='arch'else'false',','.join(map(str,window['paint'])),points))
  rows.append(' %s:[%s],'%(serial,','.join(items)))
 rows+=['}','const HOODS={']
 for serial,hood in HOODS.items():
  origin=records[str(serial)]['origin'];left,top,right,bottom=hood['crop'];profiles=[]
  for key in ['profile','window']:profiles.append('['+','.join('Vector2(%s,%s)'%(x-origin[0],y-origin[1])for x,y in hood[key])+']')
  rows.append(' %s:[%s,%s,Rect2(%s,%s,%s,%s)],'%(serial,*profiles,left-origin[0],top-origin[1],right-left,bottom-top))
 rows+=['}','const LOWER_SLITS={']
 for family,items in slits.items():
  values=[]
  for item in items:
   q=item['quad'];points=','.join('Vector2(%s,%s)'%(q[i],q[i+1])for i in range(0,8,2));values.append('[Rect2(%s),[%s]]'%(','.join(map(str,item['paint'])),points))
  rows.append(' "%s":[%s],'%(family,','.join(values)))
 rows+=['}','const ROUND_COURSE=[Rect2(2,198,540,16),[%s]]'%','.join('Vector2(%s,%s)'%p for p in ROUND_COURSE)]
 rows+=['const ROUND_FEET=[%s]'%','.join('[Rect2(474,%s,64,64),[%s]]'%(2+i*68,','.join('Vector2(%s,%s)'%(q[j],q[j+1])for j in range(0,8,2)))for i,q in enumerate(ROUND_FEET))]
 rows+=['const SQUARE_COURSES=[%s]'%','.join('[Rect2(%s),[%s]]'%(','.join(map(str,r['paint'])),','.join('Vector2(%s,%s)'%(r['quad'][j],r['quad'][j+1])for j in range(0,8,2)))for r in course_rows)]
 features['windows']=window_atlas;features['arrow_details']=arrow_atlas
 rows+=['const WALL_SLITS={']
 for serial,items in wall_rows.items():
  rows.append(' %s:[%s],'%(serial,','.join('[Rect2(%s),[%s]]'%(','.join(map(str,r['paint'])),','.join('Vector2(%s,%s)'%(r['quad'][j],r['quad'][j+1])for j in range(0,8,2)))for r in items)))
 rows+=['}']
 rows+=['const WALL_SUPPORTS={']
 for serial,items in support_rows.items():
  rows.append(' %s:[%s],'%(serial,','.join('[Rect2(%s),Rect2(%s),[%s]]'%(','.join(map(str,r['paint'])),','.join(map(str,r['bounds'])),','.join('Vector2(%s,%s)'%(x,y)for x,y in r['profile']))for r in items)))
 rows+=['}']
 rows+=['const WALL_SPURS={']
 for serial,r in spur_rows.items():
  q=r['quad'];rows.append(' %s:[Rect2(%s),[%s]],'%(serial,','.join(map(str,r['paint'])),','.join('Vector2(%s,%s)'%(q[i],q[i+1])for i in range(0,8,2))))
 rows+=['}']
 features['wall_spurs']=spur_atlas
 rows+=['const SPUR_ENDS={']
 for serial,items in end_rows.items():
  encoded=[]
  for r in items:
   points=lambda q:','.join('Vector2(%s,%s)'%(q[j],q[j+1])for j in range(0,8,2))
   sides=','.join('[Rect2(%s),[%s]]'%(','.join(map(str,rect)),points(q))for rect,q in zip(r['side_paint'],r['side_quads']))
   encoded.append('[Rect2(%s),[%s],%s,%s,[%s]]'%(','.join(map(str,r['paint'])),points(r['quad']),r['height'],r['depth'],sides))
  rows.append(' %s:[%s],'%(serial,','.join(encoded)))
 rows+=['}'];features['spur_ends']=end_atlas
 features['wall_supports']=support_atlas
 features['wall_openings']=wall_atlas
 features['square_courses']=courses
 return records,'\n'.join(rows)+'\n',atlas,mask,masonry,features

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');a=p.parse_args()
 records,text,atlas,mask,masonry,features=recover(a.source)
 outputs=[('city_fort_paint.png',atlas),('city_fort_mask.png',mask),('city_fort_masonry.png',masonry)]+[(f'city_fort_{name}.png',im)for name,im in features.items()]
 if a.check:
  assert json.loads((OUT/'city_fort_paint.json').read_text())==json.loads(json.dumps(records))
  assert (OUT/'city_fort_paint.gd').read_text()==text
  for name,expected in outputs:
   with Image.open(OUT/name)as actual:assert actual.size==expected.size and actual.tobytes()==expected.tobytes()
 else:
  (OUT/'city_fort_paint.gd').write_text(text);(OUT/'city_fort_paint.json').write_text(json.dumps(records,indent=2)+'\n')
  for name,im in outputs:im.save(OUT/name,optimize=True)
 print('PASS: preserved and measured',len(records),'original fort graphics')

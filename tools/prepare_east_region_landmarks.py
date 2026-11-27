"""Prepare native landmark references, separate surface paint and measured exterior profiles."""
import argparse
import ast
import hashlib
import json
import math
from pathlib import Path

from PIL import Image,ImageDraw,ImageFilter,ImageChops
from build_village_building_surfaces import surface_atlas
from recover_venoa_walls import native_without_ground_shadow
from east_region_landmark_profiles import REGIONAL,SURFACES,SOURCE_ROCKS,ROCK_HOLES,STATUES
from east_region_classic_landmarks import REUSED,SHELTERS,COMPOUNDS as CLASSIC_COMPOUNDS,ROCKS as CLASSIC_ROCKS,HOLES as CLASSIC_HOLES,SURFACES as CLASSIC_SURFACES
from prepare_abanis_cliffs import measured_profile
from prepare_east_stone_profiles import source_contour_profile
from east_region_living_trees import apply_living_shapes
from east_region_tree_families import records as tree_family_records,prepare as prepare_tree_family

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/maps/original_crossgate'
OUT=ROOT/'assets/maps/falan/east_region/landmarks'
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks'

# Visible feet, curved eaves and roof apex in the unchanged native drawing.
HOUSES={
 1233000:dict(feet=[[52,381],[187,473],[346,377]],eaves=[[4,247],[197,379],[392,243]],apex=[196,86],wall_pixels=95,finial=[160,0,234,86]),
 1233001:dict(feet=[[50,373],[180,468],[344,366]],eaves=[[5,239],[190,369],[390,238]],apex=[196,81],wall_pixels=94,finial=[166,0,223,82]),
 1233005:dict(feet=[[50,350],[178,445],[344,342]],eaves=[[5,217],[188,347],[390,217]],apex=[196,60],wall_pixels=96,finial=[165,0,224,61]),
}
# Compound masses are measured independently, so towers and living trunks retain depth at other angles.
COMPOUNDS={
1233006:dict(houses=[dict(feet=[[51,516],[181,619],[350,516]],eaves=[[4,393],[193,526],[392,392]],apex=[193,275],wall_pixels=95),dict(feet=[[139,308],[194,345],[249,308]],eaves=[[115,209],[195,261],[274,208]],apex=[196,52],wall_pixels=72,level_pixels=230)],details=[[160,0,220,55]]),
1233007:dict(houses=[dict(feet=[[34,337],[332,505],[461,410]],eaves=[[4,191],[332,393],[479,284]],apex=[194,50],wall_pixels=111,roof='roof_green')],towers=[dict(base=[397,437],level_pixels=0,height_pixels=230,diameter=52,material='plaster',profile=[[0,.8],[.8,.8],[.81,1],[.86,1],[.91,.55],[1,0]])],details=[[166,0,225,63]]),
1233003:dict(houses=[dict(feet=[[49,501],[295,638],[397,563]],eaves=[[2,350],[299,552],[449,456]],apex=[138,280],wall_pixels=87,roof='roof_red'),dict(feet=[[100,382],[300,506],[344,474]],eaves=[[87,207],[299,352],[365,302]],apex=[188,145],wall_pixels=150,level_pixels=88,roof='roof_red')],towers=[dict(base=[155,238],level_pixels=245,height_pixels=182,diameter=100,material='roof_red',profile=[[0,1],[.12,.83],[.55,.45],[.88,.19],[1,0]]),dict(base=[299,329],level_pixels=245,height_pixels=177,diameter=98,material='roof_red',profile=[[0,1],[.12,.83],[.55,.45],[.88,.19],[1,0]])],details=[[138,0,182,60],[279,91,322,156]]),
1233004:dict(houses=[dict(feet=[[45,548],[164,639],[407,491]],eaves=[[2,449],[160,550],[448,353]],apex=[291,276],wall_pixels=87),dict(feet=[[109,473],[164,506],[355,381]],eaves=[[82,300],[163,350],[365,206]],apex=[279,147],wall_pixels=150,level_pixels=88)],towers=[dict(base=[163,328],level_pixels=245,height_pixels=184,diameter=102,material='roof_gold',profile=[[0,1],[.12,.83],[.55,.45],[.88,.19],[1,0]]),dict(base=[299,237],level_pixels=245,height_pixels=182,diameter=100,material='roof_gold',profile=[[0,1],[.12,.83],[.55,.45],[.88,.19],[1,0]])],details=[[137,90,189,150],[275,0,319,60]]),
1233002:dict(houses=[dict(feet=[[49,341],[175,449],[343,335]],eaves=[[3,199],[176,329],[378,195]],apex=[281,8],ridge=[[75,151],[281,5]],wall_pixels=115)],towers=[dict(base=[177,337],level_pixels=82,height_pixels=275,diameter=111,material='roof_gold',profile=[[0,1],[.12,.85],[.48,.42],[.94,.05],[1,0]])],details=[[144,0,197,65]]),
1233012:dict(towers=[dict(base=[114,320],height_pixels=220,diameter=153,material='brick',profile=[[0,1],[.12,1.05],[.64,.61],[1,.48]])],details=[[54,0,172,118]]),
1233017:dict(towers=[dict(base=[113,320],height_pixels=220,diameter=153,material='brick',profile=[[0,1],[.12,1.05],[.64,.61],[1,.48]])],details=[[53,0,171,118]]),
1233056:dict(towers=[dict(base=[81,275],height_pixels=128,diameter=150,material='stone',profile=[[0,1],[.08,1],[.1,.88],[1,.88]]),dict(base=[80,169],level_pixels=130,height_pixels=118,diameter=150,material='roof_blue',profile=[[0,.86],[.12,1],[.45,.92],[.7,.66],[.9,.30],[1,0]])],details=[[55,0,101,51]]),
}
TREEHOUSES={
1230039:dict(trunks=[dict(base=[180,336],height_pixels=331,diameter=96)],houses=[dict(feet=[[67,273],[156,333],[281,258]],eaves=[[8,150],[159,250],[293,156]],apex=[161,77],wall_pixels=88,roof='roof_blue')],stairs=[dict(near=[[53,318],[82,338]],far=[[81,265],[113,283]],height_pixels=40,steps=6)],crowns=[[251,36,390,174]]),
1230064:dict(trunks=[dict(base=[161,389],height_pixels=282,diameter=100)],houses=[dict(feet=[[56,322],[170,393],[274,324]],eaves=[[5,211],[161,306],[301,210]],apex=[173,148],wall_pixels=84,roof='roof_blue')],stairs=[dict(near=[[233,392],[262,373]],far=[[202,321],[233,302]],height_pixels=45,steps=7)],crowns=[[78,0,242,159],[0,103,92,198]]),
1230062:dict(trunks=[dict(base=[249,551],height_pixels=545,diameter=107),dict(base=[383,466],height_pixels=415,diameter=91)],houses=[dict(feet=[[160,455],[256,520],[362,451]],eaves=[[85,361],[256,471],[420,366]],apex=[274,281],wall_pixels=79),dict(feet=[[288,412],[375,471],[472,412]],eaves=[[245,297],[382,393],[488,311]],apex=[363,219],wall_pixels=76),dict(feet=[[247,294],[329,351],[416,293]],eaves=[[184,148],[328,245],[447,158]],apex=[315,78],wall_pixels=93,level_pixels=170)],stairs=[dict(near=[[287,553],[325,530]],far=[[263,503],[301,479]],height_pixels=38,steps=6),dict(near=[[418,461],[453,439]],far=[[394,415],[428,394]],height_pixels=38,steps=6)],crowns=[[399,30,552,173],[118,178,254,276],[0,257,149,391]]),
1230063:dict(trunks=[dict(base=[276,544],height_pixels=538,diameter=106),dict(base=[147,450],height_pixels=399,diameter=91)],houses=[dict(feet=[[197,466],[284,525],[377,465]],eaves=[[139,365],[281,461],[412,367]],apex=[278,282],wall_pixels=77),dict(feet=[[84,409],[171,469],[264,408]],eaves=[[52,294],[172,385],[307,300]],apex=[192,219],wall_pixels=75),dict(feet=[[132,292],[219,350],[304,290]],eaves=[[89,151],[219,244],[363,151]],apex=[229,78],wall_pixels=91,level_pixels=169)],stairs=[dict(near=[[232,551],[270,528]],far=[[255,500],[291,479]],height_pixels=38,steps=6),dict(near=[[102,456],[137,435]],far=[[125,411],[160,391]],height_pixels=38,steps=6),dict(near=[[314,603],[356,631]],far=[[373,506],[416,535]],height_pixels=71,steps=12)],crowns=[[3,30,155,169],[306,177,443,278],[404,253,556,392]],terraces=[dict(points=[[385,456],[437,420],[516,475],[460,511]],height_pixels=69)]),
1230065:dict(trunks=[dict(base=[294,524],height_pixels=427,diameter=103),dict(base=[160,427],height_pixels=325,diameter=96)],houses=[dict(feet=[[235,462],[324,522],[417,459]],eaves=[[178,368],[326,460],[472,360]],apex=[324,282],wall_pixels=79,roof='roof_blue'),dict(feet=[[97,369],[185,429],[278,368]],eaves=[[33,259],[185,355],[323,262]],apex=[170,181],wall_pixels=79,roof='roof_blue')],stairs=[dict(near=[[56,430],[90,451]],far=[[92,360],[126,381]],height_pixels=45,steps=8),dict(near=[[201,518],[235,541]],far=[[243,439],[278,463]],height_pixels=49,steps=8)],crowns=[[9,25,166,177],[195,148,369,306],[350,223,523,365]]),
1230066:dict(trunks=[dict(base=[254,558],height_pixels=503,diameter=103),dict(base=[388,468],height_pixels=413,diameter=91)],houses=[dict(feet=[[166,480],[258,541],[352,478]],eaves=[[109,381],[257,479],[416,370]],apex=[261,294],wall_pixels=78,roof='roof_blue'),dict(feet=[[287,401],[381,465],[479,398]],eaves=[[250,289],[382,386],[501,303]],apex=[364,218],wall_pixels=76,roof='roof_blue'),dict(feet=[[251,294],[338,354],[429,291]],eaves=[[202,164],[338,252],[457,161]],apex=[375,66],wall_pixels=90,level_pixels=166,roof='roof_blue')],stairs=[dict(near=[[308,582],[342,559]],far=[[271,496],[307,472]],height_pixels=49,steps=9),dict(near=[[438,486],[471,464]],far=[[400,402],[435,379]],height_pixels=49,steps=9)],crowns=[[243,0,350,154],[52,114,203,252],[156,206,322,334],[0,267,153,398]]),
}
for spec in TREEHOUSES.values():
 spec['kind']='compound';spec['living_tree']=True
 for index,trunk in enumerate(spec['trunks']):trunk.update(diameter=round(trunk['diameter']*(.52 if index==0 else .36)),material='bark',profile=[[0,1.4],[.05,1.15],[.3,.86],[.62,.8],[.85,.68],[1,.64]],tiled_front=True,recess=8)
 for house in spec['houses']:house.update(roof=house.get('roof','roof_wood'),trim='bark',cap=False,window='tree_window')
TRUNK_TOPS={1230039:[[162,9]],1230064:[[172,110]],1230062:[[316,8],[451,88]],1230063:[[226,8],[82,88]],1230065:[[173,103],[78,87]],1230066:[[334,62],[408,149]]}
for serial,tops in TRUNK_TOPS.items():
 for trunk,top in zip(TREEHOUSES[serial]['trunks'],tops):trunk['top']=top
VISIBLE_TRUNK_BASES={1230039:[[163,175]],1230064:[[161,257]],1230062:[[317,194],[409,300]],1230063:[[220,194],[135,300]],1230065:[[165,285],[127,251]],1230066:[[325,245],[395,338]]}
for serial,bases in VISIBLE_TRUNK_BASES.items():
 for index,(trunk,base) in enumerate(zip(TREEHOUSES[serial]['trunks'],bases)):
  total=trunk.get('level_pixels',0)+trunk['height_pixels'];height=base[1]-trunk['top'][1]
  trunk.update(base=base,height_pixels=height,level_pixels=total-height,diameter=70 if index==0 else 22)
COMPOUNDS.update(TREEHOUSES)
COMPOUNDS[1238094]=dict(stairs=[dict(near=[[159,386],[225,342]],far=[[51,76],[86,49]],height_pixels=207,steps=18,support=True)])
COMPOUNDS[1260057]=dict(towers=[dict(base=[38,157],height_pixels=65,diameter=68,material='stone',sides=8,profile=[[0,.8],[.14,1],[.26,.82],[.85,.8],[1,.95]]),dict(base=[37,104],level_pixels=53,height_pixels=42,diameter=74,material='stone',sides=8,profile=[[0,.84],[.25,1],[.45,.83],[.8,.5],[1,.28]]),dict(base=[36,60],level_pixels=95,height_pixels=60,diameter=23,material='crystal',sides=6,profile=[[0,0],[.19,.65],[.75,.8],[1,0]])])
COMPOUNDS[1233020]=dict(houses=[dict(feet=[[86,449],[330,611],[567,449]],eaves=[[94,321],[330,477],[556,326]],apex=[311,165],wall_pixels=131,roof='roof_blue')],
 towers=[dict(base=[147,400],height_pixels=80,diameter=90,material='stone',profile=[[0,1],[.1,1.02],[.95,.88],[1,.95]]),dict(base=[147,322],level_pixels=80,height_pixels=122,diameter=104,material='roof_blue',profile=[[0,.8],[.1,1],[.32,.93],[.68,.63],[.9,.38],[1,.05]]),
 dict(base=[325,596],height_pixels=145,diameter=90,material='stone',profile=[[0,1],[.1,1.02],[.95,.88],[1,.95]]),dict(base=[325,453],level_pixels=145,height_pixels=120,diameter=103,material='roof_blue',profile=[[0,.8],[.1,1],[.32,.93],[.68,.63],[.9,.38],[1,.05]]),
 dict(base=[491,414],height_pixels=83,diameter=90,material='stone',profile=[[0,1],[.1,1.02],[.95,.88],[1,.95]]),dict(base=[491,333],level_pixels=83,height_pixels=124,diameter=104,material='roof_blue',profile=[[0,.8],[.1,1],[.32,.93],[.68,.63],[.9,.38],[1,.05]]),
 dict(base=[302,270],level_pixels=160,height_pixels=69,diameter=78,material='stone',profile=[[0,1],[.95,.88],[1,.95]]),dict(base=[302,203],level_pixels=229,height_pixels=124,diameter=108,material='roof_blue',profile=[[0,.8],[.1,1],[.32,.93],[.68,.63],[.9,.38],[1,.05]]),
 dict(base=[311,292],level_pixels=215,height_pixels=53,diameter=91,material='stone',profile=[[0,1],[1,1]]),dict(base=[311,241],level_pixels=268,height_pixels=75,diameter=103,material='roof_blue',profile=[[0,.83],[.15,1],[.45,.9],[.75,.58],[1,.05]])],
 stairs=[dict(near=[[87,584],[115,606]],far=[[144,481],[173,503]],height_pixels=69,steps=12),dict(near=[[194,654],[222,676]],far=[[251,543],[280,565]],height_pixels=75,steps=13)],
 terraces=[dict(points=[[15,445],[296,260],[643,482],[363,674]],height_pixels=33)],details=[[127,115,166,208],[281,0,326,90],[470,126,511,218],[300,275,346,347],[292,128,332,178]])
COMPOUNDS[1230040]=dict(living_tree=True,trunks=[dict(base=[119,688],height_pixels=530,diameter=99,material='bark',profile=[[0,1.6],[.1,1],[.4,.88],[.8,.7],[1,.4]]),dict(base=[268,638],height_pixels=345,diameter=106,material='bark',profile=[[0,1.6],[.1,1],[.5,.85],[1,.9]]),dict(base=[406,604],height_pixels=478,diameter=109,material='bark',profile=[[0,1.6],[.1,1],[.5,.8],[1,.4]])],
 houses=[dict(feet=[[54,652],[130,699],[219,644]],eaves=[[5,545],[129,626],[251,549]],apex=[105,480],wall_pixels=75,roof='roof_blue'),dict(feet=[[217,468],[291,519],[384,459]],eaves=[[166,370],[292,450],[408,377]],apex=[280,311],wall_pixels=70,level_pixels=133,roof='roof_blue'),dict(feet=[[367,524],[444,576],[523,520]],eaves=[[322,420],[444,499],[528,438]],apex=[464,351],wall_pixels=73,level_pixels=97,roof='roof_blue')],
 stairs=[dict(near=[[180,704],[210,685]],far=[[154,645],[185,624]],height_pixels=42,steps=7),dict(near=[[235,503],[266,524]],far=[[255,455],[286,475]],height_pixels=39,steps=6),dict(near=[[431,568],[461,549]],far=[[407,515],[437,494]],height_pixels=39,steps=6)],crowns=[[0,150,178,336],[263,0,463,184],[329,94,535,277],[26,248,234,431]])
for trunk,top in zip(COMPOUNDS[1230040]['trunks'],[[111,183],[279,303],[362,32]]):trunk.update(diameter=round(trunk['diameter']*.52),top=top,tiled_front=True,recess=8)
for house in COMPOUNDS[1230040]['houses']:house.update(trim='bark',cap=False,window='tree_window')
for house in COMPOUNDS[1233020]['houses']:house.update(wall='stone',base_material='stone',window='palace_window',trim='stone')
for tower in COMPOUNDS[1233020]['towers']:
 if tower['material']=='stone':tower['window']='palace_window'
for terrace in COMPOUNDS[1233020]['terraces']:terrace['material']='stone'
TREES={**{1230000+i:('bamboo_cluster' if i in [5,6,7,8] else 'crossgate_flora/cg_woodland') for i in range(10)},
       **{1233190+i:'crossgate_flora/cg_evergreen' for i in range(20)}}
RELIEFS={1233010:dict(slope=.75,depth=.9,back='brick'),1233011:dict(slope=-.75,depth=.9,back='brick'),
         1233014:dict(slope=-.75,depth=1.1,back='brick'),1233015:dict(slope=.75,depth=1.1,back='brick'),
         1233018:dict(slope=.75,depth=.42,back='stone'),1233019:dict(slope=-.75,depth=.42,back='stone')}
RELIEFS.update({serial:dict(slope=0,depth=.18,back='timber') for serial in [1230068,1230070,1230072,1230073,1230076,1230084,1230086,1230088,1230090]})
RELIEFS.update({1233181:dict(slope=.75,depth=.18,back='stone'),1233182:dict(slope=-.75,depth=.18,back='stone')})
ISLETS=[12912,12913,12914,12919,12922]
BOAT=1230057
MAST=1230059
PATCHES={
 'plaster':(1233000,[(155,401)]*4,False,(64,64)),
 'brick':(1233000,[(76,367),(96,381),(96,401),(76,387)],False,(64,64)),
 'stone':(1233020,[(107,374)]*4,False,(64,64)),
 'roof_gold':(1233000,[(223,160),(244,174),(265,160),(244,143)],False,(96,64)),
 'roof_blue':(1233020,[(285,119),(296,112),(300,139),(290,146)],False,(64,96)),
 'roof_green':(1233007,[(230,147),(258,168),(253,200),(224,180)],False,(64,96)),
 'roof_red':(1233003,[(137,154),(157,166),(158,205),(132,188)],False,(64,96)),
 'timber':(1230057,[(176,140),(193,126),(205,134),(188,148)],False,(96,64)),
 'bark':(1230062,[(303,60),(324,60),(324,90),(303,90)],False,(64,96)),
 'gold':(1233000,[(188,96)]*4,False,(64,64)),
 'rope':(1230059,[(230,700)]*4,False,(64,64)),
 'dark':(1230057,[(99,91)]*4,False,(64,64)),
 'blue_wood':(1230057,[(125,81)]*4,False,(64,64)),
 'crystal':(1260057,[(36,39)]*4,False,(64,64)),
 'roof_wood':(1230062,[(222,119),(239,131),(233,146),(216,134)],False,(64,64)),
 'hollow':(1230062,[(314,19)]*4,False,(64,64)),
 'window':(1233000,[(75,311),(101,328),(101,358),(75,341)],True,(64,96)),
 'tree_window':(1230062,[(161,405),(181,417),(181,450),(161,438)],True,(64,96)),
 'palace_window':(1233020,[(177,385),(214,410),(214,450),(177,426)],True,(64,96)),
}
COMPOUNDS.update(REGIONAL)
COMPOUNDS.update(CLASSIC_COMPOUNDS)
apply_living_shapes(COMPOUNDS)
PATCHES.update(SURFACES)
PATCHES.update(CLASSIC_SURFACES)
SOURCE_ROCKS.update(CLASSIC_ROCKS)
SOURCE_ROCKS.update({serial:'rubble_stone' for serial in range(1233236,1233246)})
SOURCE_ROCKS.update({serial:'rock_moss' for serial in [1233216,1233220,1233222,1233223,1233224]})
SOURCE_ROCKS.update({serial:'bark' for serial in range(1233225,1233233)})
SOURCE_ROCKS.update({serial:'rubble_stone' for serial in range(1233233,1233236)})
PATCHES['rubble_stone']=(1233243,[(60,50),(72,56),(72,70),(60,64)],False,(64,64))
PATCHES['living_bark']=(1230062,[(304,12),(319,12),(319,36),(304,36)],False,(64,96))
ROCK_HOLES.update(CLASSIC_HOLES)


def digest(raw):return hashlib.sha256(raw).hexdigest()

def measured_gold_spires(art,boxes):
 result=[]
 for box in boxes:
  x0,y0,x1,y1=max(0,box[0]-8),max(0,box[1]-2),min(art.width,box[2]+8),min(art.height,box[3]+24)
  rows=[]
  for y in range(y0,y1):
   xs=[x for x in range(x0,x1) if (lambda p:p[3]>=128 and p[0]>100 and p[0]>p[2]*1.24 and p[1]>p[2]*1.1)(art.getpixel((x,y)))]
   if xs:rows.append((len(xs),min(xs),max(xs),y))
  assert rows,box
  _,left,right,cy=max(rows)
  result.append({'center':[(left+right)/2,cy],'diameter':right-left+1,'tip':[(left+right)/2,min(row[3] for row in rows)],'bottom':[(left+right)/2,max(row[3] for row in rows)],'source_box':box})
 return result


def rock_front(original):
 # The existing cliff preparer treats border-connected near-black as hidden faces, not painted crevices.
 w,h=original.size;void=Image.new('L',(w,h));pixels=original.load();mask=void.load()
 for y in range(h):
  for x in range(w):
   r,g,b,a=pixels[x,y]
   if a<128 or max(r,g,b)<=45 and max(r,g,b)-min(r,g,b)<3:mask[x,y]=255
 for x,y in [(x,y) for x in range(w) for y in (0,h-1)]+[(x,y) for y in range(h) for x in (0,w-1)]:
  if void.getpixel((x,y))==255:ImageDraw.floodfill(void,(x,y),128)
 result=original.copy();out=result.load()
 for y in range(h):
  for x in range(w):
   if mask[x,y]==128:out[x,y]=(*pixels[x,y][:3],0)
 return result


def prepare():
 catalog=json.loads((ART/'east/catalog.json').read_text());pages={}
 def image(serial):
  g=catalog['graphics'][str(serial)];page=g['page']
  if page not in pages:pages[page]=Image.open(ART/catalog['pages'][page]).convert('RGBA')
  x,y,w,h=g['rect'];return pages[page].crop((x,y,x+w,y+h))
 definition=next(n for n in ast.parse((ROOT/'tools/prepare_elsa_scenery.py').read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='outline')
 scope={'math':math,'Image':Image};exec(compile(ast.Module(body=[definition],type_ignores=[]),'prepare_elsa_scenery.py','exec'),scope)
 outline=scope['outline']
 data={'schema':1,'graphics':{},'source_catalog_sha256':digest((ART/'east/catalog.json').read_bytes()),
       'calibration':{'horizontal':32/3,'floor_shear':8,'vertical':math.sqrt(2*((32/3)**2-8**2))},
       'inferred':['Unseen backs continue separately sampled native masonry/wood and roof materials.','Roof depth, hidden roof faces, mast thickness, sail billow and tree crown depth are inferred.','Original map positions, origins, footprints, navigation and door/quest owners remain unchanged.']}
 data['calibration'].update(gameplay_owner_height_per_pixel=.045,gameplay_owner_y_scale=.045*data['calibration']['vertical'],reference_frame='Euclidean city/source study; gameplay applies the existing OriginalMaps owner height frame once after composition.')
 for serial,spec in HOUSES.items():data['graphics'][str(serial)]={'kind':'hip_house',**spec}
 for serial,spec in COMPOUNDS.items():data['graphics'][str(serial)]={'kind':'compound',**spec}
 for serial,spec in STATUES.items():data['graphics'][str(serial)]={'kind':'statue',**spec}
 for serial,spec in REUSED.items():data['graphics'][str(serial)]={'kind':'classic_reuse',**spec}
 for serial,spec in SHELTERS.items():data['graphics'][str(serial)]={'kind':'shelter',**spec}
 data['graphics']['11010']={'kind':'log_deck','owner':'scripts/forest/forest_falan_lamps.gd','near':[[112,173],[207,114]],'far':[[5,54],[50,7]],'logs':7}
 data['graphics']['17638']={'kind':'mine_frame','owner':'scripts/forest/forest_tina_harbor_details.gd','feet':[[20,153],[82,194],[156,146]],'eaves':[[5,64],[91,121],[174,65]],'ridge':[[85,6],[149,47]],'apex':[85,6],'wall_pixels':83,'roof':'classic_wood_roof','rim':[[31,151],[31,90],[90,46],[146,91],[146,147]]}
 for serial in [1260162,1260163,1260164,1260165,1260166,1260167,1260168,1260169,1260172,1260173,1260177]:data['graphics'][str(serial)]={'kind':'native_floor_piece','visual_namespace':'inferred unique expanded DB counterpart; original layout/planes unchanged'}
 for serial in [1260077,1260079,1260081,1260083,1260086,1260317,1260322,1260324]:data['graphics'][str(serial)]={'kind':'rope_post','visual_namespace':'inferred unique expanded DB counterpart; original layout/planes unchanged'}
 for serial in [1260074,1260075,1260312,1260313]:data['graphics'][str(serial)]={'kind':'bridge_gate','visual_namespace':'inferred unique expanded DB counterpart; original layout/planes unchanged'}
 for serial,material in SOURCE_ROCKS.items():data['graphics'][str(serial)]={'kind':'source_rock','material':material,'height_frame':'original-owner'}
 for serial,asset in TREES.items():
  if str(serial) in catalog['graphics']:data['graphics'][str(serial)]={'kind':'tree','asset':asset}
 for serial,spec in tree_family_records().items():data['graphics'][str(serial)]=spec
 for serial in range(1230000,1230039):
  if str(serial) in catalog['graphics']:data['graphics'][str(serial)]={'kind':'native_foliage'}
 for serial,spec in RELIEFS.items():data['graphics'][str(serial)]={'kind':'relief',**spec}
 for serial in ISLETS:data['graphics'][str(serial)]={'kind':'source_islet','slope':0,'depth':.9,'inference':'Native rock and water pixels are separated; inferred shallow rock volume and a closed independently tiled reverse retain the original source anchor. Navigation is unchanged.'}
 data['graphics'][str(BOAT)]={'kind':'boat','platform':[[3,128],[123,215],[262,104],[145,23]],
  'port':[[12,174],[40,177],[102,143],[167,90],[225,24],[237,2]],
  'starboard':[[12,174],[44,197],[109,165],[175,111],[229,50],[237,2]]}
 data['graphics'][str(MAST)]={'kind':'mast','base':[244,732],'top':[235,0],
  'cloth_polygons':[[[44,0],[226,0],[226,550],[81,482],[11,373],[0,265],[9,155]],
                    [[251,0],[452,0],[450,143],[398,354],[397,574],[462,749],[352,650],[283,545],[251,515]]]}
 images={serial:image(serial) for serial in set(s[0] for s in PATCHES.values())}
 surfaces,rows=surface_atlas(images,PATCHES)
 # Unseen pale palace stone keeps the native color and independent native stone grain.
 stone_slot=list(PATCHES).index('stone');grain_slot=list(PATCHES).index('ruin_stone')
 sx,sy=(stone_slot%4)*128,(stone_slot//4)*128;gx,gy=(grain_slot%4)*128,(grain_slot//4)*128
 grain=surfaces.crop((gx,gy,gx+128,gy+128)).convert('L');tone=images[1233020].getpixel((107,374))[:3]
 for y in range(128):
  for x in range(128):
   scale=.87+.13*grain.getpixel((x,y))/255.
   surfaces.putpixel((sx+x,sy+y),(*(round(channel*scale) for channel in tone),255))
 # The unseen living exterior uses coherent native wood grain, not the source's
 # neutral 50% dither checker as a repeating masonry-like knot pattern.
 living_slot=list(PATCHES).index('living_bark');lx,ly=(living_slot%4)*128,(living_slot//4)*128
 original_living=images[1230062].crop((304,12,319,36)).convert('RGBA');grain=original_living.copy()
 browns=[(x,y,original_living.getpixel((x,y))) for y in range(grain.height) for x in range(grain.width) if (lambda p:p[0]>p[1]*1.12 and p[0]>p[2]*1.2)(original_living.getpixel((x,y)))]
 for y in range(grain.height):
  for x in range(grain.width):
   color=original_living.getpixel((x,y))
   if not(color[0]>color[1]*1.12 and color[0]>color[2]*1.2):
    nearest=sorted(browns,key=lambda p:(p[0]-x)**2+(p[1]-y)**2)[:4]
    grain.putpixel((x,y),(*(round(sum(p[2][c] for p in nearest)/len(nearest)) for c in range(3)),255))
 # Three narrow native-grain repeats compensate the existing owner's compressedY
 # without stretching the observed front over the reconstructed whole trunk.
 strip=grain.resize((43,128),Image.Resampling.BICUBIC);tile=Image.new('RGBA',(128,128))
 for x in (0,43,86):tile.paste(strip,(x,0))
 surfaces.paste(tile,(lx,ly))
 OUT.mkdir(parents=True,exist_ok=True);REPORT.mkdir(exist_ok=True)
 surfaces.save(OUT/'surfaces.png');(OUT/'surfaces.gd').write_text('\n'.join(rows+['}'])+'\n')
 for token,spec in data['graphics'].items():
  g=catalog['graphics'][token];art=image(int(token));clean,shadow=native_without_ground_shadow(art)
  if spec['kind']=='native_foliage':
   pixels=clean.load()
   for y in range(clean.height//2,clean.height):
    for x in range(clean.width):
     r,gr,b,a=pixels[x,y]
     if a and (r,gr,b)==(71,71,71):pixels[x,y]=(r,gr,b,0);shadow.add((x,y))
  spec.update(graphic_id=int(token),native_rgba_sha256=g['rgba_sha256'],visible=spec.get('visible_override',list(clean.getbbox())),source_serial=g.get('source_serial',int(token)),removed_ground_shadow=len(shadow))
  if 'crown_ground_source' in spec:spec['crown_ground_pixels']=[float(y)+g['origin'][1] for y in spec['crown_ground_source']]
  if spec['kind'] in ('seasonal_tree','native_branch_tree','native_canopy_tree'):prepare_tree_family(spec,g,clean,OUT,ROOT)
  assert digest(art.tobytes())==g['rgba_sha256'],token
  if spec['kind']=='source_rock':
   profile,coverage=measured_profile(art,g);spec.update(profile=profile,source_coverage=coverage,inferred_back_material=spec['material'])
   if int(token)==1233220:
    # The broad 5x3 collision footprint overestimates the painted ground diamond.
    # Its tall exposed rock columns measure about 80 vertical native pixels.
    spec['height_measurement']={'native_face_pixels':80,'method':'visible central pillar face; hidden base/depth inferred independently of the oversized collision diamond'}
   if int(token) in [1233216,1233220,1233222,1233223,1233224,1233233,1233234,1233235]:
    profile,proof=source_contour_profile(clean,g,profile,measured_height=3.6 if int(token)==1233220 else None)
    spec.update(profile=profile,source_contour=proof)
   if int(token) in ROCK_HOLES:spec['hole']=ROCK_HOLES[int(token)]
   rock_front(art).save(OUT/f'{token}-rock-front.png')
  if spec['kind']=='native_foliage':clean.save(OUT/f'{token}-foliage.png')
  if spec['kind']=='source_islet':
   rock=clean.copy();water=clean.copy()
   for y in range(clean.height):
    for x in range(clean.width):
     r,gr,b,a=clean.getpixel((x,y));is_water=b>r*1.06 and b>=gr*.90
     rock.putpixel((x,y),(r,gr,b,0 if is_water else a))
     water.putpixel((x,y),(r,gr,b,a if is_water else 0))
   bounds=rock.getbbox();assert bounds,token
   spec['ground_offset']=float(g['origin'][1])+bounds[3]
   spec['rock_bounds']=list(bounds);spec['edges']=outline(rock)
   rock.save(OUT/f'{token}-islet-rock.png');water.save(OUT/f'{token}-islet-water.png')
   tile=surfaces.crop((256,1152,384,1280)).resize((48,48),Image.Resampling.BILINEAR)
   back=Image.new('RGBA',art.size)
   for y in range(clean.height):
    for x in range(clean.width):
     a=rock.getpixel((x,y))[3]
     if a:back.putpixel((x,y),(*tile.getpixel((x%48,y%48))[:3],a))
   back.save(OUT/f'{token}-islet-back.png')
  if spec['kind'] in ('relief','statue'):
   spec['edges']=outline(clean);clean.save(OUT/f'{token}-front.png')
   crop=images[PATCHES[spec['back']][0]];sample=PATCHES[spec['back']][1][0];tone=crop.getpixel(tuple(sample))[:3]
   if int(token) in (1233018,1233019,1233181,1233182):
    back=clean.copy()
    spec['inferred_reverse_material']='The opposite face continues the observed thin ornamental frame and its carved/floral design. Its reverse is unrecorded; original alpha openings and the measured frame extrusion are retained.'
   elif int(token) in (1233010,1233011,1233014,1233015):
    back=Image.new('RGBA',art.size)
    brick=surfaces.crop((128,0,256,128)).resize((48,48),Image.Resampling.BILINEAR)
    heights=[float(spec['slope'])*(x+g['origin'][0])-y-g['origin'][1] for y in range(clean.height) for x in range(clean.width) if clean.getpixel((x,y))[3]>=128]
    coping=min(heights)+(max(heights)-min(heights))*.68
    for y in range(clean.height):
     for x in range(clean.width):
      r,gr,b,a=clean.getpixel((x,y))
      if not a:continue
      height=float(spec['slope'])*(x+g['origin'][0])-y-g['origin'][1]
      color=clean.getpixel((x,y))[:3] if height>=coping else brick.getpixel((x%brick.width,int(height)%brick.height))[:3]
      back.putpixel((x,y),(*color,a))
    spec['inferred_reverse_material']='Independent tiled masonry continues the wall around its unseen reverse. The observed upper carved coping and exact alpha outline continue across the edge; no rear door or new passage is drawn.'
   elif spec['kind']=='statue':
    slot=list(PATCHES).index('ruin_stone');sx=(slot%4)*128;sy=(slot//4)*128
    grain=surfaces.crop((sx,sy,sx+128,sy+128)).convert('L').resize((48,48),Image.Resampling.BILINEAR)
    bright=[p[:3] for p in clean.getdata() if p[3]>=192 and min(p[:3])>140]
    tone=tuple(sum(p[channel] for p in bright)//len(bright) for channel in range(3))
    back=Image.new('RGBA',art.size)
    for y in range(clean.height):
     for x in range(clean.width):
      a=clean.getpixel((x,y))[3]
      if a:
       shade=.83+.17*grain.getpixel((x%48,y%48))/255.
       back.putpixel((x,y),(*(round(c*shade) for c in tone),a))
    spec['inferred_reverse_material']='The unseen sculpture reverse uses independent native stone grain in the observed pale palette; rounded body/head masses and thin wing edges are reconstructed without copying the front face onto the back.'
   else:
    back=Image.new('RGBA',art.size,tone+(255,));back.putalpha(clean.getchannel('A'))
   back.save(OUT/f'{token}-back.png')
  if spec['kind']=='mast':
   mask=Image.new('L',art.size);draw=ImageDraw.Draw(mask)
   for polygon in spec['cloth_polygons']:draw.polygon([tuple(p) for p in polygon],fill=255)
   cloth=art.copy();cloth.putalpha(ImageChops.multiply(clean.getchannel('A'),mask));cloth.save(OUT/'mast-cloth.png')
  if spec['kind']=='hip_house':
   review=art.copy();draw=ImageDraw.Draw(review)
   for color,points in [('cyan',spec['feet']),('magenta',spec['eaves']),('yellow',[spec['apex']])]:
    for p in points:draw.ellipse((p[0]-4,p[1]-4,p[0]+4,p[1]+4),fill=color)
   review.save(REPORT/f'{token}-measured-feet-roof.png')
  if spec['kind']=='compound':
   if int(token)==1233020:
    spec['gold_spires']=measured_gold_spires(clean,spec['details'])
    spec['inferred_gold_depth']='Gold silhouette, staff extents and bulb width are measured from the native gold pixels. Round closed bulbs and staff depth reconstruct the unseen sides; rectangular adjacent roof paint is excluded.'
   for part in spec.get('towers',[]):
    if not part.get('measure_rim'):continue
    sides=part.get('sides',32);radius=part['diameter']/(2*(32/3)*math.sqrt(2))*part['profile'][-1][1]
    top=part.get('top',[part['base'][0],part['base'][1]-part['height_pixels']]);part['rim_offsets']=[]
    for side in range(sides):
     angle=side*math.tau/sides+part.get('angle_offset',0);x=round(top[0]+(math.cos(angle)+math.sin(angle))*radius*(32/3));x=max(0,min(clean.width-1,x))
     marks=[y for y in range(clean.height) if clean.getpixel((x,y))[3]>=128 and max(clean.getpixel((x,y))[:3])>45]
     nominal=top[1]+(math.sin(angle)-math.cos(angle))*radius*8
     part['rim_offsets'].append(max(-28,min(28,nominal-(marks[0] if marks else nominal))))
   spec['crown_anchors']=[]
   for index,box in enumerate(spec.get('crowns',[])):
    leaves=clean.crop(tuple(box));mask=Image.frombytes('L',leaves.size,bytes(a if gr>=r*.85 and gr>b*1.04 and gr>12 else 0 for r,gr,b,a in leaves.getdata()))
    mask=ImageChops.multiply(mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5)),leaves.getchannel('A'));leaves.putalpha(mask)
    bbox=mask.getbbox()
    if bbox:
     density=mask.filter(ImageFilter.BoxBlur(7));cx=(bbox[0]+bbox[2])/2;cy=(bbox[1]+bbox[3])/2
     candidates=[(density.getpixel((x,y))-.08*((x-cx)**2+(y-cy)**2)**.5,x,y) for y in range(bbox[1],bbox[3]) for x in range(bbox[0],bbox[2]) if mask.getpixel((x,y))>=192]
     _,ax,ay=max(candidates);spec['crown_anchors'].append([box[0]+ax+.5,box[1]+ay+.5])
    else:raise ValueError(f'Native crown has no opaque junction: {token}/{index}')
    leaves.save(OUT/f'{token}-crown-{index}.png')
   review=art.copy();draw=ImageDraw.Draw(review)
   for house in spec.get('houses',[]):
    for color,points in [('cyan',house['feet']),('magenta',house['eaves']),('yellow',[house['apex']])]:
     for p in points:draw.ellipse((p[0]-3,p[1]-3,p[0]+3,p[1]+3),fill=color)
   for stair in spec.get('stairs',[]):
    for line in [stair['near'],stair['far']]:draw.line([tuple(p) for p in line],fill='red',width=3)
   review.save(REPORT/f'{token}-measured-components.png')
 pending=OUT/'profiles.json.pending';pending.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n');pending.replace(OUT/'profiles.json')
 (OUT/'surface-provenance.json').write_text(json.dumps(PATCHES,indent=2)+'\n')
 print('EAST_LANDMARK_PROFILES',len(data['graphics']),'native profiles; inferred backs/depth explicit')


if __name__=='__main__':prepare()

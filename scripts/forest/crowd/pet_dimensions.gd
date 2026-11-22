@static_unload
extends RefCounted
## Authored species proportions relative to Kaz, not atlas borders or attack effects.
const KAZ_HEIGHT=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const COMPANION_SKINS=617
static var extra_profiles:Array=[]
const MANTIS_SCALE=.85
const BEE_SCALE=.8
# Reviewed standing bodies in source pixels, excluding weapons, shadows and aura.
const CHARACTER_BODY_PIXELS={
 "joy-ex:821":84,"original:2797":94,"ex:745":85,"joy:436":69,
 "joy:773":78,"joy:901":81,"ex:674":73,"ex:718":71,
 "ch1:412":52,"original:2759":94,"ch1:483":146,"v3:341":105,
 "ch1:71":89,"v3:464":106,"v3:521":106,"puk3:206":135,
 "ex:722":73,"original:2769":76,"original:2738":80,"ex:688":86,
 "puk2:33":113,"joy:863":103,"puk3:70":148,"puk3:71":148,
}
# Core body fits in source pixels; tails, scythes, antennae, snow and aura are not hurt regions.
const HOUND_BODY=Vector3(58,68,76)
const DRAGON_BODY=Vector3(62,55,80)
const BEE_BODY=Vector3(32,52,34)
const MANTIS_BODIES=[Vector3(46,92,48),Vector3(48,97,50),Vector3(46,92,48),Vector3(48,94,50),Vector3(46,92,48)]
const MANTIS_FITS=[0,1,2,3,4,1,1,1,0,0,0,1,0,0,0,0,1,2,3,4]
const HEIGHTS={
 "shalena":[1.6,.85,1.0,1.0,.85,.8,1.1,1.9,1.9,.8,.7,1.05,.7,1.0,1.1,1.1],
 "falan_encounters":preload("res://assets/maps/falan/map_encounter_data.gd").HEIGHTS,
 "habaru":[2.0,2.1,.65,1.65,1.35],
 "zombie_cave":[1.15,1.0,1.0,.85],
 "pirate_cave":[1.1,.80,1.0],
 "forest_grave":[1.35,1.0,1.55,.75],
 "black_prayer":[1.1,1.15,1.15],
 "falken":[1.3,1.0,1.05],
 "cursed_maze":[.8,.6,2.1937499999999996,2.1937499999999996,2.1937499999999996],
 "beast_maze":[.6],
 "undersea":[1.4,1.05,1.05],
}
static func exploring(model:RefCounted)->bool:
 return not model.falan_area.is_empty() or model.terrain_detail==model.FreyjaTerrain.ID
static func size_variant_scale(skin:int)->float:
 if skin<21 or skin>=82:return 1.0
 return 1.5 if (skin>=36 and skin<41) or (skin>=57 and skin<61) or skin>=77 else .9
static func scales(root:String,data:Dictionary)->PackedFloat32Array:
 var result=PackedFloat32Array();result.resize(COMPANION_SKINS);result.fill(1.0)
 var family=root.trim_suffix("/").get_file()
 if family=="guard_pets":
  for skin in range(21,82):result[skin]=(MANTIS_SCALE if skin<41 else BEE_SCALE if skin>=61 else 1.0)*size_variant_scale(skin)
  for skin in range(82,COMPANION_SKINS):result[skin]=float(extras()[skin-82].visual_scale)
 if HEIGHTS.has(family):
  assert(HEIGHTS[family].size()==data.variants.size())
  for skin in data.variants.size():result[skin]=KAZ_HEIGHT*HEIGHTS[family][skin]/float(data.variants[skin].standing_height)
 return result
static func companion_body(skin:int)->AABB:
 assert(skin>=0 and skin<COMPANION_SKINS)
 if skin>=82:
  var row:Array=extras()[skin-82].body
  var low=Vector3(row[0],row[1],row[2])
  return AABB(low,Vector3(row[3],row[4],row[5])-low)
 var size_=HOUND_BODY
 if skin==19:size_=Vector3(80,92,100)
 elif skin==20:size_=Vector3(78,82,86)
 elif skin>=61:size_=BEE_BODY*BEE_SCALE
 elif skin>=41:size_=DRAGON_BODY
 elif skin>=21:size_=MANTIS_BODIES[MANTIS_FITS[skin-21]]*MANTIS_SCALE
 size_*=Roles.HOUND_PIXEL_SIZE*Roles.HOUND_SCALE
 var hover=24*Roles.HOUND_PIXEL_SIZE*Roles.HOUND_SCALE*BEE_SCALE if skin>=61 else 0.0
 var factor=size_variant_scale(skin)
 return AABB(Vector3(-size_.x*.5,hover,-size_.z*.5)*factor,size_*factor)
static func extras()->Array:
 if extra_profiles.is_empty():
  extra_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crossgate/companions/catalog.json")).profiles
  var variants:Array=load("res://scripts/forest/pet_catalog.gd").motions().variants
  for skin in range(82,COMPANION_SKINS):
   var key:String=variants[skin].key
   if not CHARACTER_BODY_PIXELS.has(key):continue
   var profile:Dictionary=extra_profiles[skin-82]
   var scale_=KAZ_HEIGHT/(CHARACTER_BODY_PIXELS[key]*Roles.HOUND_PIXEL_SIZE*Roles.HOUND_SCALE)
   var factor=scale_/float(profile.visual_scale)
   for axis in 6:profile.body[axis]*=factor
   profile.body[4]=profile.body[1]+KAZ_HEIGHT
   profile.visual_scale=scale_
 return extra_profiles
static func body(source:Script,skin:int)->AABB:
 var family:String=source.ROOT.trim_suffix("/").get_file()
 var box:AABB=source.BODY
 match family:
  "falan_encounters","shalena":
   if source.tree(skin):box=source.TREE_BODY
  "habaru":
   box=source.CHAMBER_BODY if skin<2 else source.SLIME_BODY if skin==2 else source.VENOA_BOSS_BODY if skin==3 else source.BODY
  "forest_grave":
   if skin==2:box=source.FINAL_BODY
  "cursed_maze":
   if skin>=2:box=companion_body(load("res://scripts/forest/pet_catalog.gd").skin(source.KEYS[skin]))
  "black_prayer":
   if skin>0:box=source.ESCORT_BODY
  "undersea":
   if skin==0:box=source.BOSS_BODY
 var scale_=scales(source.ROOT,source.motions())[skin]
 box=AABB(box.position*scale_,box.size*scale_)
 if HEIGHTS.has(family):box.size.y=KAZ_HEIGHT*HEIGHTS[family][skin]
 return box
static func offset(kind:int,skin:int)->int:
 return (skin+(COMPANION_SKINS if kind==Roles.SLIME else COMPANION_SKINS+29 if kind==Roles.CAVE_BEAR else 0))*7
static func geometry(cave:Script,world_sizes:bool=true,enemy_scale:float=1.0)->PackedFloat32Array:
 var rows=PackedFloat32Array()
 for kind in [Roles.GATEKEEPER_HOUND,Roles.SLIME,Roles.CAVE_BEAR]:
  var source:Script=load("res://scripts/forest/crowd/habaru_sprites.gd") if kind==Roles.CAVE_BEAR else cave if kind==Roles.SLIME else null
  var factors=scales(source.ROOT,source.motions()) if source!=null else PackedFloat32Array()
  for skin in (COMPANION_SKINS if kind==Roles.GATEKEEPER_HOUND else 29 if kind==Roles.SLIME else 5):
   var box:AABB
   var factor=1.0
   if kind==Roles.GATEKEEPER_HOUND:
    box=companion_body(skin);factor=MANTIS_SCALE if skin>=21 and skin<41 else 1.0
    if skin>=61 and skin<82:factor=BEE_SCALE
    factor*=size_variant_scale(skin)
    if skin>=82:factor=float(extras()[skin-82].visual_scale)
   elif source!=null and world_sizes:
    var fitted=mini(skin,source.motions().variants.size()-1)
    box=body(source,fitted);factor=factors[fitted]
   else:box=source.BODY if kind==Roles.CAVE_BEAR else AABB(Vector3(-.84,0,-.84)*Roles.SLIME_SCALE,Vector3(1.68,1.8,1.68)*Roles.SLIME_SCALE)
   if kind==Roles.SLIME:
    box=AABB(box.position*enemy_scale,box.size*enemy_scale)
    factor*=enemy_scale
   for point in [box.position,box.end]:rows.append_array(PackedFloat32Array([point.x,point.y,point.z]))
   rows.append(factor)
 return rows
static func bounds(rows:PackedFloat32Array,kind:int,skin:int)->AABB:
 var at=offset(kind,skin)
 var low=Vector3(rows[at],rows[at+1],rows[at+2])
 return AABB(low,Vector3(rows[at+3],rows[at+4],rows[at+5])-low)

extends RefCounted
## Cape event payloads run through the existing guarded source dialogue owner.
const ROOT="res://assets/characters/crossgate/sokia_region/"
const STATS=preload("res://scripts/forest/crowd/sokia_region_sprites.gd").STATS
static var specifications:Dictionary={}
static var run:Variant=null
static var access_data:Dictionary={}
static func access()->Dictionary:
 if access_data.is_empty():access_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/cape/access/events/data.json"))
 return access_data
static func decorate(record:Dictionary):
 var actor:Dictionary=access().actors.get(str(record.id),{})
 if actor.is_empty():return
 for key in ["quest_action","script","type","source_line","battle_owner","dialogue_owner","messages"]:
  if actor.has(key):record[key]=actor[key]
static func on_map(model,actor:Dictionary)->bool:
 if int(actor.source) in [100,300]:
  var south=load("res://scripts/forest/forest_south_kili_population.gd")
  if model.falan_area not in (south.FREYJA_AREAS if int(actor.source)==100 else south.SOKIA_AREAS):return false
  var regions=load("res://scripts/forest/forest_freyja_regions.gd")
  return model.terrain.mask_bounds().has_point(regions.frame(model.falan_area).inverse()*(Vector2(actor.cell[0],actor.cell[1])*3.))
 return model.falan_area=="interior" and model.falan_floor==int(actor.source)
static func source_area(source:int,cell:Vector2i)->String:
 return "west_lakes" if source==100 and cell in [Vector2i(172,145),Vector2i(174,171)] else ""
static func can_travel_source(game,source:int,cell:Vector2i)->bool:
 var area=source_area(source,cell)
 if area.is_empty():return load("res://scripts/forest/forest_east_region.gd").can_travel_source(game,source,cell)
 var terrain=game.model.FreyjaTerrain.new();terrain.variant=area
 var at:Vector2=load("res://scripts/forest/forest_freyja_regions.gd").frame(area).inverse()*(Vector2(cell)*3.)
 var image:Image=terrain.mask_image();var pixel=Vector2i(((at-terrain.mask_origin())/3.).round())
 if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel):return false
 var color=image.get_pixelv(pixel)
 return color.a>=.5 and color.r<.5 and color.b<.98
static func travel_source(game,source:int,cell:Vector2i)->bool:
 var area=source_area(source,cell)
 if area.is_empty():return load("res://scripts/forest/forest_east_region.gd").travel_source(game,source,cell)
 if not can_travel_source(game,source,cell):return false
 var regions=game.FalanTour.Regions;var at:Vector2=regions.frame(area).inverse()*(Vector2(cell)*3.)
 game.transitioning=true;game.FalanTour.travel.call_deferred(game,regions.layout(area),{"arrival":at,"yaw":game.camera_rig.yaw,"velocity":Vector3.ZERO})
 return true
static func npcs(model)->Array:
 var result=[];var regions=load("res://scripts/forest/forest_freyja_regions.gd")
 for original in access().actors.values():
  if str(original.id) in access().existing_coast_actor_ids or not on_map(model,original):continue
  var record:Dictionary=original.duplicate(true);var cell=Vector2(record.cell[0],record.cell[1])
  var at:Vector2=regions.frame(model.falan_area).inverse()*(cell*3.) if int(record.source) in [100,300] else load("res://scripts/forest/forest_original_maps.gd").floor_info(model.falan_floor)[1]+cell*3.
  if int(record.source) in [100,300] and not model.terrain.mask_bounds().has_point(at):continue
  var art:Dictionary=access().art[record.token];var r:Array=art.rect;var o:Array=art.origin
  var offset=Vector2(float(o[0])+float(r[2])*.5,-float(o[1])-float(r[3])*.5)
  if art.has("body_foot"):offset.y=float(art.body_foot)-float(r[3])*.5
  result.append([at,Rect2(r[0],r[1],r[2],r[3]),record.name,offset,record])
 return result
static func clear_ledger(tree:SceneTree,keys:Array):
 var regional=load("res://scripts/forest/forest_university_region.gd")
 var battles:Dictionary=tree.get_meta(regional.BATTLES,{})
 var slain:Dictionary=tree.get_meta(regional.SLAIN,{})
 for key in keys:
  battles.erase(key);specifications.erase(key)
  for slot in slain.keys():
   if slot is String and slot.begins_with(key+":"):slain.erase(slot)
  if tree.get_meta("university_victory","")==key:tree.remove_meta("university_victory")
 tree.set_meta(regional.BATTLES,battles);tree.set_meta(regional.SLAIN,slain)
static func prepare_run(game):
 var token=[game.get_instance_id(),game.model.seed_value];var tree:SceneTree=game.get_tree()
 var battles:Dictionary=tree.get_meta("university_battles",{})
 var keys=battles.keys().filter(func(key):return str(key).begins_with("sokia:"))
 if run!=token:
  for enemy in game.model.enemies.values().filter(func(row):return str(row.get("university_battle","")).begins_with("sokia:")):
   var handle:int=game.army_runtime.handles.get(enemy.id,0)
   if handle!=0:game.army_runtime.despawn(handle)
   game.model.enemies.erase(enemy.id)
  clear_ledger(tree,keys);specifications.clear();run=token
 elif keys.is_empty():
  # New adventures already clear the shared ledger, including when the seed repeats.
  specifications.clear()
static func data()->Dictionary:return load("res://scripts/forest/forest_south_kili_population.gd").cape_data().battles
static func companion(member:int)->bool:return data().species[member].bank=="companion"
static func radius(member:int)->float:
 var skin:int=data().species[member].skin
 var dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
 var box:AABB=dimensions.companion_body(skin) if companion(member) else dimensions.body(preload("res://scripts/forest/crowd/sokia_region_sprites.gd"),skin)
 return minf(box.size.x,box.size.z)*.5*preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE
static func specification(key:String)->Dictionary:return specifications.get(key,{})
static func action(game,key:String)->bool:
 if not key.begins_with("sokia_cape:"):return false
 var data:Dictionary=load("res://scripts/forest/forest_south_kili_population.gd").cape_data()
 var actor:Dictionary=data.actors.get(key.trim_prefix("sokia_cape:"),{})
 if actor.is_empty():return true
 if actor.get("dialogue_owner","")=="sokia_cape_access" and not on_map(game.model,actor):return true
 return load("res://scripts/forest/forest_east_events.gd").source_actor(game,actor,data.runtime_scripts.get(actor.script,{}))
static func begin(game,actor:Dictionary,args:String)->bool:
 var fields=args.split("|",true)
 if fields.size()<10 or not fields[9].is_valid_int():return false
 var encounter=int(fields[9])
 if not data().bosses.has(str(encounter)) or str(actor.id) not in ["5225","5237","5243","5305"]:return false
 prepare_run(game)
 var target=fields[1].split(",",false);var win=[]
 if target.size()==4 and target[0]=="0":win=[int(target[1]),int(target[2]),int(target[3])]
 var key="sokia:%s:%d:%d"%[actor.id,game.model.falan_floor,encounter]
 var tree:SceneTree=game.get_tree()
 if tree.get_meta("university_victory","")==key:return false
 if tree.get_meta("university_battles",{}).get(key,{}).get("complete",false):
  # A fresh source interaction may start another fight; no source one-shot flag is specified here.
  clear_ledger(tree,[key])
 specifications[key]={"map":game.model.falan_floor,"area":game.model.falan_area,"cell":Vector2i(actor.cell[0],actor.cell[1]),"encounter":encounter,"win":win,"actors":[str(actor.id)],"actor":actor,"raw_args":args}
 return load("res://scripts/forest/forest_university_region.gd").begin(game,key)
static func victory(game,_key:String,spec:Dictionary)->bool:
 if spec.win.is_empty():return false
 var target:int=spec.win[0];var cell=Vector2i(spec.win[1],spec.win[2])
 if target==300:
  var tour=load("res://scripts/forest/forest_falan_tour.gd");var area="ghana_road"
  var at:Vector2=tour.Regions.frame(area).inverse()*(Vector2(cell)*3.)
  game.transitioning=true;tour.travel.call_deferred(game,tour.Regions.layout(area),{"arrival":at,"yaw":game.camera_rig.yaw,"velocity":Vector3.ZERO})
 else:load("res://scripts/forest/forest_university_region.gd").travel(game,target,cell)
 return true

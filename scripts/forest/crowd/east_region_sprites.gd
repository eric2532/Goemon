@static_unload
extends RefCounted
const ContextRegions=preload("res://scripts/forest/forest_freyja_regions.gd")
## Source data and prepared pages for the existing native Explore army owner.
const ROOT="res://assets/characters/crossgate/east_region/"
const Snow=preload("res://scripts/forest/crowd/snow_region_sprites.gd")
const Index=preload("res://assets/maps/falan/east_region/map_index.gd")
const BODY=Snow.BODY
const STATS=Snow.STATS
const FOOTPRINT=Snow.FOOTPRINT
const TREE_FOOTPRINT=Snow.TREE_FOOTPRINT
const LEGACY_OWNERS=[11003,11004,11005,11028,15505,16503,47017]
static var population:Dictionary={}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var zone_rows:Dictionary={}
static var world_states:Dictionary={}
static var freyja_owner:Script

static func data()->Dictionary:
 if population.is_empty():
  population=load("res://scripts/forest/forest_east_region.gd").residents()
  freyja_owner=load("res://scripts/forest/forest_south_kili_population.gd")
  var freyja:Dictionary=freyja_owner.freyja_data()
  population.zones=population.zones.filter(func(zone):return int(zone.map)!=100)
  population.zones.append_array(freyja.zones)
  population.groups.merge(freyja.east_groups,true)
  var trial:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/freyja_trial/encounters.json"))
  assert(population.species.slice(0,trial.species.size())==trial.species,"Trial caves retain every established species index")
  for zone in trial.zones:
   assert(not population.zones.any(func(old):return int(old.id)==int(zone.id)),"Trial source zone must retain one owner")
   population.zones.append(zone)
  for id in trial.groups:
   assert(not population.groups.has(id),"Trial source group must retain one owner")
   population.groups[id]=trial.groups[id]
  var wind:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_wind_tower/encounters.json"))
  assert(wind.species.slice(0,population.species.size())==population.species,"Wind Tower preserves every existing species index")
  population.species.append_array(wind.species.slice(population.species.size()))
  for zone in wind.zones:
   assert(not population.zones.any(func(old):return int(old.id)==int(zone.id)),"Wind source zone retains one owner")
   population.zones.append(zone)
  for id in wind.groups:
   assert(not population.groups.has(id),"Wind source group retains one owner")
   population.groups[id]=wind.groups[id]
  for id in wind.bosses:
   assert(not population.bosses.has(id),"Wind scripted pool retains one owner")
   population.bosses[id]=wind.bosses[id]
  var wind_events:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_wind_tower/events/data.json"))
  population.scripted_battles.append_array(wind_events.scripted_battles)
  var desert:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_desert_temple/encounters.json"))
  population.generated["303"]=desert.generated_approach
  assert(desert.species.slice(0,population.species.size())==population.species,"Desert Temple preserves established species indices")
  population.species.append_array(desert.species.slice(population.species.size()))
  for zone in desert.zones:
   assert(not population.zones.any(func(old):return int(old.id)==int(zone.id)),"Desert source zone retains one owner")
   population.zones.append(zone)
  for id in desert.groups:
   assert(not population.groups.has(id),"Desert source group retains one owner")
   population.groups[id]=desert.groups[id]
  var dragon:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_dragon_summit/encounters.json"))
  for branch_ in dragon.generated_branches:population.generated[str(int(branch_.config))]=branch_
  assert(dragon.species.slice(0,population.species.size())==population.species,"Dragon/Summit preserves established species indices")
  population.species.append_array(dragon.species.slice(population.species.size()))
  for zone in dragon.zones:
   assert(not population.zones.any(func(old):return int(old.id)==int(zone.id)),"Dragon source zone retains one owner")
   population.zones.append(zone)
  for id in dragon.groups:
   assert(not population.groups.has(id),"Dragon source group retains one owner")
   population.groups[id]=dragon.groups[id]
  for id in dragon.bosses:
   assert(not population.bosses.has(id),"Dragon scripted pool retains one owner")
   population.bosses[id]=dragon.bosses[id]
  var dragon_events:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_dragon_summit/events/data.json"))
  population.scripted_battles.append_array(dragon_events.scripted_battles)
  var laboratory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/explore_recovered/encounters.json"))
  assert(laboratory.species.slice(0,population.species.size())==population.species,"Laboratory preserves established species indices")
  population.species.append_array(laboratory.species.slice(population.species.size()))
  population.generated["300"]=laboratory.generated_branch
  for id in laboratory.groups:
   assert(not population.groups.has(id),"Laboratory source group retains one owner")
   population.groups[id]=laboratory.groups[id]
  for id in laboratory.bosses:
   assert(not population.bosses.has(id),"Laboratory scripted pool retains one owner")
   population.bosses[id]=laboratory.bosses[id]
  population.scripted_battles.append_array(laboratory.scripted_battles)
  for source_index in freyja.east_member_indices:
   assert(int(population.species[int(freyja.east_member_indices[source_index])].id)==int(freyja.species[int(source_index)].id),"Freyja retains the existing East/companion presentation indices")
  for zone in population.zones:
   var source=int(zone.map)
   if not zone_rows.has(source):zone_rows[source]=[]
   zone_rows[source].append(zone)
  for group in population.groups.values():
   for detail in group.get("details",[]):
    var raw:Array=detail.raw_enemy
    detail.name=detail.get("name",population.species[int(detail.species)].name)
    detail.level=[int(raw[4]),int(raw[5])];detail.count=[int(raw[6]),int(raw[7])]
    detail.exp_override=int(raw[9])
    assert(detail.level[0]<=detail.level[1] and detail.count[0]>=1 and detail.count[0]<=detail.count[1],"Invalid pinned East enemy range")
 return population

static func owns(id:int)->bool:
 if id in LEGACY_OWNERS:return false
 var maps=load("res://scripts/forest/forest_original_maps.gd")
 if maps.source_id(id) in maps.Art.EXPLORE_RECOVERED_IDS:return maps.owns(id)
 if maps.source_id(id) in maps.Art.FREYJA_TRIAL_IDS or maps.source_id(id) in maps.Art.SOKIA_WIND_IDS or maps.source_id(id) in maps.Art.SOKIA_DESERT_TEMPLE_IDS or maps.source_id(id) in maps.Art.SOKIA_DRAGON_SUMMIT_IDS:return maps.owns(id)
 var branch:String=maps.generated().branch(id)
 if not branch.is_empty():return maps.generated().SPECS[branch].get("east",false)
 return maps.source_id(id) in Index.FIXED

static func owns_model(model)->bool:
 var context=ContextRegions.private_source_context
 if context!=null and context.owns(model):return true
 return model.falan_area in ["east_gate","north_coast"] or model.falan_area=="interior" and owns(model.falan_floor)

static func tree(_skin:int)->bool:return false

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:return PackedFloat32Array(motions().timelines)

static func make_mesh()->QuadMesh:
 if sounds.is_empty():
  for cue in motions().sounds:sounds[cue]=load(motions().sounds[cue] if motions().sounds[cue].begins_with("res://") else ROOT+motions().sounds[cue])
 return preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.,1.)

static func zone_at(id:int,cell:Vector2i)->Dictionary:
 data()
 var maps=load("res://scripts/forest/forest_original_maps.gd")
 var key:String=maps.generated().branch(id)
 if not key.is_empty() and maps.generated().SPECS[key].get("east",false):
  var config:int=maps.generated().SPECS[key].config
  var source:Dictionary=population.generated.get(str(config),{})
  if source.is_empty() or source.get("pool",{}).is_empty():return {}
  var zone:Dictionary=source.pool.duplicate(true)
  zone.id=id;zone.levels=maps.generated().SPECS[key].levels
  return zone
 var result={};var source:int=100 if id<=0 or id==100 else maps.source_id(id)
 for zone in zone_rows.get(source,[]):
  var b:Array=zone.bounds
  if cell.x<b[0] or cell.y<b[1] or cell.x>b[2] or cell.y>b[3]:continue
  if result.is_empty() or int(zone.priority)>int(result.priority) or int(zone.priority)==int(result.priority) and int(zone.id)>int(result.id):result=zone
 return result

static func group(zone:Dictionary,bags:Dictionary,rng:RandomNumberGenerator,items:Dictionary={})->Array:
 if zone.is_empty() or zone.groups.is_empty() or int(zone.maximum)<=0:return []
 if zone.get("freyja_trial_source",false) or zone.get("wind_tower_source",false) or zone.get("source_party_contract",false):
  data()
  return freyja_owner.group_from_data(zone,bags,rng,population.groups,items)
 if zone.get("freyja_source",false):
  data()
  var party:Array=freyja_owner.group(zone,bags,rng,items);var contract:Dictionary=freyja_owner.freyja_data()
  for member in party:member[0]=int(contract.east_member_indices[str(int(member[0]))])
  return party
 var id=Snow.weighted(bags,"east-group:%s"%zone.id,zone.groups,rng)
 var source:Dictionary=data().groups[id]
 if source.has("fixed"):return source.fixed.duplicate(true)
 var choices=[]
 for i in source.members.size():choices.append([i,source.members[i][3]])
 var count_=int(Snow.draw(bags,"east-count:%s"%zone.id,range(1,int(zone.maximum)+1),rng));var result=[]
 for i in count_:
  var member:Array=source.members[Snow.weighted(bags,"east-member:"+id,choices,rng)]
  var span:Array=zone.get("levels",[member[1],member[2]])
  var level=int(Snow.draw(bags,"east-level:%s:%s"%[zone.id,member[0]],range(int(span[0]),int(span[1])+1),rng))
  result.append([int(member[0]),level])
 return result

static func available(member:int)->bool:
 return member>=0 and member<data().species.size() and data().species[member].bank in ["east_region","companion"] and int(data().species[member].skin)>=0

static func companion(member:int)->bool:return data().species[member].bank=="companion"

static func radius(member:int)->float:
 if not available(member):return FOOTPRINT*preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE
 var species:Dictionary=data().species[member]
 var dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
 var box:AABB=dimensions.companion_body(int(species.skin)) if companion(member) else dimensions.body(load("res://scripts/forest/crowd/east_region_sprites.gd"),int(species.skin))
 return minf(box.size.x,box.size.z)*.5*preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE

static func source_cell(model,at:Vector2)->Vector2i:
 var context=ContextRegions.private_source_context
 if context!=null and context.owns(model):return Vector2i(((at-context.source_point(context.source_id(model),Vector2i.ZERO))/3.).round())
 if model.falan_area=="interior":
  var maps=load("res://scripts/forest/forest_original_maps.gd")
  return Vector2i(((at-maps.state(model.falan_floor,model.seed_value).origin)/3.).round())+maps.crop(model.falan_floor,model.seed_value).position
 return Vector2i((load("res://scripts/forest/forest_freyja_regions.gd").frame(model.falan_area)*at/3.).round())

static func state(model)->Dictionary:
 if model.falan_area=="interior":
  var row=load("res://scripts/forest/forest_original_maps.gd").state(model.falan_floor,model.seed_value)
  return {"size":row.size,"origin":row.origin,"bits":row.bits}
 var texture:Texture2D=model.terrain.mask_texture();var origin:Vector2=model.terrain.mask_origin()
 var signature=[texture.get_instance_id(),origin]
 var cached:Dictionary=world_states.get(model.falan_area,{})
 if cached.get("signature",[])==signature:return cached
 var image:Image=model.terrain.mask_image();var bits=PackedByteArray();bits.resize((image.get_width()*image.get_height()+7)>>3)
 for y in image.get_height():
  for x in image.get_width():
   var c=image.get_pixel(x,y);var n=y*image.get_width()+x
   if c.r<.5 and c.b<.98 and c.a>=.5:bits[n>>3]|=1<<(n&7)
 cached={"size":image.get_size(),"origin":origin,"bits":bits,"signature":signature}
 world_states[model.falan_area]=cached
 return cached

static func encounter_scope(model,at:Vector2)->bool:
 var context=ContextRegions.private_source_context
 if context!=null and context.owns(model):return false
 if not owns_model(model):return false
 data()
 if model.falan_area in ["east_gate","north_coast"]:
  if load("res://scripts/forest/forest_freyja_regions.gd").village_contains(model.falan_area,at):return false
  if not freyja_owner.encounter_scope(model,at):return false
 return not zone_at(model.falan_floor,source_cell(model,at)).is_empty()

static func source_bounds(model)->Rect2i:
 var bounds:Rect2=model.terrain.mask_bounds()
 var corners=[bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]
 var first:Vector2i=source_cell(model,corners[0]);var low=first;var high=first
 for at in corners:
  var cell=source_cell(model,at);low=low.min(cell);high=high.max(cell)
 return Rect2i(low,high-low+Vector2i.ONE)

static func held_item_encounters(model)->Array:
 var runtime=model.get("army_runtime")
 var scene:SceneTree=runtime.get_tree() if is_instance_valid(runtime) else Engine.get_main_loop() as SceneTree
 if scene==null:return []
 var events=load("res://scripts/forest/forest_east_events.gd")
 var held:Dictionary=scene.get_meta(events.ITEMS,{})
 var result=[]
 for battle in data().scripted_battles:
  if battle.has("item") and events.item_count(held,int(battle.item))>0:result.append(str(int(battle.encounter)))
 return result

static func possible_members(model)->Array:
 data()
 var maps=load("res://scripts/forest/forest_original_maps.gd")
 var context=ContextRegions.private_source_context
 var source:int=context.source_id(model) if context!=null and context.source_id(model)>0 else 100 if model.falan_area in ["east_gate","north_coast"] else maps.source_id(model.falan_floor)
 var key:String=maps.generated().branch(model.falan_floor) if model.falan_area=="interior" else ""
 var config:int=int(maps.generated().SPECS[key].config) if not key.is_empty() and maps.generated().SPECS[key].get("east",false) else -1
 var groups={};var pending=[];var seen={}
 var bounds=source_bounds(model) if source==100 else Rect2i()
 if config>=0:
  var generated:Dictionary=population.generated.get(str(config),{})
  for choice in generated.get("pool",{}).get("groups",[]):groups[str(choice[0])]=true
 else:
  for zone in zone_rows.get(source,[]):
   var b:Array=zone.bounds
   if source==100 and not bounds.intersects(Rect2i(Vector2i(b[0],b[1]),Vector2i(b[2]-b[0]+1,b[3]-b[1]+1))):continue
   for choice in zone.groups:groups[str(choice[0])]=true
 for battle in population.scripted_battles:
  if config>=0 and battle.get("generated_by")!=null and int(battle.generated_by)==config:pending.append(str(int(battle.encounter)));continue
  if config>=0 or battle.get("generated_by")!=null or int(battle.source)!=source:continue
  if source==100:
   var actor:Dictionary={}
   for row in population.actors:
    if str(row.id)==str(battle.actor):actor=row;break
   if actor.is_empty() or not bounds.has_point(Vector2i(actor.cell[0],actor.cell[1])):continue
  pending.append(str(int(battle.encounter)))
 # This only warms possible source pages; item Floor/time/quest predicates still run at use.
 pending.append_array(held_item_encounters(model))
 while not pending.is_empty():
  var id:String=pending.pop_back()
  if seen.has(id):continue
  seen[id]=true
  var zone:Dictionary=population.bosses.get(id,{})
  for choice in zone.get("groups",[]):groups[str(choice[0])]=true
  if int(zone.get("next_encounter",0))>0:pending.append(str(int(zone.next_encounter)))
 var members={}
 for id in groups:
  var source_group:Dictionary=population.groups.get(id,{})
  for row in source_group.get("members",[]):members[int(row[0])]=true
  for row in source_group.get("details",[]):members[int(row.species)]=true
 return members.keys()

static func prepare(model)->Dictionary:
 if not owns_model(model):return {"members":[],"skins":[],"pages":[]}
 var members=possible_members(model);var skins={};var pages={};var data_=motions()
 for member in members:
  if not available(member) or companion(member):continue
  var skin=int(data().species[member].skin);skins[skin]=true
  assert(skin<data_.variants.size() and skin<data_.skin_pages.size(),"East source skin has no prepared page contract")
  for page in data_.skin_pages[skin]:pages[int(page)]=true
 var selected:Array=pages.keys();selected.sort()
 make_mesh()
 preload("res://scripts/forest/crowd/hound_sprites.gd").prepare_pages(ROOT,data_,selected)
 return {"members":members,"skins":skins.keys(),"pages":selected}

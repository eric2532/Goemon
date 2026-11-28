extends Node
## Explore wayfinding and optional returns share the existing travel and native combat owners.
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const HOSPITAL_DOOR=Vector2(-153,-204)
const HOSPITAL_LANDING=Vector2(-144,-204)
const VICTORY_DIAMOND_SCALE=.35
const HOSPITAL_DIAMOND_COLOR=Color(.2,1.,.55)
const GROUP_FIELDS=["habaru_slot","venoa_bear_slot","undersea_slot","zombie_slot","captain_slot","grave_slot","ruby_slot","falken_slot","frostpass_slot","black_prayer_slot"]
var game
var encounters:Dictionary={}
var map_token:Array=[]
var timer=0.
var visuals:Node3D
var gates:Array=[]
var gate_visuals:Node3D
var returns:Dictionary={}
var pending_return:Dictionary={}
var boss_spots:Array=[]
var endpoint:Dictionary={}
var endpoint_ready=false
var rewards:Dictionary={}
var places:Dictionary={}
var gates_dirty=false

func reset_run():
 encounters.clear();returns.clear();pending_return.clear();gates.clear();rewards.clear();places.clear();gates_dirty=false;map_token=[]
 invalidate()
 if is_instance_valid(gate_visuals):gate_visuals.queue_free()
 for spot in boss_spots:
  if is_instance_valid(spot.get("host")):spot.host.queue_free()
  if is_instance_valid(spot.get("label")):spot.label.queue_free()
 boss_spots=[];endpoint={};endpoint_ready=false

func scope()->String:return "%s:%d"%[game.model.falan_area,game.model.falan_floor]
func enabled()->bool:
 return game.playing and game.model!=null and game.get_tree().has_meta("falan_venture") and not Tour.area(game.model).is_empty()

func _process(delta):
 if not enabled() or game.transitioning:return
 if game.army_runtime.configured_model!=game.model or game.army_runtime.navigation_revision!=game.model.navigation_revision:return
 timer-=delta
 if timer>0:return
 timer=.15
 var token=[game.model.get_instance_id(),game.world.map_features.get_instance_id()]
 if token!=map_token:
  if is_instance_valid(visuals):visuals.queue_free()
  if is_instance_valid(gate_visuals):gate_visuals.queue_free()
  map_token=token;visuals=null;gate_visuals=null
  prepare_gates()
  endpoint=preload("res://scripts/forest/forest_explore_endpoints.gd").prepare(game);endpoint_ready=false
  prepare_boss_spots()
 if gates_dirty:prepare_gates();gates_dirty=false
 if not endpoint.is_empty() and not endpoint_ready and game.model.phase=="wave":
  endpoint_ready=true
  if not encounters.get(scope()+":endpoint:"+endpoint.key,{}).get("cleared",false):
   if not preload("res://scripts/forest/forest_explore_endpoints.gd").spawn(game,endpoint):
    game.model.set_meta("explore_endpoint_blocker",{"map":game.model.falan_floor,"reason":"No source-open encounter spot fits the prepared native body and player route."})
   elif game.model.has_meta("explore_endpoint_blocker"):game.model.remove_meta("explore_endpoint_blocker")
 update_boss_spots()
 resolve_pending()
 rebuild_visuals()
 for key in rewards.get(scope(),{}):
  if not game.exploration_loot.opened_chests.has(key):game.exploration_loot.spawn_boss_chest(game.model.world_point(rewards[scope()][key]),key)

func resolve_pending():
 for key in encounters:
  var record:Dictionary=encounters[key]
  if record.scope!=scope()or not record.get("pending",false):continue
  if int(record.get("pending_model",-1))!=game.model.get_instance_id():record.pending=false;continue
  var alive=game.model.enemies.values().any(func(e):return e.hp>0 and member(e,record.group))
  var phases_complete=record.group!="grave_slot"or game.get_tree().get_meta(Tour.Grave.SLAIN,{}).has(3)
  if not alive and phases_complete:won(key,record.at)

func map_retiring():
 if not enabled()or game.army_runtime.configured_model!=game.model:return
 var bookmark=pending_return;pending_return={}
 resolve_pending()
 pending_return=bookmark
 for record in encounters.values():
  if record.scope==scope()and not record.cleared:record.pending=false;record.erase("pending_model")

func prepare_gates():
 if is_instance_valid(gate_visuals):gate_visuals.queue_free()
 var signature=[game.model.get_instance_id(),game.model.falan_area,game.model.falan_floor,game.world.map_features.get_instance_id()]
 if game.explorer_npcs.map_signature!=signature:game.explorer_npcs.prepare()
 gates=[]
 if not pending_return.is_empty():
  pending_return.entry_at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  returns[scope()]=pending_return;pending_return={}
 if returns.has(scope()):
  var back:Dictionary=returns[scope()].duplicate();back.at=back.entry_at;back.caption="返回 · "+str(back.layout.get("title","入口"));back.back=true
  gates.append(back)
 for record in encounters.values():
  if record.scope!=scope()or not record.cleared or record.get("superseded",false) or record.get("win",[]).is_empty():continue
  var win:Array=record.win;var cell=Vector2i(win[1],win[2])
  if not preload("res://scripts/forest/forest_explore_routes.gd").can_travel(game,int(win[0]),cell):
   record.win_blocker={"map":win[0],"cell":cell,"reason":"Original post-victory destination is not available."};continue
  var portal:Vector2=record.get("portal",record.at);var direction=Vector2.RIGHT
  var native_exits=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==Tour.Winter.Recovered.runtime_id(int(win[0])))
  native_exits.sort_custom(func(a,b):return a.at.distance_squared_to(portal)<b.at.distance_squared_to(portal))
  # Stay on the arena side of an ordinary exit that opens after victory.
  if not native_exits.is_empty()and portal.distance_squared_to(native_exits[0].at)<30.*30.:
   var away:Vector2=portal-native_exits[0].at
   if away.length_squared()>.01:direction=away.normalized()
  var station=safe_station(portal+direction*7.5)
  if not station.is_finite():continue
  gates.append({"at":station,"target":int(win[0]),"landing":cell,"actor":"victory","caption":"出口 · "+preload("res://scripts/forest/forest_explore_routes.gd").destination_title(int(win[0]))})
 for candidate in preload("res://scripts/forest/forest_explore_routes.gd").candidates(game):
  if gates.any(func(g):return g.get("target",-1)==candidate.target and g.get("landing",Vector2i.ZERO)==candidate.landing and g.at.distance_squared_to(candidate.at)<9.):continue
  var station=safe_station(candidate.at,false,candidate.get("exclude_trigger",Rect2()))
  if not station.is_finite():continue
  candidate.at=station;gates.append(candidate)
 for gate in gates.duplicate():
  if gate.get("back",false):
   var station=safe_station(gate.at)
   if not station.is_finite():gates.erase(gate);continue
   gate.at=station
 var captions={}
 for gate in gates:captions.get_or_add(gate.caption,[]).append(gate)
 for group_ in captions.values():
  for gate in group_:
   if group_.any(func(other):return not is_same(other,gate) and other.at.distance_squared_to(gate.at)<8.*8.):gate.caption+=" · 入口 %d"%(group_.find(gate)+1)
 gate_visuals=Node3D.new();gate_visuals.name="ExploreCrossGates";game.world.map_features.add_child(gate_visuals)
 var drawn=[]
 for gate in gates:
  if drawn.any(func(point):return point.distance_squared_to(gate.at)<1.):continue
  drawn.append(gate.at)
  var host=Node3D.new();host.set_meta("explore_gate",gate.duplicate());host.position=game.model.world_point(gate.at)/game.model.falan_scale;gate_visuals.add_child(host)
  Tour.build_diamond(host,Vector3.ZERO)
  var diamond=host.get_child(0);diamond.scale=Vector3.ONE*.6;diamond.position.y=1.6
  if gate.get("actor","")=="victory":
   diamond.scale=Vector3.ONE*VICTORY_DIAMOND_SCALE;diamond.position.y=10.*VICTORY_DIAMOND_SCALE
   diamond.set_meta("explore_portal_role","original_exit")
  var label=Label3D.new();label.font=preload("res://scripts/forest/preparation_skin.gd").FONT;label.font_size=30;label.pixel_size=.00065;label.fixed_size=true
  var names=PackedStringArray()
  for other in gates:
   if other.at.distance_squared_to(gate.at)<1.:names.append(other.caption)
  label.text="F · Cross Gate\n"+"\n".join(names);label.position=Vector3.UP*5.;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.visibility_range_end=30.;host.add_child(label)
  if gate.get("actor","")=="victory":label.position.y=7.

func prepare_boss_spots():
 for spot in boss_spots:
  if is_instance_valid(spot.get("host")):spot.host.queue_free()
  if is_instance_valid(spot.get("label")):spot.label.queue_free()
 boss_spots=[]
 var regional=preload("res://scripts/forest/forest_university_region.gd");var maps=Tour.Winter.Recovered
 for key in regional.BOSSES:
  var spec:Dictionary=regional.specification(key,game.model.seed_value)
  if game.model.falan_area!="interior" or int(spec.map)!=game.model.falan_floor:continue
  var at=maps.point(game.model.falan_floor,spec.cell,game.model.seed_value) if maps.generated().owns(game.model.falan_floor) else maps.source_point(game.model.falan_floor,spec.cell)
  for entry in game.explorer_npcs.actors:
   if str(entry.record.id).trim_prefix("source:")in spec.get("actors",[])and entry.has("interaction_point"):
    at=Vector2(entry.interaction_point.x,entry.interaction_point.z)/game.model.falan_scale;break
  var spot={"at":at,"key":key,"name":key,"group":"regional:"+key,"actors":spec.get("actors",[]).duplicate()}
  var source=regional.bank_for(key);var zone:Dictionary=source.data().bosses.get(str(spec.encounter),{})
  if zone.is_empty():continue
  var party:Dictionary=source.data().groups[zone.groups[0][0]]
  var member_:Dictionary=party.details[0];spot.name=member_.get("name",key)
  if key in ["lizard","zombie","dijiro"]:
   spot.manual_begin=true
   var skin:int=source.data().species[int(member_.species)].skin
   var companion:bool=source.companion(int(member_.species));var pets=preload("res://scripts/forest/pet_catalog.gd");var sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
   var mesh=sprites.meshes.get(pets.ROOT)if companion else source.make_mesh()
   if mesh!=null and (not companion or pets.is_prepared(skin)):
    var dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
    var box=dimensions.companion_body(skin)if companion else dimensions.body(source,skin)
    var height=box.end.y if companion else float(source.motions().variants[skin].standing_height)
    var host=game.prepare_boss_host(mesh,"ExploreBossWaiting_"+key,at,box,height,spot.name)
    if companion:sprites.apply_world_scale(host,game.model)
    else:host.set_instance_shader_parameter("map_enemy_scale",preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE)
    host.multimesh.set_instance_custom_data(0,Color(skin,0,0,0));host.get_child(0).hide()
    spot.host=host
  boss_spots.append(spot)
 if game.model.falan_floor==game.Habaru.ROOM:
  boss_spots.append({"at":Tour.Regions.Sites.HABARU_FORMATION[0],"key":"","name":"熊弟","group":"habaru_slot"})
 if game.model.falan_floor==Tour.Regions.Sites.VENOA_BOSS_FLOOR:
  boss_spots.append({"at":Tour.Regions.Sites.VENOA_BOSS_AT,"key":"","name":game.model.waves.CaveProgression.HABARU[game.Habaru.VENOA_BOSS_SKIN][0],"group":"venoa_bear_slot"})
 if game.model.falan_floor==game.Falken.ROOM:
  boss_spots.append({"at":game.Falken.Route.point(game.Falken.ROOM,game.Falken.Route.BOSS_CELL),"key":"","name":"法爾肯","group":"falken_slot"})
 var guardian=Tour.Winter.Decree.GUARDIAN_FLOORS.find(game.model.falan_floor)
 if guardian>=0:
  var at=maps.source_point(game.model.falan_floor,Tour.Winter.Decree.Recovered.GUARD_CELLS[guardian])
  var name_="凱法 / 帕布提斯馬"if guardian==Tour.Winter.Decree.GUARDIAN_FLOORS.size()-1 else Tour.Winter.Decree.TITLES[game.model.falan_floor].get_slice(" · ",1)
  boss_spots.append({"at":at,"key":"","name":name_,"group":"frostpass_slot"})
 var legacy={11004:"habaru_slot",15505:"zombie_slot",16503:"captain_slot",47017:"grave_slot",game.Falken.ROOM:"falken_slot",Tour.Ruby.ROOM:"ruby_slot"}
 for floor_:int in Tour.Winter.Decree.GUARDIAN_FLOORS:legacy[floor_]="frostpass_slot"
 if game.model.falan_floor==15505:
  boss_spots.append({"at":Tour.Regions.Sites.ZOMBIE_FORMATIONS[15505][0][0],"key":"","name":game.model.waves.CaveProgression.ZOMBIE[0][0],"group":"zombie_slot"})
 if game.model.falan_floor==16503:
  boss_spots.append({"at":Tour.Regions.Sites.CAPTAIN_FORMATION[0][0],"key":"","name":game.model.waves.CaveProgression.CAPTAIN[0][0],"group":"captain_slot"})
 if game.model.falan_floor==47017:
  boss_spots.append({"at":Tour.Regions.Sites.GRAVE_FORMATION[0],"key":"","name":game.model.waves.CaveProgression.GRAVE[0][0],"group":"grave_slot"})
 if game.model.falan_floor==Tour.Ruby.ROOM:
  boss_spots.append({"at":Tour.Regions.Sites.RUBY_FORMATION[0][0],"key":"","name":"露比","group":"ruby_slot"})
 var undersea=game.model.waves.Undersea
 if game.model.falan_floor==undersea.SOKIA:
  var host=game.prepare_boss_host(undersea.make_mesh(),"ExploreOznikWaiting",undersea.BOSS_AT,undersea.BODY,float(undersea.motions().variants[0].standing_height),undersea.BOSS_NAME)
  host.set_instance_shader_parameter("map_enemy_scale",preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE)
  host.get_child(0).text="Boss · "+undersea.BOSS_NAME
  boss_spots.append({"at":undersea.BOSS_AT,"key":"","name":undersea.BOSS_NAME,"group":"undersea_slot","undersea":true,"host":host})
 for entry in game.explorer_npcs.actors:
  var record:Dictionary=entry.node.get_meta("npc_record",{})
  var action:String=record.get("quest_action","")
  if action.begins_with("region_boss_"):continue
  var source:int=record.get("source",-1)
  var declarations:Array=preload("res://scripts/forest/forest_explore_routes.gd").catalog.get("bosses",{}).get(str(source),[])
  if not declarations.any(func(b):return str(b.actor)==str(record.get("id",""))):continue
  var interaction:Vector3=entry.get("interaction_point",entry.node.global_position)
  var at=Vector2(interaction.x,interaction.z)/game.model.falan_scale
  if entry.get("source_cell_blocked",false):
   var station=safe_station(at)
   if station.is_finite()and station.distance_squared_to(at)<=8.*8.:
    at=station;entry.interaction_point=game.model.world_point(station,.15)
  var matches=declarations.filter(func(b):return str(b.actor)==str(record.id))
  if legacy.has(game.model.falan_floor):
   for spot in boss_spots:
    if spot.group==legacy[game.model.falan_floor]:spot.get_or_add("actors",[]).append(str(record.id))
   continue
  var fights=[]
  for declaration in matches:fights.append_array(declaration.declarations)
  var spot={"at":at,"key":"","actor":str(record.id),"record":record,"fights":fights,"name":record.name,"group":"trigger:"+str(record.id)}
  boss_spots.append(spot)
 var region=load("res://scripts/forest/forest_east_region.gd")
 var source_id:int=maps.source_id(game.model.falan_floor) if game.model.falan_area=="interior" else {"city":1000,"castle":1500,"east_gate":100,"north_coast":100}.get(game.model.falan_area,-1)
 if game.model.falan_area in region.SOURCE_VILLAGES.values():source_id=int(Tour.Regions.Sites.VILLAGES[game.model.falan_area][0])
 if game.model.falan_area in Tour.SouthPopulation.FREYJA_AREAS:source_id=100
 if game.model.falan_area in Tour.SouthPopulation.SOKIA_AREAS:source_id=300
 region.residents()
 var boss_catalog:Dictionary=preload("res://scripts/forest/forest_explore_routes.gd").catalog.get("bosses",{})
 var declarations:Array=boss_catalog.get(str(source_id),[]).duplicate()
 var terminal=region.terminal_record(game.model)
 if not terminal.is_empty():declarations.append_array(boss_catalog.get("777",[]).filter(func(d):return str(d.actor)==str(terminal.id)))
 for declaration in declarations:
  var actor:String=str(declaration.actor)
  if boss_spots.any(func(s):return s.get("actor","")==actor or actor in s.get("actors",[])):continue
  if legacy.has(game.model.falan_floor):
   for spot in boss_spots:
    if spot.group==legacy[game.model.falan_floor]:spot.get_or_add("actors",[]).append(actor)
   continue
  var matched=false
  for spot in boss_spots:
   if spot.key.is_empty():continue
   var encounter=int(regional.specification(spot.key,game.model.seed_value).encounter)
   if declaration.declarations.any(func(d):var args=d.split("|",true);return args.size()>9 and int(args[9])==encounter):
    spot.get_or_add("actors",[]).append(actor);matched=true;break
  if matched:continue
  var record:Dictionary=region.source_actors.get(actor,{})
  if record.is_empty():record=load("res://scripts/forest/forest_sokia_cape.gd").access().actors.get(actor,{})
  if not terminal.is_empty() and actor==str(terminal.id):record=terminal
  if record.is_empty():continue
  var cell=Vector2i(record.cell[0],record.cell[1]);var original=record.render_at if record.has("render_at") else region.source_point(source_id,cell,game.model.falan_area)
  var at=safe_station(original)
  if not at.is_finite() or at.distance_squared_to(original)>8.*8.:continue
  boss_spots.append({"at":at,"key":"","actor":actor,"record":record,"fights":declaration.declarations,"name":record.name,"group":"trigger:"+actor})
 if not endpoint.is_empty():boss_spots.append({"at":endpoint.at,"key":"","name":endpoint.name,"group":"endpoint:"+str(endpoint.key)})
 for spot in boss_spots:
  var place=scope()+":"+str(spot.get("actor",""))
  if places.has(place) and encounters.has(places[place]):spot.group=encounters[places[place]].group
  var label=Label3D.new();label.font=preload("res://scripts/forest/preparation_skin.gd").FONT;label.font_size=32;label.pixel_size=.00065;label.fixed_size=true;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  label.text="⚔ Boss · "+spot.name;label.position=game.model.world_point(spot.at,5.)/game.model.falan_scale;label.visibility_range_end=55.;game.world.map_features.add_child(label);spot.label=label

func update_boss_spots():
 for spot in boss_spots:
  if not endpoint.is_empty()and spot.group=="endpoint:"+str(endpoint.key):
   spot.at=endpoint.at
   if is_instance_valid(spot.get("label")):spot.label.position=game.model.world_point(spot.at,5.)/game.model.falan_scale
  var key=scope()+":"+spot.group
  if not encounters.has(key):encounters[key]={"scope":scope(),"group":spot.group,"at":spot.at,"name":spot.name,"cleared":false,"discovered":false,"pending":false}
  var record:Dictionary=encounters[key]
  if not spot.key.is_empty():
   var battle:Dictionary=game.get_tree().get_meta("university_battles",{}).get(spot.key,{})
   if is_instance_valid(spot.get("host")):spot.host.visible=battle.is_empty()
   if is_instance_valid(spot.get("host")):
    var pose=spot.host.multimesh.get_instance_custom_data(0);pose.b+=.15;spot.host.multimesh.set_instance_custom_data(0,pose)
  if spot.get("undersea",false)and is_instance_valid(spot.get("host")):spot.host.visible=not game.model.waves.undersea_source_requested and not record.cleared
  if game.player.position.distance_squared_to(game.model.world_point(spot.at))<pow(42.*game.model.falan_scale,2):record.discovered=true
  if is_instance_valid(spot.get("label")):spot.label.text=("✓ 已擊敗 · "if record.cleared else "F · ⚔ Boss · "if spot.has("fights")or spot.get("manual_begin",false)or spot.get("undersea",false)else "⚔ Boss · ")+spot.name

func group(enemy:Dictionary)->String:
 if enemy.get("explore_undersea_member",false):return "undersea_slot"
 if enemy.has("explore_endpoint"):return "endpoint:"+str(enemy.explore_endpoint)
 if enemy.has("university_battle"):return "regional:"+str(enemy.university_battle)
 if enemy.has("elsa_battle"):return "elsa:"+str(enemy.elsa_battle)
 for field in GROUP_FIELDS:
  if enemy.has(field):return field
 return "unit:"+str(enemy.id)

func member(enemy:Dictionary,identity:String)->bool:
 if identity.begins_with("endpoint:"):return enemy.get("explore_endpoint","")==identity.trim_prefix("endpoint:")
 if identity.begins_with("regional:"):return enemy.get("university_battle","")==identity.trim_prefix("regional:")
 if identity.begins_with("elsa:"):return enemy.get("elsa_battle","")==identity.trim_prefix("elsa:")
 if identity=="undersea_slot":return enemy.has(identity) or enemy.get("explore_undersea_member",false)
 # Guardian rooms contain their original retinue, not wandering corridor patrols.
 if identity=="frostpass_slot":return enemy.has(identity)and (enemy.get("boss",false)or game.model.falan_floor in Tour.Winter.Decree.GUARDIAN_FLOORS)
 if identity in ["venoa_bear_slot","zombie_slot"]:return enemy.has(identity) and enemy.get("boss",false)
 if identity.begins_with("unit:"):return str(enemy.id)==identity.trim_prefix("unit:")
 return enemy.has(identity)

func discover(enemy:Dictionary)->String:
 var identity=group(enemy);var key=scope()+":"+identity
 if identity.begins_with("regional:"):
  var battle_key=identity.trim_prefix("regional:")
  var spec:Dictionary=preload("res://scripts/forest/forest_university_region.gd").specification(battle_key,game.model.seed_value)
  var actors:Array=spec.get("actors",[]).duplicate()
  if battle_key.begins_with("east:")and spec.has("raw_args"):
   var original=declaration_identity(spec.raw_args)
   var anchors=boss_spots.filter(func(s):return str(s.get("actor",""))in actors)
   for spot in boss_spots:
    if not spot.has("actor")or str(spot.actor)in actors or not anchors.any(func(a):return a.at.distance_squared_to(spot.at)<=8.*8.):continue
    for declaration:String in spot.get("fights",[]):
     if declaration_identity(declaration)==original:actors.append(str(spot.actor));break
  for actor in actors:
   var place=scope()+":"+str(actor)
   if enemy.hp>0:
    var previous:String=places.get(place,"")
    if previous!=key:
     if encounters.has(previous):encounters[previous].superseded=true;encounters[previous].erase("portal")
     places[place]=key;gates_dirty=true;invalidate()
   var trigger_key=scope()+":trigger:"+str(actor)
   if encounters.has(trigger_key):encounters.erase(trigger_key)
   for spot in boss_spots:
    if spot.get("actor","")==str(actor):spot.group=identity
 if not encounters.has(key):
  encounters[key]={"scope":scope(),"group":identity,"at":Vector2(enemy.pos.x,enemy.pos.z)/game.model.falan_scale,"name":enemy.get("enemy_name","Boss"),"discovered":false,"cleared":false,"pending":false}
 var record:Dictionary=encounters[key]
 if enemy.hp>0:record.superseded=false
 record.name=enemy.get("enemy_name",record.name)
 if enemy.pos.distance_squared_to(game.player.position)<pow(42.*game.model.falan_scale,2):record.discovered=true
 # A later native generation owns a fresh victory and removes the previous portal.
 if record.cleared and enemy.hp>0:record.cleared=false;record.erase("portal");gates_dirty=true;invalidate()
 return key

func defeated(enemy:Dictionary):
 if not enabled():return
 var key=discover(enemy)if enemy.get("boss",false)else scope()+":"+group(enemy)
 if not encounters.has(key):return
 var record:Dictionary=encounters[key];record.discovered=true
 # Scripted owners decide when their complete phase chain has ended.
 if record.group.begins_with("regional:") or record.group.begins_with("elsa:"):return
 record.pending=true;record.pending_model=game.model.get_instance_id()

func scripted_victory(identity:String,at:Vector2,name_:String="Boss",win:Array=[]):
 var key=scope()+":"+identity
 if not encounters.has(key):encounters[key]={"scope":scope(),"group":identity,"at":at,"name":name_,"discovered":true,"cleared":false,"pending":false}
 encounters[key].win=win
 if game.model.enemies.values().any(func(e):return e.hp>0 and member(e,identity)):
  encounters[key].pending=true;encounters[key].pending_model=game.model.get_instance_id()
  return
 won(key,encounters[key].at)

func won(key:String,at:Vector2):
 var record:Dictionary=encounters[key]
 if record.cleared:return
 record.cleared=true;record.discovered=true;record.at=at;record.pending=false;record.erase("pending_model")
 if not record.has("win"):
  var actors=[]
  for spot in boss_spots:
   if spot.group==record.group:actors.append_array(spot.get("actors",[]))
  var source:int=Tour.Winter.Recovered.source_id(game.model.falan_floor);var wins=[]
  for route in preload("res://scripts/forest/forest_explore_routes.gd").data().get(str(source),[]):
   if str(route.actor)not in actors or not route.get("victory_only",route.get("type","")=="StandEnemy"):continue
   var win=[int(route.target),int(route.landing[0]),int(route.landing[1])]
   if int(route.target)==source and Vector2(route.cell[0],route.cell[1]).distance_to(Vector2(route.landing[0],route.landing[1]))<=1.:continue
   if win not in wins:wins.append(win)
  if wins.size()==1:record.win=wins[0]
 record.victories=int(record.get("victories",0))+1
 var portal_at=at
 # The original bridge's side pillars obscure Yamabuki's retry view; its centre approach aisle is open.
 if game.model.falan_floor==35006 and record.group.begins_with("regional:east:313002:"):portal_at=Tour.Winter.Recovered.source_point(35006,Vector2i(10,10))
 # Chichi's three original exits share the cliff edge; use the open grass beside their captions.
 if game.model.falan_floor==43000 and record.group.begins_with("regional:east:305108:"):portal_at=at+Vector2(-9,3)
 var station=safe_station(portal_at,true)
 if not station.is_finite():station=safe_station(portal_at)
 if station.is_finite():record.portal=station
 else:record.portal_pending=true
 record.chest_key="boss:%s:%d"%[key,record.victories]
 if record.has("portal"):place_chest(record)
 invalidate()
 prepare_gates()
 game.toast("戰鬥勝利 · 菱形傳送門 → 法蘭城東醫院外")

func place_chest(record:Dictionary):
 var station=safe_station(record.portal+Vector2(-6.,0))
 if not station.is_finite():station=record.portal
 record.chest=station
 rewards.get_or_add(scope(),{})[record.chest_key]=station
 game.exploration_loot.spawn_boss_chest(game.model.world_point(station),record.chest_key)

func safe_station(at:Vector2,avoid_gates:bool=false,exclude_trigger:Rect2=Rect2())->Vector2:
 var path_start=player_path_start()
 if not path_start.is_finite():return Vector2.INF
 var candidates=[at]
 var player_at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var edges=[]
 if exclude_trigger.has_area()and not exclude_trigger.has_point(player_at):edges=[exclude_trigger.position,Vector2(exclude_trigger.end.x,exclude_trigger.position.y),exclude_trigger.end,Vector2(exclude_trigger.position.x,exclude_trigger.end.y)]
 for ring in range(1,9):
  for direction in 16:candidates.append(at+Vector2.from_angle(direction*TAU/16.)*ring*1.5)
 for point:Vector2 in candidates:
  if exclude_trigger.has_area()and exclude_trigger.has_point(point):continue
  var crosses=false
  for i in edges.size():
   if Geometry2D.segment_intersects_segment(player_at,point,edges[i],edges[(i+1)%edges.size()])!=null:crosses=true;break
  if crosses:continue
  if avoid_gates and gates.any(func(g):return point.distance_squared_to(g.at)<4.5*4.5):continue
  if avoid_gates and boss_spots.any(func(s):return point.distance_squared_to(s.at)<4.5*4.5):continue
  if avoid_gates and game.explorer_npcs.actors.any(func(n):return is_instance_valid(n.node) and game.model.world_point(point).distance_squared_to(n.get("interaction_point",n.node.global_position))<pow(4.5*game.model.falan_scale,2)):continue
  if game.model.falan_area=="interior":
   var info=Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)
   var bits=Tour.Indoor.walk_mask(game.model.falan_floor,info[0],info[2].hex_decode(),game.model.seed_value)
   var cell=Vector2i(((point-info[1])/3.).round())
   if not Tour.Winter.Recovered.open(bits,info[0],cell):continue
  var ground=game.model.world_point(point,.15)
  if not body_clear(ground):continue
  if game.model.get_meta("falan_links",[]).any(func(link):return point.distance_squared_to(link.at)<4.5*4.5):continue
  if not game.model.terrain.disk_clear(ground/game.model.falan_scale,.65):continue
  if game.model.scenery_obstacles.values().any(func(box):return box.grow(.65).has_point(ground/game.model.falan_scale)):continue
  if not game.army_runtime.native.can_reach_ally(path_start,ground,.55*game.model.falan_scale):continue
  return point
 return Vector2.INF

func player_path_start()->Vector3:
 var player=game.player;var scale_=game.model.falan_scale;var native=game.army_runtime.native
 var start=player.position;start.y=game.model.world_height(start.x,start.z)
 if native.can_reach_ally(start,start,.55*scale_):return start
 # Certify a short physical walk off a navigation boundary after combat.
 var at=Vector2(player.position.x,player.position.z)/scale_
 for ring in range(1,4):
  for direction in 16:
   var point=game.model.world_point(at+Vector2.from_angle(direction*TAU/16.)*ring*.75,.15)
   if not game.model.terrain.disk_clear(point/scale_,.55)or not body_clear(point):continue
   if not native.can_reach_ally(point,point,.55*scale_):continue
   if player.test_move(player.global_transform,point-player.global_position):continue
   return point
 return Vector3.INF

func body_clear(point:Vector3)->bool:
 for child in game.player.get_children():
  if not child is CollisionShape3D:continue
  var query=PhysicsShapeQueryParameters3D.new();query.shape=child.shape;query.collision_mask=game.player.collision_mask;query.exclude=[game.player.get_rid()]
  var pose=game.player.global_transform;pose.origin=point;query.transform=pose*child.transform
  return game.player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
 return false

func invalidate():
 if is_instance_valid(visuals):visuals.queue_free()
 visuals=null

func rebuild_visuals():
 for record in encounters.values():
  if record.scope!=scope() or not record.cleared or not record.get("portal_pending",false):continue
  var station=safe_station(record.at,true)
  if not station.is_finite():station=safe_station(record.at)
  if not station.is_finite():continue
  record.portal=station;record.erase("portal_pending");place_chest(record);invalidate();gates_dirty=true
 if is_instance_valid(visuals):return
 visuals=Node3D.new();visuals.name="ExploreVictoryPortals";game.world.map_features.add_child(visuals)
 for key in encounters:
  var record:Dictionary=encounters[key]
  if record.scope!=scope() or not record.cleared:continue
  if not record.has("portal"):continue
  var host=Node3D.new();host.name="BossReturnPortal";host.set_meta("explore_encounter",key);host.position=game.model.world_point(record.portal)/game.model.falan_scale;host.scale=Vector3.ONE*VICTORY_DIAMOND_SCALE;visuals.add_child(host)
  Tour.build_diamond(host,Vector3.ZERO)
  host.get_child(0).position.y=10.
  var diamond=host.get_child(0);diamond.modulate=HOSPITAL_DIAMOND_COLOR;diamond.set_meta("explore_portal_role","hospital_return")
  for glow in diamond.get_children():
   if glow is OmniLight3D:glow.light_color=Color("45ffa3")
  var label=Label3D.new();label.font=preload("res://scripts/forest/preparation_skin.gd").FONT;label.font_size=30;label.pixel_size=.00065/VICTORY_DIAMOND_SCALE;label.fixed_size=true
  label.text="F · 返回法蘭城\n東醫院外";label.position=Vector3.UP*12.5;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;host.add_child(label)
 for key in rewards.get(scope(),{}):
  if game.exploration_loot.opened_chests.has(key):continue
  var label=Label3D.new();label.font=preload("res://scripts/forest/preparation_skin.gd").FONT;label.font_size=28;label.pixel_size=.00065;label.fixed_size=true
  label.text="F · Boss 武器寶箱";label.position=game.model.world_point(rewards[scope()][key],3.)/game.model.falan_scale
  label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.visibility_range_end=35.;visuals.add_child(label)

func interact()->bool:
 if not enabled() or game.paused or game.transitioning or game.player.hp<=0:return false
 var at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var nearby=gates.filter(func(g):return at.distance_squared_to(g.at)<4.*4. and game._ryo_clear_path(game.player.position+Vector3.UP*2.5*game.model.falan_scale,game.model.world_point(g.at,2.5*game.model.falan_scale)))
 nearby.sort_custom(func(a,b):return at.distance_squared_to(a.at)<at.distance_squared_to(b.at))
 # Preserve the original waiting boss conversation when its host is closer than a bypass gate.
 var waiting=game.habaru_waiting if game.can_talk_habaru()else game.falken_waiting if game.can_talk_falken()else null
 if is_instance_valid(waiting)and (nearby.is_empty()or game.player.position.distance_squared_to(waiting.global_position)<=game.player.position.distance_squared_to(game.model.world_point(nearby[0].at))):return false
 var portals=encounters.values().filter(func(r):return r.scope==scope() and r.has("portal") and r.cleared and at.distance_squared_to(r.portal)<=4.*4.)
 portals.sort_custom(func(a,b):return at.distance_squared_to(a.portal)<at.distance_squared_to(b.portal))
 for record in portals:
  if not nearby.is_empty() and nearby[0].at.distance_squared_to(record.portal)>=4.5*4.5 and at.distance_squared_to(nearby[0].at)<at.distance_squared_to(record.portal):break
  if boss_spots.any(func(s):return (s.has("fights") or s.get("manual_begin",false) or s.get("undersea",false)) and at.distance_squared_to(s.at)<at.distance_squared_to(record.portal) and at.distance_squared_to(s.at)<5.*5.):break
  var npc:Dictionary=game.explorer_npcs.nearest
  if not npc.is_empty() and game.player.position.distance_squared_to(npc.get("interaction_point",npc.node.global_position))<game.player.position.distance_squared_to(game.model.world_point(record.portal)):break
  var target=game.model.world_point(record.portal,2.5*game.model.falan_scale)
  if not game._ryo_clear_path(game.player.position+Vector3.UP*2.5*game.model.falan_scale,target):continue
  var venture:Dictionary=game.get_tree().get_meta("falan_venture",{})
  if not venture.get("falan_areas",{}).has("city"):return false
  portal_menu(record)
  return true
 if nearby.is_empty():
  var overlapping=boss_spots.filter(func(s):return s.has("fights")and at.distance_squared_to(s.at)<5.*5.)
  if overlapping.size()>1:
   var options=[]
   for i in overlapping.size():options.append([str(i),challenge_caption(overlapping,i)])
   options.append(["cancel","離開"])
   var menu_label=Label3D.new()
   game.show_boss_dialogue("選擇挑戰",[{"text":"選擇此處的 Explore 挑戰。","portrait":null,"options":options}],menu_label,game.close_boss_dialogue);menu_label.free()
   game.dialogue.chosen.connect(func(answer:String):
    game.close_boss_dialogue()
    if answer.is_valid_int():challenge(overlapping[int(answer)]))
   return true
  for spot in boss_spots:
   if at.distance_squared_to(spot.at)>5.*5.:continue
   if spot.get("manual_begin",false):return preload("res://scripts/forest/forest_university_region.gd").begin(game,spot.key,-1,true)
   if spot.get("undersea",false):
    var record:Dictionary=encounters.get(scope()+":undersea_slot",{})
    if record.get("cleared",false):record.cleared=false;record.erase("portal");game.model.waves.undersea_source_requested=false;invalidate()
    return game.model.waves.tick_fixed_undersea(game.player.position/game.model.falan_scale)
   if spot.has("fights") and game.model.falan_floor not in [11004,15505,16503,47017]:
    return challenge(spot)
  return false
 var npc:Dictionary=game.explorer_npcs.nearest
 var native_talk=is_instance_valid(waiting)
 var talk=native_talk or not npc.is_empty() and nearby.any(func(g):return str(g.get("actor",""))==str(npc.record.id).trim_prefix("source:"))
 var challenges=boss_spots.filter(func(s):return s.has("fights") and at.distance_squared_to(s.at)<5.*5. and nearby.any(func(g):return g.at.distance_squared_to(s.at)<4.5*4.5) and game._ryo_clear_path(game.player.position+Vector3.UP*2.5*game.model.falan_scale,game.model.world_point(s.at,2.5)))
 if nearby.size()==1 and not talk and challenges.is_empty():enter_gate(nearby[0]);return true
 var choices=[]
 for i in nearby.size():choices.append([str(i),nearby[i].caption])
 if talk:choices.append(["talk","與"+("熊弟"if waiting==game.habaru_waiting else"法爾肯")+"交談"if native_talk else"與"+str(npc.record.name)+"交談"])
 for i in challenges.size():choices.append(["challenge:%d"%i,challenge_caption(challenges,i)])
 choices.append(["cancel","離開"])
 var label=Label3D.new()
 game.show_boss_dialogue("Cross Gate",[{"text":"Explore 通路 · 不會完成任務或領取獎勵。","portrait":null,"options":choices}],label,game.close_boss_dialogue);label.free()
 game.dialogue.chosen.connect(func(answer:String):
  game.close_boss_dialogue()
  if answer=="talk" and talk:
   if native_talk:
    if waiting==game.habaru_waiting:game.show_habaru_dialogue()
    else:game.show_falken_dialogue()
   else:game.explorer_npcs.interact()
  if answer.begins_with("challenge:"):challenge(challenges[int(answer.trim_prefix("challenge:"))])
  if answer.is_valid_int()and int(answer)>=0 and int(answer)<nearby.size():enter_gate(nearby[int(answer)]))
 return true

func portal_at_chest(chest:Dictionary)->bool:
 var at=Vector2(chest.pos.x,chest.pos.z)
 # A co-located reward must not steal the portal menu through ground-height rounding.
 return encounters.values().any(func(r):return r.scope==scope()and r.cleared and r.has("portal")and at.distance_squared_to(r.portal*game.model.falan_scale)<.001*.001)

func interaction_distance_squared()->float:
 var distance=INF
 for record in encounters.values():
  if record.scope==scope()and record.cleared and record.has("portal"):distance=minf(distance,game.player.position.distance_squared_to(game.model.world_point(record.portal,.05)))
 for gate in gates:distance=minf(distance,game.player.position.distance_squared_to(game.model.world_point(gate.at,.05)))
 for spot in boss_spots:
  if spot.has("fights")or spot.get("manual_begin",false)or spot.get("undersea",false):distance=minf(distance,game.player.position.distance_squared_to(game.model.world_point(spot.at,.05)))
 return distance

func challenge_caption(spots:Array,index:int)->String:
 var spot:Dictionary=spots[index]
 return "Explore 挑戰 · "+spot.name+(" · %d"%(index+1)if spots.filter(func(s):return s.name==spot.name).size()>1 else "")

func declaration_identity(value:String)->String:
 var fields=value.split("|",true)
 return fields[9].strip_edges()+":"+fields[1].strip_edges()if fields.size()>9 else value

func source_boss_cleared(actor:String)->bool:
 var key:String=places.get(scope()+":"+actor,"")
 if encounters.get(key,{}).get("cleared",false):return true
 var sources=boss_spots.filter(func(s):return str(s.get("actor",""))==actor or actor in s.get("actors",[]))
 for spot in boss_spots:
  var same_trigger=sources.any(func(s):return is_same(s,spot)or s.at.distance_squared_to(spot.at)<=8.*8. and s.get("fights",[]).any(func(f):return spot.get("fights",[]).any(func(other):return declaration_identity(f)==declaration_identity(other))))
  if same_trigger and encounters.get(scope()+":"+spot.group,{}).get("cleared",false):return true
 return false

func portal_menu(record:Dictionary):
 var choices=[["return","法蘭城東醫院外"]]
 var exits=gates.filter(func(g):return g.at.distance_squared_to(record.portal)<4.5*4.5 and game._ryo_clear_path(game.player.position+Vector3.UP*2.5*game.model.falan_scale,game.model.world_point(g.at,2.5*game.model.falan_scale)))
 for i in exits.size():choices.append(["gate:%d"%i,exits[i].caption])
 var chest=game.exploration_loot.nearest()
 if chest>=0:
  var slot:Dictionary=game.exploration_loot.slots[chest]
  choices.append(["loot","開啟 Boss 武器寶箱"if slot.get("boss",false)else"開啟 精英寶箱"if slot.get("elite",false)else"開啟 食物寶箱"])
 if preload("res://scripts/forest/forest_explore_retries.gd").supported(record.group):choices.append(["retry","再挑戰"])
 var npc:Dictionary=game.explorer_npcs.nearest
 if not npc.is_empty():choices.append(["talk","與"+str(npc.record.name)+"交談"])
 var challenges=boss_spots.filter(func(s):return s.has("fights") and s.at.distance_squared_to(record.portal)<4.5*4.5)
 for i in challenges.size():choices.append(["challenge:%d"%i,challenge_caption(challenges,i)])
 choices.append(["cancel","繼續收集戰利品"])
 var label=Label3D.new()
 game.show_boss_dialogue("回城傳送門",[{"text":"戰鬥已結束。要返回法蘭城東醫院外嗎？","portrait":null,"options":choices}],label,game.close_boss_dialogue);label.free()
 game.dialogue.chosen.connect(func(answer:String):
  game.close_boss_dialogue()
  if answer=="return":
   var venture:Dictionary=game.get_tree().get_meta("falan_venture",{})
   game.transitioning=true
   Tour.travel.call_deferred(game,venture.falan_areas.city,{"arrival":HOSPITAL_LANDING,"yaw":PI*.5,"velocity":Vector3.ZERO,"preserve_checkpoint":true})
  elif answer=="retry":
   var before:Dictionary=record.duplicate();record.cleared=false;record.pending=false;record.erase("portal");invalidate();gates_dirty=true
   if not preload("res://scripts/forest/forest_explore_retries.gd").begin(game,record):
    record.merge(before,true);invalidate();game.toast("此戰鬥暫時無法重新開始")
  elif answer=="talk" and not npc.is_empty():game.explorer_npcs.interact()
  elif answer=="loot":game.exploration_loot.open_nearest()
  elif answer.begins_with("gate:"):enter_gate(exits[int(answer.trim_prefix("gate:"))])
  elif answer.begins_with("challenge:"):challenge(challenges[int(answer.trim_prefix("challenge:"))]))

func challenge(spot:Dictionary)->bool:
 if game.get_tree().has_meta("university_victory")or not preload("res://scripts/forest/forest_university_region.gd").active(game.get_tree(),game.model.falan_floor,game.model.falan_area).is_empty() or encounters.values().any(func(r):return r.scope==scope() and r.get("pending",false)):game.toast("請先完成目前的戰鬥");return true
 if not game._ryo_clear_path(game.player.position+Vector3.UP*2.5*game.model.falan_scale,game.model.world_point(spot.at,2.5)):return false
 var choices=[["source","原始對話"]]
 for i in spot.fights.size():choices.append([str(i),"Explore 挑戰"+(" %d"%(i+1)if spot.fights.size()>1 else "")])
 choices.append(["cancel","離開"])
 var label=Label3D.new()
 game.show_boss_dialogue(spot.name,[{"text":"Explore 挑戰不需要任務物品。獲勝後可使用回城傳送門。","portrait":null,"options":choices}],label,game.close_boss_dialogue);label.free()
 game.dialogue.chosen.connect(func(answer:String):
  game.close_boss_dialogue()
  if answer=="source":
   var record:Dictionary=spot.record
   if not load("res://scripts/forest/forest_east_events.gd").action(game,record.get("quest_action","")):Tour.university_quest(game,record.get("quest_action",""))
  elif answer.is_valid_int()and int(answer)>=0 and int(answer)<spot.fights.size():
   var declaration:String=spot.fights[int(answer)].strip_edges();var args=declaration.trim_prefix("Encount ").trim_prefix("encount ")
   if spot.record.type=="StandEnemy":args=declaration
   var owner=load("res://scripts/forest/forest_sokia_cape.gd")if spot.record.get("battle_owner","")=="sokia_cape"else load("res://scripts/forest/forest_black_prayer_events.gd")if spot.record.get("battle_owner","")=="black_prayer"else load("res://scripts/forest/forest_east_battles.gd")
   owner.begin(game,spot.record,args))
 return true

func enter_gate(gate:Dictionary):
 if gate.get("back",false):
  game.transitioning=true;Tour.travel.call_deferred(game,gate.layout,{"arrival":gate.arrival,"yaw":game.camera_rig.yaw,"velocity":Vector3.ZERO,"preserve_checkpoint":true});return
 var bookmark={"layout":game.get_tree().get_meta("forest_custom_layout").duplicate(true),"arrival":gate.at}
 if preload("res://scripts/forest/forest_explore_routes.gd").travel(game,gate.target,gate.landing):pending_return=bookmark

func pins()->Array:
 var result=[]
 for gate in gates:result.append({"at":gate.at,"label":"◇ "+gate.caption,"color":Color("ffe264")})
 for record in encounters.values():
  if record.scope!=scope() or not record.discovered or record.get("superseded",false):continue
  result.append({"at":record.at,"label":("✓ 已擊敗 · " if record.cleared else "⚔ 未擊敗 · ")+record.name,"color":Color("88d9aa") if record.cleared else Color("f6856b")})
  if record.cleared and record.has("portal"):result.append({"at":record.portal,"label":"◇ 返回法蘭城東醫院外","color":HOSPITAL_DIAMOND_COLOR})
 for key in rewards.get(scope(),{}):
  if not game.exploration_loot.opened_chests.has(key):result.append({"at":rewards[scope()][key],"label":"▣ Boss 武器寶箱","color":Color("f6c575")})
 return result

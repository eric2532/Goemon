extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
const Encounters=preload("res://assets/maps/falan/map_encounter_data.gd")
const Patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Map Encounters/"
var checks=0

func _initialize():
 create_timer(600).timeout.connect(func():printerr("MAP_ENCOUNTERS_TIMEOUT");quit(1))
 run.call_deferred()

func check(ok:bool,message:String):
 checks+=1
 super.check(ok,message)

func check_east_il_road():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 if "--attacks-only" in OS.get_cmdline_user_args():
  await open_room(13001)
  for i in game.model.waves.patrol_posts.size()+1:game.model.waves.tick(12,game.player.position)
  game.army_runtime.import_arrivals()
  check_native_attacks()
  if DisplayServer.get_name()!="headless":
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
   await lineup(true)
  print("MAP_ATTACKS_RESULT checks=",checks," failures=",errors)
  return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
 var data=Patrols.motions()
 check(data.variants.size()==29 and data.timelines.size()==29*8*32,"All reference species fit the existing 29 native skins, with complete directional cues")
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crossgate/falan_frontier/motions.json"))
 for skin in 5:
  check(data.variants[skin]==old.variants[skin],"Preserved original patrol identity and source height "+str(skin))
  for direction in 8:
   check(data.timelines.slice((skin*8+direction)*32,(skin*8+direction)*32+28)==old.timelines.slice((skin*8+direction)*28,(skin*8+direction+1)*28),"Preserved original contact/audio clocks")
 var seen={}
 for area in ["west_lakes","east_coast","north_coast","south_lakes","sokia_coast","sokia_desert","ghana_road","ghana_north_road"]:
  var model=Doc.Model.new();model.reset(42,{},Tour.Regions.layout(area),false)
  model.start_wave()
  for i in model.waves.patrol_posts.size()+1:model.waves.tick(12,Vector3.ZERO)
  check(not model.enemies.is_empty() and model.enemies.size()<=240,"Bounded native patrol population: "+area)
  for row:Dictionary in model.enemies.values():
   var local:Vector3=row.pos/model.falan_scale
   check(model.waves.navigation.move_clear(local,row.footprint*model.waves.patrol_fits[row.skin]),"Actual spawn clears terrain/scenery: "+area)
   check(not Tour.Regions.village_contains(area,Vector2(local.x,local.z)),"Village remains safe: "+area)
   seen[row.skin]=true
  for post:Vector4i in model.waves.patrol_posts:
   var zone:Array=Encounters.ZONES[post.w]
   check(zone[0].has_point(Vector2i(post.x,post.y)) and (int(zone[1])&(1<<post.z))!=0,"Patrol uses a member of its source encounter region")
  var area_skins={}
  for row:Dictionary in model.enemies.values():area_skins[row.skin]=true
  print("MAP_POPULATION ",area," ",model.enemies.size()," skins=",area_skins.keys())
 for area in ["north_coast","sokia_coast","sokia_desert","ghana_road","ghana_north_road"]:
  await open_area(area)
  var waves=game.model.waves
  for i in waves.patrol_posts.size()+1:waves.tick(12,game.player.position)
  game.army_runtime.finish_integration();game.army_runtime.import_arrivals()
  for row:Dictionary in game.model.enemies.values():
   var handle:int=game.army_runtime.handles.get(row.id,0)
   check(handle!=0 and game.army_runtime.unit_state(handle).pose_row==row.skin,"World monster uses its native sprite/combat skin")
  check(game.model.enemies.size()>0,"Live native encounters in "+area)
  var count=game.model.enemies.size()
  waves.tick(12,game.player.position);game.army_runtime.import_arrivals()
  check(game.model.enemies.size()==count,"Repeated population does not duplicate native creatures")
  if DisplayServer.get_name()!="headless":
   var row:Dictionary=game.model.enemies.values()[game.model.enemies.size()/2]
   await shot("../Asset Toolkit/Map Encounters/"+area,row.pos+Vector3(12,15,19),row.pos+Vector3.UP*2,64,true)
 await open_room(13001)
 for i in game.model.waves.patrol_posts.size()+1:game.model.waves.tick(12,game.player.position)
 game.army_runtime.import_arrivals()
 var cave:Dictionary={}
 for row:Dictionary in game.model.enemies.values():cave[row.skin]=true;seen[row.skin]=true
 check(cave.has(14) and cave.has(15),"Great Wind Cave contains red-eye mantises and water spiders")
 check_native_attacks()
 var victim:Dictionary=game.model.enemies.values()[0]
 var slot:int=victim.map_patrol_slot
 game.army_runtime.apply_hit(game.army_runtime.handles[victim.id],{"amount":victim.max_hp*2,"direction":Vector3.FORWARD})
 game.army_runtime.dispatch_events()
 check(get_meta("map_patrol_slain",{}).has(slot),"Great Wind Cave death persists through the shared native lifecycle")
 await open_room(13001)
 for i in game.model.waves.patrol_posts.size()+1:game.model.waves.tick(12,game.player.position)
 check(not game.model.enemies.values().any(func(row):return row.get("map_patrol_slot")==slot),"Returning to Great Wind Cave does not revive a defeated creature")
 for floor_ in [15004,15005,15592,15594]:
  await open_room(floor_)
  var before=game.model.enemies.size()
  game.model.waves.tick(12,game.player.position)
  game.army_runtime.import_arrivals()
  var skins={}
  for row:Dictionary in game.model.enemies.values():
   skins[row.skin]=true
   check(row.has("undersea_slot") and game.army_runtime.handles.has(row.id),"Sea passage uses the existing native lizard lifecycle")
  check(skins.has(1) and skins.has(2),"Sea passage has water dragon lizards and lizard warriors: "+str(floor_))
  check(before==game.model.enemies.size(),"Sea passage population is stable")
 check(seen.size()==29,"All 29 matched species have actual clear spawns across recovered maps; got "+str(seen.keys()))
 if DisplayServer.get_name()!="headless":await lineup()
 print("MAP_ENCOUNTERS_RESULT checks=",checks," failures=",errors)

func check_native_attacks():
 var probe=ClassDB.instantiate("GoemonCrowdRuntime")
 probe.configure(64,2000)
 check(probe.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model)),"All 29 source contact tables configure the existing native owner")
 probe.set_navigation(game.army_runtime.navigation_data(game.model))
 var at:Vector3=game.model.enemies.values()[0].pos
 var target=at
 for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]:
  var candidate=at+direction*1.6
  candidate.y=game.model.world_height(candidate.x,candidate.z)
  if probe.can_reach(at,candidate,.55):target=candidate;break
 check(target!=at,"Native attack fixture has reachable footing")
 var targets:Dictionary=game.army_runtime.external_targets()
 targets.positions[0]=target;targets.targetable[0]=1
 if targets.minimum[0]!=targets.maximum[0]:
  targets.minimum[0]+=target-game.player.position
  targets.maximum[0]+=target-game.player.position
 probe.set_targets(targets)
 var samples=[]
 for skin in 29:
  var handle:int=probe.spawn(skin+1,0,Roles.SLIME,at,3000,.5)
  check(probe.set_pet_skin(handle,skin),"Native attack uses the selected world species")
  probe.set_pose(handle,at,atan2(target.x-at.x,target.z-at.z));probe.set_guard(handle,at,14)
  var hits=[]
  var pressured=false
  for tick in 1200:
   var before=Time.get_ticks_usec()
   probe.step(1.0/60)
   samples.append(Time.get_ticks_usec()-before)
   hits.append_array(probe.take_events().filter(func(event):return event.kind=="external_damage"))
   if hits.size()>=2:break
   if hits.size()==1 and (not pressured or tick%6==0):
    var state:Dictionary=probe.unit_state(handle)
    var front=Vector3(sin(state.yaw),0,cos(state.yaw))
    probe.apply_hit(handle,{"amount":2.0,"direction":front,"joint_attack":true})
    pressured=true
  check(hits.size()>=2 and hits.all(func(hit):return is_equal_approx(hit.amount,30)),"Repeated exact native damage from "+Patrols.NAMES[skin])
  probe.despawn(handle);probe.take_events()
 samples.sort()
 print("MAP_NATIVE_ATTACK_STEP p95_us=",samples[floori(samples.size()*.95)]," max_us=",samples[-1]," samples=",samples.size())
 check_patrol_guard(probe,at,target,targets)

func check_patrol_guard(probe:Object,at:Vector3,target:Vector3,targets:Dictionary):
 var toward:Vector3=(target-at).slide(Vector3.UP).normalized()
 var farther:Vector3=target+toward*5.0
 farther.y=game.model.world_height(farther.x,farther.z)
 for key in ["positions","minimum","maximum"]:targets[key][0]+=farther-target
 targets.player_attack_facing=-toward;targets.player_attack_reach=12.0
 var guarded=false
 for attempt in 24:
  targets.player_attack_serial=attempt+1
  probe.set_targets(targets)
  var handle:int=probe.spawn(attempt+40,0,Roles.SLIME,at,3000,.5)
  probe.set_pet_skin(handle,14);probe.set_pose(handle,at,atan2(-toward.x,-toward.z));probe.set_guard(handle,at,14)
  for tick in 16:
   probe.step(1.0/60)
   if probe.unit_state(handle).blocking:
    var hit:Dictionary=probe.apply_hit(handle,{"amount":40.0,"direction":-toward,"joint_attack":true})
    check(is_equal_approx(hit.hp,2990),"An exploration patrol takes chip damage during a frontal guard")
    guarded=true;break
  probe.despawn(handle);probe.take_events()
  if guarded:break
 check(guarded,"Great Wind Cave uses the native guard with patrol targeting enabled")

func open_room(id:int):
 var at:Vector2=Tour.Indoor.floor_info(id)[1]+Vector2(15,15)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":at,"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame

func lineup(guard:bool=false):
 var study=Node3D.new();game.world.add_child(study)
 study.position=Vector3(2500,0,2500)*game.model.falan_scale
 study.scale=Vector3.ONE*game.model.falan_scale
 var batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new()
 batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_custom_data=true
 batch.multimesh.mesh=Patrols.make_mesh();study.add_child(batch)
 batch.set_instance_shader_parameter("use_world_pet_sizes",true)
 batch.multimesh.instance_count=29
 batch.custom_aabb=AABB(Vector3(-50,-5,-50),Vector3(100,30,100))
 for skin in 29:
  var at=Vector3((skin%6-2.5)*8,0,(skin/6-2)*8)
  batch.multimesh.set_instance_transform(skin,Transform3D(Basis.IDENTITY,at))
  batch.multimesh.set_instance_custom_data(skin,Color(skin,6 if guard else 0,.2,0))
  var label=Label3D.new();label.text=Patrols.NAMES[skin];label.font=preload("res://scripts/forest/preparation_skin.gd").FONT
  label.font_size=36;label.pixel_size=.025;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=at+Vector3(0,-.4,0);study.add_child(label)
 var capture_name="guard-lineup" if guard else "species-lineup"
 await shot("../Asset Toolkit/Map Encounters/"+capture_name,study.to_global(Vector3(0,48,48)),study.to_global(Vector3(0,1,0)),58)
 study.queue_free()

extends "res://tests/forest-shrine/original_maps_test.gd"
const Clock=preload("res://scripts/forest/forest_explorer_clock.gd")
const EVIDENCE="res://build/Other Files/Asset Toolkit/Tina Recovery/"

func run():
 var clock=Clock.new()
 for bad in [null,"midnight",NAN,INF,-1.0,24.0,true]:
  clock.load_hour(bad)
  check(clock.hour==9.0,"Invalid saved clock defaults safely")
 for values in [[5.99,true],[6.0,false],[17.99,false],[18.0,true],[23.99,true]]:
  clock.load_hour(values[0]);check(clock.night()==values[1],"Day/night boundary "+str(values[0]))
 check(Clock.CYCLE_SECONDS==1440,"A complete cycle takes 24 minutes")
 check(Original.outdoor(4201),"Night Tina is an outdoor area")
 for id in [51005,4201,4206,4208,4209,4210,4211,4212,4213,4214,4220,4221,4222,4230,4232,4299]:
  var row=Original.state(id)
  check(row.raw==Original.Art.raw_map(Original.path_for(id)),"Tina keeps full source bounds and all source planes "+str(id))
  var known=true
  for i in row.size.x*row.size.y:
   var serial=row.raw.decode_u16(20+(row.size.x*row.size.y+i)*2)
   if serial>=1000:known=known and Original.Forms.kind(serial,false,Original.Art.data().graphics[str(serial)])!="prop"
  check(known,"Tina scenery uses identified solid families "+str(id))
  for link in Original.links(id):
   var cell=Vector2i(((link.at-row.origin)/3).round())
   check(Original.open(row.bits,row.size,cell),"Tina entrance keeps original open approach "+str(id))
 for gate in [Vector2i(569,274),Vector2i(570,274),Vector2i(571,274),Vector2i(584,317),Vector2i(585,317)]:
  check(Original.links(Original.SHALENA_SOUTH).any(func(l):return l.at==Original.source_point(Original.SHALENA_SOUTH,gate)),"Tina approach retains native road gate "+str(gate))
 check(Original.links(51005).any(func(l):return l.floor==4206),"Recovered food shop can be entered from the village")
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-tina-day-night-test.cfg"
 root.add_child(game);current_scene=game
 root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false
 game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true
 game.set_process(false)
 clock=game.explorer_clock
 clock.load_hour(12.0)
 var before=clock.hour
 clock.tick(game,60.0)
 check(is_equal_approx(clock.hour,before+1.0),"One real minute advances one game hour")
 game.paused=true;before=clock.hour;clock.tick(game,100)
 check(clock.hour==before,"Pausing freezes the world clock")
 game.paused=false
 clock.load_hour(23.9);clock.tick(game,12)
 check(is_equal_approx(clock.hour,.1),"Midnight wraps without resetting the cycle")
 clock.load_hour(12.0)
 await visit(51005,Vector2i(43,55))
 var env=game.world.get_world_3d().environment
 var day_brightness=env.adjustment_brightness
 var phase_root=game.world.map_features
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 300:
  clock.load_hour(8.0+i/30.0);clock.update_lighting()
 check(game.world.map_features==phase_root and get_node_count()==nodes,"Ordinary daylight updates reuse existing scenery and nodes")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Ordinary daylight updates allocate no new resources")
 var source_at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 clock.load_hour(17.9999);clock.tick(game,.21)
 for i in 8:await physics_frame
 check(game.model.falan_floor==4201,"Dusk changes the active village to its native night layout")
 check((Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale).distance_to(source_at)<.1,"A clear dusk arrival preserves the player's exact horizontal position")
 check(game.model.falan_area=="interior" and game.get_tree().has_meta("falan_venture"),"Day/night remains inside the existing Explorer adventure")
 check(game.world.get_world_3d().environment.adjustment_brightness<day_brightness,"Night also darkens native emissive artwork")
 if DisplayServer.get_name()!="headless":await capture_named("tina-night")
 clock.load_hour(0);clock.update_lighting()
 if DisplayServer.get_name()!="headless":await capture_named("tina-midnight")
 check(game.model.get_meta("falan_links",[]).any(func(l):return l.get("floor")==4230),"Night uses the original night-pub entrance")
 await cross(4230)
 clock.load_hour(5.9999);clock.tick(game,.21)
 for i in 8:await physics_frame
 check(game.model.falan_floor==4208,"Dawn restores the daytime tavern")
 await cross(51005)
 check(game.model.falan_floor==51005,"Tavern returns into the correct daytime village")
 await cross(4210);await cross(4211);await cross(4210);await cross(51005)
 await cross(51007);await cross(4213);await cross(4214);await cross(4299);await cross(4214);await cross(4213);await cross(51007);await cross(51005)
 await cross(4206);await cross(51005)
 await cross(Original.SHALENA_SOUTH)
 var hour_before=clock.hour
 await cross(51005)
 check(clock.hour==hour_before,"Road travel preserves the shared world time")
 var original_position=game.player.position
 var original_hp=game.player.hp
 clock.load_hour(12);clock.update_lighting()
 var environment_before=game.world.get_world_3d().environment
 var ambient_before=environment_before.ambient_light_energy
 for i in 3:game.world.apply_map_environment()
 check(is_equal_approx(environment_before.ambient_light_energy,ambient_before),"Reapplying scenery lighting does not compound day/night dimming")
 check(game.player.position==original_position and game.player.hp==original_hp,"Lighting preserves player position and health")
 for sample in [["city",0],["east_gate",0],["south_lakes",0],["sokia_desert",0],["interior",51011],["interior",51012]]:
  var layout=Original.layout(sample[1]) if sample[0]=="interior" else Tour.outdoor_layout(game.get_tree().get_meta("falan_venture"),sample[0])
  var arrival=Tour.Indoor.safe_point(sample[1],Vector2.ZERO) if sample[0]=="interior" else Vector2.ZERO
  clock.load_hour(12);Tour.travel(game,layout,{"arrival":arrival,"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  check(not clock.lighting.is_empty(),"Shared daylight covers Explorer area "+str(sample))
  var features=game.world.map_features;env=game.world.get_world_3d().environment
  clock.load_hour(0);clock.update_lighting()
  check(env.adjustment_enabled and env.adjustment_brightness<.6,"The whole outdoor area receives night lighting "+str(sample))
  check(game.world.map_features==features,"Outdoor night does not rebuild terrain "+str(sample))
  if DisplayServer.get_name()!="headless" and sample[0] in ["city","east_gate"]:await capture_named(sample[0]+"-night")
 await visit(4210,Vector2i(8,9))
 check(clock.lighting.is_empty(),"Indoor fixtures keep their authored lighting at night")
 await visit(15000,Vector2i(22,32))
 check(clock.lighting.is_empty(),"Caves keep their authored lighting at night")
 clock.load_hour(19.5);check(game.save_settings()==OK,"World time saves with existing preferences")
 clock.load_hour(9);game.load_settings()
 check(is_equal_approx(clock.hour,19.5),"World time survives settings reload")
 var arena=Tour.Document.new();arena.load_wind_meadow()
 Tour.travel(game,arena.data,{"arrival":Vector2.ZERO,"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 check(clock.lighting.is_empty(),"Arena lighting is restored after leaving Explorer")
 finish()

func visit(id:int,cell:Vector2i):
 Tour.travel(game,Original.layout(id),{"arrival":Tour.Indoor.safe_point(id,Original.source_point(id,cell)),"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 check(game.model.falan_floor==game.explorer_clock.phase_floor(id),"Explorer enters the correct source phase "+str(id))
 if Original.source_id(id) in [4200,4201]:
  check(game.world.map_features.get_meta("recovered_source_map",0)==Original.source_id(game.model.falan_floor),"Explorer renders the current native village")
 if DisplayServer.get_name()!="headless" and Original.source_id(id)==4200:await capture_named("tina-day")

func cross(target:int)->bool:
 if Original.source_id(game.model.falan_floor) in [4200,4201]:
  var entrances=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("floor")==target)
  if not entrances.is_empty():check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(entrances[0].at,.15),.5),"Native movement reaches the village entrance "+str(target))
 return await super.cross(target)

func capture_named(name_:String):
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
 game.camera_rig.reset_follow()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(EVIDENCE+name_+".png")

extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dodge Counter/"
const DT=1.0/60
var army
var step_times:Array=[]

func advance(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  army.integration_tick(DT);army.flush_presentation()
  step_times.append(Time.get_ticks_usec()-start)

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func visit(floor_:int):
 Tour.travel(game,Tour.Indoor.layout(floor_),{"arrival":Vector2.ZERO,"yaw":0.0})
 game.set_physics_process(false);game.set_process(false);game.player.set_physics_process(false)
 army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 game.paused=false;game.habaru_dialogue_seen=true
 var waves=game.model.waves
 match floor_:
  11004:waves.tick_habaru(Vector3.ZERO)
  11001:waves.tick_venoa_bears(Tour.Regions.Sites.VENOA_BEARS[floor_])
  15003:waves.tick_undersea(Vector3(24,0,12))
  15505:waves.tick_zombie_cave(Vector3.ZERO,Tour.Regions.Sites.ZOMBIE_FORMATIONS[floor_]+game.model.Dungeons.ZOMBIE_PATROLS)
  16503:
   var at:Vector2=Tour.Regions.Sites.CAPTAIN_FORMATION[0][0];waves.tick_captain(Vector3(at.x,0,at.y))
  16508:waves.tick_ruby(Vector3(-3,0,-42))
  47017:waves.tick_grave(0,Vector3(3,0,-15))
 army.import_arrivals();army.sync_compatibility()

func run():
 create_timer(300).timeout.connect(func():printerr("BOSS_REACTIONS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 set_meta("forest_custom_layout",Tour.Indoor.layout(11004))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(5)
 army=game.army_runtime;army.record_events=true
 var p=game.player;p.select_character(34);p.set_auto_attack(false);game.tuning.invincible=true
 for node in [game,p,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 game.settings.forest_pet_loadout=[];game.music.stop()
 for floor_ in [11004,11001,15003,15505,16503,16508,47017]:
  visit(floor_)
  var bosses=game.model.enemies.values().filter(func(row):return row.get("boss",false))
  check(not bosses.is_empty(),"Floor %d marks its actual dungeon boss"%floor_)
  for row in game.model.enemies.values():
   var handle:int=army.handles[row.id]
   var result:Dictionary=army.native.unit_state(handle)
   # Native state exposes the authoritative setup for this check, not a second stat owner.
   var expected_counter=.75 if row.get("boss",false) else .20 if row.get("patrol_radius",0.0)>0 else 0.0
   check(result.dodge_chance==(.05 if row.get("boss",false) else 0.0) and result.counter_chance==expected_counter,"Floor %d skin %d: bosses retain reactions; ordinary patrols counter without dodge"%[floor_,row.skin])
  if floor_!=16503:continue
  var boss:Dictionary=bosses[0];var handle:int=army.handles[boss.id]
  for row in game.model.enemies.values().duplicate():
   if row.id!=boss.id:army.despawn(army.handles[row.id]);game.model.enemies.erase(row.id)
  var home:Vector3=boss.pos
  p.position=home+Vector3.BACK*2;p.facing=Vector3.FORWARD;p.hp=p.max_hp
  game.model.update_vision(home)
  game.camera_rig.camera.global_position=home+Vector3(-6,5,10);game.camera_rig.camera.look_at(home+Vector3.UP*1.8)
  check(army.native.set_boss_reactions(handle,1,0),"Force a deterministic boss dodge in the fixture")
  var before:float=army.unit_state(handle).hp
  var accepted=army.apply_hit(handle,{"amount":1.0,"direction":Vector3.FORWARD}).accepted
  advance(13)
  var snapshot:Dictionary=army.native.snapshot();var index:int=snapshot.logical_ids.find(boss.id)
  check(not accepted and army.unit_state(handle).hp==before and snapshot.dodge_offsets[index].length()>.1,"Boss dodge avoids HP loss and publishes a visible retreat offset")
  var native_buffers:Dictionary=army.native.instance_buffers(snapshot,game.crowd.army.native_profiles)
  check(native_buffers.valid,"The existing native batcher accepts the displaced boss")
  await picture("boss-dodge")
  advance(27);snapshot=army.native.snapshot();index=snapshot.logical_ids.find(boss.id)
  check(snapshot.dodge_offsets[index].is_zero_approx(),"Boss returns home after the out-and-back reaction")
  army.native.set_boss_reactions(handle,0,1)
  var kit_data=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
  var base_damage:float=kit_data.soldier_profiles[kit_data.soldier_kinds.find(boss.variant)*6+2]
  army.apply_hit(handle,{"amount":1.0,"direction":Vector3.FORWARD});army.event_log.clear()
  var counter_seen=false
  for i in 180:
   advance(1)
   if army.unit_state(handle).counter_active:
    counter_seen=true
    if army.unit_state(handle).action_time>.15:break
  check(counter_seen,"A successful roll waits through hit recovery and starts a normal counter animation")
  await picture("boss-counter-windup")
  advance(180)
  var counters=army.event_log.filter(func(event):return event.kind=="external_damage" and event.source_id==boss.id and event.action_index==718)
  check(counters.size()==1,"One roll produces exactly one native retaliation contact")
  check(counters.is_empty() or counters[0].amount==game.model.enemies[boss.id].damage_scale*base_damage,"Boss counter uses normal damage without a special multiplier")
  game.tuning.invincible=false;p.invuln=0;p.hp=p.max_hp
  game.update_character_tuning(34,"dodge_chance",100);game.update_character_tuning(34,"counter_chance",100)
  p.active_ability.clear_shin_counter();p.model.clear_kagerou_dodge()
  p.take_hit_from(1,Vector3.FORWARD,false,boss.id,true)
  check(p.hp==p.max_hp and p.active_ability.shin_counter.is_empty(),"A boss counter can be dodged without creating a counter loop")
  game.tuning.invincible=true
 step_times.sort()
 print("BOSS_REACTIONS_DESKTOP_RESULT checks=",checks," failures=",failures," step_p95_us=",step_times[int(step_times.size()*.95)]," max_us=",step_times.back())
 game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

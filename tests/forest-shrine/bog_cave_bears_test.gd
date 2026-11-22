extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Roster=preload("res://scripts/rogue_roster.gd")
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Bog/Cave Bears/"
const DT=1.0/60
var army
var timings:Array[int]=[]

func press_three():
 var event=InputEventKey.new();event.physical_keycode=KEY_3;event.pressed=true
 game.player._unhandled_input(event)
 event.pressed=false;game.player._input(event)

func bears()->Array:
 var result=[]
 for id in army.handles:
  var row:Dictionary=army.unit_state(army.handles[id])
  if row.get("kind")==Roles.CAVE_BEAR:result.append(row)
 return result

func advance(ticks:int):
 for i in ticks:
  var started=Time.get_ticks_usec()
  army.integration_tick(DT)
  timings.append(Time.get_ticks_usec()-started)
  game.crowd.army.presentation.tick(DT)
 army.flush_presentation()

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();army.flush_presentation()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)

func rendered_play():
 if DisplayServer.get_name()=="headless":return
 game.model.team_progression.cards_enabled=false
 game.set_process(true);game.set_physics_process(true);army.set_process(true)
 var frame_times:Array[int]=[]
 var previous=Time.get_ticks_usec()
 for i in 180:
  await process_frame
  var now=Time.get_ticks_usec();frame_times.append(now-previous);previous=now
  if i==30 or i==90:game.player.tick_mana(20);press_three()
 game.set_physics_process(false);game.set_process(false);army.set_process(false)
 army.finish_integration()
 check(bears().size()==15,"Live rendered gameplay accepts two more five-bear casts")
 frame_times.sort()
 print("BOG_BEARS_RENDER frame_us_p95=%d max=%d samples=%d focused=%s"%[frame_times[171],frame_times[-1],frame_times.size(),root.has_focus()])
 await capture("Live repeated summons")

func verify_pack_cleanup():
 army.clear();advance(1)
 game.player.position=Vector3(-120,0,125)
 game.player.position.y=game.model.surface_height(-120,125)
 game.player.velocity=Vector3.ZERO
 game.player.tick_mana(20)
 press_three();advance(120)
 var pack=bears()
 var point:Vector3=game.player.position+Vector3(0,0,-10)
 point.y=game.model.surface_height(point.x,point.z)
 for i in pack.size():
  var post=point+Vector3((i-2)*3.5,0,3)
  post.y=game.model.surface_height(post.x,post.z)
  army.native.set_pose(army.handles[pack[i].logical_id],post,0)
 var target:int=army.spawn(93000,0,12,point,1000000,.7)
 advance(90)
 check(bears().size()==5 and bears().all(func(row):return row.target_id==93000),"All five bears engage the cleanup fixture")
 game.player.position.x+=45
 game.player.position.y=game.model.surface_height(game.player.position.x,game.player.position.z)
 advance(1)
 check(bears().all(func(row):return row.target_id==93000 and row.position.distance_to(game.player.position)>18),"All five bears keep fighting after the player leaves their group")
 var nodes=game.crowd.army.presentation.get_child_count()
 var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 var cleanup_times:Array[int]=[]
 for cycle in 3:
  var next_id=93001+cycle
  var next:int=army.spawn(next_id,0,12,point+Vector3(2,0,0),1000000,.7)
  army.apply_hit(target,{"amount":1000000.0})
  var start=Time.get_ticks_usec();advance(1);cleanup_times.append(Time.get_ticks_usec()-start)
  check(bears().all(func(row):return row.target_id==next_id),"All five bears immediately choose the next nearby enemy after a kill, cycle %d"%cycle)
  for tick in 90:
   advance(1)
   if DisplayServer.get_name()!="headless" and tick%3==0:await frames(1)
  check(army.unit_state(next).hp<1000000,"The pack continues dealing real damage with the player far away, cycle %d"%cycle)
  target=next
 game.camera_rig.camera.global_position=point+Vector3(18,26,30)
 game.camera_rig.camera.look_at(point)
 await capture("Clearing nearby enemies with player away")
 check(game.crowd.army.presentation.get_child_count()==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Repeated pack retargeting reuses prepared nodes and resources")
 var before=bears().map(func(row):return row.position)
 var max_step=0.0
 army.apply_hit(target,{"amount":1000000.0})
 for tick in 360:
  advance(1)
  var rows=bears()
  for i in rows.size():
   max_step=maxf(max_step,rows[i].position.distance_to(before[i]));before[i]=rows[i].position
  if tick==65:
   check(rows.all(func(row):return row.target_id==0 and row.velocity.length()>5),"All five bears are running midway through the automatic return")
   if DisplayServer.get_name()!="headless":
    var camera=game.camera_rig.camera
    camera.global_position=point+Vector3(22,28,34);camera.look_at(point+Vector3(19,0,5))
    game.crowd.present_army(army.render_snapshot(),[])
    await capture("Running back after the last enemy")
 check(max_step<.75,"Automatic return moves the bear pack in bounded steps")
 check(bears().all(func(row):return row.target_id==0 and row.position.distance_to(game.player.position)<18),"The pack returns only after the local enemies are gone")
 print("BEAR_CLEANUP_STEP_US ",cleanup_times)

func verify_pack_spread():
 game.model.waves.crossgate_pet_test=true
 game.crowd.army.meshes[Roles.SLIME]=preload("res://scripts/forest/crowd/slime_sprites.gd").make_mesh()
 army.refresh_kits()
 var point:Vector3=game.player.position+Vector3(0,0,-10)
 point.y=game.model.surface_height(point.x,point.z)
 var pack=bears()
 for i in pack.size():
  var post=point+Vector3((i-2)*3.5,0,3)
  post.y=game.model.surface_height(post.x,post.z)
  army.native.set_pose(army.handles[pack[i].logical_id],post,0)
 var previous=[army.spawn(94000,0,Roles.SLIME,point,1000000,Roles.SLIME_RADIUS)]
 army.apply_hit(previous[0],{"element":"stun","status_seconds":60.0,"provoke":false})
 advance(60)
 check(bears().all(func(row):return row.target_id==94000),"Scattering still lets all bears share a lone enemy")
 var nodes=game.crowd.army.presentation.get_child_count()
 var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for cycle in 3:
  var replacements=[]
  for i in 5:
   var post=point+Vector3((i-2)*6,0,-6)
   post.y=game.model.surface_height(post.x,post.z)
   var handle:int=army.spawn(94100+cycle*5+i,0,Roles.SLIME,post,1000000,Roles.SLIME_RADIUS)
   army.apply_hit(handle,{"element":"stun","status_seconds":60.0,"provoke":false})
   replacements.append(handle)
  for handle in previous:army.apply_hit(handle,{"amount":1000000.0})
  advance(1)
  var chosen={}
  for row in bears():chosen[row.target_id]=true
  check(not chosen.has(0) and chosen.size()>=3,"Five bears immediately spread across nearby replacements, cycle %d"%cycle)
  advance(150)
  var damaged=replacements.filter(func(h):return army.unit_state(h).hp<1000000)
  check(damaged.size()>=3,"Spread-out bears land real attacks on different enemies, cycle %d"%cycle)
  previous=replacements
 game.camera_rig.camera.global_position=point+Vector3(22,30,36)
 game.camera_rig.camera.look_at(point)
 await capture("Scattered replacement targets")
 check(game.crowd.army.presentation.get_child_count()==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Repeated scattered targeting retains prepared nodes and resources")
 for handle in previous:army.apply_hit(handle,{"amount":1000000.0})
 advance(180)

func native_checks():
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new()
 runtime.configure(null)
 var data=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model)
 runtime.configure_kits(data)
 for hz in [20,30,60]:
  runtime.clear();runtime.set_navigation(hz,{"width":0})
  var pet:int=runtime.spawn(-1,1,Roles.CAVE_BEAR,Vector3(0,0,6),150,1.1)
  check(runtime.native.set_pet_skin(pet,Habaru.VENOA_BEAR_SKIN) and not runtime.native.set_pet_skin(pet,5),"%d Hz: prepared cave-bear skin is validated"%hz)
  runtime.native.set_guard(pet,Vector3(0,0,6),18)
  var foe:int=runtime.spawn(1,0,12,Vector3(0,0,-4),100000,.7)
  var player={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3.ZERO]),"hp":PackedFloat32Array([1000]),"targetable":PackedByteArray([0]),"hound_order":2}
  runtime.native.set_targets(player)
  for i in hz/4:runtime.step(1.0/hz,{})
  check(runtime.unit_state(pet).velocity.length()>10,"%d Hz: native pursuit uses the fast movement profile"%hz)
  for i in hz*4:runtime.step(1.0/hz,{})
  var hits=runtime.take_events().filter(func(e):return e.kind=="damage" and e.target_id==1)
  check(not hits.is_empty() and hits.all(func(e):return e.amount==50),"%d Hz: guard automatically attacks through H hold, exactly 50 per contact"%hz)
  var hp:float=runtime.unit_state(pet).hp
  runtime.apply_hit(pet,{"amount":10.0})
  check(hp==150 and runtime.unit_state(pet).hp==140,"%d Hz: independent 150 HP takes ordinary native damage"%hz)
  var upgraded:Dictionary=data.duplicate(true)
  upgraded.hound_hp=195
  runtime.configure_kits(upgraded)
  check(runtime.unit_state(pet).hp==140 and runtime.unit_state(pet).max_hp==150,"%d Hz: hound health upgrades preserve bear health and wounds"%hz)
  player.positions[0]=Vector3(45,0,0);player.hound_player_speed=18;player.hound_order=1
  runtime.native.set_targets(player)
  for i in hz*4:runtime.step(1.0/hz,{})
  var row:Dictionary=runtime.unit_state(pet)
  check(row.target_id==1 and row.position.distance_to(player.positions[0])>18,"%d Hz: bears keep fighting locally after the player moves away"%hz)
  var next:int=runtime.spawn(2,0,12,row.position+Vector3(2,0,0),100000,.7)
  runtime.apply_hit(foe,{"amount":100000.0});runtime.step(1.0/hz,{})
  check(runtime.unit_state(pet).target_id==2,"%d Hz: bears find their next nearby enemy outside the player's radius"%hz)
  for i in hz*2:runtime.step(1.0/hz,{})
  check(runtime.unit_state(next).hp<100000,"%d Hz: bears damage the next enemy while the player remains away"%hz)
  runtime.apply_hit(next,{"amount":100000.0})
  for i in hz*4:runtime.step(1.0/hz,{})
  check(runtime.unit_state(pet).target_id==0 and runtime.unit_state(pet).position.distance_to(player.positions[0])<18,"%d Hz: bears return after their own nearby enemies are cleared"%hz)
  var gap:float=runtime.unit_state(pet).position.distance_to(player.positions[0])
  check(gap>=7.8 and gap<=17,"%d Hz: resting guards keep a wider ring around Bog"%hz)
  for i in hz*2:
   player.positions[0].z+=6.0/hz;player.hound_player_speed=6
   runtime.native.set_targets(player);runtime.step(1.0/hz,{})
  player.hound_player_speed=0;runtime.native.set_targets(player)
  for i in hz*3:runtime.step(1.0/hz,{})
  gap=runtime.unit_state(pet).position.distance_to(player.positions[0])
  check(gap>=7.8 and gap<=18,"%d Hz: guards follow movement and spread out again after stopping"%hz)
  var death=runtime.apply_hit(pet,{"amount":150.0})
  check(death.dead and not runtime.valid(pet),"%d Hz: lethal damage retires the native summon"%hz)
 runtime.free()

func run():
 create_timer(120).timeout.connect(func():printerr("BOG_BEARS_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 army=game.army_runtime
 army.clear();army.refresh_kits()
 game.player.select_character(Roster.BOG_ID)
 game.player.spell_loadout.equip(Roster.BOG_ID,"sky_strike",game.player.spell_loadout.Catalog.BEARS)
 game.player.position=Vector3(-150,0,127)
 game.player.position.y=game.world.height_at(-150,127)+.05
 game.player.velocity=Vector3.ZERO;game.player.smoke_mode=true
 game.model.update_vision(game.player.position)
 game.camera_rig.camera.global_position=game.player.position+Vector3(22,28,32)
 game.camera_rig.camera.look_at(game.player.position)
 check(game.player.spell_loadout.numbered_slots[2][0]=="召喚穴熊" and str(game.player.spell_loadout.numbered_slots[2][1])=="sky_strike","Bog's equipped third slot names the summon")
 check(Roles.stats(Roles.CAVE_BEAR).speed==12,"Bears run at 12 m/s before catch-up")
 native_checks()
 game.forest_ui.sync()
 var spell_icon:TextureRect=game.forest_ui.helper_portraits[2]
 check(spell_icon.visible and spell_icon.material==null and spell_icon.texture==game.player.spell_loadout.Catalog.KAZI_ICONS[game.player.spell_loadout.Catalog.BEARS] and spell_icon.texture.resource_path.ends_with("/skills/summon-bears.png"),"Bog's key 3 shares the catalog's original 穴熊 sprite icon")
 advance(1)
 press_three()
 check(army.pending_cave_bears.size()==5 and game.player.mana==10,"Physical key 3 pays 40 mana and queues exactly five")
 advance(120)
 check(bears().size()==5 and army.pending_cave_bears.is_empty(),"All five arrive on actual arena ground")
 check(bears().all(func(row):return row.hp==150 and row.max_hp==150 and row.mana==50 and row.max_mana==50 and row.pose_row==Habaru.VENOA_BEAR_SKIN),"Each summon has 150 health, 50 mana and recovered 穴熊 appearance")
 check(bears().all(func(row):return Vector2(row.position.x-game.player.position.x,row.position.z-game.player.position.z).length()>=8),"All five summoned bears leave more room around Bog")
 await capture("Five guards")
 press_three()
 check(army.pending_cave_bears.is_empty() and bears().size()==5,"Insufficient mana leaves the first pack in place")
 game.player.tick_mana(15);press_three();advance(120)
 check(bears().size()==10 and army.pending_cave_bears.is_empty(),"The next affordable cast adds five more without replacing the pack")
 var nodes=game.crowd.army.presentation.get_child_count()
 var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for repetition in 3:
  for row in bears():army.apply_hit(army.handles[row.logical_id],{"amount":150.0})
  advance(120)
  check(bears().is_empty(),"Dead bears retire without stale handles, cycle %d"%repetition)
  game.player.tick_mana(20);press_three();advance(120)
  check(bears().size()==5 and bears().all(func(row):return row.hp==150 and row.mana==50),"Later casts create five fresh guards, cycle %d"%repetition)
 check(game.crowd.army.presentation.get_child_count()==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources,"Repeated deaths and summons reuse prepared presentation and resources")
 var guard=bears()[0]
 army.record_events=true;army.event_log.clear()
 var target:Dictionary=game.model.waves.spawn_enemy(0,guard.position+Vector3(0,0,-6))
 advance(300)
 check(army.event_log.any(func(e):return e.kind=="damage" and e.target_id==target.id and e.source_id<=army.CAVE_BEAR_ID and e.amount==50),"Five simultaneous guards land requested damage against an actual arena enemy")
 await capture("Guard pack")
 game.player.select_character(Roster.SHIN_ID)
 game.forest_ui.sync()
 check(not spell_icon.visible,"Switching to Shin clears Bog's bear icon from key 3")
 var count_before=army.cave_bear_serial
 press_three()
 check(army.cave_bear_serial==count_before and bears().size()==5,"Switching characters preserves living guards without giving Shin the spell")
 game.player.select_character(Roster.BOG_ID)
 game.paused=true;press_three();game.paused=false
 check(army.cave_bear_serial==count_before,"Pause blocks new summons")
 await verify_pack_cleanup()
 await verify_pack_spread()
 await rendered_play()
 army.clear()
 check(army.pending_cave_bears.is_empty() and army.cave_bear_serial==0 and bears().is_empty(),"Run reset clears living and queued summons")
 timings.sort()
 print("BOG_BEARS_PROFILE integration_us_p95=%d max=%d samples=%d"%[timings[int(timings.size()*.95)],timings[-1],timings.size()])
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("BOG_CAVE_BEARS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

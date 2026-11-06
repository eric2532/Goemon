extends SceneTree
## Native combat, original audio, saved layouts and a rendered repeated-volley check.
class Battle extends "res://scripts/forest/forest_game.gd":
 func _sync_camera_mouse():Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
const OUT="res://build/Other Files/Asset Toolkit/Human Cannon Tower/"
const Document=preload("res://scripts/forest/forest_map_document.gd")
var game
var checks=0
var failures=0
var samples=[]
var intervals=[]
var cfg="user://human-cannon-test-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(180).timeout.connect(func():printerr("CANNON_TEST_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func frames(n=3):
 for i in n:await process_frame
func photo(name_:String):
 if DisplayServer.get_name()=="headless":return
 await frames();await RenderingServer.frame_post_draw
 var path=OUT+("large-" if "--large" in OS.get_cmdline_user_args() else "")+name_+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"Capture "+name_)
func pcm_hash(bytes:PackedByteArray)->String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func native_enemy(at:Vector3):
 var row=game.model.waves.spawn_enemy(0,at);row.hp=1000;row.max_hp=1000
 game.army_runtime.import_arrivals();return game.actors[row.id]
func volley(point:Vector3):
 var m=game.model;var view=game.tower_arrows
 for i in 16:
  var id=900000+i;var from=point+Vector3((i%4-1.5)*3,15,(i/4-1.5)*3)
  m.workforce.arrows[id]={"id":id,"from":from,"pos":from,"target":-1,"age":0.0,"cannon":true,"to":point,"duration":.6,"damage":0.0}
  view.audio.last_events.clear();view.launch({"id":id,"from":from,"to":point,"cannon":true})
 for i in 100:
  var start=Time.get_ticks_usec()
  m.workforce.tick_arrows(1.0/60)
  for event in m.events:
   if event.kind=="arrow_impact":view.impact(event)
  m.events.clear();view.sync(1.0/60)
  samples.append((Time.get_ticks_usec()-start)/1000.0)
  if DisplayServer.get_name()!="headless":
   await process_frame;intervals.append((Time.get_ticks_usec()-start)/1000.0)
  elif i%15==0:await process_frame
 view.clear();await frames()
 check(m.workforce.arrows.is_empty() and view.visuals.is_empty() and view.bursts.is_empty(),"Volley releases every shell and impact")
func run():
 root.size=Vector2i(1280,800);root.title="Goemon · Human Cannon Tower"
 var doc=Document.new(false)
 check((doc.load_wind_meadow_large() if "--large" in OS.get_cmdline_user_args() else doc.load_wind_meadow()).is_empty(),"Load bundled Wind Meadow")
 set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true);set_meta("forest_fighter",1)
 game=Battle.new();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(8)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var m=game.model;var workforce=m.workforce;var view=game.tower_arrows
 m.gold=10000
 check(game.forest_ui.build_buttons.has("tower") and game.forest_ui.build_buttons.has("cannon_tower"),"Both Human tower choices are available")
 game.forest_ui.open_build_menu()
 var key=InputEventKey.new();key.physical_keycode=KEY_5;key.pressed=true
 check(game.forest_ui.preparation_menu_input(key) and game.build_kind=="cannon_tower","B then 5 selects Cannon Tower")
 check(game.forest_ui.build_buttons.cannon_tower.get_node("Shortcut").text=="5","Cannon card keeps existing shortcuts 1–4")
 var cell=Vector2i(9999,9999)
 for z in range(3,14):
  for x in range(-2,8):
   var c=Vector2i(x,z)
   if cell.x==9999 and m.placement_error("cannon_tower",c,0).is_empty():cell=c
 check(cell.x!=9999,"Cannon has a legal courtyard site")
 if cell.x==9999:finish();return
 var money=m.gold;var cannon:Dictionary=m.build("cannon_tower",cell,0);game.world.sync(0)
 check(cannon.kind=="cannon_tower" and m.gold==money-200,"Cannon uses its own 200-ryo purchase")
 check(not m.placement_error("cannon_tower",cell,0).is_empty(),"Occupied site cannot charge or overlap")
 check(workforce.capacity(cannon)==0 and is_equal_approx(workforce.attack_interval(cannon),2.5),"Automatic cannon needs no crew and retains slower 2.5-second shots")
 var visual=game.world.structure_nodes[cannon.id].get_node("WindMeadowAsset")
 var mesh:MeshInstance3D=visual.find_children("*","MeshInstance3D",true,false)[0]
 check(mesh.mesh.get_surface_count()==2 and visual.find_children("*","Skeleton3D",true,false).is_empty(),"Prepared native Cannon Tower has two shared surfaces and no runtime rig")
 check(mesh.mesh.get_aabb().end.y<24 and mesh.mesh.get_aabb().end.y>23,"Native cannon form is shorter than the roofed Guard Tower")
 doc.capture(m);var encoded=doc.encode();var copy=Document.new(false)
 check(copy.decode(encoded).is_empty() and copy.data.buildings.any(func(b):return b.kind=="cannon_tower"),"Saved map roundtrip retains Cannon Tower")
 check(workforce.assign_workers(cannon.id)==0 and workforce.count_job(cannon.id)==0,"Cannon does not take workers from other jobs")
 game.build_kind="";game.forest_ui.selected_id=cannon.id;game.forest_ui.sync()
 check(game.forest_ui.inspect_text.text.contains("Automatic") and not game.forest_ui.inspect_text.text.contains("Crew"),"Tower inspector explains automatic firing instead of crew slots")
 check(game.forest_ui.build_buttons.tower.tooltip_text.contains("No workers needed") and game.forest_ui.build_buttons.cannon_tower.tooltip_text.contains("No workers needed"),"Both tower tooltips explain worker-free operation")

 cannon.hp-=50;money=m.gold
 check(m.repair(cannon.id) and cannon.hp==cannon.max_hp and m.gold==money-5,"Cannon uses normal paid repairs")
 var center:Vector3=m.center(cannon)
 game.forest_ui.hide();game.camera_rig.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera_rig.camera.size=46
 game.camera_rig.camera.position=center+Vector3(33,29,39);game.camera_rig.camera.look_at(center+Vector3.UP*12)
 await photo("cannon-front")
 game.camera_rig.camera.position=center+Vector3(-33,27,-39);game.camera_rig.camera.look_at(center+Vector3.UP*12)
 await photo("cannon-back")
 game.camera_rig.camera.position=center+Vector3(33,29,39);game.camera_rig.camera.look_at(center+Vector3.UP*12)
 game.forest_ui.show();game.forest_ui.sync();await photo("build-menu");game.forest_ui.hide()
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/warcraft_cannon/source.json"))
 check(source.samples.size()==12,"All twelve original cannon/shared building WAVs recovered")
 for row in source.samples:
  var path="res://"+row.file;var stream=load(path) as AudioStreamWAV
  check(FileAccess.get_sha256(path)==row.sha256 and stream.mix_rate==row.sample_rate and pcm_hash(stream.data)==row.pcm_sha256,"Byte-identical file and imported PCM: "+path.get_file())
 for event in ["cannon-launch","cannon-impact"]:
  check(view.audio.cache[event] is AudioStreamRandomizer and view.audio.cache[event].streams_count==3,event+" has all three original variants")
 for event in game.placement_audio.CANNON:
  check(game.placement_audio.play_cannon(event),"Original building cue plays: "+event)
 var cursor=game.placement_audio.voice_cursor;game.sound_library.recording=true
 check(not game.placement_audio.play_cannon("select") and cursor==game.placement_audio.voice_cursor,"Recording suppresses building cues")
 game.sound_library.recording=false
 game.start_wave();game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.army_runtime.clear();game.actors.clear();game.enemies.clear();m.enemies.clear();m.waves.pending=0;m.events.clear()
 m.workers.clear();game.world.sync(0)
 for b in m.buildings.values():b.clock=1000
 cannon.clock=0;workforce.assignment_clock=10000
 var point=center+Vector3(0,0,24);point.y=m.surface_height(point.x,point.z)
 var target=native_enemy(point);m.update_vision(center);m.sync_enemy_records()
 workforce.tick(.01,game.player.position)
 var shells=workforce.arrows.values().filter(func(s):return s.get("cannon",false))
 check(shells.size()==m.balance.tower_workers,"Empty cannon fires its configured native-targeted volley")
 if not shells.is_empty():
  var shell:Dictionary=shells[0];var hp:float=target.hp
  check(Vector2(shell.from.x-center.x,shell.from.z-center.z).length()>6.4,"Muzzle clears its own tower even when firing downhill")
  check(is_equal_approx(shell.damage,100.5),"Native average damage is scaled through existing tower balance")
  view.audio.last_events.clear()
  for event in m.events:
   if event.kind=="arrow":view.launch(event)
  m.events.clear();workforce.tick_arrows(.1);view.sync(.1)
  check(target.hp==hp and not view.audio.last_events.has("cannon-impact"),"Flight does not damage or play impact early")
  check(shell.pos.y>shell.from.lerp(shell.to,shell.age/shell.duration).y,"Shell follows the original arcing trajectory")
  target.take_hit(2000,Vector3.ZERO,false,{"tower":true});m.enemies.erase(target.forest_id)
  for i in 120:workforce.tick_arrows(1.0/60)
  check(not workforce.arrows.has(shell.id) and m.events.any(func(e):return e.kind=="arrow_impact" and e.get("cannon",false)),"Shell still explodes when its original target dies")
 view.clear();m.events.clear()
 # Fixed native targets exercise full, half, tenth and outside splash bands.
 game.army_runtime.clear();game.actors.clear();game.enemies.clear();m.enemies.clear()
 var splash=Vector3(0,0,19);splash.y=m.surface_height(splash.x,splash.z)+1
 var actors=[]
 for x in [0,5.5,8.0,14.0]:
  var at=splash+Vector3(x,0,0);at.y=m.surface_height(at.x,at.z);actors.append(native_enemy(at))
 game.army_runtime.sync_targets()
 workforce.cannon_splash(splash,100,Vector3.RIGHT)
 var health=actors.map(func(e):return e.hp)
 print("CANNON_SPLASH_HEALTH ",health)
 check(health==[900.0,950.0,990.0,1000.0],"Native splash applies full / half / tenth damage and excludes outside bodies")
 check(game.army_runtime.unit_state(actors[0].handle).hp==900.0,"Damage belongs to the native army owner")
 var cover=StaticBody3D.new();cover.collision_layer=1;cover.position=splash+Vector3(3,0,0)
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(.4,8,12);cover.add_child(shape);game.world.add_child(cover)
 await physics_frame;await physics_frame
 workforce.cannon_splash(splash,100,Vector3.RIGHT)
 check(actors[0].hp==800 and actors[1].hp==950 and actors[2].hp==990,"Solid cover blocks splash to neighbors behind it")
 cover.queue_free();await frames();await physics_frame
 var guard:Dictionary=m._make_building("tower",Vector2i(-4,8),0);game.world.sync(0)
 check(is_equal_approx(workforce.attack_interval(guard),1.4),"Guard Tower firing cadence stays unchanged")
 game.army_runtime.clear();game.actors.clear();game.enemies.clear();m.enemies.clear();workforce.arrows.clear();m.events.clear()
 var guard_center:Vector3=m.center(guard)
 var guard_point=guard_center+Vector3(0,0,24);guard_point.y=m.surface_height(guard_point.x,guard_point.z)
 var guard_target=native_enemy(guard_point);m.update_vision(guard_center);m.sync_enemy_records()
 for b in m.buildings.values():b.clock=1000
 guard.clock=0;workforce.tick(0,guard_center)
 check(workforce.arrows.size()==m.balance.tower_workers and m.workers.is_empty(),"Empty Guard Tower fires its full volley through the native owner")
 var guard_hp:float=guard_target.hp
 for i in 120:workforce.tick_arrows(1.0/60)
 check(is_equal_approx(guard_target.hp,guard_hp-m.balance.tower_workers*m.balance.tower_damage),"Automatic guard arrows deliver unchanged damage exactly once")

 m.team_progression.ranks.tower_speed=1;m.team_progression.ranks.tower_damage=1
 check(is_equal_approx(workforce.attack_interval(cannon),2.0),"Existing speed card applies to Cannon Tower")
 m.team_progression.ranks.clear()
 game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 game.camera_rig.camera.position=splash+Vector3(17,13,26);game.camera_rig.camera.look_at(splash+Vector3(3,1,0))
 view.audio.last_events.clear();view.impact({"to":splash,"direction":Vector3.DOWN,"cannon":true})
 await frames(8);await photo("native-splash")
 check(view.audio.last_events.has("cannon-impact"),"Contact selects original cannon explosion cues")
 game.show_pause();await frames();check(view.audio.voices.all(func(v):return not v.can_process()),"Ordinary pause stops cannon audio and presentation")
 game.resume();game.set_process(false);game.set_physics_process(false)
 view.clear();m.workforce.arrows.clear();m.events.clear()
 await volley(splash);await frames(10)
 var counts=[Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)]
 samples.clear();intervals.clear()
 for cycle in 5:await volley(splash)
 await frames(10)
 var after=[Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)]
 check(counts==after,"Five simultaneous 16-shell volleys retain stable nodes/resources: %s -> %s"%[counts,after])
 var report={"checks":checks,"failures":failures,"before":counts,"after":after,"map":"large" if "--large" in OS.get_cmdline_user_args() else "standard"}
 samples.sort();report.work_p95_ms=samples[int(samples.size()*.95)]
 if not intervals.is_empty():intervals.sort();report.frame_p95_ms=intervals[int(intervals.size()*.95)];report.frame_max_ms=intervals[-1]
 m.damage_building(cannon.id,cannon.max_hp*2)
 check(not m.buildings.has(cannon.id) and m.events.any(func(e):return e.kind=="cannon_sound" and e.event=="death"),"Destroyed cannon releases its footprint and delivers the native building-death cue")
 check(m.workers.is_empty(),"Cannon combat and destruction never create or require workers")
 report.checks=checks;report.failures=failures
 FileAccess.open(OUT+"gameplay-"+DisplayServer.get_name()+"-"+report.map+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CANNON_TOWER_REPORT ",JSON.stringify(report));finish()
func finish():
 game.queue_free();paused=false;await frames(5);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("HUMAN_CANNON_TOWER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

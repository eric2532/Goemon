extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Kazi Matched Reach/"
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 create_timer(90).timeout.connect(func():printerr("KAZI_CONTACT_TIMEOUT");quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false);game.explorer_helpers.set_process(false)
 for node in [game,game.player,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 var saved=ConfigFile.new()
 if saved.load("user://settings.cfg")==OK:
  print("KAZI_SAVED_PROFILE ",saved.get_value("character_balance","profiles",{}).get("kazi",{}))
 var p=game.player;p.select_character(34);fresh()
 game.model.hero_position=p.position+Vector3.BACK
 game.world.sync(0)
 var ground:ShaderMaterial=game.world.attack_materials.front()
 check(ground.get_shader_parameter("attack_center")==Vector2(p.global_position.x,p.global_position.z),"Kaz's melee circle follows his current position between battle updates")
 game.model.hero_position=p.position
 game.training_dummy.position=Vector3(0,-100,0);game.training_dummy.collision_layer=0
 var owner=game.army_runtime
 owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 var samples=[]
 var cut_ms=[]
 var second_cut_ms=[]
 for kind in [0,1,3,6,9,16]:
  for pair in [Vector2(0,2),Vector2(0,3),Vector2(1.3,2),Vector2(-1.3,2),Vector2(1.7,4.8),Vector2(0,5.55),Vector2(0,7.1),Vector2(5,2),Vector2(0,-3),Vector2(2.8,0)]:
   var point=ORIGIN+Vector3(pair.x,0,-pair.y)
   var row=game.model.waves.spawn_enemy(kind,point);row.hp=100000;row.max_hp=100000
   owner.import_arrivals();owner.integration_tick(1.0/60)
   var handle:int=owner.handles[row.id];var target=game.actors[row.id]
   p.position=ORIGIN;p.facing=Vector3.FORWARD;p.ai_controlled=true;p.ai_aim=ORIGIN+Vector3.FORWARD*10
   p.attack_chain.reset()
   var kit=p.active_ability;kit.start_attack()
   var before:float=owner.unit_state(handle).hp
   var started=Time.get_ticks_usec()
   kit.tick(kit.CONTACT+.001)
   cut_ms.append((Time.get_ticks_usec()-started)/1000.0)
   var after_cut:float=owner.unit_state(handle).hp
   started=Time.get_ticks_usec()
   kit.tick(kit.SECOND_CUT_CONTACT-kit.elapsed+.001)
   second_cut_ms.append((Time.get_ticks_usec()-started)/1000.0)
   var after_second_cut:float=owner.unit_state(handle).hp
   if pair.y in [2.0,3.0] and absf(pair.x)<=1.3:
    check(is_equal_approx(before-after_cut,50) and is_equal_approx(after_cut-after_second_cut,50),"Two regular cuts hit kind %d at %s"%[kind,pair])
   if kind==0 and pair in [Vector2(1.7,4.8),Vector2(0,5.55)]:
    check(is_equal_approx(before-after_cut,50) and is_equal_approx(after_cut-after_second_cut,50),"Both cuts hit a soldier near the shared range limit at %s"%pair)
   if kind==0 and (pair.x==5 or pair.y<0 or pair.y>7 or pair==Vector2(2.8,0)):
    check(before==after_second_cut,"Neither cut hits a soldier outside the regular sweep at %s"%pair)
   var bounds:AABB=target.combat_bounds()
   samples.append({"kind":kind,"offset":[pair.x,pair.y],"cut":before-after_cut,"second_cut":after_cut-after_second_cut,"bounds_min":[bounds.position.x-ORIGIN.x,bounds.position.y-ORIGIN.y,bounds.position.z-ORIGIN.z],"bounds_size":[bounds.size.x,bounds.size.y,bounds.size.z]})
   kit.cancel();owner.despawn(handle);owner.integration_tick(1.0/60)
 print("KAZI_CONTACT_SAMPLES ",JSON.stringify(samples))
 FileAccess.open(OUT+"contacts.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
 var metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
 print("KAZI_CUT_MS ",metrics.summary(cut_ms))
 print("KAZI_SECOND_CUT_MS ",metrics.summary(second_cut_ms))
 p.attack_chain.reset()
 p.character_id=34;game.character_tuning={"kazi":{"melee_reach":10.0,"model_scale":1.8}};p.model.scale=Vector3.ONE*1.8
 var near=game.model.waves.spawn_enemy(0,ORIGIN+Vector3.FORWARD*2);near.hp=100000;near.max_hp=100000
 owner.import_arrivals();owner.integration_tick(1.0/60)
 var target_handle:int=owner.handles[near.id];var target_hp:float=owner.unit_state(target_handle).hp
 p.position=ORIGIN;p.facing=Vector3.FORWARD;p.ai_controlled=true;p.ai_aim=ORIGIN+Vector3.FORWARD*10
 var scaled_kit=p.active_ability;scaled_kit.start_attack();scaled_kit.tick(scaled_kit.CONTACT+.001)
 check(owner.unit_state(target_handle).hp<target_hp,"A normal enemy remains hittable with saved 10x reach and 1.8x visual size")
 check(is_equal_approx(p.melee_strike_reach(),100.8),"Shared reach outline includes the configured model scale and reach")
 check(is_equal_approx(target_hp-owner.unit_state(target_handle).hp,50),"Custom reach and size still deliver one 50-damage cut")
 scaled_kit.cancel()
 for yaw in [PI*.5,PI,PI*1.5]:
  owner.despawn(target_handle);owner.integration_tick(1.0/60)
  var facing=Vector3.FORWARD.rotated(Vector3.UP,yaw)
  near=game.model.waves.spawn_enemy(0,ORIGIN+facing*2);near.hp=100000;near.max_hp=100000
  owner.import_arrivals();owner.integration_tick(1.0/60);target_handle=owner.handles[near.id];target_hp=owner.unit_state(target_handle).hp
  p.facing=facing;p.ai_aim=ORIGIN+facing*10;scaled_kit.start_attack();scaled_kit.tick(scaled_kit.CONTACT+.001)
  check(owner.unit_state(target_handle).hp<target_hp,"Saved-range contacts work when turning to yaw %.2f"%yaw);scaled_kit.cancel()
 game.character_tuning={};p.model.scale=Vector3.ONE;p.facing=Vector3.FORWARD;p.ai_aim=ORIGIN+Vector3.FORWARD*10
 owner.despawn(target_handle);owner.integration_tick(1.0/60)
 near=game.model.waves.spawn_enemy(0,ORIGIN+Vector3.FORWARD*2);near.hp=100000;near.max_hp=100000
 owner.import_arrivals();owner.integration_tick(1.0/60);target_handle=owner.handles[near.id];target_hp=owner.unit_state(target_handle).hp
 scaled_kit.start_attack();scaled_kit.ticket.skill_hit_area=4.0;scaled_kit.tick(scaled_kit.CONTACT+.001)
 check(owner.unit_state(target_handle).hp<target_hp,"Hit-area tuning expands contact without raising its origin")
 scaled_kit.cancel()
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("KAZI_CONTACT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

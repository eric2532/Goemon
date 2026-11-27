extends "res://tests/forest-shrine/dodge_counter_stats_test.gd"
const EVIDENCE="res://build/Other Files/Asset Toolkit/Water Boomerang Contact/"
const Shot=preload("res://scripts/recovered_enemy_projectile.gd")

func waves()->Array:
 return game.crowd.army.presentation.effects.filter(func(effect):return effect.kind=="water-boomerang-wave")

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();game.crowd.army.presentation.draw_effects()
 await frames(2);RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(EVIDENCE+stem+".png")==OK,"Capture "+stem)

func launch(kind:String="water_dragon_boomerang",accuracy:float=100.0):
 return Pool.service(game).launch(game.player,Shot,kind,{"kind":kind,"position":game.player.auto_aim_origin(),"velocity":Vector3.FORWARD*72,"boomerang_reach":18.0,"damage":10.0,"attack_ticket":{"accuracy":accuracy}})

func flight(shot,enemy,capture_:bool=false):
 var health:float=enemy.hp;var count_=0
 for i in ceili(shot.boomerang_duration/DT)+2:
  if not shot.pool_live:break
  var before=waves().size();shot._physics_process(DT)
  var current=waves()
  if current.size()>before:
   count_+=current.size()-before
   check(enemy.combat_bounds().grow(.05).has_point(current.back().position),"The wave starts at the enemy's exact contact surface")
   check(current.back().position.distance_to(game.player.position)>8,"The wave starts away from the thrower")
   if capture_:await picture("confirmed-contact");capture_=false
  game.crowd.army.presentation.tick(DT)
 return {"waves":count_,"damage":health-enemy.hp}

func run():
 create_timer(240).timeout.connect(func():printerr("WATER_BOOMERANG_CONTACT_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EVIDENCE);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={};game.settings.skill_item_loadouts={}
 game.begin_arena();game.choose_rogue_character(37);game.select_shin_skin(37,900050);await frames(2);game.equipment_hub.enter_map();await frames(3)
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 game.clear_menu();game.playing=true;game.paused=false;paused=false;game.forest_ui.hide();game.music.stop()
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.global_position=home+Vector3(8,7,21);game.camera_rig.camera.look_at(home+Vector3(0,2,-10));game.camera_rig.camera.make_current()
 var p=game.player;var army=game.army_runtime;var fx=game.crowd.army.presentation;var pool=Pool.service(game)
 game.update_character_tuning(37,"critical_chance",0);game.update_character_tuning(37,"accuracy",100)
 pool.launched.connect(func(shot):shot.set_physics_process(false);shots.append(shot))
 check(game.save_equipment_loadouts({Gear.character_key(37):{"1":"weapon:water-dragon-boomerang"}},{},{}),"Equip the custom 水龍 boomerang")
 planted();army.clear();game.model.enemies.clear();army.refresh_kits()
 var enemy=spawn(Vector3.FORWARD*18).target
 var kit=p.active_ability;var pattern:Dictionary=p.model.normal_attack_pattern();var rate:float=p.attack_speed_multiplier()
 check(p.model.motions.wave_on_contact,"Custom throw drawing uses its separated contact wave")
 for direction in 8:
  var attack:Dictionary=p.model.body_clip(5,"5:%d"%direction)
  p.model.show_shin_counter(p.position,attack,true);p.model.pose_shin_counter(attack,attack.duration*.8)
  p.model.show_frame(5,"5:%d"%direction,mini(attack.frames.size()-1,floori(attack.frames.size()*.8)))
  check(p.model.sprite.texture==p.model.stat_counter_shadow.texture and p.model.sprite.region_rect==p.model.stat_counter_shadow.region_rect,"Normal and counter reuse the same wave-free body: facing %d"%direction)
 p.model.stat_counter_shadow.hide();p.facing=Vector3.FORWARD;kit.start_attack();kit.tick(float(pattern.contacts[0])/rate+.001)
 check(shots.size()==1 and waves().is_empty(),"Release launches the boomerang without a wave beside the caster")
 if shots.size()!=1:quit(1);return
 await picture("release-without-wave")
 var result:Dictionary=await flight(shots[0],enemy,true)
 check(result.waves==1 and result.damage>0,"One connected hit produces one blue wave across both flight legs")
 check(not shots[0].pool_live,"The boomerang still returns and retires")
 fx.tick(.5);check(waves().is_empty(),"Contact waves expire in the existing effect pool")
 # Physical misses, empty flight and the original weapon cannot trigger the custom burst.
 kit.cancel(true);planted();var missed=launch("water_dragon_boomerang",-100)
 result=await flight(missed,enemy)
 check(result.waves==0 and result.damage==0,"A real native physical miss has no contact wave")
 planted();var original=launch("crossgate_boomerang")
 result=await flight(original,enemy)
 check(result.waves==0 and result.damage>0,"The original default boomerang keeps ordinary impacts")
 planted();var empty=launch();empty.boomerang_forward=Vector3.BACK
 result=await flight(empty,enemy)
 check(result.waves==0,"Empty flight produces no wave")
 planted();chance(0,100);p.take_hit_from(2,Vector3.BACK,false,enemy.forest_id)
 check(not kit.shin_counter.is_empty(),"A natural counter starts")
 if not kit.shin_counter.is_empty():
  kit.tick_shin_counter(float(kit.shin_counter.contact)/rate+.001)
  check(shots.size()==1 and waves().is_empty(),"The counter releases without a caster-side wave")
  result=await flight(shots[0],enemy)
  check(result.waves==1 and result.damage>0,"A counter's actual hit gets the same contact wave")
 kit.clear_shin_counter();pool.release_owner(p);planted()
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 4:check(mirrors.reinforce(37,home+Vector3((i-1.5)*2,0,1)),"Deploy a native copy")
 shots.clear()
 for body in mirrors.bodies:
  body.ai_target=enemy
  check(body.perform(0,enemy.global_position),"Native copy throws")
  body.active_ability.tick(float(body.model.normal_attack_pattern().contacts[0])/body.attack_speed_multiplier()+.002)
 check(shots.size()==4 and waves().is_empty(),"Four native copies release without waves at their feet")
 for shot in shots:shot.attack_ticket.accuracy=100.0
 var hp:float=enemy.hp;var contacts=0
 for i in 150:
  var before=waves().size()
  for shot in shots:
   if shot.pool_live:shot._physics_process(DT)
  contacts+=waves().size()-before;fx.tick(DT)
 check(contacts==4 and enemy.hp<hp,"Each simultaneous native copy produces its wave only on contact (contacts %d)"%contacts)
 mirrors.dispose();await frames(2);planted()
 var warm=launch();await flight(warm,enemy);fx.tick(.5);fx.draw_effects();await create_timer(.5).timeout;await frames(4)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for repeat_ in 12:
  var shot=launch();result=await flight(shot,enemy)
  check(result.waves==1,"Repeated lease produces one fresh contact burst")
 fx.tick(.5)
 await create_timer(.5).timeout;await frames(4)
 print("WATER_CONTACT_REUSE nodes=",nodes,"/",get_node_count()," resources=",resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)," projectiles=",created,"/",pool.created)
 check(get_node_count()==nodes and pool.created==created and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated hits reuse prepared effects/projectiles without node or resource growth")
 var capacity=fx.effect_capacity;fx.effect_capacity=0;var health:float=enemy.hp
 var capped=launch();result=await flight(capped,enemy);fx.effect_capacity=capacity
 check(enemy.hp<health and result.waves==0,"A full cosmetic pool never suppresses real damage")
 print("WATER_BOOMERANG_CONTACT_RESULT checks=",checks," failures=",failures)
 game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

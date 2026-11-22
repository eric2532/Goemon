extends "res://tests/forest-shrine/crossgate_shin_skills_test.gd"
const EXPLOSION_OUT="res://build/Other Files/Lancelot Arrow Explosion/"
const Pool=preload("res://scripts/character_projectile_pool.gd")
var arrows:Array[Node3D]=[]
var home:Vector3
var impact_point=Vector3.ZERO

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(EXPLOSION_OUT+filename)==OK,"Captured "+filename)

func charge()->Node3D:
 var p=game.player
 p.active_ability.cancel(true);p.active_ability.clear_cooldowns();p.attack_chain.reset()
 p.impact_pause=0;game.hit_stop=0;p.position=home;p.facing=Vector3.FORWARD
 arrows.clear();victims.clear();game.crowd.army.presentation.tick(5)
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(5)
 press(KEY_2)
 for i in 160:
  if not arrows.is_empty():break
  step_player(1)
 check(arrows.size()==1 and victims.is_empty(),"Key 2 releases one prepared arrow before any damage")
 return arrows[0] if not arrows.is_empty() else null

func fly(arrow:Node3D):
 for i in 160:
  if not arrow.pool_live:break
  arrow._physics_process(STEP)
  game.army_runtime.flush_presentation()
 var bursts=game.crowd.army.presentation.effects.filter(func(row):return row.kind=="shin_sure_strike")
 if not bursts.is_empty():impact_point=bursts.back().position

func wall_at(point:Vector3,size_:Vector3)->StaticBody3D:
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;shape.shape=box
 wall.add_child(shape);game.add_child(wall);wall.position=point
 return wall

func run():
 create_timer(140).timeout.connect(func():printerr("LANCELOT_ARROW_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EXPLOSION_OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var army=game.army_runtime;var p=game.player
 game.set_process(false);army.set_physics_process(false);army.set_process(false)
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 p.select_character(Roster.LANCELOT_ID);fresh()
 game.select_crossgate_skin(Roster.LANCELOT_ID,105206)
 game.settings.disable_character_cooldowns=false;game.tuning.invincible=false
 game.settings.skill_balance={"lancelot/sure-strike":{"damage":1.6}}
 home=Vector3(-120,0,125);home.y=game.model.world_height(home.x,home.z)+.05
 game.model.update_vision(home);settle(home)
 game.camera_rig.camera.global_position=home+Vector3(12,14,22)
 game.camera_rig.camera.look_at(home+Vector3(0,1,-14))
 game.training_dummy.position=home+Vector3.DOWN*100
 army.set_navigation(9934,army.navigation_data(game.model));army.record_events=false
 var targets=[]
 for offset in [Vector3(0,0,-30),Vector3(3,0,-30),Vector3(14,0,-30),Vector3(5.8,0,-30)]:
  var point=home+offset;point.y=game.model.world_height(point.x,point.z)
  var row=game.model.waves.spawn_enemy(0,point);row.hp=2000000;row.max_hp=row.hp
  army.import_arrivals();army.sync_targets()
  var enemy:Ninja=game.actors[row.id];targets.append(enemy)
  army.apply_hit(enemy.handle,{"element":"ice","status_seconds":1000.0})
 game.impact_confirmed.connect(func(victim,_strength,_time):victims.append(victim))
 var pool=Pool.service(game)
 pool.launched.connect(func(arrow):
  if arrow.kind=="crossgate_arrow":arrows.append(arrow);arrow.set_physics_process(false))
 var arrow=await charge()
 if arrow==null:game.queue_free();paused=false;await frames(4);quit(1);return
 var expected=arrow.damage*arrow.skill_factor("damage")
 check(is_equal_approx(arrow.damage,p.active_ability.SHIN_SURE_DAMAGE*p.damage_multiplier()),"乾坤 keeps 5,000 base damage and slime-sized impact feedback")
 check(arrow.attack_ticket.skill_id=="lancelot/sure-strike" and is_equal_approx(arrow.skill_factor("damage"),1.6),"The released arrow carries 乾坤 tuning and attribution")
 game.model.team_progression.skill_food_stacks=20
 check(is_equal_approx(arrow.attack_ticket.sure_strike_size,10.8),"Food eaten after release cannot change the in-flight blast snapshot")
 check(not game.crowd.army.presentation.effects.any(func(row):return row.kind=="shin_sure_strike"),"No explosion appears at the caster or at bow release")
 var before=targets.map(func(enemy):return army.unit_state(enemy.handle).hp)
 arrow._physics_process(.15)
 check(arrow.pool_live and victims.is_empty(),"The arrow travels visibly toward its target before exploding")
 game.crowd.present_army(army.render_snapshot(),army.presentation_events)
 await capture("charged-arrow-in-flight.png")
 fly(arrow)
 check(not arrow.pool_live and victims.count(targets[0])==1 and not victims.has(targets[1]) and not victims.has(targets[2]),"One arrow hits only its direct enemy and leaves nearby enemies unharmed")
 check(is_equal_approx(before[0]-army.unit_state(targets[0].handle).hp,expected) and is_equal_approx(before[1],army.unit_state(targets[1].handle).hp),"The direct target takes tuned damage once; the nearby target takes none")
 check(is_equal_approx(before[2],army.unit_state(targets[2].handle).hp) and is_equal_approx(before[3],army.unit_state(targets[3].handle).hp),"Enemies whose body centres are outside the visible impact circle remain unharmed")
 check(impact_point.distance_to(targets[0].position)<3 and impact_point.distance_to(home)>25,"The recovered explosion is centered at the arrow's actual contact point")
 check(game.crowd.army.presentation.effects.filter(func(row):return row.kind=="shin_sure_strike").size()==1,"The impact submits one explosion")
 game.crowd.present_army(army.render_snapshot(),army.presentation_events)
 game.crowd.army.presentation.tick(.08)
 await capture("arrow-impact-explosion.png")
 var grown_arrow=await charge()
 check(grown_arrow!=null and is_equal_approx(grown_arrow.attack_ticket.sure_strike_size,21.6),"Twenty servings double the next body explosion's visual dimensions")
 var grown_before:float=targets[3].hp
 if grown_arrow!=null:fly(grown_arrow)
 check(targets[3].hp==grown_before,"A larger body explosion adds no splash damage")
 game.model.team_progression.skill_food_stacks=0
 var side_wall=wall_at(targets[0].position+Vector3(2,2,0),Vector3(.5,5,6))
 await physics_frame;await physics_frame
 arrow=await charge();before=targets.map(func(enemy):return army.unit_state(enemy.handle).hp);fly(arrow)
 check(army.unit_state(targets[0].handle).hp<before[0] and army.unit_state(targets[1].handle).hp==before[1],"Solid cover blocks splash damage without blocking the primary arrow")
 side_wall.queue_free();await physics_frame;await physics_frame
 var front_wall=wall_at(home+Vector3(0,2,-14),Vector3(40,5,.6))
 await physics_frame;await physics_frame
 arrow=await charge();before=targets.map(func(enemy):return army.unit_state(enemy.handle).hp);fly(arrow)
 check(not arrow.pool_live and victims.is_empty() and targets.all(func(enemy):return army.unit_state(enemy.handle).hp==before[targets.find(enemy)]),"A wall impact retires the arrow and cannot hit enemies beyond its blast")
 check(not game.crowd.army.presentation.effects.any(func(row):return row.kind=="shin_sure_strike"),"A wall contact creates no enemy-body explosion")
 game.crowd.army.presentation.tick(.08)
 await capture("wall-impact-explosion.png")
 front_wall.queue_free();await physics_frame;await physics_frame
 p.active_ability.cancel(true);p.active_ability.clear_cooldowns();p.attack_chain.reset();arrows.clear();victims.clear();game.crowd.army.presentation.tick(5)
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(5)
 tap("light_attack");step_player(90)
 check(arrows.size()==1 and arrows[0]==arrow and not arrows[0].attack_ticket.has("sure_strike_size"),"Reusing the charged arrow lease for a normal arrow clears its blast state and ticket")
 before=targets.map(func(enemy):return army.unit_state(enemy.handle).hp);fly(arrows[0])
 check(victims==[targets[0]] and army.unit_state(targets[1].handle).hp==before[1] and not game.crowd.army.presentation.effects.any(func(row):return row.kind=="shin_sure_strike"),"Ordinary arrows keep their single-target hit without an explosion")
 for enemy in targets:army.despawn(enemy.handle)
 arrow=await charge();fly(arrow)
 check(not arrow.pool_live and victims.is_empty() and not game.crowd.army.presentation.effects.any(func(row):return row.kind=="shin_sure_strike"),"An arrow that expires without contact produces no damage or explosion")
 for enemy in targets:check(enemy.dead,"Retired native targets stay retired")
 var dummy=game.training_dummy;dummy.position=home+Vector3.FORWARD*30;dummy.home=dummy.position
 await charge();fly(arrows.back());game.crowd.army.presentation.tick(5)
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(5);await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var created=pool.created;var misses=pool.misses;var costs=[]
 for i in 12:
  arrow=await charge()
  var started=Time.get_ticks_usec();fly(arrow);costs.append(Time.get_ticks_usec()-started)
  check(victims==[dummy],"Repeated charged arrow detonates exactly once")
  game.crowd.army.presentation.tick(5)
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(5)
 await frames(3)
 print("ARROW_REUSE nodes=",nodes,"/",get_node_count()," resources=",resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)," created=",created,"/",pool.created," misses=",misses,"/",pool.misses)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created and pool.misses==misses,"Repeated explosions retain warmed nodes/resources and prepared arrow capacity")
 p.active_ability.cancel(true);p.active_ability.clear_cooldowns();arrows.clear();press(KEY_2);step_player(6);p.active_ability.cancel(true);step_player(100)
 check(arrows.is_empty(),"Cancelling the charge creates no late arrow or blast")
 print("LANCELOT_ARROW_PERFORMANCE repeated_flight_max_us=%d pool_created=%d pool_misses=%d"%[costs.max(),pool.created,pool.misses])
 var config=game.settings_path;game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(config):DirAccess.remove_absolute(ProjectSettings.globalize_path(config))
 print("LANCELOT_ARROW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

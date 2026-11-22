extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"

const Pool=preload("res://scripts/character_projectile_pool.gd")
const Evidence="res://build/Other Files/Asset Toolkit/Maze Kunai Aim/"
var shots:Array=[]

func throw_pair():
 var kit=game.player.active_ability
 kit.cancel(true);game.player.attack_chain.reset();shots.clear()
 var started=Time.get_ticks_usec()
 kit.start_attack()
 var rate:float=kit.primary_attack_tempo()
 kit.tick((kit.throw_release-.001)/rate)
 samples.append(Time.get_ticks_usec()-started)
 check(shots.is_empty(),"The pair waits for the recovered release marker")
 started=Time.get_ticks_usec()
 kit.tick(.002/rate)
 samples[-1]+=Time.get_ticks_usec()-started
 check(shots.size()==2,"The release emits exactly two kunai")
 check(shots.all(func(shot):return shot.dagger_sprite.texture==preload("res://assets/characters/crossgate/maze/regular-dagger.png") and shot.dagger_sprite.hframes==16),"Every release uses the shared regular dagger at sixteen flight angles")

func finish_shots():
 for i in 120:
  for shot in shots:
   if shot.pool_live:shot._physics_process(DT)
 check(shots.all(func(shot):return not shot.pool_live and shot.target==null),"Retired leases clear their targets")

func picture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();game.crowd.army.presentation.tick(2.0)
 game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 game.crowd.army.presentation.draw_effects()
 game.player.model.show_pose(7,game.player.active_ability.elapsed,false)
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(Evidence+name_+".png")==OK,"Rendered "+name_)

func run():
 create_timer(90).timeout.connect(func():printerr("MAZE_KUNAI_AIM_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(Evidence)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 game.set_process(false);army.set_process(false);army.set_physics_process(false)
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*1000
 p.select_character(p.RogueRoster.MAZE_ID);fresh();p.position=home;p.velocity=Vector3.ZERO
 game.reset_character_tuning(p.character_id);game.update_character_tuning(p.character_id,"critical_chance",0)
 p.active_ability.set_weapon(p.RogueRoster.MazeWeapon.KUNAI)
 var per_dagger=50.0
 army.clear();army.refresh_kits()
 game.camera_rig.camera.global_position=home+Vector3(0,17,22)
 game.camera_rig.camera.look_at(home+Vector3(0,1,-5))
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 var first=spawn(Vector3(-5,0,-7));var second=spawn(Vector3(6,0,-9))
 var third=spawn(Vector3(-5,0,-18))
 await physics_frame
 var created:int=pool.created;var misses:int=pool.misses
 throw_pair()
 check(shots[0].target.get_ref()==first and shots[1].target.get_ref()==second,"The two knives choose different nearest visible enemies")
 check(shots.all(func(shot):return shot.velocity.normalized().dot((AttackChain.aim_point(shot.target.get_ref(),shot.position)-shot.position).normalized())>.9999),"Each knife aims at its enemy from its own release position")
 check(is_equal_approx(shots[0].position.distance_to(shots[1].position),.6),"Release spacing remains 0.6 m")
 for shot in shots:shot._physics_process(.035)
 await picture("two-enemy-release")
 finish_shots()
 check(is_equal_approx(1000000-first.hp,per_dagger) and is_equal_approx(1000000-second.hp,per_dagger) and third.hp==1000000,"The selected enemies each take 50 base damage; the third is untouched")
 check(p.attack_chain.count==1,"The pair still earns one attack-chain link")
 army.despawn(army.handles[second.forest_id]);army.despawn(army.handles[third.forest_id]);army.sync_compatibility()
 var before:float=first.hp
 throw_pair()
 check(shots.all(func(shot):return shot.target.get_ref()==first),"A lone enemy receives both aimed kunai")
 finish_shots()
 check(is_equal_approx(before-first.hp,2.0*per_dagger),"A lone enemy takes the unchanged pair damage")
 second=spawn(Vector3(6,0,-9))
 var wall=StaticBody3D.new();var collision=CollisionShape3D.new();var box=BoxShape3D.new()
 box.size=Vector3(3,6,1);collision.shape=box;wall.add_child(collision);game.add_child(wall)
 wall.global_position=home+Vector3(3,2,-4.5)
 await physics_frame;await physics_frame
 throw_pair()
 check(shots.all(func(shot):return shot.target.get_ref()==first),"An enemy behind a wall is not selected for the second knife")
 finish_shots();wall.queue_free();await physics_frame;await physics_frame
 p.active_ability.cancel(true);p.attack_chain.reset();shots.clear();p.active_ability.start_attack()
 first.take_hit(2000000,Vector3.FORWARD,false)
 p.active_ability.tick(.22)
 check(shots.size()==2 and shots.all(func(shot):return shot.target.get_ref()==second),"If the locked enemy dies during windup, both knives aim at the surviving enemy")
 finish_shots()
 for i in 12:
  throw_pair();finish_shots()
 check(pool.created==created and pool.misses==misses,"Repeated throws reuse prepared leases without pool growth")
 p.active_ability.cancel(true);p.attack_chain.reset()
 var mirrors=p.spell_loadout._instance("blademaster/mirror-image").controller.mirrors
 Skills.set_level(p,"blademaster/mirror-image",30)
 check(mirrors.cast() and mirrors.handles.size()==9,"Nine native copies prepare the existing kunai owner")
 third=spawn(Vector3(-8,0,-12));shots.clear()
 for body in mirrors.bodies.slice(0,mirrors.handles.size()):
  body.ai_target=second
  body.active_ability.start_attack();body.active_ability.tick(.22)
 check(shots.all(func(shot):return shot.dagger_sprite.texture==preload("res://assets/characters/crossgate/maze/regular-dagger.png")),"All native copies share the regular dagger artwork")
 check(shots.size()==18 and shots.all(func(shot):return shot.target!=null),"Nine simultaneous copies each release two targeted kunai")
 check(mirrors.bodies.slice(0,mirrors.handles.size()).all(func(body):
  var pair=shots.filter(func(shot):return shot.hero==body)
  return pair.size()==2 and pair[0].target.get_ref()==second and pair[1].target.get_ref()==third),"Each copy keeps its native primary pursuit and aims its second knife at another enemy")
 check(pool.misses==misses,"Simultaneous copies use prepared projectile capacity")
 await picture("nine-copy-volley")
 finish_shots();mirrors.clear()
 army.clear();army.sync_compatibility();shots.clear()
 throw_pair()
 check(shots.all(func(shot):return shot.target==null and shot.velocity.is_finite()),"With no enemy, both knives retain a valid forward throw")
 finish_shots()
 p.select_character(p.RogueRoster.SAIZO_ID);p.active_ability.set_weapon(p.RogueRoster.MazeWeapon.KUNAI)
 p.position=home;p.attack_chain.reset();first=spawn(Vector3(0,0,-7));shots.clear()
 p.active_ability.start_attack();p.active_ability.tick(.3)
 check(shots[0].dagger_sprite.texture==preload("res://assets/characters/crossgate/maze/regular-dagger.png"),"Saizo shares the regular dagger appearance")
 check(shots.size()==1 and shots[0].target==null,"Saizo retains one ordinary kunai and its existing contact rules")
 finish_shots()
 check(is_equal_approx(1000000-first.hp,50.0),"Saizo's single dagger starts at 50 damage per contact")
 samples.sort()
 print("MAZE_KUNAI_MANUAL_CAST_US p95=",samples[ceili(samples.size()*.95)-1]," max=",samples[-1])
 game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MAZE_KUNAI_AIM_RESULT checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)

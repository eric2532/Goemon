extends "res://tests/forest-shrine/magic_mouse_target_test.gd"

const QI_REPORT="res://build/Other Files/Asset Toolkit/Qi Targeting/"
var qi_samples:Array[int]=[]

func step_qi(count_:int):
 for tick in count_:
  for row in releases:
   if row.shot.pool_live:
    var started=Time.get_ticks_usec()
    row.shot._physics_process(DT)
    qi_samples.append(Time.get_ticks_usec()-started)

func expected_aim(enemy:Ninja,from:Vector3)->Vector3:
 from.y=enemy.combat_bounds().get_center().y
 return enemy.combat_aim_point(from)

func qi_picture():
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.global_position=home+Vector3(14,11,16)
 game.camera_rig.camera.look_at(home+Vector3(0,3,-12))
 game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(QI_REPORT+"body-height-homing.png")==OK,"Captured torso-height Qi homing")

func run():
 create_timer(240).timeout.connect(func():printerr("QI_TARGETING_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(QI_REPORT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 for node in [game,p,army,game.camera_rig]:node.set_process(false);node.set_physics_process(false)
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.model.balance.enemy_profiles={str(Roles.SLIME):{"dodge_chance":0.0}}
 army.refresh_kits()
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  shot.set_physics_process(false)
  releases.append({"target":shot.target,"position":shot.global_position,"shot":shot}))
 game.impact_confirmed.connect(func(enemy,_strength,_time):focused_impacts.append(enemy.get_instance_id()))
 for id in [p.RogueRoster.KAZI_ID,p.RogueRoster.SHIN_ID,p.RogueRoster.RUBY_ID,p.RogueRoster.MAZE_ID]:
  p.select_character(id);fresh();p.position=home;p.velocity=Vector3.ZERO
  await driver.advance(20,advance)
  army.clear();game.model.enemies.clear();army.refresh_kits();await frames(2)
  game.enemies=game.enemies.filter(is_instance_valid)
  var enemy=spawn(Vector3(0,0,-28))
  var miss=p.attack_chain.make_ticket("qi_accuracy_control");miss.accuracy=0
  var before=enemy.hp
  enemy.take_hit(1,Vector3.FORWARD,false,miss)
  check(enemy.hp<before,"Fighter %d contact fixture has zero native evasion"%id)
  for spell in ["kazi/qigong","maze/qigong"]:
   var label="%d %s"%[id,spell]
   army.set_pose(enemy.handle,home+Vector3(0,0,-28),0);army.sync_targets()
   p.position=home+Vector3.UP*8
   var skill=p.spell_loadout._instance(spell).controller
   p.active_ability.primary_tab_target=weakref(enemy)
   await aim_at(enemy.combat_bounds().get_center())
   begin(skill);finish(skill)
   check(releases.size()==3 and all_on(enemy),label+" locks all three blasts on the selected target")
   for row in releases:
    var wanted=row.position.direction_to(expected_aim(enemy,row.position))
    check(row.shot.velocity.normalized().dot(wanted)>.999,label+" leaves toward body height from an elevated caster")
   var shot=releases[0].shot
   army.set_pose(enemy.handle,home+Vector3(9,2,-30),.7);army.sync_targets()
   var from:Vector3=shot.global_position
   var wanted=from.direction_to(expected_aim(enemy,from))
   shot._physics_process(DT)
   check(shot.pool_live and shot.velocity.normalized().dot(wanted)>.999,label+" follows lateral and vertical native target motion")
   var wall=StaticBody3D.new();var collider=CollisionShape3D.new();var box=BoxShape3D.new()
   box.size=Vector3(40,30,.5);collider.shape=box;wall.add_child(collider);game.add_child(wall)
   wall.global_position=home+Vector3(0,10,-12)
   await physics_frame;await physics_frame
   focused_impacts.clear();before=enemy.hp
   var result:Dictionary=shot.attack_ticket.get("magic_result",{})
   shot.age=shot.flight_life+.1
   step_qi(25)
   check(enemy.hp<before and (not shot.pool_live or shot.contact_done),label+" resolves a late locked blast as contact instead of silently expiring")
   if id==p.RogueRoster.KAZI_ID and spell=="kazi/qigong":await qi_picture()
   step_qi(300)
   check(focused_impacts.count(enemy.get_instance_id())==3 and enemy.hp<before,label+" all locked blasts reach the moving target through new cover")
   check(releases.all(func(row):return not row.shot.pool_live and row.shot.target==null and not row.shot.shine.is_visible_in_tree()),label+" finishes and clears pooled targets and impact shines")
   if not result.is_empty():check(result.pending==0 and result.hit,label+" completes its magic result once")
   wall.queue_free();await physics_frame;await physics_frame
   skill.cancel(true)
  p.position=home
 # Losing a target redirects the same lease once, then cleans up when no enemy remains.
 var skill=p.spell_loadout._instance("kazi/qigong").controller
 army.clear();game.model.enemies.clear();await frames(2)
 game.enemies=game.enemies.filter(is_instance_valid)
 var primary=spawn(Vector3(0,0,-25));var replacement=spawn(Vector3(-10,0,-24))
 spawn(Vector3(10,0,-38));spawn(Vector3(0,0,-32))
 await aim_at(primary.combat_bounds().get_center())
 p.active_ability.primary_tab_target=weakref(primary)
 begin(skill);skill.ticket.pet_cast_reach=30.0;skill.ticket.rank11_shine=true;finish(skill)
 var shining=releases[0].shot
 var body=primary.combat_bounds()
 shining.start_delay=0
 shining.global_position=body.get_center()+Vector3.BACK*(body.size.z*.5+shining.hit_radius*shining.collision_scale+1.0)
 shining._physics_process(DT);shining._physics_process(.04)
 check(shining.rank11_shine and shining.shine.visible and not shining.shine_anchor.is_empty() and shining.shine_age>=0 and shining.shine_age<shining.SHINE_LEAD and not shining.contact_done,"The original target starts its pre-hit shine without taking contact")
 primary.mark_dead()
 for row in releases:
  row.shot.start_delay=0;row.shot.global_position=home+Vector3(6,2,-25)
 step_qi(1)
 check(releases.all(func(row):return row.shot.pool_live and row.shot.target==replacement),"Retarget picks the nearest eligible enemy, excluding a closer enemy beyond the cast's 30 m reach")
 check(shining.shine_age<0 and shining.shine_anchor.is_empty() and not shining.shine.visible,"Retarget clears the defeated target's unfinished shine and anchor")
 shining.global_position=expected_aim(replacement,home+Vector3(0,2,-25))
 var replacement_hp=replacement.hp
 shining._physics_process(DT)
 check(shining.shine_age==0 and shining.shine.visible and not shining.shine_anchor.is_empty() and shining.shine_anchor.position.is_equal_approx(replacement.combat_bounds().get_center()) and not shining.contact_done and replacement.hp==replacement_hp,"The replacement starts its own full pre-hit shine before damage")
 army.clear();game.model.enemies.clear();await frames(2)
 step_qi(1)
 check(releases.all(func(row):return not row.shot.pool_live and row.shot.target==null),"Freed targets with no replacement retire without stale hits")
 # An intentionally untargeted fan keeps its ordinary flight and lifetime on reuse.
 var config={"position":home+Vector3.UP*20,"velocity":Vector3.FORWARD*30,"target":null,"damage":10.0,"effect_height":Skills.BASE_DIAMETER,"attack_ticket":p.attack_chain.make_ticket("kazi/qigong")}
 releases.clear()
 var stray=pool.launch(p,skill.Shot,skill.projectile_profile(),config)
 stray._physics_process(DT)
 check(stray.pool_live and stray.target==null and stray.global_position.z<home.z,"Reused untargeted Qi keeps its forward fan")
 stray.age=stray.flight_life+.1;stray._physics_process(DT)
 check(not stray.pool_live,"Untargeted Qi still expires normally")
 var enemy=spawn(Vector3(0,0,-24))
 await aim_at(enemy.combat_bounds().get_center())
 p.active_ability.primary_tab_target=weakref(enemy)
 for cycle in 2:
  begin(skill);finish(skill);step_qi(300)
 await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created;var misses=pool.misses
 for cycle in 4:
  begin(skill);finish(skill);step_qi(300)
 await frames(2)
 check(pool.created==created and pool.misses==misses and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated homing volleys reuse warmed nodes, resources and projectile capacity")
 # Faster fleeing targets must not hold leases forever or grow the warmed pool.
 focused_impacts.clear();begin(skill);finish(skill)
 var fleeing_before=enemy.hp
 var fleeing_result:Dictionary=releases[0].shot.attack_ticket.get("magic_result",{})
 var deadline=ceili(releases[0].shot.flight_life/DT)+24
 for tick in deadline:
  army.set_pose(enemy.handle,home+Vector3(0,0,-24-40.0*tick*DT),0);army.sync_targets()
  step_qi(1)
 check(enemy.hp<fleeing_before and focused_impacts.count(enemy.get_instance_id())==3,"All three blasts catch a continuously fleeing 40 m/s target by the flight deadline plus its impact animation")
 check(releases.all(func(row):return not row.shot.pool_live) and pool.created==created and pool.misses==misses,"Fleeing-target chase returns every lease without growing the warmed pool")
 if not fleeing_result.is_empty():check(fleeing_result.pending==0 and fleeing_result.hit,"Fleeing-target cast completes its result once")
 army.set_pose(enemy.handle,home+Vector3(0,0,-24),0);army.sync_targets()
 await aim_at(enemy.combat_bounds().get_center())
 # Homing guarantees arrival; the target's ordinary native dodge still decides damage.
 game.model.balance.enemy_profiles[str(Roles.SLIME)]={"dodge_chance":100.0};army.refresh_kits()
 var before=enemy.hp
 var control=p.attack_chain.make_ticket("qi_dodge_control");control.accuracy=0
 enemy.take_hit(1,Vector3.FORWARD,false,control)
 check(enemy.hp==before,"Native dodge control rejects damage at 100% evasion")
 begin(skill);finish(skill)
 var result:Dictionary=releases[0].shot.attack_ticket.get("magic_result",{})
 step_qi(300)
 check(enemy.hp==before and releases.all(func(row):return not row.shot.pool_live),"Qi reaches a dodging target but does not force damage or retry a rejected hit")
 if not result.is_empty():check(result.pending==0 and not result.hit,"A dodged Qi volley completes as a miss")
 game.model.balance.enemy_profiles[str(Roles.SLIME)]={"dodge_chance":0.0};army.refresh_kits()
 var contact=expected_aim(enemy,enemy.global_position+Vector3.BACK*20)
 config.position=contact+Vector3.BACK*.0005;config.target=enemy;config.hit_radius=0.0
 before=enemy.hp
 var precise=pool.launch(p,skill.Shot,skill.projectile_profile(),config)
 precise._physics_process(DT)
 check(not precise.pool_live and enemy.hp<before,"A zero-radius blast resolves its final submillimeter instead of holding a lease forever")
 qi_samples.sort()
 var report={"checks":checks,"failures":failures,"projectile_step_p95_us":qi_samples[floori(qi_samples.size()*.95)],"projectile_step_max_us":qi_samples.back(),"pool_misses":pool.misses}
 FileAccess.open(QI_REPORT+("headless" if DisplayServer.get_name()=="headless" else "desktop")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("QI_TARGETING_RESULT ",JSON.stringify(report));quit(1 if failures else 0)

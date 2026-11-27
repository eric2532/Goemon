extends "res://tests/forest-shrine/crossgate_native_skill_pattern_test.gd"

const REPORT="res://build/Other Files/Asset Toolkit/Magic Mouse Target/"
var releases:Array=[]
var focused_impacts:Array=[]

func aim_at(point:Vector3):
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,4,8)
 camera.look_at(point);camera.make_current()
 await physics_frame

func begin(skill:Node):
 skill.cancel(true);skill.clear_cooldowns();releases.clear()
 game.player.attack_chain.reset();game.player.mana=game.player.max_mana
 skill.start_cast();skill.ticket.skill_count=3

func finish(skill:Node):
 for i in 300:
  skill.tick(DT)
  if not skill.is_attacking() and skill.spirit_targets.is_empty():break

func first_is(target:Ninja)->bool:
 if releases.is_empty():return false
 return releases[0].target==target if releases[0].target!=null else releases[0].position.distance_to(target.global_position)<.01

func all_on(target:Ninja)->bool:
 return not releases.is_empty() and releases.all(func(row):return row.target==target if row.target!=null else row.position.distance_to(target.global_position)<.01)

func run():
 create_timer(240).timeout.connect(func():printerr("MAGIC_MOUSE_TARGET_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REPORT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.refresh_kits()
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
 var timings=[]
 for id in [p.RogueRoster.KAZI_ID,p.RogueRoster.SHIN_ID,p.RogueRoster.RUBY_ID,p.RogueRoster.MAZE_ID]:
  p.select_character(id);fresh();p.position=home;p.velocity=Vector3.ZERO
  await driver.advance(20,advance)
  army.clear();game.model.enemies.clear();army.refresh_kits();await frames(2)
  game.enemies=game.enemies.filter(is_instance_valid)
  var near=spawn(Vector3(6,0,-6));var hovered=spawn(Vector3(0,0,-14))
  await physics_frame
  p.active_ability.primary_tab_target=weakref(near)
  for spell_id in SPELLS:
   p.active_ability.primary_tab_target=weakref(near)
   var skill=p.spell_loadout._instance(spell_id).controller
   var label="%d %s"%[id,spell_id]
   await aim_at(AttackChain.aim_point(hovered))
   check(game.enemy_near_crosshair(200)==hovered,label+" fixture points at the farther enemy")
   var started=Time.get_ticks_usec();begin(skill);timings.append(Time.get_ticks_usec()-started)
   check(skill.aim_target()==hovered,label+" captures mouse priority ahead of the nearer Tab lock")
   await aim_at(AttackChain.aim_point(near))
   finish(skill)
   check(first_is(hovered),label+" releases first at the cast's mouse target after aim moves")
   check(all_on(hovered),label+" sends every shot or effect to the chosen enemy")
   if spell_id in ["kazi/qigong","maze/qigong","kazi/moon"]:check(releases.size()==3,label+" retains all three projectiles while focusing one enemy")
   if spell_id=="uru/spirit":check(releases.size()==p.model.normal_attack_pattern().contacts.size(),label+" focuses every native strike on the chosen enemy")
   if not releases.is_empty() and releases[0].shot.attack_ticket.has("magic_result"):
    check(releases[0].shot.attack_ticket.magic_result.pending==releases.size(),label+" tracks every focused projectile in the magic combo")
   if spell_id in ["kazi/qigong","maze/qigong"]:
    focused_impacts.clear()
    var result:Dictionary=releases[0].shot.attack_ticket.get("magic_result",{})
    for i in 180:
     for row in releases:
      if row.shot.pool_live:row.shot._physics_process(DT)
    check(focused_impacts.count(hovered.get_instance_id())==3,label+" lands all three Qi blasts on the selected native enemy")
    if not result.is_empty():check(result.pending==0 and result.hit,label+" completes the focused cast and its hit combo")
   # The same prepared effects must be reusable on a new mouse selection.
   begin(skill);finish(skill)
   check(all_on(near),label+" repeated cast takes the new mouse target")
   await aim_at(home+Vector3(-40,2,-10))
   begin(skill);finish(skill)
   check(all_on(near),label+" empty mouse aim uses the blue-triangle Tab target")
   p.active_ability.primary_tab_target=weakref(hovered)
   begin(skill)
   var toward=hovered.global_position-p.global_position;toward.y=0
   check(p.facing.dot(toward.normalized())>.999,label+" faces the Tab target during its cast gesture")
   finish(skill)
   check(all_on(hovered),label+" Tab can focus the farther enemy without mouse hover")
   p.active_ability.primary_tab_target=null
   begin(skill);finish(skill)
   check(first_is(near),label+" empty aim falls back to the nearest eligible enemy")
   await aim_at(AttackChain.aim_point(hovered))
   begin(skill);hovered.dead=true;finish(skill);hovered.dead=false
   check(first_is(near),label+" target death falls back safely")
   begin(skill)
   var saved:Vector3=hovered.position
   hovered.position=home+Vector3(0,0,-240)
   finish(skill);hovered.position=saved
   check(first_is(near),label+" out-of-range targets cannot override spell range")
   var cell=game.model.cell_of(hovered.global_position/game.model.falan_scale)
   game.model.visible_cells.erase(cell)
   begin(skill);finish(skill)
   game.model.visible_cells[cell]=true
   check(first_is(near),label+" hidden enemies cannot take mouse priority")
   begin(skill)
   var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new()
   box.size=Vector3(4,15,.5);shape.shape=box;wall.add_child(shape);game.add_child(wall)
   wall.global_position=home+Vector3(0,3,-7)
   await physics_frame;await physics_frame
   finish(skill)
   var ignores_cover=not skill.kind.is_empty() and p.RogueRoster.uses_crossgate_spells(id)
   check(first_is(hovered if ignores_cover else near),label+" preserves its existing cover rule when cover blocks the selected target")
   wall.queue_free();await physics_frame;await physics_frame
   begin(skill)
   var original=AttackChain.enemy_candidates(game,home,192).duplicate()
   var terrain_exclude:Array[RID]=[]
   var before=original.duplicate();var chosen=skill.nearest_targets(p.global_position+Vector3.UP,terrain_exclude,3)
   check(original==before and chosen==[hovered],label+" focusing does not reorder the shared snapshot")
   skill.cancel(true)
   p.active_ability.primary_tab_target=weakref(hovered)
   p.ai_controlled=true
   begin(skill)
   check(skill.aim_target()==null,label+" AI casts do not borrow the player's pointer or Tab lock")
   p.ai_controlled=false;skill.cancel(true)
  p.spell_loadout.equip(id,"special_4","kazi/fire")
  var fire=p.spell_loadout._instance("kazi/fire").controller
  await aim_at(AttackChain.aim_point(hovered))
  fire.clear_cooldowns();p.mana=p.max_mana;releases.clear();tap("special_4")
  check(p.spell_loadout.current!=null and fire.aim_target()==hovered,"Fighter %d casts mouse-targeted Fire through the normal input route"%id)
  for i in 300:
   p.spell_loadout.tick(DT)
   if p.spell_loadout.current==null:break
  check(first_is(hovered),"Fighter %d normal input keeps mouse priority through the full spell loadout"%id)
  if DisplayServer.get_name()!="headless" and id==p.RogueRoster.KAZI_ID:
   for row in releases:
    if row.shot.pool_live:row.shot._physics_process(.15)
   game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(REPORT+"mouse-priority-fire.png")==OK,"Captured the farther mouse-targeted fire cast")
  fire.cancel(true)
 timings.sort();print("MAGIC_MOUSE_CAST_US p95=",timings[floori(timings.size()*.95)]," max=",timings.back())
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MAGIC_MOUSE_TARGET_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

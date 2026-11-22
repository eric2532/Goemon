extends "res://tests/forest-shrine/crossgate_native_skill_pattern_test.gd"
const EVIDENCE="res://build/Other Files/Asset Toolkit/Magic Power/"
const MAGIC=["uru/spirit","kazi/fire","kazi/ice","kazi/wind","kazi/meteor"]
var spell_times:Array[int]=[]

func cast_spell(caster:Hero,id:String)->Array:
 var skill=caster.spell_loadout._instance(id).controller
 skill.cancel(true);skill.clear_cooldowns();caster.attack_chain.reset();shots.clear()
 caster.mana=caster.max_mana
 var started=Time.get_ticks_usec();skill.start_cast()
 for tick in 360:
  skill.tick(DT)
  if not skill.is_attacking() and skill.spirit_targets.is_empty():break
 spell_times.append(Time.get_ticks_usec()-started)
 return shots.duplicate()

func deliver(released:Array):
 for tick in 600:
  for shot in released:
   if shot.pool_live:shot._physics_process(DT)

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(EVIDENCE+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(240).timeout.connect(func():printerr("MAGIC_POWER_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EVIDENCE)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var state=p.team_progression
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 check(not state.spend_stat("magic_power"),"Magic cannot be purchased without points")
 state.stat_points=2
 check(state.spend_stat("magic_power") and state.stat_points==1 and is_equal_approx(state.stat_magic_multiplier(),1.15) and state.stat_damage_multiplier()==1,"One Magic power point adds 15% magic without physical damage")
 state.level=5
 check(is_equal_approx(state.stat_magic_multiplier(),1.27) and is_equal_approx(state.stat_damage_multiplier(),1.12),"Automatic level growth adds once to each independent damage stat")
 state.reset()
 check(state.stat_ranks.magic_power==0 and state.stat_points==0 and state.stat_magic_multiplier()==1,"New runs reset Magic power")
 for fighter in p.RogueRoster.CROSSGATE:
  p.select_character(fighter);fresh();state.reset();game.reset_character_tuning(fighter);game.update_character_tuning(fighter,"critical_chance",0)
  p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
  await driver.advance(20,advance)
  army.clear();game.model.enemies.clear();army.refresh_kits();await frames(2);game.enemies=game.enemies.filter(is_instance_valid)
  var victim=spawn(Vector3(0,0,-14))
  var base=p.damage_multiplier()
  for allocation in ["baseline","attack","magic_power"]:
   state.stat_ranks.attack=0;state.stat_ranks.magic_power=0
   if allocation!="baseline":state.stat_points=1;check(state.spend_stat(allocation),"Spend "+allocation)
   var magic_factor=1.15 if allocation=="magic_power" else 1.0
   var physical_factor=1.15 if allocation=="attack" else 1.0
   check(is_equal_approx(p.damage_multiplier(),base*physical_factor) and is_equal_approx(p.magic_damage_multiplier(),base*magic_factor),"Fighter %d keeps physical/magic allocations separate: %s"%[fighter,allocation])
   for id in MAGIC:
    var released=cast_spell(p,id);var before=victim.hp
    check(not released.is_empty(),"Fighter %d releases %s (%s)"%[fighter,id,allocation])
    var expected=((5000.0 if id=="uru/spirit" else 100.0)+50.0*magic_factor)*base
    deliver(released)
    check(is_equal_approx(before-victim.hp,expected),"Fighter %d %s %s actual damage %.2f = %.2f"%[fighter,id,allocation,before-victim.hp,expected])
   for id in ["kazi/qigong","kazi/moon"]:
    var released=cast_spell(p,id)
    var expected=Skills.normal_damage(p)*(1.5 if id=="kazi/qigong" else 1.4)*base*physical_factor
    check(not released.is_empty() and released.all(func(shot):return is_equal_approx(shot.damage,expected)),"Fighter %d %s retains physical scaling (%s)"%[fighter,id,allocation])
    for shot in released:
     if shot.pool_live:shot.retire()
  p.spell_loadout.cancel()
 # The real panel exposes the new rank, spend button and separate damage values.
 var saved_hash=FileAccess.get_sha256(game.settings_path)
 state.reset();state.stat_points=2;game.show_status_panel();await frames()
 var panel=game.status_panel
 panel.buttons.magic_power.pressed.emit()
 check(state.stat_points==1 and state.stat_ranks.magic_power==1 and panel.values[3].text=="x%.2f"%p.magic_damage_multiplier(),"The real Magic power button spends one shared point and updates magic damage")
 await picture("magic-power-stats")
 root.size=Vector2i(960,640);await frames()
 check(root.get_visible_rect().encloses(panel.panel.get_global_rect()),"Six stats fit the smaller window")
 for button_ in panel.buttons.values():check(panel.panel.get_global_rect().encloses(button_.get_global_rect()),"Every stat button fits")
 await picture("magic-power-stats-small")
 game.close_status_panel();await frames();root.size=Vector2i(1280,800)
 check(FileAccess.get_sha256(game.settings_path)==saved_hash,"Run-only Magic power preserves saved preferences")
 # Native copies snapshot both damage channels, including their summon factor.
 p.select_character(p.RogueRoster.MAZE_ID);fresh();p.position=home;p.facing=Vector3.FORWARD
 state.reset();state.stat_ranks.attack=4;state.stat_ranks.magic_power=2
 p.spell_loadout.equip(p.character_id,"special_4","kazi/fire")
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0);mirrors.prepare_count()
 check(mirrors.cast(),"Native copies summon with separate magic inheritance")
 var copied=p.magic_damage_multiplier()*.85;var physical=p.damage_multiplier()*.85
 var copied_fire=100.0*p.base_damage_multiplier()*.85+50.0*copied
 for body in mirrors.bodies:
  check(is_equal_approx(body.magic_damage_multiplier(),copied) and is_equal_approx(body.damage_multiplier(),physical),"A copy snapshots each damage channel with the summon multiplier once")
 state.stat_ranks.magic_power=3;state.stat_ranks.attack=5
 check(mirrors.bodies.all(func(body):return is_equal_approx(body.magic_damage_multiplier(),copied) and is_equal_approx(body.damage_multiplier(),physical)),"Later allocations do not rewrite summoned damage snapshots")
 var simultaneous=[]
 for body in mirrors.bodies:simultaneous.append_array(cast_spell(body,"kazi/fire"))
 check(simultaneous.size()>=mirrors.bodies.size() and simultaneous.all(func(shot):return is_equal_approx(shot.damage,copied_fire/shot.hero.model.normal_attack_pattern().contacts.size())),"Simultaneous copies add their snapshotted base magic damage to their spell damage")
 deliver(simultaneous);mirrors.dispose();await frames(4)
 # Warm both paths before checking retained resources and pool misses.
 for id in MAGIC:deliver(cast_spell(p,id))
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var misses=pool.misses
 for repeat_ in 6:
  for id in MAGIC:deliver(cast_spell(p,id))
 await frames(3)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated magic casts retain no additional nodes/resources")
 check(pool.misses==misses,"Repeated and simultaneous magic use prepared projectile pools")
 spell_times.sort();print("MAGIC_CAST_US p95=",spell_times[floori((spell_times.size()-1)*.95)]," max=",spell_times.back())
 print("MAGIC_POWER_RESULT checks=%d failures=%d"%[checks,failures])
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

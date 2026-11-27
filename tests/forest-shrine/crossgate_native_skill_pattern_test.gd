extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"

const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const SPELLS=["kazi/qigong","maze/qigong","kazi/moon","kazi/fire","kazi/ice","kazi/wind","kazi/meteor","uru/spirit"]
var shots:Array=[]

func spell_ids()->Array:return SPELLS

func run():
 create_timer(240).timeout.connect(func():printerr("NATIVE_SKILL_PATTERN_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var fx=game.crowd.army.presentation
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.refresh_kits()
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 var timings=[]
 for id in p.RogueRoster.CROSSGATE:
  if id in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if id==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  p.select_character(id);fresh();game.reset_character_tuning(id);game.update_character_tuning(id,"critical_chance",0)
  if id==37:p.model.select_stance(1)
  p.position=home;p.velocity=Vector3.ZERO;await driver.advance(20,advance)
  if id==36:
   p.active_ability.set_weapon(p.RogueRoster.MazeWeapon.KUNAI)
   var orb=p.spell_loadout._instance("kazi/qigong").controller
   p.active_ability.set_weapon(p.RogueRoster.MazeWeapon.KATANA)
   check(pool.all[orb.pool_key].size()>=2,"The pool prepares two overlapping level-one Qi casts")
   var misses=pool.misses;shots.clear()
   for cast_index in 2:
    p.mana=p.max_mana
    orb.clear_cooldowns();orb.start_cast()
    for tick in 180:orb.tick(DT)
   check(shots.size()==2 and shots.all(func(shot):return shot.pool_live),"Two level-one casts retain their two projectiles across the native gestures")
   check(pool.misses==misses,"The weapon change creates no combat-time pool misses")
   orb.cancel(true)
  army.clear();game.model.enemies.clear();army.refresh_kits();await frames(2);game.enemies=game.enemies.filter(is_instance_valid);spawn(Vector3(0,0,-14))
  var pattern=p.model.normal_attack_pattern()
  for spell_id in spell_ids():
   p.spell_loadout.equip(id,"special_4",spell_id)
   var skill=p.spell_loadout.instances["%d:%s"%[id,spell_id]].controller
   p.mana=p.max_mana
   skill.clear_cooldowns();shots.clear();p.attack_chain.reset();skill.start_cast()
   check(skill.native_pattern.contacts==pattern.contacts and skill.native_pattern.pose==pattern.pose,"Fighter %d %s snapshots the native contact timeline and animation"%[id,spell_id])
   var release_times=[];var count_before=0
   for i in 300:
    var started=Time.get_ticks_usec();skill.tick(DT);timings.append(Time.get_ticks_usec()-started)
    if shots.size()>count_before:release_times.append(skill.native_elapsed);count_before=shots.size()
    if not skill.is_attacking() and skill.spirit_targets.is_empty():break
   var quota=3 if spell_id=="kazi/moon" else 1 if spell_id in ["kazi/qigong","maze/qigong"] else pattern.contacts.size()
   var expected_damage=Skills.normal_damage(p)*(1.4 if spell_id=="kazi/moon" else 1.5)
   var expected_releases=mini(quota,pattern.contacts.size())
   if spell_id=="uru/spirit":expected_damage=5050.0/pattern.contacts.size()
   elif not skill.kind.is_empty():expected_damage=150.0/float(pattern.contacts.size())/float({"fire":1,"ice":3,"wind":4,"meteor":2}[skill.kind])
   check(shots.size()==quota,"Fighter %d %s respects its cast quota across native strikes"%[id,spell_id])
   if spell_id in ["kazi/qigong","maze/qigong"]:
    check(shots.all(func(shot):return float(shot.visual.get_instance_shader_parameter("gold_palette"))==0.0 and float(shot.visual.get_instance_shader_parameter("uru_palette"))==0.0 and shot.visual.get_instance_shader_parameter("qi_tint")==Color.WHITE),"Fighter %d %s defaults to the regular blue Qi palette"%[id,spell_id])
   check(shots.all(func(shot):return is_equal_approx(shot.damage,expected_damage)),"Fighter %d %s respects the per-projectile or divided per-cast damage contract"%[id,spell_id])
   check(release_times.size()==expected_releases and release_times.all(func(at):return pattern.contacts.any(func(contact):return absf(at-float(contact))<=DT*skill.cast_speed*p.attack_speed_multiplier()+.00001)),"Fighter %d %s emits only at actual native contact markers"%[id,spell_id])
   skill.cancel(true);check(shots.all(func(shot):return not shot.pool_live),"Cancelling clears every repeated projectile")
  # A one-hit override consumes one native contact, not a full multi-contact hop.
  p.spell_loadout.cancel();p.active_ability.cancel(true);p.active_ability.clear_cooldowns();p.attack_chain.reset()
  army.clear();game.model.enemies.clear();army.refresh_kits();fx.effects.clear();victims.clear();await frames(2);game.enemies=game.enemies.filter(is_instance_valid)
  var victim=spawn(Vector3(0,0,-3.5));var before=victim.hp;var kit=p.active_ability
  p.mana=p.max_mana
  kit.start_combo();kit.ticket.skill_count=1;kit.ticket.combo_splash_radius=0
  for i in 300:
   kit.tick(DT);army.flush_presentation()
   if not kit.is_attacking():break
  check(is_equal_approx(before-victim.hp,.8*Skills.normal_damage(p)),"Fighter %d combo keeps the per-hit damage contract (got %.2f, expected %.2f)"%[id,before-victim.hp,.8*Skills.normal_damage(p)])
  print("NATIVE_SKILL_PATTERN fighter=",id," contacts=",pattern.contacts," volleys=",pattern.contacts.size())
 timings.sort();print("NATIVE_SKILL_TICK_US p95=",timings[floori(timings.size()*.95)]," max=",timings.back())
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CROSSGATE_NATIVE_SKILL_PATTERN_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

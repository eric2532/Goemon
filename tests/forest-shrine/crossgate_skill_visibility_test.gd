extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Hound=preload("res://scripts/forest/crowd/hound_sprites.gd")
const MIRROR="blademaster/mirror-image"
const OUT="res://build/Other Files/Cross Gate Skill Visibility/"

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(180).timeout.connect(func():printerr("SKILL_VISIBILITY_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;var loadout=p.spell_loadout;var army=game.army_runtime
 var saved={"36":{"equip":"goemon/dash","surge":"kazi/fire","sky_strike":MIRROR},"39":{"equip":"edo/beam"}}
 game.settings.spell_loadouts=saved.duplicate(true)
 game.settings.skill_balance={"goemon/dash":{"travel_speed":1.5},MIRROR:{"size":1.4}}
 game.save_settings();game.load_settings()
 check(game.settings.spell_loadouts==saved,"Legacy saved assignments survive reload")
 check(game.settings.skill_balance.has("goemon/dash"),"Hidden skill tuning survives reload")
 check(not loadout.equip(36,"special_5","goemon/dash") and game.settings.spell_loadouts==saved,"Retired skills cannot be newly equipped or change saved data")
 for id in Catalog.Roster.selection_ids():
  var slots=loadout.assignments(id)
  check(slots.values().all(func(skill):return Catalog.available(Catalog.all()[skill])),"Fighter %d only activates Cross Gate skills or Mirror Image"%id)
 check(not loadout.assignments(36).has("equip") and loadout.assignments(36).surge=="kazi/fire","Hidden override restores the native slot while preserving a Cross Gate override")
 check(loadout.assignments(36).sky_strike==MIRROR and loadout.assignments(39).sky_strike==MIRROR,"Maze and Saizo retain Mirror Image")
 p.select_character(36);await frames()
 check(not loadout.instances.has("36:goemon/dash") and loadout.instances.has("36:"+MIRROR),"Hidden skill is not prepared; Mirror Image is ready")
 game.show_rogue_roster()
 var picker=load("res://scripts/spells/spell_picker.gd").new();picker.game=game;game.menu.add_child(picker);await frames()
 var expected=Catalog.all().keys().filter(func(id):return Catalog.available(Catalog.all()[id]) and id not in [Catalog.RECOVERY,Catalog.MAZE_QI])
 for option in picker.choices.values():
  var ids=[]
  for i in range(1,option.item_count):ids.append(option.get_item_metadata(i))
  check(ids==expected and ids.has(MIRROR),"Every skill picker contains exactly Cross Gate choices plus Mirror Image")
 check(picker.choices.equip.selected==0 and picker.choices.equip.get_item_text(0).contains("暗殺"),"Hidden saved skill displays the restored native ability")
 picker.choices.equip.get_popup().popup();await capture("crossgate-loadout");picker.choices.equip.get_popup().hide()
 picker.queue_free();await frames()
 game.show_skill_balance(false,"goemon/dash");await frames()
 var editor=game.menu.find_child("SkillBalance",true,false);var balance=editor.find_child("BalanceSkill",true,false)
 var visible=[]
 for i in balance.item_count:visible.append(balance.get_item_metadata(i))
 check(visible==Skills.all().keys().filter(func(id):return Catalog.available(Skills.all()[id])),"Balance lists exactly Cross Gate skills and Mirror Image, including native stance skills")
 check(editor.skill_id!="goemon/dash" and Skills.all().has("goemon/dash"),"Opening an old skill falls back safely without deleting its definition")
 await capture("crossgate-balance")
 game.resume();game.close_rogue_roster()
 loadout.equip(36,"special_4","kazi/ice")
 check(game.settings.spell_loadouts["36"].equip=="goemon/dash" and game.settings.spell_loadouts["39"].equip=="edo/beam","Editing an allowed slot preserves hidden saved assignments")
 var home=Vector3(-120,0,125);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 game.camera_rig.set_physics_process(false)
 game.camera_rig.camera.global_position=home+Vector3(10,20,30);game.camera_rig.camera.look_at(home+Vector3.UP*2)
 var fx=game.crowd.army.presentation
 for character in [36,39]:
  p.select_character(character);fresh();p.position=home;await frames()
  var mirrors=loadout.instances["%d:%s"%[character,MIRROR]].controller.mirrors
  fx.clear();army.presentation_events.clear()
  loadout.clear_cooldowns();loadout.number_input(3,true);loadout.number_input(3,false)
  for i in 100:p._physics_process(1.0/60)
  check(mirrors.handles.size()==5,"Number 3 summons five copies for fighter %d"%character)
  var events=army.presentation_events.filter(func(event):return event.kind=="hound_summon")
  check(events.size()==5 and mirrors.bodies.all(func(body):return events.any(func(event):return event.position.is_equal_approx(body.global_position))),"Each successful copy queues the pet effect at its arrival point")
  game.crowd.present_army(army.render_snapshot(),army.presentation_events);army.presentation_events.clear();fx.tick(.12)
  check(fx.batches.hound_summon.multimesh.visible_instance_count==5,"All five effects share the existing summon batch")
  check(fx.voices.filter(func(voice):return voice.playing and voice.stream==Hound.SUMMON_SOUND).size()==1,"Five copies share one pet summon sound")
  await capture("mirror-arrival-%d"%character)
  fx.tick(Hound.SUMMON_LIFE)
  check(not fx.effects.any(func(effect):return effect.kind=="hound_summon") and fx.batches.hound_summon.multimesh.visible_instance_count==0,"Summoning effects expire and release their slots")
  var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  var bodies=mirrors.bodies.duplicate();var times=[]
  for cycle in 8:
   var started=Time.get_ticks_usec()
   check(mirrors.cast(),"Repeated summon succeeds")
   times.append((Time.get_ticks_usec()-started)/1000.0)
   game.crowd.present_army(army.render_snapshot(),army.presentation_events);army.presentation_events.clear();fx.tick(Hound.SUMMON_LIFE)
  check(mirrors.bodies==bodies and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated summons reuse bodies and retain no extra nodes/resources")
  times.sort();print("MIRROR_CAST character=",character," max_ms=",times[-1])
  p.position=Vector3(100000,0,100000)
  check(not mirrors.cast() and army.presentation_events.is_empty(),"Rejected placement emits no summon effects")
  mirrors.clear();fx.clear();army.presentation_events.clear()
 var path=game.settings_path;game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("SKILL_VISIBILITY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

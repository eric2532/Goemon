extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Hit Source Review/"
const Roster=preload("res://scripts/rogue_roster.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const STEP=1.0/60
var shots:Array=[]
var target:Ninja
var fx:Node
var army:Node
var stage="current"

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 fx.draw_effects()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Capture "+name_)

func clear_feedback():
 fx.clear()
 army.presentation_events.clear();army.event_log.clear()

func flush_feedback():
 army.presentation_dirty=true
 army.flush_presentation()
 fx.draw_effects()

func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--stage="):stage=arg.trim_prefix("--stage=")
 create_timer(120).timeout.connect(func():printerr("CRITICAL_SKILL_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800)
 await setup_fixture()
 game.settings.forest_pet_loadout=[]
 game.set_process(false);game.explorer_helpers.set_process(false)
 army=game.army_runtime;army.set_process(false);army.set_physics_process(false)
 game.ui.hide();game.forest_ui.hide();game.music.stop()
 fx=game.crowd.army.presentation
 game.training_dummy.hide();game.training_dummy.position=ORIGIN+Vector3.DOWN*100
 game.training_dummy.collision_layer=0;game.enemies.erase(game.training_dummy)
 army.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 army.set_navigation(92301,{"width":0})
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-12))
 row.hp=10000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_targets();target=game.actors[row.id]
 army.record_events=true
 game.camera_rig.camera.global_position=ORIGIN+Vector3(9,8,10)
 game.camera_rig.camera.look_at(target.global_position+Vector3.UP)
 game.player.select_character(Roster.LANCELOT_ID);fresh()
 var kit=game.player.active_ability
 Pool.service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 for chance in [0,100]:
  game.character_tuning={"lancelot":{"critical_chance":chance}}
  for volley in [false,true]:
   kit.cancel();kit.clear_cooldowns();game.player.attack_chain.reset();shots.clear();clear_feedback()
   game.player.mana=game.player.max_mana
   if volley:
    game.player.position=ORIGIN;game.player.velocity=Vector3.DOWN*5
    for i in 20:game.player._physics_process(STEP)
    check(game.player.is_on_floor(),"Lancelot volley fixture stands on the ground")
    kit.start_random_shot()
   else:kit.start_attack()
   for i in 600:
    kit.tick(STEP)
    for shot in shots:
     if shot.pool_live:shot._physics_process(STEP)
    if not kit.is_attacking() and shots.all(func(shot):return not shot.pool_live):break
   var damage=army.event_log.filter(func(event):return event.kind=="damage")
   var expected=int(preload("res://scripts/spells/skill_levels.gd").stats("lancelot/random-shot",1).count) if volley else 1
   check(shots.size()==expected,"Lancelot releases expected basic/volley arrows at %d%%"%chance)
   check(damage.size()==shots.size() and damage.all(func(event):return event.critical==(chance==100)),"Every actual arrow contact preserves its critical roll at %d%%"%chance)
   flush_feedback()
   var bursts=fx.effects.filter(func(effect):return effect.kind=="critical")
   check(bursts.size()==(damage.size() if chance==100 else 0),"Lancelot basic/volley contacts emit one burst per critical")
   if not volley:await capture("lancelot-"+str(chance)+"-"+stage)
   army.event_log.clear()
 var loadout=game.player.spell_loadout
 for spell in ["kazi/qigong","kazi/fire","kazi/ice","kazi/wind","kazi/meteor"]:
  for chance in [0,100]:
   kit.cancel();fresh();game.character_tuning={"lancelot":{"critical_chance":chance}}
   game.player.mana=game.player.max_mana
   check(loadout.equip(Roster.LANCELOT_ID,"equip",spell),"Lancelot equips "+spell)
   loadout.clear_cooldowns();shots.clear();clear_feedback();loadout._cast(spell,"equip")
   for i in 600:
    loadout.tick(STEP)
    for shot in shots:
     if shot.pool_live:shot._physics_process(STEP)
    if loadout.current==null and shots.all(func(shot):return not shot.pool_live):break
   var damage=army.event_log.filter(func(event):return event.kind=="damage")
   check(not damage.is_empty() and damage.all(func(event):return event.critical==(chance==100)),"Actual equipped "+spell+" preserves its %d%% critical rolls"%chance)
   flush_feedback()
   check(fx.effects.any(func(effect):return effect.kind=="critical")== (chance==100),"Actual equipped "+spell+" sparks only on critical damage")
   if chance==100 and spell=="kazi/fire":await capture("lancelot-fire-"+stage)
   loadout.cancel()
 loadout.equip(Roster.LANCELOT_ID,"equip","")
 # Every damaging catalog skill uses the same ticket/contact path.
 var skills=preload("res://scripts/spells/skill_balance.gd")
 game.character_tuning={"lancelot":{"critical_chance":100}}
 for id in skills.all():
  if not skills.supports(id,"damage"):continue
  game.player.attack_chain.reset();clear_feedback()
  var ticket=game.player.attack_chain.make_ticket(id)
  target.take_hit(1,Vector3.FORWARD,false,ticket);flush_feedback()
  check(fx.effects.any(func(effect):return effect.kind=="critical"),"Shared skill contact sparks: "+id)
 # Exploration scales world positions; the visibility table stays in map space.
 var saved_cells=game.model.visible_cells.duplicate()
 var point:Vector3=target.global_position+Vector3.UP
 game.model.falan_scale=1.3;game.model.visible_cells.clear()
 game.model.visible_cells[game.model.cell_of(point/1.3)]=true
 check(game.forest_point_visible(point) and not game.model.visible_at(point),"Scaled-world fixture distinguishes visible map/world coordinates")
 clear_feedback();kit.cancel();shots.clear();kit.start_attack()
 var before:float=target.hp
 for i in 300:
  kit.tick(STEP)
  for shot in shots:
   if shot.pool_live:shot._physics_process(STEP)
  if not kit.is_attacking() and not shots.is_empty() and shots.all(func(shot):return not shot.pool_live):break
 check(shots.size()==1 and target.hp<before,"A real arrow hits the visible scaled-world target")
 flush_feedback()
 check(fx.effects.any(func(effect):return effect.kind=="critical"),"Visible scaled-world arrow contacts retain critical sparks")
 check(fx.labels.any(func(label):return label.visible),"Visible scaled-world contacts retain damage numbers")
 await capture("lancelot-scaled-"+stage)
 clear_feedback();game.damage_number(point,2,false,true)
 check(fx.effects.any(func(effect):return effect.kind=="critical"),"Shared direct skill damage retains scaled-world critical sparks")
 clear_feedback();game.model.visible_cells.clear()
 target.take_hit(1,Vector3.FORWARD,false,game.player.attack_chain.make_ticket("crossgate_bow"));flush_feedback()
 check(fx.effects.is_empty() and not fx.labels.any(func(label):return label.visible),"Hidden scaled-world contacts still consume no spark or number slots")
 game.model.visible_cells=saved_cells;game.model.falan_scale=1.0
 for chance in [0,100]:
  clear_feedback()
  var ticket={"quiet_contact":true,"critical_chance":chance}
  target.take_hit(1,Vector3.FORWARD,false,ticket);flush_feedback()
  check(fx.effects.size()==(1 if chance==100 else 0) and (fx.effects.is_empty() or fx.effects[0].kind=="critical"),"Quiet skills suppress ordinary feedback while retaining critical sparks at %d%%"%chance)
  game.training_dummy.position=ORIGIN+Vector3(2,0,-3)
  clear_feedback();game.training_dummy.take_hit(1,Vector3.FORWARD,false,ticket)
  check(fx.effects.size()==(1 if chance==100 else 0),"Practice target retains quiet-skill critical sparks at %d%%"%chance)
 print("CRITICAL_SKILL_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

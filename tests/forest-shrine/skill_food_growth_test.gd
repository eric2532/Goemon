extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Skills=preload("res://scripts/spells/skill_balance.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Loot=preload("res://scripts/forest/exploration_loot.gd")
const OUT="res://build/Other Files/Skill Size Revision/Growth/"
const DT=1.0/60
var home=Vector3(-120,0,125)
var victims:Array[int]=[]
var driver
var samples:Array[int]=[]

func advance(_delta:float):
 var started=Time.get_ticks_usec()
 game.player._physics_process(DT)
 game.army_runtime.flush_presentation()
 game.crowd.army.presentation.tick(DT)
 samples.append(Time.get_ticks_usec()-started)

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.exploration_loot.sync_buffs()
 var fx=game.crowd.army.presentation
 for effect in fx.effects:
  if effect.kind=="shin_sure_strike":effect.age=5*fx.SURE_STRIKE_FRAME_TIME
  elif effect.kind=="shin_double_edge":effect.age=5*fx.DOUBLE_EDGE_FRAME_TIME
  elif effect.kind=="shin_combo":effect.age=6*fx.SHIN_COMBO_FRAME_TIME
  elif effect.kind=="kazi_combo":effect.age=5*fx.COMBO_FRAME_TIME
 fx.tick(0)
 game.forest_ui.sync();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)

func spawn(at:Vector3,kind:int=0)->int:
 at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(kind,at);row.hp=1000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals()
 return row.id

func shine_size(kit)->float:
 var glow:Sprite3D=kit.cast_model().combo_glow
 var cell=glow.texture.get_size()/Vector2(glow.hframes,glow.vframes)
 return maxf(cell.x,cell.y)*glow.pixel_size*glow.global_basis.get_scale().x

func run():
 create_timer(240).timeout.connect(func():printerr("SKILL_FOOD_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var rewards=game.model.team_progression;var loot=game.exploration_loot
 game.set_process(false);army.set_physics_process(false);army.set_process(false);loot.set_process(false)
 game.model.waves.crossgate_pet_test=true;army.refresh_kits()
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100
 game.impact_confirmed.connect(func(victim,_strength,_duration):victims.append(victim.forest_id))
 game.camera_rig.camera.global_position=home+Vector3(9,10,15);game.camera_rig.camera.look_at(home+Vector3(0,1,-3))
 p.select_character(37);fresh();rewards.reset()
 p.position=home;p.velocity=Vector3.ZERO
 await driver.advance(20,advance)
 check(Loot.FOOD_NAMES[Loot.OYAKODON]=="親子丼" and Loot.FOODS.size()==9,"親子丼 appends without changing existing food IDs")
 var base=p.attack_chain.make_ticket("shin_sure_strike")
 check(base.skill_size==1 and base.skill_hit_area==1,"A new run starts at the authored slime-size baseline")
 var hp:float=p.hp
 check(loot.eat(Loot.OYAKODON) and p.hp==hp and rewards.skill_food_stacks==1,"親子丼 at full HP adds one run stack without healing or overheal")
 var grown=p.attack_chain.make_ticket("shin_sure_strike")
 check(is_equal_approx(grown.skill_size,1.05) and is_equal_approx(grown.skill_hit_area,1.05),"One serving grows visual dimensions and hit radius by five percent")
 check(base.skill_size==1 and base.skill_hit_area==1,"A previously started cast keeps its original snapshot")
 for i in 19:loot.eat(Loot.OYAKODON)
 grown=p.attack_chain.make_ticket("shin_sure_strike")
 check(grown.skill_size==2 and grown.skill_hit_area==2,"Twenty servings add up to twice the starting size, without compounding")
 check(grown.skill_damage==base.skill_damage and not grown.has("skill_count"),"Growth changes neither damage nor explosion count")
 p.tick_food_buffs(3600)
 check(rewards.skill_food_stacks==20,"Run growth does not expire with temporary food timers")
 p.select_character(Skills.Catalog.Roster.RUBY_ID)
 check(rewards.skill_food_stacks==20 and Skills.effective(p,"kazi/combo","size")==2,"Growth follows character switches and shared skills")
 check(Skills.effective(p,Skills.Catalog.RECOVERY,"hit_area")==1,"An unsupported utility area stays unchanged")
 loot.sync_buffs()
 check(loot.buff_counts.back().text=="×20" and loot.buff_tiles.back().tooltip_text.contains("Rest of run"),"The shared food HUD shows permanent stacks and lifetime")
 await capture("oyakodon-run-stacks")
 for id in [37,40]:
  p.select_character(id);fresh();rewards.reset();game.reset_character_tuning(id)
  var kit=p.active_ability
  for polearm in ([false,true] if id==37 else [false]):
   if polearm:p.model.select_stance(2)
   check(p.model.motions.weapon==("polearm" if polearm else "sword" if id==37 else "axe"),"The native weapon and animation stay intact")
   for stacks in [0,20]:
    kit.cancel(true);army.clear();army.refresh_kits();rewards.skill_food_stacks=stacks
    p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0;p.facing=Vector3.FORWARD
    await driver.advance(20,advance)
    var near=spawn(home+Vector3(0,0,-2.7))
    var extra=spawn(home+Vector3.FORWARD*kit.melee_visual_reach()*1.6)
    var outside=spawn(home+Vector3(60,0,-9))
    var edge=spawn(home+Vector3.FORWARD*60,Roles.SLIME)
    spawn(home+Vector3(9,0,-6),Roles.SLIME)
    army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
    victims.clear();var fx=game.crowd.army.presentation;fx.effects.clear()
    kit.clear_cooldowns();kit.start_shin_area_cast()
    check(kit.clip=="6" and is_equal_approx(shine_size(kit),preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*(91.0/357.0)*(2 if stacks else 1)),"The original starting shine is the shared base size and grows with the same food bonus")
    check(kit.cast_model().combo_glow.global_position.is_equal_approx(p.model.qi_blast_chest()),"The shine starts at the caster's body centre")
    kit.cast_model().combo_glow.frame=4
    await capture("shine-%d-%s-%d-servings"%[id,"polearm" if polearm else "native",stacks])
    kit.cancel(true);p.facing=Vector3.FORWARD
    kit.ticket=p.attack_chain.begin("shin_sure_strike")
    kit.ticket.shin_blast_forward=Vector3.FORWARD;kit.start_sure_strike_attack()
    kit.advance_attack(kit.duration+.001);army.flush_presentation()
    check(victims.count(near)==(2 if id==40 else 1) and victims.count(extra)==((2 if id==40 else 1) if stacks else 0) and not victims.has(outside),"%d %s: growth reaches an additional native enemy once, with range exclusion"%[id,"諸刃" if polearm else "乾坤"])
    check(not victims.has(edge),"A target beyond the grown weapon range stays safe")
    var bursts=fx.effects.filter(func(row):return row.kind==("shin_double_edge" if polearm else "shin_sure_strike"))
    check(bursts.size()==victims.size(),"Each connected native strike draws one body explosion")
    var anchor=army.enemy_target(near).combat_bounds().get_center()
    check(bursts.any(func(row):return row.position.is_equal_approx(anchor)),"The near victim's explosion starts at its body centre")
    var pixels=252.0 if polearm else 232.0
    check(not bursts.is_empty() and is_equal_approx(bursts[0].scale*pixels*fx.CONTACT_PIXEL_SIZE,preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*(2 if stacks else 1)),"The visible burst starts the shared base size and grows with the hit area")
    await capture("fighter-%d-%s-%d-servings"%[id,"polearm" if polearm else "native",stacks])
 for id in [34,37,40]:
  p.select_character(id);fresh();rewards.reset()
  if id==37:p.model.select_stance(1)
  var kit=p.active_ability
  for stacks in [0,20]:
   rewards.skill_food_stacks=stacks;army.clear();army.refresh_kits()
   p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0;p.facing=Vector3.FORWARD
   await driver.advance(20,advance)
   var near=spawn(home+Vector3(0,0,-4))
   var extra=spawn(home+Vector3(8,0,-4))
   spawn(home+Vector3(9,0,-6),Roles.SLIME)
   army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
   kit.clear_cooldowns();victims.clear();game.crowd.army.presentation.effects.clear()
   kit.start_combo()
   check(kit.clip=="6" and is_equal_approx(shine_size(kit),preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*(91.0/357.0)*(2 if stacks else 1)),"Native/shared original combo shine uses the same starting size and growth")
   p.position+=Vector3.RIGHT
   kit.tick_charge(DT)
   check(kit.cast_model().combo_glow.global_position.is_equal_approx(p.model.qi_blast_chest()),"The shine follows the caster's chest when the body moves")
   p.position-=Vector3.RIGHT
   for frame in 180:
    await driver.advance(1,advance)
    if not victims.is_empty():break
   check(victims.count(near)==1 and victims.count(extra)==(1 if stacks else 0),"Fighter %d combo splash grows once per contact"%id)
   var fx=game.crowd.army.presentation
   var bursts=fx.effects.filter(func(row):return row.kind in ["kazi_combo","shin_combo"])
   var pixels=fx.SHIN_COMBO_SIZE_PIXELS if id in [37,40] else fx.COMBO_BURST_SIZE_PIXELS
   check(bursts.size()==victims.size() and not bursts.is_empty() and is_equal_approx(bursts[0].scale*pixels*fx.CONTACT_PIXEL_SIZE,preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*(2 if stacks else 1)),"Native/shared combo effects use the same slime-size starting unit")
   await capture("combo-%d-%d-servings"%[id,stacks])
   kit.cancel(true);p.spell_loadout.interrupt()
 p.select_character(37);fresh();rewards.reset();p.model.select_stance(1)
 army.clear();army.refresh_kits();p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
 await driver.advance(20,advance)
 for i in 16:spawn(home+Vector3((i%4-1.5)*.6,0,-2.0-floori(i/4.0)*.5))
 army.sync_targets();await frames(3)
 var kit=p.active_ability;var fx=game.crowd.army.presentation
 kit.ticket=p.attack_chain.begin("shin_sure_strike");kit.ticket.shin_blast_forward=Vector3.FORWARD;kit.start_sure_strike_attack();kit.advance_attack(kit.duration+.001);army.flush_presentation();fx.tick(2)
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var repeated=[]
 for i in 12:
  rewards.skill_food_stacks=20;kit.ticket=p.attack_chain.begin("shin_sure_strike")
  var started=Time.get_ticks_usec();kit.ticket.shin_blast_forward=Vector3.FORWARD;kit.start_sure_strike_attack();kit.advance_attack(kit.duration+.001);army.flush_presentation();fx.tick(2);repeated.append(Time.get_ticks_usec()-started)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated grown bursts reuse prepared effects and resources")
 samples.sort();repeated.sort()
 print("SKILL_FOOD_STEP_US p95=",samples[floori(samples.size()*.95)]," max=",samples.back()," repeated_contact_max=",repeated.back())
 rewards.reset()
 check(rewards.skill_food_stacks==0 and rewards.skill_food_multiplier()==1,"A fresh run resets food growth")
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKILL_FOOD_GROWTH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

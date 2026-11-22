extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"
var arrows:Array=[]
const Evidence="res://build/Other Files/Skill Levels/Melee/"

func picture(name_:String):
 if DisplayServer.get_name()=="headless":return
 var camera=game.camera_rig.camera;var pose=camera.global_transform
 camera.global_position=home+Vector3(20,14,24);camera.look_at(home+Vector3(0,2,-7))
 if name_.ends_with("contact") or name_.ends_with("impact"):
  for effect in game.crowd.army.presentation.effects:
   if effect.kind in ["kazi_combo","shin_combo","shin_double_edge","shin_two_birds","shin_two_birds_ex"]:effect.age=.15
 game.forest_ui.hide();game.army_runtime.flush_presentation();game.crowd.army.presentation.draw_effects()
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(Evidence+name_+".png")==OK,"Rendered "+name_)
 camera.global_transform=pose

func attack_frames(n:int):
 for i in n:
  await driver.advance(1,advance)
  for arrow in arrows:
   if arrow.pool_live:arrow._physics_process(DT)

func clean_arena():
 game.army_runtime.clear();game.army_runtime.refresh_kits();victims.clear();arrows.clear()
 game.player.active_ability.cancel(true);game.player.active_ability.clear_cooldowns();game.player.attack_chain.reset()
 game.player.position=home;game.player.velocity=Vector3.ZERO;game.player.facing=Vector3.FORWARD
 game.crowd.army.presentation.effects.clear()

func run():
 create_timer(240).timeout.connect(func():printerr("SKILL_LEVEL_MELEE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(Evidence)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;var army=game.army_runtime
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.set_process(false)
 game.camera_rig.camera.global_position=home+Vector3(0,14,28);game.camera_rig.camera.look_at(home+Vector3(0,2,-7))
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 game.impact_confirmed.connect(func(enemy,_strength,_time):victims.append(enemy.forest_id))
 var pool=preload("res://scripts/character_projectile_pool.gd").service(game)
 pool.launched.connect(func(shot):
  if shot.hero==p:shot.set_physics_process(false);arrows.append(shot))
 var assassination_only="--assassination-only" in OS.get_cmdline_user_args()
 var focused="--two-birds-only" in OS.get_cmdline_user_args() or assassination_only
 for fighter in ([] if focused or "--rest-only" in OS.get_cmdline_user_args() else p.RogueRoster.CROSSGATE.keys()):
  p.select_character(fighter);fresh();game.reset_character_tuning(fighter);game.update_character_tuning(fighter,"critical_chance",0)
  if fighter==37:p.model.select_stance(1)
  if fighter in [36,39]:p.active_ability.set_weapon(p.RogueRoster.MazeWeapon.KATANA)
  p.position=home;p.velocity=Vector3.ZERO;await driver.advance(20,advance)
  for level_ in [1,30]:
   clean_arena();var target=spawn(Vector3(0,0,-3.5));var before=target.hp
   Skills.set_level(p,"shin/sure-strike",level_)
   var count_=p.model.normal_attack_pattern().contacts.size()
   p.active_ability.start_shin_area_cast();await attack_frames(220)
   var expected=Skills.normal_damage(p)*(1.1 if level_==1 else 4.0)*count_
   check(is_equal_approx(before-target.hp,expected),"Fighter %d sure strike Lv%d uses normal contact damage × skill multiplier (%.2f vs %.2f)"%[fighter,level_,before-target.hp,expected])
 p.select_character(34);fresh();game.update_character_tuning(34,"critical_chance",0)
 p.position=home;await driver.advance(20,advance)
 for level_ in ([] if focused else [1,2,3,4,30]):
  clean_arena();var target=spawn(Vector3(0,0,-5));var before=target.hp;Skills.set_level(p,"kazi/combo",level_)
  p.active_ability.start_combo();await attack_frames(12)
  if level_ in [1,30]:await picture("combo-level-%02d-charge"%level_)
  for i in 600:
   await attack_frames(1)
   if target.hp<before:
    if level_ in [1,30]:await picture("combo-level-%02d-contact"%level_)
    break
  for i in 600:
   if not p.active_ability.is_attacking():break
   await attack_frames(1)
  var count_=3+floori((level_-1)/2.0);var damage=.8+.1*floori(level_/2.0)
  check(victims.size()==count_,"Combo Lv%d has %d contacts, including when one living target is shared (got %d)"%[level_,count_,victims.size()])
  check(is_equal_approx(before-target.hp,250.0*damage*count_),"Combo Lv%d delivers the agreed damage on every native contact"%level_)
 p.select_character(37);fresh();p.model.select_stance(2);game.update_character_tuning(37,"critical_chance",0)
 p.position=home;await driver.advance(20,advance)
 check(p.model.motions.weapon=="polearm","Polearm skills use the existing source stance")
 for level_ in ([] if assassination_only else [1,30]):
  clean_arena();var target=spawn(Vector3(0,0,-3.5));var before=target.hp
  Skills.set_level(p,"shin/double-edge",level_);p.active_ability.start_shin_area_cast()
  check(p.double_edge_left==10 and is_equal_approx(p.double_edge_penalty,.10 if level_==1 else .39),"Double Edge applies the caster's ten-second defense penalty on use")
  await attack_frames(12);await picture("double-edge-level-%02d-charge"%level_)
  for i in 160:
   await attack_frames(1)
   if target.hp<before:await picture("double-edge-level-%02d-contact"%level_);break
  check(is_equal_approx(before-target.hp,250.0*(1.6 if level_==1 else 7.4)),"Double Edge uses the level damage multiplier")
  check(p.double_edge_left>0 and p.double_edge_left<10,"Defense penalty counts down during play")
  await attack_frames(620)
  check(p.double_edge_left==0,"Double Edge defense recovers after ten seconds")
  clean_arena();var front=spawn(Vector3(0,0,-4));var rear=spawn(Vector3(0,0,-22))
  var front_hp=front.hp;var rear_hp=rear.hp
  Skills.set_level(p,"shin/two-birds",level_);p.active_ability.start_shin_area_cast(true)
  var direction=p.facing
  army.native.set_pose(front.handle,home+direction*4,0);army.native.set_pose(rear.handle,home+direction*22,0);army.sync_targets()
  await attack_frames(12);await picture("two-birds-level-%02d-charge"%level_)
  for i in 180:
   await attack_frames(1)
   if front.hp<front_hp:await picture("two-birds-level-%02d-impact"%level_);break
  for i in 180:
   await attack_frames(1)
   if rear.hp<rear_hp:
    for effect in game.crowd.army.presentation.effects:
     if effect.kind in ["shin_two_birds","shin_two_birds_ex"]:effect.age=.25
    await picture("two-birds-level-%02d-explosion"%level_);break
  check(is_equal_approx(front_hp-front.hp,250.0*(1.1 if level_==1 else 4.0)),"Two Birds primary stage keeps its own damage")
  check(is_equal_approx(rear_hp-rear.hp,250.0*(2.1 if level_==1 else 5.0)),"Two Birds rear stage keeps its separate damage (got %.2f, expected %.2f)"%[rear_hp-rear.hp,250.0*(2.1 if level_==1 else 5.0)])
  var impact_kind="shin_two_birds_ex" if level_==30 else "shin_two_birds"
  check(game.crowd.army.presentation.effects.any(func(effect):return effect.kind==impact_kind and effect.get("rear",false)),"Two Birds creates the original follow-up explosion for its level")
  clean_arena();target=spawn(Vector3(0,0,-3));before=target.hp
  Skills.set_level(p,"shin/counter",level_);p.spell_loadout.equip(37,"surge","shin/counter")
  p.active_ability.counter_after_hit(Vector3.BACK,target.forest_id)
  for i in 700:
   p.active_ability.tick_shin_counter(DT)
   if i==8:await picture("counter-level-%02d"%level_)
  check(is_equal_approx(before-target.hp,250.0*(1.5 if level_==1 else 7.3)*(1 if level_==1 else 7)),"Counter damage and repeated hit count follow level rules (got %.2f)"%[before-target.hp])
  p.active_ability.clear_shin_counter()
 p.select_character(36);fresh();p.active_ability.set_weapon(p.RogueRoster.MazeWeapon.KATANA)
 p.position=home;await driver.advance(20,advance);clean_arena()
 var target=spawn(Vector3(0,0,-8));Skills.set_level(p,"maze/assassination",1)
 var ticket=p.attack_chain.begin("maze_assassination");ticket.skill_chance=0;ticket.critical_chance=0
 target.take_hit(1,Vector3.FORWARD,false,ticket)
 check(not target.dead and ticket.has("assassination_success") and not ticket.assassination_success,"A failed assassination rolls once on actual contact")
 ticket.skill_chance=1;target.take_hit(1,Vector3.FORWARD,false,ticket)
 check(not target.dead and not ticket.assassination_success,"Later native contacts do not reroll the same assassination")
 Skills.set_level(p,"maze/assassination",30);ticket=p.attack_chain.begin("maze_assassination");ticket.critical_chance=0
 target.take_hit(1,Vector3.FORWARD,false,ticket)
 check(target.dead and ticket.assassination_success,"Level 30 kills an eligible target on a confirmed assassination hit")
 clean_arena();target=spawn(Vector3(0,0,-8))
 army.native.set_pose(target.handle,target.global_position,0);army.sync_targets()
 await driver.advance(3,advance)
 Skills.set_level(p,"maze/assassination",1);p.active_ability.start_assassination(target)
 check(p.model.combo_glow.texture==p.active_ability.ShineTiers.textures["110103"],"Level-one assassination selects the smallest original sheet")
 p.active_ability.cancel(true);Skills.set_level(p,"maze/assassination",30);p.mana=p.max_mana
 p.active_ability.input(preload("res://scripts/spells/spell_instance.gd").event("equip",true))
 check(p.active_ability.assassinating() and not p.active_ability.assassination_enabled,"Pressing the skill directly starts assassination without toggling")
 check(p.model.combo_glow.scale==Vector3.ONE and p.model.combo_glow.texture==p.active_ability.ShineTiers.textures["111016"],"Level-30 assassination uses the shared EX shine")
 await attack_frames(10);await picture("assassination-charge")
 var hit_seen=false
 for i in 240:
  await attack_frames(1)
  if target.dead and not hit_seen:hit_seen=true;await picture("assassination-contact")
 check(target.dead,"Direct level-30 assassination completes a real lethal contact (hp %.2f, impacts %d)"%[target.hp,victims.size()])
 p.active_ability.cancel(true);p.model.prepare_kagerou_shadows();p.active_ability.kagerou_enabled=true
 seed(1478)
 for row in [[1,200,300],[30,970,999]]:
  Skills.set_level(p,"kazi/kagerou",row[0]);var dodges=0
  for i in 1000:
   if p.try_kagerou_dodge(Vector3.BACK):dodges+=1
  check(dodges>=row[1] and dodges<=row[2],"Dodge probability Lv%d is %d / 1000, not guaranteed"%[row[0],dodges])
 p.model.tick_kagerou_dodge(.08);await picture("kagerou-afterimage")
 p.team_progression.stat_ranks.defense=10
 check(is_equal_approx(p.team_progression.stat_incoming_multiplier(0,.61),100.0/161.0),"The debuff reduces defense, not a flat incoming-damage percentage")
 print("SKILL_LEVEL_MELEE checks=%d failures=%d"%[checks,failures])
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

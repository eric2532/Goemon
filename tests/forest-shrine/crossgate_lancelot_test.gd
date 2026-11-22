extends "res://tests/forest-shrine/crossgate_shin_skills_test.gd"

const LANCELOT_OUT="res://build/Other Files/Asset Toolkit/Lancelot/Gameplay/"
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/recovered_enemy_projectile.gd")
var shots:Array[Node3D]=[]

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(LANCELOT_OUT+filename)==OK,"Captured "+filename)

func pose_cost(visual:Node)->float:
 var started=Time.get_ticks_usec()
 for i in 1200:visual.animate(STEP,5,true,0,0,false,0,false)
 return (Time.get_ticks_usec()-started)/1200.0

func run():
 create_timer(100).timeout.connect(func():printerr("LANCELOT_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(LANCELOT_OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 p.select_character(Roster.MAZE_ID)
 var reference_cost=pose_cost(p.model)
 game.show_rogue_roster();await frames(3)
 var card=game.menu.find_child("RogueFighter_lancelot",true,false)
 check(card!=null,"Lancelot has his own character card")
 var picker:Button=card.find_child("LancelotSkin",true,false)
 check(picker.catalog.size()==8,"The picker contains all eight recovered skins")
 card.pressed.emit()
 check(p.character_id==Roster.LANCELOT_ID and p.model.variant_skin==106125,"The card selects Lancelot with White / Silver by default")
 var visual=p.model
 var kit=p.active_ability
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  if shot.kind=="crossgate_arrow":shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(victim,_strength,_time):victims.append(victim))
 check(not visual.can_swap_stance() and not visual.fighter.get("maze",false),"Lancelot stays bow-equipped without the kunai weapon-switch system")
 check(p.spell_loadout.numbered_slots[0][0]==p.spell_loadout.Catalog.RANDOM_SHOT_NAME and p.spell_loadout.numbered_slots[0][1]=="equip","亂射 is the default key 1 skill")
 check(SoundLibrary.original_for(Roster.LANCELOT_ID,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(Roster.LANCELOT_ID,"land")==SoundLibrary.HUMANOID_LANDING,"Prepared Goemon footstep and landing defaults are preserved")
 for slot in SoundLibrary.CROSSGATE_BOW_SOUNDS:
  var audio=SoundLibrary.original_for(Roster.LANCELOT_ID,slot)
  check(audio==SoundLibrary.CROSSGATE_BOW_SOUNDS[slot] and audio.loop_mode==AudioStreamWAV.LOOP_DISABLED,"Original bow audio is prepared without loops: "+slot)
 var home=Vector3(40,0,60)
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 var dummy=game.training_dummy
 dummy.position=home+Vector3(-5,0,-2);dummy.home=dummy.position
 game.settings.disable_character_cooldowns=false;game.tuning.invincible=false
 var body_nodes=visual.body.get_child_count()
 for skin in Roster.LANCELOT.skins:
  game.show_rogue_roster();await frames(2)
  card=game.menu.find_child("RogueFighter_lancelot",true,false)
  picker=card.find_child("LancelotSkin",true,false)
  picker.select_skin(skin)
  game.forest_ui.sync_character()
  check(p.model==visual and visual.motions.id==skin and visual.motions.source_id==skin+1 and visual.motions.weapon=="bow","Skin %d selects the original bow record on the same model"%skin)
  check(visual.motions.clips.size()==152 and is_equal_approx(visual.sprite.pixel_size*visual.body_height_pixels,preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT),"Skin %d retains all 152 clips and established body height"%skin)
  if skin in [106125,105206]:await capture("Lancelot %d gallery.png"%skin)
  game.close_rogue_roster();fresh();settle(home);victims.clear();shots.clear()
  p.facing=Vector3.FORWARD
  tap("light_attack")
  check(kit.is_attacking() and kit.fire_target!=null and kit.fire_target.get_ref()==dummy and p.facing.x<0,"Left click aims the bow at the selected target")
  check(kit.ground_attack_velocity()==Vector3.INF and p.melee_strike_reach()==0,"Bow attacks allow movement and have no melee damage outline")
  var rate=p.attack_speed_multiplier()
  var motion:Dictionary=visual.motions.clips["5:0"]
  kit.tick((float(motion.draw)-.001)/rate)
  check(shots.is_empty() and victims.is_empty(),"Bow windup creates no early arrow or melee hit")
  kit.tick(.002/rate)
  check(game.last_sound_voice.stream==SoundLibrary.CROSSGATE_BOW_SOUNDS.swing,"Draw sound plays at original frame 5")
  kit.tick((float(motion.release)-kit.elapsed-.001)/rate)
  check(shots.is_empty(),"The arrow waits until original release frame 11")
  kit.tick(.002/rate)
  check(shots.size()==1 and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_BOW_SOUNDS.throw,"Release creates one arrow and plays its original bow sound")
  var arrow=shots[0]
  check(arrow.dagger_sprite.texture==Shot.ARROW_ATLAS and arrow.dagger_sprite.hframes==16 and arrow.attack_ticket.crossgate_sound_source==Roster.LANCELOT_ID,"Arrow uses original art, sixteen flight angles and Lancelot audio ownership")
  check(is_equal_approx(arrow.velocity.length(),72) and is_equal_approx(arrow.velocity.length()*arrow.lifetime,120) and arrow.velocity.x<0,"Arrow follows the kunai's speed, range and automatic aim")
  arrow._physics_process(.025)
  visual.show_pose(5,kit.elapsed,false)
  if skin in [106125,105206]:await capture("Lancelot %d arrow flight.png"%skin)
  for i in 120:
   if arrow.pool_live:arrow._physics_process(STEP)
  check(victims==[dummy] and not arrow.pool_live and arrow.attack_ticket.is_empty() and arrow.hero==null,"Swept arrow hits once and releases its damage ticket and owner")
  check(game.last_sound_voice.stream==SoundLibrary.CROSSGATE_BOW_SOUNDS.coin_hit,"Arrow contact uses the recovered arrow impact sound")
  kit.tick(2)
  check(shots.size()==1 and not kit.is_attacking(),"Recovery never launches a duplicate arrow")
  check(visual.body.get_child_count()==body_nodes,"Skin changes and repeated shots retain the same body nodes")
 await frames(2)
 var warm_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 var created:int=pool.created
 var misses:int=pool.misses
 for i in 20:
  kit.cancel(true);p.attack_chain.reset();shots.clear();kit.start_attack();kit.tick(2)
  for shot in shots:shot._physics_process(2)
 check(pool.created==created and pool.misses==misses,"Twenty more attacks reuse warmed arrows without pool growth or misses")
 check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=warm_resources,"Twenty repeated attacks retain the warmed resource count")
 shots.clear();kit.start_attack();kit.tick(.4)
 game.select_crossgate_skin(Roster.LANCELOT_ID,106125)
 kit.tick(2)
 check(shots.is_empty() and not kit.is_attacking(),"Changing skins cancels an unreleased arrow")
 fresh();settle(home);shots.clear();kit.start_attack();dummy.dead=true;kit.tick(1)
 check(shots.size()==1 and shots[0].target==null,"A dead aim target leaves an ordinary arrow without a stale target reference")
 dummy.dead=false;pool.release_owner(p)
 kit.cancel(true);fresh();settle(home);shots.clear();victims.clear()
 p.smoke_move=Vector2.RIGHT
 for i in 12:p._physics_process(STEP);await physics_frame
 var run_speed:float=p.velocity.x
 var start:Vector3=p.position
 kit.start_attack()
 for i in 20:p._physics_process(STEP);await physics_frame
 check(run_speed>1 and p.velocity.x>=run_speed-.05 and p.position.x>start.x+run_speed*.3,"Lancelot keeps his running speed through the bow windup")
 p.smoke_move=Vector2.ZERO;kit.cancel(true);fresh();settle(home)
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,4,2)
 shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=home+Vector3(-2.5,1.5,-1)
 await physics_frame;await physics_frame
 check(AttackChain.nearest_visible_target(p,p.auto_aim_origin(),120)!=dummy,"Auto-aim excludes a target behind a wall")
 wall.queue_free();await physics_frame;await physics_frame
 dummy.position=home+Vector3.FORWARD*130
 check(AttackChain.nearest_visible_target(p,p.auto_aim_origin(),120)!=dummy,"Auto-aim excludes targets outside arrow range")
 dummy.position=dummy.home
 kit.start_attack();shots.clear();victims.clear()
 wall=StaticBody3D.new();wall.collision_layer=1
 shape=CollisionShape3D.new();shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=home+Vector3(-2.5,1.5,-1)
 await physics_frame;await physics_frame
 kit.tick(1);shots.back()._physics_process(.5)
 check(victims.is_empty() and not shots.back().pool_live,"A wall appearing during windup intercepts the arrow")
 wall.queue_free();await frames(2);kit.cancel(true)
 fresh();settle(home);await physics_frame;await physics_frame
 p.velocity=Vector3.DOWN;p.move_and_slide()
 var second_row=game.model.waves.spawn_enemy(0,home+Vector3(5,0,-8))
 second_row.hp=1000000;second_row.max_hp=second_row.hp
 game.army_runtime.import_arrivals();game.army_runtime.integration_tick(STEP)
 var second:Ninja=game.actors[second_row.id]
 game.army_runtime.apply_hit(second.handle,{"element":"ice","status_seconds":1000.0})
 seed(95);shots.clear();victims.clear();kit.clear_cooldowns();press(KEY_1)
 check(kit.ticket.action=="lancelot_random_shot" and visual.combo_glow.visible and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"Key 1 starts the original physical-skill shine and sound")
 kit.tick(.1);visual.animate(STEP,0,true,0,0,false,0,false)
 await capture("Lancelot 亂射 shine.png")
 check(shots.is_empty() and visual.current_clip.begins_with("0:"),"The shine precedes arrows and uses the original standing bow pose")
 kit.tick(.351)
 check(not visual.combo_glow.visible and kit.clip=="5","Shine completion starts the rapid bow sequence")
 var aims=[]
 var launched=0
 var barrage_started=Time.get_ticks_usec()
 for i in 400:
  kit.tick(STEP)
  if shots.size()>launched:
   aims.append(shots.back().velocity.normalized());launched=shots.size()
   if launched==3:
    visual.show_pose(5,kit.elapsed,false)
    await capture("Lancelot 亂射 rapid arrows.png")
  for arrow in shots:
   if arrow.pool_live:arrow._physics_process(STEP)
  if not kit.is_attacking():break
 check(launched==12 and not kit.is_attacking(),"One 亂射 fires exactly twelve arrows and ends cleanly")
 check(aims.any(func(a):return a.x<0) and aims.any(func(a):return a.x>0),"The rapid sequence retargets random visible enemies on both sides")
 check(kit.RANDOM_SHOT_RATE>3 and Time.get_ticks_usec()-barrage_started<10000000,"The sequence uses the traced 33% bow clock without blocking the simulation")
 check(pool.created==created and pool.misses==misses,"The entire rapid volley uses prewarmed arrow leases")
 var barrage_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for repetition in 3:
  kit.clear_cooldowns();kit.start_random_shot()
  for i in 400:
   kit.tick(STEP)
   for arrow in shots:
    if arrow.pool_live:arrow._physics_process(STEP)
   if not kit.is_attacking():break
 check(pool.created==created and pool.misses==misses and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=barrage_resources,"Repeated rapid volleys retain warm resources and arrow capacity")
 press(KEY_1)
 check(not kit.is_attacking() and kit.random_shot_cooldown>0,"The shared skill cooldown blocks immediate repeat casts")
 kit.tick_timers(5);press(KEY_1)
 check(kit.is_attacking() and visual.combo_glow.visible,"The skill is usable again after its cooldown")
 shots.clear();game.select_crossgate_skin(Roster.LANCELOT_ID,105206);kit.tick(5)
 check(shots.is_empty() and not visual.combo_glow.visible and not kit.is_attacking(),"Changing skin cancels both the shine and queued rapid arrows")
 game.select_crossgate_skin(Roster.LANCELOT_ID,106125)
 game.army_runtime.despawn(second.handle)
 var library=game.sound_library
 library.select_character(Roster.LANCELOT_ID);library.set_gain("throw",.35);library.set_muted("coin_hit",true)
 check(is_equal_approx(library.gain_for(Roster.LANCELOT_ID,"throw"),.35) and library.is_muted_for(Roster.LANCELOT_ID,"coin_hit") and not library.is_muted_for(Roster.MAZE_ID,"coin_hit"),"Bow gain and mute controls remain independent of kunai audio")
 library.set_gain("throw",1);library.set_muted("coin_hit",false)
 fresh();settle(home);game.hit_stop=0
 var army=game.army_runtime
 army.set_navigation(9933,{"width":0});army.record_events=false
 var row=game.model.waves.spawn_enemy(0,home+Vector3.FORWARD*18)
 row.hp=1000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_targets()
 var enemy:Ninja=game.actors[row.id]
 army.apply_hit(enemy.handle,{"element":"ice","status_seconds":1000.0})
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 check(mirrors.cast(),"Five Lancelot images spawn through the native army lifecycle")
 check(mirrors.bodies.all(func(body):return body.character_id==Roster.LANCELOT_ID and body.model.variant_skin==visual.variant_skin),"Native images preserve Lancelot's selected skin")
 var ally_shots=0
 for i in 420:
  var before:int=shots.size()
  army.step(STEP,{"targets":army.external_targets()})
  ally_shots+=shots.size()-before
  for arrow in shots:
   if arrow.pool_live:arrow._physics_process(STEP)
  if i%30==0:await physics_frame
 check(ally_shots>=60 and mirrors.bodies.all(func(body):return body.position.is_finite()),"Five simultaneous native allies complete their twelve-arrow volleys without invalid poses")
 check(mirrors.bodies.all(func(body):return body.action_history.has(2)),"All five native images use 亂射 through their existing numbered skill action")
 check(game.hit_stop==0 and p.impact_pause==0,"Ally arrow impacts do not pause the player")
 mirrors.dispose();await frames(2)
 var config=ConfigFile.new()
 check(config.load(cfg)==OK and config.get_value("settings","lancelot_skin")==106125,"Lancelot's skin saves independently")
 samples.sort()
 print("LANCELOT_PERFORMANCE pose_us_maze=%.2f pose_us_lancelot=%.2f player_p95_us=%d pool_created=%d pool_misses=%d body_nodes=%d"%[reference_cost,pose_cost(visual),samples[int(samples.size()*.95)],pool.created,pool.misses,body_nodes])
 game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("LANCELOT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roster=preload("res://scripts/rogue_roster.gd")
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")
const OUT="res://build/Other Files/Asset Toolkit/Emilia/"
const STEP=1.0/60

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await frames()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+filename+".png")==OK,"Captured "+filename)

func pose_cost(model_:Node)->float:
 var start=Time.get_ticks_usec()
 for i in 1200:model_.animate(STEP,5.0,true,0,0,false,0,false)
 return float(Time.get_ticks_usec()-start)/1200.0

func run():
 create_timer(180).timeout.connect(func():printerr("EMILIA_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 p.select_character(Roster.RUBY_ID)
 var uru=p.model
 var uru_slots=p.spell_loadout.numbered_slots.duplicate(true)
 var uru_script=p.active_ability.get_script()
 var uru_cost=pose_cost(uru)
 game.show_rogue_roster();await frames(4)
 var card=game.menu.find_child("RogueFighter_emilia",true,false)
 check(card!=null,"Emilia appears in the shared Cross Gate gallery")
 var catalog:Dictionary=Roster.EMILIA.skins
 check(catalog.size()==18 and Roster.selected_skin(Roster.EMILIA_ID,game.settings)==120387,"All eighteen verified appearances are offered, starting with Emilia + Puck")
 var scroll:ScrollContainer=game.menu.find_child("RosterScroll",true,false)
 scroll.ensure_control_visible(card)
 await capture("Emilia gallery")
 card.pressed.emit()
 var model_=p.model
 var kit=p.active_ability
 check(p.character_id==Roster.EMILIA_ID and model_.appearance.id==120387,"The gallery selects Emilia + Puck")
 check(kit.get_script()==uru_script and model_.fighter.strike=="staff","Emilia reuses Uru's exact staff controller")
 check(p.spell_loadout.numbered_slots==uru_slots and Catalog.defaults(Roster.EMILIA_ID)==Catalog.defaults(Roster.RUBY_ID),"Emilia and Uru both start with six empty skill slots")
 check(SoundLibrary.original_for(Roster.EMILIA_ID,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(Roster.EMILIA_ID,"land")==SoundLibrary.HUMANOID_LANDING,"Shared prepared footsteps and landing are preserved")
 check(SoundLibrary.original_for(Roster.EMILIA_ID,"swing")==SoundLibrary.original_for(Roster.RUBY_ID,"swing") and SoundLibrary.original_for(Roster.EMILIA_ID,"hit")==SoundLibrary.original_for(Roster.RUBY_ID,"hit"),"Staff audio reuses Uru's prepared originals")
 check(model_.sprite in model_.body.find_children("*","Sprite3D",false,false),"The appearance keeps its prepared body sprite alongside shared presentation effects")
 var emilia_cost=pose_cost(model_)
 var node_count=model_.get_child_count()
 game.show_rogue_roster();await frames()
 card=game.menu.find_child("RogueFighter_emilia",true,false)
 for skin in catalog:
  game.select_crossgate_skin(Roster.EMILIA_ID,skin)
  game.close_rogue_roster();game.show_rogue_roster();await frames(1)
  card=game.menu.find_child("RogueFighter_emilia",true,false)
  game.forest_ui.sync_character()
  check(p.model==model_ and model_.appearance.id==skin and model_.motions.weapon=="staff","Skin %d changes the existing staff model"%skin)
  check(model_.motions.clips.size()==152,"Skin %d keeps all nineteen actions in eight directions"%skin)
  var valid=true
  for pose in model_.motions.clips:
   var action=int(pose.get_slice(":",0))
   var motion:Dictionary=model_.motions.clips[pose]
   for frame in [0,motion.frames.size()/2,motion.frames.size()-1]:
    model_.show_frame(action,pose,int(frame))
    var region:Rect2=model_.sprite.region_rect
    valid=valid and region.has_area() and Rect2(Vector2.ZERO,model_.sprite.texture.get_size()).encloses(region)
  check(valid and model_.get_child_count()==node_count,"Skin %d plays every action and facing without rebuilding nodes or clipping atlas frames"%skin)
  var portrait:AtlasTexture=card.find_child("SelectionPortrait",true,false).texture
  check(portrait.atlas==Roster.skin_portrait(Roster.EMILIA_ID,skin) and game.forest_ui.hero_portrait.texture==game.forest_ui.PaintedHeads.portrait(Roster.EMILIA_ID,game.settings),"Skin %d updates the gallery while selecting Emilia's matching painted HUD head"%skin)
  for direction in 8:
   var key="5:%d"%direction
   var attack:Dictionary=model_.motions.clips[key]
   check(attack.duration==uru.motions.clips[key].duration and attack.frames.size()==38 and attack.sounds==uru.motions.clips[key].sounds,"Skin %d facing %d preserves all five Uru swing/contact times"%[skin,direction])
 var config=ConfigFile.new()
 check(config.load(cfg)==OK and config.get_value("settings","emilia_skin")==100230,"Emilia's selected appearance is saved")
 game.close_rogue_roster()
 fresh();p.select_character(Roster.EMILIA_ID)
 game.training_dummy.position=Vector3(0,-100,0);game.training_dummy.collision_layer=0
 var owner=game.army_runtime
 var row=game.model.waves.spawn_enemy(0,p.global_position+Vector3.FORWARD*2)
 row.hp=100000;row.max_hp=100000
 owner.import_arrivals();owner.integration_tick(STEP)
 var handle:int=owner.handles[row.id]
 for skin in Roster.EMILIA.skins:
  game.select_crossgate_skin(Roster.EMILIA_ID,skin)
  p.attack_chain.reset()
  var hp:float=owner.unit_state(handle).hp
  p.auto_attack_enabled=true;p.auto_lock_target=game.actors[row.id];p.auto_lock_refresh=100
  kit.start_attack();p.auto_attack_enabled=false
  for i in 121:
   kit.tick(STEP);model_.animate(STEP,0,true,0,0,false,0,false)
  check(not kit.is_attacking() and is_equal_approx(owner.unit_state(handle).hp,hp-500),"Skin %d delivers exactly Uru's five 100-damage native contacts (%.1f damage)"%[skin,hp-float(owner.unit_state(handle).hp)])
 game.select_crossgate_skin(Roster.EMILIA_ID,120387)
 model_.show_pose(0,0,true)
 game.camera_rig.camera.global_position=p.global_position+Vector3(6,4,-9)
 game.camera_rig.camera.look_at(p.global_position+Vector3.UP*1.5)
 model_.show_pose(0,0,true)
 await capture("Emilia and Puck with staff")
 p.auto_attack_enabled=true;p.auto_lock_target=game.actors[row.id];p.auto_lock_refresh=100
 kit.start_attack();p.auto_attack_enabled=false
 kit.tick(.8);model_.animate(STEP,0,true,0,0,false,0,false)
 await capture("Emilia staff contact")
 kit.cancel()
 var skill_fixture={"equip":Catalog.SPIRIT,"surge":"kazi/fire","sky_strike":"kazi/ice","special_4":"kazi/wind","special_5":"kazi/meteor","special_6":Catalog.RECOVERY}
 for action in skill_fixture:check(p.spell_loadout.equip(Roster.EMILIA_ID,action,skill_fixture[action]),"Explicitly equip the skill under review")
 var pool=Pool.service(game)
 var spirit=p.spell_loadout.instances["%d:%s"%[Roster.EMILIA_ID,Catalog.SPIRIT]]
 check(spirit.controller.range_multiplier()==3.0 and spirit.controller.SPIRIT_RANGE==192.0,"Emilia retains Uru's targeting ranges")
 var hp:float=owner.unit_state(handle).hp
 p.attack_chain.reset()
 p.spell_loadout.number_input(1,true);p.spell_loadout.number_input(1,false)
 check(spirit.controller.is_attacking() and is_equal_approx(spirit.controller.cooldown,5.0),"Key 1 starts Uru's Spirit Shockwave with the same cooldown")
 for i in 150:
  p.spell_loadout.tick(STEP)
  for shot in pool.all[spirit.controller.pool_key]:
   shot.set_physics_process(false)
   if shot.pool_live:shot._physics_process(STEP)
  if i==24:
   model_.animate_spell(STEP,spirit)
   await capture("Emilia casting")
 check(is_equal_approx(owner.unit_state(handle).hp,hp-5050) and spirit.controller.spirit_targets.is_empty(),"Spirit Shockwave adds 50 base magic damage and clears its queue (%.1f damage)"%(hp-float(owner.unit_state(handle).hp)))
 p.spell_loadout.cancel()
 for number in [2,3,4,5]:
  var spell_id:String=skill_fixture[["surge","sky_strike","special_4","special_5"][number-2]]
  var instance=p.spell_loadout.instances["%d:%s"%[Roster.EMILIA_ID,spell_id]]
  p.attack_chain.reset()
  p.mana=p.max_mana
  var before:float=owner.unit_state(handle).hp
  p.spell_loadout.number_input(number,true);p.spell_loadout.number_input(number,false)
  check(instance.controller.is_attacking() and is_equal_approx(instance.controller.cooldown,5.0),"Key %d starts the same %s controller and cooldown as Uru"%[number,spell_id])
  for i in 240:
   p.spell_loadout.tick(STEP)
   for shot in pool.all[instance.controller.pool_key]:
    shot.set_physics_process(false)
    if shot.pool_live:shot._physics_process(STEP)
  if number==4:
   # The isolated fixture also retains a distant dummy; allow the full tracked flight lease.
   for i in 360:
    for shot in pool.all[instance.controller.pool_key]:
     if shot.pool_live:shot._physics_process(STEP)
  check(owner.unit_state(handle).hp<before and pool.all[instance.controller.pool_key].all(func(shot):return not shot.pool_live),"%s damages the native target and returns every projectile lease (%.1f damage)"%[spell_id,before-float(owner.unit_state(handle).hp)])
  p.spell_loadout.cancel()
 p.max_hp=1000;p.hp=100;p.mana=p.max_mana
 p.spell_loadout.number_input(6,true);p.spell_loadout.number_input(6,false)
 var recovery=p.spell_loadout.instances["%d:%s"%[Roster.EMILIA_ID,Catalog.RECOVERY]].controller
 check(recovery.cast_left>0 and recovery.COOLDOWN_DURATION==10.0,"Key 6 starts Uru's Regrowth")
 for i in 90:p.spell_loadout.tick(STEP)
 check(is_equal_approx(p.hp,280.0) and recovery.moves_left==0,"Level-one Regrowth restores 20% of missing health once")
 kit.start_attack();p.spell_loadout.tick(STEP);kit.cancel()
 check(is_equal_approx(p.hp,280.0) and recovery.moves_left==0,"A later staff attack does not repeat the completed recovery pulse")
 p.spell_loadout.cancel()
 var mirrors=Mirrors.new(p,0)
 for i in 5:
  check(mirrors.reinforce(Roster.EMILIA_ID,ORIGIN+Vector3((i-2)*.5,0,.5)),"Emilia reuses native ally slot %d"%i)
 check(mirrors.bodies.all(func(body):return body.model.atlases==model_.atlases and body.model.variant_skin==120387),"All five allies share the selected appearance and immutable atlas pages")
 check(mirrors.bodies.all(func(body):return body.actions.size()==7 and not body.spell_loadout.instances.has("%d:%s"%[Roster.EMILIA_ID,Catalog.RECOVERY])),"Allies keep Uru's offensive loadout and skip player-only Regrowth")
 for body in mirrors.bodies:
  body.ai_aim=game.actors[row.id].global_position
  body.active_ability.start_attack()
 for i in 121:
  for body in mirrors.bodies:
   body.active_ability.tick(STEP);body.model.animate(STEP,0,true,0,0,false,0,false)
 check(mirrors.bodies.all(func(body):return not body.active_ability.is_attacking()),"Simultaneous native ally staff combos finish cleanly")
 var created:int=pool.created
 var misses:int=pool.misses
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 6:
  kit.start_attack()
  for tick in 121:kit.tick(STEP);model_.animate(STEP,0,true,0,0,false,0,false)
 check(pool.created==created and pool.misses==misses and misses==0,"Repeated staff use adds no projectiles and misses no pooled leases")
 check(model_.get_child_count()==node_count and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated animations and attacks add no resources or presentation nodes")
 game.select_crossgate_skin(Roster.EMILIA_ID,100224)
 var copy=mirrors.bodies[0]
 var copy_handle:int=copy.native_handle
 copy.copy_from(p);copy.native_handle=copy_handle
 check(copy.model.variant_skin==100224 and copy.model.atlases==model_.atlases,"A reused native ally copies a non-default Emilia skin without resetting its appearance")
 game.select_crossgate_skin(Roster.EMILIA_ID,120387)
 kit.start_attack()
 check(kit.is_attacking() and p.has_offensive_action(),"Emilia's staff attack participates in the shared interruption rules")
 p.interrupt_attack_for_movement()
 check(not kit.is_attacking() and p.attack_left==0,"Movement interruption clears Emilia's unfinished staff attack")
 model_.reset_jump_pose();model_.jump_count=1;model_.jump_age=.2
 check(model_.show_jump_pose(false,3.0) and model_.current_clip.begins_with("3:"),"Airborne Emilia uses her prepared run pose through the shared jump system")
 model_.reset_jump_pose()
 mirrors.dispose();mirrors=null
 check(p.spell_loadout.assignments(Roster.EMILIA_ID)==skill_fixture,"Skin changes and repeated combat preserve the explicitly equipped skills")
 print("EMILIA_POSE_US uru=%.2f emilia_puck=%.2f"%[uru_cost,emilia_cost])
 print("EMILIA_RESULT checks=%d failures=%d"%[checks,failures])
 p.spell_loadout.cancel()
 owner.clear()
 await frames(5)
 game.queue_free();paused=false;await frames(10)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

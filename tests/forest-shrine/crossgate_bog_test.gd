extends "res://tests/forest-shrine/crossgate_shin_skills_test.gd"

const BOG_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Bog/Gameplay/"

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(BOG_OUT+filename)==OK,"Captured "+filename)

func pose_cost(visual:Node)->float:
 var started=Time.get_ticks_usec()
 for i in 1200:visual.animate(STEP,5,true,0,0,false,0,false)
 return (Time.get_ticks_usec()-started)/1200.0

func settle(home:Vector3):
 game.hit_stop=0
 super.settle(home)
 game.camera_rig.camera.global_position=home+Vector3(0,12,20)
 game.camera_rig.camera.look_at(home+Vector3(0,4,-8))
 for i in 60:
  if game.player.is_on_floor():break
  step_player(1)
 check(game.player.is_on_floor(),"Bog's fixture confirms physical floor contact before casting")

func run():
 create_timer(100).timeout.connect(func():printerr("BOG_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(BOG_OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 p.select_character(Roster.SHIN_ID)
 var shin=p.model
 var shin_cost=pose_cost(shin)
 game.show_rogue_roster();await frames(3)
 var card=game.menu.find_child("RogueFighter_bog",true,false)
 check(card!=null,"Bog appears in Character Select")
 var picker:Button=card.find_child("BogSkin",true,false)
 check(picker.catalog.size()==2 and picker.catalog.keys()[0]==100625 and picker.catalog.keys()[1]==100942,"Bog offers only the two approved old-model skins")
 card.pressed.emit()
 check(p.character_id==Roster.BOG_ID and p.model.variant_skin==100625,"Gallery selects Bog with gray hair / black")
 var visual=p.model
 var kit=p.active_ability
 var presentation=game.crowd.army.presentation
 check(kit.get_script()==p.character_abilities[Roster.SHIN_ID].get_script(),"Bog reuses the existing Cross Gate combat owner")
 check(p.spell_loadout.numbered_slots[0][0]=="乾坤" and p.spell_loadout.numbered_slots[1][0]=="連擊" and p.spell_loadout.numbered_slots[3][0]=="明鏡止水","Bog's numbered slots are 1 乾坤, 2 連擊 and 4 明鏡止水")
 check(p.spell_loadout.numbered_slots[2][0]=="召喚穴熊" and p.spell_loadout.numbered_slots[4].is_empty() and not visual.can_swap_stance(),"Bog has key 3 cave bears, no key 5 skill or weapon switching")
 check(p.spell_loadout.equip(Roster.BOG_ID,"equip","kazi/fire"),"Bog accepts a shared spell override")
 check(p.spell_loadout.equip(Roster.BOG_ID,"equip",""),"Removing Bog's override restores his native axe skill")
 check(Roster.valid_skin(Roster.BOG_ID,-1)==100625 and Roster.valid_skin(Roster.BOG_ID,"100942")==100625,"Invalid or malformed saved skin IDs fall back to the approved default")
 check(SoundLibrary.original_for(Roster.BOG_ID,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(Roster.BOG_ID,"land")==SoundLibrary.HUMANOID_LANDING,"Bog uses the prepared Goemon footsteps and landing")
 var home=Vector3(-120,0,125)
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 var dummy=game.training_dummy
 dummy.position=home+Vector3.FORWARD*2.3;dummy.home=dummy.position
 game.impact_confirmed.connect(func(victim,_strength,_time):victims.append(victim))
 game.settings.disable_character_cooldowns=false;game.tuning.invincible=false
 var body_nodes=visual.body.get_child_count()
 var presentation_nodes=presentation.get_child_count()
 for skin in [100625,100942]:
  game.show_rogue_roster();await frames(2)
  card=game.menu.find_child("RogueFighter_bog",true,false)
  picker=card.find_child("BogSkin",true,false)
  picker.select_skin(skin)
  var portrait:AtlasTexture=card.find_child("SelectionPortrait",true,false).texture
  game.forest_ui.sync_character()
  check(p.model==visual and visual.motions.id==skin and visual.motions.weapon=="axe" and portrait.atlas==Roster.skin_portrait(Roster.BOG_ID,skin) and game.forest_ui.hero_portrait.texture==game.forest_ui.PaintedHeads.portrait(Roster.BOG_ID,game.settings),"Skin %d updates the axe model and gallery while selecting Bog's matching painted HUD head"%skin)
  await capture("Bog %d gallery.png"%skin)
  game.close_rogue_roster();fresh();settle(home)
  check(is_equal_approx(visual.sprite.pixel_size*visual.body_height_pixels,shin.sprite.pixel_size*shin.body_height_pixels),"Skin %d matches the established Cross Gate standing body height, excluding the axe"%skin)
  check(is_equal_approx(p.melee_strike_reach(),(kit.SHIN_DEFAULT_WEAPON_REACH+kit.CUT_RADIUS)*visual.basis.get_scale().x*p.melee_range_multiplier()),"Axe reach uses the existing melee and ground-ring contract")
  victims.clear();p.swap_weapon()
  check(visual.motions.weapon=="axe","Cycling leaves Bog equipped with the axe")
  tap("light_attack")
  var rate=p.attack_speed_multiplier()
  kit.tick(.575/rate)
  check(victims.is_empty(),"Axe waits for its first source contact")
  kit.tick(.003/rate)
  check(game.last_sound_voice.stream==SoundLibrary.CROSSGATE_AXE_SOUNDS[106],"Axe plays original swing 106 before contact")
  kit.tick(.031/rate)
  check(victims==[dummy] and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_AXE_SOUNDS[136],"First axe contact plays recovered impact 136 once")
  visual.show_pose(5,kit.elapsed,false)
  await capture("Bog %d axe contact.png"%skin)
  kit.tick(.512/rate)
  check(victims==[dummy,dummy] and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_AXE_SOUNDS[138],"Second axe contact reuses the original distinct impact 138")
  kit.tick(.6/rate)
  check(victims.size()==2 and not kit.is_attacking(),"Axe recovery adds no stale hit")
  var warm_resources=0
  for repetition in 3:
   p.attack_chain.reset();kit.clear_cooldowns();settle(home);victims.clear()
   press(KEY_1)
   check(visual.combo_glow.visible and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"乾坤 reuses the original charge art and sound")
   step_player(28)
   for i in 100:
    step_player(1)
    if not victims.is_empty():break
   check(victims==[dummy] and presentation.effects.any(func(fx):return fx.kind=="shin_sure_strike"),"乾坤 uses one shared area contact and the recovered red EX effect")
   if repetition==0:
    step_player(5);await capture("Bog %d 乾坤.png"%skin)
   step_player(120)
   p.hp=p.max_hp*.4;var initial:float=p.hp
   kit.clear_cooldowns();press(KEY_4)
   check(visual.combo_glow.visible and game.last_sound_voice.stream.resource_path.ends_with("/cgefc10.wav"),"明鏡止水 reuses the original cast sound")
   var release:float=visual.motions.clips["6:0"].release
   step_player(int(release/STEP)-1)
   check(p.hp==initial and visual.current_clip.begins_with("6:") and visual.sprite.texture.resource_path.ends_with("/cast-0.png"),"Meditation retains Bog's original axe casting animation before healing")
   if repetition==0:await capture("Bog %d 明鏡止水 cast.png"%skin)
   step_player(3)
   check(not visual.combo_glow.visible and p.hp==initial,"Meditation glow ends at Bog's source release marker")
   step_player(80)
   check(is_equal_approx(p.hp,initial*1.5) and game.last_sound_voice.stream.resource_path.ends_with("/cgefc05.wav"),"Meditation heals once with the shared recovery sound")
   press(KEY_4)
   check(not kit.is_attacking(),"Meditation cooldown blocks immediate repeated use")
   p.attack_chain.reset();kit.clear_cooldowns();settle(home);victims.clear()
   press(KEY_2)
   check(visual.combo_glow.visible and kit.ticket.action=="kazi_combo","連擊 starts the shared chain with its original charge")
   var health:float=p.hp;p.invuln=0;p.take_hit(10,Vector3.BACK)
   check(p.hp==health,"連擊 preserves the existing charge protection")
   for i in 400:
    step_player(1)
    if repetition==0 and not captured and presentation.effects.any(func(fx):return fx.kind=="shin_combo"):
     captured=true;await capture("Bog %d 連擊.png"%skin)
    if not kit.is_attacking():break
   check(victims.size()==7 and not kit.is_attacking(),"連擊 reuses seven axe strikes, retargeting and EX contacts")
   check(visual.body.get_child_count()==body_nodes,"Repeated skills retain the same sprites and shadow pool")
   check(presentation.get_child_count()==presentation_nodes,"Repeated skills retain the shared presentation pools")
   var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
   if repetition==0:warm_resources=resources
   else:check(resources<=warm_resources,"Repeated skills do not grow the resource count after warmup")
  visual.jump_age=.01;visual.jump_count=1
  check(visual.show_jump_pose(false,5) and visual.current_clip.begins_with("9:"),"Bog jumps with his own prepared axe guard")
  visual.jump_landing_left=visual.JUMP_LANDING
  check(visual.show_jump_pose(true,0) and visual.current_clip.begins_with("10:"),"Bog lands with his original fall frames")
  visual.reset_jump_pose();settle(home)
  kit.clear_cooldowns();press(KEY_1);victims.clear()
  game.select_crossgate_skin(Roster.BOG_ID,100942 if skin==100625 else 100625)
  step_player(120)
  check(victims.is_empty() and not visual.combo_glow.visible,"Skin changes cancel pending damage and charge effects")
  captured=false
 var config=ConfigFile.new()
 check(config.load(cfg)==OK and config.get_value("settings","bog_skin")==100625,"Bog's skin persists independently in settings")
 samples.sort()
 print("BOG_PERFORMANCE pose_us_shin=%.2f pose_us_bog=%.2f player_p95_us=%d body_nodes=%d"%[shin_cost,pose_cost(visual),samples[int(samples.size()*.95)],body_nodes])
 game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("BOG_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

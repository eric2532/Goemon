extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const OUT="res://build/Other Files/Asset Toolkit/Kaz Kagerou/BlueCG/"
const STEP=1.0/60.0

func press_six(echo:bool=false):
 var key=InputEventKey.new();key.physical_keycode=KEY_6;key.pressed=true;key.echo=echo
 game.player._unhandled_input(key)
 key.pressed=false;game.player._input(key)

func heard_dodge(before:int)->bool:
 return game.voice_idx==before+1 and game.last_sound_voice.get_meta("kind")=="cg_kagerou_dodge" and game.last_sound_voice.stream==SoundLibrary.KAZ_KAGEROU_DODGE

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+filename)==OK,"Captured "+filename)

func run():
 create_timer(120).timeout.connect(func():quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 p.select_character(34);fresh()
 p.spell_loadout.equip(34,"special_6",p.spell_loadout.Catalog.KAGEROU)
 # Motion/contact coverage must not depend on the level-one random dodge roll.
 preload("res://scripts/spells/skill_balance.gd").set_modifier(p,"kazi/kagerou","motion-fixture",{"chance":1.0})
 game.forest_ui.message_left=0
 game.tuning.invincible=false
 var home=Vector3(-150,0,127)
 home.y=game.model.surface_height(home.x,home.z)+.1
 p.global_position=home
 p.facing=Vector3.LEFT
 game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,4.5,10);camera.look_at(home+Vector3.UP*1.25)
 var kit=p.active_ability
 var model=p.model
 model.show_pose(0,0,true)
 var shadows:Array[Sprite3D]=model.kagerou_shadows
 var shadow=shadows.front()
 var ui=game.forest_ui
 var hp:float=p.hp
 ui.sync()
 check(ui.loadout_buttons[5].visible and ui.helper_portraits[5].texture==p.spell_loadout.Catalog.KAGEROU_ICON and ui.loadout_cooldowns[5].text=="OFF","Kaz has the afterimage icon and starts off")
 await capture("ready.png")
 var sound:int=game.voice_idx
 press_six()
 ui.sync()
 check(kit.kagerou_enabled and heard_dodge(sound) and not shadow.visible and ui.loadout_buttons[5].button_pressed and ui.loadout_cooldowns[5].text=="ON","Key 6 enables dodge, lights the icon and plays the original cue")
 sound=game.voice_idx
 press_six(true)
 check(kit.kagerou_enabled and game.voice_idx==sound,"Holding 6 does not toggle repeatedly or replay the sound")
 var origin:Vector3=model.sprite.global_position
 var velocity:Vector3=p.velocity
 var pose:Rect2=model.sprite.region_rect
 p.take_hit(20,Vector3.RIGHT)
 check(heard_dodge(sound),"The avoided hit also plays the original cue")
 model.tick_kagerou_dodge(STEP)
 check(shadow.visible and shadow.region_rect==pose and shadow.texture==model.sprite.texture and shadow.global_position.is_equal_approx(origin),"First clone freezes the sprite at the contact point")
 check(is_equal_approx(shadow.modulate.a,128.0/255.0),"Clone uses the client's 128/255 alpha")
 for i in 11:
  model.tick_kagerou_dodge(STEP)
  model.show_pose(0,0,true)
 check(shadow.global_position.is_equal_approx(origin) and shadows.all(func(s):return s.visible),"Six stamps coexist and the oldest survives its first eleven ticks")
 await capture("afterimage.png")
 model.tick_kagerou_dodge(STEP)
 var pixel:float=model.sprite.pixel_size*model.global_basis.x.length()
 var peak:Vector3=origin+Vector3.RIGHT*52*pixel
 check(model.sprite.global_position.is_equal_approx(peak) and p.global_position==home,"Kaz retreats exactly 52 source pixels over 13 updates")
 check(shadow.global_position.is_equal_approx(origin+Vector3.RIGHT*48*pixel),"The first clone's slot is reused at exactly 12 ticks of age")
 sound=game.voice_idx
 p.take_hit(20,Vector3.LEFT,true)
 check(p.hp==hp and p.velocity==velocity and p.invuln==0 and game.voice_idx==sound,"An overlapping projectile is evaded without knockback or a second cue")
 model.tick_kagerou_dodge(STEP*15)
 check(model.sprite.global_position.is_equal_approx(peak),"Kaz holds the full retreat through tick 28")
 for i in 6:
  model.tick_kagerou_dodge(STEP)
  model.show_pose(0,0,true)
 await capture("return.png")
 model.tick_kagerou_dodge(STEP*6)
 check(model.sprite.global_position.is_equal_approx(origin) and shadows.any(func(s):return s.visible),"Return snaps home at tick 40 and existing stamps finish independently")
 model.tick_kagerou_dodge(STEP*10)
 check(shadows.filter(func(s):return s.visible).size()==1,"The last stamp stays visible through tick 50")
 model.tick_kagerou_dodge(STEP*2)
 check(shadows.all(func(s):return not s.visible),"All stamps have expired after their source lifetime")
 model.tick_kagerou_dodge(30.0)
 check(kit.kagerou_enabled,"The toggle stays on without a timeout")

 var army=game.army_runtime
 army.record_events=true
 var point=home+Vector3.FORWARD*2.5
 point.y=game.model.surface_height(point.x,point.z)
 game.model.waves.spawn_enemy(0,point)
 army.import_arrivals()
 var native_hit=false
 for i in 86:
  model.tick_kagerou_dodge(STEP)
  army.integration_tick(STEP)
  if army.event_log.any(func(event):return event.kind=="external_damage" and event.target_id==0 and event.unit_kind==0):
   native_hit=true;break
 check(native_hit and p.hp==hp and model.kagerou_tick>=0,"A real native soldier attack triggers the same dodge")
 sound=game.voice_idx
 press_six()
 ui.sync()
 check(not kit.kagerou_enabled and heard_dodge(sound) and not ui.loadout_buttons[5].button_pressed and ui.loadout_cooldowns[5].text=="OFF","Key 6 turns dodge off immediately and plays the same cue")
 p.take_hit(20,Vector3.RIGHT)
 check(p.hp<hp,"A hit can damage Kaz immediately after toggling off")
 p.invuln=0
 press_six()
 check(kit.kagerou_enabled,"Kaz can toggle straight back on")
 p.select_character(1);game.forest_ui.sync()
 check(not kit.kagerou_enabled and model.kagerou_tick<0 and not game.forest_ui.loadout_buttons[5].visible,"Switching fighters clears the toggle and reaction")
 p.select_character(34);press_six()
 var nodes=get_node_count()
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var samples=PackedInt32Array()
 for i in 30:
  p.take_hit(20,Vector3.RIGHT,i%2==0)
  for tick in 52:
   var started=Time.get_ticks_usec()
   model.tick_kagerou_dodge(STEP)
   samples.append(Time.get_ticks_usec()-started)
 samples.sort()
 print("KAGEROU_SPRITE_STEP_US p95=",samples[floori((samples.size()-1)*.95)]," max=",samples[-1])
 check(model.kagerou_shadows==shadows and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Thirty dodges reuse six prepared sprites and retain no new resources")
 p.cancel_charge()
 check(not kit.kagerou_enabled and not shadow.visible,"Run reset clears Kagerou")
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("KAGEROU_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

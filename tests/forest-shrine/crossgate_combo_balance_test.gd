extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Balance=preload("res://scripts/character_balance.gd")
const SLIME_SIZE=preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER
const BASE_HEIGHT=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT
const OUT="res://build/Other Files/Combo Balance/"
const STEP=1.0/60
var samples:Array[int]=[]
var victims:Array=[]
var driver
var sound_events:Array=[]
var sound_cursor=0

func advance(count:int):
 for i in count:
  var before=Time.get_ticks_usec()
  game.player._physics_process(STEP)
  samples.append(Time.get_ticks_usec()-before)
  game.army_runtime.flush_presentation()
  game.crowd.army.presentation.tick(STEP)
  for voice in game.voices:
   if int(voice.get_meta("order",-1))>sound_cursor:sound_events.append({"kind":voice.get_meta("kind"),"stream":voice.stream,"order":voice.get_meta("order")})
  sound_cursor=game.voice_idx

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)

func shine_size(model)->float:
 var glow:Sprite3D=model.combo_glow
 var cell=glow.texture.get_size()/Vector2(glow.hframes,glow.vframes)
 return maxf(cell.x,cell.y)*glow.pixel_size*glow.global_basis.get_scale().x

func run():
 create_timer(120).timeout.connect(func():quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 game.training_dummy.position=Vector3(0,-100,0)
 game.impact_confirmed.connect(func(victim,_strength,_duration):victims.append(victim))
 for id in [Balance.Roster.KAZI_ID,Balance.Roster.SHIN_ID,Balance.Roster.BOG_ID]:
  check(game.balance_value(id,"combo_charge_size")==1.0 and is_equal_approx(game.balance_value(id,"combo_effect_height"),SLIME_SIZE/BASE_HEIGHT) and is_equal_approx(game.balance_value(id,"combo_splash_radius"),SLIME_SIZE*.5),"Fighter %d starts with the shared slime-sized combo baseline"%id)
 check(Balance.sanitized({"combo_charge_size":INF,"combo_effect_height":"2","combo_splash_radius":NAN},34).is_empty(),"Invalid combo values are rejected")
 check(Balance.sanitized({"combo_charge_size":0,"combo_effect_height":99,"combo_splash_radius":-1},34)=={"combo_charge_size":.1,"combo_effect_height":10.0,"combo_splash_radius":0.0},"Combo values stay inside editor limits")
 check(Balance.sanitized({"combo_charge_size":2},Balance.Roster.RUBY_ID).is_empty(),"Fighters without this combo do not gain unused controls")
 for id in [34,37]:
  game.show_character_balance(false,id);await frames()
  var editor=game.menu.find_child("CharacterBalance",true,false)
  check(editor.find_child("ComboBaseline",true,false)!=null,"Fighter %d shows its original baseline"%id)
  for row in [["combo_charge_size",1.5],["combo_effect_height",3.0],["combo_splash_radius",4.0]]:
   var spin=editor.find_child("Balance_"+row[0],true,false)
   check(spin!=null,"Editor exposes "+row[0])
   spin.value=row[1]
  var last=editor.find_child("Balance_combo_splash_radius",true,false)
  last.get_parent().get_parent().get_parent().ensure_control_visible(last)
  await capture("%d settings"%id)
 check(is_equal_approx(game.balance_value(Balance.Roster.BOG_ID,"combo_splash_radius"),SLIME_SIZE*.5),"Editing Kaz and Shin preserves Bog")
 game.update_character_tuning(34,"combo_splash_radius",12)
 game.character_tuning={};game.load_settings()
 check(game.balance_value(34,"combo_splash_radius")==12 and game.balance_value(37,"combo_splash_radius")==4,"Different per-fighter values survive saving and reloading")
 game.reset_character_tuning(34)
 check(is_equal_approx(game.balance_value(34,"combo_effect_height"),SLIME_SIZE/BASE_HEIGHT) and game.balance_value(37,"combo_effect_height")==3.0,"Reset restores only the selected fighter")
 game.reset_character_tuning(37);game.resume()
 var home=Vector3(-150,0,127);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 var army=game.army_runtime
 var targets:Array=[]
 for offset in [Vector3(0,0,-4),Vector3(8,0,-4),Vector3(24,0,-4)]:
  var point=home+offset;point.y=game.model.surface_height(point.x,point.z)
  var row=game.model.waves.spawn_enemy(0,point,-1,targets.size())
  row.hp=100000.0;row.max_hp=row.hp;army.import_arrivals();targets.append(game.actors[row.id])
 army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
 for id in [34,37,Balance.Roster.BOG_ID]:
  p.select_character(id);fresh()
  for radius in [0.0,4.0,12.0]:
   game.update_character_tuning(id,"combo_charge_size",1.5)
   game.update_character_tuning(id,"combo_effect_height",3.0)
   game.update_character_tuning(id,"combo_splash_radius",radius)
   p.active_ability.cancel();p.active_ability.clear_cooldowns();p.attack_chain.reset()
   p.global_position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.impact_pause=0
   await driver.advance(1,func(_delta):advance(20))
   game.camera_rig.camera.global_position=home+Vector3(8,8,18)
   game.camera_rig.camera.look_at(home+Vector3(0,1,-4))
   victims.clear()
   var kit=p.active_ability
   sound_events.clear();sound_cursor=game.voice_idx
   kit.start_combo()
   if not kit.is_attacking():quit(1);return
   check(game.voice_idx==sound_cursor+1 and game.last_sound_voice.get_meta("kind")=="cg_combo_charge" and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"Fighter %d opens 連擊 with its prepared shine sound once"%id)
   check(kit.is_attacking() and is_equal_approx(shine_size(p.model),SLIME_SIZE*(91.0/357.0)*1.5),"Fighter %d applies its slime-based charge size once"%id)
   game.update_character_tuning(id,"combo_effect_height",5)
   game.update_character_tuning(id,"combo_splash_radius",0 if radius>0 else 12)
   check(kit.ticket.combo_effect_height==3 and kit.ticket.combo_splash_radius==radius,"An active combo keeps its starting settings")
   for i in 100:
    advance(1)
    if not victims.is_empty():break
   check(victims.size()==(2 if radius==12 else 1) and victims.has(targets[0]) and not victims.has(targets[2]),"Fighter %d uses radius %s for native damage (%s hits)"%[id,radius,victims.size()])
   sound_events.sort_custom(func(a,b):return a.order<b.order)
   check(sound_events.map(func(event):return event.kind)==["cg_combo_charge","swing","hit"],"Fighter %d plays charge, weapon swing and impact once, including splash"%id)
   var swing:AudioStream=SoundLibrary.original_for(id,"swing") if id==34 else kit.shin_sound(false)
   var impact:AudioStream=SoundLibrary.KAZ_SWORD_IMPACTS.hit if id==34 else kit.shin_sound(true)
   check(sound_events.size()==3 and sound_events[0].stream==SoundLibrary.CROSSGATE_FLASH and sound_events[1].stream==swing and sound_events[2].stream==impact,"Fighter %d uses its own prepared weapon samples"%id)
   var fx=game.crowd.army.presentation
   var key="kazi_combo" if id==34 else "shin_combo"
   var pixels=fx.COMBO_BURST_SIZE_PIXELS if id==34 else fx.SHIN_COMBO_SIZE_PIXELS
   check(fx.effects.any(func(effect):return effect.kind==key and is_equal_approx(effect.scale*pixels*fx.CONTACT_PIXEL_SIZE,BASE_HEIGHT*3)),"Fighter %d uses its snapshotted burst size"%id)
   if radius==12:await capture("%d tuned hit"%id)
   kit.cancel();advance(40)
  if id==37:
   p.active_ability.clear_cooldowns();p.active_ability.start_charge("shin_sure_strike")
   check(is_equal_approx(shine_size(p.model),SLIME_SIZE*(91.0/357.0)),"Other Shin skills restore their slime-sized starting shine")
   p.active_ability.cancel()
  game.reset_character_tuning(id)
 # Earlier cases stop at the first hit; warm the complete chain's pooled effects.
 p.active_ability.clear_cooldowns();p.global_position=home;p.velocity=Vector3.ZERO
 await driver.advance(1,func(_delta):advance(20))
 p.active_ability.start_combo();advance(150);p.active_ability.cancel();advance(40)
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 sound_events.clear();sound_cursor=game.voice_idx
 for i in 8:
  p.active_ability.clear_cooldowns();p.global_position=home;p.velocity=Vector3.ZERO
  await driver.advance(1,func(_delta):advance(20))
  p.active_ability.start_combo();advance(150);p.active_ability.cancel();advance(40)
 await frames(3)
 check(sound_events.size()>14 and sound_events.all(func(event):return event.kind in ["cg_combo_charge","swing","hit"]),"Complete repeated chains retain the starting shine cue and weapon sounds")
 check(sound_events.filter(func(event):return event.kind=="cg_combo_charge").size()==8,"Each repeated chain plays the starting shine sound once, not once per hop")
 print("COMBO_REUSE nodes=",nodes,"/",get_node_count()," resources=",resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated combos retain no new nodes or resources")
 samples.sort()
 print("COMBO_BALANCE player_step_p95_ms=",samples[floori(samples.size()*.95)]*.001," max_ms=",samples.back()*.001)
 game.queue_free();paused=false;await frames()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("COMBO_BALANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)


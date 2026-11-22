extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const OUT="res://build/Other Files/Shared Cross Gate Skills/"
const DT=1.0/60
var driver
var impacts:Array=[]
var samples:Array[int]=[]
var home=Vector3(-150,0,127)

func press(number:int):
 var event=InputEventKey.new();event.physical_keycode=KEY_1+number-1;event.pressed=true
 game.player._unhandled_input(event)
 event.pressed=false;game.player._input(event)

func advance(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  game.player._physics_process(DT)
  game.army_runtime.flush_presentation()
  game.crowd.army.presentation.tick(DT)
  samples.append(Time.get_ticks_usec()-start)

func settle():
 var p=game.player
 p.cancel_charge();p.attack_chain.reset();p.clear_character_cooldowns()
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.impact_pause=0;game.hit_stop=0
 if p.character_id in [27,29]:p._clear_large_character_spawn()
 await driver.advance(1,func(_delta):advance(60))
 check(p.is_on_floor(),"Fighter %d settles on actual arena ground"%p.character_id)

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)

func verify_reuse():
 var p=game.player;var loadout=p.spell_loadout;var army=game.army_runtime
 p.select_character(Catalog.Roster.RUBY_ID);await frames(2);await settle();loadout.clear_cooldowns()
 army.clear();army.refresh_kits();p.mana=p.max_mana;press(3)
 for i in 120:army.integration_tick(DT)
 var snapshot:Dictionary=army.render_snapshot()
 check(snapshot.kinds.count(21)==5,"A borrowed bear cast creates five real native guards")
 var hp_ok=true
 for i in snapshot.kinds.size():
  if snapshot.kinds[i]==21:hp_ok=hp_ok and snapshot.hp[i]==150
 check(hp_ok,"Borrowed bears start with 150 health")
 p.tick_mana(15);press(3)
 p.tick_mana(20);press(3)
 for i in 120:army.integration_tick(DT)
 check(army.render_snapshot().kinds.count(21)==15,"Repeated borrowed bear casts accumulate the full pack")
 army.flush_presentation();await capture("Uru borrowed bear pack")
 army.clear();army.refresh_kits()
 game.training_dummy.home=home+Vector3.DOWN*100;game.training_dummy.position=game.training_dummy.home
 var targets:Array=[]
 for i in 8:
  var point=home+Vector3(sin(i*TAU/8),0,cos(i*TAU/8))*4
  point.y=game.model.surface_height(point.x,point.z)
  var row=game.model.waves.spawn_enemy(0,point)
  row.hp=100000;row.max_hp=100000;army.import_arrivals();targets.append(game.actors[row.id])
 army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
 game.update_character_tuning(Catalog.Roster.RUBY_ID,"critical_chance",0)
 game.update_character_tuning(Catalog.Roster.KAZI_ID,"combo_splash_radius",0)
 await settle();loadout.clear_cooldowns();p.tick_mana(9);impacts.clear();press(5);advance(1000)
 var first:float=targets.reduce(func(total,target):return total+100000-army.unit_state(target.handle).hp,0.0)
 check(impacts.size()==3 and impacts.all(func(target):return target in targets),"The level-one shared combo lands its three contacts on real native enemies")
 check(first>0,"The confirmed contacts cause native damage")
 # Uru's full native staff sequence lasts longer than the five-second cooldown.
 check(loadout.cooldown_for("special_5")==0,"The original cooldown expires during Uru's longer native combo")
 advance(330);p.position=home;p.velocity=Vector3.ZERO;game.hit_stop=0;p.impact_pause=0
 var before:float=targets.reduce(func(total,target):return total+army.unit_state(target.handle).hp,0.0)
 press(5);advance(1000)
 var second:float=before-targets.reduce(func(total,target):return total+army.unit_state(target.handle).hp,0.0)
 check(is_equal_approx(second,first*1.5),"Consecutive shared casts retain the 1.5× second-cast damage")
 check(loadout.equip(p.character_id,"special_5","") and loadout.equip(p.character_id,"special_5",Catalog.COMBO) and loadout.cooldown_for("special_5")==0,"Re-equipping preserves the already-expired cooldown")
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 6:
  p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0;game.hit_stop=0
  loadout.clear_cooldowns();press(5);advance(1000)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated borrowed combos retain no extra nodes or resources")
 loadout.interrupt()
 p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0;game.hit_stop=0
 loadout.clear_cooldowns();press(5)
 check(loadout.current!=null and loadout.current.controller.clip=="6","A borrowed combo enters charge before cancellation")
 var contacts=impacts.size()
 loadout.equip(p.character_id,"special_5","");advance(1000)
 check(loadout.current==null and impacts.size()==contacts,"Changing the equipped combo cancels pending contacts")

func run():
 create_timer(240).timeout.connect(func():printerr("SHARED_CROSSGATE_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 var p=game.player;var loadout=p.spell_loadout
 var dummy=game.training_dummy;dummy.position=home+Vector3.FORWARD*3;dummy.home=dummy.position
 game.impact_confirmed.connect(func(victim,_strength,_duration):impacts.append(victim))
 game.settings.disable_character_cooldowns=false;game.tuning.critical_chance=0
 check(Catalog.all().has(Catalog.COMBO) and Catalog.all().has(Catalog.BEARS),"Both skills appear in the shared catalog")
 for id in [Catalog.Roster.BOG_ID,Catalog.Roster.SHIN_ID,Catalog.Roster.SHIN_SPECIAL_ID]:
  p.select_character(id)
  game.show_rogue_roster()
  var editor=load("res://scripts/spells/spell_picker.gd").new();editor.game=game;game.menu.add_child(editor)
  await frames(2)
  var picker=game.menu.find_child("SpellSlot_equip",true,false)
  check(picker!=null and picker.is_visible_in_tree(),"Fighter %d exposes editable skill slots"%id)
  await capture("Fighter %d unlocked loadout"%id)
  editor.free();game.close_rogue_roster()
 for id in Catalog.Roster.CROSSGATE:
  p.select_character(id);fresh();await frames(1)
  check(loadout.equip(id,"sky_strike",Catalog.BEARS) and loadout.equip(id,"special_5",Catalog.COMBO),"Fighter %d accepts both shared spells"%id)
  await frames(2);await settle()
  dummy.position=p.position+Vector3.FORWARD*3;dummy.home=dummy.position
  game.model.update_vision(p.position)
  check(loadout.assignments(id).sky_strike==Catalog.BEARS and loadout.assignments(id).special_5==Catalog.COMBO,"Fighter %d retains its own assignments"%id)
  check(id==Catalog.Roster.KAZI_ID or loadout.instances.has("%d:%s"%[id,Catalog.COMBO]),"Fighter %d prepares or reuses the combo before combat"%id)
  game.forest_ui.sync()
  check(game.forest_ui.helper_portraits[2].visible and game.forest_ui.helper_portraits[4].visible,"Fighter %d displays bear and combo icons"%id)
  var serial:int=game.army_runtime.cave_bear_serial
  p.mana=p.max_mana
  press(3);press(3)
  check(game.army_runtime.cave_bear_serial==serial+5 and p.mana==10,"Fighter %d needs more mana before summoning again"%id)
  p.tick_mana(15);press(3)
  check(game.army_runtime.cave_bear_serial==serial+10 and p.mana==0,"Fighter %d can summon on exact mana after regenerating"%id)
  game.army_runtime.pending_cave_bears.clear()
  var instance=loadout.instances.get("%d:%s"%[id,Catalog.COMBO])
  var controller=p.active_ability if id==Catalog.Roster.KAZI_ID else instance.controller
  var sound_order:int=game.voice_idx
  var heard:Array=[]
  p.tick_mana(9);impacts.clear();press(5)
  check((id==Catalog.Roster.KAZI_ID or loadout.current==instance) and controller.clip=="6","Fighter %d starts shared 連擊 through its assigned key"%id)
  var shine:Sprite3D=controller.cast_model().combo_glow
  check(shine.texture==controller.ShineTiers.textures["110103"],"Fighter %d uses the original level-one charge sheet"%id)
  check(shine.global_position.is_equal_approx(p.model.qi_blast_chest()),"Fighter %d starts the shine at his own body centre"%id)
  check(game.voice_idx==sound_order+1 and game.last_sound_voice.get_meta("kind")=="cg_combo_charge","Fighter %d plays the shared combo opening shine"%id)
  var hp:float=p.hp;p.invuln=0;p.take_hit(1,Vector3.BACK)
  check(p.hp==hp,"Fighter %d retains combo charge protection"%id)
  var captured_combo=false
  for i in 1000:
   advance(1)
   if id==20 and not controller.is_attacking():
    check(p.model.resource.get_meta("clips").has(p.model.current_clip),"A recovered soldier's shared combo uses its own prepared clip")
   for voice in game.voices:
    if int(voice.get_meta("order",-1))>sound_order:heard.append(str(voice.get_meta("kind")))
   sound_order=game.voice_idx
   if not captured_combo and not impacts.is_empty() and id in [1,3,13,18,20,27,28,29,31,32,33,37,38,40]:
    captured_combo=true
    var height:float=p.model.qi_blast_height()
    game.camera_rig.camera.global_position=p.position+Vector3(8,7,14)*maxf(1,height/6.44)
    game.camera_rig.camera.look_at(p.position+Vector3.UP*height*.5)
    await capture("Fighter %d shared combo"%id)
   if not controller.is_attacking():break
  check(impacts.count(dummy)==3 and not controller.is_attacking(),"Fighter %d completes all three level-one contacts on a lone target"%id)
  check(controller.combo_cooldown<=controller.COMBO_COOLDOWN,"Fighter %d retains the existing cooldown while its native animation runs"%id)
  if id==Catalog.Roster.KAZI_ID:
   press(2)
   check(not controller.is_attacking(),"Kaz's native and assigned combo share one cooldown")
  var contact_cue="coin_hit" if Catalog.Roster.is_crossgate_archer(id) else "hit"
  check(heard.count("cg_combo_charge")==1 and heard.has("swing") and heard.count(contact_cue)==impacts.count(dummy),"Fighter %d plays one charge and an original cue for each confirmed contact"%id)
  loadout.interrupt()
 game.save_settings();game.load_settings()
 check(Catalog.Roster.CROSSGATE.keys().all(func(id):return loadout.assignments(id).get("special_5","")==Catalog.COMBO),"Every Cross Gate fighter's assignments survive save/reload validation")
 for id in [Catalog.Roster.BOG_ID,Catalog.Roster.SHIN_ID,Catalog.Roster.SHIN_SPECIAL_ID]:
  p.select_character(id)
  var original_slot:Array=loadout.numbered_slots[0].duplicate()
  check(loadout.equip(id,"equip","kazi/fire") and loadout.numbered_slots[0][0]==Catalog.all()["kazi/fire"].name,"Fighter %d can override a native first slot"%id)
  check(loadout.equip(id,"equip","") and loadout.numbered_slots[0]==original_slot,"Fighter %d restores its original native first slot"%id)
 await verify_reuse()
 samples.sort()
 print("SHARED_CROSSGATE_PROFILE player_us_p95=%d max=%d"%[samples[int(samples.size()*.95)],samples[-1]])
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SHARED_CROSSGATE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

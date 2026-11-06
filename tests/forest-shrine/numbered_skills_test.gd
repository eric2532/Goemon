extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const OUT="res://build/Other Files/Controls 1-5/"
var visual=false
var step_times=[]
var frame_times=[]
var focus_losses=0
const INPUTS=["scripts/player.gd","scripts/game.gd","scripts/hud.gd","scripts/forest/forest_ui.gd","scripts/spells/spell_catalog.gd","scripts/spells/spell_loadout.gd","scripts/spells/spell_picker.gd","scripts/master_chief_hud.gd","assets/characters/musashi/combat/musashi_combat.gd"]
func key(number:int,pressed:bool=true,shift_:bool=false,echo_:bool=false):
 var event=InputEventKey.new();event.physical_keycode=KEY_1+number-1;event.keycode=event.physical_keycode
 event.pressed=pressed;event.shift_pressed=shift_;event.echo=echo_
 Input.parse_input_event(event);Input.flush_buffered_events()
func reset_fighter():
 fresh();var p=game.player;p.hp=p.max_hp;p.dodge_time=0;p.dodge_cooldown=0
 if p.is_rogue_character():p.active_ability.reset_run()
 p.position=ORIGIN-Vector3.UP*.11;p.velocity=Vector3.DOWN*20
 for i in 3:p.move_and_slide()
 p.velocity=Vector3.ZERO
 if p.character_id==27:
  p.position=Vector3(0,game.model.surface_height(0,140)+.01,140)
  for i in 20:p._physics_process(1.0/60)
 if p.character_id==2:p.active_ability.shield_cooldown=0
func advance(n:int):
 var previous=Time.get_ticks_usec()
 for i in n:
  var start=Time.get_ticks_usec();game.player._physics_process(1.0/60)
  if game.player.character_id==13:
   game.player.active_ability.assimilation.set_physics_process(false)
   game.player.active_ability.assimilation._physics_process(1.0/60)
   game.player.active_ability.assimilation.set_physics_process(false)
  for instance in game.player.spell_loadout.instances.values():
   if instance.source_id==13:
    instance.controller.assimilation.set_physics_process(false)
    instance.controller.assimilation._physics_process(1.0/60)
  step_times.append((Time.get_ticks_usec()-start)/1000.0)
  if visual:
   await physics_frame
   if not root.has_focus():focus_losses+=1
   var now=Time.get_ticks_usec();frame_times.append((now-previous)/1000.0);previous=now
  elif i%30==0:await process_frame
func capture(label_:String):
 if not visual:return
 game.forest_ui.sync();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label_+".png")
func run():
 visual=DisplayServer.get_name()!="headless"
 create_timer(220).timeout.connect(func():printerr("NUMBERED_SKILLS_TIMEOUT");quit(1))
 var hashes={}
 for path in INPUTS:hashes[path]=FileAccess.get_sha256("res://"+path)
 await setup_fixture();game.set_process(false)
 if visual:root.grab_focus();DisplayServer.window_move_to_foreground()
 root.title="Goemon · Five skill controls";Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var p=game.player;var ui=game.forest_ui;var loadout=p.spell_loadout
 game.settings.spell_loadouts={};game.ui.show();ui.show();game.model.phase="wave"
 game.camera_rig.camera.position=ORIGIN+Vector3(15,12,25);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,2,-5))
 var serial=game.explorer_helpers.summon_serial
 for character in Catalog.Roster.PLAYABLE_IDS:
  p.select_character(character);reset_fighter();ui.sync()
  check(loadout.numbered_slots.size()==5 and ui.loadout_buttons.size()==5,"Fighter %d has exactly five slots"%character)
  for number in range(1,6):
   reset_fighter();var slot:Array=loadout.numbered_slots[number-1]
   if character==19 and number==2:
    p.position.y+=5;p.velocity=Vector3.UP;p.move_and_slide()
   key(number)
   if slot.is_empty():check(not p.has_offensive_action() and not loadout.held_numbers.has(number),"Fighter %d empty %d does nothing"%[character,number])
   else:
    check(loadout.held_numbers.has(number),"Fighter %d physical key %d reaches %s"%[character,number,slot[0]])
    var active=p.has_offensive_action() or p.dodge_time>0 or p.surge_left>0
    if p.is_rogue_character():active=active or p.active_ability.player.roll>0 or p.active_ability.player.buffTime>0 or p.active_ability.player.drink>0 or p.active_ability.player.cooldowns.roll>0
    if character==2:active=active or p.active_ability.blocks_movement() or p.active_ability.shield_left>0 or p.active_ability.beam_held
    if character==31:active=active or p.active_ability.wind_left>0
    if character==32:active=active or p.active_ability.immolating
    if character==18:active=p.master_chief_combat.weapon_slot==number
    check(active,"Fighter %d key %d actually starts its native ability"%[character,number])
    check(ui.spell_summary.text.contains(slot[0]) and not ui.loadout_buttons[number-1].disabled,"Fighter %d names skill %d in the visible HUD"%[character,number])
   key(number,false,true)
   check(not loadout.held_numbers.has(number),"Fighter %d key %d releases even after Shift changes"%[character,number])
  await frames(1)
 check(game.explorer_helpers.summon_serial==serial,"Numbered skills never hire paid mercenaries")
 # Charged and sustained native moves use the real key down/up path.
 for entry in [[16,1,"ice_charge"],[17,1,"shield_enter"],[17,2,"bazooka_charge"],[15,2,"bombs"],[14,4,"beam"],[19,1,"spin_charge"]]:
  p.select_character(entry[0]);reset_fighter();key(entry[1]);await advance(8)
  check(p.active_ability.is_attacking(),"Held %d/%d stays active through physics"%[entry[0],entry[1]])
  key(entry[1],false)
  if entry[0]==16:check(not p.active_ability.ice_held,"Ice charge releases its native hold")
  if entry[0]==17:check(not p.active_ability.shield_held and not p.active_ability.secondary_held,"Yae releases her native shield / bazooka hold")
  if entry[0]==15:check(not p.active_ability.secondary_held,"Ben releases his native bomb hold")
  if entry[0]==14:check(p.active_ability.mode!="beam","Ed releases his native beam")
  await advance(150)
  check(not loadout.held_numbers.has(entry[1]),"Held %d/%d retires its input"%[entry[0],entry[1]])
 # Edo polls action state instead of only listening for releases.
 p.select_character(2);reset_fighter();p.active_ability.activate_shield();key(4);await advance(20)
 check(p.active_ability.beam_held,"Edo's blue beam remains held from key 4")
 key(4,false);check(not p.active_ability.beam_held,"Edo's numbered beam stops on release")
 # Existing assignments retain their stable saved keys, and all five slots accept a held spell.
 game.settings.spell_loadouts={"1":{"equip":"yae/shield","surge":"ninja/roll","sky_strike":"edo/meteors"}}
 p.select_character(1);reset_fighter();ui.sync()
 check(loadout.numbered_slots[0][0]=="Sword Shield" and loadout.numbered_slots[1][0]=="Wide Shuriken","Old E/R/T assignments appear on 1/2/3")
 for number in range(1,6):
  loadout.equip(1,Catalog.SLOTS.keys()[number-1],"yae/shield");reset_fighter();key(number);await advance(3)
  check(loadout.current!=null and loadout.current.held,"Custom skill works on number %d"%number)
  key(number,true,false,true);key(number,false);await advance(65)
  check(loadout.current==null and loadout.held_slots.is_empty(),"Custom number %d ignores echo and finishes after release"%number)
 game.save_settings();game.load_settings();loadout.prepare()
 check(loadout.assignments(1).size()==5,"All five choices survive saving and loading")
 reset_fighter();key(5);game.show_pause();key(5,false);key(4)
 check(loadout.current==null and loadout.held_numbers.is_empty(),"Pause clears held skills and blocks new numbered casts")
 key(4,false);game.resume();key(1);p.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT);key(1,false)
 check(loadout.current==null and loadout.held_numbers.is_empty(),"Focus loss cancels a held numbered skill")
 key(1);p.select_character(17);key(1,false)
 check(loadout.current==null and not p.active_ability.shield_held,"Switching fighters clears old held casts")
 p.select_character(1);reset_fighter();game.show_rogue_roster();key(2);key(2,false)
 check(loadout.current==null,"Gallery blocks numbered casts")
 game.close_rogue_roster();game.settings.spell_loadouts={};p.select_character(28);reset_fighter();key(1,true,true)
 check(p.active_ability.is_attacking(),"Shift sprint still allows a numbered special during battle");key(1,false)
 p.select_character(13);reset_fighter();ui.sync();await capture("musashi-five-slots")
 # Repeated 3-Way fire retains the already prepared native pool.
 loadout.equip(13,"special_5","musashi/three-way")
 key(5);await advance(50);key(5,false);await advance(90)
 var pool=loadout.instances["13:musashi/three-way"].controller.assimilation;var nodes=pool.get_child_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 3:
  reset_fighter();key(5);await advance(45);key(5,false);await advance(90)
 check(pool.get_child_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated held 3-Way does not grow nodes or resources")
 check(not pool.held and not pool.shots.any(func(s):return s.active),"Repeated 3-Way releases and retires every projectile")
 for character in [1,16,30]:
  p.select_character(character);reset_fighter();ui.sync();await capture("fighter-%d"%character)
 game.show_rogue_roster()
 var picker=load("res://scripts/spells/spell_picker.gd").new();picker.game=game;game.menu.add_child(picker)
 check(picker.choices.size()==5,"Equipment exposes five editable slots")
 await frames(3)
 var footer=picker.get_child(0).get_child(1)
 check(picker.get_global_rect().encloses(footer.get_global_rect()),"Equipment keeps Done and Restore fully visible")
 if visual:
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"equipment.png")
  picker.queue_free();await frames();root.size=Vector2i(960,600);await frames(3)
  picker=load("res://scripts/spells/spell_picker.gd").new();picker.game=game;game.menu.add_child(picker);await frames(3)
  footer=picker.get_child(0).get_child(1)
  check(root.get_visible_rect().encloses(picker.get_global_rect()) and picker.get_global_rect().encloses(footer.get_global_rect()),"Five-slot equipment and footer fit a 960×600 window")
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"equipment-960.png")
 picker.queue_free();await frames()
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"manual_player_step_p95_ms":step_times[floori(step_times.size()*.95)]}
 report.focus_losses=focus_losses
 report.changed_inputs=[]
 for path in hashes:
  if FileAccess.get_sha256("res://"+path)!=hashes[path]:report.changed_inputs.append(path)
 report.input_hashes=hashes
 if visual:report.frame_median_ms=frame_times[frame_times.size()/2];report.frame_p95_ms=frame_times[floori(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 FileAccess.open(OUT+("rendered.json" if visual else "headless.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("NUMBERED_SKILLS_RESULT ",JSON.stringify(report))
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

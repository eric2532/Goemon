extends "res://tests/forest-shrine/crossgate_player_audio_test.gd"

const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const DT=1.0/60
const OUTPUT="res://build/Other Files/Asset Toolkit/Skin Skill Audio/"
const SPELLS=[Catalog.COMBO,Catalog.BEE_FLURRY,Catalog.SURE_STRIKE,Catalog.DOUBLE_EDGE,Catalog.COUNTER,"kazi/qigong",Catalog.MAZE_QI,Catalog.MOON,Catalog.SPIRIT,"kazi/fire","kazi/ice","kazi/wind","kazi/meteor"]
var home=Vector3(-120,0,125)
var driver
var results=[]

func player_steps(count_:int):
 for tick in count_:game.player._physics_process(DT)

func skill_case(spell:String):
 var p=game.player;var bar=p.spell_loadout;var kit=p.active_ability
 bar.cancel();kit.cancel(true);kit.clear_cooldowns();bar.clear_cooldowns();bar.magic_result={}
 p.attack_chain.reset();p.position=home;p.velocity=Vector3.DOWN;p.impact_pause=0;p.facing=Vector3.FORWARD
 await driver.advance(1,func(_dt):player_steps(20))
 game.training_dummy.position=p.position+Vector3.FORWARD*1.6;game.training_dummy.home=game.training_dummy.position
 check(bar.equip(p.character_id,"special_4",spell),"Equip selected-skin skill "+spell)
 var direction=p.combat_attack_direction()
 p.facing=direction
 game.training_dummy.position=p.position+direction*1.6;game.training_dummy.home=game.training_dummy.position
 var pattern=p.model.normal_attack_pattern()
 var cues:Array=pattern.attack.audio_cues
 var layered=[]
 for group in cues:
  for id in group:
   if contract.mix_recipes.has(str(int(id))) and id not in layered:layered.append(id)
 var cursor={"order":game.voice_idx,"steps":0};var events=[];shots.clear();contacts.clear()
 var live=DisplayServer.get_name()!="headless" and p.character_id==34 and spell in [Catalog.BEE_FLURRY,Catalog.MOON]
 var recording:AudioEffectRecord
 var bus=AudioServer.get_bus_index("SFX")
 if live:
  for voice in game.voices:voice.stop()
  recording=AudioEffectRecord.new();recording.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(bus,recording);recording.set_recording_active(true)
 if spell==Catalog.COUNTER:
  kit.begin_shin_counter({"origin":p.position,"basis":Basis(Vector3.UP,atan2(-direction.x,-direction.z)),"facing":direction,"source":0,"target":game.training_dummy,"hits_done":0,"basic":true,"after_dodge":false})
 else:bar._cast(spell,"special_4")
 check(kit.is_attacking() or bar.current!=null or not kit.shin_counter.is_empty(),"Selected skill starts "+spell)
 for frame in (700 if live else 1):
  await driver.advance(1,func(_dt):
   for tick in (1 if live else 700):
    p._physics_process(DT)
    for shot in shots:
     if shot.pool_live:shot._physics_process(DT)
    events.append_array(heard(cursor.order));cursor.order=game.voice_idx;cursor.steps+=1
    if cursor.steps>20 and not kit.is_attacking() and bar.current==null and kit.shin_counter.is_empty():break)
  if cursor.steps>20 and not kit.is_attacking() and bar.current==null and kit.shin_counter.is_empty():break
 if live:
  await create_timer(1.5).timeout
  recording.set_recording_active(false)
  var wav=recording.get_recording()
  check(wav!=null and wav.data.count(0)<wav.data.size(),"Real skill mixer produces audible layered output")
  if wav!=null:check(wav.save_to_wav(OUTPUT+"%d-%s.wav"%[p.model.kaz_skin,spell.get_file()])==OK,"Saved actual skill-audio recording")
  AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 var weapon=events.filter(func(event):return event.kind in ["swing","hit","heavy_hit"])
 var elemental=spell in ["kazi/fire","kazi/ice","kazi/wind","kazi/meteor"]
 if elemental:
  check(weapon.is_empty(),"Elemental casting retains its own spell audio without weapon sounds")
 else:
  check(not weapon.is_empty() and weapon.all(func(event):return matches(event.stream,cues[0] if event.kind=="swing" else cues[1])),"Skill retains the selected skin's cached weapon samples: "+spell)
  check(layered.all(func(id):return weapon.any(func(event):return matches(event.stream,[id]))),"Skill retains every selected skin effect layer: "+spell)
  if spell in [Catalog.COMBO,Catalog.BEE_FLURRY,Catalog.SURE_STRIKE,Catalog.DOUBLE_EDGE,Catalog.COUNTER]:check(not contacts.is_empty(),"Melee skill confirms a real contact")
 check(not kit.is_attacking() and bar.current==null and kit.shin_counter.is_empty(),"Skill completes without a queued cast")
 results.append({"character":p.character_id,"skin":p.model.shin_skin if p.character_id==38 else p.model.kaz_skin,"spell":spell,"weapon_voices":weapon.size(),"contacts":contacts.size(),"player_position":str(p.position),"target_position":str(game.training_dummy.position),"facing":str(p.facing),"effect_ids":layered,"streams":weapon.map(func(event):return str(event.kind)+":"+event.stream.resource_path)})
 bar.cancel();kit.cancel(true)
 for shot in shots:
  if shot.pool_live:shot.retire()

func allied_skills(skin:int):
 var p=game.player;p.select_character(34);choose_skin(34,skin);p.position=home
 var copies=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 var controllers=[];var streams=[];var cursor=game.voice_idx;var events=[]
 for i in 5:
  check(copies.reinforce(34,home+Vector3.RIGHT*.1*i),"Prepare native skill-audio copy")
  var body=copies.bodies.back();body.facing=Vector3.FORWARD;body.ai_aim=home+Vector3.FORWARD*20
  var controller=body.spell_loadout._instance(Catalog.MOON).controller
  streams.append(body.model.attack_sound(false));controllers.append(controller);controller.start_cast()
 for tick in 240:
  for controller in controllers:
   controller.tick(DT);events.append_array(heard(cursor));cursor=game.voice_idx
 var expected=900007 if skin==102488 else 900001
 check(events.filter(func(event):return event.kind=="swing" and matches(event.stream,[expected])).size()==5,"Five native Moon casters retain their selected Fire rise")
 var impact=900008 if skin==102488 else 900009
 check(events.filter(func(event):return event.kind=="hit" and matches(event.stream,[impact])).size()==5,"Five native Moon casters retain their selected Fire impact")
 for controller in controllers:controller.cancel(true)
 copies.dispose();await frames(3)

func run():
 create_timer(600).timeout.connect(func():printerr("SKIN_SKILL_AUDIO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 contract=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/crossgate/player-attacks.json"))
 for id in contract.samples:
  if not contract.samples[id].is_empty():samples[id]=load(contract.samples[id])
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 if is_instance_valid(game.music):game.music.stop()
 for node in [game,game.player,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 var p=game.player;p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.set_auto_attack(false)
 Pool.service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 var rows=[[34,102488],[34,109146]]
 for skin in SHIN_NINE:rows.append([38,skin])
 for row in rows:
  p.select_character(row[0]);choose_skin(row[0],row[1])
  var weapon="unarmed" if row[1]==118986 else "polearm" if row[1]==108313 else "sword"
  p.model.apply_gear_weapon(weapon,Gear.allowed(row[0],game.settings)[weapon])
  for spell in SPELLS:await skill_case(spell)
  print("SKIN_SKILL_AUDIO skin=",row[1]," failures=",failures)
 await allied_skills(102488);await allied_skills(109146)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var pattern=p.model.normal_attack_pattern()
 for repeat in 100:
  p.model.single_strike_sound(pattern.attack);p.model.attack_effect_sound(0,pattern.attack)
 check(nodes==get_node_count() and resources==Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"Repeated skill audio resolution reuses cached resources")
 var file=FileAccess.open(OUTPUT+"verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":results},"  "));file.close()
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKIN_SKILL_AUDIO_RESULT checks=%d failures=%d cases=%d"%[checks,failures,results.size()]);quit(1 if failures else 0)

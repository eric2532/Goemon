extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
const BEE_OUT="res://build/Other Files/Asset Toolkit/Bee Blink Flurry/"
const ID=Pets.Spells.BEE_FLURRY
const Skills=preload("res://scripts/spells/skill_balance.gd")

func check_shine(glow:Sprite3D,level_:int,label_:String):
 var tiers=preload("res://scripts/spells/skill_effects.gd")
 var tier=Skills.Levels.shine_tier(level_)
 var cell=glow.texture.get_size()/Vector2(glow.hframes,glow.vframes)
 var diameter=maxf(cell.x,cell.y)*glow.pixel_size*glow.global_basis.get_scale().x
 check(glow.visible and glow.texture==tiers.textures[tiers.PHYSICAL_SHINES[tier]] and is_equal_approx(diameter,Skills.BASE_DIAMETER*[91.0,168.0,272.0,357.0,357.0][tier]/357.0),"%s level %d uses original shine art and world size"%[label_,level_])

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 if "shine" in name_:
  game.crowd.army.presentation.tick(2)
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
 game.army_runtime.flush_presentation();game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(BEE_OUT+name_+".png")==OK,"Captured "+name_)

func main_step(_dt:float=DT):
 game.player._physics_process(DT);advance()

func clear_enemies():
 game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.refresh_kits();hit_anchors.clear()

func settle_main(id:int):
 clear_enemies()
 var p=game.player;p.select_character(id);p.active_ability.cancel(true);p.cancel_charge();p.attack_chain.reset();p.set_auto_attack(false)
 game.update_character_tuning(id,"critical_chance",0)
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.hp=p.max_hp;p.invuln=0;p.impact_pause=0;p.dodge_time=0;p.smoke_mode=true;p.smoke_move=Vector2.ZERO
 check(p.spell_loadout.equip(id,"equip",ID),"Fighter %d equips Bee Blink Flurry"%id)
 await driver.advance(1,func(_dt):
  for i in 60:p._physics_process(DT))
 check(p.is_on_floor(),"Fighter %d starts on actual ground"%id)

func run():
 create_timer(300).timeout.connect(func():printerr("BEE_FLURRY_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(BEE_OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false);game.music.stop()
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*1000;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.settings.forest_pet_loadout=[];game.tuning.invincible=false;game.settings.disable_character_cooldowns=false;army.record_events=true
 game.camera_rig.camera.global_position=home+Vector3(7,8,16);game.camera_rig.camera.look_at(home+Vector3(0,2,-2))
 game.impact_confirmed.connect(func(enemy,_strength,_time):hit_anchors.append(AttackChain.effect_anchor(enemy).position))
 for id in p.RogueRoster.CROSSGATE:
  await settle_main(id)
  var enemy=spawn(Vector3(0,0,-4));enemy.freeze_for(1000)
  var hp:float=enemy.hp;var start:Vector3=p.global_position
  tap("equip")
  var instance=p.spell_loadout.current
  check(instance!=null,"Fighter %d starts the new skill"%id)
  if instance==null:continue
  var kit=instance.controller
  var player_hp:float=p.hp;p.take_hit(2,Vector3.BACK)
  check(p.hp==player_hp,"Fighter %d is invulnerable during the initial shine"%id)
  check(kit.ticket.critical_chance==5,"Level-one flurry adds exactly five critical-chance points")
  kit.ticket.critical_chance=0 # Isolate fixed base damage from the independent per-hit critical roll.
  check(kit.cast_model().combo_glow.visible and kit.cast_model().combo_glow.texture==kit.ShineTiers.textures["110103"],"Fighter %d begins with the shared original shine"%id)
  check(game.last_sound_voice.get_meta("kind")=="cg_combo_charge" and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"Fighter %d starts with the original shine sound"%id)
  if id==34:await capture("main-charge")
  var previous=Vector3.ZERO;var stops=0
  for tick in 600:
   await driver.advance(1,main_step)
   if tick==0:check(is_equal_approx(kit.elapsed,DT*1.5),"Fighter %d advances the opening shine at 1.5× speed"%id)
   if kit.combo_strikes>stops:
    stops=kit.combo_strikes
    check(game.last_sound_voice.stream==SoundLibrary.original_for(36,"maze_assassination_vanish"),"Blink keeps its original teleport sound")
    var side=(p.global_position-enemy.global_position).normalized()
    if stops>1:check(side.dot(previous)<-.4,"Fighter %d blink %d changes to the opposing side"%[id,stops])
    previous=side
    p.take_hit(2,Vector3.BACK)
    check(p.hp==player_hp,"Fighter %d remains invulnerable at blink %d"%[id,stops])
    if id==34 and stops<=2:await capture("main-hop-%d"%stops)
   if p.spell_loadout.current==null:break
  check(stops==5 and hit_anchors.size()==5,"Fighter %d performs five single hits: %d stops, %d hits"%[id,stops,hit_anchors.size()])
  check(is_equal_approx(hp-enemy.hp,5*preload("res://scripts/spells/skill_balance.gd").normal_damage(p)*p.damage_multiplier()),"Fighter %d deals exactly five normal-damage skill hits"%id)
  check(p.global_position.distance_to(start)<.02,"Fighter %d returns to the exact starting position"%id)
  check(instance.cooldown_remaining()>0,"Fighter %d keeps its skill cooldown after returning"%id)
  p.invuln=0;p.take_hit(2,Vector3.BACK)
  check(p.hp<player_hp,"Fighter %d can take damage again after returning"%id)
  if id==34:await capture("main-return")
  for level_ in [1,9,10,18,19,27,28,30]:
   Skills.set_level(p,ID,level_);kit.clear_cooldowns();tap("equip")
   check_shine(kit.cast_model().combo_glow,level_,"Fighter %d"%id)
   if id==34 and level_ in [1,10,19,28]:
    p.model.show_pose(0,0,false)
    kit.cast_model().combo_glow.frame=6;await capture("main-shine-%02d"%level_)
   p.spell_loadout.interrupt()
  Skills.set_level(p,ID,1)

 await settle_main(34)
 spawn(Vector3(0,0,-4)).freeze_for(1000)
 var library:SoundLibrary=game.sound_library;library.select_character(34)
 library.mutes.cg_combo_charge=true
 var order:int=game.voice_idx;tap("equip")
 check(p.spell_loadout.current!=null and game.voice_idx==order,"Bee shine respects the existing charge mute")
 p.spell_loadout.interrupt();library.mutes.erase("cg_combo_charge")
 var sound_kit=p.spell_loadout.instances["34:"+ID].controller
 sound_kit.clear_cooldowns()
 library.custom.cg_combo_charge=SoundLibrary.KAZ_SWORD_IMPACTS.hit;library.gains.cg_combo_charge=.5
 tap("equip")
 check(game.last_sound_voice.stream==library.custom.cg_combo_charge and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.8*.55*.5),"Bee shine respects recorded charge and gain overrides")
 p.spell_loadout.interrupt();sound_kit.clear_cooldowns();library.custom.erase("cg_combo_charge");library.gains.erase("cg_combo_charge")
 if DisplayServer.get_name()!="headless":
  for voice in game.voices:voice.stop()
  var recorder=AudioEffectRecord.new();var bus=AudioServer.get_bus_index("SFX");var slot=AudioServer.get_bus_effect_count(bus)
  AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true);tap("equip")
  await create_timer(1.3).timeout;recorder.set_recording_active(false)
  var wav=recorder.get_recording()
  check(wav!=null and wav.data.count(0)<wav.data.size() and wav.save_to_wav(ProjectSettings.globalize_path(BEE_OUT+"starting-shine.wav"))==OK,"Actual Bee shine reaches the desktop SFX recording")
  AudioServer.remove_bus_effect(bus,slot);p.spell_loadout.interrupt()
 sound_kit.clear_cooldowns()

 # Distance boundary and interrupted return share the same prepared instance.
 await settle_main(34)
 var kit=p.spell_loadout.instances["34:"+ID].controller
 var range_:float=kit.bee_start_range()
 check(is_equal_approx(range_,2*p.active_ability.melee_visual_reach()),"Skill acquisition is exactly twice the active attack range")
 var enemy=spawn(Vector3(0,0,-range_-.5));enemy.freeze_for(1000);tap("equip")
 check(not kit.is_attacking() and kit.combo_cooldown==0,"Out-of-range targets do not start or spend the skill")
 clear_enemies();enemy=spawn(Vector3(0,0,-4));enemy.freeze_for(1000)
 var start:Vector3=p.global_position;tap("equip")
 for tick in 120:
  await driver.advance(1,main_step)
  if kit.combo_strikes>0:break
 p.spell_loadout.interrupt()
 check(p.global_position.distance_to(start)<.02 and not kit.is_attacking(),"Cancelling mid-flurry returns home and retires the sequence")

 for level_ in range(1,31):
  Skills.set_level(p,ID,level_)
  var rules=Skills.rules_for(p,ID);var ticket=p.attack_chain.make_ticket(ID)
  check(rules=={"damage":1.0,"critical_bonus":float(level_*5)},"Level %d changes only critical chance by five points"%level_)
  check(ticket.critical_chance==minf(100,level_*5) and Skills.damage(p,ticket,0)==250 and Skills.factor(ticket,"size")==1 and Skills.factor(ticket,"hit_area")==1,"Level %d retains damage/size/reach and caps the final chance"%level_)
 var health:float=enemy.hp;kit.clear_cooldowns();tap("equip")
 check(kit.ticket.skill_level==30 and kit.ticket.critical_chance==100,"Level thirty snapshots guaranteed critical chance")
 await driver.advance(1,func(_dt):
  for tick in 600:main_step())
 check(is_equal_approx(health-enemy.hp,2500),"Level thirty lands five double-damage criticals without increasing base damage")
 await capture("level-30-return")
 Skills.set_level(p,ID,1)
 # Warm once, then repeat the complete start/hit/return lifecycle.
 for repeat in 2:
  kit.clear_cooldowns();tap("equip");kit.ticket.critical_chance=0
  await driver.advance(1,func(_dt):
   for tick in 600:main_step())
 await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 8:
  kit.clear_cooldowns();var count_=hit_anchors.size();tap("equip");kit.ticket.critical_chance=0
  await driver.advance(1,func(_dt):
   for tick in 600:main_step())
  check(hit_anchors.size()-count_==5 and p.global_position.distance_to(start)<.02,"Repeated cast %d hits five times and returns once"%repeat)
 await frames(2)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Warmed repeated casts retain no additional nodes/resources")

 # The existing pet owner runs the same new wire code for every companion family.
 var skins=[0,21,41,61,81]
 await equip_pack(skins,skins.map(func(_skin):return [ID,"",""]))
 var origins={};var victims={}
 for skin in skins:
  var h:int=army.handles[army.HOUND_ID-skin];var point:Vector3=army.unit_state(h).position
  origins[skin]=point;victims[skin]=spawn(point-home+Vector3.FORWARD*4);victims[skin].freeze_for(1000)
 var done={};var paths={};var contacts={}
 for tick in 600:
  await driver.advance(1,advance)
  for event in army.event_log:
   if event.kind not in ["pet_skill_started","pet_skill_move","pet_skill_contact"] or event.get("reviewed",false) or int(event.action_index)!=11:continue
   event.reviewed=true
   var skin=army.HOUND_ID-int(event.source_id)
   if event.kind=="pet_skill_started":
    origins[skin]=event.position
    var caster=army.pet_skills.casters[Pets.key(skin)]
    check(caster.ticket.critical_chance==5,"Pet flurry adds its own level-one critical bonus")
    caster.ticket.critical_chance=0
   if event.kind=="pet_skill_contact":contacts[skin]=int(contacts.get(skin,0))+1
   if event.kind=="pet_skill_move":
    if not paths.has(skin):paths[skin]=[]
    paths[skin].append(event.position)
    if paths[skin].size()==6:done[skin]=true
  if not done.is_empty():
   for skin in done:
    var h:int=army.handles[army.HOUND_ID-skin]
    army.native.set_pet_skill_ready(h,0)
  if done.size()==5:break
 for skin in skins:
  check(done.has(skin) and int(contacts.get(skin,0))==5,"Pet skin %d completes five contacts and returns"%skin)
  if paths.get(skin,[]).size()>=6:check(paths[skin][5].distance_to(origins[skin])<.02,"Pet skin %d returns to its start"%skin)
  var caster=army.pet_skills.casters[Pets.key(skin)]
  check(caster.ticket.get("skill_id")==ID and caster.ticket.get("skill_level")==1,"Pet skin %d uses shared skill rules and its own saved loadout"%skin)
  var skill_hits=army.event_log.filter(func(e):return e.kind=="damage" and int(e.source_id)==army.HOUND_ID-skin and int(e.ticket_id)>0)
  check(skill_hits.size()==5 and skill_hits.all(func(e):return is_equal_approx(float(e.amount),250.0)),"Pet skin %d deals exactly five normal base skill hits"%skin)
 var caster=army.pet_skills.casters[Pets.key(61)]
 for level_ in range(1,31):
  Skills.set_level(caster,ID,level_)
  var ticket=caster.attack_chain.make_ticket(ID)
  check(ticket.skill_level==level_ and ticket.critical_chance==minf(100,level_*5) and Skills.damage(caster,ticket,0)==250,"Pet level %d changes only critical chance and keeps base damage"%level_)
 check(Skills.level_for(p,ID)==1,"Pet skill levels stay independent of the main character")
 Skills.set_level(caster,ID,1)
 await capture("five-pets")
 for skin in skins:army.native.set_pet_skill_ready(army.handles[army.HOUND_ID-skin],7)
 await driver.advance(1,func(_dt):
  for tick in 600:advance())
 await frames(2)
 nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var sample_start=costs.size()
 await driver.advance(1,func(_dt):
  for tick in 1800:advance())
 await frames(2)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Five simultaneous warmed pet flurries retain no extra nodes/resources")
 for skin in skins:
  var pet=army.pet_skills.casters[Pets.key(skin)]
  p.position=pet.position+Vector3.RIGHT*5
  for level_ in [1,9,10,18,19,27,28,30]:
   Skills.set_level(pet,ID,level_)
   pet.receive({"kind":"pet_skill_started","ticket_id":pet.native_handle,"action_index":11,"position":pet.position,"direction":pet.facing,"projectile_id":100000+level_,"amount":1.0})
   check_shine(pet.charge,level_,"Pet %d"%skin)
   check(game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"Pet %d level %d starts with the original shine sound"%[skin,level_])
   if skin==61 and level_ in [1,10,19,28]:
    pet.charge.frame=6;await capture("pet-shine-%02d"%level_)
   pet.finish_cast()
  Skills.set_level(pet,ID,1)
 p.position=caster.position+Vector3.RIGHT*5
 library.select_character(34);library.mutes.cg_combo_charge=true
 order=game.voice_idx
 caster.receive({"kind":"pet_skill_started","ticket_id":caster.native_handle,"action_index":11,"position":caster.position,"direction":caster.facing,"projectile_id":200001,"amount":1.0})
 check(caster.charge.visible and game.voice_idx==order,"Pet Bee shine respects the same charge mute")
 caster.finish_cast();library.mutes.erase("cg_combo_charge")
 var timing=costs.slice(sample_start);timing.sort()
 print("BEE_PET_MANUAL_STEP_US p95=",timing[floori(timing.size()*.95)]," max=",timing.back())
 var icon=Pets.Spells.KAZI_ICONS[ID]
 check(icon.get_width()==128 and icon.get_height()==128,"The editable bee teleport icon imports at 128×128")
 icon.get_image().save_png(BEE_OUT+"icon.png")
 check(Pets.skill_codes([ID,"kazi/qigong",Pets.Spells.SPIRIT])==PackedInt32Array([11,3,10]),"New wire code appends without changing saved pet skills")
 var report={"checks":checks,"failures":failures}
 FileAccess.open(BEE_OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BEE_BLINK_FLURRY_RESULT ",JSON.stringify(report))
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

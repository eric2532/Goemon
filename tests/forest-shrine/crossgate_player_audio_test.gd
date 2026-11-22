extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Gear=preload("res://scripts/forest/equipment.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Player Audio/"
const SHIN_NINE=[106707,109140,111624,111625,118986,118987,118993,108313,120440]
var kaz_focused="--kaz-fire" in OS.get_cmdline_user_args()
var water_focused="--water-dragon" in OS.get_cmdline_user_args()
var focused=kaz_focused or water_focused or "--shin-special" in OS.get_cmdline_user_args()
var focused_character=Gear.Roster.SHIN_ID if water_focused else Gear.Roster.KAZI_ID if kaz_focused else Gear.Roster.SHIN_SPECIAL_ID
var focused_skins=[900050] if water_focused else [102488,109146] if kaz_focused else SHIN_NINE
var output=OUT
var contract:Dictionary
var samples:Dictionary={}
var shots:Array=[]
var mismatches:Array=[]
var cases=0

func choose_skin(id:int,skin:int):
 if id==34:game.select_kaz_skin(skin)
 elif id==36:game.select_kaz_skin(preload("res://scripts/kaz_skins.gd").MAZE)
 elif Gear.Roster.is_shin(id):game.select_shin_skin(id,skin)
 else:game.select_crossgate_skin(id,skin)

func heard(after:int)->Array:
 var result=[]
 for voice in game.voices:
  if int(voice.get_meta("order",-1))>after:
   result.append({"order":voice.get_meta("order"),"kind":str(voice.get_meta("kind")),"stream":voice.stream,"pitch":voice.pitch_scale})
 result.sort_custom(func(a,b):return a.order<b.order)
 return result

func matches(stream:AudioStream,ids:Array)->bool:
 for id in ids:
  if int(id)==0 and stream is AudioStreamWAV and stream.data.count(0)==stream.data.size():return true
  var expected:AudioStreamWAV=samples.get(str(int(id)))
  if stream is AudioStreamWAV and expected!=null and stream.data==expected.data:return true
 return false

func attack_case(id:int,skin:int,weapon:String,landed:bool,facing:Vector3=Vector3.FORWARD):
 var p=game.player;var kit=p.active_ability;var visual=p.model
 kit.cancel();p.attack_chain.reset();contacts.clear();p.facing=facing
 game.training_dummy.position=ORIGIN+facing*(1.6 if landed else 200);game.training_dummy.home=game.training_dummy.position
 shots.clear()
 var controlled=p.ai_controlled
 if focused:p.ai_controlled=true;p.ai_aim=ORIGIN+facing*30
 kit.start_attack();p.ai_controlled=controlled
 var direction=visual.direction();var key="%s5:%d"%["fist:" if weapon=="unarmed" and Gear.Roster.has_crossgate_throws(id) and not visual.gear_external else "",direction]
 var profile:Array=contract.profiles[visual.native_root if not visual.gear_external else visual.gear_route.root]
 var definition:Dictionary=profile[visual.shin_weapon_index if not visual.gear_external else 0]
 if not definition.has(key):kit.cancel();return
 var expected:Array=definition[key]
 var swing_quota=1 if visual.fighter.strike=="bow" or (visual.fighter.strike=="timed" and kit.cut_times.is_empty()) else kit.sound_cues.filter(func(cue):return visual.fighter.strike!="staff" or int(cue.get("id",0))!=139).size()
 var observed=[];var cursor=game.voice_idx
 var pattern=visual.normal_attack_pattern();var rate=p.attack_speed_multiplier()
 for tick in ceili(float(pattern.duration)*120)+2:
  kit.tick(1.0/120/rate)
  for shot in shots:
   if shot.pool_live:shot._physics_process(1.0/120/rate)
  observed.append_array(heard(cursor));cursor=game.voice_idx
 for tick in 180:
  for shot in shots:
   if shot.pool_live:shot._physics_process(1.0/60)
  observed.append_array(heard(cursor));cursor=game.voice_idx
 var hit_index=0;var swing_index=0;var correct=true
 for event in observed:
  var ids:Array=[]
  if event.kind=="swing":
   ids=[expected[0][mini(swing_index,expected[0].size()-1)]];swing_index+=1
  elif event.kind in ["hit","heavy_hit"]:
   ids=[expected[1][mini(hit_index,expected[1].size()-1)]];hit_index+=1
  elif event.kind=="throw":ids=expected[1]
  elif event.kind=="cg_dagger_throw":ids=[111]
  elif event.kind=="cg_dagger_hit":ids=[141]
  elif event.kind=="coin_hit":ids=[142]
  else:continue
  if not matches(event.stream,ids) or event.pitch!=1:
   correct=false
   mismatches.append({"character":id,"skin":skin,"weapon":weapon,"landed":landed,"kind":event.kind,"expected":ids,"actual":event.stream.resource_path})
 check(correct,"Original attack audio %d skin %d %s contact=%s"%[id,skin,weapon,landed])
 if weapon not in ["bow","kunai"]:
  check(hit_index==(pattern.contacts.size() if landed else 0),"Confirmed contacts alone sound impacts, without changing their count")
 if weapon!="kunai":
  check(swing_index==swing_quota,"Attack keeps its existing swing count")
  check(matches(game.sound_preview(id,"swing"),[expected[0][0]]) and matches(game.sound_preview(id,"hit"),[expected[1][0]]),"Sound Studio previews the selected weapon's original cues")
 cases+=1
 for shot in shots:
  if shot.pool_live:shot.retire()
 kit.cancel()

func overrides_and_reuse():
 var lib=game.sound_library;var id=focused_character if focused else Gear.Roster.RUBY_ID
 lib.select_character(id)
 var original:AudioStream=samples["900010" if water_focused else "900007" if kaz_focused else "900001" if focused else "116"]
 var take:AudioStream=samples["133"]
 lib.custom.throw=take;lib.gains.throw=.4
 game.sound("throw",.8,false,{},id,original)
 check(game.last_sound_voice.stream==take and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.8*.55*.4),"Explicit weapon defaults preserve character recordings and gains")
 lib.mutes.throw=true;var before=game.voice_idx;game.sound("throw",.8,false,{},id,original)
 check(game.voice_idx==before,"Explicit weapon defaults preserve mute")
 lib.mutes.erase("throw");lib.custom.erase("throw");lib.gains.erase("throw")
 game.sound("throw",.8,false,{},id,original)
 check(game.last_sound_voice.stream==original and game.last_sound_voice.pitch_scale==1,"A recovered default replaces prototype fallback at original pitch")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 100:game.sound("throw",.8,false,{},id,original)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated explicit defaults reuse prepared streams and voices")
 lib.recording=true;before=game.voice_idx;game.sound("throw",.8,false,{},id,original)
 check(game.voice_idx==before,"Recording mode still suppresses explicit defaults");lib.recording=false

func allied_copies():
 var p=game.player
 var home=Vector3(-150,0,150);home.y=game.model.surface_height(home.x,home.z)+.1
 p.position=home;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.FORWARD*1.6;game.training_dummy.home=game.training_dummy.position
 for skin in (focused_skins if focused else [Gear.Roster.SAIZO_ID,Gear.Roster.SHIN_SPECIAL_ID]):
  var id=focused_character if focused else skin
  p.select_character(id);choose_skin(id,skin if focused else int(Gear.Roster.CROSSGATE[id].get("skin_default",106707)))
  var copies=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
  for i in 5:
   check(copies.reinforce(id,home+Vector3.RIGHT*.1*i),"Prepare native allied audio copy")
   var body=copies.bodies.back();body.facing=Vector3.FORWARD;body.ai_aim=home+Vector3.FORWARD*30
   body.active_ability.start_attack()
  var hits=0;var swings=0;var correct=true
  for tick in 150:
   for body in copies.bodies:
    var before=game.voice_idx
    body.active_ability.tick(1.0/120/body.attack_speed_multiplier())
    var cues:Array=body.model.body_clip(5,"5:%d"%body.model.direction()).audio_cues
    for event in heard(before):
     if event.kind=="swing":swings+=1;correct=correct and matches(event.stream,cues[0])
     if event.kind in ["hit","heavy_hit"]:hits+=1;correct=correct and matches(event.stream,cues[1])
  check(correct and swings>=5 and hits>=5,"Five simultaneous native copies keep their own recovered swing and impact samples")
  if id==Gear.Roster.SAIZO_ID:check(swings==5 and hits==5,"Each Saizo copy makes one sword cut, with one swing and impact")
  copies.dispose();await frames(3)

func audition():
 var p=game.player;var home=Vector3(-150,0,150);home.y=game.model.surface_height(home.x,home.z)+.1
 game.camera_rig.camera.global_position=home+Vector3(0,3.8,9);game.camera_rig.camera.look_at(home+Vector3.UP*1.5)
 var capture=AudioEffectRecord.new();capture.format=AudioStreamWAV.FORMAT_16_BITS
 var bus=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,capture)
 capture.set_recording_active(true)
 var rows=[]
 if water_focused:rows.append([Gear.Roster.SHIN_ID,900050,"sword"])
 elif kaz_focused:
  for skin in focused_skins:rows.append([Gear.Roster.KAZI_ID,skin,"sword"])
 elif focused:
  for skin in SHIN_NINE:rows.append([Gear.Roster.SHIN_SPECIAL_ID,skin,"unarmed" if skin==118986 else "polearm" if skin==108313 else "sword"])
  rows.append([Gear.Roster.SHIN_SPECIAL_ID,120440,"polearm"])
 else:rows=[[35,0,"bow"],[39,Gear.Roster.SaizoSkins.DEFAULT,"sword"],[42,Gear.Roster.EMILIA.skin_default,"staff"]]
 for row in rows:
  var id:int=row[0];var weapon:String=row[2]
  p.select_character(id);choose_skin(id,int(row[1]));p.position=home
  p.model.apply_gear_weapon(weapon,Gear.allowed(id,game.settings)[weapon])
  p.facing=Vector3.RIGHT;game.model.update_vision(home)
  game.training_dummy.position=home+Vector3.RIGHT*1.6;game.training_dummy.home=game.training_dummy.position
  var kit=p.active_ability;shots.clear();p.attack_chain.reset()
  var controlled=p.ai_controlled;p.ai_controlled=true;p.ai_aim=home+Vector3.RIGHT*30
  kit.start_attack();p.ai_controlled=controlled
  var duration:float=kit.duration;var picture=false
  for tick in ceili(duration*60)+30:
   kit.tick(1.0/60/p.attack_speed_multiplier());p.model.show_pose(5,kit.elapsed,false)
   for shot in shots:
    if shot.pool_live:shot._physics_process(1.0/60)
   if not picture and kit.elapsed>=duration*.5:
    game.forest_ui.sync();RenderingServer.force_draw()
    check(root.get_texture().get_image().save_png(output+"%d-%d-%s.png"%[id,int(row[1]),weapon])==OK,"Rendered original weapon audio audition")
    picture=true
   await create_timer(1.0/60).timeout
  for shot in shots:
   if shot.pool_live:shot.retire()
  kit.cancel()
 capture.set_recording_active(false)
 var wav=capture.get_recording()
 check(wav!=null and wav.data.count(0)<wav.data.size(),"Desktop mixer produces audible prepared weapon output")
 if wav!=null:check(wav.save_to_wav(output+"weapon-audition.wav")==OK,"Saved real SFX mixer output")
 AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)

func audition_shin_five():
 var folder="res://build/Other Files/Asset Toolkit/Shin Special Review/Audibility/"
 DirAccess.make_dir_recursive_absolute(folder)
 var p=game.player;var home=Vector3(-150,0,150)
 home.y=game.model.surface_height(home.x,home.z)+.1
 p.select_character(Gear.Roster.SHIN_SPECIAL_ID);choose_skin(Gear.Roster.SHIN_SPECIAL_ID,118986)
 p.model.apply_gear_weapon("unarmed",Gear.allowed(Gear.Roster.SHIN_SPECIAL_ID,game.settings).unarmed)
 p.position=home;game.model.update_vision(home)
 var preferences=ConfigFile.new();preferences.load("user://settings.cfg")
 var master=AudioServer.get_bus_index("Master");var previous=AudioServer.get_bus_volume_db(master)
 var volume=float(preferences.get_value("settings","volume",.8))
 AudioServer.set_bus_volume_db(master,linear_to_db(volume))
 if is_instance_valid(game.music):game.music.stop()
 var capture=AudioEffectRecord.new();capture.format=AudioStreamWAV.FORMAT_16_BITS
 AudioServer.add_bus_effect(master,capture)
 var report={"saved_volume":volume,"cases":[]}
 for landed in [false,true]:
  for voice in game.voices:voice.stop()
  await create_timer(.2).timeout
  var kit=p.active_ability;kit.cancel();p.attack_chain.reset();contacts.clear()
  p.facing=Vector3.RIGHT
  game.training_dummy.position=home+Vector3.RIGHT*(1.6 if landed else 200);game.training_dummy.home=game.training_dummy.position
  var cursor=game.voice_idx;var observed=[]
  capture.set_recording_active(true)
  var controlled=p.ai_controlled;p.ai_controlled=true;p.ai_aim=home+Vector3.RIGHT*30
  kit.start_attack();p.ai_controlled=controlled
  for tick in 144:
   kit.tick(1.0/60/p.attack_speed_multiplier())
   observed.append_array(heard(cursor));cursor=game.voice_idx
   await create_timer(1.0/60).timeout
  capture.set_recording_active(false)
  var wav=capture.get_recording();var name="shin-5-hit.wav" if landed else "shin-5-empty-swing.wav"
  var blasts=observed.filter(func(event):return event.kind=="swing" and matches(event.stream,[900006]))
  check(blasts.size()==1,"Shin 5 releases punch + Meteor + Fire exactly once, including empty swings")
  check(contacts.size()==(1 if landed else 0),"Audible release preserves confirmed damage and misses")
  check(wav!=null and wav.data.count(0)<wav.data.size(),"Real master mixer contains Shin 5 blast audio")
  if wav!=null:check(wav.save_to_wav(folder+name)==OK,"Saved isolated Shin 5 master recording")
  report.cases.append({"landed":landed,"blast_voices":blasts.size(),"contacts":contacts.size(),"recording":name})
  kit.cancel()
 AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
 AudioServer.set_bus_volume_db(master,previous)
 var file=FileAccess.open(folder+"master-verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()

func run():
 if water_focused:output="res://build/Other Files/Asset Toolkit/Shin Water Dragon/Water Audio/"
 elif kaz_focused:output="res://build/Other Files/Asset Toolkit/Kaz Special Sound Review/Fire/"
 elif focused:output="res://build/Other Files/Asset Toolkit/Shin Special Review/Runtime/"
 DirAccess.make_dir_recursive_absolute(output)
 create_timer(1200).timeout.connect(func():printerr("PLAYER_AUDIO_TIMEOUT");quit(1))
 contract=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/crossgate/player-attacks.json"))
 for id in contract.samples:
  if not contract.samples[id].is_empty():samples[id]=load(contract.samples[id])
 # Projectile contact samples are shared across the recovered weapon sources.
 samples["111"]=preload("res://assets/audio/crossgate/ruby/cgply05a.wav")
 samples["141"]=SoundLibrary.KUNAI_IMPACT;samples["142"]=SoundLibrary.CROSSGATE_BOW_SOUNDS.coin_hit
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;p.position=ORIGIN;p.smoke_mode=true;p.set_auto_attack(false)
 Pool.service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 var appearances=0
 for id in Gear.Roster.CROSSGATE:
  if focused and id!=focused_character:continue
  if id==34:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").DEFAULT
  if id==36:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE
  p.select_character(id)
  check(SoundLibrary.original_for(id,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(id,"land")==SoundLibrary.HUMANOID_LANDING,"Character keeps the approved shared footstep and landing defaults")
  var skins=Gear.Roster.skin_catalog(id).keys() if id!=36 else [0]
  for skin in skins:
   if focused and skin not in focused_skins:continue
   if id==34 and skin==preload("res://scripts/kaz_skins.gd").MAZE:continue
   choose_skin(id,skin);p.position=ORIGIN
   for weapon in Gear.allowed(id,game.settings):
    p.model.apply_gear_weapon(weapon,Gear.allowed(id,game.settings)[weapon])
    for direction in (8 if focused else 1):
     for landed in [false,true]:attack_case(id,skin,weapon,landed,Vector3.FORWARD.rotated(Vector3.UP,direction*TAU/8))
   appearances+=1;await frames(1)
  print("PLAYER_AUDIO_CHARACTER id=%d appearances=%d cases=%d failures=%d"%[id,appearances,cases,failures])
 if water_focused:
  choose_skin(Gear.Roster.SHIN_ID,100050)
  p.model.apply_gear_weapon("sword",Gear.allowed(Gear.Roster.SHIN_ID,game.settings).sword)
  attack_case(Gear.Roster.SHIN_ID,100050,"sword",true)
  choose_skin(Gear.Roster.SHIN_ID,900050)
 overrides_and_reuse()
 await allied_copies()
 if "--visual" in OS.get_cmdline_user_args():
  await audition()
  if focused and not kaz_focused and not water_focused:await audition_shin_five()
 var file=FileAccess.open(output+"runtime-verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"characters":Gear.Roster.CROSSGATE.size(),"appearances":appearances,"cases":cases,"checks":checks,"failures":failures,"mismatches":mismatches},"  "));file.close()
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PLAYER_AUDIO_RESULT checks=%d failures=%d cases=%d"%[checks,failures,cases]);quit(1 if failures else 0)

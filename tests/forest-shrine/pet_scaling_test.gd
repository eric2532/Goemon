extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Progression=preload("res://scripts/forest/team_progression.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Kit=preload("res://scripts/forest/crowd/army_kit_data.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const OUT="res://build/Other Files/Pet Scaling/"
const PACKS={"mixed":[0,10,18,21,24],"mantises":[21,22,23,24,25],"fastest":[2,3,5,9,12]}
var results=[]
func unit_checks():
 var p=Progression.new();p.cards_enabled=false
 var ember=Pets.key(0);var jade=Pets.key(1)
 p.award_kills(48)
 check(p.level==3 and p.pet_experience.is_empty(),"Character levels never award pet XP")
 check(p.award_pet_enemy(ember,480)==2 and p.pet_experience[ember].level==3 and p.stat_points==2,"48 XP reaches pet level three without granting character points")
 check(p.award_pet_enemy(jade,155)==0 and p.pet_experience[jade].experience()==15.5 and p.award_pet_enemy(jade,5)==1,"A second appearance tracks its own exact XP")
 check(is_equal_approx(p.pet_growth(ember,.1),.2/1.1) and is_equal_approx(p.pet_growth(jade,.08),.08/1.05),"Each appearance uses only its own level for growth")
 p.reset()
 check(p.level==1 and p.pet_experience.is_empty() and p.ranks.is_empty(),"New run clears pet XP and cards")

func battle(model,runtime,pack:Array,level_:int,ranks_:int,count_:int,old:bool=false)->Dictionary:
 runtime.clear();runtime.set_navigation(1,{"width":0})
 var progression=model.team_progression
 progression.reset();progression.ranks={"pet_damage":ranks_,"pet_health":ranks_}
 var data=Kit.from_model(model)
 if old:data.hound_damage=30
 runtime.configure_kits(data)
 var hp=Pets.BASE_HEALTH*(progression.multiplier("pet_health")+.08*(level_-1)/(1+(level_-1)/20.0))
 var dogs=[];var foes=[]
 for i in pack.size():
  var angle=i*TAU/pack.size();var at=Vector3(sin(angle),0,cos(angle))*5
  var h=runtime.spawn(-100-i,1,19,at,hp,.9);dogs.append(h)
  runtime.native.set_pet_skin(h,pack[i]);runtime.native.set_pose(h,at,angle);runtime.native.set_guard(h,Vector3.ZERO,18)
  if level_>1:
   var key=Pets.key(pack[i])
   progression.award_pet_enemy(key,80*level_*(level_-1))
   runtime.native.set_pet_growth(h,Pets.BASE_HEALTH*progression.pet_growth(key,.08),Pets.BASE_DAMAGE*progression.pet_growth(key,.10))
 for i in count_:
  var at=Vector3.ZERO if i==0 else Vector3(sin(i*2.4),0,cos(i*2.4))*(12+floori(i/12.0)*6)
  var h=runtime.spawn(100+i,0,20,at,1000,Roles.SLIME_RADIUS);foes.append(h);runtime.native.set_pet_skin(h,i%29)
 runtime.native.set_targets({"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,25)]),"hp":PackedFloat32Array([1000]),"hound_order":1})
 var first=-1.0;var damage=0.0;var attackers={};var elapsed=0.0
 for tick in 1800:
  runtime.step(1.0/60,{})
  for event in runtime.take_events():
   if event.kind=="damage" and event.source_id<=-100 and event.source_id>=-104:damage+=event.amount;attackers[event.source_id]=true
  elapsed=(tick+1)/60.0
  if first<0 and foes.any(func(h):return not runtime.valid(h)):first=elapsed
  if foes.all(func(h):return not runtime.valid(h)):break
 var alive=dogs.filter(func(h):return runtime.valid(h)).size()
 var health=0.0
 for h in dogs:
  if runtime.valid(h):health+=runtime.unit_state(h).hp
 return {"level":level_,"ranks":ranks_,"enemies":count_,"old":old,"first_kill_seconds":first,"duration":elapsed,"kills":foes.filter(func(h):return not runtime.valid(h)).size(),"pets_alive":alive,"pet_hp_fraction":health/(hp*5),"damage":damage,"attackers":attackers.size()}

func balance_checks():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42);model.waves.crossgate_pet_test=true
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 for name_ in PACKS:
  var before=battle(model,runtime,PACKS[name_],1,0,1,true)
  var after=battle(model,runtime,PACKS[name_],1,0,1)
  before.pack=name_;after.pack=name_;results.append(before);results.append(after)
  check(after.kills==1 and after.first_kill_seconds<before.first_kill_seconds and after.first_kill_seconds<15,"Level-one %s pack kills an ordinary slime sooner and within 15 seconds"%name_)
 for level_ in [1,10,30,99]:
  for rank_ in [0]:
   for name_ in PACKS:
    var row=battle(model,runtime,PACKS[name_],level_,rank_,116);row.pack=name_;results.append(row)
    check(row.kills<116 and row.pet_hp_fraction<1,"Five %s pets cannot clear 116 attacking slimes unharmed at level %d / rank %d"%[name_,level_,rank_])
 print("PET_BALANCE ",JSON.stringify(results))
 FileAccess.open(OUT+"native-balance.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 runtime.clear();runtime.free()

func arrive():
 for i in 60:
  game.army_runtime.integration_tick(1.0/60)
  if game.army_runtime.pending_hounds.is_empty():break
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func audio_checks():
 var fx=game.crowd.army.presentation;var point=game.player.position
 var volume=game.settings.volume;game.settings.volume=.65
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for skin in [0,21]:
  var cue=int(Pets.motions().variants[skin].attack_directions[4][0].id)
  var stream=Pets.sounds[cue]
  for voice in fx.voices:voice.stop()
  fx.present([{"kind":"status","unit_kind":19,"team":1,"position":point,"action_index":500+cue}])
  check(fx.voices.any(func(v):return v.playing and v.stream==stream and is_equal_approx(v.volume_db,linear_to_db(.55*1.5))),"Pet %d uses its original cue at +4.93 dB over the old gain"%skin)
  for voice in fx.voices:
   voice.stream=preload("res://assets/audio/crossgate/hounds/cgbtl03.wav");voice.set_meta("started",-100);voice.play()
  fx.clock+=1;fx.present([{"kind":"status","unit_kind":19,"team":1,"position":point,"action_index":500+cue}])
  check(fx.voices.any(func(v):return v.playing and v.stream==stream),"Pet attack can reclaim a voice during a crowded battle")
 for i in 100:
  for skin in PACKS.mixed:
   var cue=int(Pets.motions().variants[skin].attack_directions[4][0].id)
   fx.present([{"kind":"status","unit_kind":19,"team":1,"position":point,"action_index":500+cue}])
 check(fx.voices.size()==8 and Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"500 pet cues reuse the eight voices without node or resource growth")
 for voice in fx.voices:voice.stop()
 var event={"kind":"status","unit_kind":19,"team":1,"position":point,"action_index":631}
 game.settings.volume=0;fx.present([event]);check(fx.voices.all(func(v):return not v.playing),"Master mute still silences pets")
 game.settings.volume=volume;game.sound_library.recording=true;fx.present([event]);check(fx.voices.all(func(v):return not v.playing),"Recording still suppresses pet sounds");game.sound_library.recording=false
 event.position=point+Vector3.RIGHT*36;fx.present([event]);check(fx.voices.all(func(v):return not v.playing),"Distant pets remain outside the existing audio radius")
func live_checks():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.player.select_character(game.player.RogueRoster.KAZI_ID)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var army=game.army_runtime;var p=game.model.team_progression
 p.cards_enabled=false;game.settings.forest_level_up_cards=false
 game.player.position=Vector3(-150,game.model.surface_height(-150,127),127)
 game.settings.forest_pet_loadout=Pets.sanitized(PACKS.mixed.map(func(skin):return Pets.key(skin)))
 army.queue_hounds();arrive()
 audio_checks()
 var pet=int(army.handles[army.HOUND_ID]);army.apply_hit(pet,{"amount":40.0})
 var begin=Time.get_ticks_usec();game.award_team_kill(160);var refresh_ms=(Time.get_ticks_usec()-begin)/1000.0
 check(p.level==2 and army.pet_stats(0).level==1 and army.unit_state(pet).max_hp==Pets.BASE_HEALTH,"A main-character level leaves companion level and HP alone")
 var victim_position:Vector3=army.unit_state(pet).position+Vector3.FORWARD*3
 var victim=game.model.waves.spawn_enemy(Roles.SLIME,victim_position)
 victim.xp_reward_tenths=160
 army.import_arrivals()
 var target:int=army.handles[victim.id]
 army.apply_hit(target,{"amount":100000,"source_id":army.HOUND_ID})
 var stale:Dictionary=army.apply_hit(target,{"amount":100000,"source_id":army.HOUND_ID})
 var row=army.unit_state(pet)
 check(not stale.accepted and p.level==2 and p.experience()==16 and army.pet_stats(0).level==2 and army.pet_stats(0).xp==0 and army.pet_stats(21).level==1,"One native kill credits the hero and only the attacking appearance, once")
 check(is_equal_approx(row.max_hp,150*(1+.08/1.05)) and is_equal_approx(row.max_hp,row.hp),"Companion level two raises live max HP and fully heals")
 army.refresh_kits();row=army.unit_state(pet)
 check(is_equal_approx(row.max_hp,row.hp),"Repeated profile refresh retains full health")
 for i in 60:army.integration_tick(1.0/60)
 var death=army.apply_hit(pet,{"amount":100000})
 check(death.dead and not army.valid(pet),"Replacement test waits out hit recovery and actually defeats the wounded pet")
 army.queue_hounds();arrive()
 row=army.unit_state(army.handles[army.HOUND_ID])
 check(is_equal_approx(row.hp,150*(1+.08/1.05)) and army.render_snapshot().kinds.count(19)==5,"Resummoning restores the appearance's own level and the pack stays at five")
 game.show_equipment_hub(true);await frames()
 var hub=game.equipment_hub;hub.select_owner(1)
 check(hub.stats.level_label.text=="Lv 2" and hub.stats.pet_state.text.contains("0 / 32 XP"),"Equipment shows the selected pet's level and next XP target")
 await capture("individual-level");root.size=Vector2i(960,640);await frames()
 check(root.get_visible_rect().encloses(hub.stats.panel.get_global_rect()),"Level and stats fit the small Equipment view")
 hub.select_owner(2)
 check(hub.stats.level_label.text=="Lv 1" and hub.stats.pet_state.text.contains("0 / 16 XP"),"Selecting a second pet shows its separate XP")
 game.back_from_equipment();root.size=Vector2i(1280,800)
 # Real arrival, combat, presentation and repeated level refresh use the existing owner.
 game.model.waves.crossgate_pet_test=true;army.refresh_kits()
 game.player.smoke_mode=true;army.order_hounds(army.HoundOrder.ATTACK)
 for i in 29:
  var at=game.player.position+Vector3(sin(i*2.4),0,cos(i*2.4))*(18+floori(i/8.0)*4)
  at.y=game.model.surface_height(at.x,at.z)
  game.model.waves.spawn_enemy(20,at,-1,i)
 var camera=game.camera_rig.camera;camera.global_position=game.player.position+Vector3(0,40,38);camera.look_at(game.player.position)
 var timings=[];var frame_times=[];var previous=Time.get_ticks_usec()
 for i in 600:
  var start=Time.get_ticks_usec();army.integration_tick(1.0/60);army.flush_presentation();timings.append((Time.get_ticks_usec()-start)/1000.0)
  if i==180:
   await capture("five-pet-combat");previous=Time.get_ticks_usec()
  if DisplayServer.get_name()!="headless":
   await process_frame
   var now=Time.get_ticks_usec();frame_times.append((now-previous)/1000.0);previous=now
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));var refreshes=[]
 for i in 12:
  begin=Time.get_ticks_usec();game.award_team_kill(p.kills_required()*10);refreshes.append((Time.get_ticks_usec()-begin)/1000.0);await frames()
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes+2 and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Twelve character level-ups retain no extra nodes or resources")
 timings.sort();frame_times.sort();refreshes.sort()
 print("PET_LIVE integration_p95_ms=",timings[569]," max_ms=",timings[-1]," level_refresh_first_ms=",refresh_ms," refresh_p95_ms=",refreshes[10]," refresh_max_ms=",refreshes[-1]," frame_p95_ms=",frame_times[floori(frame_times.size()*.95)] if not frame_times.is_empty() else 0," frame_max_ms=",frame_times[-1] if not frame_times.is_empty() else 0)
 var before_travel=army.pet_stats(0)
 game.preview_forest_map(doc.data,false,false,true)
 var after_travel=army.pet_stats(0)
 check(game.model.team_progression==p and after_travel.level==before_travel.level and after_travel.xp==before_travel.xp,"Retained-run travel keeps each appearance's level and XP")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
func run():
 create_timer(240).timeout.connect(func():printerr("PET_SCALING_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 unit_checks();
 if "--live-only" not in OS.get_cmdline_user_args():balance_checks();
 if "--native-only" not in OS.get_cmdline_user_args():await live_checks()
 print("PET_SCALING_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

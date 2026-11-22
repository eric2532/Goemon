extends "res://tests/forest-shrine/pet_loadout_test.gd"
const TOGGLE_OUT="res://build/Other Files/Asset Toolkit/Pet Toggle/"
const Hound=preload("res://scripts/forest/crowd/hound_sprites.gd")
func recall_p():
 var army=game.army_runtime;var fx=game.crowd.army.presentation
 for voice in fx.voices:voice.stop()
 press_p()
 check(army.presentation_events.filter(func(e):return e.kind=="hound_recall").size()==1,"One successful P recall queues one original sound for the whole pack")
 army.flush_presentation()
 var playing=fx.voices.filter(func(v):return v.playing and v.stream==Hound.RECALL_SOUND)
 check(playing.size()==1 and playing[0].position==game.player.position and playing[0].pitch_scale==1.0,"Recall plays one original-speed cue at the player through a pooled voice")
 army.flush_presentation()
 check(fx.voices.filter(func(v):return v.playing and v.stream==Hound.RECALL_SOUND).size()==1,"A second presentation flush does not replay recall audio")
func key(code:int,pressed:bool=true,echo:bool=false):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;event.echo=echo;game._input(event)
func shot(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.crowd.army.presentation.tick(2.0);game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(TOGGLE_OUT+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(180).timeout.connect(func():quit(1));DirAccess.make_dir_recursive_absolute(TOGGLE_OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 game.player.position=Vector3(-120,game.model.surface_height(-120,125),125)
 var army=game.army_runtime;var ui=game.forest_ui
 var fx=game.crowd.army.presentation
 var pcm=HashingContext.new();pcm.start(HashingContext.HASH_SHA256);pcm.update(Hound.RECALL_SOUND.data)
 check(Hound.RECALL_SOUND.mix_rate==22050 and pcm.finish().hex_encode()=="2a056095383b9434267f15c9c5d13c4de6324157720c31452c4b21e5b8cb225c","Recall retains the original sound ID 205 PCM and sample rate")
 var voices=fx.voices.map(func(v):return v.get_instance_id())
 check(ui.PET_STANCES[0][0].resource_path.ends_with("attack-normal.png") and ui.PET_STANCES[1][0].resource_path.ends_with("defend-normal.png") and ui.PET_STANCES[2][0].resource_path.ends_with("return-normal.png"),"Original command artwork follows Attack, Defend, Back order")
 var pack=Pets.sanitized([Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61),Pets.key(81)])
 game.settings.forest_pet_loadout=pack;game.settings.forest_pet_skills={pack[0]:[Pets.Spells.COMBO]}
 var learned=preload("res://scripts/spells/skill_levels.gd").family(Pets.Spells.COMBO)
 game.model.team_progression.pet_skill_levels={pack[0]:{learned:7}}
 var counters=[game.model.waves.pending,game.model.waves.spawned,game.model.waves.kill_spawn_pending]
 var bear=army.spawn(army.CAVE_BEAR_ID,1,army.Roles.CAVE_BEAR,game.player.position+Vector3(30,0,0),1000,1)
 var enemy=army.spawn(777777,0,army.Roles.GATEKEEPER_HOUND,game.player.position+Vector3(60,0,0),1000,1)
 for character in game.player.RogueRoster.selection_ids():
  game.player.select_character(character)
  press_p();check(army.pending_hounds.size()==5,"P queues the mixed pack for fighter "+str(character))
  key(KEY_P,false);key(KEY_P,true,true)
  game.paused=true;press_p();game.paused=false
  check(army.pending_hounds.size()==5,"Release, key repeat and paused P leave summons alone")
  check(not army.presentation_events.any(func(e):return e.kind=="hound_recall"),"Summoning, release, key repeat and paused P do not queue recall audio")
  recall_p();arrive();check(population()==0 and army.pending_hounds.is_empty(),"Second P cancels pending summons")
  press_p();army.integration_tick(1.0/60)
  check(population()>0 and not army.pending_hounds.is_empty(),"Native placement can leave a partially arrived pack")
  recall_p();arrive();check(population()==0 and army.pending_hounds.is_empty(),"P retires partial arrivals and cancels the remainder")
  press_p();arrive();check(population()==5,"P summons five pets again")
  for command in [[MOUSE_BUTTON_RIGHT,0,"RMB"],[KEY_F,1,"F Defend"],[KEY_Z,2,"Z Back"]]:
   if command[0]==MOUSE_BUTTON_RIGHT:tap("heavy_attack")
   else:key(command[0])
   ui.sync()
   check(ui.hound_stance==command[1] and ui.hound_stance_labels[command[1]].text=="› "+command[2],"HUD order is Attack, Defend, Back with the correct selection")
   check(ui.hound_stance_labels[command[1]].get_combined_minimum_size().x<=70,"Selected command fits its column")
  if character==game.player.RogueRoster.KAZI_ID:
   var camera=game.camera_rig.camera;camera.global_position=game.player.position+Vector3(-4,20,32);camera.look_at(game.player.position+Vector3.UP)
   game.crowd.present_army(army.render_snapshot(),[]);await shot("summoned-back")
   tap("heavy_attack");ui.sync();await shot("attack-first")
   key(KEY_F);ui.sync();await shot("defend-second")
  var handles=pack.map(func(pet):return army.handles[army.HOUND_ID-Pets.skin(pet)])
  army.apply_hit(handles[0],{"amount":100000.0});army.begin_integration(1.0/60,false)
  recall_p()
  check(not army.integration_pending and population()==0 and army.pending_hounds.is_empty(),"P finishes an active native step and recalls survivors after a death")
  army.flush_presentation();ui.sync()
  check(not ui.hound_dock.visible and handles.all(func(handle):return not army.valid(handle)),"Unsummoning hides HUD portraits and invalidates old native handles")
  check(army.pet_skills.casters[pack[0]].native_handle==0,"Unsummoning retires the pet skill caster")
  check(army.valid(bear) and army.valid(enemy),"Unsummoning preserves bears and enemies")
  check(game.settings.forest_pet_loadout==pack and game.settings.forest_pet_skills=={pack[0]:[Pets.Spells.COMBO]} and game.model.team_progression.pet_skill_levels[pack[0]][learned]==7,"Selection, skills and learned levels survive unsummoning")
  if character==game.player.RogueRoster.KAZI_ID:await shot("unsummoned")
 check(counters==[game.model.waves.pending,game.model.waves.spawned,game.model.waves.kill_spawn_pending],"Pet toggles preserve wave counters")
 game.settings.forest_pet_loadout=[];press_p();arrive();check(population()==0 and army.pending_hounds.is_empty(),"An empty pack stays empty")
 for voice in fx.voices:voice.stop()
 check(not army.recall_hounds() and not army.presentation_events.any(func(e):return e.kind=="hound_recall"),"An empty recall queues no sound")
 var event={"kind":"hound_recall","position":game.player.position}
 game.settings.volume=0;fx.present([event])
 check(fx.voices.all(func(v):return not v.playing),"Master mute silences the recall cue")
 game.settings.volume=.65;game.sound_library.recording=true;fx.present([event])
 check(fx.voices.all(func(v):return not v.playing),"Recording suppresses the recall cue");game.sound_library.recording=false
 for voice in fx.voices:voice.stream=Hound.SUMMON_SOUND;voice.play()
 fx.present([event])
 check(fx.voices.filter(func(v):return v.playing and v.stream==Hound.RECALL_SOUND).size()==1,"Recall can reclaim a voice during a crowded battle")
 for i in 100:fx.present([event])
 check(fx.voices.map(func(v):return v.get_instance_id())==voices,"Repeated recalls reuse the same audio players")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_TOGGLE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

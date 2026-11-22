extends "res://scripts/recovered_leaders_tests.gd"
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const OUT="res://build/Other Files/Habaru Dialogue/"

func key(code:int,pressed:bool=true,echo:bool=false):
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code
 event.pressed=pressed;event.echo=echo;Input.parse_input_event(event)
 Input.flush_buffered_events()

func tap_space():
 key(KEY_SPACE);key(KEY_SPACE,false)

func shot(label_:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)

func run():
 create_timer(120).timeout.connect(func():printerr("HABARU_DIALOGUE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 set_meta("forest_custom_layout",Tour.Indoor.layout(11004))
 game=load("res://scenes/forest_shrine.tscn").instantiate()
 game.settings_path="user://habaru-dialogue-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(5)
 game.player.position=game.model.world_point(Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,22),.15)
 game.checkpoint=game.player.position;game.camera_rig.reset_follow()
 game.start_wave();await frames(8)
 check(not is_instance_valid(game.dialogue) and not paused,"Entering the chamber leaves exploration running")
 check(is_instance_valid(game.habaru_waiting) and game.habaru_waiting.visible,"熊弟 waits using the existing army sprite")
 check(game.habaru_waiting.multimesh.mesh==game.Habaru.make_mesh(),"The waiting host shares the prepared army mesh and material")
 check(game.model.enemies.is_empty(),"Neither the boss nor the bears can attack before talking")
 var pets=preload("res://scripts/forest/pet_catalog.gd")
 game.settings.forest_pet_loadout=pets.sanitized([pets.key(0)])
 game.army_runtime.queue_hounds();await frames(30)
 key(KEY_F);key(KEY_F,false)
 check(game.army_runtime.hound_order==game.army_runtime.HoundOrder.HOLD,"F outside talking range still orders pets to hold")
 game.army_runtime.order_hounds(game.army_runtime.HoundOrder.ATTACK)
 var pet_order_serial=game.army_runtime.hound_order_serial
 check(not is_instance_valid(game.dialogue) and not game.habaru_talk_hint.visible,"F cannot talk from the room entrance")
 game.player.position=game.habaru_waiting.position+Vector3(0,.15,7)*game.model.falan_scale
 game.checkpoint=game.player.position;game.camera_rig.reset_follow();await frames(8)
 check(game.habaru_talk_hint.visible and not is_instance_valid(game.dialogue),"Approaching shows F to talk without opening dialogue automatically")
 var waiting_hp=game.player.hp
 await frames(30)
 check(game.player.hp==waiting_hp and game.model.enemies.is_empty(),"Waiting beside 熊弟 does not trigger combat or bears")
 await shot("approach-f-prompt")
 game.player.position.y+=20;await frames(2)
 check(not game.can_talk_habaru() and not game.habaru_talk_hint.visible,"Talk requires being on the boss's level")
 game.player.position=game.habaru_waiting.position+Vector3(0,.15,7)*game.model.falan_scale
 key(KEY_F,false);key(KEY_F,true,true)
 check(not is_instance_valid(game.dialogue),"F release and keyboard repeat cannot begin the encounter")
 game.show_pause();key(KEY_F);key(KEY_F,false)
 check(not is_instance_valid(game.dialogue),"F cannot start dialogue while paused")
 game.resume();key(KEY_F);key(KEY_F,false)
 check(is_instance_valid(game.dialogue),"Pressing F nearby opens 熊弟's dialogue")
 check(game.army_runtime.hound_order_serial==pet_order_serial,"Talking with F does not also issue a pet order")
 if not is_instance_valid(game.dialogue):quit(1);return
 var d=game.dialogue
 check(game.paused and paused and game.ordinary_pause and game.army_runtime.blocked(),"Dialogue pauses player, world and native army")
 check(game.model.enemies.is_empty(),"Bears stay absent throughout the conversation")
 check(d.body.visible_characters==0 and d.speaker=="熊弟","The correct speaker starts with hidden dialogue")
 check(FileAccess.get_sha256("res://assets/ui/dialogue/kumatei-confident.png")=="0e340a2dda23e8638db61412db789c89dfdd2e586ee6c7b0563a24266b124a8d","The approved confident master is unchanged")
 check(d.portrait.texture.resource_path.ends_with("kumatei-confident.png"),"Dialogue uses the approved flat-top portrait")
 check(d.panel.get_theme_stylebox("panel").texture==d.MenuSkin.PANEL,"Dialogue reuses the recovered Blue Crossgate menu frame")
 var steps=game.army_runtime.simulation_steps
 var hp=game.player.hp;var position=game.player.position;var clock=game.model.waves.wave_clock
 await create_timer(.35).timeout
 check(d.body.visible_characters>0 and d.body.visible_characters<d.body.get_total_character_count(),"Text reveals gradually while gameplay is paused")
 await shot("typing")
 key(KEY_ESCAPE);key(KEY_ESCAPE,false);key(KEY_I);key(KEY_I,false)
 key(KEY_1);key(KEY_1,false);key(KEY_P);key(KEY_P,false)
 check(is_instance_valid(game.dialogue) and not is_instance_valid(game.status_panel) and game.ordinary_pause,"Gameplay and menu keys cannot bypass the intro")
 check(game.player.hp==hp and game.player.position==position and game.model.waves.wave_clock==clock and game.army_runtime.simulation_steps==steps,"Reading causes no movement, damage, wave time or native combat steps")
 key(KEY_SPACE,true,true)
 check(not d.closing,"Keyboard repeat cannot advance dialogue")
 tap_space()
 check(is_instance_valid(game.dialogue) and d.body.visible_characters==d.body.get_total_character_count(),"First Space reveals the rest without starting combat")
 for dimensions in [Vector2i(1280,800),Vector2i(960,600)]:
  root.size=dimensions;await frames(4)
  check(root.get_visible_rect().encloses(d.panel.get_global_rect()),"Text box fits %s"%dimensions)
  check(root.get_visible_rect().encloses(d.portrait.get_global_rect()),"Portrait fits %s"%dimensions)
  check(d.body.get_line_count()==2 and d.body.size.y>=d.body.get_minimum_size().y,"Chinese dialogue fits without clipping")
  await shot("dialogue-%dx%d"%[dimensions.x,dimensions.y])
 key(KEY_SPACE)
 await frames(3)
 check(is_instance_valid(game.dialogue) and game.paused,"Holding the closing Space keeps combat paused until release")
 key(KEY_SPACE,false);await frames(2)
 check(is_instance_valid(game.dialogue) and game.paused and d.page==1,"First-page dismissal advances to the callout while gameplay stays paused")
 check(d.portrait.texture.resource_path.ends_with("kumatei-shouting.png"),"The callout switches to 熊弟's angry yelling portrait")
 check(d.body.visible_characters<3 and d.body.text=="熊兄弟們，出來吧！\n一起上，讓他見識我們的厲害！","The bear callout resets the text reveal")
 check(game.model.enemies.is_empty() and game.army_runtime.simulation_steps==steps,"No bears or combat start before the final callout is finished")
 key(KEY_F);key(KEY_F,false);key(KEY_SPACE,true,true)
 check(d.page==1 and not d.closing,"F and held-key repeat cannot skip the final callout")
 tap_space()
 check(is_instance_valid(game.dialogue) and d.body.visible_characters==d.body.get_total_character_count(),"Space reveals the callout without summoning bears")
 for dimensions in [Vector2i(1280,800),Vector2i(960,600)]:
  root.size=dimensions;await frames(4)
  check(root.get_visible_rect().encloses(d.portrait.get_global_rect()) and d.body.get_line_count()==2,"Yelling portrait and two-line callout fit %s"%dimensions)
  await shot("callout-%dx%d"%[dimensions.x,dimensions.y])
 key(KEY_SPACE);await frames(3)
 check(is_instance_valid(game.dialogue) and game.model.enemies.is_empty() and game.paused,"Holding final Space keeps the bears absent until release")
 key(KEY_SPACE,false);await frames(8)
 check(not is_instance_valid(game.dialogue) and not paused and not game.paused and game.forest_ui.visible,"Space release closes the dialogue and restores play and HUD")
 check(game.player.jump_buffer<=0 and game.player.velocity.y<=0,"The closing Space does not leak into a jump")
 check(not game.habaru_waiting.visible,"The harmless host is hidden when the native boss takes over")
 await shot("fight-summoned-bears")
 check(game.model.enemies.size()==10 and game.army_runtime.handles.size()>=10,"熊弟 and all nine bears start through the existing native lifecycle")
 check(game.model.enemies.values().all(func(e):return e.max_hp==(30000.0 if e.habaru_slot==0 else 10000.0)),"The existing encounter HP stays intact")
 check(game.army_runtime.simulation_steps>steps,"Native combat resumes after the dialogue")
 game.show_habaru_dialogue();check(not is_instance_valid(game.dialogue),"Intro does not repeat while staying in the chamber")
 Tour.travel(game,Tour.Indoor.layout(11003),{"arrival":Vector2(42,-51),"yaw":0.0})
 check(not is_instance_valid(game.dialogue),"Other dungeon floors do not open the boss intro")
 Tour.travel(game,Tour.Indoor.layout(11004),{"arrival":Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,22),"yaw":0.0})
 await frames(8)
 check(not is_instance_valid(game.dialogue) and game.model.enemies.is_empty(),"Re-entry waits for another nearby conversation")
 game.player.position=game.habaru_waiting.position+Vector3(0,.15,7)*game.model.falan_scale
 key(KEY_F);key(KEY_F,false)
 check(is_instance_valid(game.dialogue),"F repeats the living boss's intro on re-entry")
 check(game.dialogue.page==0 and game.dialogue.portrait.texture.resource_path.ends_with("kumatei-confident.png"),"Re-entry starts at the confident introduction again")
 await create_timer(2.0).timeout
 check(is_instance_valid(game.dialogue) and game.dialogue.body.visible_characters==game.dialogue.body.get_total_character_count(),"Natural typing finishes and waits for Space instead of auto-starting combat")
 tap_space();tap_space();tap_space();await frames(30)
 # Isolate repeated UI allocation from native arrivals and combat presentation.
 game.set_physics_process(false)
 var warm_nodes=0;var warm_resources=0
 for repetition in 4:
  game.habaru_dialogue_seen=false;game.player.position=game.habaru_waiting.position+Vector3(0,.15,7)*game.model.falan_scale;game.show_habaru_dialogue();await frames(2)
  check(is_instance_valid(game.dialogue) and game.dialogue.body.visible_characters<3,"Reopened dialogue resets reveal state")
  tap_space();tap_space();tap_space();tap_space();await frames(3)
  if repetition==0:
   warm_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));warm_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  else:
   check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=warm_nodes,"Repeated dialogue retains no extra nodes")
   check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=warm_resources,"Repeated dialogue retains no extra resources")
 game.habaru_dialogue_seen=false;set_meta("habaru_slain",{0:true});game.show_habaru_dialogue()
 check(not is_instance_valid(game.dialogue),"A defeated boss never speaks again")
 remove_meta("habaru_slain");game.show_habaru_dialogue();game.show_title();await frames(2)
 check(not is_instance_valid(game.dialogue) and paused and not game.playing,"Returning to title clears the dialogue without unpausing the title")
 check(not game.habaru_dialogue_seen and not is_instance_valid(game.habaru_waiting),"Title clears the host and interrupted introduction")
 # A slain boss must not block surviving escorts or return as a talkable host.
 set_meta("habaru_slain",{0:true,1:true})
 game.set_physics_process(true);game.playing=true;game.resume()
 Tour.travel(game,Tour.Indoor.layout(11004),{"arrival":Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,22),"yaw":0.0})
 await frames(8)
 check(not is_instance_valid(game.habaru_waiting) and not is_instance_valid(game.dialogue),"The defeated boss stays absent on return")
 check(game.model.enemies.size()==8 and game.model.enemies.values().all(func(e):return e.habaru_slot>1),"Only surviving bears return after a partial clear")
 set_meta("habaru_slain",{0:true,1:true,2:true,3:true,4:true,5:true,6:true,7:true,8:true,9:true})
 Tour.travel(game,Tour.Indoor.layout(11004),{"arrival":Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,22),"yaw":0.0})
 await frames(8)
 check(game.model.enemies.is_empty() and not is_instance_valid(game.habaru_waiting),"Fully cleared rooms stay empty")
 var path=game.settings_path
 stop_audio(game);game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("HABARU_DIALOGUE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

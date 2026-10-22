extends SceneTree
const AUDIO=preload("res://assets/rogue/scripts/audio.gd")
const IMPACT="res://assets/rogue/audio/landing-strike-dragoon.wav"
const FOLDER="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/dragoon-landing-audio-20261017"
var game
var checks=0
var failures=0
var sandbox="user://dragoon-landing-%d"%OS.get_process_id()
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: Dragoon landing audio timeout");quit(1))
 run.call_deferred()
func check(ok:bool,note:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func frames(n=3):
 for i in n:await physics_frame
func fresh():
 game.player.select_character(8);game.player.position=Vector3(0,.1,70);game.player.velocity=Vector3.ZERO
 game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 var c=game.player.active_ability;c.cancel();c.reset_run()
 for i in 30:c._move_body(1.0/120)
 c.player.pos=game.player.position;c.player.angle=PI
 c.sound.last_events.clear();return c
func last_file(c)->String:
 return c.sound.voices[posmod(c.sound.cursor-1,c.sound.voices.size())].stream.resource_path
func stop_audio(node:Node):
 if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop();node.stream=null
 for child in node.get_children():stop_audio(child)
func run():
 check(AUDIO.event_file("slam",{"style":"dragoon"})=="landing-strike-dragoon","Dragoon landing routes to the layered impact")
 check(AUDIO.event_file("slam",{"style":"mage"})=="slam" and AUDIO.event_file("slam")=="slam","Other slam sounds stay unchanged")
 check(ResourceLoader.exists(IMPACT),"Layered landing asset is present")
 if failures:print("DRAGOON_LANDING_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1);return
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=sandbox+".cfg";root.add_child(game);current_scene=game;await frames()
 game.sound_library.free();var lib=load("res://scripts/sound_library.gd").new();lib.folder=sandbox;lib.config_path=sandbox+"-sounds.cfg";game.sound_library=lib;lib.game=game;game.add_child(lib)
 game.start_wave();game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 var c=await fresh()
 check(game.sound_preview(8,"move_secondary_weapon").resource_path==IMPACT and game.sound_preview(8,"native_slam").resource_path==IMPACT,"Sound Studio previews the same layered landing")
 var cursor=c.sound.cursor
 c.action("flintlock");c.tick(.25,false)
 check(last_file(c).ends_with("sweep-dragoon.wav"),"Grounded right-click retains the existing lance sweep sound")
 c=await fresh();game.player.jump_buffer=.15
 for i in 12:c._move_body(1.0/120)
 c.action("flintlock")
 check(c.player.travel!=null,"Airborne right-click begins the real Dragon Leap")
 if c.player.travel==null:stop_audio(game);game.queue_free();quit(1);return
 c.player.travel.target=Vector3(game.player.position.x,0,game.player.position.z)
 cursor=c.sound.cursor
 check(not c.sound.last_events.has("slam"),"The landing strike remains silent during descent")
 c._process(0)
 var diving=c.fx.items.filter(func(item):return item.kind=="dragon-descent")
 check(diving.size()==1,"The real airborne thrust shows one diving dragon before landing")
 if not diving.is_empty():
  var before=diving[0].node.global_position;var hero_before=game.player.position
  c.step_travel(1.0/120);c.fx.tick(1.0/120)
  check((diving[0].node.global_position-before).is_equal_approx(game.player.position-hero_before),"The diving dragon follows actual collision-constrained movement")
 for i in 180:
  c.step_travel(1.0/120)
  if c.player.travel==null:break
 check(game.player.is_on_floor() and c.player.travel==null,"The real floor contact completes the leap")
 check(last_file(c)==IMPACT and posmod(c.sound.cursor-cursor,28)==1,"Landing plays the three-layer mix exactly once even without an enemy")
 check(not c.fx.items.any(func(item):return item.kind=="dragon-descent") and c.fx.items.filter(func(item):return item.kind=="dragon-eruption").size()==1,"Ground contact replaces the diving dragon with exactly one eruption")
 var landed_cursor=c.sound.cursor
 for i in 120:c.step_travel(1.0/120);c.tick(1.0/120,false)
 check(c.sound.cursor==landed_cursor,"Later body ticks and the three pulses cannot replay the landing sound")
 c=await fresh();game.player.jump_buffer=.15
 for i in 12:c._move_body(1.0/120)
 c.action("cutlass")
 check(c.player.travel!=null,"Airborne left-click uses the shared landing strike path")
 c.cancel();cursor=c.sound.cursor
 for i in 160:c.step_travel(1.0/120)
 check(c.sound.cursor==cursor,"Cancelling a leap clears the pending landing audio")
 # A tall fall must not expire its dragon at the short landing effect lifetime.
 c=await fresh();game.player.position.y=160;game.player.velocity=Vector3.DOWN;game.player.move_and_slide();c.player.pos=game.player.position
 c.action("flintlock");c.player.travel.target=Vector3(0,0,70);c._process(0)
 diving=c.fx.items.filter(func(item):return item.kind=="dragon-descent")
 for i in 120:c.step_travel(1.0/60);c.fx.tick(1.0/60)
 check(c.player.travel!=null and not diving.is_empty() and is_instance_valid(diving[0].node) and not diving[0].node.is_queued_for_deletion(),"A long native descent keeps its attached dragon until the landing")
 c.cancel();c._process(0)
 check(not c.fx.items.any(func(item):return item.kind=="dragon-descent") and (diving.is_empty() or diving[0].node.is_queued_for_deletion()),"Cancelling a long fall removes its dragon without an impact")
 # Human crosshair dives can travel thirty metres from a shallow jump. The
 # dragon's muzzle should face that heading, rather than being pitched skyward.
 for heading in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
  c=await fresh();game.player.position.y=80;game.player.velocity=Vector3.DOWN
  await physics_frame;game.player.move_and_slide();c.player.pos=game.player.position
  c.action("flintlock");c.player.travel.target=game.player.position+heading*30+Vector3.DOWN*4
  c.player.angle=atan2(heading.x,heading.z)
  await physics_frame;c.step_travel(1.0/60);c._process(0)
  diving=c.fx.items.filter(func(item):return item.kind=="dragon-descent")
  var muzzle=diving[0].node.global_basis.z.normalized() if not diving.is_empty() else Vector3.ZERO
  var transform=diving[0].node.global_transform if not diving.is_empty() else Transform3D.IDENTITY
  var upper_jaw=transform*Vector3(0,10.75,2.75)
  var lower_jaw=transform*Vector3(0,9.25,2.3)
  print("PLAYER_DIVE_FACING heading=",heading," velocity=",game.player.velocity," muzzle=",muzzle," up=",transform.basis.y.normalized())
  check(upper_jaw.y>lower_jaw.y and transform.basis.y.normalized().dot(Vector3.UP)>.8,"The human dragon keeps its upper jaw and horns above its lower jaw at heading "+str(heading))
  check(muzzle.y<0 and transform.basis.determinant()>0,"The human dragon pitches its muzzle down without an inverted or mirrored frame at heading "+str(heading))
  check(muzzle.dot(heading)>.8 and absf(muzzle.y)<.6,"A shallow human glide keeps the dragon facing forward at heading "+str(heading))
 # Existing player recordings replace the complete default mix through the same slot.
 var take=AudioStreamWAV.new();take.format=AudioStreamWAV.FORMAT_16_BITS;take.mix_rate=48000;take.data=PackedByteArray([0,0,0,0,0,0])
 lib.select_character(8);lib.take=take;lib.take_slot="move_secondary_weapon";check(lib.save_take(),"A custom Dragon Leap weapon recording can still be saved")
 c=await fresh();game.player.jump_buffer=.15
 for i in 12:c._move_body(1.0/120)
 c.action("flintlock");c.player.travel.target=Vector3(game.player.position.x,0,game.player.position.z)
 for i in 180:
  c.step_travel(1.0/120)
  if c.player.travel==null:break
 var voice=c.sound.voices[posmod(c.sound.cursor-1,28)]
 check(voice.stream==lib.custom_for(8,"move_secondary_weapon") and voice.pitch_scale==1.0,"Actual landing retains a custom weapon take at its original pitch")
 lib.reset_slot("move_secondary_weapon");lib.cancel();c.cancel();stop_audio(game);game.queue_free();paused=false;await frames();await create_timer(.3).timeout
 # The fixture uses an isolated sound folder and never overwrites user takes.
 DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox+".cfg"));DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox+"-sounds.cfg"))
 print("DRAGOON_LANDING_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

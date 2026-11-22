extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roster=preload("res://scripts/rogue_roster.gd")
const OUT="res://build/Other Files/Asset Toolkit/Aoi/"
var samples:Array[float]=[]

func tap(action:String):
 game.player.auto_attack_enabled=true
 game.player.auto_lock_target=game.training_dummy;game.player.auto_lock_refresh=100
 super.tap(action)
 game.player.auto_attack_enabled=false

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)

func run():
 create_timer(100).timeout.connect(func():printerr("AOI_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player
 var home=Vector3(-150,0,150)
 home.y=game.model.surface_height(home.x,home.z)+.1
 p.position=home;game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(8,5.0,-10)
 game.camera_rig.camera.look_at(home+Vector3.UP*1.4)
 p.select_character(Roster.KAZI_ID)
 var kaz=p.model
 var kaz_slots=p.spell_loadout.numbered_slots.duplicate(true)
 p.select_character(Roster.AOI_ID)
 var visual=p.model
 var kit=p.active_ability
 check(Roster.selection_ids().has(Roster.AOI_ID) and Roster.class_id(Roster.AOI_ID)=="aoi","Original adventurer has a stable selectable ID")
 check(visual.get_script()==kaz.get_script() and kit.get_script()==p.character_abilities[Roster.KAZI_ID].get_script(),"Aoi shares Kaz's existing sprite model and combat controller")
 check(p.spell_loadout.numbered_slots==kaz_slots,"Aoi inherits Kaz's existing skill defaults")
 check(visual.appearance.key=="original:aoi" and visual.atlases.size()==visual.appearance.pages,"Only the new character's prepared atlas pages are loaded")
 game.forest_ui.sync_character()
 check(game.forest_ui.hero_portrait.texture==Roster.portrait(Roster.AOI_ID) and game.forest_ui.hero_portrait.material.get_shader_parameter("face_crop")==Vector4(0,0,1,1),"HUD uses the separate prepared face crop")
 check(visual.find_children("*","Skeleton3D",true,false).is_empty(),"No runtime rig or retargeter is created")
 check(visual.appearance.authoring.pipe_multiplier==4 and is_equal_approx(visual.appearance.authoring.pipe_length,3.8),"Authored pipe is four times its short ruler")
 check(is_equal_approx(visual.standing_height(),kaz.standing_height()),"Body height matches Kaz at the default scale")
 check(SoundLibrary.original_for(Roster.AOI_ID,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(Roster.AOI_ID,"land")==SoundLibrary.HUMANOID_LANDING,"Prepared Goemon footstep and landing defaults are reused")
 var camera=game.camera_rig.camera
 var right=Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
 var back=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
 for direction in 8:
  var angle=(direction-1)*TAU/8
  p.facing=right*sin(angle)-back*cos(angle)
  check(visual.direction()==direction,"Direction slot %d follows camera-relative facing"%direction)
  for action in [0,1,3,5,6,8,9,10]:
   var key="%d:%d"%[action,direction]
   var clip:Dictionary=visual.motions.clips[key]
   visual.show_pose(action,float(clip.duration)*.5,false)
   check(visual.current_clip==key and visual.sprite.texture in visual.atlases,"Prepared action %s draws its own atlas frame"%key)
 p.facing=Vector3.FORWARD
 visual.show_pose(0,0,true)
 await capture("Aoi standing")
 game.show_rogue_roster();await frames(3)
 var card=game.menu.find_child("RogueFighter_aoi",true,false)
 check(card!=null and card.get_meta("fighter_id")==Roster.AOI_ID,"Aoi appears beside the original Cross Gate cast")
 check(card.find_child("SelectionPortrait",true,false).texture==Roster.selection_portrait(Roster.AOI_ID),"Gallery fits the complete portrait, including the long pipe")
 await capture("Aoi gallery")
 game.close_rogue_roster()
 var dummy=game.training_dummy
 dummy.position=home+Vector3.FORWARD*3;dummy.home=dummy.position
 p.velocity=Vector3.ZERO;p.attack_chain.reset();contacts.clear()
 tap("light_attack")
 var cuts:Array=kit.cut_times
 kit.tick(float(cuts[0])-.001)
 check(contacts.is_empty(),"Pipe windup does not hit early")
 kit.tick(.002);visual.show_pose(5,kit.elapsed,false)
 check(contacts.size()==1,"First pipe contact uses the existing cut marker")
 await capture("Aoi pipe contact")
 kit.tick(float(cuts[1])-kit.elapsed+.001)
 check(contacts.size()==2,"Second pipe contact uses the existing cut marker")
 kit.tick(1)
 check(contacts.size()==2 and not kit.is_attacking(),"Recovery adds no stale hit")
 for repeat in 12:
  p.attack_chain.reset();tap("light_attack");kit.tick(1)
 check(contacts.size()==26,"Twelve repeated attacks retain exactly two contacts each")
 var nodes=visual.find_children("*","Node",true,false).size()
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for tick in 1200:
  visual.locomotion_velocity=Vector3.FORWARD*5
  var start=Time.get_ticks_usec()
  visual.animate(1.0/60,5,true,0,0,false,0,false)
  samples.append(float(Time.get_ticks_usec()-start))
 check(visual.find_children("*","Node",true,false).size()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated sprite playback retains node and resource counts")
 var kaz_samples:Array[float]=[]
 kaz.locomotion_velocity=Vector3.FORWARD*5
 for tick in 1200:
  var start=Time.get_ticks_usec()
  kaz.animate(1.0/60,5,true,0,0,false,0,false)
  kaz_samples.append(float(Time.get_ticks_usec()-start))
 visual.jump_age=.01;visual.jump_count=1
 check(visual.show_jump_pose(false,5) and visual.current_clip.begins_with("9:"),"Jump takeoff uses the new guard frames")
 visual.jump_age=.3
 check(visual.show_jump_pose(false,-2) and visual.current_clip.begins_with("3:"),"Jump descent reuses the existing Cross Gate presentation")
 visual.reset_jump_pose()
 var pool=preload("res://scripts/character_projectile_pool.gd").service(game)
 var waves:Array=[]
 var observe=func(shot):
  if shot.hero==p and shot.attack_ticket.get("action","")=="kazi/moon":waves.append(shot)
 pool.launched.connect(observe)
 var misses:int=pool.misses
 var moon=p.spell_loadout.instances["%d:kazi/moon"%Roster.AOI_ID]
 p.spell_loadout.number_input(1,true);p.spell_loadout.number_input(1,false)
 check(p.spell_loadout.current==moon and moon.busy(),"The inherited first skill starts on Aoi")
 p.spell_loadout.tick(moon.controller.MOON_RELEASE+.001)
 check(visual.current_clip.begins_with("5:") and p.model==visual,"The inherited cast uses Aoi's own prepared attack frames")
 check(waves.size()==6 and pool.misses==misses,"Six inherited sword waves launch through the prepared projectile pool")
 for shot in waves:pool.release(shot)
 pool.launched.disconnect(observe);p.spell_loadout.cancel()
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:
  var allocated=mirrors.reinforce(Roster.AOI_ID,home+Vector3.BACK.rotated(Vector3.UP,i*TAU/5)*2)
  check(allocated,"Native owner accepts Aoi ally %d"%i)
 check(mirrors.bodies.size()==5 and mirrors.bodies.all(func(b):return b.model.atlases[0]==visual.atlases[0]),"Five native allies share the same prepared atlas")
 var before_contacts=contacts.size()
 for body in mirrors.bodies:body.perform(0,dummy.global_position)
 for i in 40:
  for body in mirrors.bodies:
   body.step(1.0/60,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
 check(mirrors.bodies.all(func(b):return not b.active_ability.is_attacking()),"Simultaneous native allies finish their attacks")
 check(contacts.size()==before_contacts+10,"Five simultaneous allies each deliver both contacts")
 await capture("Aoi native allies")
 mirrors.dispose()
 if DisplayServer.get_name()!="headless":
  var start=p.position
  var camera_offset=camera.global_position-p.position
  var shown_frames={}
  p.smoke_mode=true;p.smoke_move=Vector2.RIGHT;p.set_physics_process(true)
  for tick in 36:
   await physics_frame
   camera.global_position=p.position+camera_offset;camera.look_at(p.position+Vector3.UP*1.4)
   shown_frames[visual.current_frame]=true
   if tick%6==0:await capture("Aoi travel %02d"%tick)
  p.set_physics_process(false);p.smoke_move=Vector2.ZERO
  check(p.position.distance_to(start)>1.0 and shown_frames.size()>3,"Rendered movement travels across the terrain and advances real sprite frames")
 samples.sort()
 kaz_samples.sort()
 var report={"checks":checks,"failures":failures,"sprite_pose_us_p95":samples[int(samples.size()*.95)],"sprite_pose_us_max":samples.back(),"kaz_pose_us_p95":kaz_samples[int(kaz_samples.size()*.95)],"renderer":DisplayServer.get_name(),"note":"Pose callback only; not full-frame or full-army performance"}
 var file=FileAccess.open(OUT+"gameplay-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 game.queue_free();await frames(4)
 DirAccess.remove_absolute(cfg)
 print("AOI_RESULT ",JSON.stringify(report))
 quit(1 if failures else 0)

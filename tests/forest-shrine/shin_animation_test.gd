extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roster=preload("res://scripts/rogue_roster.gd")
const Gear=preload("res://scripts/forest/equipment.gd")
const OUT="res://build/Other Files/Asset Toolkit/Shin Animation Review/"
var reviewed:Array=[]
var focused="--red-lightning-only" in OS.get_cmdline_user_args()
var output=OUT

func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+stem+".png")==OK,"Capture "+stem)

func verify_shift_controls(p):
 check(InputMap.action_get_events("sprint").any(func(event):return event is InputEventKey and event.physical_keycode==KEY_SHIFT),"Shift is bound to sprint")
 for character in Roster.CROSSGATE:
  p.select_character(character);p.active_ability.cancel(true);p.set_auto_attack(false)
  var model=p.model
  model.reset_jump_pose();model.clear_kagerou_dodge()
  for speed in [8.0,30.0]:
   model.locomotion_velocity=Vector3.FORWARD*speed
   Input.action_release("sprint");Input.action_release("walk_modifier")
   model.animate(1.0/60,speed,true,0,0,false,0,false)
   check(model.current_clip.begins_with("1:"),"%d walks without Shift at speed %s"%[character,speed])
   var phase=model.phase
   Input.action_press("sprint")
   model.animate(0,speed,true,0,0,false,0,false)
   check(model.current_clip.begins_with("3:") and model.phase==phase,"%d Shift selects run without restarting stride"%character)
   Input.action_press("walk_modifier")
   model.animate(0,speed,true,0,0,false,0,false)
   check(model.current_clip.begins_with("1:"),"%d slow walk overrides Shift even with boosted movement"%character)
   Input.action_release("walk_modifier");Input.action_release("sprint")
   model.animate(0,speed,true,0,0,false,0,false)
   check(model.current_clip.begins_with("1:"),"%d releasing Shift returns to walk"%character)
  model.locomotion_velocity=Vector3.ZERO
  Input.action_press("sprint")
  var phase=model.phase
  var steps=model.locomotion.step_events
  model.animate(.2,18,true,0,0,false,0,false)
  check(model.current_clip.begins_with("0:") and model.phase==phase and model.locomotion.step_events==steps,"%d holding Shift against an obstruction stays idle without footsteps"%character)
  Input.action_release("sprint")

func run():
 create_timer(600).timeout.connect(func():printerr("SHIN_ANIMATION_TIMEOUT");quit(1))
 if focused:output="res://build/Other Files/Asset Toolkit/Red Lightning Run/"
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[];game.paused=false;game.playing=true
 var p=game.player
 var home=Vector3(-120,0,125)
 home.y=game.model.surface_height(home.x,home.z)+.05
 if focused:verify_shift_controls(p)
 game.training_dummy.position=home+Vector3.UP*100
 game.camera_rig.camera.global_position=home+Vector3(0,12,20)
 game.camera_rig.camera.look_at(home+Vector3.UP*1.5)
 for character in ([Roster.SHIN_SPECIAL_ID] if focused else [Roster.SHIN_ID,Roster.SHIN_SPECIAL_ID]):
  p.select_character(character)
  var skins=Roster.skin_catalog(character).keys()
  if character==Roster.SHIN_SPECIAL_ID:skins.append_array(Roster.ShinSkins.HIDDEN_CLASSIC)
  for skin in skins:
   if focused and skin!=118993:continue
   game.select_shin_skin(character,skin)
   var routes:Dictionary=Gear.catalog()[str(character)][str(skin)]
   for weapon in routes:
    p.active_ability.cancel(true);p.set_auto_attack(false)
    var model=p.model
    model.apply_gear_weapon(weapon,routes[weapon])
    model.clear_kagerou_dodge();model.reset_jump_pose()
    p.position=home;p.facing=Vector3.FORWARD;model.rotation.y=0
    var label_="%d/%s"%[skin,weapon]
    if focused:check(model.motions.run_reuse.part=="sword_run" and model.motions.run_reuse.source_id==100184,"Red Lightning loads the reviewed native sword-run grip")
    for action in [0,1,3,5,6,8,9,10]:
     for direction in 8:
      var key="%d:%d"%[action,direction]
      if action==9 and model.jump_guard_atlas!=null:
       model.show_frame(action,key,0)
       check(model.sprite.texture==model.jump_guard_atlas,label_+" guard "+key)
       continue
      check(model.motions.clips.has(key),label_+" has "+key)
      if not model.motions.clips.has(key):continue
      var clip:Dictionary=model.motions.clips[key]
      check(float(clip.duration)>0 and not clip.frames.is_empty(),label_+" valid "+key)
      for index in clip.frames.size():
       var frame:Array=clip.frames[index]
       model.show_frame(action,key,index)
       var rect=Rect2(frame[1],frame[2],frame[3],frame[4])
       var texture:Texture2D=model.atlases[int(frame[0])]
       check(Rect2(Vector2.ZERO,texture.get_size()).encloses(rect) and model.sprite.texture==texture and model.sprite.region_rect==rect,label_+" draws "+key+" frame %d"%index)
    # Exercise the same locomotion callback used by the player and native copies.
    for direction in 8:
     p.facing=Vector3.FORWARD.rotated(Vector3.UP,direction*TAU/8)
     for speed in [0.0,2.0,8.0]:
      var expected=0 if speed==0 else 1 if speed<=2.5 else 3
      if expected==3:Input.action_press("sprint")
      else:Input.action_release("sprint")
      var seen={}
      model.locomotion_velocity=p.facing*speed
      for tick in 90:
       model.animate(1.0/60,speed,true,0,0,false,0,false)
       seen[model.current_frame]=true
       check(model.current_clip=="%d:%d"%[expected,model.direction()],label_+" selects movement %d"%expected)
      check(seen.size()==model.motions.clips[model.current_clip].frames.size(),label_+" plays every movement frame")
    # Check real body movement too, rather than only injecting a visual speed.
    p.smoke_mode=true;p.smoke_move=Vector2(0,-1);p.impact_pause=0
    p.dodge_time=0;p.jump_windup=0;p.combat_hold_left=0
    var moving_frames={}
    var travel=[]
    for stage in ([0,1,2] if focused else [1]):
     var boosting=stage==1
     var shift=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=boosting;shift.shift_pressed=boosting
     Input.parse_input_event(shift);Input.flush_buffered_events()
     await physics_frame
     check(Input.is_action_pressed("sprint")==boosting,"Real Shift event sets sprint input")
     p.position=home;p.velocity=Vector3.DOWN;p.move_and_slide();model.reset_jump_pose()
     var seen={}
     var expected=3 if boosting else 1
     for tick in (60 if focused else 30):
      await physics_frame
      p._physics_process(1.0/60)
      if model.current_clip.begins_with("%d:"%expected):seen[model.current_frame]=true
      if focused and tick%5==0:
       var camera=game.camera_rig.camera
       camera.global_position=p.position+Vector3(0,4,9)
       camera.look_at(p.position+Vector3.UP*1.5)
       await capture("shift-stage%d-frame%02d"%[stage,tick])
     var distance=p.position.distance_to(home)
     check(distance>2 and seen.size()>1 and model.current_clip.begins_with("%d:"%expected),label_+" actual movement uses %s after Shift %s"%["run" if boosting else "walk","press" if boosting else "release"])
     travel.append(distance)
     if boosting:moving_frames=seen
    if focused:check(travel[1]>travel[0]*1.3 and travel[1]>travel[2]*1.3,"Shift retains faster gameplay travel; release restores normal speed")
    p.smoke_move=Vector2.ZERO;p.position=home;p.velocity=Vector3.ZERO
    Input.action_release("sprint")
    model.reset_jump_pose();model.locomotion_velocity=Vector3.ZERO
    p.facing=Vector3.FORWARD;model.rotation.y=0
    if focused:
     var camera=game.camera_rig.camera
     camera.global_position=home+Vector3(0,4,9)
     camera.look_at(home+Vector3.UP*1.5)
     check([home,home+Vector3.UP*model.standing_height()].all(func(point):return not camera.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(root.size)).has_point(camera.unproject_position(point))),"Body and grip remain in view after resetting the moving fixture")
    reviewed.append({"character":character,"skin":skin,"weapon":weapon,"run_frames":moving_frames.size(),"shift_travel":travel})
    if focused:
     for direction in 8:
      p.facing=Vector3.FORWARD.rotated(Vector3.UP,direction*TAU/8)
      var key="3:%d"%model.direction()
      for index in model.motions.clips[key].frames.size():
       model.show_frame(3,key,index)
       await capture("run-facing%d-frame%d"%[model.direction(),index])
     var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
     for index in 5:
      check(mirrors.reinforce(character,home+Vector3(index,0,0)),"Reuse native Red Lightning copy")
     for tick in 60:
      for copy in mirrors.bodies:
       copy.step(1.0/60,{"position":copy.position,"hp":copy.max_hp,"yaw":0.0,"pose_velocity":Vector3.FORWARD*8})
     check(mirrors.bodies.all(func(copy):return copy.model.motions.has("run_reuse") and copy.model.current_clip.begins_with("3:") and copy.model.atlases[-1]==model.atlases[-1]),"Five native copies share and play the prepared running atlas")
     mirrors.dispose();await frames(4)
     var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
     Input.action_press("sprint")
     for tick in 600:
      model.locomotion_velocity=Vector3.FORWARD*8
      model.animate(1.0/60,8,true,0,0,false,0,false)
     check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated running retains no extra nodes or resources")
     Input.action_release("sprint")
     p.facing=Vector3.FORWARD
    if weapon==routes.keys()[0] and skin not in Roster.ShinSkins.HIDDEN_CLASSIC:
     for action in [0,1,3,5,6,8,9,10]:
      var count=1 if action==9 and model.jump_guard_atlas!=null else model.motions.clips["%d:%d"%[action,model.direction()]].frames.size()
      for sample in 3:
       model.show_frame(action,"%d:%d"%[action,model.direction()],mini(count-1,floori(sample*count/3.0)))
       await capture("game-%d-%d-%d"%[skin,action,sample])
     # Play an unbroken source run cycle on screen for separate visual review.
     Input.action_press("sprint")
     for tick in 60:
      model.locomotion_velocity=Vector3.FORWARD*8
      model.animate(1.0/60,8,true,0,0,false,0,false)
      if DisplayServer.get_name()!="headless":await process_frame
     Input.action_release("sprint")
    await frames()
   print("SHIN_ANIMATION_SKIN ",skin," weapons=",routes.size()," failures=",failures)
 var result={"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"routes":reviewed}
 var receipt=FileAccess.open(output+("headless" if DisplayServer.get_name()=="headless" else "desktop")+".json",FileAccess.WRITE)
 receipt.store_string(JSON.stringify(result,"  "));receipt.close()
 var path=game.settings_path
 game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("SHIN_ANIMATION_RESULT checks=%d failures=%d routes=%d"%[checks,failures,reviewed.size()])
 quit(1 if failures else 0)

extends "res://tests/forest-shrine/attack_reach_presentation_test.gd"
const INK=preload("res://assets/rogue/shaders/magic_ink_brush.gdshader")
const OUT="res://build/Other Files/Asset Toolkit/Strong Melee/"
var output=OUT
var driver
var cpu=[]
var intervals=[]
var last_frame=0
func brushes(node:Node)->Array:
 var found=[]
 if node is MeshInstance3D and node.get_script() in [preload("res://scripts/recovered_leader_trail.gd"),preload("res://scripts/recovered_musashi_trail.gd"),preload("res://assets/rogue/scripts/magic_sword_brush.gd")] and not (node.get_script()==preload("res://scripts/recovered_leader_trail.gd") and (node.additive or node.original)) and node.name!="OriginalWeaponBrush":found.append(node)
 for child in node.get_children():found.append_array(brushes(child))
 return found
func original_brushes(hero)->Array:
 var model=hero.model
 if hero.character_id==15:return [model.original_blade_trail]
 if hero.character_id in [31,32]:return model.blade_trails.map(func(b):return b.original)
 if hero.character_id==13:
  var found=[]
  for trail in [model.sword_trail,model.dual_sword_trail]:
   found.append(trail.original_trail)
   for old in trail.fading_trails:found.append(old.original_trail)
  return found
 if hero.is_rogue_character():
  var found=[]
  for item in hero.active_ability.fx.items:
   if item.kind=="magic-brush" and item.node.original_brush!=null:found.append(item.node.original_brush)
  return found
 return []
func live_originals(hero)->Array:
 return original_brushes(hero).filter(func(b):return b.is_visible_in_tree() and b.layers!=0 and b.mesh!=null and b.mesh.get_surface_count()>0)
func visible_brushes()->Array:
 var found=brushes(game.player.model)
 var c=game.player.active_ability
 if c!=null and game.player.is_rogue_character():found.append_array(brushes(c.fx))
 if game.player.character_id==18:found.append(c.sword_brush)
 return found.filter(func(b):return b.is_visible_in_tree() and b.mesh!=null and b.mesh.get_surface_count()>0)
func step(count:int):
 await driver.advance(count,func(dt):
  var started=Time.get_ticks_usec();game.camera_focused=true;game.player._physics_process(dt);game.player.model.sync_skeleton()
  cpu.append(Time.get_ticks_usec()-started)
  var now=Time.get_ticks_usec()
  if last_frame>0:intervals.append(now-last_frame)
  last_frame=now)
func input_attack(down:bool):
 var event=InputEventAction.new();event.action="light_attack";event.pressed=down
 if down:game.player._unhandled_input(event)
 else:game.player._input(event)
func run():
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 create_timer(240).timeout.connect(func():printerr("STRONG_MELEE_TIMEOUT");quit(1))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false);node.set_process_input(false);node.set_process_unhandled_input(false)
 game.music.stop();game.camera_focused=false;game._sync_camera_mouse();game.tuning.invincible=true
 game.camera_focused=true
 game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO;game.player.set_auto_attack(false)
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var p=game.player;var origin=Vector3(25,game.model.surface_height(25,25)+.15,25)
 var rows=[]
 var selected=[9,1,3,4,5,7,8,11,12,13,15,16,17,28,29,31,32,33,18]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
  if arg.begins_with("--fighters="):selected=Array(arg.trim_prefix("--fighters=").split(",")).map(func(id):return int(id))
 for id in selected:
  p.cancel_charge();p.select_character(id);p.position=origin;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.soft_target=false
  p.clear_powerups();p.attack_chain.reset();tune(id,4 if id in [28,16,17] else 1)
  if p.active_ability!=null:p.active_ability.cancel()
  if id==18:p.active_ability.select_slot(5)
  await step(12)
  var camera=game.camera_rig.camera
  var large=id in [29,31,32,33]
  camera.global_position=origin+(Vector3(25,22,38) if large else Vector3(9,7,16));camera.look_at(origin+Vector3.UP*(7 if large else 1.5))
  var seen=false;var combined=false;var original_seen=false;var strongest=0.0;var image_:Image;var phase=0
  input_attack(true);await step(1);input_attack(false)
  for frame in 42:
   await step(1)
   var active=visible_brushes()
   if not active.is_empty():
    seen=true
    if not original_seen and not live_originals(p).is_empty():
     var originals=live_originals(p)
     if id in [15,31,32]:
      var tint=Color("fff0b0") if id==15 else p.model.Effects.energy_color(id)
      check(originals.all(func(b):return b.heavy_color.is_equal_approx(tint)),"Fighter %d original trail retains its own RGB"%id)
      if id in [31,32]:
       check(p.model.blade_trails.all(func(b):return b.original.samples.back().tip.distance_to(p.model.physical_blade_segment(b)[1])<.001),"Fighter %d original trail follows the physical blade"%id)
     elif p.is_rogue_character():
      check(originals.all(func(b):return b.material_override.get_shader_parameter("custom_palette")==true and not b.material_override.get_shader_parameter("strong_energy")),"Fighter %d retains its original pigment treatment"%id)
     original_seen=true
    if id==28 and p.model.blade_trail.mesh!=null:
     combined=true
     check(p.model.blade_trail.material_override is StandardMaterial3D and p.model.blade_trail.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Kojiro retains the original additive blade glow")
     check(p.model.blade_trail.light_color.is_equal_approx(Color(240.0/255,120.0/255,240.0/255)),"Both Kojiro layers retain his original pink-purple")
    var area=0.0
    for b in active:
     area+=b.mesh.get_aabb().size.length_squared()
     var palettes={1:[Color("ffdf83"),Color("fff0b0")],15:[Color("fff0b0")],16:[Color("d7d4ac")],17:[Color("b4e4c3")],28:[Color(240.0/255,120.0/255,240.0/255)],29:[Color("a9d670")],31:[Color("ff2028")],32:[Color("b05bff")],33:[Color("278dff")],18:[Color("75dfff")]}
     if palettes.has(id):
      var pigment=b.material_override.get_shader_parameter("ink_tint")
      check(palettes[id].any(func(tint):return pigment.is_equal_approx(tint)),"Fighter %d retains its own attack color"%id)
     check(b.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]!=null,"Fighter %d crescent has the shared pigment coordinates"%id)
     check(b.material_override.get_shader_parameter("strong_energy")==true or b.material_override.get_shader_parameter("purple_energy")==true or b.material_override.get_shader_parameter("crimson")==true,"Fighter %d uses its bright edged energy palette"%id)
    if area>maxf(.05,strongest) and frame>=3 and (id!=28 or combined) and DisplayServer.get_name()!="headless":
     strongest=area;phase=frame;await process_frame;await RenderingServer.frame_post_draw;image_=root.get_texture().get_image();last_frame=0
   elif id==8:
    seen=seen or p.active_ability.fx.items.any(func(row):return row.kind=="thrust")
    if seen and frame==10 and DisplayServer.get_name()!="headless":
     await process_frame;await RenderingServer.frame_post_draw;image_=root.get_texture().get_image();last_frame=0
  check(seen,"Fighter %d draws strong attack presentation"%id)
  if id in [3,5,7,11,12,13,15,31,32]:check(original_seen,"Fighter %d draws the original effect alongside the strong crescent"%id)
  if id==28:check(combined,"Kojiro draws his original blade trail together with the new crescent")
  if image_!=null:check(image_.save_png(output+"fighter-%d.png"%id)==OK,"Capture fighter %d"%id)
  rows.append({"fighter":id,"seen":seen,"capture_frame":phase})
  p.cancel_charge()
  if p.active_ability!=null:p.active_ability.cancel()
  await step(40)
  check(visible_brushes().is_empty(),"Fighter %d cancellation leaves no stale crescent"%id)
  check(live_originals(p).is_empty(),"Fighter %d cancellation clears original effects too"%id)
  if id==28:check(p.model.blade_trail.mesh==null and p.model.blade_trail.samples.is_empty(),"Cancellation clears the original blade layer too")
 await kojiro_range_contact(origin)
 await kojiro_combined_allies(origin)
 await combined_allies(origin)
 await allied_reuse()
 cpu.sort();intervals.sort()
 var report={"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"fighters":rows,"manual_player_step_us":{"p95":cpu[int(cpu.size()*.95)],"max":cpu[-1]},"physics_callback_us":{"p95":intervals[int(intervals.size()*.95)],"max":intervals[-1]},"note":"Manual player stepping and isolated native ally presentation; no full battle or controlled FPS claim."}
 FileAccess.open(output+"focused-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("STRONG_MELEE_RESULT ",JSON.stringify(report))
 game.queue_free();await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
func kojiro_range_contact(origin:Vector3):
 var p=game.player;p.select_character(28);tune(28,4);p.position=origin+Vector3.UP*12;p.velocity=Vector3.ZERO;await step(5)
 origin=p.position
 p.facing=Vector3.FORWARD;p.soft_target=false;p.active_ability.cancel()
 # Prepared native hurtbox, frozen independently of the visual test.
 p.model.rotation.y=0
 var reach=p.active_ability.melee_visual_reach()
 var row=game.model.waves.spawn_enemy(0,origin+Vector3.FORWARD*(reach*.8));row.hp=100000;row.max_hp=row.hp;row.stun=100
 var army=game.army_runtime;army.import_arrivals();army.set_pose(army.handles[row.id],origin+Vector3.FORWARD*(reach*.8),0);army.sync_targets();army.sync_compatibility();game.model.update_vision(origin)
 p.active_ability.start_skill("slash");p.facing=Vector3.FORWARD;p.model.rotation.y=0
 p.active_ability.tick(.26);p.model.animate(1.0/60,0,true,0,0,false,1,false)
 check(p.model.trail.mesh==null and p.model.sword_contact_ready,"First cut keeps the full-range crescent out of the rear windup")
 check(not p.model.blade_trail.samples.is_empty(),"Original compact glow still follows the windup sword")
 check(army.unit_state(army.handles[row.id]).hp<100000,"Kojiro retains damage at the original source contact tick")
 var hp=army.unit_state(army.handles[row.id]).hp
 p.active_ability.tick(.05);p.model.animate(.05,0,true,0,0,false,1,false)
 check(p.model.trail.mesh!=null and p.model.blade_trail.mesh!=null,"Forward snap shows both original glow and the strong crescent")
 check(p.model.trail.samples.all(func(sample):return (sample.tip-origin).dot(p.facing)>0),"Every extended first-cut sample points in front of Kojiro")
 check(army.unit_state(army.handles[row.id]).hp==hp,"Delayed cosmetic presentation adds no duplicate damage")
 p.active_ability.cancel();game.settings.reduced_flashes=true
 p.active_ability.start_skill("slash");p.active_ability.tick(.31);p.model.animate(.016,0,true,0,0,false,1,false)
 check(is_equal_approx(p.model.trail.material_override.get_shader_parameter("energy"),.42),"Reduced flashes subdue the forward crescent")
 game.settings.reduced_flashes=false;p.active_ability.cancel()
 for reach_scale in [1,4]:
  tune(28,reach_scale)
  for yaw in [0.0,PI/2,PI]:
   for hz in [30,60,120]:
    for stage in 3:
     var combat=p.active_ability;combat.cancel();combat.combo=stage-1;combat.combo_timer=1;combat.start_skill("slash")
     p.facing=Vector3.FORWARD.rotated(Vector3.UP,yaw);p.model.rotation.y=yaw
     var seen=false;var forward_only=true
     for frame in ceili(combat.duration*hz/2):
      combat.tick(1.0/hz);p.model.animate(1.0/hz,0,true,0,0,false,stage+1,false)
      if p.model.trail.mesh!=null:
       seen=true
       for sample in p.model.trail.samples:forward_only=forward_only and (sample.tip-p.global_position).dot(p.facing)>.0
       var arrays=p.model.trail.mesh.surface_get_arrays(0)
       for v in arrays[Mesh.ARRAY_VERTEX].size():
        if arrays[Mesh.ARRAY_TEX_UV][v].y==1:forward_only=forward_only and (arrays[Mesh.ARRAY_VERTEX][v]-p.global_position).dot(p.facing)>-.005
     check(seen and forward_only,"Kojiro cut %d stays forward at reach %d yaw %.2f %d Hz (seen=%s forward=%s)"%[stage,reach_scale,yaw,hz,seen,forward_only])
     combat.cancel()
     check(not p.model.sword_contact_ready and p.model.trail.mesh==null,"Cancel clears pending forward-cut presentation")
 tune(28,4)

func kojiro_combined_allies(origin:Vector3):
 var p=game.player;p.active_ability.cancel();p.position=origin;p.velocity=Vector3.ZERO
 await step(5)
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 check(mirrors.cast() and mirrors.bodies.size()==5,"Five native Kojiro allies prepare both visual layers")
 var ids=[]
 for i in mirrors.bodies.size():
  var body=mirrors.bodies[i];body.set_physics_process(false);body.model.set_process(false);body.active_ability.set_process(false)
  body.position=origin+Vector3((i-2)*5,0,0);body.facing=Vector3.FORWARD;body.ai_aim=body.position+Vector3.FORWARD*30
  ids.append([body.model.trail.prepared_mesh.get_instance_id(),body.model.blade_trail.prepared_mesh.get_instance_id(),body.model.trail.material_override.get_instance_id(),body.model.blade_trail.material_override.get_instance_id()])
 var timings=[]
 for cycle in 5:
  for body in mirrors.bodies:body.active_ability.cancel();body.active_ability.start_skill("slash")
  var seen={}
  for frame in 18:
   var before=Time.get_ticks_usec()
   for body in mirrors.bodies:
    body.active_ability.tick(1.0/60);body.model.animate(1.0/60,0,true,0,0,false,1,false)
    if body.model.trail.mesh!=null and body.model.blade_trail.mesh!=null:seen[body.get_instance_id()]=true
   timings.append(Time.get_ticks_usec()-before)
  check(seen.size()==5,"Every native ally shows both layers together on repeat %d"%cycle)
  for i in mirrors.bodies.size():
   var body=mirrors.bodies[i];body.active_ability.cancel()
   check(body.model.trail.mesh==null and body.model.blade_trail.mesh==null,"Native ally cancellation clears both layers")
   check(ids[i]==[body.model.trail.prepared_mesh.get_instance_id(),body.model.blade_trail.prepared_mesh.get_instance_id(),body.model.trail.material_override.get_instance_id(),body.model.blade_trail.material_override.get_instance_id()],"Native ally repeats reuse both meshes and materials")
 timings.sort();print("KOJIRO_COMBINED_ALLY_US p95=",timings[int(timings.size()*.95)]," max=",timings[-1])
 mirrors.dispose();await frames(3)

func combined_allies(origin:Vector3):
 var p=game.player;var timings=[]
 for id in [15,13,31,32,7]:
  var fighter_timings=[]
  p.select_character(id);p.position=origin;p.velocity=Vector3.ZERO;await step(5)
  var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
  check(mirrors.cast(),"Fighter %d prepares five native combined-effect allies"%id)
  for i in mirrors.bodies.size():
   var body=mirrors.bodies[i];body.set_physics_process(false);body.model.set_process(false);body.active_ability.set_process(false)
   body.position=origin+Vector3((i-2)*5,0,0);body.facing=Vector3.FORWARD
  var identities=[]
  for body in mirrors.bodies:
   identities.append(original_brushes(body).map(func(b):return b.get_instance_id()))
  for cycle in 3:
   game.settings.reduced_flashes=cycle==1
   var seen={}
   for body in mirrors.bodies:
    body.active_ability.cancel();body.perform(0,body.position+Vector3.FORWARD*30);body.release()
   for frame in 40:
    var before=Time.get_ticks_usec()
    for body in mirrors.bodies:
     body.active_ability.tick(1.0/60)
     if body.is_rogue_character():body.active_ability._animate(1.0/60,0)
     else:body.model.animate(1.0/60,0,true,0,body.attack_left,false,1,false)
     if not live_originals(body).is_empty():seen[body.get_instance_id()]=true
    var elapsed=Time.get_ticks_usec()-before
    timings.append(elapsed)
    if cycle>0:fighter_timings.append(elapsed)
   check(seen.size()==5,"Fighter %d has both layers for all five native allies on repeat %d"%[id,cycle])
   for i in mirrors.bodies.size():
    var body=mirrors.bodies[i];body.active_ability.cancel()
    if body.is_rogue_character():body.active_ability.fx.tick(1)
    check(live_originals(body).is_empty(),"Fighter %d native ally clears originals on cancellation"%id)
    if not body.is_rogue_character():check(identities[i]==original_brushes(body).map(func(b):return b.get_instance_id()),"Fighter %d repeats reuse prepared original owners"%id)
  for body in mirrors.bodies:
   body.model.hide()
   check(live_originals(body).is_empty(),"Fighter %d hidden ally leaves no original glow"%id)
  fighter_timings.sort();print("ROSTER_COMBINED_WARM_US fighter=",id," p95=",fighter_timings[int(fighter_timings.size()*.95)]," max=",fighter_timings[-1])
  mirrors.dispose();await frames(3)
 game.settings.reduced_flashes=false
 timings.sort();print("ROSTER_COMBINED_ALLY_US p95=",timings[int(timings.size()*.95)]," max=",timings[-1])

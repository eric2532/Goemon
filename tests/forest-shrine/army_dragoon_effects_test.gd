extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Renderer=preload("res://scripts/forest/crowd/army_renderer.gd")
var checks=0
var failures=0
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func _initialize():run.call_deferred()
func run():
 if "--live" in OS.get_cmdline_user_args():
  await verify_live();finish();return
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var data=load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 var runtime=Runtime.new();runtime.configure(null);runtime.configure_kits(data);runtime.set_navigation(1,{"width":0})
 var renderer=Renderer.new();root.add_child(renderer);renderer.configure(null);renderer.configure_profiles(data)
 var fx=renderer.presentation
 check(fx.batches.has("dragon-descent") and fx.batches.has("dragon-eruption"),"Native army presentation includes both existing dragon effects")
 if failures:renderer.free();runtime.free();finish();return
 var target=runtime.spawn(1,0,0,Vector3.ZERO,100000,3.9);runtime.apply_hit(target,{"element":"ice","status_seconds":100})
 var dragoon=runtime.spawn(-1,1,8,Vector3(0,12.12,0),200,.4)
 runtime.step(.1,{});var s=runtime.render_snapshot();renderer.present(s,runtime.take_events())
 var dive:MultiMesh=fx.batches["dragon-descent"].multimesh
 check(dive.visible_instance_count==1,"A native opening drop displays its attached dragon")
 var actual=dive.get_instance_transform(0)
 var anchor=CharacterBody3D.new();root.add_child(anchor);anchor.position=s.positions[1];anchor.velocity=s.velocities[1]
 var source=load("res://assets/rogue/scripts/effects.gd").new();root.add_child(source);var original=source.dragon_descent(anchor,s.yaw[1],data.dragoon[9])
 if RenderingServer.get_rendering_device()!=null:check(actual.is_equal_approx(original.global_transform),"Batched descent retains the existing helper dragon's size, attachment and orientation")
 source.free();anchor.free()
 runtime.apply_hit(dragoon,{"element":"ice","status_seconds":.5});runtime.step(.2,{});renderer.present(runtime.render_snapshot(),runtime.take_events())
 var frozen=dive.get_instance_transform(0);var phase=dive.get_instance_custom_data(0)
 runtime.step(.2,{});renderer.present(runtime.render_snapshot(),runtime.take_events())
 check(dive.get_instance_transform(0)==frozen and dive.get_instance_custom_data(0)==phase,"Freezing the native body freezes its dragon position and animation")
 runtime.step(1.1,{});var events=runtime.take_events();renderer.present(runtime.render_snapshot(),events)
 check(events.filter(func(e):return e.kind=="landing_pulse").size()==3,"The real landing still emits all three damage pulses")
 check(dive.visible_instance_count==0 and fx.projectile_batches.dragon.multimesh.visible_instance_count==1,"Landing replaces the diving dragon with exactly one hunting dragon")
 renderer.present(runtime.render_snapshot(),events)
 check(fx.projectile_batches.dragon.multimesh.visible_instance_count==1,"Repeated native events cannot duplicate the landing dragon")
 fx.tick(.1)
 check(fx.projectile_batches.dragon.multimesh.visible_instance_count==1,"The landing dragon is submitted to the renderer")
 runtime.step(3.1,{});renderer.present(runtime.render_snapshot(),runtime.take_events())
 check(fx.projectile_batches.dragon.multimesh.visible_instance_count==0,"Hunting dragons expire after three seconds")
 runtime.clear();runtime.configure_kits(data)
 target=runtime.spawn(2,0,0,Vector3.ZERO,100000,3.9);runtime.apply_hit(target,{"element":"ice","status_seconds":100})
 dragoon=runtime.spawn(-2,1,8,Vector3(0,48.12,0),200,.4);runtime.step(.1,{})
 renderer.present(runtime.render_snapshot(),runtime.take_events());runtime.step(.8,{});renderer.present(runtime.render_snapshot(),runtime.take_events())
 check(dive.visible_instance_count==1,"A long native descent retains its dragon beyond the short effect lifetime")
 runtime.apply_hit(dragoon,{"knockback":Vector3(5,0,0),"flinch":.25});renderer.present(runtime.render_snapshot(),runtime.take_events())
 check(dive.visible_instance_count==0,"Interrupting the attack removes its dragon while the body falls")
 runtime.clear();renderer.clear()
 for i in 500:runtime.spawn(-i-1,1,8,Vector3(i*4,12,0),200,.4)
 s=runtime.render_snapshot();s.air_phase.fill(1);s.velocities.fill(Vector3.DOWN*45)
 var nodes=fx.get_child_count();renderer.present(s,[])
 check(dive.visible_instance_count<=fx.effect_capacity and fx.get_child_count()==nodes,"Many descending dragoons use bounded shared batches without actor nodes")
 fx.effect_capacity=0;renderer.present(s,[])
 check(dive.visible_instance_count==0 and runtime.render_snapshot().handles.size()==500,"Zero cosmetic capacity leaves every native fighter intact")
 renderer.clear();check(dive.visible_instance_count==0 and fx.batches["dragon-eruption"].multimesh.visible_instance_count==0,"Reset clears both dragon batches")
 renderer.free();runtime.clear();runtime.free();await process_frame;finish()
func finish():
 print("ARMY_DRAGOON_EFFECTS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
func verify_live():
 var cfg="user://dragoon-effects-live-%d.cfg"%OS.get_process_id()
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.army_runtime.set_process(false)
 game.model.gold=2000;game.model.build("barracks",Vector2i(12,10),0)
 var helpers=game.explorer_helpers;var point=Vector3.INF
 for z in range(8,18):
  for x in range(-8,9):
   var candidate=game.model.point(Vector2i(x,z))
   if helpers.placement_error(0,candidate).is_empty():point=candidate;break
  if point.is_finite():break
 check(point.is_finite() and helpers.purchase(0,point),"The real barracks can recruit a native Dragoon")
 if helpers.active_units(0).is_empty():game.free();return
 var unit=helpers.active_units(0)[0];game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.army_runtime.set_process(false)
 game.player.position=point+Vector3(0,0,8);game.player.hide();game.model.update_vision(point)
 var foe=game.model.waves.spawn_enemy(0,point+Vector3(0,0,14));foe.hp=100000;foe.max_hp=100000
 game.army_runtime.integration_tick(1.0/60);var target=game.army_runtime.handles[foe.id]
 game.army_runtime.apply_hit(target,{"element":"ice","status_seconds":100})
 var camera=Camera3D.new();root.add_child(camera);camera.current=true;camera.position=point+Vector3(23,18,30);camera.look_at(point+Vector3(0,8,10))
 root.size=Vector2i(960,720);game.ui.hide();game.camera_rig.camera.current=false;camera.current=true
 var fx=game.crowd.army.presentation;var captured_dive=false;var captured_landing=false
 for frame in 500:
  if not captured_dive:
   var p=game.army_runtime.unit_state(unit.handle).position
   game.army_runtime.set_pose(target,p+Vector3(0,-p.y,16),0)
  game.army_runtime.integration_tick(1.0/60);game.army_runtime.flush_presentation()
  if not captured_dive and fx.batches["dragon-descent"].multimesh.visible_instance_count>0:
   await capture_live("descent");captured_dive=true
  if captured_dive and fx.effects.any(func(e):return e.kind=="dragon-eruption"):
   fx.tick(.2);await capture_live("landing");captured_landing=true;break
 check(captured_dive and captured_landing,"A barracks recruit displays both dragons through the live native coordinator")
 game.sound_library.cancel();game.music.stop();camera.free();game.free();paused=false;await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
func capture_live(label_:String):
 await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
 var folder="res://build/Other Files/Dragoon Effects"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.get_texture().get_image().save_png(folder+"/"+label_+".png")

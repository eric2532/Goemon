extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func shot(label: String):
 if DisplayServer.get_name()=="headless":return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/dragoon-preview/"+label+".png")
func finish():
 Input.action_release("jump")
 game.queue_free();await frames(3)
 print("DRAGOON_PREVIEW_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
func aim_at(point: Vector3):
 game.camera_rig.camera.global_position=game.player.position+Vector3(0,5,10)
 game.camera_rig.camera.look_at(point)
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0;game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 await fresh(8);var c=game.player.active_ability
 check(c.has_method("_update_leap_preview"),"Dragoon exposes a live landing indicator")
 if failures:await finish();return
 c._update_leap_preview()
 check(c.get("_leap_preview")==null or not c.get("_leap_preview").visible,"Landing indicator stays hidden on the ground")
 game.player.jump_buffer=.15
 Input.action_press("jump")
 for i in 80:c.physics_step(1.0/60)
 aim_at(ORIGIN+Vector3(8,0,-8));c._update_leap_preview()
 var marker=c.get("_leap_preview")
 check(marker!=null and marker.visible,"Jumping and hovering show the translucent ground circle")
 if marker==null:await finish();return
 var point: Vector3=c.dragoon_landing_target()
 check(marker.global_position.distance_to(point+Vector3.UP*.045)<.05,"Circle is centered on the actual crosshair landing solution")
 check(is_equal_approx(float(marker.radius),19.8*game.player.range_multiplier()),"Outer circle matches the enlarged outer damage radius")
 var shader: ShaderMaterial=marker.visual.material_override
 check(shader.shader!=null and marker.visual.mesh is PlaneMesh,"Circle uses one reusable shader surface")
 var instance: int=marker.get_instance_id();var mesh_id: int=marker.visual.mesh.get_instance_id()
 var first: Vector3=marker.global_position
 aim_at(ORIGIN+Vector3(-10,0,-5));c._update_leap_preview()
 check(marker.global_position.distance_to(first)>5,"Crosshair movement moves the predicted damage area")
 for i in 120:c._update_leap_preview()
 check(marker.get_instance_id()==instance and marker.visual.mesh.get_instance_id()==mesh_id and marker.get_child_count()==1,"Repeated aiming reuses one mesh without accumulating effects")
 await shot("aiming")
 c.action("cutlass")
 var fixed: Vector3=c.player.travel.target
 var fixed_scale: float=c.player.travel.rangeScale
 c._update_leap_preview()
 aim_at(ORIGIN+Vector3(15,0,-10));c._update_leap_preview()
 check(marker.global_position.distance_to(fixed+Vector3.UP*.045)<.05,"Launching freezes the circle on the committed strike target")
 check(is_equal_approx(float(marker.radius),c.Actions.dragoon_impact_radius(2)*fixed_scale),"Committed preview uses the strike's damage-radius snapshot")
 c.player.travel.phase="drop";c._update_leap_preview()
 check(Vector2(marker.global_position.x-game.player.position.x,marker.global_position.z-game.player.position.z).length()<.1,"Blocked-launch fallback shows the new straight-down landing area")
 c.player.travel.phase="aimed-drop";c._update_leap_preview()
 await shot("committed")
 Input.action_release("jump")
 for i in 300:c.physics_step(1.0/120)
 c._update_leap_preview()
 check(game.player.is_on_floor() and not marker.visible,"Landing hides the aiming circle")
 game.player.jump_buffer=.15
 for i in 50:c.physics_step(1.0/60)
 c._update_leap_preview();check(marker.visible,"A new jump reuses and shows the circle")
 game.paused=true;c._update_leap_preview();check(not marker.visible,"Menu pause hides the world aiming circle")
 game.paused=false;c._update_leap_preview();check(marker.visible,"Returning to combat restores the aerial circle")
 game.player.hp=0;c._update_leap_preview();check(not marker.visible,"Death hides the circle")
 game.player.hp=100;c._update_leap_preview()
 c.cancel();check(not marker.visible,"Cancel hides the existing preview immediately")
 c._update_leap_preview();c.reset_run();check(not marker.visible,"Reset clears the existing preview immediately")
 c._update_leap_preview()
 game.model.phase="defeat";game.set_phase_view()
 await process_frame;await process_frame
 check(paused and not marker.visible,"Real paused-tree defeat overlay hides the active circle")
 paused=false;game.paused=false;game.model.phase="wave"
 c._update_leap_preview();game.player.select_character(3);c._process(0)
 check(not marker.visible,"Switching away from Dragoon hides his circle")
 await finish()

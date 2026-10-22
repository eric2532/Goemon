extends SceneTree
## Verify the extracted assets and the live HeroModel/viewmodel adapters.
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func meshes(node:Node)->Array:
	var found:Array=[]
	if node is MeshInstance3D:found.append(node)
	for child in node.get_children():found.append_array(meshes(child))
	return found
func run():
	check(ResourceLoader.exists("res://scripts/master_chief_model.gd"),"Master Chief has a dedicated character model adapter")
	check(ResourceLoader.exists("res://scripts/master_chief_viewmodel.gd"),"Rocket launcher has a dedicated first-person presentation")
	if failures:quit(1);return
	var model=load("res://scripts/master_chief_model.gd").new()
	root.add_child(model)
	await process_frame
	check(model is HeroModel and model.locomotion!=null,"Chief integrates with the real HeroModel movement contract")
	check(ResourceLoader.exists(model.BODY_PATH) and not meshes(model.rig_visual).is_empty(),"Chief loads recovered Halo geometry")
	check(model.get_meta("halo_source","")=="Xbox retail map","Model records its actual retail-map provenance")
	model.locomotion_velocity=Vector3(5,0,0)
	model.animate(.3,5,true,0,0,false,0,false)
	model.sync_skeleton()
	check(model.locomotion.step_events>0,"Grounded motion emits footsteps")
	check(model.body.transform.is_finite(),"Body pose remains finite during movement")
	var view=load("res://scripts/master_chief_viewmodel.gd").new()
	root.add_child(view)
	await process_frame
	var native_meshes=meshes(view.weapon).filter(func(mesh):return mesh.name!="MuzzleFlash")
	check(ResourceLoader.exists(view.ASSET_PATH) and native_meshes.size()>=2,"First-person weapon and arms contain recovered visible meshes")
	check(view.animations!=null and view.animations.has_animation("idle") and view.animations.has_animation("firing"),"First-person hands and weapon retain native idle and firing animations")
	check(view.get("weapon_view")!=null and view.weapon_view.own_world_3d,"Walls cannot clip the first-person arms or weapon")
	check(view.has_method("fire_shot") and view.has_method("update_motion"),"Camera can drive recoil and locomotion presentation")
	view.fire_shot()
	check(view.recoil>0,"A shot visibly recoils the weapon")
	for i in 120:view.update_motion(1.0/60,0,true)
	check(view.recoil<.001,"Recoil settles after firing stops")
	check(view.transform.is_finite(),"First-person weapon transform remains finite")
	check(view.audio.stream!=null,"Rocket launcher has a firing sound")
	view.hide();await process_frame;view._process(0)
	check(not view.overlay.visible,"Hiding Chief's weapon removes the screen overlay")
	view.show();await process_frame;view._process(0)
	check(view.overlay.visible,"Returning to Chief restores the weapon overlay")
	view.stop();await create_timer(.15).timeout
	model.queue_free();view.queue_free();await process_frame
	print("MASTER_CHIEF_MODEL_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)

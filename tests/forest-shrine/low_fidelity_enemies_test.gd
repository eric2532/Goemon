extends SceneTree
class MeasuredRaider extends "res://scripts/forest/forest_raider.gd":
	var bar_queries=0
	func combat_contact_point(point: Vector3)->Vector3:
		bar_queries+=1;return super.combat_contact_point(point)
var game
var failures=0
var checks=0
var config_path="user://low-fidelity-enemies-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n: int=3):
	for i in range(n):await process_frame
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await frames()
	var crowd=game.crowd
	check(crowd.get("low_fidelity")==true,"The playable game defaults to low-fidelity enemies")
	if crowd.get("low_fidelity")!=true:await finish();return
	check(crowd.pose_textures.is_empty() and crowd.pose_images.is_empty(),"Low fidelity allocates no animation textures")
	check(crowd.materials.is_empty() and crowd._artwork_cache.is_empty(),"No detailed enemy shaders or artwork are loaded by the renderer")
	check(crowd.batches.size()==4,"All four enemy roles remain represented")
	var parts=0
	for kind in range(4):
		for slot in crowd.primitive_batches[kind]:
			parts+=1;var batch=slot.batch;var mesh=batch.multimesh.mesh
			check(mesh is BoxMesh,"Each enemy contact region is one twelve-triangle box")
			check(batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Every low-fidelity enemy part has shadows disabled")
			var material=mesh.material
			check(material is StandardMaterial3D and material.albedo_texture==null and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"Enemy markers are flat-colored and untextured")
			check(mesh.size.is_equal_approx(slot.item.bounds.size),"Primitive dimensions follow the existing combat region")
	check(parts<=10,"Primitive draw batches remain bounded independently of enemy count")
	game.start_wave();game.set_physics_process(false);game.player.set_physics_process(false);game.model.waves.pending=0
	game.player.position=Vector3(0,.1,70)
	for kind in range(4):
		var data=game.model.waves.spawn_enemy(kind,Vector3((kind-1.5)*12,0,85));data.stun=100
	game.sync_enemies()
	for actor in game.actors.values():actor.set_physics_process(false);actor._physics_process(0)
	for x in range(-40,40):
		for z in range(-40,40):game.model.visible_cells[Vector2i(x,z)]=true
	game.crowd._process(.016)
	for kind in range(4):
		check(crowd.batches[kind].multimesh.visible_instance_count==1,"A visible enemy enters its primitive batch (%d)"%kind)
		var data=game.model.enemies.values().filter(func(e):return e.variant==kind)[0]
		var actor=game.actors[data.id]
		check(actor.model.get_child_count()==0 and not actor.model.visible,"No hidden full model or skeleton runs per enemy (%d)"%kind)
		var before=data.hp;actor.take_hit(10,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false})
		check(data.hp==before-10,"Low-fidelity enemy still receives damage (%d)"%kind)
		data.frozen=1;data.frozen_pose=data.duplicate();crowd._process(.016);await frames(2)
		if DisplayServer.get_name()!="headless":check(crowd.batches[kind].multimesh.get_instance_color(0).b>.8,"Frozen enemies remain readable using color (%d)"%kind)
		else:check(crowd._poses[data.id].frozen==1,"Primitive presentation retains authoritative freeze state without animation textures (%d)"%kind)
		data.frozen=0;data.erase("frozen_pose")
	crowd.clear()
	check(crowd.primitive_batches.all(func(slots):return slots.all(func(slot):return slot.batch.multimesh.visible_instance_count==0)),"Clear hides every live compound part, not only its primary batch")
	crowd._process(.016)
	var giant_data=game.model.enemies.values().filter(func(e):return e.variant==2)[0]
	var giant=game.actors[giant_data.id]
	giant.dead=true;game.model.enemies.erase(giant_data.id);crowd._process(.2)
	check(crowd.presentation_transform(giant,crowd._poses[giant_data.id],crowd._death_age[giant_data.id]).basis.get_scale().x<1,"A dead compound enemy shrinks using its retained presentation")
	giant.queue_free();await frames();crowd._process(.016)
	check(not crowd._poses.has(giant_data.id) and crowd.batches[2].multimesh.visible_instance_count==0,"Freed dead enemies leave no primitive instances or cached state")
	game.model.visible_cells.clear();crowd._process(.016)
	check(crowd.batches.all(func(b):return b.multimesh.visible_instance_count==0),"Fog removes hidden enemies from every primary batch")
	check(crowd.primitive_batches.all(func(slots):return slots.all(func(slot):return slot.batch.multimesh.visible_instance_count==0)),"Fog also removes compound giant and lantern parts")
	crowd.clear();check(crowd._poses.is_empty(),"Run cleanup drops primitive presentation state")
	var fixture=game.model.waves.spawn_enemy(0,Vector3(0,0,70))
	var measured=MeasuredRaider.new();measured.game=game;measured.forest_id=fixture.id;measured.variant=0;measured.position=fixture.pos;game.add_child(measured);measured.set_physics_process(false)
	measured.bar_queries=0;measured._sync_fitted_pose()
	check(measured.bar_queries==0,"A hidden full-health bar makes no fitted-surface query")
	measured.take_hit(10,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false});measured.bar_queries=0;measured._sync_fitted_pose()
	check(measured.bar_queries==0 and not measured.bar.visible,"Damaged enemies keep health bars hidden without fitting a bar surface")
	measured.queue_free();game.model.enemies.erase(fixture.id)
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("LOW_FIDELITY_ENEMIES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

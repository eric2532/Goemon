extends "res://scripts/shared_enemy_hitbox_tests.gd"
## Drawing must consume the exact snapshot physics already prepared, while
## fresh physics steps and local combat mutations still update every member.
func run():
	await setup()
	for kind in range(5):
		var fixture=spawn(kind);var actor=fixture.actor;var data:Dictionary=fixture.data
		actor.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		actor.process_mode=Node.PROCESS_MODE_DISABLED;actor.set_physics_process(true)
		await physics_frames()
		data.pos+=Vector3(1,0,0);data.walk_phase+=.1;game.model_tick_serial+=1
		actor._physics_process(1.0/60)
		var snapshot:Dictionary=actor.fitted_contact
		var formation:Dictionary=game.crowd._formations[data.id]
		var clock:float=formation.clock
		game.crowd._process(1.0/60)
		check(is_same(snapshot,actor.fitted_contact),"Drawing reuses role %d's exact prepared physics snapshot"%kind)
		check(is_same(formation,game.crowd._formations[data.id]),"Drawing does not rebuild role %d's supported formation"%kind)
		game.crowd._process(1.0/144)
		check(is_same(snapshot,actor.fitted_contact),"Extra render frames do not repeat role %d collision preparation"%kind)
		await physics_frames()
		geometry_checks(actor,data,displayed_parts(data))
		await physics_frames()
		actor._physics_process(1.0/60)
		check(game.crowd._formations[data.id].clock>clock,"Enemy motion still advances on a fresh physics step without a model tick (%d)"%kind)
		actor.combat_knockback(Vector3.RIGHT,2,.1);actor._physics_process(0)
		var changed:Dictionary=actor.fitted_contact
		check(not is_same(snapshot,changed),"A local combat mutation refreshes role %d between model ticks"%kind)
		game.crowd._process(1.0/60)
		check(is_same(changed,actor.fitted_contact),"Drawing also reuses role %d's immediate combat refresh"%kind)
		var held_clock:float=game.crowd._formations[data.id].clock
		actor.take_hit(1,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false})
		game.crowd._process(1.0/60)
		check(is_equal_approx(game.crowd._formations[data.id].clock,held_clock),"A hit after physics refreshes contacts without advancing role %d's motion twice"%kind)
		var vision:Dictionary=game.model.visible_cells.duplicate()
		game.model.visible_cells.clear();actor._sync_fitted_pose();game.crowd._process(0)
		check(not actor.has_shared_combat_contacts(),"Hidden role %d releases its rendered contacts"%kind)
		game.model.visible_cells=vision;game.crowd._process(1.0/60)
		check(actor.has_shared_combat_contacts(),"Revealing role %d restores visible member contacts before the next physics tick"%kind)
		game.explorer_helpers.living_count=48
		var army_snapshot:Dictionary=actor.fitted_contact
		var army_clock:float=game.crowd._formations[data.id].clock
		await physics_frames();actor._physics_process(1.0/60);game.crowd._process(1.0/60)
		check(is_same(army_snapshot,actor.fitted_contact),"An army's unchanged 30Hz world step reuses role %d contacts while combat keeps ticking"%kind)
		check(is_equal_approx(game.crowd._formations[data.id].clock,army_clock),"An army midpoint retains role %d motion until the world advances"%kind)
		game.model_tick_serial+=1;actor._physics_process(1.0/60)
		check(not is_same(army_snapshot,actor.fitted_contact),"The next army world step refreshes role %d geometry"%kind)
		check(is_equal_approx(game.crowd._formations[data.id].clock,army_clock+2.0/60),"An army world step consumes both elapsed role %d physics intervals exactly once"%kind)
		await physics_frames();actor._physics_process(1.0/60)
		actor.take_hit(1,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false})
		game.crowd._process(1.0/60)
		check(is_equal_approx(game.crowd._formations[data.id].clock,army_clock+3.0/60) and is_zero_approx(actor.formation_step),"A dirty army render consumes role %d pending midpoint time once"%kind)
		game.crowd._process(1.0/144)
		check(is_equal_approx(game.crowd._formations[data.id].clock,army_clock+3.0/60),"An extra army render adds no role %d motion time"%kind)
		game.explorer_helpers.living_count=0
		actor.set_physics_process(false)
		var before:float=game.crowd._formations[data.id].clock
		game.crowd._process(.1)
		check(game.crowd._formations[data.id].clock>before,"Manually driven previews still animate role %d"%kind)
		await remove_enemy(actor,data)
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	for i in 3:await process_frame
	if FileAccess.file_exists(config_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("CROWD_SNAPSHOT_REUSE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

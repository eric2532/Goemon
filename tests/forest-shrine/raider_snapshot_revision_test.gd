extends SceneTree
class CountedRaider extends "res://scripts/forest/forest_raider.gd":
	var preparations=0
	func _sync_fitted_pose():
		preparations+=1;super._sync_fitted_pose()
var checks=0
var failures=0
var cfg="user://raider-snapshot-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run():
	var probe=CountedRaider.new()
	check(probe.has_method("_fitted_pose_needs_sync"),"Raider snapshots follow actual model revisions")
	if probe.has_method("_fitted_pose_needs_sync"):
		var fake=Node.new();probe.game=fake
		check(probe._fitted_pose_needs_sync(),"Games without a model serial always retain fresh synchronization")
		fake.free()
	probe.free()
	if failures:finish();return
	var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	for i in range(3):await physics_frame
	game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.set_physics_process(false)
	check(game.get("model_tick_serial")!=null,"Forest model exposes its actual simulation tick serial")
	if game.get("model_tick_serial")==null:game.queue_free();finish();return
	var data=game.model.waves.spawn_enemy(0,Vector3(0,0,70))
	data.hp=10000;data.max_hp=10000
	var actor=CountedRaider.new();actor.game=game;actor.forest_id=data.id;actor.variant=0;actor.position=data.pos;game.add_child(actor);actor.set_physics_process(false);game.actors[data.id]=actor;game.enemies.append(actor)
	var initial=actor.preparations
	var initial_pulse=actor.pulse
	for i in range(120):actor._physics_process(1.0/60)
	check(actor.preparations==initial,"120 unchanged-model physics steps reuse one fitted preparation")
	check(absf(actor.pulse-initial_pulse-2)<.0001,"Presentation timers still advance at every physics step")
	data.pos+=Vector3(6,0,0);game.model_tick_serial+=1;actor._physics_process(1.0/60)
	check(actor.preparations==initial+1 and actor.global_position==data.pos,"Model advance refreshes the pose and authoritative position")
	data.simulation_revision=1;actor._physics_process(1.0/60)
	var sliced_previous=actor.preparations
	game.model_tick_serial+=1;actor._physics_process(1.0/60)
	check(actor.preparations==sliced_previous,"Other enemy slices do not rebuild this actor's unchanged contacts")
	data.pos+=Vector3(0,0,1);data.simulation_revision+=1;actor._physics_process(1.0/60)
	check(actor.preparations==sliced_previous+1 and actor.position==data.pos,"An actor's own slice revision refreshes its pose immediately")
	sliced_previous=actor.preparations
	game.model.waves.tick_enemy(data,1.0/60,game.player.position);game.model_tick_serial+=1;actor._physics_process(1.0/60)
	check(actor.preparations==sliced_previous+1 and actor.position==data.pos,"A legacy direct enemy tick refreshes a previously sliced actor")
	game.model.tick(1.0/60,game.player.position);game.model_tick_serial+=1;actor._physics_process(1.0/60)
	check(not data.has("simulation_revision"),"A real synchronous world step restores the legacy snapshot mode")
	sliced_previous=actor.preparations;game.model_tick_serial+=1;actor._physics_process(1.0/60)
	check(actor.preparations==sliced_previous+1,"Returning to synchronous mode restores global revision invalidation")
	var previous=actor.preparations
	actor.take_hit(10,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false});actor._physics_process(1.0/60)
	check(actor.preparations==previous+1 and data.hp==9990,"Direct hit invalidates the snapshot without changing damage")
	previous=actor.preparations;actor.freeze_for(2);actor._physics_process(1.0/60)
	check(actor.preparations==previous+1 and actor.frozen_left==2,"Freeze invalidates even without a model tick")
	for operation in [func():actor.combat_knockback(Vector3.RIGHT,2,.1),func():actor.apply_rogue_bash(Vector3.RIGHT),func():actor.apply_defense_slow(.5,1)]:
		previous=actor.preparations;operation.call();actor._physics_process(1.0/60)
		check(actor.preparations==previous+1,"Local combat mutation refreshes its fitted snapshot")
	previous=actor.preparations;game.crowd.low_fidelity=false;actor._physics_process(1.0/60)
	check(actor.preparations==previous+1 and not actor.fitted_block_contacts,"Renderer mode changes refresh physical geometry")
	game.crowd.low_fidelity=true;actor._physics_process(1.0/60)
	previous=actor.preparations;actor._sync_fitted_pose()
	check(actor.preparations==previous+1,"Explicit manual pose synchronization always refreshes")
	previous=actor.preparations;game.explorer_helpers.activate_taunt(game.explorer_helpers.pool[0]);actor._physics_process(1.0/60)
	check(actor.preparations==previous+1,"Immediate taunt cancellation refreshes poses between model ticks")
	data.hp-=7;previous=actor.hp;actor._physics_process(1.0/60)
	check(actor.hp==previous-7,"Authoritative HP events synchronize even between simulation ticks")
	var boss_data=game.model.waves.spawn_enemy(4,Vector3(0,0,140))
	var boss=CountedRaider.new();boss.game=game;boss.forest_id=boss_data.id;boss.variant=4;boss.position=boss_data.pos;game.add_child(boss);boss.set_physics_process(false)
	previous=boss.preparations;boss._physics_process(1.0/60)
	check(boss.preparations==previous and boss.bar.visible and boss.boss_health_text.visible,"Unchanged boss snapshot keeps its health display live")
	boss_data.hp-=100;boss._physics_process(1.0/60)
	check(boss.hp==boss_data.hp and boss.boss_health_text.text.contains(str(ceili(boss.hp))),"Boss bar reflects model damage without an extra simulation tick")
	actor.dead=true;actor.death_timer=.02;actor._physics_process(.03)
	check(actor.is_queued_for_deletion(),"Death cleanup remains independent of simulation revisions")
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	for i in range(3):await process_frame
	await create_timer(.2).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	finish()
func finish():
	print("RAIDER_SNAPSHOT_REVISION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

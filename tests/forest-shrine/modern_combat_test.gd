extends SceneTree
var game
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func frames(n: int=3):
	for i in range(n):await physics_frame
func press(action: String,down: bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down;Input.parse_input_event(event);Input.flush_buffered_events()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game;await frames()
	game.start_wave();game.model.waves.spawn_clock=10000;game.player.position=Vector3(0,.1,70);game.tuning.invincible=true
	game.camera_rig.set_process(false);var camera=game.camera_rig.camera
	camera.global_position=game.player.position+Vector3(.65,2.4,10);camera.look_at(game.player.position+Vector3(0,1.1,-6))
	game.model.waves.spawn_one();var data=game.model.enemies.values()[0];data.pos=game.player.position+Vector3(0,0,-6);data.hp=10000;data.max_hp=10000;data.stun=100
	game.sync_enemies();await frames();game.model.update_vision(game.player.position)
	var actor=game.actors[data.id]
	game.player.set_auto_attack(true)
	check(game.player.auto_attack_enabled and game.player.auto_aim_target()==actor,"J auto-lock keeps the latest camera-visible targeting in Forest")
	game.model.visible_cells.clear()
	check(game.player.auto_aim_target()==null,"Cached auto-lock releases immediately when shared vision is lost")
	game.player.set_auto_attack(false)
	game.player.select_character(2)
	var targets=EdoMeteorRain.choose_targets(game.player,1,100)
	check(targets[0].distance_to(actor.position)>1,"Edo meteors cannot select a hidden enemy group")
	var before=game.get_tree().get_nodes_in_group("edo_explosions").size()
	EdoFireExplosion.emit(game,actor.position)
	check(game.get_tree().get_nodes_in_group("edo_explosions").size()==before,"An impact outside shared vision does not reveal a hidden enemy with fire effects")
	game.model.update_vision(game.player.position)
	game.player.musashi.activate_shield();press("light_attack");await frames(30);press("light_attack",false)
	check(data.hp<10000,"Updated Edo beam damages real Forest enemies")
	game.player.musashi.cancel()
	game.player.select_character(4);var ability=game.player.active_ability;ability.reset_run()
	var seen_ink=false
	for stage in range(5):
		ability.player.cooldowns.cutlass=0;press("light_attack");press("light_attack",false)
		check(ability.player.attack!=null and ability.player.attack.index==stage,"Latest Samurai combo retains cut %d"%(stage+1))
		for i in range(65):
			await frames(1)
			seen_ink=seen_ink or ability.fx.items.any(func(item):return item.kind=="magic-brush")
			if ability.player.attack==null:break
	check(seen_ink,"Samurai swings retain the authored blade-following ink trail")
	game.player.select_character(10);ability=game.player.active_ability;ability.reset_run()
	camera.look_at(game.player.position+Vector3(0,10,-40))
	ability._update_aim();ability.Actions.fire_ranger_fan(ability,ability.player.angle,true,"flintlock",ability.ranger_ground_target(ability.player.angle))
	check(ability.projectiles.size()==5 and ability.projectiles.all(func(pr):return pr.aimDirection.y>0 and pr.rangerFlight.get("curved",false)),"Ranger keeps the five-arrow spread, upward crosshair aim and curved flight")
	game.model.visible_cells.clear()
	check(ability._nearby_targets(actor.position,100).is_empty(),"Elemental chains do not select hidden neighbors")
	check(ability._segment_targets(actor.position+Vector3(-4,1.1,0),actor.position+Vector3(4,1.1,0),.5).is_empty(),"Projectile contact queries do not reveal hidden enemies")
	game.model.update_vision(game.player.position);game.player.select_character(1)
	game.slash(game.player.position+Vector3.UP,Vector3.FORWARD,false,0)
	check(is_instance_valid(game.native_ink_feedback) and not game.native_ink_feedback.fx.items.is_empty(),"Goemon keeps the newer native ink attacks in Forest")
	await frames(60)
	check(game.native_ink_feedback.fx.items.is_empty(),"Native ink effects expire through the Forest gameplay clock")
	game.show_pause();game.queue_free();paused=false;await frames();await create_timer(.35).timeout
	print("FOREST_MODERN_COMBAT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

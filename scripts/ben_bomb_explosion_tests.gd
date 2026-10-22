extends "res://scripts/recovered_leader_projectile_tests.gd"
## Damage, visible blast and its sole boom coincide after the one-second fuse.
func run():
	projectile_script=load("res://scripts/recovered_leader_projectile.gd")
	arena=Arena.new();root.add_child(arena)
	caster=Hero.new();caster.character_id=15;arena.player=caster
	var victim=target(Vector3(1,3,0))
	var p=shot(Vector3(0,3,0),Vector3.ZERO,true)
	p._explode(p.global_position)
	check(not p.is_queued_for_deletion(),"Bomb detonation retains its visible original terminal animation")
	check(victim.hp==72,"Detonation applies damage exactly once")
	var body=p.find_child("SourceBombSprite",true,false) as Sprite3D
	check(body!=null and not body.is_visible_in_tree(),"Bomb body disappears immediately when explosion damage lands")
	check(p.bomb_effect.terminal_started,"Terminal explosion starts with damage without another warning delay")
	arena.paused=true;p._physics_process(.5)
	check(p.bomb_effect.age==1.0 and not arena.sounds.has(["ben_bomb_end",15]),"Pause freezes terminal timing and the end sound")
	arena.paused=false;p._physics_process(.001)
	var clouds=p.find_children("SourceBombExplosion*","Sprite3D",true,false)
	check(clouds.size()==4,"Terminal detonation renders four original explosion sprites")
	check(arena.sounds==[["ben_bomb_explosion",15]],"The full visual blast plays exactly one boom with no preceding or trailing cue")
	if clouds.size()==4:
		check(clouds[0].hframes==10 and clouds[0].frame==0,"Terminal animation begins at recovered source frame0")
		await process_frame;await process_frame
		var vertices: PackedVector3Array=clouds[0].generate_triangle_mesh().get_faces()
		var quad=AABB(vertices[0],Vector3.ZERO)
		for vertex in vertices:quad=quad.expand(vertex)
		check(quad.position.is_equal_approx(Vector3(-1.12,-1.05,0)) and quad.end.is_equal_approx(Vector3(1.05,1.12,0)),"Terminal rendered quad preserves original(-16,-16)..(15,15) anchor and PSX Y conversion")
		p._physics_process(5.0/30.0)
		check(clouds[0].frame==5 and clouds[0].is_visible_in_tree(),"Terminal sprite advances at one original frame per tick")
		check(absf(clouds[0].pixel_size*32-2.17)<.001,"Terminal original31-unit quad uses source scale7 and world mapping")
		p._physics_process(5.0/30.0)
	check(p.is_queued_for_deletion() and victim.hp==72,"Terminal animation completes without repeated explosion damage")
	await process_frame;clear_targets()
	p=shot(Vector3(0,3,0),Vector3.ZERO,true);p._explode(p.global_position);arena.playing=false;p._physics_process(.1)
	check(p.is_queued_for_deletion(),"Wave end clears an ongoing danger animation immediately")
	await process_frame;arena.playing=true
	p=shot(Vector3(0,3,0),Vector3.ZERO,true);p._explode(p.global_position);caster.free();p._physics_process(.1)
	check(p.is_queued_for_deletion(),"Invalid caster clears an ongoing danger animation")
	await process_frame;arena.free()
	print("BEN_BOMB_EXPLOSION_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)

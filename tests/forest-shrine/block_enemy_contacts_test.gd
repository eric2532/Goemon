extends SceneTree
## Every visible low-fidelity member shares the logical enemy's health. Its
## corners, frozen pose and part transforms must also be physical hit regions.
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Crowd=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
var checks=0
var failures=0
var config_path="user://block-contacts-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run():
	var api: Variant=Contact.new()
	check(api.has_method("_box_interval"),"Low-fidelity blocks have exact box segment queries")
	if not api.has_method("_box_interval"):finish();return
	for variant in range(5):
		var detailed=Contact.shapes(variant)
		var blocks: Array=api.shapes(variant,true)
		check(blocks.size()==detailed.size(),"Every rendered part has exactly one block contact")
		for i in range(blocks.size()):
			check(blocks[i].get("box",false) and blocks[i].shape is BoxShape3D,"Block mode uses centered BoxShape3D")
			check(blocks[i].bounds==detailed[i].bounds and blocks[i].group==detailed[i].group,"Block geometry matches the rendered member-zero region")
			check(detailed[i].get("box",false)==(variant in [0,1,3]),"Soldiers retain the original actor OBB in either renderer; oversized geometry remains unchanged")
		for frozen in [false,true]:
			var data={"variant":variant,"pos":Vector3(17,2,-31),"facing":.73,"walk_phase":1.7,"velocity":Vector3(1,0,2),"action":"walk","attack_progress":.9,"attack_point":Vector3(21,3,-38),"block_contacts":true}
			if frozen:
				data.frozen_pose=data.duplicate(true);data.frozen=2.0;data.walk_phase=4.1;data.attack_progress=.1
			var prepared=Contact.prepare(data)
			var expected=AABB();var first=true
			for item in blocks:
				var pose=Transform3D(Basis(Vector3.UP,data.facing),data.pos)*Contact.part_pose(item.group,data)
				var box: AABB=pose*item.bounds
				expected=box if first else expected.merge(box);first=false
				for local in [item.bounds.position,item.bounds.end,item.bounds.get_center()]:
					var point: Vector3=pose*local
					check(Contact.contact(data,point).distance_to(point)<.0001,"Rendered corner/interior is included in live block contact")
					check(Contact.contact(data,point,prepared).distance_to(point)<.0001,"Prepared block contact retains rendered corner/interior")
					check(not Contact.segment_contact(data,point,point,.0001).is_empty(),"Stationary segment includes each posed rendered corner")
				for radius in [0.0,.25,1.35]:
					var bounds: AABB=item.bounds
					var a=Vector3(bounds.position.x-2,bounds.end.y+radius,bounds.get_center().z)
					var b=Vector3(bounds.end.x+2,a.y,a.z)
					var interval: Vector2=api._box_interval(bounds,a,b,radius)
					var want=(2-radius)/(bounds.size.x+4)
					check(absf(interval.x-want)<.00001,"Expanded tangent slab has exact entry time")
					check(api._box_interval(bounds,a+Vector3(0,.001,0),b+Vector3(0,.001,0),radius).x<0,"Outside expanded rendered block misses")
					var live=Contact.segment_contact(data,pose*a,pose*b,radius)
					var cached=Contact.segment_contact(data,pose*a,pose*b,radius,prepared)
					check(live.is_empty()==cached.is_empty() and (live.is_empty() or absf(live.t-cached.t)<.00001),"Live and prepared rotated block sweeps agree")
			check(Contact.bounds(data).is_equal_approx(expected) and Contact.bounds(data,prepared).is_equal_approx(expected),"Rendered compound bounds match both block query modes")
	await actor_checks()
	finish()
func actor_checks():
	var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	for i in range(3):await physics_frame
	game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.set_physics_process(false);game.tuning.critical_chance=0.0
	game.player.select_character(11)
	var combat=game.player.active_ability
	for variant in range(5):
		var data=game.model.waves.spawn_enemy(variant,Vector3(0,0,70+variant*70))
		data.hp=100000.0;data.max_hp=100000.0
		data.facing=.53;data.stun=100.0;data.action="walk";data.walk_phase=1.7;data.attack_progress=0.0
		game.sync_enemies();var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose()
		check(data.get("block_contacts",false) and actor._combat_data().get("block_contacts",false),"Actor and authoritative tower data both select block contacts")
		game.model.visible_cells[game.model.cell_of(data.pos)]=true
		for frame in 2:await physics_frame
		for entry in actor.fitted_shapes:
			var item: Dictionary=entry.item
			var formation:Dictionary=game.crowd._formations.get(data.id,{})
			var root_pose=Transform3D(Basis(Vector3.UP,data.facing),data.pos) if formation.is_empty() else formation.roots[entry.member]
			var part_data:Dictionary=data if formation.is_empty() else formation.parts[entry.member]
			var expected=root_pose*Contact.part_pose(item.group,part_data)*Transform3D(Basis.IDENTITY,item.bounds.get_center())
			check(entry.node.shape is BoxShape3D and entry.node.global_transform.is_equal_approx(expected),"Physical block collider matches rendered part transform")
			var center: Vector3=expected.origin
			var ray=PhysicsRayQueryParameters3D.create(center+Vector3.RIGHT*64,center,4)
			var physical=actor.get_world_3d().direct_space_state.intersect_ray(ray)
			check(physical.get("collider")==actor,"Query-only native enemy bodies remain hittable on layer 4 (%d %s)"%[variant,item.group])
			game.player.global_position=center-Vector3.UP;combat.player.pos=game.player.global_position
			var before: float=data.hp
			Actions.area(combat,center,.05,37,"flintlock",false,Color.WHITE,"slam",1.0)
			check(is_equal_approx(data.hp,before-37),"Native allied ability applies unchanged damage through %d %s region (before=%.0f after=%.0f)"%[variant,item.group,before,data.hp])
		actor.freeze_for(2);actor._physics_process(0)
		check(actor.combat_bounds().is_equal_approx(Contact.bounds(data)),"Frozen model and actor block geometry agree")
		game.crowd.low_fidelity=false;actor._sync_fitted_pose()
		check(not data.block_contacts and actor.fitted_shapes.all(func(entry):return entry.item.get("box",false)==(variant in [0,1,3])),"Mode change retains native soldier OBBs and detailed oversized collision shapes")
		check(actor.combat_bounds().is_equal_approx(Contact.bounds(data)),"Detailed-mode refresh retains exact fitted geometry")
		game.crowd.low_fidelity=true;actor._sync_fitted_pose()
		check(data.block_contacts and actor.fitted_shapes.all(func(entry):return entry.node.shape is BoxShape3D),"Mode change rebuilds block collision shapes")
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	for i in range(3):await process_frame
	await create_timer(.2).timeout
	if FileAccess.file_exists(config_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
func finish():
	print("BLOCK_ENEMY_CONTACTS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

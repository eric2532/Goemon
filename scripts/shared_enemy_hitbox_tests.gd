extends SceneTree
## One figure per actor: rendered parts, native physics and combat agree.
## Health is charged once per enemy, even when several body parts overlap.
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Crowd=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
var game
var checks=0
var failures=0
var config_path="user://shared-enemy-hitboxes-%d.cfg"%OS.get_process_id()
const ORIGIN=Vector3(0,0,90)
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func physics_frames(count:int=2):
	for i in count:await physics_frame
func setup():
	# A clear authored map avoids depending on whatever map was saved last.
	set_meta("forest_custom_layout",{"format":"forest_shrine_map","schema":1,"title":"Shared enemy contacts","buildings":[],"trees":[],"deposits":[],"portals":[],"roads":[],"ramparts":[]})
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	await physics_frames(3)
	game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=100000
	game.set_physics_process(false);game.player.set_physics_process(false);game.crowd.set_process(false);game.camera_rig.set_process(false)
	game.player.select_character(11);game.tuning.critical_chance=0.0
	game.training_dummy.set_physics_process(false);game.training_dummy.hide();game.enemies.erase(game.training_dummy)
	var floor_=StaticBody3D.new();floor_.collision_layer=1;floor_.collision_mask=0
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(470,1,470);collision.shape=box;floor_.add_child(collision)
	game.add_child(floor_);floor_.position=Vector3(0,-.5,0)
	await physics_frames()
func spawn(kind:int)->Dictionary:
	var origin=ORIGIN;origin.y=game.model.surface_height(origin.x,origin.z)
	var data:Dictionary=game.model.waves.spawn_enemy(kind,origin)
	data.hp=100000.0;data.max_hp=100000.0;data.facing=.53;data.stun=100.0;data.walk_phase=1.7;data.velocity=Vector3(1,0,2);data.attack_progress=0.0
	game.model.visible_cells[game.model.cell_of(data.pos)]=true
	game.sync_enemies()
	var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose()
	game.crowd._process(0)
	return {"data":data,"actor":actor}
func displayed_parts(data:Dictionary)->Array:
	# These are the renderer's submitted formation roots and independently
	# animated part dictionaries, not a contact-system formation helper.
	var formation:Dictionary=game.crowd._formations[data.id]
	var result=[]
	for member in range(formation.roots.size()):
		var root_pose:Transform3D=formation.roots[member]
		if root_pose.basis.x.is_zero_approx():continue
		for item in Contact.shapes(int(data.variant),true):
			var pose:Transform3D=root_pose*Crowd.part_pose("body" if item.group=="capsule" else item.group,formation.parts[member])
			result.append({"member":member,"item":item,"pose":pose})
	return result
func fixture_contains(parts:Array,point:Vector3,padding:float=.02)->bool:
	for part in parts:
		if part.item.bounds.grow(padding).has_point(part.pose.affine_inverse()*point):return true
	return false
func native_owner_at(actor,point:Vector3)->bool:
	var sphere=SphereShape3D.new();sphere.radius=.025
	var query=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,point);query.collision_mask=4;query.collide_with_bodies=true;query.collide_with_areas=false
	var results=actor.get_world_3d().direct_space_state.intersect_shape(query,32)
	return results.any(func(hit):return hit.collider==actor)
func geometry_checks(actor,data:Dictionary,parts:Array):
	var rendered_bounds=AABB();var first=true;var members={}
	for part in parts:
		members[part.member]=true
		var item:Dictionary=part.item;var pose:Transform3D=part.pose;var bounds:AABB=item.bounds
		var label="role %d member %d %s"%[data.variant,part.member,item.group]
		var world_box:AABB=pose*bounds;rendered_bounds=world_box if first else rendered_bounds.merge(world_box);first=false
		for fraction in [Vector3.ONE*.1,Vector3.ONE*.5,Vector3.ONE*.9]:
			var point:Vector3=pose*(bounds.position+bounds.size*fraction)
			check(actor.combat_contact_point(point).distance_to(point)<.002,"Actor point contact covers displayed "+label)
			check(not actor.combat_segment_contact(point,point,0.0).is_empty(),"Stationary attack covers displayed "+label)
			check(Contact.contact(data,point).distance_to(point)<.002,"Model point contact covers displayed "+label)
		var center:Vector3=pose*bounds.get_center()
		check(native_owner_at(actor,center),"Layer 4 body-part query belongs to shared actor: "+label)
		var a:Vector3=pose*Vector3(bounds.position.x-1,bounds.get_center().y,bounds.get_center().z)
		var b:Vector3=pose*Vector3(bounds.end.x+1,bounds.get_center().y,bounds.get_center().z)
		check(not actor.combat_segment_contact(a,b,0.0).is_empty(),"Swept attack crosses displayed "+label)
		check(not Contact.segment_contact(data,a,b,0.0).is_empty(),"Model sweep crosses displayed "+label)
	check(members.size()==1,"Each logical enemy displays one body (%d)"%data.variant)
	check(Contact.bounds(data).is_equal_approx(rendered_bounds),"Model bounds match the displayed enemy (%d)"%data.variant)
	check(actor.combat_bounds().is_equal_approx(rendered_bounds),"Actor bounds match the displayed enemy (%d)"%data.variant)
	var air=rendered_bounds.end+Vector3.ONE
	check(actor.combat_segment_contact(air,air,0).is_empty(),"Air outside the enemy remains a miss (%d)"%data.variant)
	check(not native_owner_at(actor,air),"Air outside the enemy has no native collision (%d)"%data.variant)
func formation_motion_checks(actor,data:Dictionary):
	var original=displayed_parts(data)
	data.pos+=Vector3(-70,0,-20);data.facing=1.35;data.walk_phase=3.4;data.velocity=Vector3(-2,0,1)
	actor.global_position=data.pos;game.model.visible_cells[game.model.cell_of(data.pos)]=true
	actor._sync_fitted_pose();game.crowd._process(.35)
	await physics_frames()
	var moved=displayed_parts(data)
	geometry_checks(actor,data,moved)
	var old_misses=0
	for part in original:
		var old_point:Vector3=part.pose*part.item.bounds.get_center()
		if fixture_contains(moved,old_point,.1):continue
		old_misses+=1
		check(actor.combat_segment_contact(old_point,old_point,0.0).is_empty() and Contact.segment_contact(data,old_point,old_point,0.0).is_empty(),"Moving the rendered formation removes old member targets (%d/%d)"%[data.variant,part.member])
		check(not native_owner_at(actor,old_point),"Moving the formation removes old native body targets (%d/%d)"%[data.variant,part.member])
	check(old_misses>0,"Moved role %d fixture contains verifiable old contact sites"%data.variant)
	actor.freeze_for(2.0);actor._physics_process(0);game.crowd._process(0)
	var frozen=displayed_parts(data)
	var shift=Vector3(5,0,7)
	data.pos+=shift;actor.global_position=data.pos;data.walk_phase+=2.7;data.attack_progress=.95;data.action="windup";data.velocity=Vector3(4,0,-1)
	game.model.visible_cells[game.model.cell_of(data.pos)]=true;game.crowd._process(.5)
	await physics_frames()
	var held=displayed_parts(data)
	check(held.size()==frozen.size(),"Freeze keeps every displayed component (%d)"%data.variant)
	for index in range(mini(held.size(),frozen.size())):
		var before:Transform3D=frozen[index].pose;var after:Transform3D=held[index].pose
		check(after.basis.is_equal_approx(before.basis) and after.origin.is_equal_approx(before.origin+shift),"Frozen member/part preserves its shown pose while its root moves (%d/%d/%s)"%[data.variant,held[index].member,held[index].item.group])
	geometry_checks(actor,data,held)
	data.frozen=0.0;data.erase("frozen_pose");data.attack_progress=0.0;data.action="walk";actor.frozen_left=0.0
	actor._sync_fitted_pose();game.crowd._process(0)
	await physics_frames()
func damage_checks(actor,data:Dictionary,parts:Array):
	var combat=game.player.active_ability
	for part in parts:
		var point:Vector3=part.pose*part.item.bounds.get_center()
		# An offset blast must select the contacted body part even when
		# the attacker stands beside another part of this enemy.
		var leader_point:Vector3=parts[0].pose*parts[0].item.bounds.get_center()
		game.player.global_position=Vector3(leader_point.x,point.y-1.0,leader_point.z);combat.player.pos=game.player.global_position
		var remote_before:float=data.hp
		var remote_count:int=Actions.area(combat,point,.05,37,"flintlock",false,Color.WHITE,"slam",1.0)
		check(remote_count==1 and is_equal_approx(data.hp,remote_before-37),"Offset area selects its contacted member while attacker stands at leader (%d/%d/%s)"%[data.variant,part.member,part.item.group])
		game.player.global_position=point-Vector3.UP;combat.player.pos=game.player.global_position
		var before:float=data.hp
		var count:int=Actions.area(combat,point,.05,37,"flintlock",false,Color.WHITE,"slam",1.0)
		check(count==1 and is_equal_approx(data.hp,before-37),"One real area hit on role %d member %d %s removes 37 HP once"%[data.variant,part.member,part.item.group])
		check(is_equal_approx(actor.hp,data.hp),"Actor and model retain the same HP after member contact (%d/%d)"%[data.variant,part.member])
	var origin:Vector3=parts[0].pose*parts[0].item.bounds.get_center()
	game.player.global_position=origin-Vector3.UP;combat.player.pos=game.player.global_position
	var before:float=data.hp
	var count:int=Actions.area(combat,origin,200,37,"flintlock",false,Color.WHITE,"slam",1.0)
	check(count==1 and is_equal_approx(data.hp,before-37),"One area overlapping all body parts damages one logical enemy once (%d)"%data.variant)
	check(game.actors.size()==1 and game.model.enemies.size()==1 and game.enemies.size()==1,"One displayed enemy owns one actor and HP pool (%d)"%data.variant)
func original_coin(from:Vector3,to:Vector3):
	var ticket={"chain_enabled":false,"critical_chance":0.0,"move_audio":{"character_id":1,"move_key":"coin","voiced":true}}
	var coin=game.spawn_gold_coin(from,(to-from).normalized(),false,false,1.0,false,0.0,ticket)
	coin.set_physics_process(false);coin.damage=13.0;coin.hit_radius=.03;coin.piercing=true;coin.velocity=(to-from)*100
	return coin
func projectile_checks(actor,data:Dictionary,parts:Array):
	# A real Goemon coin descends through each member. Repeating its contact
	# cannot debit a second HP pool or count a second component of that member.
	var tested={}
	for part in parts:
		if tested.has(part.member):continue
		tested[part.member]=true
		var point:Vector3=part.pose*part.item.bounds.get_center()
		var world_box:AABB=part.pose*part.item.bounds
		var from=Vector3(point.x,world_box.end.y+3,point.z)
		var coin=original_coin(from,point);var before:float=data.hp
		coin._physics_process(.01);coin.velocity=Vector3.ZERO;coin._physics_process(.01)
		check(coin.get_meta("original_goemon_coin",false) and is_equal_approx(data.hp,before-13) and coin.hit_enemies.size()==1,"Native Goemon coin hits role %d member %d once through repeated contact"%[data.variant,part.member])
		check(is_equal_approx(actor.hp,data.hp),"Native projectile updates the same HP (%d/%d)"%[data.variant,part.member])
		coin.queue_free()
	if int(data.variant)!=0:return
	var target_part:Dictionary=parts[0]
	var point:Vector3=target_part.pose*target_part.item.bounds.get_center()
	var world_box:AABB=target_part.pose*target_part.item.bounds
	var from=Vector3(point.x,world_box.end.y+6,point.z)
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(3,.2,3);collision.shape=box;wall.add_child(collision)
	game.add_child(wall);wall.global_position=Vector3(point.x,world_box.end.y+3,point.z)
	await physics_frames()
	var coin=original_coin(from,point);var before:float=data.hp;coin._physics_process(.01)
	check(is_equal_approx(data.hp,before) and coin.hit_enemies.is_empty(),"A real scenery wall blocks a Goemon coin before a visible enemy")
	check(coin.is_queued_for_deletion(),"A coin stopped by scenery keeps its existing wall-stop behavior")
	wall.queue_free();coin.queue_free();await physics_frames()
func native_pipe_tip()->Vector3:
	# Reconstruct the frame-four weapon tip directly from the recovered ROM
	# motion, independently of the runtime sweep/contact implementation.
	var motion:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_goemon/motion.json"))
	var clip:Dictionary=motion.clips[motion.actions[str(0x68)]]
	var v:Array=clip.frames[4][clip.pointers.find("0x9002518")]
	var native=Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
	var model=game.player.model
	return model.rig_visual.global_transform*((native.basis*Vector3(23,-3,78)*(model.pipe_visual_scale/HeroModel.WeaponProportions.SCALE)+native.origin)*model.source_scale+model.source_offset)
func pipe_pose_at(point:Vector3):
	var p=game.player
	p.attack_left=0.0;p.struck_targets.clear();p.select_weapon(1)
	p.position=point;p.facing=Vector3.FORWARD;p.model.rotation.y=0
	p.start_attack(false,1);p.melee_assist.reset()
	p.attack_left=p.attack_duration-4.0/18.0;p.model.pipe_visual_scale=1.15
	p.model.animate(0,0,true,0,p.attack_left/p.attack_duration,false,1,false);p.model.sync_skeleton()
	p.position+=point-native_pipe_tip()
func native_pipe_checks(actor,data:Dictionary,parts:Array):
	if int(data.variant)!=0:return
	var p=game.player;p.select_character(1)
	var tested={}
	for part in parts:
		if tested.has(part.member):continue
		tested[part.member]=true
		var point:Vector3=part.pose*part.item.bounds.get_center()
		pipe_pose_at(point);await physics_frames()
		var before:float=data.hp;p.strike();p.strike()
		check(is_equal_approx(data.hp,before-66.0),"The actual expanded Gold Pipe tip hits member %d for 66 HP once"%part.member)
		check(is_equal_approx(actor.hp,data.hp),"Native pipe damage keeps one HP pool (%d)"%part.member)
	var target_part:Dictionary=parts[0]
	var point:Vector3=target_part.pose*target_part.item.bounds.get_center()
	pipe_pose_at(point)
	var origin=p.global_position+Vector3.UP*1.1
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(20,20,.12);collision.shape=box;wall.add_child(collision);game.add_child(wall)
	wall.global_position=origin.lerp(point,.5);wall.look_at(point)
	await physics_frames();var before:float=data.hp;p.strike()
	check(is_equal_approx(data.hp,before),"Solid cover blocks the actual Gold Pipe before a visible enemy")
	wall.queue_free();await physics_frames();p.select_character(11)
func remove_enemy(actor,data:Dictionary):
	game.enemies.erase(actor);game.actors.erase(data.id);game.model.enemies.erase(data.id);actor.queue_free()
	await physics_frames()
	game.crowd._process(0)
func run():
	await setup()
	for kind in range(5):
		var fixture=spawn(kind);var actor=fixture.actor;var data:Dictionary=fixture.data
		await physics_frames()
		check(game.crowd._formations.has(data.id),"Real renderer submits role %d formation"%kind)
		if game.crowd._formations.has(data.id):
			var parts=displayed_parts(data)
			geometry_checks(actor,data,parts)
			await formation_motion_checks(actor,data)
			parts=displayed_parts(data)
			damage_checks(actor,data,parts)
			await projectile_checks(actor,data,parts)
			await native_pipe_checks(actor,data,parts)
		await remove_enemy(actor,data)
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	for i in range(3):await process_frame
	await create_timer(.2).timeout
	if FileAccess.file_exists(config_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("SHARED_ENEMY_HITBOX_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

extends Node3D
## Gameplay owns progress, purchases and arrows; supplied GLBs provide visuals only.

const TOWER_SCENE=preload("res://assets/economy_v1/arrow_tower/exports/tower_build_recoil_reverse.glb")
const WALL_MOUNT_SCENE=preload("res://assets/economy_v1/arrow_tower/exports/tower_wall_mount.glb")
const ARROW_SCENE=preload("res://assets/economy_v1/arrow_tower/exports/arrow_projectile.glb")
const MINE_SCENE=preload("res://assets/economy_v1/gold_mine/goldmine_v1.glb")
const HAMMER_SCENE=preload("res://assets/economy_v1/construction_fx/exports/FS_FX_Hammer_BuildLoop.glb")
const COMPLETION_SCENE=preload("res://assets/economy_v1/construction_fx/exports/FS_FX_CompletionPulse.glb")
const ARROW_RANGE=48.0
const ARROW_SPEED=65.0
const ARROW_DAMAGE=50.0
const SHOT_INTERVAL=.5
const RECOIL_SECONDS=.35
const EPSILON=.000001
var game: Node
var director: Node
var kind="arrow"
var level=1
var ice_effects
var render_batches: Array[MeshInstance3D]=[]
var target: Node3D
var shells: Array=[]
var blasts: Array=[]
var completed=false
var completion_events=0
var shots_fired=0
var progress=0.0
var working=false
var visual_root: Node3D
var progress_root: Node3D
var progress_fill: MeshInstance3D
var progress_label: Label3D
var _selected=false
var _ghost_material: StandardMaterial3D
var _original_materials: Dictionary={}
var _ring_fraction=-1.0
var proximity_prompt: Label3D
var hammer: Node3D
var completion_light: Node3D
var launcher: Node3D
var muzzle: Node3D
var build_socket: Node3D
var income_socket: Node3D
var recoil: Node3D
var embedded_arrow: Node3D
var build_player: AnimationPlayer
var hammer_player: AnimationPlayer
var completion_player: AnimationPlayer
var build_clip: StringName
var build_clip_duration=0.0
var _model_meshes: Array[Node]=[]
var _generation=0
var _shot_clock=0.0
var _work_clock=0.0
var _mine_clock=0.0
var _completion_left=0.0
var _recoil_left=0.0
var _feedback_initialized=false
var _proximity_initialized=false
var _proximity_affordable=false
var _preview_completed=-1

func _ready():
	_generation=int(director.generation) if is_instance_valid(director) else 0
	visual_root=Node3D.new();visual_root.name="VisualAdapter";add_child(visual_root)
	var model=(TOWER_SCENE if kind=="arrow" else MINE_SCENE).instantiate()
	visual_root.add_child(model)
	_bind_imported_visual(model)
	if kind=="arrow" and position.y>2:
		var mount=WALL_MOUNT_SCENE.instantiate();mount.name="AuthoredWallMount";visual_root.add_child(mount)
		_model_meshes.append_array(mount.find_children("*","MeshInstance3D",true,false))
	_ghost_material=StandardMaterial3D.new()
	_ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color=Color(.42,.82,.72,.3)
	_ghost_material.roughness=.8
	for mesh in _model_meshes:
		_original_materials[mesh.get_instance_id()]={"material":mesh.material_override,"shadow":mesh.cast_shadow}
	# Four low stones mark the footprint without a bright purchasing platform.
	for x in [-1,1]:
		for z in [-1,1]:
			Geo.box(self,Vector3(x*(2.0 if kind=="mine" else 1.2),-.07 if kind=="arrow" else .035,z*(2.0 if kind=="mine" else 1.2)),Vector3(.22,.05,.22),Geo.mat("767b65"))
	_build_feedback()
	set_build_progress(progress,working)

func _find_player(model: Node)->AnimationPlayer:
	for node in model.find_children("*","AnimationPlayer",true,false):
		node.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		return node
	return null

func _seek(player: AnimationPlayer,clip: StringName,seconds: float):
	player.play(clip);player.seek(seconds,true);player.pause()

func _bind_imported_visual(model: Node):
	# Keep supplied names and GLB +Y-up/+Z-front: Godot already converted Blender axes.
	launcher=model.find_child("LAUNCHER_YAW",true,false) as Node3D
	muzzle=model.find_child("SOCKET_ARROW_MUZZLE",true,false) as Node3D
	recoil=model.find_child("LAUNCHER_RECOIL",true,false) as Node3D
	embedded_arrow=model.find_child("ARROW_PROJECTILE",true,false) as Node3D
	build_socket=model.find_child("SOCKET_BUILD_FX" if kind=="arrow" else "socket_build_fx",true,false) as Node3D
	income_socket=model.find_child("socket_income_fx",true,false) as Node3D
	build_player=_find_player(model)
	build_clip=&"Tower_Build_Recoil_Reverse" if kind=="arrow" else &"build"
	build_clip_duration=71.0/24.0 if kind=="arrow" else 2.0
	_model_meshes=model.find_children("*","MeshInstance3D",true,false)
	if kind=="mine":build_player.get_animation("work_loop").loop_mode=Animation.LOOP_LINEAR

func _build_feedback():
	progress_root=Node3D.new();progress_root.name="ConstructionProgress";add_child(progress_root)
	progress_root.position=to_local(build_socket.global_position)+Vector3.UP*.25
	var backing=MeshInstance3D.new();backing.name="ProgressCircleTrack";backing.mesh=_arc_mesh(1.0)
	backing.material_override=_ring_material(Color("344947"));progress_root.add_child(backing)
	progress_fill=MeshInstance3D.new();progress_fill.name="CounterclockwiseProgressFill"
	progress_fill.material_override=_ring_material(Color("9be6c4"));progress_fill.position.z=.006;progress_root.add_child(progress_fill)
	progress_label=Label3D.new();progress_label.name="BuildPercent";progress_label.font_size=28;progress_label.pixel_size=.012
	progress_label.position=Vector3(0,0,.025);progress_label.outline_size=6;progress_label.modulate=Color("e2f6e8");progress_root.add_child(progress_label)
	var label=Label3D.new();label.name="BuildPrice";label.text="%d GOLD" % (10 if kind=="mine" else 5)
	label.position.y=-.87;label.font_size=21;label.pixel_size=.012;label.outline_size=5
	label.modulate=Color("ffe1a0");label.visibility_range_end=40;progress_root.add_child(label)
	for mesh in progress_root.find_children("*","GeometryInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end=45
	proximity_prompt=Label3D.new();proximity_prompt.name="BuildProximityPrompt";add_child(proximity_prompt)
	# An empty foundation is low to the ground. Keep its prompt over that
	# foundation instead of the completed tower's much higher FX socket.
	proximity_prompt.position=Vector3(0,1.25 if kind=="arrow" else 1.8,0)
	proximity_prompt.font_size=30;proximity_prompt.pixel_size=.013;proximity_prompt.outline_size=8
	proximity_prompt.outline_modulate=Color("10222a");proximity_prompt.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	proximity_prompt.visibility_range_end=45;proximity_prompt.hide()
	hammer=HAMMER_SCENE.instantiate();hammer.name="WorkingHammer";add_child(hammer)
	hammer.position=to_local(build_socket.global_position)+Vector3(1.1,-.6,0);hammer.scale=Vector3.ONE*.7
	hammer_player=_find_player(hammer);hammer_player.get_animation("Build_HammerLoop").loop_mode=Animation.LOOP_LINEAR
	_seek(hammer_player,&"Build_HammerLoop",0)
	completion_light=COMPLETION_SCENE.instantiate();completion_light.name="PaidCompletionPulse";add_child(completion_light)
	completion_light.position.y=.1;completion_light.scale=Vector3.ONE*(1.55 if kind=="mine" else 1.0)
	completion_player=_find_player(completion_light)
	completion_player.get_animation("Complete_GoldPulse").loop_mode=Animation.LOOP_NONE
	_seek(completion_player,&"Complete_GoldPulse",0);completion_light.hide()

func _sync_mesh_visibility():
	# Authored epsilon-scale hidden parts need not consume a draw call.
	for mesh in _model_meshes:mesh.visible=not mesh.get_meta("render_batched",false) and mesh.global_basis.get_scale().length()>.025

func _ring_material(color: Color)->StandardMaterial3D:
	var material=StandardMaterial3D.new();material.albedo_color=color
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	return material

func _arc_mesh(fraction: float)->ArrayMesh:
	var mesh=ArrayMesh.new()
	if fraction<=0:return mesh
	var vertices=PackedVector3Array();var count=maxi(1,int(ceil(64*fraction)))
	for i in range(count):
		var start=TAU*fraction*i/count;var end=TAU*fraction*(i+1)/count
		# XY faces the camera. Twelve o'clock -> left -> bottom -> right.
		var outer_a=Vector3(-sin(start)*.68,cos(start)*.68,0)
		var inner_a=Vector3(-sin(start)*.52,cos(start)*.52,0)
		var outer_b=Vector3(-sin(end)*.68,cos(end)*.68,0)
		var inner_b=Vector3(-sin(end)*.52,cos(end)*.52,0)
		vertices.append_array(PackedVector3Array([outer_a,inner_a,outer_b,outer_b,inner_a,inner_b]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _sync_preview():
	visual_root.visible=completed or _selected or working
	var preview_state=int(completed)
	if _preview_completed==preview_state:return
	_preview_completed=preview_state
	for mesh in _model_meshes:
		var original: Dictionary=_original_materials[mesh.get_instance_id()]
		mesh.material_override=original.material if completed else _ghost_material
		mesh.cast_shadow=original.shadow if completed else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_build_progress(p: float,valid_work: bool):
	if completed:return
	var next_progress=clampf(p,0,1)
	var next_working=valid_work and next_progress<1
	if _feedback_initialized and is_equal_approx(progress,next_progress) and working==next_working:return
	progress=next_progress;working=next_working
	if not is_instance_valid(visual_root):return
	_feedback_initialized=true
	# Preview the whole finished silhouette while the purchase is still unpaid.
	_seek(build_player,build_clip,build_clip_duration)
	_sync_mesh_visibility();_sync_preview()
	progress_root.visible=(_selected or working) and progress>EPSILON
	if progress_root.visible:proximity_prompt.hide()
	progress_fill.visible=progress>0
	if not is_equal_approx(_ring_fraction,progress):
		progress_fill.mesh=_arc_mesh(progress);_ring_fraction=progress
	progress_label.text="%d%%" % int(round(progress*100))
	hammer.visible=working

func set_proximity(selected: bool,affordable: bool):
	if _proximity_initialized and _selected==selected and _proximity_affordable==affordable:return
	_selected=selected
	if not is_instance_valid(proximity_prompt):return
	_proximity_initialized=true;_proximity_affordable=affordable
	_sync_preview()
	progress_root.visible=selected and not completed and progress>EPSILON
	proximity_prompt.visible=selected and not completed and progress<=EPSILON
	if not proximity_prompt.visible:return
	var label="MINE · 10 GOLD" if kind=="mine" else "ARROW TOWER · 5 GOLD"
	proximity_prompt.text=("STAND NEARBY TO BUILD" if affordable else "NEED GOLD")+"\n"+label
	proximity_prompt.modulate=Color("a3f0ca") if affordable else Color("ffb792")

func complete_build():
	if completed:return
	set_build_progress(1,false)
	completed=true;working=false;completion_events+=1
	_sync_preview()
	if kind=="arrow":render_batches=preload("res://scripts/fire_siege_structure_batch.gd").convert(self)
	progress_root.hide();hammer.hide();proximity_prompt.hide()
	_completion_left=1.0;_seek(completion_player,&"Complete_GoldPulse",0);completion_light.show()

func set_upgrade_proximity(selected: bool,affordable: bool):
	proximity_prompt.visible=selected and completed and level==1
	if not proximity_prompt.visible:return
	proximity_prompt.position.y=2.8
	proximity_prompt.text="F: ICE UPGRADE · 10 GOLD\nSLOW ONLY"+(" · NEED GOLD" if not affordable else "")
	proximity_prompt.modulate=Color("93e9ff") if affordable else Color("ffb792")

func attack_type()->StringName:return &"ice" if level==2 else &"arrow"

func upgrade_to_ice()->bool:
	if not completed or kind!="arrow" or level!=1:return false
	retire_wave_effects();level=2
	ice_effects=preload("res://scripts/ice_tower_effects.gd").new();ice_effects.configure(self)
	return true

func tick(delta: float,powered_delta: float):
	var elapsed=maxf(0,delta)
	_tick_feedback(elapsed)
	if ice_effects!=null:ice_effects.tick(elapsed)
	if not is_instance_valid(director) or not director.active or int(director.generation)!=_generation or director.phase not in ["spawning","clearance"]:
		retire_wave_effects();return
	if not completed or kind!="arrow":return
	var paid=clampf(powered_delta,0,elapsed)
	if paid<=0:
		_tick_arrows(elapsed);return
	# Advance physical flight between firing deadlines; depleted portions still advance arrows.
	# Paid time is shared uniformly through this tick by the economy director.
	var rate=paid/elapsed
	var remaining=elapsed
	while remaining>EPSILON:
		target=_acquire_target()
		if target==null:
			_shot_clock=maxf(0,_shot_clock-remaining*rate);_tick_arrows(remaining);break
		if _shot_clock<=EPSILON:
			_fire_at(target);_shot_clock=1.0 if level==2 else SHOT_INTERVAL
		var step=minf(remaining,_shot_clock/rate)
		_tick_arrows(step);_shot_clock=maxf(0,_shot_clock-step*rate);remaining-=step
	# A deadline at the tick boundary is still due, and must not wait one more frame.
	if _shot_clock<=EPSILON:
		target=_acquire_target()
		if target!=null:_fire_at(target);_shot_clock=1.0 if level==2 else SHOT_INTERVAL

func _tick_feedback(delta: float):
	var camera=get_viewport().get_camera_3d()
	if is_instance_valid(camera):progress_root.global_basis=camera.global_basis
	if working:
		_work_clock=fmod(_work_clock+delta,1.0)
		_seek(hammer_player,&"Build_HammerLoop",_work_clock)
	if _completion_left>0:
		_completion_left=maxf(0,_completion_left-delta)
		_seek(completion_player,&"Complete_GoldPulse",1-_completion_left)
		completion_light.visible=_completion_left>0
	if completed and kind=="mine" and is_instance_valid(director) and director.active and director.generation==_generation and director.phase=="spawning":
		_mine_clock=fmod(_mine_clock+delta,4.0)
		_seek(build_player,&"work_loop",_mine_clock)
		_sync_mesh_visibility()

func _tick_recoil(delta: float):
	if _recoil_left<=0:return
	_recoil_left=maxf(0,_recoil_left-delta)
	if _recoil_left>0:
		var fraction=1-_recoil_left/RECOIL_SECONDS
		_seek(build_player,build_clip,3.25+fraction*(4.041666667-3.25))
		embedded_arrow.hide()
	else:
		_seek(build_player,build_clip,build_clip_duration)
		embedded_arrow.show()

func _eligible(enemy)->bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.dead and director.owns(enemy)

func _acquire_target()->Node3D:
	var chosen: Node3D=null
	var downstream=-INF;var nearest=INF
	for enemy in game.enemies:
		if not _eligible(enemy):continue
		var distance=global_position.distance_squared_to(enemy.global_position)
		if distance>ARROW_RANGE*ARROW_RANGE:continue
		var z: float=enemy.global_position.z
		if z>downstream or (is_equal_approx(z,downstream) and distance<nearest):
			chosen=enemy;downstream=z;nearest=distance
	return chosen

func _fire_at(enemy: Node3D):
	if not _eligible(enemy) or global_position.distance_squared_to(enemy.global_position)>ARROW_RANGE*ARROW_RANGE:return
	var aim=enemy.global_position+Vector3.UP*1.05
	# Authored LAUNCHER_YAW remains a yaw pivot. The independent arrow can pitch toward its target.
	var direction=launcher.to_local(aim)
	launcher.rotation.y+=atan2(direction.x,direction.z)
	var arrow: Node3D
	if level==2:
		arrow=ice_effects.acquire()
		if arrow==null:return
	else:
		arrow=ARROW_SCENE.instantiate() as Node3D
		add_child(arrow);arrow.set_as_top_level(true)
	arrow.global_transform=muzzle.global_transform
	arrow.look_at(aim,Vector3.UP,true)
	shells.append({"node":arrow,"target":weakref(enemy),"generation":_generation,"wave":int(director.wave),"age":0.0})
	shots_fired+=1;_recoil_left=RECOIL_SECONDS
	_seek(build_player,build_clip,3.25);embedded_arrow.hide()

func _tick_arrows(delta: float):
	_tick_recoil(delta)
	for index in range(shells.size()-1,-1,-1):
		var shot: Dictionary=shells[index]
		var enemy=shot.target.get_ref()
		shot.age+=maxf(0,delta)
		if shot.age>3.0 or shot.generation!=director.generation or shot.wave!=director.wave or not _eligible(enemy):
			_remove_arrow(index);continue
		var node: Node3D=shot.node
		var previous=node.global_position
		var aim: Vector3=enemy.global_position+Vector3.UP*1.05
		var destination=previous.move_toward(aim,ARROW_SPEED*delta)
		var ray=PhysicsRayQueryParameters3D.create(previous,destination,1)
		ray.hit_from_inside=true
		var hit=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():_remove_arrow(index);continue
		node.global_position=destination
		if destination.distance_squared_to(aim)<=.0001:
			var direction=(aim-previous).normalized();direction.y=0
			if level==2:
				enemy.apply_defense_slow(.6,2.0);ice_effects.impact(aim)
			else:enemy.take_hit(ARROW_DAMAGE,direction,false,{"tower":true})
			_remove_arrow(index)
		else:
			node.look_at(aim,Vector3.UP,true)

func _remove_arrow(index: int):
	var node=shells[index].node
	if level==2:ice_effects.release(node)
	elif is_instance_valid(node):node.queue_free();node.hide()
	shells.remove_at(index)

func retire_wave_effects():
	for index in range(shells.size()-1,-1,-1):_remove_arrow(index)
	blasts.clear();target=null;_shot_clock=0
	if ice_effects!=null:ice_effects.clear()
	if _recoil_left>0:
		_recoil_left=0;_seek(build_player,build_clip,build_clip_duration);embedded_arrow.show()

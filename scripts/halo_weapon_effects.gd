extends Node3D
## Adapter for the retail effect graph. Gameplay damage remains in Chief combat.
const Data=preload("res://scripts/halo_effect_data.gd")
const Particles=preload("res://scripts/halo_effect_particles.gd")
const Trails=preload("res://scripts/halo_effect_trails.gd")
const LightVolumes=preload("res://scripts/halo_effect_light_volume.gd")
const CameraEffects=preload("res://scripts/halo_effect_camera.gd")
const Math=preload("res://scripts/halo_particle_math.gd")
const Impact=preload("res://scripts/halo_impact_material.gd")
const METRES=3.048
const MAX_PARTICLES=4096
const MAX_JOBS=8192
const KEYS=["rocket_launcher","pistol","shotgun","assault_rifle"]
var game:Node
var hero:Node3D
var camera_override:Camera3D
var render_layer=1
var data=Data.new()
var particles:Node3D
var trails:Node3D
var light_volumes:Node3D
var camera_effects:Node
var native_paths:Dictionary={}
var _jobs:Array[Dictionary]=[]
var _lights:Array[Dictionary]=[]
var _decals:Array[Dictionary]=[]
var _audio:Array[AudioStreamPlayer3D]=[]
var _audio_cursor=0
var _streams:Dictionary={}
var _decal_shader:Shader
var _rockets:Dictionary={}
var _clock=0.0
var _counts:Dictionary={}
var _ejection_generation=0

func configure(owner_game:Node,owner_hero:Node3D,camera:Camera3D=null,layer:int=1):
	game=owner_game;hero=owner_hero;camera_override=camera;render_layer=layer
func _ready():
	particles=Particles.new();add_child(particles);particles.configure(data,camera_override,render_layer)
	particles.particle_collision.connect(_shell_collision)
	trails=Trails.new();add_child(trails);trails.configure(data,particles,camera_override,render_layer)
	light_volumes=LightVolumes.new();add_child(light_volumes);light_volumes.configure(data,particles,camera_override,render_layer)
	camera_effects=CameraEffects.new();add_child(camera_effects);camera_effects.configure(game,hero)
func _process(delta:float):advance(delta)
func live_count()->int:return particles.live_count() if is_instance_valid(particles) else 0
func pending_count()->int:return _jobs.size()
func component_count(kind:String)->int:return int(_counts.get(kind,0))
func _weapon(slot:int)->Dictionary:return data.manifest().weapons[KEYS[clampi(slot-1,0,3)]]
func _basis(direction:Vector3)->Basis:
	var d=direction.normalized()
	if d.is_zero_approx():d=Vector3.FORWARD
	return Basis.looking_at(d,Vector3.RIGHT if absf(d.y)>.98 else Vector3.UP)
func _context(at:Vector3,normal:Vector3=Vector3.UP,scale_:float=1)->Dictionary:
	return {"transform":Transform3D(_basis(normal),at),"scale":scale_,"camera":"world","filter":"all","material":"stone","depth":0}
func fire_world(slot:int,from:Vector3,to:Vector3,contact:Dictionary,tracer:bool):
	var projectile=data.resolve(_weapon(slot).projectile)
	if tracer:
		for attachment in projectile.get("obje_attrs",{}).get("attachments",[]):
			if attachment.type.get("class","")=="contrail":trails.streak(data.resolve(attachment.type),from,to)
	if contact.get("impact",false):
		var context=_context(to,contact.get("normal",Vector3.UP))
		context.material=contact.get("material","stone");_material_impact(projectile,context)
func _material_impact(projectile:Dictionary,context:Dictionary):
	var responses:Array=projectile.get("proj_attrs",{}).get("material_responses",[])
	var index=data.manifest().materials.find(context.material)
	if index<0:index=2
	if index>=responses.size():return
	var response:Dictionary=responses[index]
	_dispatch(response.get("effect",{}),context)
	_dispatch(response.get("detonation_effect",{}),context)
func explosion(at:Vector3,normal:Vector3,material:String,visual_scale:float=1):
	var context=_context(at,normal,visual_scale);context.material=material
	var projectile=data.resolve(_weapon(1).projectile)
	_material_impact(projectile,context)
	_dispatch(projectile.get("proj_attrs",{}).get("detonation",{}).get("effect",{}),context)
func fire_first_person(slot:int,muzzle:Transform3D,ejection:Transform3D,mechanical:bool=true,marker_provider:Callable=Callable()):
	var context=_context(muzzle.origin,-muzzle.basis.z)
	context.transform=muzzle;context.camera="first_person";context.filter="muzzle";context.marker_provider=marker_provider
	context.markers={"primary trigger":muzzle,"primary ejection":ejection,"secondary ejection":ejection}
	_dispatch(_weapon(slot).firing_effect,context)
	var weapon=_weapon(slot)
	for firing in weapon.trigger.get("firing_effects",[]):_dispatch(firing.get("firing_damage",{}),context)
	for attachment in weapon.get("attachments",[]):
		# Flashlight output is independent from the native firing-light output.
		if attachment.type.get("class","")=="light" and str(attachment.type.get("path","")).ends_with("\\muzzle flash"):
			var definition=data.resolve(attachment.type)
			definition=definition.duplicate(true)
			definition.effect_parameters.duration=maxf(.03,float(weapon.trigger.misc.get("illumination_recovery_time",.08)))
			_light(definition,context)
	if mechanical:
		var refs:Array=weapon.get("animation_sound_references",[])
		for event in weapon.get("animation_sound_events",[]):
			if not str(event.get("name","")).to_lower().contains("fire"):continue
			var index=int(event.get("sound",-1))
			if index>=0 and index<refs.size():
				_queue(maxf(0,float(event.get("sound_frame_index",0))/30),"dispatch",{"ref":refs[index].sound,"context":dict_with_filter(context,"mechanical")})
			break
func dict_with_filter(context:Dictionary,filter_:String)->Dictionary:
	var copy=context.duplicate();copy.filter=filter_;return copy
func fire_ejection(slot:int,muzzle:Transform3D,ejection:Transform3D,marker_provider:Callable=Callable()):
	var context=_context(muzzle.origin,-muzzle.basis.z)
	context.transform=muzzle;context.camera="first_person";context.filter="eject";context.generation=_ejection_generation;context.marker_provider=marker_provider
	context.markers={"primary trigger":muzzle,"primary ejection":ejection,"secondary ejection":ejection}
	_dispatch(_weapon(slot).firing_effect,context)
func cancel_ejection():
	_ejection_generation+=1
	for i in range(_jobs.size()-1,-1,-1):
		if _jobs[i].payload.get("context",{}).get("filter","")=="eject":_jobs.remove_at(i)
func _queue(delay:float,kind:String,payload:Dictionary):
	if delay<=.000001:_run_job(kind,payload);return
	if _jobs.size()<MAX_JOBS:_jobs.append({"time":_clock+delay,"kind":kind,"payload":payload})
func _run_job(kind:String,payload:Dictionary):
	var context:Dictionary=payload.get("context",{})
	if context.get("filter","")=="eject" and context.get("generation",-1)!=_ejection_generation:return
	match kind:
		"dispatch":_dispatch(payload.ref,context)
		"particle":_particle(payload.definition,payload.emission,context)
func _dispatch(reference:Dictionary,context:Dictionary):
	var path=str(reference.get("path",""));var cls=str(reference.get("class",""))
	if path.is_empty() or int(context.get("depth",0))>12:return
	var definition=data.resolve(reference)
	if definition.is_empty():return
	native_paths[path]=true;_counts[cls]=int(_counts.get(cls,0))+1
	match cls:
		"effect":_effect(definition,context)
		"particle_system":_system(definition,context)
		"sound":
			if context.get("filter","")!="muzzle":_sound(reference,context.transform.origin)
		"decal":_decal(definition,context)
		"light":_light(definition,context)
		"damage_effect":_camera_effect(definition,context)
func _allowed(item:Dictionary,context:Dictionary)->bool:
	var environment=str(item.get("create_in_env","any_environment"))
	if environment=="water_only":return context.get("material","")=="water"
	if environment=="air_only" and context.get("material","")=="water":return false
	var camera=str(item.get("create_in_camera","either"));var fp=context.get("camera","")=="first_person"
	if camera=="first_person_only" or camera=="first_person_if_possible":return fp
	if camera=="third_person_only":return not fp
	return true
func _location(definition:Dictionary,item:Dictionary,context:Dictionary)->Dictionary:
	var result=context.duplicate()
	result.depth=int(context.get("depth",0))+1
	var locations:Array=definition.get("locations",[]);var index=int(item.get("location",0))
	if index>=0 and index<locations.size():
		var marker=str(locations[index].get("marker_name",""))
		result.marker_name=marker
		if context.get("markers",{}).has(marker):result.transform=context.markers[marker]
		elif marker=="gravity":result.transform=Transform3D(_basis(Vector3.DOWN),context.transform.origin)
	return result
func _effect(definition:Dictionary,context:Dictionary):
	var time=0.0
	for event in definition.get("events",[]):
		time+=Math.sample(event.get("delay_bounds"))
		var duration=Math.sample(event.get("duration_bounds"))
		if randf()>=float(event.get("skip_fraction",0)):
			for part in event.get("parts",[]):
				var eject_sound:bool=part.get("type",{}).get("class","")=="sound" and str(part.get("type",{}).get("path","")).ends_with("\\eject")
				if _allowed(part,context) and (context.get("filter","")!="eject" or eject_sound):
					_queue(time,"dispatch",{"ref":part.type,"context":_location(definition,part,context)})
			for emission in event.get("particles",[]):
				if not _allowed(emission,context):continue
				var native=data.resolve(emission.get("particle_type",{}))
				var solid=str(emission.get("particle_type",{}).get("path","")).contains("\\solid\\")
				if context.get("filter","")=="muzzle" and solid:continue
				if context.get("filter","")=="eject" and not solid:continue
				# Native event counts truncate their sampled real range.
				var count=int(Math.sample(emission.get("created_count")))
				for i in mini(count,512):
					# An emission occurs when int(cumulative_fraction*N) crosses
					# its next integer, including the final particle at event end.
					var fraction=(float(i)+1.0)/maxf(1,count)
					_queue(time+duration*Math.emission_time(str(emission.get("distribution_function","constant")),fraction),"particle",{"definition":native,"emission":emission,"context":_location(definition,emission,context)})
		time+=duration
func _cone(direction:Vector3,angle:float)->Vector3:
	# Effect velocities use a uniform angle about a random 3D axis. The
	# weapon projectile cone uses a different distribution in the retail game.
	return Basis(_random_direction(),randf()*angle)*direction.normalized()
func _random_direction()->Vector3:
	var vertical=randf_range(-1.0,1.0);var azimuth=randf()*TAU
	var horizontal=sqrt(maxf(0,1.0-vertical*vertical))
	return Vector3(cos(azimuth)*horizontal,vertical,sin(azimuth)*horizontal)
func _particle(definition:Dictionary,emission:Dictionary,context:Dictionary):
	if definition.is_empty():return
	var transform:Transform3D=context.transform;var scale_=float(context.get("scale",1))
	var provider:Callable=context.get("marker_provider",Callable())
	if provider.is_valid() and context.has("marker_name"):
		var current=provider.call(str(context.marker_name))
		if current is Transform3D:transform=current
	var direction=transform.basis*Math.native_vector(emission.get("relative_direction_vector",{"x":1}))
	direction=_cone(direction,float(emission.get("velocity_cone_angle",0)))
	var radius=Math.sample(emission.get("radius"),.05)
	var position=transform.origin+transform.basis*Math.native_vector(emission.get("relative_offset",{}))*METRES*scale_
	position+=_random_direction()*Math.sample(emission.get("distribution_radius"))*METRES*scale_
	var opts={"position":position,"velocity":direction*Math.sample(emission.get("velocity"))*METRES*scale_,"direction":direction,"radius_halo":radius,"radius":radius*METRES*scale_,"rotation":randf()*TAU if int(emission.get("flags",0))&2!=0 else 0.0,"rotation_rate":Math.sample(emission.get("angular_velocity")),"tint":Math.random_color(emission.get("tint_lower_bound",{}),emission.get("tint_upper_bound",{}),int(emission.get("flags",0))&8!=0)}
	opts.first_person=context.get("camera","")=="first_person" and context.get("filter","")=="muzzle"
	if int(emission.get("flags",0))&1!=0 and provider.is_valid() and context.has("marker_name"):
		opts.attachment_provider=provider;opts.attachment_marker=str(context.marker_name)
		opts.attachment_local=transform.affine_inverse()*position
		opts.attachment_direction=transform.basis.inverse()*direction
	if is_instance_valid(hero) and hero is CollisionObject3D:opts.exclude=[hero.get_rid()]
	if context.has("attachment_id") and int(emission.get("flags",0))&1!=0:opts.attachment_id=context.attachment_id
	particles.emit_particle(definition,transform,scale_,opts)
func _system(definition:Dictionary,context:Dictionary,continuous:bool=false):
	for type in definition.get("particle_types",[]):
		var count=int(type.get("initial_particle_count",0))
		if continuous:count=1
		var type_context:Dictionary=context.duplicate()
		# Type state timing belongs to the shared emitter, not each particle.
		type_context.type_state_plan=Math.state_plan(type.get("states",[]))
		for i in mini(count,512):_system_particle(definition,type,type_context)
func _system_particle(definition:Dictionary,type:Dictionary,context:Dictionary):
	var plan=Math.state_plan(type.get("particle_states",[]))
	if plan.is_empty():return
	var scale_=float(context.get("scale",1));var transform:Transform3D=context.transform
	var axis=_random_direction();var offset=Vector3.ZERO;var velocity=Vector3.ZERO
	var constants:Array=type.get("physics_constants",[])
	if type.get("particle_creation_physics","")=="explosion" and constants.size()>=3:
		offset=Vector3(axis.x*float(constants[0].k),absf(axis.y)*float(constants[1].k),axis.z*float(constants[0].k))
		velocity=offset*float(constants[2].k)
		# Native rotational explosion sprites roll about the horizontal
		# perpendicular to their launch offset, rather than the launch vector.
		axis=Vector3(offset.z,0,-offset.x).normalized()
	var opts={"bitmap":plan[0].data.get("bitmaps",{}),"position":transform.origin+offset*METRES*scale_,"velocity":velocity*METRES*scale_,"state_plan":plan,"scale":scale_,"physics":definition.get("point_physics",{}),"radius_halo":float(type.get("radius",1)),"direction":axis,"complex_sprite_render_modes":type.get("complex_sprite_render_modes","simple"),"type_flags":int(type.get("flags",0)),"hsv":false,"rotation":randf()*TAU}
	opts.type_state_plan=context.get("type_state_plan",[])
	particles.spawn_sprite(opts)
func _sound(reference:Dictionary,at:Vector3,loop:bool=false)->AudioStreamPlayer3D:
	var path=str(reference.get("path",""));var definition=data.resolve(reference,"sound")
	var files:Array=data.manifest().get("sounds",{}).get(path,{}).get("files",[])
	if files.is_empty() or randf()<float(definition.get("skip_fraction",0)):return null
	var file:Dictionary=files.pick_random();var resource=str(file.path)
	if not _streams.has(resource):_streams[resource]=load(resource)
	var player:AudioStreamPlayer3D
	if loop:
		player=AudioStreamPlayer3D.new();add_child(player)
	else:
		if _audio.size()<32:player=AudioStreamPlayer3D.new();add_child(player);_audio.append(player)
		else:player=_audio[_audio_cursor];_audio_cursor=(_audio_cursor+1)%_audio.size();player.stop()
	player.stream=_streams[resource];player.position=at
	player.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
	player.unit_size=METRES*maxf(1,float(definition.get("minimum_distance",1)))
	player.max_distance=METRES*maxf(40,float(definition.get("maximum_distance",0)))
	player.pitch_scale=maxf(.1,Math.sample(definition.get("random_pitch_bounds"),1))
	var gain=float(definition.get("gain_modifier",1))
	for pitch_range in definition.get("pitch_ranges",[]):
		for permutation in pitch_range.get("permutations",[]):
			if str(permutation.get("name",""))==str(file.get("permutation","")):gain*=float(permutation.get("gain",1))
	player.volume_db=linear_to_db(maxf(.001,gain))
	player.play();return player
func _shell_collision(at:Vector3,normal:Vector3,reference:Dictionary,contact:Dictionary):
	var definition=data.resolve(reference,"material_effects");var effects:Array=definition.get("effects",[])
	if effects.size()<=8:return
	var materials:Array=effects[8].get("materials",[]);var index=data.manifest().materials.find(Impact.resolve(contact))
	if index<0 or index>=materials.size():return
	var item:Dictionary=materials[index];var context=_context(at,normal)
	_dispatch(item.get("effect",{}),context);_dispatch(item.get("sound",{}),context)
func _light(definition:Dictionary,context:Dictionary):
	if _lights.size()>=12:
		_lights[0].node.queue_free();_lights.pop_front()
	var light=OmniLight3D.new();add_child(light);light.position=context.transform.origin;light.layers=render_layer
	light.light_color=Math.color(definition.get("color",{}).get("color_upper_bound",{}));light.light_energy=1.0
	light.omni_range=float(definition.get("shape",{}).get("radius",1))*METRES*float(context.get("scale",1))
	var lifetime=maxf(.03,float(definition.get("effect_parameters",{}).get("duration",.1)))
	_lights.append({"node":light,"start":_clock,"life":lifetime,"function":definition.get("effect_parameters",{}).get("falloff_function","linear")})
func _decal(definition:Dictionary,context:Dictionary):
	# Surface-aligned native bitmap, with original multiplication blend.
	var bitmap=definition.get("shader",{}).get("shader_map",{})
	var sequences:Array=data.resolve(bitmap).get("sequences",[])
	var frame=data.bitmap_frame(bitmap,randi_range(0,maxi(0,sequences.size()-1)))
	if frame.is_empty():return
	if _decals.size()>=96:_decals[0].node.queue_free();_decals.pop_front()
	var node=MeshInstance3D.new();var mesh=QuadMesh.new();var radius=Math.sample(definition.get("radius"),.1)*METRES*float(context.get("scale",1))
	mesh.size=Vector2.ONE*radius*2;node.mesh=mesh;node.layers=render_layer
	if _decal_shader==null:
		_decal_shader=Shader.new();_decal_shader.code="shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_never,blend_mul; uniform sampler2D atlas; uniform vec4 rect; uniform float fade=1.; uniform float gain=2.; void fragment(){vec4 p=texture(atlas,rect.xy+UV*rect.zw); ALBEDO=mix(vec3(1.),p.rgb*gain,fade); ALPHA=1.;}"
	var material=ShaderMaterial.new();material.shader=_decal_shader;material.set_shader_parameter("atlas",frame.texture);material.set_shader_parameter("rect",Vector4(frame.rect.position.x,frame.rect.position.y,frame.rect.size.x,frame.rect.size.y));node.material_override=material
	material.set_shader_parameter("gain",2.0 if definition.get("shader",{}).get("framebuffer_blend_function","")=="double_multiply" else 1.0)
	var basis:Basis=context.transform.basis
	if int(definition.get("flags",0))&8==0:basis=basis*Basis(Vector3.BACK,randf()*TAU)
	add_child(node);node.transform=Transform3D(basis,context.transform.origin-context.transform.basis.z*.012)
	var animation:Dictionary=definition.get("animation",{})
	_decals.append({"node":node,"material":material,"start":_clock,"life":Math.sample(animation.get("lifetime"),30),"decay":Math.sample(animation.get("decay_time"),1)})
	_dispatch(definition.get("next_decal_in_chain",{}),context)
func _camera_effect(definition:Dictionary,context:Dictionary):
	if not is_instance_valid(camera_effects):return
	var native=definition.duplicate()
	native._local=context.get("camera","")=="first_person"
	var presentation:Node=camera_effects
	# Viewport muzzle effects share the world player's camera channels. One
	# compositor owns the pose, so cancellation cannot restore another offset.
	if native._local and is_instance_valid(hero):
		var combat=hero.get("master_chief_combat")
		var world_fx=combat.get("native_fx") if is_instance_valid(combat) else null
		var shared=world_fx.get("camera_effects") if is_instance_valid(world_fx) else null
		if is_instance_valid(shared) and shared!=camera_effects:
			camera_effects.clear();presentation=shared
	presentation.emit(native,context.transform.origin,float(context.get("scale",1)))
func rocket_start(id:int,at:Vector3,direction:Vector3):
	rocket_stop(id)
	var projectile=data.resolve(_weapon(1).projectile);var attachments:Array=projectile.get("obje_attrs",{}).get("attachments",[])
	var item={"at":at,"direction":direction,"accumulator":0.0,"flash":0.0,"systems":[],"effects":[],"audio":null}
	for attachment in attachments:
		var reference:Dictionary=attachment.type;var definition=data.resolve(reference)
		match str(reference.get("class","")):
			"contrail":trails.start(id,definition,at,direction)
			"particle_system":item.systems.append(definition)
			"effect":item.effects.append(reference)
			"sound_looping":
				for track in definition.get("tracks",[]):
					item.audio=_sound(track.get("loop",{}),at,true);break
	_rockets[id]=item
	for widget in projectile.get("obje_attrs",{}).get("widgets",[]):
		var reference:Dictionary=widget.get("reference",{})
		if reference.get("class","")=="light_volume":
			light_volumes.start(id,data.resolve(reference),at,direction)
			native_paths[str(reference.path)]=true
	for reference in item.effects:
		var context=_context(at,-direction);context.attachment_id=id;_dispatch(reference,context)
func rocket_move(id:int,at:Vector3,direction:Vector3,delta:float):
	if not _rockets.has(id):return
	var item:Dictionary=_rockets[id];var previous:Vector3=item.at
	particles.shift_attachment(id,at-previous)
	light_volumes.move(id,at,direction)
	trails.move(id,at,direction,delta);item.accumulator+=delta;item.flash+=delta
	while item.accumulator>=1.0/30:
		item.accumulator-=1.0/30
		var context=_context(previous.lerp(at,1-item.accumulator/maxf(delta,.001)),-direction)
		for definition in item.systems:_system(definition,context,true)
	if item.flash>=.075:
		item.flash=fmod(item.flash,.075)
		for reference in item.effects:
			var context=_context(at,-direction);context.attachment_id=id;_dispatch(reference,context)
	if is_instance_valid(item.audio):
		item.audio.position=at
		if not item.audio.playing:item.audio.play()
	item.at=at;item.direction=direction
func rocket_stop(id:int):
	if is_instance_valid(light_volumes):light_volumes.stop(id)
	if is_instance_valid(particles):particles.clear_attachment(id)
	if is_instance_valid(trails):trails.stop(id)
	if _rockets.has(id):
		if is_instance_valid(_rockets[id].audio):_rockets[id].audio.queue_free()
		_rockets.erase(id)
func advance(delta:float):
	if not is_instance_valid(particles):return
	light_volumes.tick(delta)
	var target_time:float=_clock+maxf(0,delta)
	# Run nested graph events in time order. Integrating between births avoids
	# giving a particle created at frame end an entire frame of extra age.
	while not _jobs.is_empty():
		var next:int=-1
		var next_time:float=INF
		for i:int in _jobs.size():
			if float(_jobs[i].time)<next_time:next=i;next_time=float(_jobs[i].time)
		if next_time>target_time:break
		var job:Dictionary=_jobs[next];_jobs.remove_at(next)
		var elapsed:float=maxf(0,next_time-_clock)
		# Birth times require simulation substeps, but only the final state is
		# visible. Rebuilding every old casing/ribbon at each birth multiplies
		# CPU work as long-lived effects accumulate.
		if elapsed>0:particles.tick(elapsed,false);trails.tick(elapsed,false)
		_clock=maxf(_clock,next_time)
		_run_job(job.kind,job.payload)
	var remaining:float=maxf(0,target_time-_clock)
	_clock=target_time
	particles.tick(remaining);trails.tick(remaining)
	if is_instance_valid(camera_effects):camera_effects.tick(delta)
	for i in range(_lights.size()-1,-1,-1):
		var item=_lights[i];var t=(_clock-item.start)/item.life
		if t>=1:item.node.queue_free();_lights.remove_at(i)
		else:item.node.light_energy=1.0*(1-Math.blend_ease(item.function,t))
	for i in range(_decals.size()-1,-1,-1):
		var item=_decals[i];var age=_clock-item.start
		if age>=item.life+item.decay:item.node.queue_free();_decals.remove_at(i)
		else:item.material.set_shader_parameter("fade",1-clampf((age-item.life)/maxf(.001,item.decay),0,1))
func clear():
	_jobs.clear();_ejection_generation+=1
	if is_instance_valid(particles):particles.clear()
	if is_instance_valid(trails):trails.clear()
	if is_instance_valid(light_volumes):light_volumes.clear()
	if is_instance_valid(camera_effects):camera_effects.clear()
	for id in _rockets.keys():rocket_stop(id)
	for item in _lights:item.node.queue_free()
	for item in _decals:item.node.queue_free()
	_lights.clear();_decals.clear()
	for player in _audio:player.stop()

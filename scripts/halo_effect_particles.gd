extends Node3D
## Bounded native sprite particles. One MultiMesh per original atlas/blend pair.
## The scheduler owns tick(); this node does not advance itself independently.
const Data=preload("res://scripts/halo_effect_data.gd")
const Math=preload("res://scripts/halo_particle_math.gd")
const MAX_PARTICLES=4096
const METRES=3.048
const NO_STATE:Dictionary={}
signal particle_collision(at:Vector3,normal:Vector3,material_effects:Dictionary,contact:Dictionary)
var data:RefCounted
var camera_override:Camera3D
var layer:int=1
var _particles:Array[Dictionary]=[]
var _batches:Dictionary={}
var _materials:Dictionary={}
var _next_id:int=1
var _data_revision:int=-1
var _view_camera:Camera3D
var _view_basis:Basis=Basis.IDENTITY
var _view_inverse:Basis=Basis.IDENTITY
var _view_frustum:Array=[]

func configure(source:Variant={},camera:Camera3D=null,render_layer:int=1):
	data=Data.new(source) if source is Dictionary else source
	if data==null:data=Data.new()
	camera_override=camera
	layer=render_layer
	for batch:Dictionary in _batches.values():batch.node.layers=layer
	_refresh_sequences()

func _refresh_sequences():
	for p:Dictionary in _particles:
		if p.has("_sprite_frames"):
			p._sprite_frames=data.bitmap_sequence(p.get("bitmap",{}),p.sequence)
			_cache_simple_bound(p)
	_data_revision=data.revision

func live_count()->int:return _particles.size()

func _attachment_matches(particle:Dictionary,id:Variant)->bool:
	var key:Variant=particle.get("attachment_id",null)
	return typeof(key)==typeof(id) and key==id

func shift_attachment(id:Variant,offset:Vector3):
	for particle:Dictionary in _particles:
		if _attachment_matches(particle,id):particle.position+=offset

func clear_attachment(id:Variant):
	for index:int in range(_particles.size()-1,-1,-1):
		if _attachment_matches(_particles[index],id):_particles.remove_at(index)

func update_attachment(id:Variant,updates:Array[Dictionary])->int:
	var updated:int=0
	for particle:Dictionary in _particles:
		if not _attachment_matches(particle,id):continue
		if updated>=updates.size():break
		particle.merge(updates[updated],true)
		_cache_simple_bound(particle)
		particle.age=0.0
		if updates[updated].has("radius_halo"):particle.base_radius_halo=particle.radius_halo
		updated+=1
	return updated

func clear():
	_particles.clear()
	for batch:Dictionary in _batches.values():
		batch.mesh.visible_instance_count=0
		batch["instances"]=[]

func emit_particle(definition:Dictionary,at:Transform3D,scale_:float=1.0,options:Dictionary={})->int:
	if data==null:configure()
	var native:Dictionary=definition.get("data",definition)
	var rendering:Dictionary=native.get("rendering",{})
	var opts:Dictionary=options.duplicate()
	opts["definition"]=native
	opts["bitmap"]=native.get("bitmap",{})
	opts["position"]=options.get("position",at.origin)
	opts["basis"]=at.basis.orthonormalized()
	opts["scale"]=scale_
	opts["lifetime"]=options.get("lifetime",Math.sample(native.get("lifespan"),1.0))
	opts["fade_in"]=float(native.get("fade_in_time",0.0))
	opts["fade_out"]=float(native.get("fade_out_time",0.0))
	opts["physics"]=native.get("physics",{})
	opts["orientation"]=rendering.get("orientation","screen_facing")
	opts["blend"]=rendering.get("framebuffer_blend_function","alpha_blend")
	opts["shader_flags"]=int(rendering.get("shader_flags",0))
	opts["frame_rate"]=options.get("frame_rate",Math.sample(rendering.get("animation_rate"),0.0))
	opts["radius_animation"]=rendering.get("radius_animation",{"from":1.0,"to":1.0})
	if not opts.has("radius"):
		opts["radius"]=float(options.get("radius_halo",.05))*METRES*scale_
	return spawn_sprite(opts)

func spawn_sprite(opts:Dictionary)->int:
	if _particles.size()>=MAX_PARTICLES:return -1
	if data==null:configure()
	var p:Dictionary=opts.duplicate()
	var native:Dictionary=p.get("definition",{})
	var rendering:Dictionary=native.get("rendering",{})
	var flags:int=int(native.get("flags",0))
	p["id"]=_next_id;_next_id+=1
	p["age"]=0.0
	p["lifetime"]=maxf(.001,float(p.get("lifetime",1.0)))
	p["position"]=p.get("position",Vector3.ZERO)
	p["velocity"]=p.get("velocity",Vector3.ZERO)
	p["direction"]=p.get("direction",Vector3.UP)
	p["rotation"]=float(p.get("rotation",0.0))
	p["rotation_rate"]=float(p.get("rotation_rate",0.0))
	p["radius"]=maxf(.00001,float(p.get("radius",.05)))
	p["radius_halo"]=float(p.get("radius_halo",p.radius/METRES))
	p["base_radius_halo"]=p.radius_halo
	p["scale"]=float(p.get("scale",1.0))
	p["tint"]=p.get("tint",p.get("color",Color.WHITE))
	if p.tint is Dictionary:p.tint=Math.color(p.tint)
	p["frame_rate"]=float(p.get("frame_rate",0.0))
	p["frame"]=float(p.get("frame",0.0))
	p["sequence"]=int(p.get("sequence",rendering.get("first_sequence_index",0)))
	p["physics_data"]=data.resolve(p.get("physics",{}),"point_physics")
	p["resting"]=false
	p["flags"]=flags
	p["mirror_u"]=bool(p.get("mirror_u",flags&1024!=0 and randf()<.5))
	p["mirror_v"]=bool(p.get("mirror_v",flags&2048!=0 and randf()<.5))
	p["backwards"]=flags&1!=0 and randf()<.5
	p["stage"]="explicit"
	if not native.is_empty():
		var initial:int=int(rendering.get("initial_sequence_count",0))
		var looping:int=int(rendering.get("looping_sequence_count",0))
		p.stage="initial" if initial>0 else "looping" if looping>0 else "final"
		_choose_sequence(p,p.stage)
		if flags&4!=0:p.frame=randf()*data.sequence_length(p.get("bitmap",{}),p.sequence)
	var plan:Array=p.get("state_plan",[])
	if not plan.is_empty():
		var prepared:Array=[]
		for item:Dictionary in plan:
			var entry:Dictionary=item.duplicate()
			var state:Dictionary=entry.get("data",entry)
			entry["_scale"]=Math.sample(state.get("scale"),1.0)
			entry["_rate"]=Math.sample(state.get("animation_rate"),0.0)
			entry["_rotation_rate"]=Math.sample(state.get("rotation_rate"),0.0)
			entry["_color"]=Math.random_color(state.get("color_1",{}),state.get("color_2",{}),bool(p.get("hsv",false)))
			prepared.append(entry)
		p.state_plan=prepared
		p.lifetime=maxf(.001,float(prepared[-1].get("end",p.lifetime)))
		if not p.has("frame") or is_zero_approx(p.frame):
			var first:Dictionary=prepared[0].get("data",{})
			p.frame=randf()*data.sequence_length(first.get("bitmaps",{}),int(first.get("sequence_index",0)))
	if data.bitmap_frame(p.get("bitmap",{}),p.sequence,p.frame).is_empty() and plan.is_empty():return -1
	var reference:Dictionary=data.bitmap_frame(p.get("bitmap",{}),int(rendering.get("first_sequence_index",p.sequence)),0)
	p["reference_pixels"]=reference.rect.size.x*reference.atlas_size.x if not reference.is_empty() else 1.0
	if plan.is_empty():p["_sprite_frames"]=data.bitmap_sequence(p.get("bitmap",{}),p.sequence)
	_cache_simple_bound(p)
	_particles.append(p)
	return p.id

func _choose_sequence(p:Dictionary,stage:String):
	var r:Dictionary=p.get("definition",{}).get("rendering",{})
	var count:int=int(r.get(stage+"_sequence_count",0))
	var first:int=int(r.get("first_sequence_index",0))
	if stage!="initial":first+=int(r.get("initial_sequence_count",0))
	if stage=="final":first+=int(r.get("looping_sequence_count",0))
	p.sequence=first+randi_range(0,maxi(0,count-1))
	p.frame=0.0
	if p.has("_sprite_frames"):
		p._sprite_frames=data.bitmap_sequence(p.get("bitmap",{}),p.sequence)
		_cache_simple_bound(p)

func _cache_simple_bound(p:Dictionary):
	p.erase("_cull_radius")
	if not p.has("_sprite_frames") or not p.get("state_plan",[]).is_empty():return
	if str(p.get("complex_sprite_render_modes",p.get("complex_sprite_render_mode","")))=="rotational":return
	var extent=0.0
	for sprite:Dictionary in p._sprite_frames:
		if sprite.is_empty():continue
		var size_:Vector2=sprite.rect.size;var registration:Vector2=sprite.registration
		var corner=Vector2(maxf(absf(registration.x),absf(size_.x-registration.x)),maxf(absf(registration.y),absf(size_.y-registration.y)))
		extent=maxf(extent,corner.length()*sprite.atlas_size.x)
	if extent==0.0:return
	if p.has("native_scale"):extent*=absf(float(p.native_scale)*METRES*p.scale)
	else:
		var bounds:Dictionary=p.get("radius_animation",{})
		extent*=2.0*p.radius*maxf(absf(float(bounds.get("from",1))),absf(float(bounds.get("to",1))))/maxf(.00001,p.reference_pixels)
	p["_cull_radius"]=extent+.001

func _advance_simple(p:Dictionary,delta:float)->bool:
	if p.stage=="explicit":
		p.frame+=p.frame_rate*delta
		return p.age<p.lifetime
	var r:Dictionary=p.definition.get("rendering",{})
	if p.age>=p.lifetime and p.stage!="final":
		if int(r.get("final_sequence_count",0))==0:return false
		p.stage="final";_choose_sequence(p,"final")
	if p.resting and p.flags&2!=0:return true
	p.frame+=absf(p.frame_rate)*delta
	var count:int=p._sprite_frames.size() if p.has("_sprite_frames") else data.sequence_length(p.get("bitmap",{}),p.sequence)
	if p.frame>=count:
		var overflow:float=fmod(p.frame,float(count))
		if p.stage=="initial":
			if int(r.get("looping_sequence_count",0))>0:p.stage="looping"
			elif int(r.get("final_sequence_count",0))>0:p.stage="final"
			else:return false
		elif p.stage=="final":return false
		_choose_sequence(p,p.stage);p.frame=overflow
	return true

func _state_at(p:Dictionary)->Dictionary:
	var plan:Array=p.get("state_plan",[])
	for index:int in plan.size():
		var entry:Dictionary=plan[index]
		if p.age<float(entry.get("end",p.lifetime)) or index==plan.size()-1:
			var transition:float=float(entry.get("transition",0))
			var amount:float=clampf((p.age-float(entry.get("start",0))-float(entry.get("hold",0)))/transition,0,1) if transition>0 else 0.0
			return {"a":entry,"b":plan[mini(index+1,plan.size()-1)],"mix":amount}
	return {}

func _type_multipliers(p:Dictionary)->Dictionary:
	var result:Dictionary={"scale":1.0,"color":Color.WHITE,"animation_rate":1.0,"rotation_rate":1.0,"radius":1.0}
	var plan:Array=p.get("type_state_plan",[])
	if plan.is_empty():return result
	var state:Dictionary=_state_at({"state_plan":plan,"age":p.age,"lifetime":p.lifetime})
	var a:Dictionary=state.a.get("data",{})
	var b:Dictionary=state.b.get("data",{})
	for field:String in ["scale","animation_rate","rotation_rate","radius"]:
		result[field]=lerpf(float(a.get(field+"_multiplier",1)),float(b.get(field+"_multiplier",1)),state.mix)
	result.color=Math.color(a.get("color_multiplier",{})).lerp(Math.color(b.get("color_multiplier",{})),state.mix)
	return result

func tick(delta:float,submit:bool=true):
	if data==null:configure()
	if _data_revision!=data.revision:_refresh_sequences()
	var step:float=maxf(0.0,delta)
	var draws:Dictionary={}
	if submit:
		_view_camera=_camera()
		_view_basis=_view_camera.global_basis.orthonormalized() if _view_camera!=null else Basis.IDENTITY
		_view_inverse=_view_camera.global_basis.inverse() if _view_camera!=null else Basis.IDENTITY
		_view_frustum=_view_camera.get_frustum() if _view_camera!=null else []
	for i:int in range(_particles.size()-1,-1,-1):
		var p:Dictionary=_particles[i]
		p.age+=step
		var states:Dictionary=_state_at(p) if p.has("state_plan") else NO_STATE
		if states.is_empty():
			if not _advance_simple(p,step):_particles.remove_at(i);continue
			p.rotation+=p.rotation_rate*step
		else:
			if p.age>=p.lifetime:_particles.remove_at(i);continue
			var a:Dictionary=states.a
			var b:Dictionary=states.b
			var multipliers:Dictionary=_type_multipliers(p)
			p.frame+=lerpf(a._rate,b._rate,states.mix)*multipliers.animation_rate*step
			p.rotation+=lerpf(a._rotation_rate,b._rotation_rate,states.mix)*multipliers.rotation_rate*step
			p["_state_scale"]=lerpf(a._scale,b._scale,states.mix)*multipliers.scale
			p["_state_color"]=a._color.lerp(b._color,states.mix)*multipliers.color
			p.radius_halo=p.base_radius_halo*multipliers.radius
			var state:Dictionary=(b if states.mix>=.5 else a).get("data",{})
			p.physics_data=data.resolve(state.get("physics",p.get("physics",{})),"point_physics")
		if not _move(p,step):_particles.remove_at(i);continue
		if not submit:continue
		if states.is_empty():_draw(p,{},1.0,draws)
		else:
			var old_state:Dictionary=states.a.get("data",{})
			var new_state:Dictionary=states.b.get("data",{})
			var same_shader:bool=old_state.get("framebuffer_blend_function","")==new_state.get("framebuffer_blend_function","") and old_state.get("map_flags",0)==new_state.get("map_flags",0) and old_state.get("sequence_index",0)==new_state.get("sequence_index",0)
			_draw(p,states.a,1.0 if same_shader else 1.0-states.mix,draws)
			if states.mix>0 and not same_shader:_draw(p,states.b,states.mix,draws)
	if submit:_flush(draws)

func _move(p:Dictionary,delta:float)->bool:
	var provider:Callable=p.get("attachment_provider",Callable())
	if provider.is_valid():
		var pose=provider.call(str(p.get("attachment_marker","primary trigger")))
		if pose is Transform3D:
			p.position=pose*p.attachment_local
			p.direction=(pose.basis*p.attachment_direction).normalized()
			return true
	if p.resting or delta<=0:return true
	var old:Vector3=p.position
	var physics:Dictionary=p.physics_data
	var physics_scale:float=maxf(.001,absf(p.scale))
	# Adapted explosions scale all world lengths together, including gravity
	# and drag displacement, while their native point mass radius stays fixed.
	p.velocity=Math.physics_velocity(p.velocity/physics_scale,p.radius_halo,physics,delta)*physics_scale
	var next:Vector3=old+p.velocity*delta
	if int(physics.get("flags",0))&2!=0 and is_inside_tree() and old.distance_squared_to(next)>.00000001:
		var query:PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(old,next,int(p.get("collision_mask",1)))
		query.exclude=p.get("exclude",[])
		var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var normal:Vector3=hit.normal
			p.position=hit.position+normal*maxf(.001,p.radius*.1)
			var ref:Dictionary=p.get("definition",{}).get("impact_effect",p.get("material_effects",{}))
			particle_collision.emit(hit.position,normal,ref,hit)
			if p.flags&32!=0:return false
			var normal_speed:float=p.velocity.dot(normal)
			var tangent:Vector3=p.velocity-normal*normal_speed
			p.velocity=tangent*(1.0-clampf(float(physics.get("surface_friction",0)),0,1))-normal*normal_speed*float(physics.get("elasticity",0))
			if p.velocity.length()<.12:
				p.velocity=Vector3.ZERO;p.resting=true
				if p.flags&16!=0:return false
			return true
	p.position=next
	return true

func _camera()->Camera3D:
	return camera_override if is_instance_valid(camera_override) else get_viewport().get_camera_3d() if is_inside_tree() else null

func _draw(p:Dictionary,entry:Dictionary,weight:float,draws:Dictionary):
	# Simple native particles retain one immutable atlas sequence until their next
	# animation stage. Its cached envelope covers every frame and registration.
	if p.has("_cull_radius") and _outside_frustum(p.position,p._cull_radius):return
	var state:Dictionary=entry.get("data",{})
	var bitmap:Variant=state.get("bitmaps",p.get("bitmap",{}))
	var sequence:int=int(state.get("sequence_index",p.sequence))
	var camera:Camera3D=_view_camera
	if str(p.get("complex_sprite_render_modes",p.get("complex_sprite_render_mode","")))!="rotational" or camera==null:
		_draw_quad(p,entry,weight,draws)
		return
	var view:Vector3=p.position-camera.global_position
	var axis:Vector3=p.direction.normalized()
	var angle:float=acos(clampf(view.normalized().dot(axis),-1,1))-PI*.5
	var fraction:float=clampf(pow(angle/(PI*.5),2),0,1)
	var bitmap_data:Dictionary=data.resolve(bitmap,"bitmap")
	if sequence+1>=bitmap_data.get("sequences",[]).size():fraction=0.0
	if fraction>.05:
		var edge_frame:float=p.frame
		var edge_rotation:float=p.rotation
		var mirror:bool=angle<0.0
		if int(p.get("type_flags",0))&128!=0:
			var count:int=data.sequence_length(bitmap,sequence+1)
			edge_frame=fposmod(count*p.rotation/TAU+.5,float(count))+p.frame
			edge_rotation=0.0;mirror=false
		_draw_quad(p,entry,weight*fraction,draws,sequence+1,edge_frame,edge_rotation,mirror)
	if 1.0-fraction>.05:
		var count:int=data.sequence_length(bitmap,sequence)
		var face_frame:float=fposmod(count*p.rotation/TAU+.5,float(count))
		var camera_axis:Vector3=_view_inverse*axis
		_draw_quad(p,entry,weight*(1.0-fraction),draws,sequence,face_frame,atan2(camera_axis.y,camera_axis.x))

func _draw_quad(p:Dictionary,entry:Dictionary,weight:float,draws:Dictionary,sequence_override:int=-1,frame_override:float=-INF,rotation_override:float=-INF,flip_u:bool=false):
	if weight<=0:return
	var state:Dictionary=entry.get("data",{})
	var bitmap:Variant=state.get("bitmaps",p.get("bitmap",{}))
	var sequence:int=int(state.get("sequence_index",p.sequence))
	var frame:float=p.frame
	if sequence_override>=0:sequence=sequence_override
	if frame_override!=-INF:frame=frame_override
	if p.backwards:frame=-frame-1
	var sprite:Dictionary
	if entry.is_empty() and sequence_override<0 and p.has("_sprite_frames"):
		var frames:Array=p._sprite_frames
		sprite=frames[posmod(int(floor(frame)),frames.size())]
	else:sprite=data.bitmap_frame(bitmap,sequence,frame)
	if sprite.is_empty():return
	var rect:Rect2=sprite.rect
	var scalar:float=0.0
	if not entry.is_empty():scalar=float(p.get("_state_scale",entry.get("_scale",1.0)))*METRES*p.scale*sprite.atlas_size.x
	elif p.has("native_scale"):scalar=float(p.native_scale)*METRES*p.scale*sprite.atlas_size.x
	else:
		var radius:float=p.radius
		var bounds:Dictionary=p.get("radius_animation",{})
		radius*=lerpf(float(bounds.get("from",1)),float(bounds.get("to",1)),clampf(p.age/p.lifetime,0,1))
		scalar=2.0*radius*sprite.atlas_size.x/maxf(.00001,p.reference_pixels)
	# Registration can place the particle anchor outside its visible rectangle.
	# Enclose every rotated corner about that anchor, rather than rejecting its
	# center: edge sprites and large smoke retain exactly their existing quads.
	# Only submission is skipped; every native age, animation and physics step
	# above still executes, so a camera turn reveals the same live particle.
	if not _view_frustum.is_empty():
		var extent=Vector2(maxf(absf(sprite.registration.x),absf(rect.size.x-sprite.registration.x)),maxf(absf(sprite.registration.y),absf(rect.size.y-sprite.registration.y)))*absf(scalar)
		var bound=extent.length()+.001
		if _outside_frustum(p.position,bound):return
	var tint:Color=p.tint
	if not entry.is_empty():tint*=p.get("_state_color",entry._color)
	var fade:float=weight
	var fade_in:float=float(p.get("fade_in",0))
	var fade_out:float=float(p.get("fade_out",0))
	if fade_in>0:fade*=clampf(p.age/fade_in,0,1)
	if fade_out>0:fade*=clampf((p.lifetime-p.age)/fade_out,0,1)
	tint.a*=fade
	var basis:Basis=_sprite_basis(p,rotation_override)
	var mirror_x:float=-1.0 if p.mirror_u!=flip_u else 1.0
	var mirror_y:float=-1.0 if p.mirror_v else 1.0
	var offset:Vector2=Vector2(rect.size.x*.5-sprite.registration.x,sprite.registration.y-rect.size.y*.5)*scalar
	var center:Vector3=p.position+basis.x*offset.x*mirror_x+basis.y*offset.y*mirror_y
	var transform:Transform3D=Transform3D(basis.scaled(Vector3(rect.size.x*scalar*mirror_x,rect.size.y*scalar*mirror_y,1)),center)
	var blend:String=str(state.get("framebuffer_blend_function",p.get("blend","alpha_blend")))
	var flags:int=int(state.get("shader_flags",p.get("shader_flags",0)))
	var secondary:Dictionary=state.get("secondary_map",p.get("definition",{}).get("secondary_map",{}))
	if p.get("first_person",false) and secondary.get("anchor","")=="with_zsprite":secondary={}
	var secondary_frame:Dictionary=data.bitmap_frame(secondary.get("bitmap",{})) if not secondary.is_empty() else {}
	if secondary_frame.is_empty():secondary={}
	var first_person:bool=bool(p.get("first_person",false))
	var key:String=_material_key(sprite,blend,flags,secondary,first_person)
	if not secondary.is_empty() and secondary.get("anchor","")=="with_zsprite":
		var depth_radius:float=p.radius
		var radius_scale:float=float(secondary.get("zsprite_radius_scale",0))
		if is_zero_approx(radius_scale):radius_scale=1.0
		transform.basis.z*=maxf(.00001,depth_radius*radius_scale)
	if not draws.has(key):draws[key]={"sprite":sprite,"blend":blend,"flags":flags,"secondary":secondary,"secondary_frame":secondary_frame,"first_person":first_person,"instances":[]}
	draws[key].instances.append({"transform":transform,"tint":tint,"uv":Color(rect.size.x,rect.size.y,rect.position.x,rect.position.y)})

func _outside_frustum(point:Vector3,radius:float)->bool:
	for plane:Plane in _view_frustum:
		if plane.distance_to(point)>radius:return true
	return false

func _sprite_basis(p:Dictionary,rotation_override:float=-INF)->Basis:
	var basis:Basis=_view_basis
	var direction:Vector3=p.direction.normalized()
	if direction.length_squared()<.5:direction=Vector3.UP
	match str(p.get("orientation","screen_facing")):
		"parallel_to_direction":
			var z:Vector3=basis.z
			var y:Vector3=z.cross(direction).normalized()
			if y.length_squared()>.5:basis=Basis(direction,y,direction.cross(y).normalized())
		"perpendicular_to_direction":
			var reference:Vector3=Vector3.UP if absf(direction.dot(Vector3.UP))<.99 else Vector3.FORWARD
			var x:Vector3=direction.cross(reference).normalized()
			basis=Basis(x,direction.cross(x).normalized(),direction)
	return basis*Basis(Vector3.BACK,p.rotation if rotation_override==-INF else rotation_override)

func _material_key(sprite:Dictionary,blend:String,flags:int,secondary:Dictionary={},first_person:bool=false)->String:
	var key:String=sprite.path+":"+blend+":"+str(flags)
	if not secondary.is_empty():key+=":"+str(secondary.get("bitmap",{}).get("path",""))+":"+str(secondary.get("anchor",""))
	if first_person and blend in ["add","alpha_multiply_add"]:key+=":first_person_coverage"
	return key

func _material(sprite:Dictionary,blend:String,flags:int,secondary:Dictionary={},secondary_frame:Dictionary={},first_person:bool=false)->ShaderMaterial:
	var key:String=_material_key(sprite,blend,flags,secondary,first_person)
	if _materials.has(key):return _materials[key]
	var mode:String="blend_mix"
	if blend in ["add","alpha_multiply_add"]:mode="blend_add"
	elif blend in ["multiply","double_multiply"]:mode="blend_mul"
	elif blend=="subtract":mode="blend_sub"
	var multiply:bool=blend in ["multiply","double_multiply"]
	var zsprite:bool=not secondary.is_empty() and secondary.get("anchor","")=="with_zsprite"
	var sampler_hint:String="filter_linear" if multiply else "source_color,filter_linear"
	var vertex_extra:String=""
	var secondary_fragment:String=""
	var declarations:String=""
	if not secondary.is_empty():
		declarations+="uniform sampler2D secondary_map:filter_linear,repeat_enable; uniform vec2 secondary_slide=vec2(0.0); uniform vec2 secondary_phase=vec2(0.0);"
		if zsprite:
			# Xbox zsprites use a dependent depth lookup. Godot's corresponding
			# adaptation compares the original green depth profile with this
			# viewport's scene depth; no main-camera projection is assumed.
			declarations+="uniform sampler2D native_scene_depth:hint_depth_texture,filter_nearest; varying float native_depth_radius;"
			vertex_extra="native_depth_radius=length(MODEL_MATRIX[2].xyz);"
			secondary_fragment="""
vec3 scene_ndc=vec3(SCREEN_UV*2.0-1.0,texture(native_scene_depth,SCREEN_UV).r);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
scene_ndc.z=scene_ndc.z*2.0-1.0;
#endif
vec4 scene_view=INV_PROJECTION_MATRIX*vec4(scene_ndc,1.0);
float scene_distance=-scene_view.z/scene_view.w;
float bulge=texture(secondary_map,UV).g*native_depth_radius;
if(scene_distance < -VERTEX.z-bulge) { discard; }
"""
		else:
			var uv_source:String="SCREEN_UV" if secondary.get("anchor","")=="with_screen_space" else "UV"
			secondary_fragment="vec4 secondary_tex=texture(secondary_map,"+uv_source+"+secondary_phase+TIME*secondary_slide);tex*=secondary_tex;"
	var color_formula:String="tex.rgb*COLOR.rgb"
	if multiply:
		color_formula="mix(vec3(1.0),tex.rgb*COLOR.rgb"+("*2.0" if blend=="double_multiply" else "")+",tex.a*COLOR.a)"
	var alpha_formula:String="1.0" if multiply else "tex.a*COLOR.a"
	if first_person and blend in ["add","alpha_multiply_add"]:
		# Retail additive bitmaps intentionally keep opaque black backgrounds.
		# A transparent weapon SubViewport needs color coverage in its alpha
		# channel so its later canvas composition cannot paint black quads.
		alpha_formula="max(tex.r,max(tex.g,tex.b))*tex.a*COLOR.a"
	var shader:Shader=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_never,"+mode+(",depth_test_disabled" if zsprite else "")+"; uniform sampler2D atlas:"+sampler_hint+"; "+declarations+" varying vec4 native_uv; void vertex(){native_uv=INSTANCE_CUSTOM;"+vertex_extra+"} void fragment(){vec4 tex=texture(atlas,UV*native_uv.xy+native_uv.zw);"+secondary_fragment+" ALBEDO="+color_formula+"; ALPHA="+alpha_formula+";}"
	var material:ShaderMaterial=ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("atlas",sprite.texture)
	if not secondary_frame.is_empty():
		material.set_shader_parameter("secondary_map",secondary_frame.texture)
		var slide:Vector2=Vector2.ZERO
		var phase:Vector2=Vector2.ZERO
		for axis:int in 2:
			var animation:Dictionary=secondary.get("u_animation" if axis==0 else "v_animation",{})
			phase[axis]=float(animation.get("phase",0))
			if animation.get("function","")=="slide":slide[axis]=float(animation.get("scale",0))/maxf(.00001,float(animation.get("period",1)))
		material.set_shader_parameter("secondary_slide",slide)
		material.set_shader_parameter("secondary_phase",phase)
	_materials[key]=material
	return material

func _flush(draws:Dictionary):
	for batch:Dictionary in _batches.values():
		batch.mesh.visible_instance_count=0
		batch["instances"]=[]
	for key:String in draws:
		var draw:Dictionary=draws[key]
		var instances:Array=draw.instances
		var camera:Camera3D=_view_camera
		if draw.blend=="alpha_blend" and camera!=null:
			var viewer:Vector3=camera.global_position
			instances.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.transform.origin.distance_squared_to(viewer)>b.transform.origin.distance_squared_to(viewer))
		if not _batches.has(key):
			var mesh:MultiMesh=MultiMesh.new()
			mesh.transform_format=MultiMesh.TRANSFORM_3D
			mesh.use_colors=true;mesh.use_custom_data=true
			var quad:QuadMesh=QuadMesh.new();quad.size=Vector2.ONE
			mesh.mesh=quad
			var node:MultiMeshInstance3D=MultiMeshInstance3D.new()
			node.multimesh=mesh;node.material_override=_material(draw.sprite,draw.blend,draw.flags,draw.get("secondary",{}),draw.get("secondary_frame",{}),draw.get("first_person",false))
			node.layers=layer;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node);node.set_as_top_level(true);node.global_transform=Transform3D.IDENTITY
			_batches[key]={"mesh":mesh,"node":node}
		var batch:Dictionary=_batches[key]
		batch["instances"]=instances
		var mesh:MultiMesh=batch.mesh
		if mesh.instance_count<instances.size():mesh.instance_count=mini(MAX_PARTICLES*4,maxi(16,int(pow(2,ceil(log(float(instances.size()))/log(2.0))))))
		mesh.visible_instance_count=instances.size()
		for i:int in instances.size():
			var item:Dictionary=instances[i]
			mesh.set_instance_transform(i,item.transform)
			mesh.set_instance_color(i,item.tint)
			mesh.set_instance_custom_data(i,item.uv)

func batch_count()->int:return _batches.size()

func snapshot()->Array[Dictionary]:
	return _particles.duplicate(true)

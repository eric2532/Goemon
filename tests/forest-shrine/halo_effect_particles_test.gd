extends SceneTree
const Data=preload("res://scripts/halo_effect_data.gd")
const Particles=preload("res://scripts/halo_effect_particles.gd")
const Math=preload("res://scripts/halo_particle_math.gd")
var checks:int=0
var failures:int=0
var collisions:int=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func near(value:float,wanted:float,label_:String,tolerance:float=.00001):check(absf(value-wanted)<=tolerance,label_)
func run():
	var data=Data.new()
	check(data.tags.size()>=399,"All native classes are available")
	var bullet:String="weapons\\pistol\\bullet"
	check(data.resolve(bullet,"projectile").has("proj_attrs"),"Class-qualified projectile collision resolves")
	check(data.resolve(bullet,"damage_effect").has("damage"),"Class-qualified damage collision resolves")
	check(data.resolve(bullet,"bitmap").is_empty(),"Wrong class cannot resolve a same-path tag")
	var bitmap:Dictionary={"class":"bitmap","path":"effects\\particles\\flash\\bitmaps\\fire cloud"}
	var sprite:Dictionary=data.bitmap_frame(bitmap,0,0)
	check(sprite.texture is Texture2D,"Original atlas loads")
	check(sprite.texture==data.bitmap_frame(bitmap,0,0).texture,"Texture cache is shared")
	check(data.sequence_length(bitmap,0)==60,"Original fire sequence retains 60 sprites")
	near(sprite.rect.position.x,.703125,"Original frame UV left")
	near(sprite.rect.position.y,.84375,"Original frame UV top")
	near(sprite.rect.size.x,.140625,"Original frame UV width")
	near(sprite.registration.x,.0703125,"Original registration retained")
	check(data.bitmap_frame(bitmap,0,60).rect==sprite.rect,"Native frames wrap without atlas grid guesses")
	var fx=Particles.new();root.add_child(fx);fx.configure(data)
	for i:int in 20:
		fx.spawn_sprite({"bitmap":bitmap,"radius":.5,"lifetime":2.0,"position":Vector3(i,2,0)})
	fx.tick(0)
	check(fx.live_count()==20,"Independent particles are retained")
	check(fx.batch_count()==1,"Same actual atlas and blend share a MultiMesh")
	var batch:Dictionary=fx._batches.values()[0]
	# The headless dummy rendering server returns defaults for GPU readback;
	# inspect the exact submitted instance stream instead.
	near(batch.instances[0].transform.basis.x.length(),1.0,"Native radius produces authored diameter")
	var uv:Color=batch.instances[0].uv
	near(uv.r,.140625,"Per-instance UV width")
	near(uv.b,.703125,"Per-instance UV origin")
	fx.tick(2.01);check(fx.live_count()==0,"Lifetime expires without node proliferation")
	var stone:Dictionary=data.resolve("effects\\point physics\\stones","point_physics")
	fx.spawn_sprite({"bitmap":bitmap,"radius":.01,"radius_halo":.003,"physics":stone,"position":Vector3(0,3,0),"lifetime":3})
	fx.tick(.1)
	check(fx.snapshot()[0].velocity.y<0,"Native dense particle gravity falls")
	fx.clear()
	for effect_scale:float in [1.0,3.0]:
		fx.spawn_sprite({"bitmap":bitmap,"radius":.03*effect_scale,"radius_halo":.01,"scale":effect_scale,"physics":stone,"position":Vector3(0,3,0)*effect_scale,"velocity":Vector3(1,2,3)*effect_scale,"lifetime":3})
	fx.tick(.1)
	var scaled:Array=fx.snapshot()
	check(scaled[1].velocity.is_equal_approx(scaled[0].velocity*3),"Threefold effect scale preserves native gravity and friction trajectory")
	check(scaled[1].position.is_equal_approx(scaled[0].position*3),"Threefold effect scale preserves all world displacements")
	fx.clear()
	var system:Dictionary=data.resolve("weapons\\frag grenade\\effects\\explosion med","particle_system")
	var states:Array=system.particle_types[0].particle_states
	var fixed:Array=[]
	for i:int in states.size():
		var state:Dictionary=states[i].duplicate(true)
		state.scale={"from":.01+i*.02,"to":.01+i*.02}
		state.duration_bounds={"from":.2,"to":.2}
		state.transition_time_bounds={"from":.2,"to":.2}
		fixed.append(state)
	fx.spawn_sprite({"state_plan":Math.state_plan(fixed),"position":Vector3(0,2,0),"scale":1.0,"radius":.02,"lifetime":2})
	fx.tick(.3)
	check(fx.live_count()==1,"Fire-to-smoke state transition keeps the original particle")
	near(fx.snapshot()[0]._state_scale,.02,"Native state scales interpolate during texture transition")
	check(fx.batch_count()>=2,"Fire and smoke draw their original separate atlases during crossfade")
	fx.tick(2);check(fx.live_count()==0,"Native last-state hold retires system particle")
	fx.clear()
	var type_plan:Array=Math.state_plan([
		{"duration_bounds":{"from":.2,"to":.2},"transition_time_bounds":{"from":.2,"to":.2},"scale_multiplier":1,"radius_multiplier":1,"color_multiplier":{"a":1,"r":1,"g":1,"b":1}},
		{"duration_bounds":{"from":1,"to":1},"scale_multiplier":3,"radius_multiplier":2,"color_multiplier":{"a":0,"r":0,"g":0,"b":0}}])
	fx.spawn_sprite({"state_plan":Math.state_plan(fixed),"type_state_plan":type_plan,"radius_halo":1.5,"position":Vector3(0,2,0),"lifetime":2})
	fx.tick(.3)
	near(fx.snapshot()[0]._state_scale,.04,"Emitter state scale multiplies the interpolated particle state")
	near(fx.snapshot()[0].radius_halo,2.25,"Emitter radius transition affects native point physics mass")
	fx.clear()
	var camera:Camera3D=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,0,5)
	fx.configure(data,camera)
	fx.spawn_sprite({"bitmap":bitmap,"native_scale":.01,"scale":2.0,"lifetime":2,"rotation":TAU*.25,"direction":Vector3.RIGHT,"complex_sprite_render_modes":"rotational"})
	fx.tick(0)
	var face:Dictionary=data.bitmap_frame(bitmap,0,15)
	var face_batch:Dictionary=fx._batches[face.path+":alpha_blend:0"]
	var face_uv:Color=face_batch.instances[0].uv
	near(face_uv.b,face.rect.position.x,"Native rotational face sequence advances from rotation")
	near(face_batch.instances[0].transform.basis.x.length(),face.rect.size.x*face.atlas_size.x*.01*3.048*2,"Native system scale uses original atlas pixel width")
	fx.clear()
	fx.spawn_sprite({"bitmap":bitmap,"native_scale":.01,"lifetime":2,"direction":Vector3.FORWARD,"complex_sprite_render_modes":"rotational"})
	fx.tick(0)
	var edge:Dictionary=data.bitmap_frame(bitmap,1,0)
	var edge_batch:Dictionary=fx._batches[edge.path+":alpha_blend:0"]
	near(edge_batch.instances[0].uv.b,edge.rect.position.x,"Axial view selects the native second sequence")
	fx.clear();camera.queue_free();fx.configure(data)
	fx.spawn_sprite({"bitmap":bitmap,"attachment_id":10,"position":Vector3(1,2,3),"lifetime":2})
	fx.spawn_sprite({"bitmap":bitmap,"position":Vector3(7,8,9),"lifetime":2})
	fx.shift_attachment(10,Vector3(2,0,0))
	check(fx.snapshot()[0].position==Vector3(3,2,3),"Attached rocket flare follows owner translation")
	check(fx.snapshot()[1].position==Vector3(7,8,9),"Detached smoke retains its world position")
	fx.clear_attachment(10)
	check(fx.live_count()==1 and fx.snapshot()[0].position==Vector3(7,8,9),"Stopping an attachment only retires its own particles")
	fx.clear()
	var dirt:Dictionary=data.resolve("effects\\particles\\solid\\dirt burst","particle")
	fx.emit_particle(dirt,Transform3D.IDENTITY,1,{"radius":.3})
	fx.tick(0)
	var zsprite_found:bool=false
	for secondary_batch:Dictionary in fx._batches.values():
		if secondary_batch.get("instances",[]).is_empty():continue
		var material:ShaderMaterial=secondary_batch.node.material_override
		var secondary_texture:Variant=material.get_shader_parameter("secondary_map")
		if secondary_texture==null:continue
		zsprite_found=true
		check(secondary_texture==data.bitmap_frame(dirt.secondary_map.bitmap).texture,"Dirt impact binds the original noisy depth bitmap")
		near(secondary_batch.instances[0].transform.basis.z.length(),.3,"Zero native zsprite radius scale defaults to one")
	check(zsprite_found,"Reachable dirt impact uses a depth-profile material")
	fx.clear()
	var ice:Dictionary=data.resolve("effects\\particles\\solid\\ice","particle")
	fx.emit_particle(ice,Transform3D.IDENTITY,1,{"radius":.1})
	fx.tick(0)
	var mask_found:bool=false
	for mask_batch:Dictionary in fx._batches.values():
		if mask_batch.get("instances",[]).is_empty():continue
		var material:ShaderMaterial=mask_batch.node.material_override
		if material.get_shader_parameter("secondary_map")==data.bitmap_frame(ice.secondary_map.bitmap).texture:
			mask_found=true
			check(material.get_shader_parameter("secondary_slide")==Vector2.ONE,"Native glass mask keeps both authored slide rates")
	check(mask_found,"Ice retains its original screen-anchored glass mask")
	fx.clear()
	fx.spawn_sprite({"bitmap":bitmap,"attachment_id":0,"position":Vector3.ZERO})
	fx.spawn_sprite({"bitmap":bitmap,"attachment_id":"light-volume:0","position":Vector3.ZERO})
	fx.spawn_sprite({"bitmap":bitmap,"position":Vector3.ZERO})
	fx.shift_attachment(0,Vector3.RIGHT)
	check(fx.snapshot()[0].position==Vector3.RIGHT and fx.snapshot()[1].position==Vector3.ZERO,"Numeric rocket and namespaced widget attachments move independently")
	check(fx.update_attachment("light-volume:0",[{"position":Vector3.UP}])==1,"Namespaced widget updates coexist with numeric and unattached sprites")
	fx.clear_attachment(0)
	check(fx.live_count()==2,"Numeric attachment clear preserves the widget and unattached sprite")
	fx.clear_attachment("light-volume:0")
	check(fx.live_count()==1,"Namespaced attachment clear preserves unattached sprites")
	fx.clear()
	var body:StaticBody3D=StaticBody3D.new()
	var collider:CollisionShape3D=CollisionShape3D.new()
	var box:BoxShape3D=BoxShape3D.new();box.size=Vector3(20,.1,20)
	collider.shape=box;body.add_child(collider);body.position.y=-.05;root.add_child(body)
	fx.particle_collision.connect(func(_at:Vector3,normal:Vector3,ref:Dictionary,_contact:Dictionary):
		collisions+=1;check(normal.y>.9,"Shell bounce emits surface normal");check(ref.get("path","")=="shell bounce","Shell bounce carries original material effect reference"))
	await physics_frame
	await physics_frame
	fx.spawn_sprite({"bitmap":bitmap,"radius":.01,"physics":{"flags":2,"elasticity":.5},"position":Vector3(0,1,0),"velocity":Vector3(0,-10,0),"material_effects":{"class":"material_effects","path":"shell bounce"},"lifetime":2})
	fx.tick(.2)
	check(collisions==1,"Swept world ray catches shell surface collision")
	check(fx.snapshot()[0].velocity.y>0,"Native elasticity reverses collision normal velocity")
	fx.clear();body.queue_free()
	for i:int in Particles.MAX_PARTICLES+5:fx.spawn_sprite({"bitmap":bitmap,"lifetime":.5})
	check(fx.live_count()==Particles.MAX_PARTICLES,"4096 particle cap holds under excess emission")
	fx.clear();check(fx.live_count()==0,"Clear retires all live entries")
	fx.queue_free();await process_frame
	print("HALO_EFFECT_PARTICLES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

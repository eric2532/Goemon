extends "res://scripts/recovered_ed_beam_tests.gd"
## Exercise viewport isolation, the live native path, and stale-frame cleanup.
const RENDERER_PATH="res://scripts/recovered_ed_beam_renderer.gd"

func run():
	check(ResourceLoader.exists(RENDERER_PATH),"Native Ed compositor manager is available")
	if failures:quit(1);return
	var renderer_script=load(RENDERER_PATH)
	beam_script=load("res://scripts/recovered_ed_beam.gd")
	arena=Arena.new();root.add_child(arena)
	lib=SoundLibrary.new();lib.config_path="user://ed-beam-renderer-%d/studio.cfg"%OS.get_process_id();lib.folder="user://ed-beam-renderer-%d/recordings"%OS.get_process_id()
	arena.add_child(lib);lib.set_process(false);arena.sound_library=lib;lib.custom_for(14,"ed_beam_charge")
	caster=Caster.new();caster.character_id=14;caster.game=arena;arena.player=caster;arena.add_child(caster)
	var camera=Camera3D.new();arena.add_child(camera);camera.position=Vector3(0,4,10);camera.look_at(Vector3(0,1,-3));camera.current=true
	var renderer=renderer_script.ensure(arena)
	renderer.set_process(false)
	check(renderer==renderer_script.ensure(caster),"A viewport shares one compositor across callers")
	renderer.render_frame()
	check(not renderer.visible,"An empty viewport keeps its native overlay hidden")
	check(renderer_script.native_size(Vector2i(640,480))==Vector2i(320,240),"A4:3 viewport keeps the source320x240 pixel grid")
	check(renderer_script.native_size(Vector2i(1280,720))==Vector2i(427,240),"A widescreen viewport extends width without stretching native pixels")
	var other_view=SubViewport.new();other_view.size=Vector2i(320,240);root.add_child(other_view)
	var other_owner=Node3D.new();other_view.add_child(other_owner)
	var other_renderer=renderer_script.ensure(other_owner);other_renderer.set_process(false)
	check(other_renderer!=renderer,"A separate viewport owns a separate native compositor")
	var active_beam=beam();active_beam.advance(8.0/30.0)
	renderer.render_frame()
	var image:Image=renderer.frame_image
	var colored=false
	if image:
		var bytes=image.get_data()
		for index in range(3,bytes.size(),4):
			if bytes[index]>0 and (bytes[index-3]>0 or bytes[index-2]>0 or bytes[index-1]>0):colored=true;break
	check(renderer.visible and colored,"A real held beam generates a covered native RGB555 foreground")
	other_renderer.render_frame()
	check(not other_renderer.visible,"Beams from another viewport never appear in this overlay")
	check_multi_beam_sum(renderer,active_beam)
	await check_whole_disc_occlusion(renderer,active_beam,camera)
	benchmark_native_frame(renderer,active_beam,camera)
	active_beam.hide();renderer.render_frame()
	check(not renderer.visible,"Hiding the beam removes its previous foreground immediately")
	active_beam.show();arena.paused=true;renderer.render_frame()
	check(renderer.visible,"Paused beam phases can still render through the current camera")
	arena.paused=false;active_beam.stop();renderer.render_frame()
	check(not renderer.visible,"Stopping the last beam clears its previous foreground immediately")
	clear();arena.free();other_view.free();renderer.free();await process_frame
	await create_timer(.35).timeout
	print("RECOVERED_ED_BEAM_RENDERER_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func check_multi_beam_sum(renderer,active_beam):
	renderer.render_frame()
	var single:PackedByteArray=renderer.frame_image.get_data()
	var ally=Caster.new();ally.character_id=14;ally.game=arena;arena.add_child(ally)
	var second=beam_script.new();second.game=arena;second.hero=ally
	second.attack_ticket={"source_hero":weakref(ally),"action":"ed_beam_renderer_test","chain_enabled":false}
	arena.add_child(second);second.advance(active_beam.elapsed)
	renderer.render_frame()
	var pair:PackedByteArray=renderer.frame_image.get_data()
	var exact=single.size()==pair.size()
	var unsaturated_channels=0
	for index in single.size():
		var expected=single[index] if index%4==3 else mini(31,single[index]*2)
		if single[index]>0 and single[index]<16 and index%4!=3:unsaturated_channels+=1
		if pair[index]!=expected:exact=false;break
	check(exact and unsaturated_channels>0,"Two coincident independent beams add every RGB555 channel with native saturation")
	second.stop();second.free();ally.free()
	renderer.render_frame()
	check(renderer.frame_image.get_data()==single,"Removing one beam immediately restores the remaining beam's foreground")

func check_whole_disc_occlusion(renderer,active_beam,camera):
	var builder=renderer.packet_builder
	# Initialize the real builder, then isolate one original twelve-spoke disc.
	builder.build(active_beam,camera,renderer.configured_size)
	var center:Vector3=active_beam.visual.glows[0].global_position
	builder.packets=PackedInt32Array();builder._disc(center,160,Vector3i(255,64,0))
	var unobstructed:PackedInt32Array=builder.packets.duplicate()
	check(unobstructed.size()==12*24,"One source disc submits exactly twelve Gouraud triangles")
	var floor_body=wall(Vector3(0,-.1,0),Vector3(100,.2,100))
	await physics_frame;await physics_frame
	builder.packets=PackedInt32Array();builder._disc(center,160,Vector3i(255,64,0))
	var reaches_below_floor=center.y-camera.global_basis.y.y*160*builder.unit<0
	check(reaches_below_floor and builder.packets==unobstructed,"A visible whole disc keeps its lower halo when the billboard extends below the floor")
	var barrier=wall(Vector3(0,0,9),Vector3(100,100,.2))
	await physics_frame;await physics_frame
	builder.packets=PackedInt32Array();builder._disc(center,160,Vector3i(255,64,0))
	check(builder.packets.is_empty(),"A wall before the disc's native ordering depth occludes the entire disc")
	barrier.free();floor_body.free();await physics_frame;await physics_frame
	builder.packets=PackedInt32Array();builder._disc(center,160,Vector3i(255,64,0))
	check(builder.packets==unobstructed,"Removing cover restores the complete source disc without stale visibility")

func benchmark_native_frame(renderer,active_beam,camera):
	active_beam.advance(2.0/30.0)
	var builder=renderer.packet_builder
	var size:Vector2i=renderer.configured_size
	var packet_us:Array[int]=[];var raster_us:Array[int]=[];var totals:Array[int]=[]
	var triangle_count=0
	# Warm native code/data before measuring twenty complete held-beam frames.
	var warm:PackedInt32Array=builder.build(active_beam,camera,size)
	renderer.rasterizer.render(warm)
	for frame in 20:
		var begin=Time.get_ticks_usec()
		var packet:PackedInt32Array=builder.build(active_beam,camera,size)
		var assembled=Time.get_ticks_usec()
		var pixels:PackedByteArray=renderer.rasterizer.render(packet)
		var finished=Time.get_ticks_usec()
		packet_us.append(assembled-begin);raster_us.append(finished-assembled);totals.append(finished-begin)
		triangle_count=packet.size()/24
		if pixels.size()!=size.x*size.y*4:check(false,"Benchmark rasterizer returns a complete frame");return
	check(triangle_count>100,"The performance fixture includes the full held native beam, shield and body discs")
	var report={"frames":20,"native_size":[size.x,size.y],"triangles":triangle_count,"reach_multiplier":2,"source_tick":active_beam.visual.source_tick,"packet_mean_ms":mean_us(packet_us)/1000.0,"raster_mean_ms":mean_us(raster_us)/1000.0,"total_mean_ms":mean_us(totals)/1000.0,"total_min_ms":totals.min()/1000.0,"total_max_ms":totals.max()/1000.0,"occlusion_enabled":builder.occlusion_enabled,"headless":DisplayServer.get_name()=="headless"}
	print("RECOVERED_ED_BEAM_RENDERER_BENCHMARK ",JSON.stringify(report))

func mean_us(values:Array[int])->float:
	var total=0
	for value in values:total+=value
	return float(total)/values.size()

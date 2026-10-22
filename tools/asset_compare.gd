extends SceneTree
## Synchronized source/candidate viewer and repeatable rendered comparison sweep.
var options={}
var models:Array[Node3D]=[]
var views:Array[SubViewport]=[]
var cameras:Array[Camera3D]=[]
var players:Array[AnimationPlayer]=[]
var palettes:Array=[]
var clips:OptionButton
var timeline:HSlider
var playing:CheckBox
var angle:HSlider
var gear:SpinBox
var readout:Label
var target=Vector3.ZERO
var distance_value=5.0
var elapsed=0.0
var capturing=false
var captures=[]
var failed=false
func _initialize():
	for arg in OS.get_cmdline_user_args():
		var pair=arg.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1] if pair.size()==2 else true
	run.call_deferred()
func fail(message:String):
	printerr("ASSET_COMPARE: ",message);failed=true;quit(1)
func read_model(path:String)->Node3D:
	var document=GLTFDocument.new();var state=GLTFState.new()
	if document.append_from_file(path,state)!=OK:fail("Cannot import "+path);return null
	return document.generate_scene(state,30.0,false,false)
func build_view(parent:Node,label_:String,path:String):
	var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(column)
	var label=Label.new();label.text=label_;column.add_child(label)
	var container=SubViewportContainer.new();container.stretch=true;container.size_flags_vertical=Control.SIZE_EXPAND_FILL;container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(container)
	var view=SubViewport.new();view.size=Vector2i(620,660);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.msaa_3d=Viewport.MSAA_4X;container.add_child(view);views.append(view)
	var scene=Node3D.new();view.add_child(scene)
	var world=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("26353f")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.65;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.environment=env;scene.add_child(world)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);sun.light_energy=1.1;scene.add_child(sun)
	var model=read_model(path)
	if model==null:return
	scene.add_child(model);models.append(model)
	if options.get("asset","")=="musashi":
		var materials=load("res://scripts/recovered_musashi_model.gd").install_palette_for(model)
		for material in materials:
			material.set_shader_parameter("compensate_filmic",true);material.set_shader_parameter("scene_exposure",env.tonemap_exposure);material.set_shader_parameter("scene_white",env.tonemap_white)
		palettes.append(materials)
	var player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	players.append(player)
	if player:player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var camera=Camera3D.new();camera.fov=38;camera.near=.01;scene.add_child(camera);camera.current=true;cameras.append(camera)
func seek(seconds:float):
	for i in players.size():
		var player=players[i]
		if player==null:continue
		var clip=clips.get_item_text(clips.selected)
		if not player.has_animation(clip):fail("Candidate is missing animation "+clip);return
		player.play(clip);player.seek(seconds,true);player.pause()
		for skeleton in models[i].find_children("*","Skeleton3D",true,false):skeleton.force_update_all_bone_transforms()
		# Match the game controller's treatment of epsilon-scale hidden stages.
		for mesh in models[i].find_children("*","MeshInstance3D",true,false):mesh.visible=mesh.global_basis.get_scale().length()>.025
func set_clip(index:int):
	clips.select(index);elapsed=0
	var clip=clips.get_item_text(index)
	timeline.max_value=players[0].get_animation(clip).length if players[0] else 1.0
	timeline.set_value_no_signal(0);seek(0)
func orbit(value:float):
	var radians=deg_to_rad(value)
	for camera in cameras:
		camera.position=target+Vector3(sin(radians)*distance_value,distance_value*.24,cos(radians)*distance_value)
		camera.look_at(target)
func set_gear(value:float):
	if palettes.is_empty():return
	var data=load("res://scripts/recovered_musashi_model.gd").equipment_sources()
	var pages:Dictionary=data.looks[int(value)].pages
	for materials in palettes:
		for material in materials:
			if material.has_meta("source_clut"):
				var key=str(material.get_meta("source_clut"))
				if pages.has(key):material.set_shader_parameter("albedo_texture",load("res://assets/characters/recovered_musashi/outfits/"+pages[key]))
func run():
	if not options.has("before") or not options.has("after"):fail("Provide --before= and --after=");return
	root.title="Goemon Asset Comparison";root.size=Vector2i(1280,820)
	var layout=VBoxContainer.new();layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(layout)
	var title=Label.new();title.text="Goemon · synchronized asset comparison";layout.add_child(title)
	var controls=HBoxContainer.new();layout.add_child(controls)
	clips=OptionButton.new();controls.add_child(clips);clips.item_selected.connect(set_clip)
	playing=CheckBox.new();playing.text="Play";controls.add_child(playing)
	timeline=HSlider.new();timeline.custom_minimum_size.x=330;timeline.step=.001;controls.add_child(timeline)
	timeline.value_changed.connect(func(value):elapsed=value;seek(value))
	angle=HSlider.new();angle.min_value=-180;angle.max_value=180;angle.value=30;angle.custom_minimum_size.x=140;controls.add_child(angle);angle.value_changed.connect(orbit)
	var wire=CheckBox.new();wire.text="Wireframe";controls.add_child(wire)
	wire.toggled.connect(func(enabled):
		for view in views:view.debug_draw=Viewport.DEBUG_DRAW_WIREFRAME if enabled else Viewport.DEBUG_DRAW_DISABLED)
	if options.get("asset","")=="musashi":
		var gear_label=Label.new();gear_label.text="Gear mask";controls.add_child(gear_label)
		gear=SpinBox.new();gear.min_value=0;gear.max_value=31;controls.add_child(gear);gear.value_changed.connect(set_gear)
	readout=Label.new();layout.add_child(readout)
	var row=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(row)
	build_view(row,"BEFORE · "+str(options.before).get_file(),options.before)
	build_view(row,"AFTER · "+str(options.after).get_file(),options.after)
	if failed:return
	if models.size()!=2 or players[0]==null or players[1]==null:fail("Both models require an AnimationPlayer");return
	for clip in players[0].get_animation_list():clips.add_item(clip)
	if players[0].get_animation_list()!=players[1].get_animation_list():fail("Imported animation lists differ");return
	var default_clip="work_loop" if options.get("asset","")=="goldmine" else "Table_00__800d46e4"
	for i in clips.item_count:
		if clips.get_item_text(i)==default_clip:clips.select(i);break
	set_clip(clips.selected)
	var bounds=AABB();var first=true
	for mesh in models[0].find_children("*","MeshInstance3D",true,false):
		if not mesh.visible:continue
		var box=mesh.global_transform*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
	target=bounds.get_center();distance_value=maxf(bounds.size.length()*1.7,1.0);orbit(angle.value)
	readout.text="Same camera / lighting / animation time. Drag the timeline and angle slider. Gear masks: 0 original, 31 all equipment."
	if options.has("capture"):
		capturing=true
		if DisplayServer.get_name()=="headless":fail("Rendered captures require a display; run without --headless");return
		await capture_sweep()
func _process(delta:float):
	if capturing or playing==null or not playing.button_pressed:return false
	elapsed=fposmod(elapsed+delta,maxf(timeline.max_value,.001));timeline.set_value_no_signal(elapsed);seek(elapsed)
	return false
func capture_sweep():
	var output=str(options.get("out",OS.get_user_data_dir()+"/asset-comparison"))
	DirAccess.make_dir_recursive_absolute(output)
	var selected=[]
	var chosen=["build","reverse_build","work_loop","upgrade_preview"] if options.asset=="goldmine" else ["Table_00__800d46e4","Table_07__800d4944","Extra__800d4c94","Extra__800d4f14","Extra__800d5360","Extra__800d4be0"]
	for i in clips.item_count:
		if options.has("all-clips") or clips.get_item_text(i) in chosen:selected.append(i)
	for clip_index in selected:
		set_clip(clip_index)
		for fraction in [0.0,.5,1.0]:
			var seconds=timeline.max_value*fraction;seek(seconds)
			for degrees in [0.0,90.0,180.0,270.0]:
				orbit(degrees)
				await process_frame;await process_frame;await RenderingServer.frame_post_draw
				var before=views[0].get_texture().get_image();var after=views[1].get_texture().get_image()
				before.convert(Image.FORMAT_RGBA8);after.convert(Image.FORMAT_RGBA8)
				var clip=clips.get_item_text(clip_index);var name="%s-%.2f-%03d"%[clip,fraction,int(degrees)]
				if before.save_png(output+"/"+name+"-before.png")!=OK or after.save_png(output+"/"+name+"-after.png")!=OK:fail("Cannot write captures");return
				var metrics=before.compute_image_metrics(after,false)
				# Perfect matches yield infinite PSNR, which is not portable JSON.
				metrics.erase("peak_snr")
				captures.append({"clip":clip,"seconds":seconds,"angle":degrees,"before":name+"-before.png","after":name+"-after.png","metrics":metrics})
	var report={"asset":options.asset,"before":options.before,"after":options.after,"captures":captures,"renderer":RenderingServer.get_video_adapter_name(),"notes":"Pixel metrics are review evidence; file preservation and imported animation tests are separate gates."}
	var file=FileAccess.open(output+"/comparison.json",FileAccess.WRITE)
	if file==null:fail("Cannot write comparison report");return
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ASSET_COMPARE_RESULT captures=%d report=%s"%[captures.size(),output+"/comparison.json"])
	quit(0)

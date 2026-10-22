extends Node3D
## Camera-mounted native Halo weapons and cyborg arms, with pooled audio.
const ASSET_PATH="res://assets/characters/master_chief/rocket_launcher_fp.glb"
const Weapons=preload("res://scripts/master_chief_weapons.gd")
const VIEW_LAYER=1<<19
var weapon_slot=1
var loadout:Dictionary={}
var weapon:Node3D
var audio:AudioStreamPlayer
var recoil=0.0
var phase=0.0
var native_fx:Node3D
var sword_visual:Node3D
var audio_pool:Array[AudioStreamPlayer]=[]
var audio_cursor=0
var native_shot_pool:Dictionary={}
var rest_position=Vector3.ZERO
var native_sample:AudioStream
var animations:AnimationPlayer
var muzzle_anchor:Node3D
var ejection_anchor:Node3D
var weapon_view:SubViewport
var weapon_camera:Camera3D
var weapon_pivot:Node3D
var overlay:CanvasLayer
func _ready():
	set_meta("halo_source","Xbox retail map")
	_setup_presentation()
	var native_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/master_chief/effects/manifest.json"))
	for slot in Weapons.SLOTS:
		var model=load(Weapons.model_path(slot)).instantiate()
		weapon_pivot.add_child(model);_prepare_meshes(model);model.hide()
		if Weapons.data(slot).get("melee",false):
			model.position+=Vector3(.18,.03,0)
			sword_visual=preload("res://scripts/master_chief_energy_sword.gd").new()
			weapon_view.add_child(sword_visual);sword_visual.configure(model,weapon_camera,VIEW_LAYER)
		var player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
		if player!=null:
			player.get_animation("idle").loop_mode=Animation.LOOP_LINEAR
			player.animation_finished.connect(_animation_finished.bind(slot))
		var markers:Dictionary
		if Weapons.data(slot).get("melee",false):
			var blade=model.find_child("BladeTip",true,false)
			if blade==null:blade=model.find_child("Muzzle",true,false)
			markers={"primary trigger":blade if blade!=null else model,"primary ejection":blade if blade!=null else model}
		else:markers=_native_markers(model,native_data.weapons[Weapons.data(slot).key].markers)
		loadout[slot]={"model":model,"animations":player,"muzzle":markers["primary trigger"],"ejection":markers["primary ejection"],"sample":load(Weapons.sound_path(slot))}
	for i in 4:
		var voice=AudioStreamPlayer.new();voice.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
		voice.stream=native_sample
		voice.volume_db=-9;add_child(voice);audio_pool.append(voice)
	audio=audio_pool[0]
	var light=OmniLight3D.new();light.position=Vector3(.2,.35,.1)
	light.light_color=Color("dce9f7");light.light_energy=.7;light.omni_range=3.0
	light.light_cull_mask=VIEW_LAYER;light.shadow_enabled=false;weapon_view.add_child(light)
	native_fx=load("res://scripts/halo_weapon_effects.gd").new()
	var game=_game_context()
	native_fx.configure(game,game.player if is_instance_valid(game) else null,weapon_camera,VIEW_LAYER)
	weapon_view.add_child(native_fx)
	select_slot(weapon_slot,true)
func select_slot(slot:int,force:bool=false):
	if not loadout.has(slot) or (slot==weapon_slot and not force):return
	stop()
	for entry in loadout.values():entry.model.hide()
	weapon_slot=slot
	var entry=loadout[slot];weapon=entry.model;animations=entry.animations
	muzzle_anchor=entry.muzzle;ejection_anchor=entry.ejection;native_sample=entry.sample
	weapon.show()
	for voice in audio_pool:voice.stream=native_sample
	if animations!=null:
		animations.speed_scale=1.0
		animations.play("ready" if animations.has_animation("ready") else "idle",.04)
func _game_context():
	var rig=get_parent().get_parent() if get_parent() is Camera3D else null
	return rig.get("game") if is_instance_valid(rig) else null
func _native_markers(model:Node3D,source:Dictionary)->Dictionary:
	# Imported Muzzle already owns the native frame-gun BoneAttachment. Anchor
	# both markers to that bone using the recovered idle transform in metres;
	# inverse attachment transform also removes the source rig's .03048 scale.
	var imported=model.find_child("Muzzle",true,false)
	var attachment=imported.get_parent() if is_instance_valid(imported) else model
	var markers={}
	for marker_name in ["primary trigger","primary ejection"]:
		var data:Dictionary=source[marker_name].godot_idle
		var p:Array=data.position;var q:Array=data.rotation_xyzw
		var pose=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3]).normalized()),Vector3(p[0],p[1],p[2]))
		var anchor=Node3D.new();anchor.name="NativeMuzzle" if marker_name=="primary trigger" else "NativeEjection"
		attachment.add_child(anchor);anchor.global_transform=model.global_transform*pose
		markers[marker_name]=anchor
	return markers
func marker_transform(marker_name:String,world:bool=false)->Transform3D:
	var anchor=ejection_anchor if marker_name=="primary ejection" else muzzle_anchor
	var pose:Transform3D=anchor.global_transform if is_instance_valid(anchor) else Transform3D.IDENTITY
	# The overlay camera and world camera share FOV and aspect; its metre-space
	# marker therefore maps directly through the actual player's camera pose.
	if world and get_parent() is Camera3D:pose=get_parent().global_transform*pose
	return pose
func _setup_presentation():
	# A separate depth buffer keeps nearby walls from cutting through the weapon.
	# This layer is drawn after the world and before the existing CanvasLayer HUD.
	weapon_view=SubViewport.new();weapon_view.name="WeaponViewport"
	weapon_view.own_world_3d=true;weapon_view.transparent_bg=true
	weapon_view.audio_listener_enable_3d=true
	weapon_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	weapon_view.msaa_3d=Viewport.MSAA_2X;add_child(weapon_view)
	weapon_pivot=Node3D.new();weapon_view.add_child(weapon_pivot)
	weapon_camera=Camera3D.new();weapon_camera.near=.025;weapon_camera.far=5
	weapon_camera.fov=78;weapon_camera.cull_mask=VIEW_LAYER;weapon_view.add_child(weapon_camera)
	var env=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d3e1ed")
	env.environment.ambient_light_energy=.7
	weapon_view.add_child(env)
	overlay=CanvasLayer.new();overlay.layer=0;add_child(overlay)
	var rect=TextureRect.new();rect.name="FirstPersonWeapon";rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.texture=weapon_view.get_texture();rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	overlay.add_child(rect)
	get_viewport().size_changed.connect(_resize_presentation)
	_resize_presentation()
func _resize_presentation():
	if is_instance_valid(weapon_view):
		weapon_view.size=Vector2i(get_viewport().get_visible_rect().size).max(Vector2i.ONE)
func _process(_delta:float):
	var shown=is_visible_in_tree()
	overlay.visible=shown
	weapon_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if get_parent() is Camera3D:weapon_camera.fov=get_parent().fov
func _prepare_meshes(node:Node):
	if node is MeshInstance3D:
		node.layers=VIEW_LAYER
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():_prepare_meshes(child)
func _native_main_sample()->AudioStream:
	if Weapons.data(weapon_slot).get("melee",false):return native_sample
	if not native_shot_pool.has(weapon_slot):
		var pool:Array[AudioStream]=[]
		var manifest:Dictionary=native_fx.data.manifest()
		var definition:Dictionary=native_fx.data.resolve(manifest.weapons[Weapons.data(weapon_slot).key].firing_effect)
		for event in definition.get("events",[]):
			for part in event.get("parts",[]):
				var reference:Dictionary=part.get("type",{})
				var path=str(reference.get("path",""))
				if reference.get("class","")!="sound" or not path.ends_with("\\fire"):continue
				for file in manifest.sounds.get(path,{}).get("files",[]):
					var stream=load(str(file.path)) as AudioStream
					if stream!=null:pool.append(stream)
				break
			if not pool.is_empty():break
		if pool.is_empty() and native_sample!=null:pool.append(native_sample)
		native_shot_pool[weapon_slot]=pool
	var choices:Array=native_shot_pool[weapon_slot]
	return choices.pick_random() if not choices.is_empty() else native_sample
func fire_shot():
	recoil=minf(.09,recoil+float(Weapons.data(weapon_slot).kick))
	if animations!=null and animations.has_animation("firing"):
		animations.speed_scale=animations.get_animation("firing").length/.65 if Weapons.data(weapon_slot).get("melee",false) else 1.0
		animations.stop();animations.play("firing")
	if not Weapons.data(weapon_slot).get("melee",false):
		native_fx.fire_first_person(weapon_slot,marker_transform("primary trigger"),marker_transform("primary ejection"),true,marker_transform.bind(false))
	if not audio_pool.is_empty():
		var voice=audio_pool[audio_cursor];audio_cursor=(audio_cursor+1)%audio_pool.size()
		voice.pitch_scale=randf_range(.97,1.03)
		var game=_game_context()
		var sample=_native_main_sample()
		var playback={"stream":sample,"gain":1.0,"muted":false}
		if is_instance_valid(game):
			var ticket={"move_audio":{"character_id":18,"move_key":Weapons.audio_key(weapon_slot),"voiced":false}}
			playback=game.move_audio.weapon(game,18,"chief_"+Weapons.audio_key(weapon_slot),sample,ticket)
			if game.sound_library.recording:return
		voice.stop();voice.stream=playback.stream
		if playback.get("recorded",false):voice.pitch_scale=1.0
		voice.volume_db=linear_to_db(.36*maxf(.0001,float(playback.gain)))
		if voice.stream!=null and not playback.muted:voice.play()
func update_motion(delta:float,speed:float,grounded:bool):
	recoil=move_toward(recoil,0,delta*.35)
	phase+=delta*(8.0 if speed>.1 else 1.5)
	var movement=clampf(speed/7.0,0,1) if grounded else .12
	position=rest_position+Vector3(sin(phase)*.008*movement,absf(cos(phase))*.006*movement,recoil)
	rotation=Vector3(recoil*.45,sin(phase*.5)*.005*movement,-recoil*.18)
	if is_instance_valid(weapon_pivot):weapon_pivot.transform=transform
func stop():
	recoil=0
	if animations!=null:animations.speed_scale=1.0
	if animations!=null and animations.has_animation("idle"):animations.play("idle",.08)
	for voice in audio_pool:voice.stop()
	if is_instance_valid(native_fx):native_fx.clear()
func _animation_finished(_clip:StringName,slot:int):
	if slot==weapon_slot and animations!=null and animations.has_animation("idle"):
		animations.speed_scale=1.0;animations.play("idle",.04)
func muzzle_position()->Vector3:
	return marker_transform("primary trigger",true).origin

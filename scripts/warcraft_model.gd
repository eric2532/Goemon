extends HeroModel
## Shared adapter for intact Warcraft skins and prepared Blender tracks.
const ROOT="res://assets/characters/warcraft/"
const Effects=preload("res://scripts/warcraft_effects.gd")
const FLIP_DURATION=preload("res://scripts/recovered_musashi_model.gd").FLIP_DURATION
# Blade-only endpoints in the original weapon bones' local coordinates.
const BLADES={31:[["Sword",Vector3(-.9,2,-20),Vector3(-1.2233,14.4119,-137.9671)]],
	32:[["L_stand_blade",Vector3(-94.3142,35.2411,25.3575),Vector3(93.0778,18.4631,-17.1304)],
		["R_stand_blade",Vector3(-97.7965,22.1422,-26.9382),Vector3(91.1233,29.4582,11.2482)]]}
static var profiles:Dictionary={}
var character=31
var combat:Node
var animation_player:AnimationPlayer
var clip=""
var clock=0.0
var frame=-1
var meshes:Array=[]
var particles:Array=[]
var live_particles:Array=[]
var billboards:Array=[]
var motion:Dictionary
var blade_trails:Array=[]
var pressure_trail:MeshInstance3D
var skin_textures:Dictionary={}

static func key(id:int)->String:return {31:"blademaster",32:"demon-hunter",33:"mountain-king"}[id]
static func data(id:int)->Dictionary:
	if not profiles.has(id):profiles[id]=JSON.parse_string(FileAccess.get_file_as_string(ROOT+key(id)+"/motion.json"))
	return profiles[id]

func _ready():
	motion=data(character)
	body=Node3D.new();add_child(body)
	head=driver("Head",Vector3(0,2.5,0));scarf=driver("Scarf",Vector3.ZERO)
	arms.assign([driver("Arm_L",Vector3(-.5,1.6,0)),driver("Arm_R",Vector3(.5,1.6,0))])
	legs.assign([driver("Leg_L",Vector3(-.2,.5,0)),driver("Leg_R",Vector3(.2,.5,0))])
	hair_normal=Node3D.new();body.add_child(hair_normal)
	hair_gold=Node3D.new();body.add_child(hair_gold);hair_gold.hide()
	pipe=Node3D.new();body.add_child(pipe);pipe.hide()
	coin=Node3D.new();body.add_child(coin);coin.hide()
	chain_pipe=ChainPipeVisual.new();body.add_child(chain_pipe);chain_pipe.hide()
	locomotion=preload("res://scripts/master_chief_locomotion.gd").new(self)
	rig_visual=load(GameAssets.model_path("res://assets/models/characters/warcraft/%s/%s.glb"%[key(character),key(character)])).instantiate();body.add_child(rig_visual)
	var fit=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT/float(motion.standing_height)
	rig_visual.scale=Vector3.ONE*fit;rig_visual.position.y=-float(motion.floor)*fit;rig_visual.rotation.y=PI/2
	animation_player=rig_visual.find_child("AnimationPlayer",true,false)
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	skeleton=rig_visual.find_child("Skeleton3D",true,false)
	for spec in motion.meshes:
		var mesh=rig_visual.find_child(spec.name,true,false) as MeshInstance3D
		var mat=mesh.get_active_material(0).duplicate() as StandardMaterial3D
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		# Depth-sort cutout skin without occluding the alternate form's embedded additive glows.
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS if int(spec.mode)==1 else BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color=Color(spec.tint[0],spec.tint[1],spec.tint[2])
		if int(spec.mode) in [3,4]:
			mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if not motion.get("authored_energy",false):mat.albedo_texture=Effects.energy_texture(mat.albedo_texture);mat.albedo_color=Effects.energy_tint(character,mat.albedo_color)
		mesh.material_override=mat;meshes.append(mesh)
		if spec.has("alternate_texture"):skin_textures[meshes.size()-1]=[mat.albedo_texture,load(ROOT+key(character)+"/"+spec.alternate_texture)]
	for spec in motion.particles:
		var sprite=Sprite3D.new();sprite.texture=load(ROOT+key(character)+"/"+spec.texture)
		if spec.texture=="energy.png":sprite.texture=Effects.energy_texture(sprite.texture)
		sprite.pixel_size=2.0/sprite.texture.get_width();sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sprite.hframes=roundi(1.0/float(spec.uv[1][0]));sprite.vframes=roundi(1.0/float(spec.uv[2][1]))
		sprite.pixel_size*=sprite.hframes;sprite.no_depth_test=false;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig_visual.add_child(sprite);sprite.hide();particles.append(sprite)
	for name_ in motion.get("billboards",Effects.data().billboards.get(str(character),[])):
		var bone=skeleton.find_bone(name_)
		if bone<0:continue
		var rest=skeleton.get_bone_global_rest(bone).basis
		billboards.append({"bone":bone,"upright":name_ in motion.get("upright",Effects.data().upright.get(str(character),[])),"axes":Basis(rest.inverse()*Vector3.RIGHT,rest.inverse()*Vector3.UP,rest.inverse()*Vector3.BACK)})
	pose("Stand",0,true)
	if character==33:
		pressure_trail=preload("res://scripts/recovered_leader_trail.gd").new();pressure_trail.light_color=Effects.energy_color(character);add_child(pressure_trail)
	for spec in BLADES.get(character,[]):
		var trail=preload("res://scripts/recovered_leader_trail.gd").new()
		trail.light_color=Effects.energy_color(character);trail.heavy_color=trail.light_color
		trail.opacity=.9;trail.lifetime=.18;trail.sample_interval=1.0/60
		add_child(trail)
		var original=preload("res://scripts/recovered_leader_trail.gd").new()
		original.name="OriginalBladeTrail";original.additive=true;original.light_color=trail.light_color;original.heavy_color=trail.heavy_color
		original.opacity=.65;original.lifetime=.18;original.sample_interval=1.0/60;add_child(original)
		blade_trails.append({"bone":skeleton.find_bone(spec[0]),"base":spec[1],"tip":spec[2],"trail":trail,"original":original})
	visibility_changed.connect(func():
		if not visible:
			for blade in blade_trails:blade.trail.clear();blade.original.clear()
			if pressure_trail!=null:pressure_trail.clear())

func physical_blade_segment(blade:Dictionary)->PackedVector3Array:
	var transform_=skeleton.global_transform*skeleton.get_bone_global_pose(blade.bone)
	return PackedVector3Array([transform_*blade.base,transform_*blade.tip])

func blade_segment(blade:Dictionary)->PackedVector3Array:
	var segment=physical_blade_segment(blade)
	if is_instance_valid(combat):
		var hero=combat.hero
		var reach=preload("res://scripts/warcraft_kit.gd").MELEE_REACH*hero.contact_size_multiplier()*hero.melee_reach_setting()*hero.pickup_multiplier("range")
		segment=preload("res://scripts/recovered_leader_trail.gd").extend_to_reach(segment,hero.global_position,reach)
	return segment

func native_clip(name_:String)->String:
	if character!=33:return name_
	return {"Stand":"Stand - 1","Stand Alternate":"Alternate Stand - 1","Stand Ready Alternate":"Alternate Ready","Walk Alternate":"Alternate Walk","Death Alternate":"Alternate Death"}.get(name_,name_)

func pose(name_:String,time:float,loop:bool=false):
	name_=native_clip(name_)
	body.transform=Transform3D.IDENTITY
	if character==32 and name_=="Stand Ready" and is_instance_valid(combat) and combat.hero.jumps_used==2 and not combat.hero.flying and combat.hero.dodge_time<=0 and locomotion.reference_jump_flip>=0:
		# Reuse Hero's torso-pivot somersault and second-jump clock at Musashi's pace.
		var turn=Basis(Vector3.RIGHT,-TAU*clampf(locomotion.reference_jump_flip*.42/FLIP_DURATION,0,1))
		var pivot=Vector3(0,1.4,0)
		body.transform=Transform3D(turn,pivot-turn*pivot)
	if clip!=name_:animation_player.play(name_);clip=name_;frame=-1
	var length=animation_player.get_animation(name_).length
	var at=fposmod(time,length) if loop and length>0 else clampf(time,0,maxf(0,length-.00001))
	skeleton.clear_bones_global_pose_override()
	animation_player.seek(at,true)
	face_glows()
	var next=mini(floori(at*30),motion.clips[name_].size()-1)
	if next==frame:return
	frame=next
	var sample:Dictionary=motion.clips[name_][frame]
	for i in meshes.size():
		var alpha=float(sample.opacity[i]);meshes[i].visible=alpha>.001
		if alpha>.001 and meshes[i].material_override.albedo_color.a!=alpha:meshes[i].material_override.albedo_color.a=alpha
	for i in skin_textures:
		var texture=skin_textures[i][1 if sample.get("avatar",0)>.5 else 0]
		if meshes[i].material_override.albedo_texture!=texture:meshes[i].material_override.albedo_texture=texture
	for i in live_particles:particles[i].hide()
	live_particles.clear()
	for p in sample.particles:
		var i=int(p[0]);var sprite:Sprite3D=particles[i]
		sprite.position=Vector3(p[1],p[3],-p[2]);sprite.scale=Vector3.ONE*maxf(.001,p[4])
		sprite.modulate=Color(p[6],p[7],p[8],p[5])
		if motion.particles[i].texture=="energy.png":sprite.modulate=Effects.energy_tint(character,sprite.modulate)
		sprite.frame=clampi(roundi(p[9]*sprite.hframes)+(sprite.vframes-1-roundi(p[10]*sprite.vframes))*sprite.hframes,0,sprite.hframes*sprite.vframes-1)
		sprite.show();live_particles.append(i)

func animate(delta:float,speed:float,_grounded:bool,_vertical:float,_attack:float,_heavy:bool,_combo:int,_dodge:bool):
	if pressure_trail!=null:pressure_trail.advance(delta,PackedVector3Array(),false,false)
	locomotion.update(delta,locomotion_velocity,_grounded,_vertical,0,_dodge)
	clock+=delta*(clampf(speed/7.0,.4,2.0) if speed>.25 else 1.0)
	if is_instance_valid(combat) and not combat.clip.is_empty():pose(combat.clip,combat.elapsed,combat.mode=="spin")
	else:pose(("Stand Ready" if not _grounded else "Walk" if speed>.25 else "Stand")+(" Alternate" if is_instance_valid(combat) and combat.demon else ""),clock,true)
	var cutting=is_instance_valid(combat) and combat.blade_active()
	for blade in blade_trails:
		blade.trail.advance(delta,blade_segment(blade) if cutting else PackedVector3Array(),cutting,false)
		blade.original.advance(delta,physical_blade_segment(blade) if cutting else PackedVector3Array(),cutting,false)

func animate_spell(_delta:float,_spell:Node):pose("Spell" if character==32 else "Spell Throw" if character==33 else "Stand Ready",0)
func _process(delta:float):
	if is_instance_valid(combat) and combat.active and combat.mode=="dead" and not combat.game.paused:
		combat.elapsed+=delta;pose(combat.clip,combat.elapsed)
func hand_position(_side:String="R")->Vector3:return global_position+Vector3.UP*1.6
func sync_skeleton():pass
func set_cloak(_equipped:bool,_gold:bool):pass
func combat_pose(_attack:float,_heavy:bool,_combo:int,_dodge:bool):pass
func set_surge(_active:bool):pass
func apply_skin(_id:String):pass

func face_glows():
	var camera=get_viewport().get_camera_3d()
	if camera==null:return
	var local=skeleton.global_basis.inverse()*camera.global_basis
	var facing=Basis(local.z,local.y,-local.x).orthonormalized()
	var normal=camera.global_basis.z;normal.y=0;normal=normal.normalized()
	var upright=skeleton.global_basis.inverse()*Basis(normal,Vector3.UP,normal.cross(Vector3.UP))
	upright=upright.orthonormalized()
	for entry in billboards:
		var transform_=skeleton.get_bone_global_pose(entry.bone)
		transform_.basis=((upright if entry.upright else facing)*entry.axes.inverse()).scaled(transform_.basis.get_scale())
		skeleton.set_bone_global_pose_override(entry.bone,transform_,1.0,true)

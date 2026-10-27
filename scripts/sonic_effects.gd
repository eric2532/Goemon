extends Node3D
## Retail SON_EFF geometry; a fixed set of shared meshes follows the existing skill owner.
const ROOT="res://assets/models/characters/sonic/"
const LIFE=.16
var aura:Node3D
var trails:Array[Node3D]=[]
var remaining=PackedFloat32Array()
var cursor=0
var clock=0.0

func _ready():
	top_level=true
	aura=load(ROOT+"effect_ball.glb").instantiate();add_child(aura)
	var trail_scene=load(ROOT+"effect_trail.glb")
	var materials:Dictionary={}
	for i in 8:
		var trail=trail_scene.instantiate();add_child(trail);trails.append(trail);remaining.append(0)
	for model in [aura]+trails:
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var source=mesh.get_active_material(0)
			if not materials.has(source):
				var material=source.duplicate()
				material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
				material.blend_mode=BaseMaterial3D.BLEND_MODE_MIX if model==aura else BaseMaterial3D.BLEND_MODE_ADD
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
				material.albedo_color.a=.32 if model==aura else .6
				materials[source]=material
			mesh.material_override=materials[source]
	clear()

func clear():
	aura.hide()
	for i in trails.size():trails[i].hide();remaining[i]=0
	cursor=0;clock=0

func advance(delta:float,hero:Hero,mode:String,charge:float):
	var spinning=mode in ["charge","roll","homing","jump"]
	aura.visible=spinning
	var size=hero.growth_multiplier()*1.3*hero.skill_factor(hero.attack_ticket,"size")
	aura.global_position=hero.global_position+Vector3.UP*1.08*(hero.growth_multiplier()-size)
	aura.rotation=Vector3(0,atan2(-hero.facing.x,-hero.facing.z),0)
	aura.scale=Vector3.ONE*size
	clock+=delta
	for i in trails.size():
		var previous=remaining[i]
		remaining[i]=maxf(0,remaining[i]-delta)
		trails[i].visible=remaining[i]>0
		if remaining[i]>0:trails[i].scale*=remaining[i]/previous
	if not spinning:return
	var moving=mode in ["roll","homing","jump"] and hero.velocity.length()>12
	if clock>=1.0/60 and (moving or mode=="charge"):
		clock=0
		var trail=trails[cursor]
		trail.global_position=hero.global_position
		trail.rotation=Vector3(0,atan2(-hero.facing.x,-hero.facing.z)+PI,0)
		if mode=="charge":trail.rotation.y+=cursor*TAU/8;trail.scale=Vector3.ONE*hero.growth_multiplier()*(.3+.4*minf(charge/10,1))
		else:trail.scale=Vector3.ONE*hero.growth_multiplier()
		remaining[cursor]=LIFE;trail.show();cursor=(cursor+1)%trails.size()

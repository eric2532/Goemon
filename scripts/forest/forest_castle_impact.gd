extends Node3D
## Two prepared emitters per castle; repeated hits restart their bounded particles.
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
var chips:CPUParticles3D
var dust:CPUParticles3D
var last_hit_ms=-1000

func setup(points:PackedVector3Array):
	name="CastleImpact"
	chips=CPUParticles3D.new();chips.name="StoneChips";chips.amount=24;chips.lifetime=.7
	chips.mesh=Meadow.source("buildings/stone_block")[0].mesh
	chips.direction=Vector3.UP;chips.spread=75;chips.gravity=Vector3(0,-22,0)
	chips.initial_velocity_min=3;chips.initial_velocity_max=9
	chips.scale_amount_min=.035;chips.scale_amount_max=.085
	chips.angular_velocity_min=-180;chips.angular_velocity_max=180
	dust=CPUParticles3D.new();dust.name="MasonryDust";dust.amount=64;dust.lifetime=1.4
	dust.direction=Vector3.UP;dust.spread=70;dust.gravity=Vector3(0,.4,0)
	dust.initial_velocity_min=1;dust.initial_velocity_max=4
	dust.scale_amount_min=.8;dust.scale_amount_max=2
	var quad=QuadMesh.new();quad.size=Vector2(2,2)
	var fade=Gradient.new();fade.offsets=PackedFloat32Array([0,.45,1]);fade.colors=PackedColorArray([Color(1,1,1,.5),Color(1,1,1,.3),Color(1,1,1,0)])
	var texture=GradientTexture2D.new();texture.gradient=fade;texture.width=32;texture.height=32
	texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(.5,0)
	var material=StandardMaterial3D.new();material.albedo_texture=texture;material.albedo_color=Color("b6ab91")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.billboard_keep_scale=true
	material.vertex_color_use_as_albedo=true;dust.color_ramp=fade;quad.material=material;dust.mesh=quad
	for emitter in [chips,dust]:
		emitter.emitting=false;emitter.one_shot=true;emitter.explosiveness=.95;emitter.local_coords=false
		emitter.emission_points=points;emitter.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(emitter)

func play(point:Vector3,destroyed:bool,whole_castle:bool=true):
	var now=Time.get_ticks_msec()
	if not destroyed and now-last_hit_ms<90:return
	last_hit_ms=now
	position=Vector3.ZERO if destroyed and whole_castle else point
	for emitter in [chips,dust]:
		emitter.emission_shape=CPUParticles3D.EMISSION_SHAPE_POINTS if destroyed and whole_castle else CPUParticles3D.EMISSION_SHAPE_POINT
	dust.scale_amount_min=(5 if whole_castle else 1.2) if destroyed else .8
	dust.scale_amount_max=(11 if whole_castle else 3.2) if destroyed else 2
	chips.scale_amount_min=.1 if destroyed else .035;chips.scale_amount_max=.25 if destroyed else .085
	chips.restart();dust.restart()

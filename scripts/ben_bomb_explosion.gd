extends Node3D
## Actor30B's30-tick CLUT phase, followed by four original shared-effect23 sprites.
## Original tick counts are exact;30Hz and source-unit/world mapping follow this port.
const DANGER=preload("res://assets/characters/recovered_leaders/ben/bomb_danger_atlas.png")
const EXPLOSION=preload("res://assets/characters/recovered_leaders/ben/bomb_explosion_atlas.png")
const ADDITIVE=preload("res://assets/characters/recovered_leaders/ben/source_explosion.gdshader")
var body: Sprite3D
var age=0.0
var terminal_started=false
var clouds: Array[Sprite3D]=[]

func advance(delta: float)->bool:
	age+=delta
	# A state transition plays940 while the flight image is still present. On the
	# next tick,29remaining maps through the source remainder table to CLUTrow9.
	var tick=int(floor(age*30.0+.00001))
	if tick<30:
		if tick>0:
			body.texture=DANGER;body.hframes=10;body.frame=posmod(30-tick,10)
			body.material_override.set_shader_parameter("albedo_texture",DANGER)
		return false
	if not terminal_started:_begin_terminal()
	var frame=tick-30
	for cloud in clouds:cloud.frame=mini(frame,9)
	return tick>=40

func _begin_terminal():
	terminal_started=true;body.hide()
	for i in range(4):
		var sprite=Sprite3D.new();sprite.name="SourceBombExplosion%d"%i
		sprite.texture=EXPLOSION;sprite.hframes=10
		# Original quad31units, animation32texels, scale0x7000/0x1000=7.
		sprite.pixel_size=31.0/32.0*.01*7.0
		# Descriptor80183664: corners(-16,-16)..(15,15), not a bottom anchor.
		# The half-source-unit center becomes(-.035,+.035) after PSX Y flip.
		sprite.offset=Vector2(-16,16)/31.0
		sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.position=Vector3(randi_range(-80,79),randi_range(0,159),randi_range(-80,79))*.01
		var material=body.material_override.duplicate() as ShaderMaterial
		material.shader=ADDITIVE;material.set_shader_parameter("albedo_texture",EXPLOSION)
		material.set_shader_parameter("billboard",true)
		sprite.material_override=material
		add_child(sprite);clouds.append(sprite)

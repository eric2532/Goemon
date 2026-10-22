extends Node3D
## Native actor30A/TMD80192B24 with its original five animated blue bands.
const NativeState=preload("res://scripts/recovered_ed_beam_native_state.gd")
var hero: Hero
var age=0.0
var material: ShaderMaterial
var releasing := false
var release_age := 0.0
var native_phase_state: RefCounted
var native_ticks=0
var native_release_base=0

func _ready():
 name="EdOriginalBlueShield";add_to_group("ed_beam_shields")
 if not hero.has_meta(NativeState.META):hero.set_meta(NativeState.META,NativeState.new())
 native_phase_state=hero.get_meta(NativeState.META)
 var visual=preload("res://assets/characters/recovered_leaders/ed/beam_shield.glb").instantiate();add_child(visual)
 material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_leaders/ed/beam_shield.gdshader")
 material.set_shader_parameter("native_normals",preload("res://assets/characters/recovered_leaders/ed/beam_shield_normals.png"))
 for mesh in visual.find_children("*","MeshInstance3D",true,false):
  mesh.layers=0;mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 advance(0)

func begin_release():
 if releasing:return
 releasing=true
 release_age=0.0
 native_release_base=native_ticks+1
 advance(0)

func advance(delta: float):
 age+=maxf(0,delta)
 if releasing:release_age+=maxf(0,delta)
 # Owner state6 is visible for transition plus15 subsequent updates; at16
 # the owner enters recovery before this child runs (80181D7C/801828A0).
 var ticks=native_release_base+mini(15,floori(release_age*30.0+.000001)) if releasing else maxi(1,floori(age*30.0+.000001)+1)
 if ticks>native_ticks:native_phase_state.shield_updates+=ticks-native_ticks;native_ticks=ticks
 var fit=preload("res://scripts/character_proportions.gd").ED_HEIGHT/1.8
 if is_instance_valid(hero.model) and is_instance_valid(hero.model.rig_visual):fit=hero.model.rig_visual.scale.x
 # This node is parented to the scaled hero; native world scale applies growth once.
 # The source shield actor retains zero rotation rather than copying Ed's yaw.
 global_basis=Basis.IDENTITY.scaled(Vector3.ONE*.01*fit*hero.growth_multiplier()*clampf(float(native_ticks)/4,.25,1))
 material.set_shader_parameter("native_scale",Vector3.ONE*clampf(float(native_ticks)/4,.25,1))
 # Existing shader derives the persistent phase from floor(clock*30)+1.
 # Use a point inside the integer tick to avoid floating-point boundary drift.
 material.set_shader_parameter("clock",(float(posmod(native_phase_state.shield_updates-1,1536))+.25)/30.0)
 material.set_shader_parameter("release_tick",mini(16,1+floori(release_age*30.0+.000001)) if releasing else 0)
 var environment=get_world_3d().environment
 if environment:
  material.set_shader_parameter("compensate_filmic",environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC)
  material.set_shader_parameter("scene_exposure",environment.tonemap_exposure);material.set_shader_parameter("scene_white",environment.tonemap_white)

func native_phase()->int:return native_phase_state.shield_phase()
func native_phase_updates()->int:return native_phase_state.shield_updates

extends RefCounted
## Retail module 0x72 motions/markers; world travel and damage fit Goemon combat.
const ROLE=17
const PLAYER=29
const SCALE=3.0
const CLAW_TEMPO=3.0
const MOVE_SPEED=6.0
const LEAP_SPEED=160.0
const LEAP_RISE_GRAVITY=320.0
const LEAP_FALL_GRAVITY=720.0
const HEALTH=5000.0
const ATTACK_RANGE=2.0
const FIRE_TEMPO=2.0
const FIRE_SCALE=9.0
const CLAW=0
const FIRE=1
const SLAM=2
const GRAB=3
const REST=4
const SPIN=5
const SPIN_CLIPS=["Source__801f1898","Source__801f1978"]
const HURT_CLIP="Source__801f0798"
const SPIN_START=7
const SPIN_END=25
const SPIN_RADIUS=4.8*SCALE*ATTACK_RANGE
const WALK_TICKS=80.0
const STEP_TICKS=[15,53]
const SOUND_RANGE=65.0*SCALE
const CLIPS=["Source__801f1198","Source__801a6544","Source__801f0478","Source__801f1340","Source__801a63fc",SPIN_CLIPS[0]]
const FIRE_TICKS=[47,55.5,64,72.5,81,89.5]
const CLAW_TICK=13
const GRAB_TICKS=[62,134]
const SLAM_TICK=54
const FIRE_SPEED=8.64*3.0*2.0
const FIRE_LIFE=3.5
const FIRE_RADIUS=.65*FIRE_SCALE
const FIRE_SPREAD=400.0/4096*TAU
const SHOCK_RADIUS=12.0*SCALE*ATTACK_RANGE
const SHOCK_DELAY=.3
const MOUTH=Vector3(0,3.5,-3.1)*SCALE
# Native indices 1–3 are fire start, interval and pair count; 21–22 are tempo/reach.
static func native()->PackedFloat64Array:
 return PackedFloat64Array([CLAW_TICK,FIRE_TICKS[0],FIRE_TICKS[1]-FIRE_TICKS[0],FIRE_TICKS.size(),GRAB_TICKS[0],GRAB_TICKS[1],SLAM_TICK,FIRE_SPEED,FIRE_LIFE,FIRE_RADIUS,FIRE_SPREAD,SHOCK_RADIUS,SHOCK_DELAY,MOUTH.x,MOUTH.y,MOUTH.z,SCALE,CLAW_TEMPO,LEAP_SPEED,LEAP_RISE_GRAVITY,LEAP_FALL_GRAVITY,FIRE_TEMPO,ATTACK_RANGE])

static func spin_turn(tick:float)->float:
 # Retail 801A146C: wind back 112 units at tick 4, then 240/tick on 7–24.
 return ((-112 if tick>=4 else 0)+240*clampi(floori(tick)-6,0,18))*TAU/4096.0

static func steps_between(before:float,after:float)->int:
 var count=0
 for tick in STEP_TICKS:count+=floori((after-tick)/WALK_TICKS)-floori((before-tick)/WALK_TICKS)
 return count

static func native_spin(resource:Resource)->PackedFloat32Array:
 var result=PackedFloat32Array();var clips:Dictionary=resource.get_meta("clips")
 for tick in 28:
  result.append_array(PackedFloat32Array([clips[SPIN_CLIPS[0]].rows[mini(tick,26)],clips[SPIN_CLIPS[1]].rows[mini(tick,26)],spin_turn(tick)]))
 return result

const SOUND_DIR="res://assets/characters/recovered_monsters/audio/dark_lumina_2/"
const FX_DIR="res://assets/characters/recovered_monsters/dark_lumina_2_effects/"
static var sounds={}
static var meshes={}
static func prepare():
 if not sounds.is_empty():return
 for cue in ["slam","step","fire_release","hurt","claw","breath","breakup","effect","throw","grab","contact_a","contact_b","fire_impact","recover","fire_charge","death","throw_layer","throw_full","death_final","effect_b","hit","hit_strong"]:sounds[cue]=load(SOUND_DIR+cue+".wav")
 # B56 is the spin's layered cry; retain the historical hurt slot and its takes.
 sounds.spin=sounds.hurt
 var debris=QuadMesh.new();debris.size=Vector2.ONE*48*.018*SCALE
 var debris_material=ShaderMaterial.new();debris_material.shader=preload("res://assets/characters/recovered_monsters/dark_lumina_2_effects/spin_debris.gdshader")
 debris_material.set_shader_parameter("atlas",load(FX_DIR+"spin_debris.png"));debris.material=debris_material;meshes.spin_debris=debris
 for key in ["fire","impact","ember"]:
  var mesh=QuadMesh.new();mesh.size=Vector2(2.3,4.6 if key=="impact" else 2.3)*FIRE_SCALE
  var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_skullpion/effects/volley.gdshader")
  # shortcut: charge reuses intact source flames until its original ember VRAM page is recovered.
  material.set_shader_parameter("atlas",load(FX_DIR+("fire" if key=="ember" else key)+".png"));material.set_shader_parameter("frames",16.0);material.set_shader_parameter("billboard",true);material.set_shader_parameter("instanced",true);material.set_shader_parameter("opacity_scale",1.0);mesh.material=material;meshes[key]=mesh
 for key in ["shock_dome","shock_ring","fragment","stomp_wave"]:
  var authored="res://assets/models/enemies/recovered_monsters/dark_lumina_2_effects/"+key+".glb"
  var scene=load(authored if FileAccess.file_exists(authored) else FX_DIR+key+".glb").instantiate()
  var source:MeshInstance3D=scene.find_children("*","MeshInstance3D",true,false)[0]
  meshes[key]=source.mesh;scene.free()
  if key=="stomp_wave":
   meshes[key]=meshes[key].duplicate()
   var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_monsters/dark_lumina_2_effects/stomp_wave.gdshader")
   material.set_shader_parameter("wave_texture",load(FX_DIR+"stomp_wave.png"))
   for surface in meshes[key].get_surface_count():meshes[key].surface_set_material(surface,material)
  if key in ["shock_dome","shock_ring"]:
   # Actor 801A5C34 sets 0x50000000 (additive), beyond the TMD transparency flag.
   meshes[key]=meshes[key].duplicate()
   for surface in meshes[key].get_surface_count():
    var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_monsters/dark_lumina_2_effects/energy_mesh.gdshader")
    meshes[key].surface_set_material(surface,material)

static func slot_for(cue:String)->String:return cue if cue in ["hurt","death"] else "dark_lumina_2_"+cue
static func slot_labels()->Dictionary:
 var result={}
 for cue in ["slam","step","fire_release","hurt","claw","breath","breakup","effect","throw","grab","contact_a","contact_b","fire_impact","recover","fire_charge","death","throw_layer","throw_full","death_final","effect_b","hit","hit_strong"]:result[slot_for(cue)]=cue.replace("_"," ").capitalize()
 result[slot_for("spin")]="Spin attack"
 result[slot_for("slam")]="Stomp landing"
 return result
static func stream_for(slot:String)->AudioStream:
 prepare()
 return sounds.get(slot.trim_prefix("dark_lumina_2_"))

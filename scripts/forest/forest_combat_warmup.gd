extends Node
## Render real combat materials in an isolated, undisplayed viewport at load.
## No attacks, damage, audio, physics or gameplay random numbers run here.
signal finished
const Effects=preload("res://assets/rogue/scripts/effects.gd")
static var warmed_msaa=-1
static var prepared_materials:Array=[]
var complete=false
var viewport:SubViewport
var drawn_frames=0
var warmup_msaa=-1
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 if DisplayServer.get_name()=="headless" or warmed_msaa==int(get_viewport().msaa_3d):
  complete=true;finished.emit();return
 warm.call_deferred()
func warm():
 warmup_msaa=int(get_viewport().msaa_3d)
 viewport=SubViewport.new();viewport.name="CombatGraphicsWarmup";viewport.size=Vector2i(64,64)
 viewport.own_world_3d=true;viewport.msaa_3d=warmup_msaa;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var camera=Camera3D.new();world.add_child(camera)
 camera.position=Vector3(12,16,26);camera.look_at(Vector3(0,3,0))
 populate_samples(world)
 # StandardMaterial3D retires its generated shader when its last material is
 # freed. Keep these few materials across map restarts, without drawing them.
 prepared_materials.clear()
 for node in world.find_children("*","GeometryInstance3D",true,false):
  if node.material_override!=null:prepared_materials.append(node.material_override)
 # Let the real material/mesh combinations submit before retiring the samples.
 # This runs during preparation, including while the game tree is paused.
 RenderingServer.frame_post_draw.connect(_after_draw,CONNECT_DEFERRED)
func _after_draw():
 if viewport==null:return
 drawn_frames+=1
 if drawn_frames<6:return
 RenderingServer.frame_post_draw.disconnect(_after_draw)
 var retired=viewport;viewport=null;retired.queue_free()
 retired.tree_exited.connect(_retired,CONNECT_DEFERRED|CONNECT_ONE_SHOT)
func _retired():
 warmed_msaa=warmup_msaa;complete=true;finished.emit()
func _exit_tree():
 if RenderingServer.frame_post_draw.is_connected(_after_draw):RenderingServer.frame_post_draw.disconnect(_after_draw)
func populate_samples(world:Node3D):
 warm_soldiers(world)
 var fx=Effects.new();fx.army_trails=true;fx.apply_quality(0);world.add_child(fx)
 for kind in ["ranger-arrow","ranger-power-arrow","star","bolt","wave","bullet"]:
  fx.add_child(fx.create_projectile(kind,Color("9bcfff")))
 # Army arrows use a separate vertex-color ribbon without mesh normals.
 fx.ranger_trail({"color":Color("9bcfff"),"rangeScale":1.0,"vel":Vector3(0,0,60)},Vector3(0,2,-2),Vector3(0,2,2))
 fx.slash(Vector3.ZERO,0);fx.thrust(Vector3.ZERO,0)
 fx.ninja_finisher(Vector3.ZERO,0,4,2,1,1)
 fx.knight_shield_pulse(Vector3.ZERO,0,1,0)
 fx.lance_wave(Vector3.ZERO,3,0)
 fx.dragon_eruption(Vector3.ZERO,0,.2)
 fx.add_child(fx._dragon_mesh("WarmDivingDragon",.25,true))
 var ribbon=preload("res://assets/rogue/scripts/magic_sword_brush.gd").new();fx.add_child(ribbon)
 ribbon.sample_blade(Vector3(-2,1,0),Vector3(-2,5,0));ribbon.sample_blade(Vector3(2,1,0),Vector3(2,5,0))
 # Use the spark renderer directly; spawning particles would consume game RNG.
 var sparks=MultiMeshInstance3D.new();sparks.name="WarmImpactSparks";sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 sparks.multimesh=MultiMesh.new();sparks.multimesh.transform_format=MultiMesh.TRANSFORM_3D;sparks.multimesh.use_colors=true
 sparks.multimesh.mesh=fx.spark_geometry;sparks.multimesh.instance_count=1;sparks.material_override=fx.burst_material
 sparks.multimesh.set_instance_transform(0,Transform3D.IDENTITY);sparks.multimesh.set_instance_color(0,Color.WHITE);world.add_child(sparks)
 var label=Label3D.new();label.text="999";label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true
 label.font_size=86;label.outline_size=10;label.pixel_size=.0065;label.position=Vector3(0,5,0);world.add_child(label)

func warm_soldiers(world:Node3D):
 var soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
 for role in [0,1,3]:
  var source=soldier.data(role);var batch=MultiMeshInstance3D.new();batch.name="WarmSoldier_%d"%role
  batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_custom_data=true
  batch.multimesh.mesh=soldier.make_mesh(role);batch.multimesh.instance_count=1;batch.multimesh.custom_aabb=source.get_meta("bounds")
  var state=soldier.frame_state({"variant":role,"velocity":Vector3.ZERO,"soldier_pose_tick":12})
  batch.multimesh.set_instance_custom_data(0,Color(state.row,0,0,0));batch.position.x=([0,1,3].find(role)-1)*8
  batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(batch)
 var bullet=preload("res://assets/characters/thirstquencher/projectiles/bullet.glb").instantiate();bullet.name="WarmSoldierBullet";bullet.scale=Vector3.ONE*soldier.SCALE;bullet.position=Vector3(0,5,0);world.add_child(bullet)
 var casing=preload("res://assets/characters/thirstquencher/projectiles/casing.glb").instantiate();casing.name="WarmSoldierCasing";casing.scale=Vector3.ONE*soldier.SCALE;casing.position=Vector3(0,3,0);world.add_child(casing)

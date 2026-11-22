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
 var source=get_parent().get("world")
 if source is Node3D:
  # Directional lights and the environment select different rendering pipeline variants.
  var environment_=WorldEnvironment.new();environment_.environment=source.get_world_3d().environment;world.add_child(environment_)
  for child in source.get_children():
   if child is DirectionalLight3D:world.add_child(child.duplicate())
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
 # Let deferred render-resource retirement finish before callers start combat.
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 if not is_inside_tree():return
 warmed_msaa=warmup_msaa;complete=true;finished.emit()
func _exit_tree():
 if RenderingServer.frame_post_draw.is_connected(_after_draw):RenderingServer.frame_post_draw.disconnect(_after_draw)
func populate_samples(world:Node3D):
 warm_soldiers(world)
 warm_boss_effects(world)
 var wind=MultiMeshInstance3D.new();wind.name="WarmMeleeWind"
 wind.multimesh=MultiMesh.new();wind.multimesh.transform_format=MultiMesh.TRANSFORM_3D;wind.multimesh.use_custom_data=true
 wind.multimesh.mesh=preload("res://scripts/forest/crowd/army_presentation.gd").prepare_melee_wind();wind.multimesh.instance_count=1
 wind.multimesh.set_instance_transform(0,Transform3D(Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP).scaled_local(Vector3(4,3,1)),Vector3(0,2,0)))
 wind.multimesh.set_instance_custom_data(0,Color(.2,1,.1,PI/4));world.add_child(wind)
 var fx=Effects.new();fx.army_trails=true;fx.apply_quality(0);world.add_child(fx)
 for kind in ["ranger-arrow","ranger-power-arrow","star","bolt","wave","bullet","dragon"]:
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
 # Bitmap combat numbers and fixed-size labels use different pipelines from the default font.
 var presentation=preload("res://scripts/forest/crowd/army_presentation.gd")
 for font in [presentation.DAMAGE_FONT,presentation.HEAL_FONT,presentation.BATTLE_TEXT_FONT,ThemeDB.fallback_font]:
  var text=Label3D.new();text.font=font;text.text="0123456789";text.font_size=36;text.outline_size=0
  text.fixed_size=true;text.billboard=BaseMaterial3D.BILLBOARD_ENABLED;text.no_depth_test=true
  text.pixel_size=.00065;text.position=Vector3(0,3,0);text.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(text)
  if font==presentation.BATTLE_TEXT_FONT:
   text.text="崩擊 · Release X";text.outline_size=5;text.pixel_size=.0012
  elif font==ThemeDB.fallback_font:
   text.text="!";text.font_size=58;text.outline_size=8;text.pixel_size=.001
 var player=get_parent().get("player")
 if is_instance_valid(player) and is_instance_valid(player.timed_dodge):
  var mark=player.timed_dodge.mark.duplicate();mark.position=Vector3(0,4,0);mark.show();world.add_child(mark)
 var crowd=get_parent().get("crowd")
 if crowd!=null and is_instance_valid(crowd.army):
  # Use the live mesh/material contracts, including the selected pet atlas and health vertices.
  var meshes=crowd.army.meshes.values()+[crowd.army.health.multimesh.mesh]
  for batch in crowd.army.presentation.batches.values():meshes.append(batch.multimesh.mesh)
  for mesh in meshes:
   var batch=MultiMeshInstance3D.new();batch.name="WarmCurrentArmy"
   batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_custom_data=true
   batch.multimesh.mesh=mesh;batch.multimesh.instance_count=1
   batch.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(0,2,0)))
   batch.multimesh.set_instance_custom_data(0,Color(0,0,0,0))
   batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(batch)
   preload("res://scripts/forest/crowd/hound_sprites.gd").apply_world_scale(batch,get_parent().model)
   if mesh==crowd.army.meshes.get(preload("res://scripts/forest/forest_enemy_roles.gd").SLIME):batch.set_instance_shader_parameter("map_enemy_scale",preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE)

func warm_boss_effects(world:Node3D):
 for kit in [preload("res://scripts/forest/dark_lumina_kit.gd"),preload("res://scripts/forest/dark_lumina_3_kit.gd")]:
  kit.prepare()
  for key in kit.meshes:
   var mesh:Mesh=kit.meshes[key];var bounds=mesh.get_aabb()
   var size_=6.0/maxf(.001,maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)))
   var sample=MultiMeshInstance3D.new();sample.name="WarmBoss_"+str(kit.ROLE)+"_"+key
   sample.multimesh=MultiMesh.new();sample.multimesh.transform_format=MultiMesh.TRANSFORM_3D;sample.multimesh.use_custom_data=true
   sample.multimesh.mesh=mesh;sample.multimesh.instance_count=1
   sample.multimesh.set_instance_transform(0,Transform3D.IDENTITY);sample.multimesh.set_instance_custom_data(0,Color(2.4,1,0,0))
   sample.scale=Vector3.ONE*size_;sample.position=Vector3(0,3,0)-bounds.get_center()*size_
   sample.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(sample)

func warm_soldiers(world:Node3D):
 var soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
 var roles=preload("res://scripts/forest/forest_enemy_roles.gd")
 for role in roles.NATIVE_TYPES:
  var batch=MultiMeshInstance3D.new();batch.name="WarmSoldier_%d"%role
  batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_custom_data=true
  if role in [roles.GATEKEEPER_HOUND,roles.CAVE_BEAR]:
   batch.multimesh.mesh=preload("res://scripts/forest/crowd/habaru_sprites.gd").make_mesh() if role==roles.CAVE_BEAR else preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh()
   batch.multimesh.custom_aabb=preload("res://scripts/forest/crowd/habaru_sprites.gd").BODY if role==roles.CAVE_BEAR else AABB(Vector3(-3,-1,-3),Vector3(6,6,6));batch.multimesh.instance_count=1
  else:
   batch.multimesh.mesh=soldier.make_mesh(role);batch.multimesh.custom_aabb=soldier.data(role).get_meta("bounds");batch.multimesh.instance_count=1
   var state=soldier.frame_state({"variant":role,"velocity":Vector3.ZERO,"soldier_pose_tick":12})
   batch.multimesh.set_instance_custom_data(0,Color(state.row,0,0,0))
  batch.position.x=(roles.NATIVE_TYPES.find(role)-2)*8
  batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(batch)
 var bullet=load(GameAssets.model_path("res://assets/characters/thirstquencher/projectiles/bullet.glb")).instantiate();bullet.name="WarmSoldierBullet";bullet.scale=Vector3.ONE*soldier.SCALE;bullet.position=Vector3(0,5,0);world.add_child(bullet)
 var casing=load(GameAssets.model_path("res://assets/characters/thirstquencher/projectiles/casing.glb")).instantiate();casing.name="WarmSoldierCasing";casing.scale=Vector3.ONE*soldier.SCALE;casing.position=Vector3(0,3,0);world.add_child(casing)

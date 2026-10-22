extends SceneTree
## Compare the batched vertex animation to Godot's original GLB skinning.
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var checks=0
var failures=0
var scene:Node3D
var camera:Camera3D
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func frames():
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
func white_shader()->Shader:
 var code=FileAccess.get_file_as_string("res://assets/materials/thirstquencher_crowd.gdshader")
 code=code.substr(0,code.find("void fragment(){"))+"void fragment(){ALBEDO=vec3(1.0);}\n"
 var shader=Shader.new();shader.code=code;return shader
func mask(image:Image)->PackedByteArray:
 var result=PackedByteArray();result.resize(image.get_width()*image.get_height())
 for y in image.get_height():
  for x in image.get_width():
   var c=image.get_pixel(x,y);result[y*image.get_width()+x]=1 if c.r>.5 and c.g>.5 and c.b>.5 else 0
 return result
func run():
 root.size=Vector2i(640,480);root.msaa_3d=Viewport.MSAA_DISABLED
 scene=Node3D.new();root.add_child(scene)
 var world=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color.BLACK;scene.add_child(world)
 camera=Camera3D.new();scene.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=18;camera.position=Vector3(12,7.8,21);camera.look_at(Vector3(0,3,0))
 for role in [0,1,3]:
  var resource=Soldier.data(role);var packed=load(Soldier.DIR+"soldier_%d.glb"%Soldier.ROLE_TO_TYPE[role])
  var original:Node3D=packed.instantiate();scene.add_child(original);original.basis=Basis(Vector3.UP,PI).scaled(Vector3.ONE*Soldier.SCALE)
  var player:AnimationPlayer=original.find_child("AnimationPlayer",true,false);player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var skeleton:Skeleton3D=original.find_child("Skeleton3D",true,false)
  var white=StandardMaterial3D.new();white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;white.cull_mode=BaseMaterial3D.CULL_DISABLED
  for mesh in original.find_children("*","MeshInstance3D",true,false):mesh.material_override=white
  var animated=MultiMeshInstance3D.new();animated.multimesh=MultiMesh.new();animated.multimesh.transform_format=MultiMesh.TRANSFORM_3D;animated.multimesh.use_custom_data=true
  var batch_mesh:Mesh=resource.get_meta("mesh").duplicate()
  for slot in batch_mesh.get_surface_count():
   var material=ShaderMaterial.new();material.shader=white_shader();material.set_shader_parameter("pose_texture",resource.get_meta("pose_texture"));batch_mesh.surface_set_material(slot,material)
  animated.multimesh.mesh=batch_mesh;animated.multimesh.instance_count=1;animated.multimesh.custom_aabb=resource.get_meta("bounds");scene.add_child(animated)
  var semantic:Dictionary=resource.get_meta("semantics")
  var samples=[[semantic.idle,0],[semantic.run,7],[semantic.attack[0],13],[semantic.death,6]]
  for sample in samples:
   var clip:String=sample[0];var tick:int=sample[1];var row:int=resource.get_meta("clips")[clip].rows[tick]
   player.play(clip);player.seek(float(tick)/30,true);skeleton.force_update_all_bone_transforms()
   animated.hide();original.show();await frames();var reference=mask(root.get_texture().get_image())
   original.hide();animated.show();animated.multimesh.set_instance_transform(0,Transform3D.IDENTITY);animated.multimesh.set_instance_custom_data(0,Color(row,0,0,0));await frames()
   var result=mask(root.get_texture().get_image());var union=0;var same=0
   for index in result.size():
    if result[index]!=0 or reference[index]!=0:union+=1
    if result[index]!=0 and reference[index]!=0:same+=1
   var overlap=float(same)/maxi(1,union)
   print("SOLDIER_GPU_SKIN role=",role," clip=",clip," tick=",tick," pixels=",union," overlap=",overlap)
   check(union>300 and overlap>.99,"GPUposes match original GLBskinning (%d/%s)"%[role,clip])
  original.queue_free();animated.queue_free();await process_frame
 scene.queue_free();await process_frame
 print("THIRSTQUENCHER_VISUAL_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

extends SceneTree
## Render actual atlas samples in an unlit world; only designated circuits glow.
func _initialize():run.call_deferred()
func run():
 if DisplayServer.get_name()=="headless":quit(2);return
 root.size=Vector2i(400,200);Engine.max_fps=60
 var world=Node3D.new();root.add_child(world)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color.BLACK
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.BLACK;environment.environment.ambient_light_energy=0
 world.add_child(environment)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2
 world.add_child(camera);camera.position=Vector3(0,0,5);camera.look_at(Vector3.ZERO);camera.current=true
 var atlas=load("res://assets/textures/enemies/neon_set/neon_atlas.png")
 var material=ShaderMaterial.new();material.shader=load("res://assets/materials/original_enemy_crowd.gdshader")
 material.set_shader_parameter("atlas",atlas);material.set_shader_parameter("neon_style",true)
 var samples=[Vector2(.375,.125),Vector2(.375,.625),Vector2(.875,.875),Vector2(.125,.125)]
 for i in range(4):
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for corner in [Vector3(-.3,-.3,0),Vector3(.3,-.3,0),Vector3(.3,.3,0),Vector3(-.3,-.3,0),Vector3(.3,.3,0),Vector3(-.3,.3,0)]:
   tool.set_normal(Vector3.BACK);tool.set_uv(samples[i]);tool.set_uv2(Vector2.ZERO);tool.add_vertex(corner)
  var mesh=MeshInstance3D.new();mesh.mesh=tool.commit();mesh.material_override=material
  world.add_child(mesh);mesh.position.x=-1.2+i*.8
 for i in range(20):await process_frame
 await RenderingServer.frame_post_draw
 var picture=root.get_texture().get_image();var failures=0
 for i in range(4):
  var pixel=picture.get_pixel(int(picture.get_width()*(.2+i*.2)),picture.get_height()/2)
  var ok=pixel.get_luminance()>.12 if i<3 else pixel.get_luminance()<.03
  if not ok:failures+=1;push_error("FAIL: emission swatch "+str(i)+" "+str(pixel))
  else:print("PASS: emission swatch ",i," ",pixel)
 print("NEON_EMISSION_RESULT checks=4 failures=",failures)
 world.queue_free();await process_frame;quit(1 if failures else 0)

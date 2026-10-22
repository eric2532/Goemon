extends SceneTree
## Render regression: treating legacy COLOR_0 as linear must fail these source RGB fixtures.
## Run with the Metal renderer (not --headless); --old demonstrates the regression.
const OUTPUT = "/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Ed and Ben/Color Verification"
const CASES = [
 {"name":"ben_green_vertex", "rgb":Vector3i(138,170,61)},
 {"name":"ben_skin_vertex", "rgb":Vector3i(242,202,154)},
 {"name":"ben_boot_vertex", "rgb":Vector3i(104,76,55)},
 {"name":"ben_cloth_vertex", "rgb":Vector3i(79,100,80)},
 {"name":"ed_hair_texture", "rgb":Vector3i(90,99,74), "texture":true},
 {"name":"ed_dark_texture", "rgb":Vector3i(41,41,33), "texture":true},
 {"name":"display_modulation", "rgb":Vector3i(90,90,80), "texture_rgb":Vector3i(180,120,80), "vertex":Vector3(.5,.75,1)},
 {"name":"source_tint", "rgb":Vector3i(110,85,61), "vertex":Vector3(138.0/255,170.0/255,61.0/255), "tint":Color(.8,.5,1)}
]
func _initialize(): run.call_deferred()
func run():
 var old = "--old" in OS.get_cmdline_user_args()
 var label_ = "before" if old else "after"
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 root.size=Vector2i(640,320)
 root.content_scale_size=Vector2i.ZERO
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var world=WorldEnvironment.new();var env=Environment.new();world.environment=env
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("1b2025")
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=1.05;env.tonemap_white=1.0
 stage.add_child(world)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.5
 camera.position=Vector3(0,0,5);stage.add_child(camera);camera.make_current()
 var shader_path="res://assets/characters/recovered_musashi/reference_palette.gdshader" if old else "res://assets/characters/recovered_leaders/source_palette.gdshader"
 var shader=load(shader_path) as Shader
 if shader==null:push_error("Palette shader did not load: "+shader_path);quit(2);return
 var centers=[]
 for i in CASES.size():
  var fixture:Dictionary=CASES[i];var rgb:Vector3i=fixture.rgb
  var raw:Vector3=fixture.get("vertex",Vector3(rgb)/255.0)
  var has_texture:bool=fixture.get("texture",false) or fixture.has("texture_rgb")
  if fixture.get("texture",false):raw=Vector3.ONE
  var color=Color(raw.x,raw.y,raw.z,1)
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.5,-.4,0),Vector3(.5,-.4,0),Vector3(.5,.4,0),Vector3(-.5,.4,0)])
  arrays[Mesh.ARRAY_COLOR]=PackedColorArray([color,color,color,color])
  arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
  arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var mat=ShaderMaterial.new();mat.shader=shader
  mat.set_shader_parameter("tint_color",fixture.get("tint",Color.WHITE));mat.set_shader_parameter("textured",has_texture)
  mat.set_shader_parameter("compensate_filmic",true);mat.set_shader_parameter("scene_exposure",1.05);mat.set_shader_parameter("scene_white",1.0)
  if has_texture:
   var tex_rgb:Vector3i=fixture.get("texture_rgb",rgb)
   var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color(float(tex_rgb.x)/255,float(tex_rgb.y)/255,float(tex_rgb.z)/255,1))
   mat.set_shader_parameter("albedo_texture",ImageTexture.create_from_image(image))
  var quad=MeshInstance3D.new();quad.mesh=mesh;quad.material_override=mat
  quad.position=Vector3((float(i%4)-1.5)*1.25,.6-float(i/4)*1.2,0);stage.add_child(quad);centers.append(quad.position)
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image();image.save_png(OUTPUT+"/palette_"+label_+".png")
 var results=[];var failures=0
 for i in CASES.size():
  var screen=camera.unproject_position(centers[i]);var sample=image.get_pixel(int(screen.x),int(screen.y))
  var actual=Vector3i(roundi(sample.r*255),roundi(sample.g*255),roundi(sample.b*255));var expected:Vector3i=CASES[i].rgb
  var difference=(actual-expected).abs();var error=maxi(difference.x,maxi(difference.y,difference.z));failures+=int(error>3)
  results.append({"case":CASES[i].name,"expected":[expected.x,expected.y,expected.z],"actual":[actual.x,actual.y,actual.z],"max_channel_error":error})
 var report={"result":"PASS" if failures==0 else "FAIL","shader":shader_path,"forest_filmic_exposure":1.05,"forest_filmic_white":1.0,"tolerance":3,"failed_cases":failures,"cases":results}
 var file=FileAccess.open(OUTPUT+"/palette_"+label_+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 print("LEADER_PALETTE_"+label_.to_upper()+" "+JSON.stringify(report))
 current_scene=null;stage.queue_free();await process_frame;quit(0 if failures==0 else 1)

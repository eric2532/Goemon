extends SceneTree
## Original asset look-development scene; never mutates a saved map or live game.
const DIR="res://assets/models/environments/wind_meadow/"
const OUT="res://build/Other Files/Asset Toolkit/Wind Meadow/"
const GROUND=preload("res://tests/forest-shrine/wind_meadow_ground.gdshader")
const FOLIAGE=preload("res://scripts/forest/wind_meadow_foliage.gdshader")
var stage:Node3D
var camera:Camera3D
var random=RandomNumberGenerator.new()
var batches=0
var instances=0
var wind_materials:Dictionary={}
var orbit=Vector2(.26,.10)
var distance_=43.0
var focus=Vector3(-2,2,-13)
var capturing=false

func _initialize():
 random.seed=231026
 capturing="--capture" in OS.get_cmdline_user_args()
 run.call_deferred()

func height_at(x:float,z:float)->float:
 var hill=2.8*exp(-((x+25)*(x+25)/550.0+(z+38)*(z+38)/650.0))
 var h=.25+hill+.32*sin(x*.08+z*.04)+.22*cos(z*.13)
 var lake=Vector2((x-28)/19.0,(z+13)/29.0).length()
 return lerpf(-.45,h,smoothstep(.87,1.18,lake))

func ground():
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in range(-115,45,2):
  for x in range(-90,90,2):
   for p in [Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]:
    surface.add_vertex(Vector3(p.x,height_at(p.x,p.y),p.y))
 surface.generate_normals()
 var node=MeshInstance3D.new();node.name="MeadowGround";node.mesh=surface.commit()
 var mat=ShaderMaterial.new();mat.shader=GROUND;node.material_override=mat;stage.add_child(node)

func place_asset(asset:String,transforms:Array,wind:bool=false):
 assert(not transforms.is_empty())
 var packed=load(DIR+asset+".glb") as PackedScene
 assert(packed!=null,"Missing imported meadow asset: "+asset)
 var source=packed.instantiate()
 var meshes=source.find_children("*","MeshInstance3D",true,false)
 assert(not meshes.is_empty(),"No imported mesh: "+asset)
 for part in meshes:
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=part.mesh;mm.instance_count=transforms.size()
  # Preserve authored part transforms as well as each landscape placement.
  var local=part.transform
  var ancestor=part.get_parent()
  while ancestor!=source and ancestor!=null:
   local=ancestor.transform*local;ancestor=ancestor.get_parent()
  for i in transforms.size():mm.set_instance_transform(i,transforms[i]*source.transform*local)
  var batch=MultiMeshInstance3D.new();batch.name=asset+"_"+str(batches);batch.multimesh=mm
  if wind and (part.name=="Canopy" or asset.begins_with("grass") or asset.begins_with("flowers")):
   var tree=asset=="broadleaf_tree"
   if not wind_materials.has(tree):
    var mat=ShaderMaterial.new();mat.shader=FOLIAGE;mat.set_shader_parameter("tree",tree)
    mat.set_shader_parameter("strength",.07 if tree else .14);wind_materials[tree]=mat
   batch.material_override=wind_materials[tree]
  if asset.begins_with("grass") or asset.begins_with("flowers"):
   batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  batch.extra_cull_margin=1.0;stage.add_child(batch);batches+=1
 instances+=transforms.size();source.free()

func pose(x:float,z:float,scale_:float=1.0)->Transform3D:
 return Transform3D(Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3.ONE*scale_),Vector3(x,height_at(x,z),z))

func landscape():
 ground()
 # The preview is bounded; use cell batches and range fading before map-wide rollout.
 for cell_z in range(-3,2):
  for cell_x in range(-3,3):
   var short:Array=[];var tall:Array=[];var flowers:Array=[]
   for i in 670:
    var x=random.randf_range(cell_x*14,(cell_x+1)*14)
    var z=random.randf_range(cell_z*15,(cell_z+1)*15)
    var lake=Vector2((x-28)/19.0,(z+13)/29.0).length()
    if lake<1.08 or absf(x-(-4+sin(z*.055)*5))<random.randf_range(1.4,2.4):continue
    var patch=sin(x*.24+sin(z*.14)*2)+cos(z*.19-x*.08)
    if random.randf()<.68:short.append(pose(x,z,random.randf_range(.8,1.2)))
    elif patch>.15:tall.append(pose(x,z,random.randf_range(.75,1.1)))
    if patch>.7 and random.randf()<.3:flowers.append(pose(x,z,random.randf_range(.85,1.3)))
   if not short.is_empty():place_asset("grass_short",short,true)
   if not tall.is_empty():place_asset("grass_tall",tall,true)
   if not flowers.is_empty():place_asset(["flowers_blue","flowers_ivory","flowers_coral"][posmod(cell_x+cell_z,3)],flowers,true)
 var trees:Array=[];var shrubs:Array=[];var rocks:Array=[]
 for p in [Vector2(-17,-8),Vector2(-25,-25),Vector2(-18,-39),Vector2(5,-40),Vector2(15,-48),Vector2(30,-51),Vector2(42,-48),Vector2(-35,4),Vector2(-38,-48),Vector2(48,-20),Vector2(50,1)]:
  trees.append(pose(p.x,p.y,random.randf_range(.95,1.5)))
 for i in 26:
  var x=random.randf_range(-42,44);var z=random.randf_range(-50,4)
  if Vector2((x-28)/19.0,(z+13)/29.0).length()>1.12 and absf(x-(-4+sin(z*.055)*5))>4:shrubs.append(pose(x,z,random.randf_range(.7,1.3)))
 for p in [Vector2(-10,-17),Vector2(-30,-5),Vector2(8,-38),Vector2(43,-43),Vector2(-35,-38)]:rocks.append(pose(p.x,p.y,random.randf_range(.8,1.7)))
 place_asset("broadleaf_tree",trees,true);place_asset("leafy_shrub",shrubs,true);place_asset("mossy_boulder",rocks)
 var mountains:Array=[]
 for p in [Vector3(-52,.9,-79),Vector3(-22,1.0,-91),Vector3(8,1.8,-110),Vector3(42,1.1,-96),Vector3(64,1.4,-112)]:
  var t=pose(p.x,p.z,p.y);t.origin.y=-1.0;mountains.append(t)
 place_asset("terraced_mountain",mountains)
 var water=MeshInstance3D.new();var lake_surface=SurfaceTool.new();lake_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 96:
  lake_surface.add_vertex(Vector3(0,-.15,0))
  for a in [(i+1)*TAU/96.0,i*TAU/96.0]:lake_surface.add_vertex(Vector3(cos(a)*19,-.15,sin(a)*29))
 lake_surface.generate_normals();water.mesh=lake_surface.commit();water.position=Vector3(28,0,-13)
 var mat=StandardMaterial3D.new();mat.albedo_color=Color("559a9e");mat.roughness=.28;mat.metallic=.12;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;water.material_override=mat;stage.add_child(water)

func view():
 camera.position=focus+Vector3(sin(orbit.x)*cos(orbit.y),sin(orbit.y),cos(orbit.x)*cos(orbit.y))*distance_
 camera.look_at(focus)

func capture_views()->Array:
 return [{"name":"meadow-eye-level","orbit":Vector2(.17,.075),"distance":39.0,"focus":Vector3(-2,2,-13),"wind_check":true},{"name":"meadow-overview","orbit":Vector2(.35,.63),"distance":75.0,"focus":Vector3(-2,2,-13)},{"name":"meadow-flowers","orbit":Vector2(.06,.04),"distance":18.0,"focus":Vector3(-9,1,-13)}]

func output_folder()->String:return OUT

func validate_scene()->bool:
 assert(instances>11000 and batches<110)
 return true

func prepare_capture(_shot:Dictionary):pass

func run():
 stage=Node3D.new();root.add_child(stage)
 root.size=Vector2i(1440,900)
 root.msaa_3d=Viewport.MSAA_4X
 var environment=WorldEnvironment.new();var env=Environment.new();environment.environment=env
 var sky=Sky.new();var sky_mat=ProceduralSkyMaterial.new()
 sky_mat.sky_top_color=Color("73adcf");sky_mat.sky_horizon_color=Color("dce7d3");sky_mat.ground_horizon_color=Color("dce7d3")
 sky_mat.sky_curve=.16;sky.sky_material=sky_mat;env.sky=sky;env.background_mode=Environment.BG_SKY
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bdcfc6");env.ambient_light_energy=.35
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=.85
 env.fog_enabled=true;env.fog_light_color=Color("b4ccd0");env.fog_density=.0018;env.fog_sky_affect=.2
 stage.add_child(environment)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-32,0);sun.light_color=Color("fff0dc");sun.light_energy=1.0;sun.shadow_enabled=true;sun.directional_shadow_max_distance=150;stage.add_child(sun)
 camera=Camera3D.new();camera.fov=52;camera.far=350;stage.add_child(camera);camera.current=true;view()
 landscape()
 var layer=CanvasLayer.new();stage.add_child(layer)
 var label=Label.new();label.position=Vector2(30,24);label.text="WIND MEADOW  /  Goemon art study\nOriginal Blender assets · live wind · layered meadow";label.add_theme_color_override("font_color",Color("f4f1df"));label.add_theme_font_size_override("font_size",20);layer.add_child(label)
 var help=Label.new();help.position=Vector2(30,842);help.text="Drag to orbit  ·  Wheel to zoom  ·  Esc to close     |     Asset preview — saved gameplay maps unchanged";help.add_theme_font_size_override("font_size",16);layer.add_child(help)
 print("WIND_MEADOW_READY instances=%d batches=%d"%[instances,batches])
 if not validate_scene():quit(1);return
 if DisplayServer.get_name()=="headless":
  print("WIND_MEADOW_IMPORT_CHECK_PASS");quit();return
 if capturing:
  for i in 30:await process_frame
  layer.hide()
  for shot in capture_views():
   prepare_capture(shot)
   orbit=shot.orbit;distance_=shot.distance;focus=shot.focus;view()
   for i in 8:await process_frame
   await RenderingServer.frame_post_draw
   var picture=root.get_texture().get_image();assert(not picture.is_empty());assert(picture.save_png(output_folder()+shot.name+".png")==OK)
   if shot.get("wind_check",false):
    var nodes_before=get_node_count()
    for i in 60:await process_frame
    await RenderingServer.frame_post_draw
    var moved=root.get_texture().get_image();var changed=0
    for y in range(300,850,7):
     for x in range(50,1390,7):
      var a=picture.get_pixel(x,y);var b=moved.get_pixel(x,y)
      if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.025:changed+=1
    assert(changed>20,"Wind must move visible foliage")
    assert(get_node_count()==nodes_before,"Wind must not construct scene nodes")
    var validation={"instances":instances,"batches":batches,"wind_changed_samples":changed,"stable_node_count":nodes_before,"renderer":RenderingServer.get_video_adapter_name(),"gameplay_performance_measured":false}
    var report=FileAccess.open(output_folder()+"preview-validation.json",FileAccess.WRITE);report.store_string(JSON.stringify(validation,"  "));report.close()
  print("WIND_MEADOW_CAPTURE_PASS");quit()

func _process(_delta):
 if stage==null or camera==null or capturing:return false
 if Input.is_physical_key_pressed(KEY_ESCAPE):quit()
 return false

func _input(event):
 if capturing:return
 if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
  orbit.x-=event.relative.x*.005;orbit.y=clampf(orbit.y+event.relative.y*.004,.02,1.2);view()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:distance_=maxf(8,distance_*.9)
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance_=minf(120,distance_*1.1)
  view()

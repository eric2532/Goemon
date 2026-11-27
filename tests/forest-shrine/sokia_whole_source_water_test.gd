extends SceneTree
## Inspect the existing full-source water surface independently of the land crops.
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Art=preload("res://scripts/forest/forest_freyja_art.gd")
var failures=0
var checks=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("SOKIA_WHOLE_SOURCE_WATER_FAIL ",message)
func _initialize():run.call_deferred()
func run():
 var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/provenance.json"))
 var coverage:Dictionary=provenance.whole_source_coverage
 var expected_open=provenance.source_completion.active_decoder_open_cells if provenance.has("source_completion")else 92140
 check(coverage.decoder_open_cells==expected_open,"All active source decoder-open components are included, not only selected entry-seed cells")
 check(coverage.components.size()>0 and coverage.components.reduce(func(sum_,row):return sum_+int(row.cells),0)==expected_open,"Every disconnected active source component is inventoried")
 check(coverage.components.all(func(c):return int(c.outside_crops)==0),"No disconnected source open component is cropped away")
 var image:Image=Terrain.Sokia.WATER.get_image()
 var index:Image=load("res://assets/maps/falan/sokia_ground_index.png").get_image()
 check(image.get_size()==Vector2i(800,532) and index.get_size()==image.get_size(),"Source water and native floor index retain full800×532 dimensions")
 var water_matches=true
 for y in image.get_height():
  for x in image.get_width():
   var tile:Color=index.get_pixel(x,y)
   if (image.get_pixel(x,y).r>.5)!=(tile.a>.5 and tile.b>.5):water_matches=false
 check(water_matches,"Every source water identity matches the native full-map ground index")
 for area in Terrain.Sokia.MASKS:
  var terrain=Terrain.new();terrain.variant=area
  var root=Node3D.new();get_root().add_child(root)
  var ground=ShaderMaterial.new();ground.shader=load("res://scripts/forest/wind_meadow_ground.gdshader")
  Art.build(root,ground,terrain,1.)
  var water=root.get_node("FreyjaWater") as MeshInstance3D
  var paint=water.material_override as ShaderMaterial
  var frame:Transform2D=Terrain.Regions.frame(area)
  var start:Vector2=frame.inverse()*Vector2(-1.5,-1.5)
  check(water.mesh.size==Vector2(2400,1596),"Full source water plane is built in "+area)
  check(Vector2(water.position.x,water.position.z).is_equal_approx(start+Vector2(1200,798)),"Water plane keeps the original source origin in "+area)
  check(paint.get_shader_parameter("layout_mask")==Terrain.Sokia.WATER,"Full source mask owns water visibility in "+area)
  check(paint.get_shader_parameter("bounds")==Vector4(start.x,start.y,2400,1596),"Shader sampling spans the full original map in "+area)
  check(ground.get_shader_parameter("native_land_visibility")==Terrain.Sokia.WATER,"Native land visibility shares the source map in "+area)
  check(ground.get_shader_parameter("sokia_source_bank")==true,"Source shore side paint is enabled only through the Sokia owner "+area)
  check(root.get_node("WaterWalkingGround").get_child(0).shape.size.x==terrain.mask_bounds().size.x,"Existing water-walking collision stays limited to the unchanged crop in "+area)
  root.free()
 var material=ShaderMaterial.new();material.shader=load("res://scripts/forest/wind_meadow_ground.gdshader")
 var terrain=Terrain.new();terrain.variant="ghana_north_road";terrain.horizontal_scale=Terrain.Regions.layout(terrain.variant).terrain_scale;terrain.configure([])
 var walk=var_to_bytes([terrain.heights,terrain.covered,terrain.bridges])
 Terrain.Sokia.northeast_clip_material(material,terrain,true)
 check(material.get_shader_parameter("sokia_ne_clip")==true,"Northeast source cave cut is enabled on its own map")
 var owned_shader=material.shader
 var empty=PackedVector4Array();empty.resize(8)
 for area in ["sokia_coast","sokia_desert","city","venoa"]:
  var next=Terrain.new();next.variant=area
  Terrain.Sokia.northeast_clip_material(material,next,true)
  check(material.get_shader_parameter("sokia_source_bank")==Terrain.Sokia.owns(area),"Reused material restores scoped source shore paint on "+area)
  check(material.get_shader_parameter("sokia_ne_clip")==false and material.get_shader_parameter("sokia_ne_entry")==Vector4.ZERO and material.get_shader_parameter("sokia_ne_profile")==empty,"Reused material clears northeast clipping on "+area)
 Terrain.Sokia.northeast_clip_material(material,terrain,true)
 check(material.shader==owned_shader and material.get_shader_parameter("sokia_ne_clip")==true,"Returning to the northeast reuses the prepared shader and restores only its own cut")
 check(var_to_bytes([terrain.heights,terrain.covered,terrain.bridges])==walk,"Visual cave clipping preserves every terrain height, navigation-coverage and bridge sample")
 for area in ["south_lakes","sokia_coast","venoa","south_lakes"]:
  var next=Terrain.new();next.variant=area
  var stage=Node3D.new();get_root().add_child(stage)
  Art.build(stage,material,next,1.,false)
  var ground_index:Texture2D=material.get_shader_parameter("freyja_ground_index")
  var expected="res://assets/maps/falan/sokia_ground_index.png" if area=="sokia_coast" else "res://assets/maps/falan/venoa_ground_index.png" if area=="venoa" else "res://assets/maps/falan/freyja_ground_index.png"
  check(ground_index.resource_path==expected,"Reused ground material restores its own source index on "+area)
  var water=stage.get_node("FreyjaWater") as MeshInstance3D
  var paint=water.material_override as ShaderMaterial
  var water_index:Texture2D=paint.get_shader_parameter("freyja_ground_index")
  check(water_index.resource_path==(Terrain.VenoaField.OCEAN_INDEX_PATH if area=="south_lakes" else expected),"Inferred ocean index remains scoped to Southern Lakes water on "+area)
  check(material.get_shader_parameter("use_native_land_visibility")==(area!="venoa") and material.get_shader_parameter("sokia_ne_clip")==false and material.get_shader_parameter("sokia_source_bank")==Terrain.Sokia.owns(area),"Native visibility and northeast aperture state are scoped on "+area)
  stage.free()
 print("SOKIA_WHOLE_SOURCE_WATER_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

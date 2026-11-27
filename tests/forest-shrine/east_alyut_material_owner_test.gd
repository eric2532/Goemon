extends SceneTree
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Canonical Stage/"
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);push_error(label)
func run():
 var paths=["scripts/forest/forest_east_alyut_source_completion.gd","scripts/forest/forest_freyja_art.gd","scripts/forest/forest_east_bank_underlay.gd",String(FOLDER+"map-data.json").trim_prefix("res://"),String(FOLDER+"banks.json").trim_prefix("res://"),"assets/maps/falan/east_region/bank_caps/data.json"]
 var before=Fresh.snapshot(paths);var terrain=Terrain.new();terrain.variant="north_coast";terrain.horizontal_scale=2.
 var ground=ShaderMaterial.new();ground.shader=load("res://scripts/forest/wind_meadow_ground.gdshader")
 var water=ShaderMaterial.new();water.shader=load("res://assets/maps/freyja_west_gate/water.gdshader")
 check(not FileAccess.file_exists(Full.ROOT+"map-data.json"),"Canonical Alyut source is still inactive")
 check(not Full.apply_materials(ground,water,terrain) and water.get_shader_parameter("layout_mask")==null,"Missing canonical source commits no material change")
 Full.review_root=FOLDER;terrain.configure([])
 var original:Texture2D=terrain.mask_texture();var pixels:Image=original.get_meta("source_cpu_image");var bytes=pixels.get_data();var heights=terrain.heights.to_byte_array();var coverage=terrain.covered.duplicate();var bounds=terrain.mask_bounds()
 water.set_shader_parameter("layout_mask",original);water.set_shader_parameter("map_scale",1.3);water.set_shader_parameter("bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y)*1.3)
 ground.set_shader_parameter("use_native_land_visibility",true)
 check(not Full.apply_materials(ground,water,terrain),"An unrelated enabled terrain visibility owner remains blocked")
 check(water.get_shader_parameter("layout_mask")==original and terrain.has_meta("alyut_complete_material_blocker"),"Blocked owner records a specific reason without partially committing water")
 ground.set_shader_parameter("use_native_land_visibility",false);ground.set_shader_parameter("map_frame",Transform3D(Basis.IDENTITY,Vector3(3,0,0)))
 check(not Full.apply_materials(ground,water,terrain) and water.get_shader_parameter("layout_mask")==original,"Unsupported material frame cannot partially commit")
 ground.set_shader_parameter("map_frame",Transform3D.IDENTITY)
 check(Full.apply_materials(ground,water,terrain),"Configured Alyut production owner commits both prepared masks")
 var visibility:Texture2D=ground.get_shader_parameter("native_land_visibility");var backing:Texture2D=water.get_shader_parameter("layout_mask")
 check(visibility.get_meta("source_bank_cut_cells").size()==117 and visibility.get_meta("source_water_cut_cells").size()==76,"Production owner retains117bank/76water cuts and excludes six distinct source100land/flower cells")
 check(backing!=original and backing.get_meta("alyut_source_water_bank_cells").size()==117,"Water texture is cloned for only original117source-water bank pixels")
 check(pixels.get_data()==bytes and heights==terrain.heights.to_byte_array() and coverage==terrain.covered,"Original source image/native height/coverage bytes remain identical")
 check(not terrain.has_meta("alyut_complete_material_blocker"),"Valid setup clears a prior specific blocker")
 check(Full.apply_materials(ground,water,terrain) and ground.get_shader_parameter("native_land_visibility")==visibility and water.get_shader_parameter("layout_mask")==backing,"Repeated same-source setup is idempotent")
 terrain.variant="east_gate"
 check(not Full.apply_materials(ground,water,terrain) and ground.get_shader_parameter("native_land_visibility")==visibility,"Other region material owners are untouched")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Production material source inputs remained current")
 var file=FileAccess.open(FOLDER+"production-material-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":before,"source_changed_during_run":changed,"scope":"Pure production material transaction/owner/idempotence contract. Canonical source is inactive; actual staged gate/support/camera review remains separate."}," "));file.close()
 print("EAST_ALYUT_MATERIAL_OWNER_CONTRACTS checks=",checks," failures=",failures.size());quit(failures.size())

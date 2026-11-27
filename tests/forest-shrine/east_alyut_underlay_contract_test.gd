extends SceneTree
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate/"
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);push_error(label)
func run():
 var paths=["scripts/forest/forest_east_alyut_source_completion.gd","scripts/forest/forest_east_bank_underlay.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/wind_meadow_ground.gdshader","assets/maps/freyja_west_gate/water.gdshader",String(FOLDER+"map-data.json").trim_prefix("res://"),String(FOLDER+"banks.json").trim_prefix("res://")]
 var before=Fresh.snapshot(paths)
 check(Full.bank_underlay_settings(null).is_empty(),"Unpublished canonical Alyut completion has no visual effect")
 Full.review_root=FOLDER
 var terrain=Terrain.new();terrain.variant="north_coast";terrain.horizontal_scale=2.;terrain.configure([])
 var height_bytes=terrain.heights.to_byte_array();var coverage_bytes=terrain.covered.duplicate();var source_bytes=FileAccess.get_file_as_bytes(FOLDER+"hybrid-map.bin")
 var settings=Full.bank_underlay_settings(terrain);var texture:Texture2D=settings.native_land_visibility;var image:Image=texture.get_meta("source_cpu_image")
 var bounds:Vector4=settings.native_visibility_bounds;var rect=Rect2(bounds.x,bounds.y,bounds.z,bounds.w)
 var box=terrain.mesh().get_aabb()
 check(rect.encloses(Rect2(box.position.x,box.position.z,box.size.x,box.size.z)),"Nearest visibility bounds cover all original terrain and decorative apron")
 check(Full.bank_underlay_settings(terrain).native_land_visibility==texture,"Configured source mask is reused")
 check(settings.size()==3 and settings.use_native_land_visibility,"Only existing ground visibility settings are returned")
 check(texture.get_meta("source_bank_cut_cells").size()==117,"Exactly117 native bank tiles replace their terrain underlay")
 check(texture.get_meta("source_water_cut_cells").size()==82,"Only82original-water neighboring cells close the triangulated ramp underlay")
 var bank_cells={}
 for row:Dictionary in Full.bank_rows():bank_cells[row.source_cell]=true
 var water_cells={}
 for row:Dictionary in Full.bank_underlay_water_rows():water_cells[row.source_cell]=true
 var source=Full.data();var ground=Marshalls.base64_to_raw(source.ground_u16le_deflate).decompress(20000,FileAccess.COMPRESSION_DEFLATE)
 var dry=0
 for y in 100:
  for x in 100:
   var cell=Vector2i(x,y);var at=Full.local_point(Vector2(cell))+Vector2(-165,-123);var index=Vector2i(((at-rect.position)/3.).floor())
   var hidden=image.get_pixelv(index).g<.5
   check(hidden==(bank_cells.has(cell) or water_cells.has(cell)),"Exact bank/original-water source-cell cutout "+str(cell))
   if hidden:check(ground.decode_u16((y*100+x)*2) in range(5000,5009) and Full.source_open(cell)==bank_cells.has(cell),"Cutout belongs to a native bank or its original blocked water neighbor "+str(cell))
   elif ground.decode_u16((y*100+x)*2) not in [0,100,5000,5001,5002,5003,5004,5005,5006,5007,5008]:dry+=1
 check(height_bytes==terrain.heights.to_byte_array() and coverage_bytes==terrain.covered,"Every original native terrain height and coverage byte is unchanged")
 check(source_bytes==FileAccess.get_file_as_bytes(FOLDER+"hybrid-map.bin"),"All compatible source BG/PG1/marker bytes are unchanged")
 var original:Texture2D=terrain.mask_texture();var original_image:Image=original.get_meta("source_cpu_image");var original_bytes=original_image.get_data();var water_bounds=terrain.mask_bounds();var scale_=1.3
 var backing=Full.bank_water_mask(terrain,original,Vector4(water_bounds.position.x,water_bounds.position.y,water_bounds.size.x,water_bounds.size.y)*scale_,scale_)
 var backing_image:Image=backing.get_meta("source_cpu_image");var bank_pixels={}
 for row:Dictionary in Full.bank_rows(true):bank_pixels[Vector2i(((row.anchor-water_bounds.position)/3.).floor())]=true
 for y in backing_image.get_height():
  for x in backing_image.get_width():
   var cell=Vector2i(x,y);var expected=original_image.get_pixelv(cell)
   if bank_pixels.has(cell):expected.r=1.;expected.a=1.
   check(backing_image.get_pixelv(cell)==expected,"Source water backing changes only exact117bank pixels "+str(cell))
 check(original_image.get_data()==original_bytes,"Original joined terrain/water source mask remains byte-identical")
 check(backing.get_meta("alyut_source_water_bank_cells").size()==117,"All117source-water bank cells receive their original2mwater backing")
 check(texture.get_meta("alyut_source_hybrid_sha256")==source.source.sha256,"Mask retains exact source provenance")
 var changed=Fresh.changed(before);check(changed.is_empty(),"All underlay contract sources stayed current")
 var file=FileAccess.open(FOLDER+"bank-underlay-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":before,"source_changed_during_run":changed,"source_hybrid_sha256":source.source.sha256,"bank_cut_tiles":117,"original_water_context_cut_tiles":82,"water_backing_tiles":117,"source_dry_tiles_retained":dry,"visual_bounds":var_to_str(rect),"scope":"Private Alyut visual mask only. Exact native water-backed bank cells plus their original blocked-water ring are cut, complete original visual bounds retained, all source/height/coverage bytes unchanged. Original2mwater backing is restored only behind117sourceBGwater bank tiles. Actual cap/join/body images remain a separate acceptance gate."}," "));file.close()
 print("EAST_ALYUT_UNDERLAY_CONTRACTS checks=",checks," failures=",failures.size());quit(failures.size())

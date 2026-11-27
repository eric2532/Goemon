extends SceneTree
## Read-only source/terrain-frame diagnosis, separate from visual acceptance.
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate/"
func _initialize():call_deferred("run")
func run():
 Full.review_root=FOLDER
 var terrain=Terrain.new();terrain.variant="north_coast";terrain.horizontal_scale=2.;terrain.configure([])
 var field:Resource=terrain.terrain_field();var bed:PackedFloat32Array=field.get_meta("bed")
 var mask=terrain.mask_image();var origin=terrain.mask_origin();var bounds=terrain.mask_bounds()
 var source=Full.data();var ground=Marshalls.base64_to_raw(source.ground_u16le_deflate).decompress(20000,FileAccess.COMPRESSION_DEFLATE)
 var banks={}
 for row:Dictionary in Full.bank_rows():banks[row.source_cell]=row
 var records=[]
 for y in range(11,20):
  for x in range(60,71):
   var cell=Vector2i(x,y);var village=Full.local_point(Vector2(cell));var at=village+Vector2(-165,-123)
   var coordinate=terrain.coordinate(at.x,at.y);var ix=floori(coordinate.x);var iz=floori(coordinate.y);var start=iz*terrain.width+ix
   var grid=Vector2i(((at-origin)/3.).round());var paint=mask.get_pixelv(grid)
   var samples=[]
   for dz in [-1.49,-.75,0.,.75,1.49]:
    for dx in [-1.49,-.75,0.,.75,1.49]:samples.append([dx,dz,terrain.height(at.x+dx,at.y+dz)])
   records.append({"cell":[x,y],"bg":ground.decode_u16((y*100+x)*2),"source_open":Full.source_open(cell),"bank_graphic":int(banks[cell].serial) if banks.has(cell) else 0,"joined_anchor":[at.x,at.y],"joined_mask_rgba":[paint.r,paint.g,paint.b,paint.a],"terrain_center_height":terrain.height(at.x,at.y),"terrain_quad_heights":[bed[start],bed[start+1],bed[start+terrain.width],bed[start+terrain.width+1]],"tile_height_samples":samples})
 var output={"source_hybrid_sha256":source.source.sha256,"source_sha256":{"terrain":FileAccess.get_sha256("res://scripts/forest/forest_freyja_terrain.gd"),"regions":FileAccess.get_sha256("res://scripts/forest/forest_freyja_regions.gd"),"full":FileAccess.get_sha256("res://scripts/forest/forest_east_alyut_source_completion.gd")},"local_frame":"Full.local_point(cell)+(-165,-123), native grid3m, cap6m, water2m","mesh_owner":"forest_wind_meadow_terrain.gd::mesh uses FreyjaTerrain.mesh_heights()=bed and two triangles per3m quad. Physics remains the same original height field; bank pieces independently provide native-open6m support.","material_owner":"forest_freyja_art.gd::build and wind_meadow_ground.gdshader; north_coast does not enable Frontier.FRAMES-only clip_archive_land. Terrain between dry6m and wet0m vertices is rendered as a triangular ramp, separate from NativeSourceBankCap geometry.","mask_bounds":var_to_str(bounds),"rows":records,"scope":"Read-only geometric diagnosis; not image acceptance or permission to modify terrain/collision/join semantics."}
 var file=FileAccess.open(FOLDER+"shore-terrain-frame-probe.json",FileAccess.WRITE);file.store_string(JSON.stringify(output," "));file.close()
 print("EAST_ALYUT_SHORE_FRAME_PROBE rows=",records.size());quit()

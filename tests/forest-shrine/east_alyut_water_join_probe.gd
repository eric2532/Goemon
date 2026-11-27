extends SceneTree
## Read-only check that visual shore remnants do not become unrecorded routes.
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Canonical Stage/"
func _initialize():call_deferred("run")
func run():
 Full.review_root=FOLDER;var terrain=Terrain.new();terrain.variant="north_coast";terrain.horizontal_scale=2.;terrain.configure([])
 var data=Full.data();var ground=Marshalls.base64_to_raw(data.ground_u16le_deflate).decompress(20000,FileAccess.COMPRESSION_DEFLATE);var objects=Marshalls.base64_to_raw(data.objects_u16le_deflate).decompress(20000,FileAccess.COMPRESSION_DEFLATE)
 var rows=[];var covered=[];var clear=[]
 for y in 100:
  for x in 100:
   var cell=Vector2i(x,y);var bg=ground.decode_u16((y*100+x)*2)
   if bg not in range(5000,5009) or Full.source_open(cell):continue
   var point=Full.local_point(Vector2(cell))+Vector2(-165,-123);var height_=terrain.height(point.x,point.y);var dry=terrain.contains(point.x,point.y);var passable=terrain.disk_clear(Vector3(point.x,height_,point.y),.55)
   var row={"cell":[x,y],"source_bg":bg,"source_pg1":objects.decode_u16((y*100+x)*2),"source_open":false,"joined_point":[point.x,point.y],"raw_terrain_y":height_,"raw_terrain_contains":dry,"raw_native_disk_clear_point55":passable}
   rows.append(row)
   if dry:covered.append(row)
   if passable:clear.append(row)
 var file=FileAccess.open(FOLDER+"water-join-probe.json",FileAccess.WRITE);file.store_string(JSON.stringify({"source_hybrid_sha256":data.source.sha256,"source_closed_water_cells":rows.size(),"raw_terrain_covered":covered,"raw_terrain_native_clear":clear,"all_water_rows":rows,"scope":"Read-only base joined terrain diagnosis before any runtime obstacle/source-actor owner. A clear result requires actual assembled-map collision/path follow-up before calling an unintended route. No source/mask/terrain/navigation mutation."}," "));file.close()
 print("EAST_ALYUT_WATER_JOIN_PROBE water=",rows.size()," covered=",covered.size()," nativeclear=",clear.size());quit()

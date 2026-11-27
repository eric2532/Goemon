extends "res://tests/forest-shrine/east_landmark_review.gd"
const Motifs=preload("res://scripts/forest/forest_east_ground_motifs.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Ground Motifs/"
func sites()->Array:return [[11037,11799,Vector2i(38,40),"earth-cave-native-circle",Vector2i(32,44),Vector2i(45,44)],[34018,11803,Vector2i(21,7),"great-tree-native-circle",Vector2i(16,12),Vector2i(27,13)],[33506,16638,Vector2i(15,9),"craftsman-native-circle",Vector2i(10,14),Vector2i(18,14)]]
func site_owned(_source:int,serial:int)->bool:return Motifs.owns(serial)
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Motifs.mesh(serial,g)
func site_visible(_serial:int,g:Dictionary)->Array:return [0,0,g.rect[2],g.rect[3]]
func review_source_paths()->Array:return super.review_source_paths()+["scripts/forest/forest_east_ground_motifs.gd","assets/maps/falan/east_region/ground_motifs/data.json"]
func landmark(row:Array):
 await super.landmark(row)
 var serial=int(row[1]);var found=false
 for batch:MultiMeshInstance3D in game.world.find_children("RecoveredShalenaSolid_*","MultiMeshInstance3D",true,false):
  if int(batch.get_meta("source_graphic",-1))!=serial:continue
  check(batch.multimesh.mesh==Motifs.mesh(serial,Maps.Art.data().graphics[str(serial)]),"Actual source room uses the full-extent floor owner "+str(serial));found=true
 check(found,"Full-extent original motif appears in actual map "+str(row[0]))

extends RefCounted
## Private visual-only restoration. No shared filter, collider or map owner calls this.
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/"
const Raw="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Candidate/100.dat"
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Trees=preload("res://scripts/forest/forest_east_native_trees.gd")
const Nature=preload("res://scripts/forest/forest_east_nature.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")

static func build(parent:Node3D,model)->Node3D:
 assert(model.falan_area=="east_gate","The thirteen source anchors belong only to the East field")
 assert(not parent.has_node("PrivateSource100Missing13"),"Do not duplicate staged source scenery")
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json"))
 var diagnosis:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"diagnosis.json"))
 assert(FileAccess.get_sha256(Raw)==source.source_raw_sha256 and source.records.size()==13,"Missing13 requires the preserved source100 candidate")
 assert(int(diagnosis.failures)==0 and diagnosis.source_changed.is_empty(),"Diagnose the original omission before staging a source placement")
 Art.load_east()
 var root=Node3D.new();root.name="PrivateSource100Missing13";var frame:Transform2D=Regions.frame("east_gate");var turn=Basis(Vector3.UP,frame.get_rotation());var represented=[]
 parent.add_child(root)
 for record:Dictionary in source.records:
  var serial=int(record.native_graphic);var cell=Vector2i(record.cell[0],record.cell[1]);var at:Vector2=frame.inverse()*(Vector2(cell)*3.);var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  assert(diagnosis.records.any(func(row):return int(row.native_graphic)==serial and row.cell==record.cell and not row.private_visual_hold),"This exact source anchor needs an unblocked entrance contract")
  for link in model.get_meta("falan_links",[]):assert(at.distance_squared_to(link.at)>=pow(1.25+1.35,2),"Hold a source prop that intersects a protected gate")
  var object=Node3D.new();object.name="Native_%d_%d_%d"%[serial,cell.x,cell.y];root.add_child(object)
  object.set_meta("source_map",100);object.set_meta("source_cell",cell);object.set_meta("source_graphic",serial);object.set_meta("visual_only",true)
  var owner:String
  if Trees.owns(serial) or Nature.owns(serial):
   var graphic:Dictionary=Art.data().graphics[str(serial)];var node=MeshInstance3D.new();node.mesh=Trees.mesh(serial,graphic) if Trees.owns(serial) else Nature.mesh(serial,graphic)
   node.transform=Transform3D(turn,p);node.set_meta("source_graphic",serial);object.add_child(node)
   owner="accepted_native_tree_fit" if Trees.owns(serial) else "existing_source_nature"
  else:
   assert(serial in [12244,12226] and record.source_row[3]=="mossy_boulder","Only the two already-prepared whole boulder masters need this branch")
   var row:Array=record.source_row;var pose=Transform3D(Basis(Vector3.UP,float(serial)*.71-frame.get_rotation()).scaled(Vector3.ONE*float(row[4])),p)
   Assets.batch(object,str(row[3]),[pose]);owner="existing_prepared_whole_mossy_boulder"
  represented.append({"graphic":serial,"cell":record.cell,"anchor":var_to_str(p),"owner":owner,"original_anchor_open":record.native_open_at_anchor})
 root.set_meta("source_placements",represented)
 return root

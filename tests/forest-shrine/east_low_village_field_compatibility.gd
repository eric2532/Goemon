extends SceneTree
const Before=preload("res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Field Compatibility/low-before.gd")
const After=preload("res://scripts/forest/forest_east_il_low_source.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/"
var checks=0
var errors=[]
func _initialize():
 create_timer(90,true,false,true).timeout.connect(func():printerr("LOW_VILLAGE_COMPATIBILITY_TIMEOUT");quit(2));run.call_deferred()
func check(yes:bool,label:String):
 checks+=1
 if not yes:errors.append(label);if errors.size()<=10:printerr("LOW_VILLAGE_COMPATIBILITY_FAIL ",label)
func run():
 var paths=[get_script().resource_path,ROOT+"Field Compatibility/low-before.gd","scripts/forest/forest_east_il_low_source.gd",ROOT+"data.json","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_kai_terrain.gd","scripts/forest/forest_ramparts.gd"]
 var snapshot=Fresh.snapshot(paths);var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 var old=Before.new();old.setup(data);var next=After.new();next.setup(data)
 check(old.variant==next.variant and next.variant=="il_village","Source2000 retains the same village context")
 check(old.heights==next.heights and old.covered==next.covered and old.bridges==next.bridges,"Exact packed source fields retained")
 check(old.pieces==next.pieces,"Exact282support pieces and source metadata retained")
 check(old.native_data()==next.native_data(),"Exact scaled native payload retained")
 check(old.mask_bounds()==next.mask_bounds(),"Exact original90×120source bounds retained")
 check(old.collision().get_faces()==next.collision().get_faces(),"Exact original-open physics faces retained")
 check(old.mesh().get_meta("source_surface_arrays")==next.mesh().get_meta("source_surface_arrays"),"Exact original drymesh packed channels retained")
 var bank_path=ROOT.trim_suffix("Low Source Candidate/")+"Whole Shore Candidate/banks.json"
 var banks:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(bank_path));var left=Node3D.new();var right=Node3D.new()
 old.build_bank_visuals(left,banks.rows);next.build_bank_visuals(right,banks.rows)
 check(left.get_child_count()==right.get_child_count(),"Same36native bank groups retained")
 var placements=0
 for index in left.get_child_count():
  var a:MultiMesh=left.get_child(index).multimesh;var b:MultiMesh=right.get_child(index).multimesh
  placements+=a.instance_count
  check(a.mesh==b.mesh and a.instance_count==b.instance_count,"CanonicalIl0.100m native bank mesh and placement count retained")
 check(placements==393,"All393native Il bank instances retained without GPU transform readback")
 left.free();right.free()
 for row:Array in data.cells:
  var at=Vector2(data.source_origin[0],data.source_origin[1])+Vector2(row[0],row[1])*3.
  check(old.height(at.x,at.y)==next.height(at.x,at.y),"All original source height queries retained "+str(row.slice(0,2)))
 var changed=Fresh.changed(snapshot);check(changed.is_empty(),"Loaded old/new field proof stayed source-current")
 var report={"checks":checks,"failures":errors.size(),"failed":errors,"source_hashes":snapshot,"source_changed":changed,"scope":"Exact source2000 field/native/physics/mesh/query regression after allowing verified2400dimensions. No source2400actual context, player/pet or visual approval."}
 var file=FileAccess.open(ROOT+"Field Compatibility/review.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print("LOW_VILLAGE_FIELD_COMPATIBILITY checks=",checks," failures=",errors.size());quit(1 if not errors.is_empty() else 0)

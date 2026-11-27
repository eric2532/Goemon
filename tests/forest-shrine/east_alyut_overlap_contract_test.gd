extends SceneTree
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Canonical Stage/"
var checks=0
var failures=[]
class TownView extends RefCounted:
 func surface_height(_x:float,_z:float)->float:return 0.
class FieldView extends RefCounted:
 var falan_area="north_coast"
func _initialize():call_deferred("run")
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);push_error(label)
func run():
 Full.review_root=FOLDER
 var paths=[get_script().resource_path,"scripts/forest/forest_east_alyut_source_completion.gd","scripts/forest/forest_east_region.gd",FOLDER+"map-data.json",FOLDER+"source-overlaps.json",FOLDER+"gate-handoffs.json"];var hashes=Fresh.snapshot(paths)
 var source=Full.source_overlap_data();check(source.source100_overlap_cells.size()==6,"Exactly six distinct source100overlap cells")
 var expected={};var field=FieldView.new();var native_open=0
 for row:Dictionary in source.source100_overlap_cells:
  var cell=Vector2i(row.village_cell[0],row.village_cell[1]);expected[cell]=true
  check(not Full.source_open(cell) and int(row.village_pg1)==0 and int(row.village_bg) in range(5000,5009),"Original2400water and walk remain untouched "+str(cell))
  check(not Full.field_handoff(cell),"Overlap ownership is separate from twelve gate buffers "+str(cell))
  check(Region.current_source(field,Full.local_point(Vector2(cell))+Vector2(-165,-123))==100,"Exact retained source100context "+str(cell))
  if row.field_native_open:native_open+=1
 check(native_open==5,"Five original100open land cells stay open; only the original flower is closed")
 for y in 100:
  for x in 100:check(Full.field_overlap(Vector2i(x,y))==expected.has(Vector2i(x,y)),"No other source cell becomes a100overlap "+str(Vector2i(x,y)))
 var plan=Full.plan(TownView.new(),[]);var flowers=plan.filter(func(row):return row.size()>3 and row[3]is Dictionary and row[3].get("source_overlap",false))
 check(flowers.size()==1,"Only one exact source100flower footprint is restored")
 if not flowers.is_empty():
  var box:AABB=flowers[0][2];var center=Full.local_point(Vector2(35,3))
  check(box.position.is_equal_approx(Vector3(center.x-1.5,5.95,center.y-1.5)) and box.size.x==3. and box.size.z==3. and box.size.y>=1.,"Flower native closure uses retained6mfield datum even though standalone2400has0mwater")
  check(flowers[0][3].map==100 and Vector2i(flowers[0][3].cell[0],flowers[0][3].cell[1])==Vector2i(564,23) and flowers[0][3].graphic==12172,"Original100PG1flower identity/1×1footprint retained")
 var water=Full.bank_underlay_water_rows();check(water.size()==76 and water.all(func(row):return not Full.field_overlap(row.source_cell)),"All six100cells are excluded from the separate2400water cuts")
 var gates:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"gate-handoffs.json"));check(gates.handoff_cells.size()==12,"All twelve original gate handoff cells remain separate")
 var changed=Fresh.changed(hashes);check(changed.is_empty(),"All ownership/closure source inputs remain current")
 var file=FileAccess.open(FOLDER+"source-overlap-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Pure original100/2400owner/collision/frame contract. Both raw map variants remain unchanged. Actual six-cell approach/return and source100flower closure remain separate verification."}," "));file.close()
 print("EAST_ALYUT_OVERLAP_CONTRACTS checks=",checks," failures=",failures.size());quit(failures.size())

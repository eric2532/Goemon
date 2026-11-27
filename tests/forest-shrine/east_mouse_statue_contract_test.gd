extends SceneTree
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Statue=preload("res://scripts/forest/forest_east_mouse_statue.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 create_timer(90,true,false,true).timeout.connect(func():printerr("MOUSE_CONTRACT_TIMEOUT");quit(2))
 run.call_deferred()
func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_original_maps.gd","scripts/forest/forest_east_mouse_statue.gd",Statue.ROOT+"data.json","assets/maps/original_crossgate/east/catalog.json","assets/maps/falan/east_region/population.json"]
 var hashes=Sources.snapshot(paths);var id=Maps.runtime_id(33608);var row:Dictionary=Maps.state(id)
 var raw:PackedByteArray=row.raw.duplicate();var bits:PackedByteArray=row.bits.duplicate();var links=JSON.stringify(Maps.links(id));var cut=Maps.crop(id)
 var art=Maps.Art.new();art.load_map(Maps.path_for(id),row.raw,row.size)
 var count=0;var ordinary=0;var cells:int=row.size.x*row.size.y
 for placement in art.placements:
  if placement[4]>=cells:continue
  var at:Vector2i=placement[5]+cut.position;var serial=int(placement[3]);var replaced=Statue.replaces_background(at,serial)
  if replaced:count+=1
  if serial in range(1220589,1220781) and not replaced:ordinary+=1;check(not Statue.replaces_background(at,serial),"Repeated ordinary BG remains outside sculpture owner")
 check(count==186,"Exactly186BGplacements replaced in actual source33608")
 check(ordinary>0,"Ordinary paving in the same graphic family remains present")
 for placement:Dictionary in Statue.data().sculpture_source_placements:check(Statue.replaces_background(Vector2i(placement.cell[0],placement.cell[1]),int(placement.graphic)),"Every unique sculpture tuple is covered")
 var scene=Node3D.new();root.add_child(scene);Maps.build(scene,id)
 var owner=scene.find_child("RecoveredSourceMouseStatue",true,false) as MeshInstance3D
 check(owner!=null and owner.mesh==Statue.mesh(),"Live map builds one prepared immutable sculpture")
 if owner!=null:
  var point=Maps.source_point(id,Vector2i(224,55));check(owner.position.is_equal_approx(Vector3(point.x,0,point.y)),"Live sculpture anchor is exact source224,55")
 check(Maps.cave(id) and not Maps.outdoor(id),"Room retains indoor cave classification")
 check(is_equal_approx(Maps.ceiling_height(id),Statue.mesh().get_meta("statue_bounds").end.y+1.5),"Minimum indoor roof clears the source-sized landmark")
 check(row.raw==raw and row.bits==bits and JSON.stringify(Maps.links(id))==links,"Source raw/walk/links remain unchanged by build")
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded sculpture contract sources remain current")
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Statue/Publication Candidate/contract.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"unique_sculpture_bg_replaced":count,"ordinary_family_bg_retained":ordinary,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Exact live33608BGownership, source preservation and indoor headroom. Rendered cameras and actor interaction require separate actual-world proof."},"  "));file.close()
 print("EAST_MOUSE_CONTRACT_RESULT checks=",checks," failures=",failures);scene.queue_free();await process_frame;quit(failures)

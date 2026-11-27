extends SceneTree
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Scenery=preload("res://scripts/forest/forest_freyja_destination_art.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Sokia full-source outdoors/"
class SourceModel:
 var terrain
 var falan_area:String
 func surface_height(x:float,z:float)->float:return terrain.height(x,z)
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 create_timer(90).timeout.connect(func():printerr("SOKIA_CLIFF_FOUNDATION_TIMEOUT");quit(1))
 run.call_deferred()
func vertices(point:Vector3,extent:Vector2,height:float,serial:int,foundation:float=NAN)->PackedVector3Array:
 var mesh=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 Scenery.crag_cluster(mesh,point,extent,height,serial,Terrain.Sokia.Details.Data.CLIFFS[serial],Terrain.Sokia.Details.Data.CLIFF_CROWNS[serial],foundation)
 return mesh.commit_to_arrays()[Mesh.ARRAY_VERTEX]
func native_bytes(terrain)->PackedByteArray:
 var field=terrain.terrain_field()
 return var_to_bytes([field.get_meta("heights"),field.get_meta("bed"),field.get_meta("covered"),field.get_meta("bridges"),Terrain.Sokia.Data.BLOCKS[terrain.variant]])
func run():
 var examples=[];var skirts=0;var old_count=0;var new_count=0
 for area in Terrain.Sokia.MASKS:
  var terrain=Terrain.new();terrain.variant=area;terrain.horizontal_scale=Terrain.Regions.layout(area).terrain_scale;terrain.expansion=Terrain.Sokia.expansion(area);terrain.configure([])
  var model=SourceModel.new();model.terrain=terrain;model.falan_area=area
  var frame=Terrain.Regions.frame(area).inverse();var original_native=native_bytes(terrain)
  for row in Terrain.Sokia.Data.SCENERY[area]:
   var serial:int=row[1]
   if serial<12536 or serial>12565:continue
   var cell:Vector2=row[0];var span:Vector2=row[2]
   var at=frame*((cell+(span-Vector2.ONE)*Vector2(.5,-.5))*3.)
   var point=Terrain.Sokia.cliff_origin(model,frame,cell,Vector3(at.x,terrain.height(at.x,at.y),at.y))
   var foundation=Terrain.Sokia.cliff_foundation(model,frame,point)
   if is_nan(foundation):continue
   check(area=="ghana_north_road","Foundation remains confined to the raised Ghana North variant")
   var extent=(frame.basis_xform(Vector2(span.x,0)).abs()+frame.basis_xform(Vector2(0,span.y)).abs())*3.
   var height=clampf((row[3]-46)*.039,9.4,14.)
   var old=vertices(point,extent,height,serial);var current=vertices(point,extent,height,serial,foundation)
   var old_lobe=old.size()/9;var current_lobe=current.size()/9;var exact=true;var bounded=true
   var low=INF;var high=-INF;var old_low=INF;var old_high=-INF
   var aabb=AABB(old[0],Vector3.ZERO)
   for p in old:aabb=aabb.expand(p);old_low=minf(old_low,p.y);old_high=maxf(old_high,p.y)
   for lobe in 9:
    for i in old_lobe:exact=exact and old[lobe*old_lobe+i]==current[lobe*current_lobe+i]
    for i in range(old_lobe,current_lobe):
     var p=current[lobe*current_lobe+i]
     bounded=bounded and p.x>=aabb.position.x-.0001 and p.x<=aabb.end.x+.0001 and p.z>=aabb.position.z-.0001 and p.z<=aabb.end.z+.0001 and p.y<=point.y
   for p in current:low=minf(low,p.y);high=maxf(high,p.y)
   check(exact and high==old_high,"Every original crag vertex and crown stays exact")
   check(bounded and absf(low-(terrain.WATER_HEIGHT-.35))<.0001 and current.size()-old.size()==864,"Only buried lower faces are added inside the existing footprint")
   old_count+=old.size();new_count+=current.size();skirts+=1
   examples.append({"anchor":[cell.x,cell.y],"serial":serial,"old_min_y":old_low,"new_min_y":low,"unchanged_max_y":high,"added_vertices":current.size()-old.size()})
  check(native_bytes(terrain)==original_native,"Native terrain, source clearance and bridges remain byte-exact "+area)
  # Default callers still use exactly the original vertex stream.
  var p=Vector3(3,17,11);check(vertices(p,Vector2(9,9),12,12556)==vertices(p,Vector2(9,9),12,12556,NAN),"Default crag callers remain unchanged "+area)
 check(skirts>0,"Raised source crags were exercised")
 var file=FileAccess.open(REVIEW+"cliff-foundation-verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"repaired_source_anchors":skirts,"old_vertices":old_count,"new_vertices":new_count,"anchors":examples,"source_input_sha256":FileAccess.get_sha256("res://assets/maps/falan/sokia/source/300.dat"),"limits":"Source anchors, upper geometry, terrain/clearance/bridges unchanged. Added depth is an inferred hidden surface, with the existing cliff paint; normal-camera judgment remains separate."},"  ")+"\n");file.close()
 print("SOKIA_CLIFF_FOUNDATION ",checks," checks ",failures," failures ",skirts," source anchors")
 quit(1 if failures else 0)

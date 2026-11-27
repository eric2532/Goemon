extends SceneTree
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate/"
var checks=0
var failures=[]
class Terrain extends RefCounted:
 var pieces=[]
 var height_buckets={}
 var maximum_height=0.
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label);push_error(label)
func strip_contains(rect:Array,p:Vector2)->bool:return p.x>=float(rect[0])-.00001 and p.x<=float(rect[2])+.00001 and p.y>=float(rect[1])-.00001 and p.y<=float(rect[3])+.00001
func run():
 Full.review_root=FOLDER
 var local_rows=Full.bank_rows();var joined=Full.bank_rows(true);var terrain=Terrain.new();Caps.append_pieces(terrain,joined)
 var prepared:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"banks.json"));var source_hash=Full.data().source.sha256
 check(local_rows.size()==117 and joined.size()==117 and prepared.counts.newly_recovered==99,"Exactly117 native source banks, including99 recovered")
 check(prepared.source_hybrid_sha256==source_hash,"Banks use active-compatible source2400")
 check(prepared.bank_data_sha256==FileAccess.get_sha256(Caps.ROOT+"data.json"),"Shared native-bank source data stays fresh")
 var probes=[];var seen={};var thin=[]
 for index in local_rows.size():
  var row:Dictionary=local_rows[index];var global_row:Dictionary=joined[index];var cell:Vector2i=row.source_cell;var serial=int(row.serial)
  check(not seen.has(cell),"One recovered cap owner "+str(cell));seen[cell]=true
  check(row.anchor==Full.local_point(Vector2(cell)),"Exact source cell anchor "+str(cell))
  check(global_row.anchor==row.anchor+Vector2(-165,-123),"Existing joined North frame "+str(cell))
  check(is_equal_approx(float(row.height),6.) and is_equal_approx(float(row.water_height),2.),"Separate source land/water datum "+str(cell))
  check(Full.source_open(cell),"Original source cap attribute remains open "+str(cell))
  check(row.native_open and row.support_only_rects==[[-1.5,-1.5,1.5,1.5]],"Invisible support preserves only the exact native-open bank tile "+str(cell))
  var cap_data:Dictionary=Caps.data().graphics[str(serial)]
  check(row.native_source_rgba_sha256==cap_data.source_rgba_sha256,"Exact native cap RGBA "+str(cell))
  var outline=Caps.cap_outline(serial);var stand=Vector2(row.deepest_stand[0],row.deepest_stand[1]);var supported=true
  for ray in 64:
   var p=stand+Vector2.from_angle(ray*TAU/64.)*.5
   if not Geometry2D.is_point_in_polygon(p,outline) or not Caps.support_rects(serial).any(func(rect):return strip_contains(rect,p)):supported=false
  check(supported,"Native half-metre disc fits prepared strips "+str(cell))
  check(Caps.all_rects(row).any(func(rect):return strip_contains(rect,Vector2(-.55,-.55))) and Caps.all_rects(row).any(func(rect):return strip_contains(rect,Vector2(.55,.55))),"Original source anchor is supported without alpha narrowing "+str(cell))
  if float(row.outline_clearance_local)<.60:thin.append([cell.x,cell.y,serial,row.outline_clearance_local])
  var at:Vector2=global_row.anchor+stand;var bucket=Vector2i(floori(at.x/12.),floori(at.y/12.))
  check(terrain.height_buckets.has(bucket),"Recovered support registered in bounded12m bucket "+str(cell))
  for approach:Dictionary in row.verified_approach_candidates:
   check(approach.source_neighbor.native_open and approach.source_neighbor.terrain_class=="dry_land" and approach.source_neighbor.height==row.height,"Join only touches original-open same-height dryland "+str(cell))
  probes.append({"cell":[cell.x,cell.y],"serial":serial,"joined_stand":[at.x,at.y],"disc_radius":.5,"disc_supported":supported,"source_clearance":row.outline_clearance_local,"dry_approaches":row.verified_approach_candidates.size()})
 check(terrain.maximum_height==6.,"No raised or underwater support datum")
 var report={"checks":checks,"failures":failures,"source_hybrid_sha256":source_hash,"bank_source_sha256":prepared.bank_data_sha256,"placements":probes,"native_pieces":terrain.pieces.size(),"height_buckets":terrain.height_buckets.size(),"less_than_point60_clearance":thin,"scope":"Pure exact-placement/source-alpha/bounded-support contract. Native player, actual assembled-map routes and visual acceptance are separate and unfinished."}
 var file=FileAccess.open(FOLDER+"bank-placement-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 print("EAST_ALYUT_BANK_CONTRACTS checks=",checks," failures=",failures.size()," placements=",local_rows.size());quit(failures.size())
func _initialize():call_deferred("run")

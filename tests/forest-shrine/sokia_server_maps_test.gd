extends SceneTree
## Source/renderer preparation only. No route or encounter activation.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server fixed maps/"
var checks=0
var failures=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("SOKIA_SERVER_MAP_FAIL ",message)
func _initialize():run.call_deferred()
func run():
 Original.Art.load_east()
 var base=Original.Art.data();var old_paths=base.maps.keys();var old_graphics=base.graphics.duplicate(true)
 Original.Art.load_sokia_server()
 check(base.maps.size()==old_paths.size()+13,"Exactly13missing maps append to existing owners")
 var old_same=true
 for key in old_graphics:
  if old_graphics[key]!=base.graphics[key]:old_same=false;break
 check(old_same,"Every existing graphic metadata/page binding stays unchanged")
 for path in ["atlas-1.png","university/atlas-0.png"]:
  var page=base.pages.find(path);var first=Original.Art.page_texture(page)
  check(first is ImageTexture and first.get_meta("original_source_page")==Original.Art.ROOT+path,"Exact prepared original page uses the existing setup owner: "+path)
  check(Original.Art.page_texture(page)==first,"Repeated page requests reuse the same prepared texture: "+path)
 var rows=[]
 for id in Original.Art.SOKIA_SERVER_IDS:
  var path=Original.path_for(id);var source:Dictionary=base.maps[path]
  var water=id in[13504,13509,13512]
  var enabled=water or id in Original.Art.EXPLORE_SERVER_IDS and source.layout_complete
  check(Original.owns(id)==enabled and source.sokia_visual_only==(not water),"Completed Explore dispatch preserves original source review markers: "+str(id))
  check(not source.source_flags_available and int(source.recorded)==0 and source.warp_cells.is_empty(),"Client flag/warp evidence remains unknown: "+str(id))
  var state=Original.state(id);var raw:PackedByteArray=Original.Art.raw_map(path)
  check(raw==state.raw,"Every complete server-derived source plane remains unchanged: "+str(id))
  var art=Original.Art.new();art.load_map(path)
  var count=0;var cells:int=state.size.x*state.size.y
  for i in cells:
   if raw.decode_u16(20+i*2)>0:count+=1
   if raw.decode_u16(20+(cells+i)*2)>=1000:count+=1
  check(art.placements.size()==count,"Existing art decoder retains every source tile/object station: "+str(id))
  var scene=Node3D.new();root.add_child(scene)
  var blocks=Original.build(scene,id)
  check(Original.Art.pending_page_uploads.is_empty(),"Map setup completes every newly-created CPU page upload: "+str(id))
  if id==5005:
   var house=scene.find_child("BlueCGVillageBuilding_11290",true,false)
   check(house!=null and house.get_meta("source_anchor")==Vector2i(15,13)and house.position.is_equal_approx(Vector3(6,0,-10.5)),"Whole existing11290house retains its measured source foot frame")
  check(scene.get_meta("recovered_source_path")==path,"Existing solid-map renderer owns the prepared layout: "+str(id))
  var finite_boxes=true
  for box:AABB in blocks:finite_boxes=finite_boxes and box.position.is_finite() and box.size.is_finite()
  check(finite_boxes,"Prepared collision bounds are finite: "+str(id))
  rows.append({"id":id,"size":str(state.size),"source_stations":count,"prepared_colliders":blocks.size(),"fixed_port_candidates":source.fixed_port_candidates.size(),"event_port_candidates":source.event_port_candidates.size(),"source_flags_available":false,"route_status":source.gate_status})
  scene.queue_free();await process_frame
 var file=FileAccess.open(REVIEW+"headless-source-renderer.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"maps":rows,"limitations":["Prepared nodes and finite boxes do not establish rendered appearance or combat clearance.","Completed source rooms have Explore owners; ordinary and quest-gated routes still need their own walking/interaction evidence."]},"  ")+"\n");file.close()
 print("SOKIA_SERVER_MAP_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

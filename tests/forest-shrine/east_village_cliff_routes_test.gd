extends "res://tests/forest-shrine/east_village_buildings_review.gd"
## Reuse all11 real house round trips after the native Alyut cliff obstacle correction.
const Cliffs=preload("res://scripts/forest/forest_east_field_cliffs.gd")
const CLIFF_ROUTE_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/"
var gate_audit=[]
func building_source_views():pass
func prop_views(_label:String,_preferred:Vector2i,_other:Vector2i,_target:Vector2i):pass

func source_contracts(map_id:int):
 await super.source_contracts(map_id)
 if map_id!=2400:return
 var source:Dictionary=Cliffs.data().alyut
 var joined=game.model.get_meta("joined_village")
 var rows=joined.falan_frontier_plan.filter(func(row):return row[0]=="archive_cliff" and row.size()>4 and row[3]==2400)
 check(rows.size()==source.blocked_cliff_cells.size()-source.opening_exceptions.size(),"Every original blocked Alyut cliff cell enters the existing obstacle owner once")
 var bits=Cliffs.walk_bits;var allowed=true
 for row in rows:
  var index=row[4].y*int(source.size[0])+row[4].x
  if bits[index>>3]&(1<<(index&7)) or source.protected_cells.has([row[4].x,row[4].y]):allowed=false
 check(allowed,"Alyut cliff obstacles preserve every native walk bit and original gate/house portal")
 for gate in [["north",Tour.Regions.ALYUT_NORTH_GATE],["south",Tour.Regions.ALYUT_SOUTH_GATE]]:
  var at=Tour.Regions.village_transform("alyut")*gate[1]
  var clear=true
  for i in 17:
   if not clear_point(at+Vector2(0,-4.+i*.5)):clear=false
  check(clear,"Original Alyut gate keeps its full existing north/south approach: "+gate[0])
  var crossed=[]
  for direction in [Vector2.UP,Vector2.DOWN]:
   await position_at(at-direction*4.)
   game.camera_rig.yaw=atan2(-direction.x,-direction.y)
   Input.action_press("move_forward")
   for i in 100:
    await physics_frame
    if (map_position()-at).dot(direction)>2.:break
   Input.action_release("move_forward")
   var passed=(map_position()-at).dot(direction)>1.5
   check(passed,"Normal on-foot movement crosses the original Alyut gate "+gate[0]+" "+str(direction));crossed.append(passed)
  gate_audit.append({"gate":gate[0],"clearance":clear,"on_foot_both_directions":crossed})

func report():
 var file=FileAccess.open(CLIFF_ROUTE_OUT+"house-route-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"door_audit":door_audit,"placement_audit":placement_audit,"gate_audit":gate_audit,"source_walk_sha256":Cliffs.data().alyut.walk_sha256,"source_map_sha256":Cliffs.data().alyut.source_sha256,"source_blocked_cliff_cells":Cliffs.data().alyut.blocked_cliff_cells.size(),"source_walkable_cliff_cells":Cliffs.data().alyut.walkable_cliff_cells,"opening_exceptions":Cliffs.data().alyut.opening_exceptions,"scope":"All11Il/Alyut house enter/return micro-approaches plus native north/south Alyut gate clearance and on-foot crossings after recovering native cliff obstacles. Reuses the existing building fixture without overwriting its earlier source/art evidence."},"  "));file.close()

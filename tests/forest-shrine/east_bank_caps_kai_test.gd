extends SceneTree
## Numeric player-terrain checks; no imported mesh, render or gameplay claim.
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
class Field extends "res://scripts/forest/forest_kai_terrain.gd":
 var origin=Vector2.ZERO
 func terrain_field()->Resource:return null
 func coordinate(x:float,z:float)->Vector2:return (Vector2(x,z)-origin)/spacing
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func field(anchor:Vector2):
 var result=Field.new();result.configure([]);result.width=25;result.spacing=3.9;result.origin=anchor-Vector2.ONE*46.8
 result.heights.resize(625);result.covered.resize(625)
 for z in 25:
  for x in 25:
   if x<=11:result.heights[z*25+x]=7.8;result.covered[z*25+x]=1
 return result
func run():
 for anchor in [Vector2(-717.6,1154.4),Vector2(-378.3,-343.2),Vector2(-12,-12),Vector2(12,12)]:
  for serial in [12528,12503,12527,12515,12502]:
   var terrain=field(anchor);var before_heights=terrain.heights.duplicate();var before_covered=terrain.covered.duplicate()
   var row:Dictionary=Caps.data().graphics[str(serial)];var approach:Dictionary=row.approaches.west
   # Technical candidate joins are separate from actual source enrollment.
   # Actual Il/Alyut may use only joins supported by their original cells.
   var placement={"serial":serial,"anchor":anchor,"height":7.8,"frame":Transform2D(0.,Vector2.ONE*1.3,0.,Vector2.ZERO),"source_cell":Vector2i.ZERO,"join_rects":[approach.join_rect]}
   Caps.append_pieces(terrain,[placement])
   var stand=anchor+Vector2(approach.stand[0],approach.stand[1])*1.3
   check(terrain.contains(stand.x,stand.y),"Exact cap supplies contains over void "+str(serial))
   check(absf(terrain._covered_height(stand.x,stand.y)-7.8)<.0001,"Player covered-height uses explicit source strip "+str(serial))
   for radius in [.25,.35,.60]:check(terrain.disk_clear(Vector3(stand.x,7.8,stand.y),radius),"Source strip supports radius at its measured interior "+str(serial))
   var water=anchor+Vector2(8,8)
   check(not terrain.contains(water.x,water.y)and is_nan(terrain._covered_height(water.x,water.y))and not terrain.disk_clear(Vector3(water.x,0,water.y),.25),"Unrelated water stays void")
   var land=anchor-Vector2(12,0)
   check(terrain.contains(land.x,land.y)and absf(terrain._covered_height(land.x,land.y)-7.8)<.0001,"Original covered field remains unchanged")
   check(terrain.heights==before_heights and terrain.covered==before_covered,"No field heights/covered bytes changed")
   terrain.configure([]);check(not terrain.contains(stand.x,stand.y),"Reconfiguration removes explicit support")
 print("EAST_BANK_CAP_KAI_RESULT checks=",checks," failures=",failures)
 quit(failures)

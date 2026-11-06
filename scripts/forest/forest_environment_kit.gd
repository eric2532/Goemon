@static_unload
extends RefCounted
## Authoring recipes for the existing rampart owner; dimensions are map cells/metres.
const DIR="res://assets/models/environments/wind_meadow/modular/"
const Ramparts=preload("res://scripts/forest/forest_ramparts.gd")
const LABELS={"platform_18":"Platform 18m","causeway_36":"Causeway 36m","ramp_6":"Ramp +6m","ramp_12":"Ramp +12m","platform_30":"Platform 30m","corner_18":"Corner 18m","t_junction_18":"T Junction 18m"}
static var scenes:Dictionary={}
static func scene(kind:String)->PackedScene:
 if not scenes.has(kind):scenes[kind]=load(DIR+kind+".tscn")
 return scenes[kind]
const TERRAIN={
 "platform_18":{"length":3,"width":3,"h0":6,"h1":6},
 "causeway_36":{"length":6,"width":3,"h0":6,"h1":6},
 "ramp_6":{"length":3,"width":3,"h0":0,"h1":6},
 "ramp_12":{"length":6,"width":3,"h0":0,"h1":12},
 "platform_30":{"length":5,"width":5,"h0":6,"h1":6}
}
const JUNCTIONS={
 "corner_18":[{"ax":0,"az":0,"bx":4.5,"bz":0},{"ax":3,"az":1.5,"bx":3,"bz":4.5}],
 "t_junction_18":[{"ax":0,"az":0,"bx":6,"bz":0},{"ax":3,"az":1.5,"bx":3,"bz":4.5}]
}
static func is_module(kind:String)->bool:return LABELS.has(kind)
static func placement(kind:String,cell:Vector2,turn:int,base_height:float)->Array:
 var result=segments(kind,cell,turn,base_height)
 for piece in result:
  for key in ["ax","az","bx","bz","width","h0","h1"]:piece[key]=float(piece[key])
 result[0].kit={"kind":kind,"x":cell.x,"z":cell.y,"rotation":float(turn),"height":base_height}
 return result
static func bounds(pieces:Array)->Rect2:
 var result=Ramparts.bounds(pieces.front())
 for piece in pieces.slice(1):result=result.merge(Ramparts.bounds(piece))
 return result
static func validation_error(pieces:Array)->String:
 var index=0
 while index<pieces.size():
  if not pieces[index].has("kit"):index+=1;continue
  var item=pieces[index].kit
  if not item is Dictionary or not item.get("kind") is String or not is_module(item.kind):return "Unsupported terrain module."
  for key in ["x","z","height","rotation"]:
   if not (item.get(key) is int or item.get(key) is float) or not is_finite(float(item[key])):return "Invalid terrain module transform."
  var rise=12 if item.kind=="ramp_12" else 6
  if item.rotation!=floor(item.rotation) or item.rotation<0 or item.rotation>3 or item.height<0 or item.height+rise>Ramparts.MAX_HEIGHT:return "Invalid terrain module height or rotation."
  if item.x*2!=floor(item.x*2) or item.z*2!=floor(item.z*2):return "Terrain modules use the three-metre grid."
  var expected=segments(item.kind,Vector2(item.x,item.z),int(item.rotation),float(item.height))
  if index+expected.size()>pieces.size():return "Incomplete terrain module."
  for part in expected.size():
   if part>0 and pieces[index+part].has("kit"):return "Overlapping terrain module records."
   for key in expected[part]:
    if pieces[index+part].get(key)!=expected[part][key]:return "Terrain module geometry does not match its transform."
  index+=expected.size()
 return ""
static func segments(kind:String,cell:Vector2,quarter_turn:int=0,base_height:float=0)->Array:
 if TERRAIN.has(kind):return [segment(kind,cell,quarter_turn,base_height)]
 assert(JUNCTIONS.has(kind) and quarter_turn in [0,1,2,3])
 var result=[]
 for source in JUNCTIONS[kind]:
  var a=Vector2(source.ax,source.az).rotated(quarter_turn*PI/2).snapped(Vector2.ONE*.5)+cell
  var b=Vector2(source.bx,source.bz).rotated(quarter_turn*PI/2).snapped(Vector2.ONE*.5)+cell
  result.append({"ax":a.x,"az":a.y,"bx":b.x,"bz":b.y,"width":3,"h0":6+base_height,"h1":6+base_height,"cap_start":false,"cap_end":false,"joined":true})
 return result
static func segment(kind:String,cell:Vector2,quarter_turn:int=0,base_height:float=0)->Dictionary:
 assert(TERRAIN.has(kind) and quarter_turn in [0,1,2,3] and is_finite(base_height) and base_height>=0)
 var recipe:Dictionary=TERRAIN[kind]
 var direction:Vector2i=[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP][quarter_turn]
 var end=cell+Vector2(direction)*int(recipe.length)
 return {"ax":cell.x,"az":cell.y,"bx":end.x,"bz":end.y,"width":recipe.width,"h0":recipe.h0+base_height,"h1":recipe.h1+base_height,"cap_start":false,"cap_end":false}

extends Node3D
## The shaft joins the two original floor grids on their entrance cells.
const Art=preload("res://scripts/forest/forest_art.gd")
const CHAMBER=11004
const BASEMENT=11028
const HATCH_CELL=Vector2i(9,10)
const BASEMENT_CELL=Vector2i(8,4)
const HATCH=Vector2(-93,-120)
const LOWER_HATCH=Vector2(9,-3)
const DEPTH=9.25
const HALF_SIZE=1.5
const BOTTOM_EXIT=Vector3(-3,-DEPTH+.08,0)
const TOP_EXIT=Vector3(0,.08,3)

var cover:StaticBody3D
var lid:Node3D
var open=false
var climbing=false
var descending=false
var progress=0.0
var mount_point=Vector3.ZERO

static func split_slab(parent:Node3D,bounds:Rect2,openings:Array[Vector2],y:float,thickness:float)->Array[StaticBody3D]:
 var pieces:Array[Rect2]=[bounds]
 for opening in openings:
  var cut=Rect2(opening-Vector2.ONE*HALF_SIZE,Vector2.ONE*HALF_SIZE*2)
  var remaining:Array[Rect2]=[]
  for piece in pieces:
   if not piece.intersects(cut):
    remaining.append(piece)
    continue
   var hole=piece.intersection(cut)
   for rect:Rect2 in [
    Rect2(piece.position,Vector2(piece.size.x,hole.position.y-piece.position.y)),
    Rect2(piece.position.x,hole.end.y,piece.size.x,piece.end.y-hole.end.y),
    Rect2(piece.position.x,hole.position.y,hole.position.x-piece.position.x,hole.size.y),
    Rect2(hole.end.x,hole.position.y,piece.end.x-hole.end.x,hole.size.y)]:
    if rect.has_area():remaining.append(rect)
  pieces=remaining
 var bodies:Array[StaticBody3D]=[]
 for rect in pieces:
  var center:Vector2=rect.get_center()
  bodies.append(Art.solid(parent,Vector3(center.x,y,center.y),Vector3(rect.size.x,thickness,rect.size.y),1,"stone"))
 return bodies

func build():
 var wood=Geo.mat("765031")
 var rung=Geo.mat("af8051")
 var iron=Geo.mat("434745",.25)
 var collar=Geo.mat("685b49")
 for side in [-1,1]:
  Geo.box(self,Vector3(side*.83,-DEPTH*.5+.28,-1.24),Vector3(.19,DEPTH+.42,.21),wood)
 for index in 21:
  var y=-.18-index*.43
  Geo.box(self,Vector3(0,y,-1.20),Vector3(1.65,.12,.23),rung)
  if index%5==0:
   for side in [-1,1]:
    Geo.box(self,Vector3(side*.84,y,-1.10),Vector3(.25,.20,.05),iron)
 for side in [-1,1]:
  Geo.box(self,Vector3(side*1.48,-.12,0),Vector3(.15,.32,3.05),wood)
  Geo.box(self,Vector3(side*1.58,-.40,0),Vector3(.16,.80,3.32),collar)
  Geo.box(self,Vector3(0,-.40,side*1.58),Vector3(3.0,.80,.16),collar)
 cover=Art.solid(self,Vector3(0,-.11,0),Vector3(3,.22,3),1,"wood")
 lid=Node3D.new()
 lid.position=Vector3(0,-.09,-1.48)
 add_child(lid)
 for index in 6:
  Geo.box(lid,Vector3(-1.25+index*.5,0,1.48),Vector3(.48,.19,2.93),wood)
 for x in [-.90,.90]:
  Geo.box(lid,Vector3(x,.103,1.48),Vector3(.11,.025,2.88),iron)
 sync_cover()

func sync_cover():
 var unlocked:bool=get_tree().get_meta("habaru_slain",{}).has(0)
 if unlocked==open:return
 open=unlocked
 lid.rotation.x=-PI*.5 if open else 0.0
 cover.collision_layer=0 if open else 1

func step(player,delta:float)->bool:
 sync_cover()
 if not open:return false
 if not climbing:
  var point=to_local(player.global_position)
  if absf(point.x)>1.08 or absf(point.z)>1.08:return false
  var at_top=absf(point.y)<.75
  var at_bottom=absf(point.y+DEPTH)<.40
  if not at_top and not at_bottom:return false
  if Vector2(player.velocity.x,player.velocity.z).length_squared()<.05:return false
  descending=at_top
  climbing=true
  progress=0.0
  mount_point=point
  player.jump_buffer=0
  player.jump_windup=0
  player.facing=Vector3.FORWARD
  player.model.rotation.y=0.0
  player.game.camera_rig.reset_follow()
 progress=minf(progress+delta/2.75,1.0)
 var top=Vector3(0,.08,-.44)
 var bottom=Vector3(0,-DEPTH+.08,-.44)
 var start=top if descending else bottom
 var finish=bottom if descending else top
 var exit=BOTTOM_EXIT if descending else TOP_EXIT
 var point:Vector3
 if progress<.14:point=mount_point.lerp(start,smoothstep(0,.14,progress))
 elif progress>.83:point=finish.lerp(exit,smoothstep(.83,1.0,progress))
 else:point=start.lerp(finish,(progress-.14)/.69)
 player.global_position=to_global(point)
 player.velocity=Vector3.ZERO
 player.model.locomotion_velocity=Vector3.ZERO
 player.model.animate(delta,0,true,0,0,false,0,false)
 if progress>=1.0:
  climbing=false
  player.game.camera_rig.reset_follow()
 return true

extends RefCounted
## Shared stone stairs placed on the archived cave warp cells.
const Art=preload("res://scripts/forest/forest_art.gd")
const DOWN_CELLS={11003:[Vector2i(41,8)],11005:[Vector2i(21,39)],
 11000:[Vector2i(8,10),Vector2i(20,59)],11002:[Vector2i(35,10),Vector2i(10,59)]}
const STONE={
 17952:preload("res://assets/maps/falan/habaru_stair_17952.png"),
 17953:preload("res://assets/maps/falan/habaru_stair_17953.png"),
 17954:preload("res://assets/maps/falan/habaru_stair_17954.png"),
 17955:preload("res://assets/maps/falan/habaru_stair_17955.png"),
 12001:preload("res://assets/maps/falan/habaru_stair_12001.png"),
}
const RISE=1.62
const RUN=3.0
const WIDTH=2.68

static func uphill(serial:int)->Vector2:
 return Vector2.RIGHT if serial==12001 else Vector2.UP

static func build(parent:Node3D,id:int,cell:Vector2i,at:Vector2,serial:int,surface:Material=null,visual_mesh:Mesh=null,step_count:int=5):
 var stair=Node3D.new()
 stair.name=("UnderseaStair" if serial in [13268,13269] else "HabaruStair")+"_%d_%d"%[cell.x,cell.y]
 stair.set_meta("blue_cg_serial",serial)
 stair.position=Vector3(at.x,0,at.y)
 parent.add_child(stair)
 var down=serial in [17953,17955,13269,17975,12002]
 if visual_mesh!=null:
  Geo.mesh(stair,visual_mesh,Vector3.ZERO,null)
  stair.rotation.y=(PI if id==11005 else 0.0) if down else (-PI*.5 if serial==12001 else 0.0)
  ramp(stair,Vector3(0,-.50,0) if down else Vector3(0,RISE*.5-.035,0),.34 if down else -RISE/RUN,2.5 if down else WIDTH)
  return
 var tread:Material=surface
 var stone:Material=surface
 if surface==null:
  var original=StandardMaterial3D.new()
  original.albedo_texture=STONE[serial]
  original.uv1_triplanar=true
  original.uv1_world_triplanar=true
  original.uv1_scale=Vector3(.67,.95,.67)
  original.roughness=.93
  var original_stone:StandardMaterial3D=original.duplicate()
  original_stone.albedo_color=Color("a9a9a0")
  tread=original;stone=original_stone
 if down:
  stair.rotation.y=PI if id==11005 else 0.0
  for side in [-1,1]:
   Geo.box(stair,Vector3(side*1.36,-.59,0),Vector3(.28,1.31,3),stone)
   Geo.box(stair,Vector3(side*1.36,.037,0),Vector3(.28,.12,3),tread)
  Geo.box(stair,Vector3(0,.013,1.44),Vector3(2.44,.10,.12),tread)
  Geo.box(stair,Vector3(0,-.59,-1.38),Vector3(2.44,1.30,.24),stone)
  Geo.box(stair,Vector3(0,.037,-1.36),Vector3(2.44,.12,.28),tread)
  Geo.box(stair,Vector3(0,-1.22,0),Vector3(2.44,.12,2.76),Geo.mat("211e19"))
  for step in 4:
   var at_step=Vector3(0,-.18-step*.26,1.14-step*.59)
   Geo.box(stair,at_step,Vector3(2.40,.20,.64),stone)
   Geo.box(stair,at_step+Vector3.UP*.105,Vector3(2.39,.045,.61),tread)
  ramp(stair,Vector3(0,-.50,0),.34,2.5)
  return
 stair.rotation.y=-PI*.5 if serial==12001 else 0.0
 var steps=step_count
 for i in steps:
  var depth=RUN/steps
  var height=RISE*(i+1)/steps
  var at_step=Vector3(0,height*.5,1.5-depth*(i+.5))
  Geo.box(stair,at_step,Vector3(WIDTH,height,depth+.02),stone)
  Geo.box(stair,Vector3(0,height-.04,at_step.z+.018),Vector3(WIDTH+.10,.115,depth+.09),tread)
 ramp(stair,Vector3(0,RISE*.5-.035,0),-RISE/RUN,WIDTH)

static func ramp(stair:Node3D,at:Vector3,slope:float,width:float):
 var angle=atan(slope)
 var body=Art.solid(stair,Vector3.ZERO,Vector3(width,.13,RUN/cos(angle)),1,"stone")
 body.name="HabaruWalkableTreads"
 body.position=at
 body.rotation.x=-angle

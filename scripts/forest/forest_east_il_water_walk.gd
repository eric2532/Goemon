extends RefCounted
## Process-private source242water floors and three inferred entry grades.
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
const Shore=preload("res://scripts/forest/forest_east_il_bank_closure.gd")
const Palace=preload("res://scripts/forest/forest_falan_palace_art.gd")

static func bank_rows(shore_path:String,proposal:Dictionary,frame:Transform2D=Transform2D.IDENTITY)->Array:
 var changed={};var entries={}
 for row:Dictionary in proposal.height_changes:changed[Vector2i(row.source_cell[0],row.source_cell[1])]=true
 for ramp:Dictionary in proposal.ramps:entries[Vector2i(ramp.source_bank_cell[0],ramp.source_bank_cell[1])]=float(ramp.h0)
 var result=Shore.placements(shore_path,frame)
 for row:Dictionary in result:
  if entries.has(row.source_cell):row.height=entries[row.source_cell];row.join_rects=[]
  else:
   var keep=[]
   for index in row.join_source_neighbors.size():
    var neighbor:Dictionary=row.join_source_neighbors[index];var cell=Vector2i(neighbor.cell[0],neighbor.cell[1])
    if not changed.has(cell):keep.append(row.join_rects[index])
   row.join_rects=keep
 return result

static func add_piece(terrain,a:Vector2,b:Vector2,half:float,h0:float,h1:float,cell:Vector2i):
 var along=(b-a).normalized();var piece={"a":a,"b":b,"along":along,"side":Vector2(-along.y,along.x),"half":half,"length":a.distance_to(b),"start":0.,"end":a.distance_to(b),"h0":h0,"h1":h1,"joined":true,"source_water_walk":true,"source_cell":cell}
 terrain.pieces.append(piece);terrain.maximum_height=maxf(terrain.maximum_height,maxf(h0,h1))
 var pad=piece.side.abs()*half+Vector2.ONE*.002;var low=a.min(b)-pad;var high=a.max(b)+pad
 for x in range(floori(low.x/12.),floori(high.x/12.)+1):
  for z in range(floori(low.y/12.),floori(high.y/12.)+1):
   var key=Vector2i(x,z)
   if not terrain.height_buckets.has(key):terrain.height_buckets[key]=[]
   terrain.height_buckets[key].append(piece)

static func append_supports(terrain,proposal:Dictionary,frame:Transform2D=Transform2D.IDENTITY):
 assert(is_equal_approx(frame.x.length(),1.) and is_equal_approx(frame.y.length(),1.),"Private source floor support uses the original unit source frame")
 for row:Dictionary in proposal.water_rows:
  var anchor=Vector2(row.anchor[0],row.anchor[1]);var cell=Vector2i(row.source_cell[0],row.source_cell[1])
  assert(int(row.source_object)==252 and int(row.source_bg) in range(5000,5009),"No ordinary water or blocked source cell gains new support")
  add_piece(terrain,frame*(anchor+Vector2(-1.5,0)),frame*(anchor+Vector2(1.5,0)),1.5,float(row.height),float(row.height),cell)
 for row:Dictionary in proposal.ramps:
  add_piece(terrain,frame*Vector2(row.a[0],row.a[1]),frame*Vector2(row.b[0],row.b[1]),float(row.half),float(row.h0),float(row.h1),Vector2i(row.source_bank_cell[0],row.source_bank_cell[1]))
  add_piece(terrain,frame*Vector2(row.b[0],row.b[1]),frame*Vector2(row.landing_end[0],row.landing_end[1]),float(row.half),float(row.h1),float(row.h1),Vector2i(row.source_bank_cell[0],row.source_bank_cell[1]))

static func build_floors(root:Node3D,proposal:Dictionary):
 var water_shape=BoxShape3D.new();water_shape.size=Vector3(3.,.06,3.)
 for row:Dictionary in proposal.water_rows:
  var before=root.get_child_count();Palace.support(root,water_shape,Vector3(row.anchor[0],float(row.height)-.03,row.anchor[1]))
  var body:StaticBody3D=root.get_child(before);body.name="Source252WaterFloor";body.set_meta("source_water_walk",true);body.set_meta("source_cell",Vector2i(row.source_cell[0],row.source_cell[1]))
 for row:Dictionary in proposal.ramps:
  var a=Vector2(row.a[0],row.a[1]);var b=Vector2(row.b[0],row.b[1]);var side=Vector2(-(b-a).normalized().y,(b-a).normalized().x)*float(row.half)
  var points=PackedVector3Array()
  for sign_ in [-1,1]:
   points.append(Vector3(a.x+side.x*sign_,row.h0,a.y+side.y*sign_));points.append(Vector3(b.x+side.x*sign_,row.h1,b.y+side.y*sign_))
  var tops=points.duplicate()
  for p:Vector3 in tops:points.append(p-Vector3.UP*.06)
  var shape=ConvexPolygonShape3D.new();shape.points=points;var before=root.get_child_count();Palace.support(root,shape,Vector3.ZERO)
  var body:StaticBody3D=root.get_child(before);body.name="Source252InferredEntryGrade";body.set_meta("source_water_walk",true);body.set_meta("source_cell",Vector2i(row.source_bank_cell[0],row.source_bank_cell[1]))
  var end=Vector2(row.landing_end[0],row.landing_end[1]);var along=(end-b).normalized();var landing=BoxShape3D.new();landing.size=Vector3(b.distance_to(end),.06,float(row.half)*2.)
  before=root.get_child_count();var middle=(b+end)*.5;Palace.support(root,landing,Vector3(middle.x,float(row.h1)-.03,middle.y))
  var landing_body:StaticBody3D=root.get_child(before);landing_body.basis=Basis(Vector3(along.x,0,along.y),Vector3.UP,Vector3(-along.y,0,along.x));landing_body.name="Source252EntryLanding";landing_body.set_meta("source_water_walk",true)

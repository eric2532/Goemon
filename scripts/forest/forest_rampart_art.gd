extends RefCounted
## Solid fortress causeways, with open joins and physical ramp/deck collision.
const Art=preload("res://scripts/forest/forest_art.gd")
const StaticBoxes=preload("res://scripts/forest/forest_static_boxes.gd")
static func build(world: Node3D,parent: Node3D):
 var terrain=world.model.terrain
 if terrain.pieces.is_empty():return
 var root=Node3D.new();root.name="RaisedWallRoutes";parent.add_child(root)
 var boxes=StaticBoxes.new()
 var stone=world.fog_material(Color("596c69"));var cap=world.fog_material(Color("aab7a0"));var dark=world.fog_material(Color("3b4c4b"))
 for piece in terrain.pieces:
  var a: Vector2=piece.a;var along: Vector2=piece.along;var side: Vector2=piece.side
  var start: Vector2=a+along*piece.start;var end: Vector2=a+along*piece.end
  var h0=lerpf(piece.h0,piece.h1,clampf(piece.start/piece.length,0,1));var h1=lerpf(piece.h0,piece.h1,clampf(piece.end/piece.length,0,1))
  var corners=[start-side*piece.half,start+side*piece.half,end+side*piece.half,end-side*piece.half]
  var points=PackedVector3Array()
  for p in corners:points.append(Vector3(p.x,-.2,p.y))
  for i in 4:points.append(Vector3(corners[i].x,h0 if i<2 else h1,corners[i].y))
  var mesh=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
  # Godot's clockwise front faces, including a continuous sloped deck.
  for face in [[4,5,6,7],[0,3,2,1],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
   for i in [0,2,1,0,3,2]:mesh.add_vertex(points[face[i]])
  mesh.generate_normals();var visual=Geo.mesh(root,mesh.commit(),Vector3.ZERO,stone)
  visual.name="StoneWallDeck";visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
  var body=StaticBody3D.new();body.name="WalkableRampart";body.collision_layer=1;body.collision_mask=0;body.set_meta("forest_terrain",true);root.add_child(body)
  var collision=CollisionShape3D.new();var hull=ConvexPolygonShape3D.new();hull.points=points;collision.shape=hull;body.add_child(collision)
  # Repeated stone ledges and buttresses make the height legible from the ground.
  var count=maxi(1,ceili((piece.end-piece.start)/6.0))
  for i in range(count):
   var u=lerpf(piece.start,piece.end,(i+.5)/count);var center=a+along*u
   var top=lerpf(piece.h0,piece.h1,clampf(u/piece.length,0,1))
   if top<.8:continue
   for sign_ in [-1,1]:
    var edge=center+side*(piece.half+.1)*sign_;var outside=center+side*(piece.half+1.6)*sign_
    if absf(terrain.height(outside.x,outside.y)-top)<.5:continue
    var rail=Vector3(edge.x,top+1.0,edge.y)
    var size_=Vector3(1.5,2,6.05) if absf(along.y)>.5 else Vector3(6.05,2,1.5)
    boxes.add(rail,size_,cap);Art.solid(root,rail,size_)
    var tooth=Vector3(edge.x,top+2.6,edge.y)
    boxes.add(tooth,Vector3(2.5,1.4,2.5),cap)
    if i%2==0:
     var support=Vector3(edge.x,top*.45,edge.y)
     boxes.add(support,Vector3(2.4,top*.9,2.4),dark)
  # Cap only genuinely exposed ends; joined routes have no blocking parapet.
  for end_u in [piece.start,piece.end]:
   var middle=a+along*end_u;var top=lerpf(piece.h0,piece.h1,clampf(end_u/piece.length,0,1))
   var outward=along*(-1 if end_u==piece.start else 1)
   var outside=middle+outward*1.5
   if top<1 or absf(terrain.height(outside.x,outside.y)-top)<.5:continue
   for step in range(-2,3):
    var p=middle+side*step*6
    var size_=Vector3(6,2,1.5) if absf(along.y)>.5 else Vector3(1.5,2,6)
    boxes.add(Vector3(p.x,top+1,p.y),size_,cap);Art.solid(root,Vector3(p.x,top+1,p.y),size_)
 boxes.build(root)

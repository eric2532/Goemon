extends RefCounted
## The archive stores one dry road surface even where the road is above a canal.
const BRIDGES=[
 Rect2(-241.5,-9,24,18), Rect2(-73.5,-9,27,18),
 Rect2(-144,46.5,12,24), Rect2(-144,-70.5,12,24),
 Rect2(-147,307.5,18,72), Rect2(-147,-325.5,18,27),
 Rect2(-127.5,-342,24,15), Rect2(214.5,-12,72,24),
]
const Data=preload("res://assets/maps/falan/city_street_data.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const Parts=preload("res://scripts/forest/forest_falan_fort_parts.gd")
static var masonry_returns={}

static func junctions()->Dictionary:
 if not masonry_returns.is_empty():return masonry_returns
 var stations={};var seen={};var bounds=[];var contacts=[]
 for i in Data.FORTIFICATIONS.size():stations[Data.FORTIFICATIONS[i][0]]=i
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var brick=SurfaceTool.new();brick.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in Data.FORTIFICATIONS.size():
  var row:Array=Data.FORTIFICATIONS[i];var serial:int=row[1]
  if serial not in [10640,10641]:continue
  var axis=Vector2.RIGHT if serial==10640 else Vector2.DOWN
  var frame=Transform3D(Basis(Vector3.UP,0 if serial==10640 else -PI*.5),Court.point(row[0]))
  var wall_pose=frame.affine_inverse()*Transform3D(Basis.IDENTITY,Court.point(row[0]))
  var wall_mesh=Parts.prepare(serial);var top:float=wall_mesh.get_meta("falan_wall_top")-.025
  for side in [-1,1]:
   var at:Vector2=row[0]+axis*9*side
   if not stations.has(at):continue
   var j:int=stations[at];var other:Array=Data.FORTIFICATIONS[j]
   if other[1] not in [10640,10641] and not (other[1] in range(10647,10654) or other[1] in range(10655,10662)):continue
   var key=Vector2i(mini(i,j),maxi(i,j))
   if seen.has(key):continue
   seen[key]=true
   var other_mesh=Parts.prepare(other[1]);var other_pose=frame.affine_inverse()*Transform3D(Basis.IDENTITY,Court.point(other[0]))
   var heights=[0.0,top]
   for height in [wall_mesh.get_meta("falan_wall_knee"),other_mesh.get_meta("falan_foundation_top",other_mesh.get_meta("falan_wall_knee",0.0))]:
    if height>.01 and height<top-.01 and not heights.has(height):heights.append(height)
   heights.sort();var rings=[];var join_bounds=AABB();var first_point=true
   for height in heights:
    var wall=Parts.stone_section(serial,wall_pose,height);var full=Parts.stone_section(other[1],other_pose,height)
    assert(wall.has_area() and full.has_area(),"A masonry return requires solid stone on both ends")
    var z0=maxf(wall.position.y,full.position.y);var z1=minf(wall.end.y,full.end.y)
    if z1-z0<.1:
     var closest=clampf(wall.get_center().y,full.position.y+.15,full.end.y-.15);z0=closest-.1;z1=closest+.1
    var contact=Parts.stone_section(other[1],other_pose,height,Vector2(z0,z1))
    assert(contact.has_area(),"A masonry return must enter the neighbour's actual section")
    var start=wall.end.x-.3 if side>0 else contact.end.x-.3
    var end=contact.position.x+.3 if side>0 else wall.position.x+.3
    var lo=minf(start,end);var hi=maxf(start,end)
    if hi-lo<.1:var mid=(lo+hi)*.5;lo=mid-.05;hi=mid+.05
    var back=minf(wall.position.y,contact.position.y)-.08;var front=maxf(wall.end.y,contact.end.y)+.08
    var ring=Parts.pier_ring(hi-lo,front-back,height,(front+back)*.5).map(func(p):return p+Vector3((lo+hi)*.5,0,0))
    rings.append(ring)
    for p:Vector3 in ring:
     var point=frame*p
     join_bounds=join_bounds.expand(point) if not first_point else AABB(point,Vector3.ZERO);first_point=false
   for level in rings.size()-1:
    var mesh=Parts.pier_loft(rings[level],rings[level+1],INF);var arrays=mesh.surface_get_arrays(0)
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var paint=brick if heights[level+1]<=float(wall_mesh.get_meta("falan_wall_knee"))+.01 else surface
    for k in vertices.size():
     var p:Vector3=frame*vertices[k];var n:Vector3=frame.basis*normals[k];var normal=n.abs()
     var uv=Vector2(p.x,p.z) if normal.y>maxf(normal.x,normal.z) else Vector2(p.z,-p.y) if normal.x>normal.z else Vector2(p.x,-p.y)
     paint.set_normal(n);paint.set_uv(uv/2);paint.set_color(Color.WHITE);paint.add_vertex(p)
   bounds.append(join_bounds);contacts.append([row[0],at])
 var mesh=surface.commit();mesh.surface_set_material(0,Parts.stone_paint)
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,brick.commit().surface_get_arrays(0));mesh.surface_set_material(1,Parts.base_paint)
 masonry_returns={"mesh":mesh,"bounds":bounds,"contacts":contacts};return masonry_returns

static func expand_bridge(rect:Rect2,ends:float,sides:float)->Rect2:
 var margin=Vector2(ends,sides) if rect.size.x>rect.size.y else Vector2(sides,ends)
 return Rect2(rect.position-margin,rect.size+margin*2)

static func water_mask(mask:Texture2D,origin:Vector2,bridges:Array=BRIDGES)->Texture2D:
 var image=mask.get_image().duplicate() # Headless textures can return their shared source image.
 for deck:Rect2 in bridges:
  var bed=expand_bridge(deck,0,3)
  var first=(bed.position-origin)/3
  var last=(bed.end-origin)/3
  var start=Vector2i(ceili(first.x),ceili(first.y))
  var end=Vector2i(floori(last.x),floori(last.y))
  image.fill_rect(Rect2i(start,end-start+Vector2i.ONE),Color.RED)
 return ImageTexture.create_from_image(image)

static func is_legacy(item:Dictionary)->bool:
 if float(item.scale)!=1.0 or item.get("height",0)!=0 or item.get("slot",0)!=0:return false
 var signature:String=Data.LEGACY_FORTS.get(Vector2i(item.x,item.z),"")
 return (item.kind=="round_gate_tower" and item.rotation==0 and signature=="tower"
  or item.kind=="wall_piece" and (item.rotation==0 and signature=="wall0" or item.rotation==90 and signature=="wall90"))

static func obstacles(placements:Array=Data.FORTIFICATIONS)->Array[AABB]:
 var result:Array[AABB]=[]
 for row in placements:
  var serial:int=row[1]
  if serial in [10646,10662]:continue
  var box=Parts.prepare(serial).get_aabb();box.position+=Court.point(row[0])
  result.append(box)
 result.append_array(junctions().bounds)
 return result

static func build(root:Node3D,ground:ShaderMaterial,placements:Array=Data.FORTIFICATIONS,bridge_visibility:Callable=Callable()):
 var features=Node3D.new()
 features.name="ArchivedFalanFortifications"
 root.add_child(features)
 var boxes=Boxes.new()
 var stone=Fort.material(Color("b8b49c"))
 var coping=Fort.material(Color("d8caab"),false)
 var base=Fort.material(Color("8b9076"))
 var groups={}
 for row in placements:
  var serial:int=row[1]
  if not groups.has(serial):groups[serial]=[]
  groups[serial].append(Transform3D(Basis.IDENTITY,Court.point(row[0])))
 for serial in groups:Parts.batch(features,serial,groups[serial])
 Geo.mesh(features,junctions().mesh,Vector3.ZERO,null).name="SourceMasonryReturns"
 for box in obstacles(placements):Art.solid(features,box.get_center(),box.size,1,"stone").set_meta("city_fortification_body",true)
 if ground!=null:bridges(features,boxes,ground,stone,coping,base,bridge_visibility)
 boxes.build(features)

static func bridges(root:Node3D,boxes,ground:ShaderMaterial,stone:Material,coping:Material,base:Material,visible:Callable=Callable()):
 var Freyja=load("res://scripts/forest/forest_freyja_art.gd")
 var lining=Fort.material(Color("a48c68"))
 var arches={}
 for bounds:Rect2 in BRIDGES:
  if visible.is_valid() and not visible.call(bounds.get_center()):continue
  var rect=expand_bridge(bounds,1.5,0)
  var p=Court.point(rect.get_center())
  var deck=Geo.box(root,p-Vector3.UP*.18,Vector3(rect.size.x,.36,rect.size.y),ground)
  deck.name="FalanCanalBridge"
  Art.solid(deck,Vector3.ZERO,Vector3(rect.size.x,.36,rect.size.y),1,"stone")
 for row in Data.QUAY_WALLS:
  if visible.is_valid() and not visible.call(row[0]):continue
  var rotated=row[1]==10632
  var p=Court.point(row[0])
  Court.part(boxes,p,rotated,Vector3(0,-2.55,1.35),Vector3(3.04,5.1,2.72),lining)
  Court.part(boxes,p,rotated,Vector3(0,-.12,1.35),Vector3(3.04,.29,2.77),coping)
 for row in Data.PARAPETS:
  if visible.is_valid() and not visible.call(row[0]):continue
  var at:Vector2=row[0]
  var serial:int=row[1]
  var rotated=serial in [10624,10630]
  var arched=serial in [10624,10625]
  var span=arched or serial in [10629,10630]
  var p=Court.point(at)
  var length_=12.0 if span else 3.04
  var bridge=Rect2()
  for rect:Rect2 in BRIDGES:
   if rect.grow(.01).has_point(at):
    bridge=rect
    break
  if arched:
   var width=2.4
   var footing=p-Vector3.UP*5.25
   if bridge.has_area():
    width=(bridge.size.x if rotated else bridge.size.y)+2.4
    if rotated:footing.x=bridge.get_center().x
    else:footing.z=bridge.get_center().y
   else:
    # The original arch faces the canal on the positive side of both sprite rotations.
    footing+=Vector3.RIGHT*1.55 if rotated else Vector3.BACK*1.55
   if not arches.has(width):arches[width]=Freyja.arch_mesh(width,lining)
   var arch=Geo.mesh(root,arches[width],footing,null)
   arch.set_surface_override_material(0,stone)
   arch.rotation.y=0 if rotated else PI*.5
  elif not (span and bridge.has_area()):
   Court.part(boxes,p,rotated,Vector3(0,-2.55,0),Vector3(length_,5.1,2.4),base)
  Court.part(boxes,p,rotated,Vector3(0,.36,0),Vector3(length_,.78,2.42),stone)
  Court.part(boxes,p,rotated,Vector3(0,.78,0),Vector3(length_,.16,2.55),coping)
  for i in (6 if span else 1):
   Court.part(boxes,p,rotated,Vector3((i-2.5)*2.0 if span else 0.0,1.11,0),Vector3(1.27,.53,1.88),coping)
  if serial in [10620,10621,10626]:
   boxes.add(p+Vector3.UP*.93,Vector3(2.24,1.86,2.24),stone)
   boxes.add(p+Vector3.UP*.46,Vector3(2.42,.22,2.42),coping)
   for level in 4:
    var width=2.26-level*.43
    boxes.add(p+Vector3.UP*(1.86+level*.25),Vector3(width,.25,width),coping)
   if bridge.has_area() and serial in [10620,10621]:
    var along_x=bridge.size.x>bridge.size.y
    var pier=Vector3(3.02,5.1,bridge.size.y+2.44) if along_x else Vector3(bridge.size.x+2.44,5.1,3.02)
    var middle=bridge.get_center()
    boxes.add(Vector3(at.x if along_x else middle.x,3.45,middle.y if along_x else at.y),pier,base)
  if bridge.has_area():
   var rail=Vector3(1.85,1.2,length_) if rotated else Vector3(length_,1.2,1.85)
   if not span:rail=Vector3(2.1,1.2,2.1)
   Art.solid(root,p+Vector3.UP*.60,rail,1,"stone")

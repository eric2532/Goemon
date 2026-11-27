extends RefCounted
## The two source return rooms reuse solid furniture masters and their own original paint.
const Quest=preload("res://scripts/forest/forest_black_prayer_events.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Casework=preload("res://scripts/forest/forest_east_room_casework.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
static var meshes:Dictionary={}
static func owns(id:int,serial:int)->bool:
 return id in [3354,5011] and Quest.data().room_fixtures.graphics.has(str(serial))
static func closed_case(width:float,depth:float,height:float)->Mesh:
 var tool=Furniture.tool();Furniture.Parts.prepare_primitives()
 Furniture.rounded_block(tool,Vector3.UP*height*.5,Vector3(width,height,depth),.035)
 for y in [.08,height-.05]:Furniture.rounded_block(tool,Vector3(0,y,0),Vector3(width+.08,.10,depth+.08),.035)
 var result=tool.commit();result.surface_set_material(0,Casework.material());return result
static func raw(serial:int,g:Dictionary,texture:Texture2D)->Mesh:
 if serial in range(10504,10510):return Forms.furnishing(serial,"coast_book",1.,1.,.30,Vector3.ZERO)
 match serial:
  16511,16512:return Casework.shelf(3,false)
  # Source face landmarks distinguish the broad cupboard front and opposite drawer variants.
  16534:return East.transformed_existing(Casework.shelf(1,false),Transform3D(Basis.IDENTITY.scaled(Vector3(2.17,1,1)),Vector3.ZERO))
  16583:return closed_case(1.1,.70,2.5)
  16584:return closed_case(.70,1.1,2.5)
  16841:return closed_case(1.1,2.4,1.3)
  17195:return Forms.Chamber.lamps(false)
  16526:
   var tool=Furniture.tool();Furniture.Parts.prepare_primitives()
   Furniture.rounded_block(tool,Vector3.ZERO,Vector3(.85,.12,2.8),.035)
   for side in [-1,1]:
    Furniture.Parts.rod(tool,Vector3(.32,-.68,side*1.12),Vector3(-.34,-.08,side*1.12),.045)
   for i in 4:
    var at=Vector3(0,.08,(i-1.5)*.60)
    Furniture.Parts.rod(tool,at,at+Vector3.UP*(.42 if i==0 else .30),.18 if i==0 else .12)
    Furniture.Parts.rod(tool,at+Vector3.UP*.32,at+Vector3.UP*.49,.10 if i==0 else .075)
   return tool.commit()
  16815:
   var tool=Furniture.tool();Furniture.Parts.prepare_primitives()
   for i in 5:
    var foot=Vector3((i%2)*.20,0,(i-2)*.19);var top=foot+Vector3((i%2-.5)*.20,1.7+(i%3)*.18,0)
    Furniture.Parts.rod(tool,foot,top,.07)
    Furniture.Parts.oval(tool,top,Vector3(.20,.48,.20))
   return tool.commit()
  16649,16651,16793:return Forms.furnishing(serial,"coast_pot",1.,1.,1.,Vector3.ZERO)
 return Forms.mesh(serial,Forms.kind(serial,false,g),g,texture)
static func mesh(serial:int,g:Dictionary,texture:Texture2D)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var record:Dictionary=Quest.data().room_fixtures.graphics[str(serial)]
 assert(g.rgba_sha256==record.source_rgba_sha256,"Regenerate source room fixture evidence")
 var model=raw(serial,g,texture)
 var turn=PI*.5 if int(g.footprint[0])>int(g.footprint[1]) else 0.
 if serial in [16511,16512]:turn=-PI*.5 if int(g.footprint[0])>int(g.footprint[1]) else PI
 if serial==16534:turn=-PI*.5
 var rotated=East.transformed_existing(model,Transform3D(Basis(Vector3.UP,turn),Vector3.ZERO))
 var b:Array=record.bounds;var target=Rect2(record.origin[0]+b[0],record.origin[1]+b[1],b[2]-b[0],b[3]-b[1])
 var pose=Fit.measure(Fit.mesh_points(rotated),"",Basis(Vector3.UP,PI*.5),target)
 if record.elevated:
  # A wall shelf/candle keeps its source elevation instead of becoming a floor stand.
  var shift=pose.origin;var middle=(shift.x+shift.z)*.5
  pose.origin=Vector3(middle,-(shift.z-shift.x)*Fit.FLOOR/Fit.VERTICAL,middle)
 var fitted=East.owner_frame(East.transformed_existing(rotated,pose))
 if serial==17195:
  var art=load("res://scripts/forest/forest_original_map_art.gd")
  var stand:Dictionary=art.data().graphics["16808"]
  var support:Mesh=mesh(16808,stand,art.solid_texture(int(stand.page)))
  var dy=support.get_aabb().end.y-fitted.get_aabb().position.y
  # Source17195 sits on16808 one cell east; this depth shift preserves its source projection.
  fitted=East.transformed_existing(fitted,Transform3D(Basis.IDENTITY,Vector3(-dy/(16*.045),dy,dy/(16*.045))))
 var result:Mesh
 if serial in [16511,16512,16534,16583,16584,16841,17194]:result=native_case(serial,g,fitted)
 else:
  var skin=Source.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
  skin.projection_center=fitted.get_aabb().get_center()
  for slot in fitted.get_surface_count():
   var arrays:Array=fitted.get_meta("east_cpu_arrays")[slot]
   var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty()
   for i in (indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
    var index:int=indices[i] if indexed else i
    skin.vertex(arrays[Mesh.ARRAY_VERTEX][index],arrays[Mesh.ARRAY_NORMAL][index])
  result=skin.finish(true)
 result.set_meta("black_prayer_source_fixture",serial)
 result.set_meta("source_rgba_sha256",g.rgba_sha256);result.set_meta("source_bounds",target)
 result.set_meta("inferred_hidden_depth",true);meshes[serial]=result;return result

static func native_case(serial:int,g:Dictionary,model:Mesh)->Mesh:
 # Reuse the East casework route: solid wood backs, bounded original decoration on observed faces.
 var art=load("res://scripts/forest/forest_original_map_art.gd")
 var texture:Texture2D=art.page_texture(int(g.page))
 var paint=Source.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 for slot in model.get_surface_count():
  var arrays:Array=model.get_meta("east_cpu_arrays")[slot]
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty()
  var count_:int=indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]] if indexed else [i,i+1,i+2]
   var normal:Vector3=(arrays[Mesh.ARRAY_NORMAL][ids[0]]+arrays[Mesh.ARRAY_NORMAL][ids[1]]+arrays[Mesh.ARRAY_NORMAL][ids[2]]).normalized()
   if normal.y<.45 and normal.dot(Vector3(-1,0,1))<.15:continue
   for index:int in ids:
    var point:Vector3=arrays[Mesh.ARRAY_VERTEX][index]
    paint.projected_vertex(point+normal*.001,normal,point)
 if serial in [16511,16512,16534]:native_inset(paint,serial,g,model)
 var front=paint.finish(true);front.set_meta("east_cpu_arrays",[front.get_meta("source_surface_arrays")])
 var result=East.combine([model,front]);result.set_meta("inferred_closed_reverse",true)
 return result

static func source_pixel(point:Vector3)->Vector2:
 return Vector2((point.x+point.z)*Fit.HORIZONTAL,(point.z-point.x)*Fit.FLOOR-point.y/.045)
static func native_inset(paint,serial:int,g:Dictionary,model:Mesh):
 # Clip the inset to the original alpha bounds; the source facade must not enlarge the solid silhouette.
 var bounds=model.get_aabb();var a=bounds.position;var b=bounds.end
 var wide=int(g.footprint[0])>int(g.footprint[1]) or serial==16534;var plane=b.z-.01 if wide else a.x+.01
 var corners=[Vector3(a.x,a.y,plane),Vector3(a.x,b.y,plane),Vector3(b.x,b.y,plane),Vector3(b.x,a.y,plane)] if wide else [Vector3(plane,a.y,a.z),Vector3(plane,b.y,a.z),Vector3(plane,b.y,b.z),Vector3(plane,a.y,b.z)]
 var polygon=PackedVector2Array()
 for point:Vector3 in corners:polygon.append(source_pixel(point))
 var r:Array=Quest.data().room_fixtures.graphics[str(serial)].bounds
 var rect=Rect2(g.origin[0]+r[0],g.origin[1]+r[1],r[2]-r[0],r[3]-r[1])
 var clip=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
 var normal=Vector3.BACK if wide else Vector3.LEFT
 for contour:PackedVector2Array in Geometry2D.intersect_polygons(polygon,clip):
  for i in range(1,contour.size()-1):
   var triangle:Array[Vector3]=[]
   for index in [0,i,i+1]:
    var pixel:Vector2=contour[index];var across=pixel.x/Fit.HORIZONTAL-plane
    var point=Vector3(across,((plane-across)*Fit.FLOOR-pixel.y)*.045,plane) if wide else Vector3(plane,((across-plane)*Fit.FLOOR-pixel.y)*.045,across)
    triangle.append(point)
   if (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).dot(normal)<0:triangle.reverse()
   for point:Vector3 in triangle:paint.projected_vertex(point,normal,point)

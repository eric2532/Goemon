extends SceneTree
const Parts=preload("res://scripts/forest/forest_falan_fort_parts.gd")
const Fit=Parts.Fit
const OUT="res://build/Other Files/Asset Toolkit/Falan Exterior Fidelity/"
var failures=0

func _initialize():run.call_deferred()
func volume(mesh:Mesh)->float:
 var faces=mesh.get_faces();var total=0.0
 for i in range(0,faces.size(),3):total+=faces[i].dot(faces[i+2].cross(faces[i+1]))/6.0
 return total

func boundary_edges(mesh:Mesh)->int:
 var edges={};var faces=mesh.get_faces()
 for i in range(0,faces.size(),3):
  for j in 3:
   var a=faces[i+j].snapped(Vector3.ONE*.00001);var b=faces[i+(j+1)%3].snapped(Vector3.ONE*.00001)
   var key=str(a)+":"+str(b) if str(a)<str(b) else str(b)+":"+str(a)
   edges[key]=edges.get(key,0)+1
 var count=0
 for uses in edges.values():
  if uses!=2:count+=1
 return count

func top_at(mesh:Mesh,at:Vector2)->float:
 var faces=mesh.get_faces();var top=-INF
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.segment_intersects_triangle(Vector3(at.x,30,at.y),Vector3(at.x,-1,at.y),faces[i],faces[i+1],faces[i+2])
  if hit!=null:top=maxf(top,hit.y)
 return top

func radius_at(mesh:Mesh,y:float,angle:float)->float:
 var faces=mesh.get_faces();var direction=Vector3(sin(angle),0,cos(angle));var radius=0.0
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.segment_intersects_triangle(direction*10+Vector3.UP*y,Vector3.UP*y,faces[i],faces[i+1],faces[i+2])
  if hit!=null:radius=maxf(radius,hit.dot(direction))
 return radius

func inside_material(mesh:Mesh,point:Vector3,texture:Texture2D)->bool:
 var hits=[]
 for part in mesh.get_surface_count():
  if mesh.surface_get_material(part).get_shader_parameter("base_texture")!=texture:continue
  var surface=ArrayMesh.new();surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(part));var faces=surface.get_faces()
  for i in range(0,faces.size(),3):
   var hit=Geometry3D.segment_intersects_triangle(point,point+Vector3.RIGHT*100,faces[i],faces[i+1],faces[i+2])
   if hit!=null and not hits.any(func(p):return p.distance_to(hit)<.0001):hits.append(hit)
 return hits.size()%2==1

func backed_at(mesh:Mesh,point:Vector3,direction:Vector3,texture:Texture2D=Parts.Masonry,depth:float=.04)->bool:
 var behind=point-direction*depth
 for part in mesh.get_surface_count():
  if mesh.surface_get_material(part).get_shader_parameter("base_texture")!=texture:continue
  var arrays=mesh.surface_get_arrays(part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
  var order=indices if indices!=null and not indices.is_empty() else range(vertices.size())
  for i in range(0,order.size(),3):
   if Geometry3D.segment_intersects_triangle(behind,point,vertices[order[i]],vertices[order[i+1]],vertices[order[i+2]])!=null:return true
 return false

func floor_paint_check(mesh:Mesh,serial:int):
 var found=false;var height=(Parts.WEST_EAST_FRAME*Vector3(0,18.5,0)).y
 for part in mesh.get_surface_count():
  if mesh.surface_get_material(part).get_shader_parameter("base_texture")!=Parts.GatePaving:continue
  found=true;var arrays=mesh.surface_get_arrays(part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  for i in vertices.size():
   var uv=uvs[i];var expected=Vector2(26+24*uv.x-8*uv.y,59+18*uv.x+6*uv.y)+Parts.Data.PARTS[10662][1].position
   if Fit.project(Vector3(vertices[i].x,height,vertices[i].z)).distance_to(expected)>.05:failures+=1;printerr("FORT_GATE_PAVING_PHASE_FAIL ",serial);break
 if not found:failures+=1;printerr("FORT_GATE_PAVING_MISSING ",serial)

func occluded_at(mesh:Mesh,point:Vector3,direction:Vector3)->bool:
 for part in mesh.get_surface_count():
  if mesh.surface_get_material(part).get_shader_parameter("base_texture") not in [Parts.Masonry,Parts.BasePaint,Parts.PavingPaint]:continue
  var arrays=mesh.surface_get_arrays(part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
  var order=indices if indices!=null and not indices.is_empty() else range(vertices.size())
  for i in range(0,order.size(),3):
   if Geometry3D.segment_intersects_triangle(point+direction*.001,point+direction*30,vertices[order[i]],vertices[order[i+1]],vertices[order[i+2]])!=null:return true
 return false

func run():
 create_timer(180).timeout.connect(func():printerr("FALAN_FORT_TIMEOUT");quit(1))
 root.size=Vector2i(1440,900)
 var stage=Node3D.new();root.add_child(stage)
 var environment_=WorldEnvironment.new();environment_.environment=Environment.new();environment_.environment.background_mode=Environment.BG_COLOR;environment_.environment.background_color=Color("596b64");environment_.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment_.environment.ambient_light_color=Color.WHITE;environment_.environment.ambient_light_energy=.8;stage.add_child(environment_)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);stage.add_child(light)
 var camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=900/(sqrt(2.0)*Fit.HORIZONTAL)
 var silhouette=StandardMaterial3D.new();silhouette.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;silhouette.albedo_color=Color.WHITE
 var report={}
 var wall_review="--wall-review" in OS.get_cmdline_user_args()
 var hood_review="--hood-review" in OS.get_cmdline_user_args()
 for serial in ([10640,10643] if wall_review else [10655,10656] if hood_review else Parts.Data.PARTS.keys()):
  camera.size=900/(sqrt(2.0)*Fit.HORIZONTAL)
  var mesh=Parts.prepare(serial);var reference:Rect2=Parts.Data.PARTS[serial][1]
  if Parts.stone_paint.get_shader_parameter("archive_triplanar")!=true or Parts.stone_paint.get_shader_parameter("uv_scale").distance_to(Vector2(1/Parts.Data.MASONRY_SPAN.x,-1/Parts.Data.MASONRY_SPAN.y))>.00001:failures+=1;printerr("FORT_MASONRY_WORLD_SCALE_FAIL ",serial)
  if Parts.stone_paint.get_shader_parameter("use_brush_finish")!=false or Parts.base_paint.get_shader_parameter("use_brush_finish")!=false or Parts.Paint.material(Parts.Masonry).get_shader_parameter("use_brush_finish")!=true:failures+=1;printerr("FORT_MASONRY_BRUSH_ISOLATION_FAIL ",serial)
  if Parts.stone_paint.get_shader_parameter("architecture_facade")!=true:failures+=1;printerr("FORT_STONE_COURSE_MATERIAL_FAIL ",serial)
  if serial in range(10642,10646):
   var has_green_base=false
   for surface in mesh.get_surface_count():
    if mesh.surface_get_material(surface).get_shader_parameter("base_texture")!=Parts.BasePaint:continue
    var base_mesh=ArrayMesh.new();base_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(surface));var base_bounds=base_mesh.get_aabb();has_green_base=true
    if absf(base_bounds.position.y)>.0001 or base_bounds.end.y>mesh.get_aabb().end.y*.5:failures+=1;printerr("FORT_PIER_BASE_REGION_FAIL ",serial)
   if not has_green_base:failures+=1;printerr("FORT_PIER_BASE_PAINT_FAIL ",serial)
  var data=mesh.surface_get_arrays(0)
  if data[Mesh.ARRAY_COLOR]==null or data[Mesh.ARRAY_COLOR].size()!=data[Mesh.ARRAY_VERTEX].size():failures+=1;printerr("FORT_REVERSE_PAINT_FAIL ",serial)
  for part in mesh.get_surface_count():
   if mesh.surface_get_material(part).get_shader_parameter("falan_source_projection")==true:failures+=1;printerr("FORT_WHOLE_PICTURE_FAIL ",serial)
  if Parts.Data.WALL_SLITS.has(serial):
   var frame:Transform3D=mesh.get_meta("falan_source_frame");var details=Parts.wall_details(serial,frame)
   var solid=ArrayMesh.new();solid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,details.surface_get_arrays(0))
   if boundary_edges(solid)!=0 or volume(solid)<=.2 or mesh.get_meta("falan_wall_panes")!=12:failures+=1;printerr("FORT_WALL_OPENING_SOLID_FAIL ",serial)
   var original=Parts.raw(serial);var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(original,0,frame);var skin=tool.commit();skin.surface_set_material(0,Parts.stone_paint)
   var arrays=details.surface_get_arrays(1);var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var seen={};var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)
   for i in vs.size():
    if ns[i].dot(ray)<=0:continue
    var pixel=uvs[i]*Vector2(Parts.WallOpeningPaint.get_size());var matched=false
    for row in Parts.Data.WALL_SLITS[serial]:
     var rect:Rect2=row[0]
     if not rect.grow(.001).has_point(pixel):continue
     var uv=(pixel-rect.position)/rect.size;var q:Array=row[1];var expected=q[0].lerp(q[3],uv.x).lerp(q[1].lerp(q[2],uv.x),uv.y)
     if Fit.project(vs[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_WALL_OPENING_SOURCE_FAIL ",serial)
     matched=true;seen[str(rect)]=true;break
    if not matched:failures+=1;printerr("FORT_WALL_OPENING_ATLAS_FAIL ",serial);break
   if seen.size()!=6:failures+=1;printerr("FORT_WALL_OPENING_COUNT_FAIL ",serial)
   for i in range(0,vs.size(),3):
    var p=(vs[i]+vs[i+1]+vs[i+2])/3
    if not backed_at(mesh,p,ns[i]) or not backed_at(skin,p,ns[i]):failures+=1;printerr("FORT_WALL_OPENING_BACKING_FAIL ",serial);break
   var brackets=Parts.wall_supports(serial,frame);var bracket_solid=ArrayMesh.new();bracket_solid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,brackets.surface_get_arrays(0))
   if boundary_edges(bracket_solid)!=0 or volume(bracket_solid)<.5 or mesh.get_meta("falan_wall_supports")!=6:failures+=1;printerr("FORT_WALL_SUPPORT_SOLID_FAIL ",serial)
   var faces=brackets.surface_get_arrays(1);vs=faces[Mesh.ARRAY_VERTEX];ns=faces[Mesh.ARRAY_NORMAL];uvs=faces[Mesh.ARRAY_TEX_UV];seen={}
   for i in vs.size():
    if ns[i].dot(ray)<=0:continue
    var pixel=uvs[i]*Vector2(Parts.WallSupportPaint.get_size());var matched=false
    for row in Parts.Data.WALL_SUPPORTS[serial]:
     var rect:Rect2=row[0];var native:Rect2=row[1]
     if not rect.grow(.001).has_point(pixel):continue
     var expected=native.position+(pixel-rect.position)/rect.size*native.size
     if Fit.project(vs[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_WALL_SUPPORT_SOURCE_FAIL ",serial)
     seen[str(rect)]=true;matched=true;break
    if not matched:failures+=1;printerr("FORT_WALL_SUPPORT_ATLAS_FAIL ",serial);break
   if seen.size()!=3:failures+=1;printerr("FORT_WALL_SUPPORT_COUNT_FAIL ",serial)
   for root_points:Array in brackets.get_meta("falan_wall_support_roots"):
    var embedded=0
    for p:Vector3 in root_points:
     if inside_material(skin,p,Parts.Masonry):embedded+=1
    if embedded<3:failures+=1;printerr("FORT_WALL_SUPPORT_ROOT_FAIL ",serial," contacts=",embedded);break
   if not occluded_at(mesh,(vs[0]+vs[1]+vs[2])/3-ray,ray):failures+=1;printerr("FORT_WALL_SUPPORT_OCCLUSION_PROBE_FAIL ",serial)
   for i in range(0,vs.size(),3):
    var p=(vs[i]+vs[i+1]+vs[i+2])/3
    if not backed_at(mesh,p,ns[i]):failures+=1;printerr("FORT_WALL_SUPPORT_SEAT_FAIL ",serial," triangle ",i/3);break
    if ns[i].dot(ray)>0 and occluded_at(mesh,p,ray):failures+=1;printerr("FORT_WALL_SUPPORT_OCCLUDED_FAIL ",serial," triangle ",i/3);break
   var spur=Parts.wall_spur(serial);var spur_solid=ArrayMesh.new();spur_solid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,spur.surface_get_arrays(0))
   if boundary_edges(spur_solid)!=0 or volume(spur_solid)<.05 or absf(spur_solid.get_aabb().position.y)>.0001:failures+=1;printerr("FORT_SPUR_SOLID_GROUND_FAIL ",serial)
   var stone_back:Array=spur.get_meta("falan_spur_back")
   for p:Vector3 in stone_back:
    if not inside_material(mesh,p+Vector3.UP*.005,Parts.BasePaint):failures+=1;printerr("FORT_SPUR_EMBED_FAIL ",serial);break
   var spur_face=spur.surface_get_arrays(1);vs=spur_face[Mesh.ARRAY_VERTEX];ns=spur_face[Mesh.ARRAY_NORMAL];uvs=spur_face[Mesh.ARRAY_TEX_UV]
   var region:Rect2=Parts.Data.WALL_SPURS[serial][0];var quad:Array=Parts.Data.WALL_SPURS[serial][1]
   for i in vs.size():
    var uv=(uvs[i]*Vector2(Parts.WallSpurPaint.get_size())-region.position)/region.size;var expected=quad[0].lerp(quad[3],uv.x).lerp(quad[1].lerp(quad[2],uv.x),uv.y)
    if Fit.project(vs[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_SPUR_NATIVE_UV_FAIL ",serial);break
   for i in range(0,vs.size(),3):
    var p=(vs[i]+vs[i+1]+vs[i+2])/3
    if not backed_at(mesh,p,ns[i]) or occluded_at(mesh,p,ray):failures+=1;printerr("FORT_SPUR_FACE_VISIBILITY_FAIL ",serial);break
   var ends:Array=spur.get_meta("falan_spur_ends");var corners=Parts.spur_corners(serial);var normal=Vector3.BACK if serial==10640 else Vector3.RIGHT
   var bottom=[corners[1],corners[2],corners[2]-normal*.10,corners[1]-normal*.10];var top=[corners[0],corners[3],corners[3]-normal*.10,corners[0]-normal*.10]
   if serial==10641:bottom.reverse();top.reverse()
   var core=Parts.pier_loft(bottom,top,INF);core.surface_set_material(0,Parts.stone_paint)
   if ends.size()!=2:failures+=1;printerr("FORT_SPUR_END_COUNT_FAIL ",serial)
   for j in ends.size():
    var entry:Dictionary=ends[j];var end_top:Array=entry.top.duplicate();var end_bottom:Array=entry.bottom.duplicate();end_top.reverse();end_bottom.reverse()
    var end_piece=Parts.pier_loft(end_bottom,end_top,INF);end_piece.surface_set_material(0,Parts.stone_paint)
    if boundary_edges(end_piece)!=0 or volume(end_piece)<.01 or (j==1 and absf(end_piece.get_aabb().position.y)>.0001):failures+=1;printerr("FORT_SPUR_END_SOLID_FAIL ",serial," ",j)
    var height=corners[0].y-.01 if j==0 else .125
    var join=(corners[1]+corners[2]).lerp(corners[0]+corners[3],height/corners[0].y)*.5-normal*.025
    if not inside_material(core,join,Parts.Masonry) or not inside_material(end_piece,join,Parts.Masonry):failures+=1;printerr("FORT_SPUR_END_CONTACT_FAIL ",serial," ",j)
   var end_face=spur.surface_get_arrays(2);vs=end_face[Mesh.ARRAY_VERTEX];ns=end_face[Mesh.ARRAY_NORMAL];uvs=end_face[Mesh.ARRAY_TEX_UV]
   for i in vs.size():
    var row:Array=Parts.Data.SPUR_ENDS[serial][i/18];var face_index=(i/6)%3;var face_row:Array=row if face_index==0 else row[4][face_index-1]
    var rect:Rect2=face_row[0];var uv=(uvs[i]*Vector2(Parts.SpurEndPaint.get_size())-rect.position)/rect.size;var points:Array=face_row[1]
    var expected=points[0].lerp(points[3],uv.x).lerp(points[1].lerp(points[2],uv.x),uv.y)
    if Fit.project(vs[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_SPUR_END_UV_FAIL ",serial);break
   for i in range(0,vs.size(),3):
    var p=(vs[i]+vs[i+1]+vs[i+2])/3
    if not backed_at(mesh,p,ns[i]) or occluded_at(mesh,p,ray):failures+=1;printerr("FORT_SPUR_END_VISIBILITY_FAIL ",serial," ",i/3);break
  if Parts.Data.WINDOWS.has(serial) or serial in range(10655,10661):
   var square=Parts.Data.WINDOWS.has(serial);var family="square" if square else "round"
   var lower=Parts.lower_details(serial,mesh.get_meta("falan_source_frame"));var solid=ArrayMesh.new();solid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,lower.surface_get_arrays(0))
   if lower.get_meta("falan_arrow_panes")!=(12 if square else 14) or boundary_edges(solid)!=0 or volume(solid)<=.1:failures+=1;printerr("FORT_ARROW_SOLID_FAIL ",serial)
   var joins:Array=lower.get_meta("falan_course_joins")
   if joins.size()!=(0 if square else 2):failures+=1;printerr("FORT_COURSE_JOIN_COUNT_FAIL ",serial)
   for join:Dictionary in joins:
    var join_tool=SurfaceTool.new();join_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for p:Vector3 in join.points:join_tool.add_vertex(p)
    var join_mesh=join_tool.commit()
    if boundary_edges(join_mesh)!=0 or volume(join_mesh)<=0:failures+=1;printerr("FORT_COURSE_JOIN_SOLID_FAIL ",serial)
    for end:Vector3 in join.ends:
     var low=INF;var high=-INF
     for p:Vector3 in join.points:
      if Vector2(p.x-end.x,p.z-end.z).length()<.04:low=minf(low,p.y);high=maxf(high,p.y)
     if absf(low-(end.y-2.5/Fit.VERTICAL))>.0001 or absf(high-(end.y+1.5/Fit.VERTICAL))>.0001:failures+=1;printerr("FORT_COURSE_JOIN_PROFILE_FAIL ",serial)
   var faces=lower.surface_get_arrays(1);var vs:PackedVector3Array=faces[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=faces[Mesh.ARRAY_NORMAL];var uvs:PackedVector2Array=faces[Mesh.ARRAY_TEX_UV];var seen={};var join_vertices=0
   for i in vs.size():
    var pixel=uvs[i]*Vector2(Parts.ArrowDetails.get_size());var expected=Vector2.ZERO;var matched=false
    if not square and Parts.Data.ROUND_COURSE_JOIN.grow(.001).has_point(pixel):join_vertices+=1;continue
    if ns[i].x+ns[i].z<=.01 and ns[i].y<.99:continue
    for row in Parts.Data.LOWER_SLITS[family]:
     var rect:Rect2=row[0]
     if not rect.grow(.001).has_point(pixel):continue
     var uv=(pixel-rect.position)/rect.size;var quad:Array=row[1];expected=quad[0].lerp(quad[3],uv.x).lerp(quad[1].lerp(quad[2],uv.x),uv.y);seen[str(rect)]=true;matched=true;break
    if not matched and not square:
     for row in Parts.Data.ROUND_FEET:
      var rect:Rect2=row[0]
      if not rect.grow(.001).has_point(pixel):continue
      var uv=(pixel-rect.position)/rect.size;var quad:Array=row[1];expected=quad[0].lerp(quad[3],uv.x).lerp(quad[1].lerp(quad[2],uv.x),uv.y);matched=true;break
    if not matched and not square:
     var rect:Rect2=Parts.Data.ROUND_COURSE[0];var line:Array=Parts.Data.ROUND_COURSE[1];var uv=(pixel-rect.position)/rect.size;var u=lerpf(line[0].x,line[-1].x,uv.x)
     for j in line.size()-1:
      if u>=line[j].x-.001 and u<=line[j+1].x+.001:expected=line[j].lerp(line[j+1],(u-line[j].x)/(line[j+1].x-line[j].x))+Vector2(0,-1.5+4*uv.y);matched=true;break
    if not matched or Fit.project(vs[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_ARROW_SOURCE_UV_FAIL ",serial);break
   if seen.size()!=(6 if square else 7):failures+=1;printerr("FORT_ARROW_SOURCE_COUNT_FAIL ",serial)
   for i in range(0,vs.size(),3):
    if not backed_at(mesh,(vs[i]+vs[i+1]+vs[i+2])/3,ns[i]):failures+=1;printerr("FORT_ARROW_SKIN_BACKING_FAIL ",serial," triangle ",i/3);break
   if (not square and join_vertices==0) or join_vertices%3!=0:failures+=1;printerr("FORT_COURSE_JOIN_PAINT_FAIL ",serial)
  if Parts.Data.WINDOWS.has(serial):
   var courses=Parts.square_courses();var solid=ArrayMesh.new();solid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,courses.surface_get_arrays(0))
   if boundary_edges(solid)!=0 or volume(solid)<40:failures+=1;printerr("FORT_SQUARE_COURSE_CLOSED_FAIL ",serial)
   var faces=courses.surface_get_arrays(1);var vs:PackedVector3Array=faces[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=faces[Mesh.ARRAY_NORMAL];var uvs:PackedVector2Array=faces[Mesh.ARRAY_TEX_UV];var seen={}
   for i in vs.size():
    if ns[i].x+ns[i].z<.5:continue
    var pixel=uvs[i]*Vector2(Parts.SquareCoursePaint.get_size());var found=false
    for row in Parts.Data.SQUARE_COURSES:
     var region:Rect2=row[0]
     if not region.grow(.001).has_point(pixel):continue
     var uv=(pixel-region.position)/region.size;var q:Array=row[1];var expected=q[0].lerp(q[3],uv.x).lerp(q[1].lerp(q[2],uv.x),uv.y)
     if Fit.project(vs[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_SQUARE_COURSE_SOURCE_FAIL ",serial)
     seen[str(region)]=true;found=true;break
    if not found:failures+=1;printerr("FORT_SQUARE_COURSE_ATLAS_FAIL ",serial);break
   if seen.size()!=4:failures+=1;printerr("FORT_SQUARE_COURSE_COUNT_FAIL ",serial)
   for i in range(0,vs.size(),3):
    if not backed_at(mesh,(vs[i]+vs[i+1]+vs[i+2])/3,ns[i]):failures+=1;printerr("FORT_SQUARE_COURSE_BACKING_FAIL ",serial);break
   var frame:Transform3D=mesh.get_meta("falan_source_frame")
   if absf(mesh.get_meta("falan_foundation_top")-3.45*frame.basis.y.y)>.0001:failures+=1;printerr("FORT_SQUARE_FOUNDATION_LEVEL_FAIL ",serial)
  if serial in [10640,10641]:
   if volume(mesh)<float(mesh.get_meta("falan_wall_slab_volume"))*.95:failures+=1;printerr("FORT_SOLID_WINDING_FAIL ",serial)
  var crowns:Array=mesh.get_meta("falan_crown_points",[])
  if serial in range(10647,10654) or serial==10661:
   if crowns.size()!=12:failures+=1;printerr("FORT_SQUARE_CROWN_FAIL ",serial)
  elif serial in range(10655,10661):
   if crowns.size()!=10:failures+=1;printerr("FORT_ROUND_CROWN_FAIL ",serial)
  elif serial in range(10642,10646):
   if crowns.size()!=4 or volume(mesh)<=1:failures+=1;printerr("FORT_PIER_SOLID_FAIL ",serial)
  elif serial in [10640,10641]:
   if crowns.size()!=7:failures+=1;printerr("FORT_WALL_CROWN_FAIL ",serial)
   else:
    for i in crowns.size():
     var expected:Vector2=Parts.WALL_CROWNS[i][0]
     if serial==10641:expected.x=143-expected.x
     if Fit.project(crowns[i]).distance_to(expected+reference.position)>.05:failures+=1;printerr("FORT_WALL_CROWN_POSITION_FAIL ",serial," ",i)
    for foot:Vector3 in mesh.get_meta("falan_crown_feet"):
     if not inside_material(mesh,foot-Vector3.UP*.005,Parts.Masonry):failures+=1;printerr("FORT_WALL_CROWN_SEAT_FAIL ",serial," ",Fit.project(foot))
  if serial in [10646,10662]:
   floor_paint_check(mesh,serial)
   var expected=25 if serial==10646 else 24
   if mesh.get_meta("falan_iron_spikes",0)!=expected or crowns.size()!=(8 if serial==10646 else 13):failures+=1;printerr("FORT_GALLERY_DETAILS_FAIL ",serial)
   var tips=mesh.get_meta("falan_iron_tips");var native_tips=[Vector2(63,199),Vector2(79,187),Vector2(88,186),Vector2(128,156),Vector2(143,139)] if serial==10646 else [Vector2(2,117),Vector2(10,123),Vector2(58,159)]
   for pixel in native_tips:
    if not tips.any(func(p):return Fit.project(p).distance_to(pixel+Parts.IRON_PIXEL_EDGES[serial]+reference.position)<.05):failures+=1;printerr("FORT_NATIVE_IRON_POINT_FAIL ",serial," ",pixel)
  if serial==10662:
   for i in range(1,8):
    if Fit.project(crowns[i]).distance_to(Vector2(-1+i*15,6+i*11)+reference.position)>.05:failures+=1;printerr("FORT_WEST_EAST_CAP_POSITION_FAIL ",i)
   for i in range(1,5):
    if Fit.project(crowns[8+i]).distance_to(Vector2(6+i*15,64+i*11)+reference.position)>.05:failures+=1;printerr("FORT_WEST_EAST_CAP_POSITION_FAIL ",i+8)
   for foot:Vector3 in mesh.get_meta("falan_crown_feet"):
    if not inside_material(mesh,foot-Vector3.UP*.005,Parts.Masonry):failures+=1;printerr("FORT_WEST_EAST_CAP_SEAT_FAIL ",Fit.project(foot))
  if serial==10646:
   for part in mesh.get_surface_count():
    if mesh.surface_get_material(part).get_shader_parameter("base_texture")!=Parts.Masonry:continue
    for p:Vector3 in mesh.surface_get_arrays(part)[Mesh.ARRAY_VERTEX]:
     if p.z>=-8.45 or p.y<=19.0:continue
     var pixel=Fit.project(p)-reference.position
     if pixel.y-.75*pixel.x< -61.3 or pixel.x>175.05:failures+=1;printerr("FORT_COPING_RETURN_CONTOUR_FAIL");break
   var corbel_points=[]
   for part in mesh.get_surface_count():
    if mesh.surface_get_material(part).get_shader_parameter("base_texture")==Parts.BasePaint:corbel_points.append_array(mesh.surface_get_arrays(part)[Mesh.ARRAY_VERTEX])
   for pixel:Vector2 in [Vector2(155,85),Vector2(174,73),Vector2(177,76),Vector2(177,136),Vector2(174,142),Vector2(156,130)]:
    if not corbel_points.any(func(p):return absf(p.x+.815)<.001 and Fit.project(p).distance_to(pixel+reference.position)<.05):failures+=1;printerr("FORT_CORBEL_NATIVE_POINT_FAIL ",pixel)
   var jamb_left=INF;var jamb_bottom=-INF
   for part in mesh.get_surface_count():
    if mesh.surface_get_material(part).get_shader_parameter("base_texture")!=Parts.BasePaint:continue
    for p:Vector3 in mesh.surface_get_arrays(part)[Mesh.ARRAY_VERTEX]:
     if p.z<1.79 or p.x< -1.52 or p.x> -.87:continue
     var pixel=Fit.project(p);jamb_left=minf(jamb_left,pixel.x-reference.position.x);jamb_bottom=maxf(jamb_bottom,pixel.y)
   if absf(jamb_left-45)>.05 or absf(jamb_bottom-reference.end.y)>.05:failures+=1;printerr("FORT_SOUTH_JAMB_CONTOUR_FAIL")
   var native_crowns=Parts.SOUTH_CROWN_TOPS[-1]+Parts.SOUTH_CROWN_TOPS[1]
   for i in crowns.size():
    if Fit.project(crowns[i]).distance_to(native_crowns[i]+reference.position)>.05:failures+=1;printerr("FORT_SOUTH_CROWN_POSITION_FAIL ",i)
   var details={Parts.BannerPaint:"banner",Parts.BlueBannerPaint:"blue_banner",Parts.GateWindowPaint:"gate_window",Parts.GateBadgePaint:"gate_badge"};var count=0
   for part in mesh.get_surface_count():
    var name_=details.get(mesh.surface_get_material(part).get_shader_parameter("base_texture"),"")
    if name_.is_empty():continue
    count+=1;var arrays=mesh.surface_get_arrays(part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var native:Array=Parts.GATE_QUADS[name_]
    var detail_center=Vector3.ZERO
    for p in vertices:detail_center+=p/vertices.size()
    for i in vertices.size():
     var uv=uvs[i];var expected=native[0].lerp(native[3],uv.x).lerp(native[1].lerp(native[2],uv.x),uv.y)+reference.position
     if Fit.project(vertices[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_NATIVE_GATE_DETAIL_FAIL ",name_);break
     if name_=="gate_window":
      var section=Parts.stone_section(serial,Transform3D.IDENTITY,vertices[i].y,Vector2(vertices[i].z-.001,vertices[i].z+.001))
      if not section.has_area() or absf(section.end.x-vertices[i].x)>.05:failures+=1;printerr("FORT_GATE_WINDOW_SUPPORT_FAIL");break
     if name_=="gate_badge" and not backed_at(mesh,vertices[i].lerp(detail_center,.001),Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)):failures+=1;printerr("FORT_GATE_BADGE_BACKING_FAIL");break
    var faces=mesh.surface_get_arrays(part);var indices=faces[Mesh.ARRAY_INDEX];var normals:PackedVector3Array=faces[Mesh.ARRAY_NORMAL]
    for i in range(0,indices.size(),3):
     var a=indices[i];var b=indices[i+1];var c=indices[i+2]
     if (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a]).dot(normals[a])<=0:failures+=1;printerr("FORT_NATIVE_GATE_DETAIL_WINDING_FAIL ",name_);break
    if name_ in ["banner","blue_banner"]:
     var cloth=ArrayMesh.new();cloth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
     var expected_volume=.024*(native[3].x-native[0].x)/Fit.HORIZONTAL*(native[1].y-native[0].y)/Fit.VERTICAL
     if boundary_edges(cloth)!=0 or absf(volume(cloth)-expected_volume)>.0001:failures+=1;printerr("FORT_CLOTH_CLOSED_FAIL ",name_)
   if count!=4:failures+=1;printerr("FORT_NATIVE_GATE_DETAILS_MISSING")
  if Parts.Data.WINDOWS.has(serial):
   var seen={};var found=false
   for part in mesh.get_surface_count():
    if mesh.surface_get_material(part).get_shader_parameter("base_texture")!=Parts.WindowDetails:continue
    found=true;var arrays=mesh.surface_get_arrays(part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    for i in vertices.size():
     if normals[i].x+normals[i].z<.5:continue
     var pixel=uvs[i]*Vector2(Parts.WindowDetails.get_size());var matched=false
     for row in Parts.Data.WINDOWS[serial]:
      var region:Rect2=row[2]
      if not region.grow(.001).has_point(pixel):continue
      var uv=(pixel-region.position)/region.size;var quad:Array=row[3];var expected=quad[0].lerp(quad[3],uv.x).lerp(quad[1].lerp(quad[2],uv.x),uv.y)
      if Fit.project(vertices[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_WINDOW_SOURCE_POINT_FAIL ",serial)
      seen[str(region)]=true;matched=true;break
     if not matched:failures+=1;printerr("FORT_WINDOW_ATLAS_REGION_FAIL ",serial)
    for i in range(0,vertices.size(),3):
     if (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).dot(normals[i])<=0:failures+=1;printerr("FORT_WINDOW_WINDING_FAIL ",serial)
     if not backed_at(mesh,(vertices[i]+vertices[i+1]+vertices[i+2])/3,normals[i]):failures+=1;printerr("FORT_WINDOW_BACKING_FAIL ",serial)
   if not found or seen.size()!=Parts.Data.WINDOWS[serial].size():failures+=1;printerr("FORT_WINDOW_VARIANT_FAIL ",serial)
  var points=Fit.mesh_points(mesh);var measured=Fit.projected_bounds(points)
  if serial in range(10647,10654) or serial in range(10655,10662):
   var crown=Fit.projected_bounds(mesh.get_meta("falan_crown_vertices"));var square=serial in range(10647,10654) or serial==10661
   if absf(crown.position.x-(-63 if square else -68))>.05 or absf(crown.position.y-(-260 if square else -283))>.05 or absf(crown.size.x-(128 if square else 137))>.05:failures+=1;printerr("FORT_CROWN_FRAME_FAIL ",serial)
  elif measured.position.distance_to(reference.position)>.05 or measured.size.distance_to(reference.size)>.05:failures+=1;printerr("FORT_DIMENSION_FAIL ",serial)
  var model=Geo.mesh(stage,mesh,Vector3.ZERO,null)
  var center=reference.get_center();var at=Vector3((center.x/Fit.HORIZONTAL+center.y/Fit.FLOOR)*.5,0,(center.y/Fit.FLOOR-center.x/Fit.HORIZONTAL)*.5)
  camera.position=at+Vector3(100,100*sqrt(2.0)*tan(asin(.75)),100);camera.look_at(at)
  for i in 5:await process_frame
  if DisplayServer.get_name()!="headless":RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+"matched-fort-%d.png"%serial)
  if DisplayServer.get_name()!="headless":
   model.material_override=silhouette;environment_.environment.background_color=Color.BLACK
   for i in 2:await process_frame
   RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+"silhouette-fort-%d.png"%serial)
   model.material_override=null;environment_.environment.background_color=Color("596b64")
  var actual=camera.unproject_position(points[0]);var expected=Vector2(root.get_visible_rect().size)*.5+Fit.project(points[0])-center
  if actual.distance_to(expected)>.1:failures+=1;printerr("FORT_CAMERA_FAIL ",serial)
  var bounds=mesh.get_aabb();var target=bounds.get_center()
  camera.position=target+Vector3(-100,100*sqrt(2.0)*tan(asin(.75)),-100);camera.look_at(target)
  for i in 5:await process_frame
  if DisplayServer.get_name()!="headless":RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+"reverse-fort-%d.png"%serial)
  if DisplayServer.get_name()!="headless":
   camera.size=maxf(bounds.size.y,maxf(bounds.size.x,bounds.size.z))*1.35
   var eyes=[Vector3(70,22,70),Vector3(-70,22,70),Vector3(-70,22,-70),Vector3(70,22,-70)]
   for side in eyes.size():
    camera.position=target+eyes[side];camera.look_at(target)
    for i in 4:await process_frame
    RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+"low-fort-%d-%d.png"%[serial,side])
  report[str(serial)]={"source_bounds":str(reference),"measured_bounds":str(measured),"bounds":str(bounds),"triangles":mesh.get_faces().size()/3,"surfaces":mesh.get_surface_count(),"crown_count":crowns.size(),"crown_source_pixels":crowns.map(func(p):return str(Fit.project(p))),"crown_bounds":str(Fit.projected_bounds(mesh.get_meta("falan_crown_vertices")))}
  model.queue_free();await process_frame
 var file=FileAccess.open(OUT+("wall-review.json" if wall_review else "hood-review.json" if hood_review else "fort-meshes.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 if not wall_review and not hood_review:
  var city=load("res://scripts/forest/forest_falan_fortifications.gd")
  var group=Node3D.new();stage.add_child(group);var poses={};var stations=[]
  for row in city.Data.FORTIFICATIONS:
   if not poses.has(row[1]):poses[row[1]]=[]
   var point=Parts.Court.point(row[0]);poses[row[1]].append(Transform3D(Basis.IDENTITY,point))
   stations.append({"serial":row[1],"anchor":[Fit.project(point).x,Fit.project(point).y]})
  for serial in poses:Parts.batch(group,serial,poses[serial])
  var masonry=city.junctions();Geo.mesh(group,masonry.mesh,Vector3.ZERO,null)
  if masonry.bounds.size()!=masonry.contacts.size() or volume(masonry.mesh)<=1:failures+=1;printerr("FORT_MASONRY_RETURNS_FAIL")
  var views={};var envelope=Rect2()
  for i in stations.size():
   var row:Dictionary=stations[i];var rect:Rect2=Parts.Data.PARTS[row.serial][1];rect.position+=Vector2(row.anchor[0],row.anchor[1])
   envelope=rect if i==0 else envelope.merge(rect)
  camera.size=900/(sqrt(2.0)*Fit.HORIZONTAL)
  for serial in [10640,10648,10651,10655,10658,10646,10662]:
   var row=city.Data.FORTIFICATIONS.filter(func(r):return r[1]==serial)[0]
   var center=Fit.project(Parts.Court.point(row[0]))+Parts.Data.PARTS[serial][1].get_center()
   var at=Vector3((center.x/Fit.HORIZONTAL+center.y/Fit.FLOOR)*.5,0,(center.y/Fit.FLOOR-center.x/Fit.HORIZONTAL)*.5)
   camera.position=at+Vector3(100,100*sqrt(2.0)*tan(asin(.75)),100);camera.look_at(at)
   for i in 3:await process_frame
   if DisplayServer.get_name()!="headless":RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+"assembly-%d.png"%serial)
   for child in group.get_children():child.material_override=silhouette
   environment_.environment.background_color=Color.BLACK
   for i in 2:await process_frame
   if DisplayServer.get_name()!="headless":RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+"assembly-mask-%d.png"%serial)
   for child in group.get_children():child.material_override=null
   environment_.environment.background_color=Color("596b64")
   views[str(serial)]=[center.x,center.y]
  var overview={"center":[envelope.get_center().x,envelope.get_center().y],"scale":minf(3840.0/(envelope.size.x+32),2160.0/(envelope.size.y+32)),"size":[3840,2160]}
  if stations.size()!=364:failures+=1;printerr("FORT_CITY_STATIONS_FAIL")
  if DisplayServer.get_name()!="headless":
   var viewport=SubViewport.new();viewport.size=Vector2i(3840,2160);viewport.world_3d=root.world_3d;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
   var overview_camera=Camera3D.new();viewport.add_child(overview_camera);overview_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;overview_camera.keep_aspect=Camera3D.KEEP_HEIGHT;overview_camera.size=2160/(sqrt(2.0)*Fit.HORIZONTAL*overview.scale);overview_camera.current=true
   var center=Vector2(overview.center[0],overview.center[1]);var at=Vector3((center.x/Fit.HORIZONTAL+center.y/Fit.FLOOR)*.5,0,(center.y/Fit.FLOOR-center.x/Fit.HORIZONTAL)*.5)
   overview_camera.far=8000;overview_camera.position=at+Vector3(1500,1500*sqrt(2.0)*tan(asin(.75)),1500);overview_camera.look_at(at)
   for i in 4:await process_frame
   if overview_camera.unproject_position(Vector3.ZERO).distance_to(Vector2(1920,1080)-center*overview.scale)>.1:failures+=1;printerr("FORT_OVERVIEW_CAMERA_FAIL")
   RenderingServer.force_draw();viewport.get_texture().get_image().save_png(OUT+"assembly-whole-city.png")
   for child in group.get_children():child.material_override=silhouette
   environment_.environment.background_color=Color.BLACK
   for i in 3:await process_frame
   RenderingServer.force_draw();viewport.get_texture().get_image().save_png(OUT+"assembly-mask-whole-city.png")
   viewport.queue_free()
  var assembly=FileAccess.open(OUT+"fort-assemblies.json",FileAccess.WRITE);assembly.store_string(JSON.stringify({"stations":stations,"views":views,"overview":overview,"masonry_returns":{"count":masonry.bounds.size(),"triangles":masonry.mesh.get_faces().size()/3,"surfaces":masonry.mesh.get_surface_count()}},"  "));assembly.close()
  group.queue_free();await process_frame
 for serial in [10647,10661]:
  var leaf=Parts.prepare(serial);var front_texture=Parts.LeafFrontPaint if serial==10647 else Parts.LeafPaint;var front=-1
  for part in leaf.get_surface_count():
   if leaf.surface_get_material(part).get_shader_parameter("base_texture")==front_texture:front=part
  if front<0:failures+=1;printerr("FORT_CARVED_LEAF_FAIL ",serial);continue
  var arrays=leaf.surface_get_arrays(front);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var native:Array=Parts.LEAF_QUADS[serial]
  for i in vertices.size():
   var uv=uvs[i];var expected=native[0].lerp(native[3],uv.x).lerp(native[1].lerp(native[2],uv.x),uv.y)+Parts.Data.PARTS[serial][1].position
   if Fit.project(vertices[i]).distance_to(expected)>.05:failures+=1;printerr("FORT_NATIVE_LEAF_FAIL ",serial);break
  var order=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else range(vertices.size())
  for i in range(0,order.size(),3):
   var a=order[i];var b=order[i+1];var c=order[i+2];var uv=(uvs[a]+uvs[b]+uvs[c])/3
   var expected=native[0].lerp(native[3],uv.x).lerp(native[1].lerp(native[2],uv.x),uv.y)+Parts.Data.PARTS[serial][1].position
   if Fit.project((vertices[a]+vertices[b]+vertices[c])/3).distance_to(expected)>.05:failures+=1;printerr("FORT_LEAF_INTERIOR_UV_FAIL ",serial);break
  var body=ArrayMesh.new();body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,leaf.surface_get_arrays(front-1))
  if absf(volume(body)-float(leaf.get_meta("falan_leaf_body_volume")))>.001:failures+=1;printerr("FORT_LEAF_SOLID_FAIL ",serial)
 for pair in [[10655,10660],[10656,10659],[10658,10657]]:
  if Parts.prepare(pair[0]).get_faces().size()<=Parts.prepare(pair[1]).get_faces().size():failures+=1;printerr("FORT_ROUND_VARIANT_FAIL ",pair)
 for serial in Parts.BRACE_SIDES:
  var brace=Parts.tower_braces(serial);var caps:Array=brace.get_meta("falan_brace_caps");var expected=[]
  var row=[Vector2(27,-114),Vector2(56,-132)] if serial<10655 else [Vector2(33,-114),Vector2(57,-132)]
  for side in Parts.BRACE_SIDES[serial]:
   for pixel:Vector2 in row:expected.append(pixel if side>0 else Vector2(2-pixel.x,pixel.y))
  if caps.size()!=expected.size():failures+=1;printerr("FORT_BRACE_CAP_COUNT_FAIL ",serial)
  for i in caps.size():
   if Fit.project(caps[i]).distance_to(expected[i])>.05:failures+=1;printerr("FORT_BRACE_CAP_POINT_FAIL ",serial)
  if boundary_edges(brace)!=0 or volume(brace)<1:failures+=1;printerr("FORT_BRACE_CLOSED_FAIL ",serial)
  var actual=Parts.prepare(serial);var points=Fit.mesh_points(actual)
  for point:Vector3 in brace.get_meta("falan_brace_controls"):
   if point.y<-.0001 or not points.any(func(p):return p.distance_to(point)<.0001):failures+=1;printerr("FORT_BRACE_PROFILE_FAIL ",serial);break
 for serial in Parts.Data.HOODS:
  var hood=Parts.round_hood(serial);var solid=ArrayMesh.new();solid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,hood.surface_get_arrays(0))
  if boundary_edges(solid)!=0 or volume(solid)<1:failures+=1;printerr("FORT_ROUND_HOOD_CLOSED_FAIL ",serial)
  var data=hood.surface_get_arrays(1);var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX];var uvs:PackedVector2Array=data[Mesh.ARRAY_TEX_UV];var crop:Rect2=Parts.Data.HOODS[serial][2]
  for i in vertices.size():
   if Fit.project(vertices[i]).distance_to(crop.position+uvs[i]*crop.size)>.05:failures+=1;printerr("FORT_ROUND_HOOD_UV_FAIL ",serial);break
  var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)
  for i in range(0,vertices.size(),3):
   if not backed_at(hood,(vertices[i]+vertices[i+1]+vertices[i+2])/3,ray):failures+=1;printerr("FORT_ROUND_HOOD_BACKING_FAIL ",serial);break
  for feature in 2:
   for pixel:Vector2 in Parts.Data.HOODS[serial][feature]:
    var expected=Parts.hood_point(serial,pixel,4.6 if feature==0 else 4.25)+ray*.35
    if not Array(solid.get_faces()).any(func(p):return p.distance_to(expected)<.0001):failures+=1;printerr("FORT_ROUND_HOOD_PROFILE_FAIL ",serial);break
 if Parts.window_shutter==null:Parts.prepare(10651)
 for frame in [Parts.window_arch,Parts.window_shutter]:
  if boundary_edges(frame)!=0 or volume(frame)<.13:failures+=1;printerr("FORT_SQUARE_WINDOW_FRAME_CLOSED_FAIL")
 if absf(volume(Parts.merlon())-1.044544)>.001 or volume(Parts.round_tooth)<.5 or volume(Parts.round_rim)<10 or volume(Parts.round_course)<.15:failures+=1;printerr("FORT_CROWN_SOLID_FAIL")
 if boundary_edges(Parts.merlon(true))!=0 or volume(Parts.merlon(true))<.5:failures+=1;printerr("FORT_WALL_HEAD_SOLID_FAIL")
 for cut in [20.0,0.0]:
  var solid=Parts.pier_loft(Parts.pier_ring(2,2,0,0),Parts.pier_ring(2,2,2,0),cut)
  if absf(volume(solid)-(8.0 if cut>0 else 4.0))>.001:failures+=1;printerr("FORT_CLIPPED_SOLID_FAIL ",cut)
 var inclined=Parts.pier_loft(Parts.pier_ring(2,2,0,0),Parts.pier_ring(2,2,2,0),0,.3)
 if absf(volume(inclined)-5.08)>.001:failures+=1;printerr("FORT_INCLINED_SOLID_FAIL")
 var pentagon=[Vector3(-1,0,-1),Vector3(-1,0,1),Vector3(1,0,1),Vector3(1,0,0),Vector3(0,0,-1)]
 for cut in [INF,1.0]:
  var five=Parts.pier_loft(pentagon,pentagon.map(func(p):return p+Vector3.UP*2),cut)
  if boundary_edges(five)!=0 or absf(volume(five)-7)>.001:failures+=1;printerr("FORT_PENTAGON_LOFT_FAIL ",cut)
 var clipped_rail=Parts.pier_loft(Parts.pier_ring(.08,.08,0,0),Parts.pier_ring(.08,.08,.08,0),.0775)
 if boundary_edges(clipped_rail)!=0 or absf(volume(clipped_rail)-.00051175)>.00000001:failures+=1;printerr("FORT_CLIPPED_RAIL_CLOSED_FAIL")
 var gallery_parts=Node3D.new()
 for cut in [20.0,0.0]:
  var part=Parts.gallery_box(gallery_parts,Vector3.ZERO,Vector3(2,2,2),Parts.stone_paint,cut)
  if absf(volume(part.mesh)-(8.0 if cut>0 else 4.0))>.001:failures+=1;printerr("FORT_GALLERY_OUTWARD_SOLID_FAIL ",cut)
  var coping=Parts.gallery_coping(gallery_parts,Vector3.ZERO,Vector3(2,2,2),Parts.stone_paint,cut)
  if boundary_edges(coping.mesh)!=0 or absf(volume(coping.mesh)-(7.992872 if cut>0 else 3.996436))>.001:failures+=1;printerr("FORT_COPING_PROFILE_SOLID_FAIL ",cut)
 gallery_parts.free()
 var round_roof=Parts.raw(10657)
 if absf(top_at(round_roof,Vector2.ZERO)-17.15)>.01 or top_at(round_roof,Vector2(sin(PI/10),cos(PI/10))*2.5)-top_at(round_roof,Vector2.ZERO)<.8:failures+=1;printerr("FORT_RECESSED_ROOF_FAIL")
 for i in 16:
  if radius_at(round_roof,1.15,(i+.5)*TAU/16)<2.89:failures+=1;printerr("FORT_BASE_SHELL_FAIL ",i)
 var square_roof=Parts.raw(10650)
 if absf(top_at(square_roof,Vector2.ZERO)-17.18)>.01 or top_at(square_roof,Vector2(4.18,0))-top_at(square_roof,Vector2.ZERO)<1:failures+=1;printerr("FORT_SQUARE_RECESSED_ROOF_FAIL")
 for i in 4:
  if radius_at(square_roof,16.95,i*PI*.5)<4.5:failures+=1;printerr("FORT_COPING_JOIN_FAIL ",i)
 for serial in [10646,10662]:
  var gallery=Parts.raw(serial)
  if absf(top_at(gallery,Vector2(-3,-3))-18.5)>.01:failures+=1;printerr("FORT_GALLERY_DECK_FAIL ",serial)
  if serial==10646:
   if not backed_at(gallery,Vector3(-3.28125,13.08,-8.8775),Vector3.DOWN,Parts.BasePaint):failures+=1;printerr("FORT_FAR_RETURN_BOTTOM_FAIL")
   for i in [-1,0,1]:
    var joint=Vector3(-2.03,19.1,-3+i*2.25+.016)
    if not inside_material(gallery,joint,Parts.Masonry) or not inside_material(gallery,joint,Parts.BasePaint):failures+=1;printerr("FORT_PROJECTING_PILLAR_JOIN_FAIL ",i)
   for z in [2.2,-8.2]:
    if absf(top_at(gallery,Vector2(-3.28125,z))-19.65)>.01:failures+=1;printerr("FORT_RAISED_LANDING_FAIL ",z)
   var cloth={}
   for part in gallery.get_surface_count():
    var texture=gallery.surface_get_material(part).get_shader_parameter("base_texture")
    if texture not in [Parts.BannerPaint,Parts.BlueBannerPaint]:continue
    var points:PackedVector3Array=gallery.surface_get_arrays(part)[Mesh.ARRAY_VERTEX];var center=Vector3.ZERO
    for p in points:center+=p
    cloth[texture]=center/points.size()
   if cloth.size()!=2 or not (cloth[Parts.BlueBannerPaint]-cloth[Parts.BannerPaint]).is_equal_approx(Vector3(0,0,-1.5)):failures+=1;printerr("FORT_ADJACENT_CLOTH_FAIL")
 var frontier=load("res://scripts/forest/forest_falan_frontier.gd")
 for area in Parts.GATE_ROTATIONS:
  var at=frontier.from_city(area,Vector2.ZERO)
  var frame=Transform3D(Basis(Vector3.UP,frontier.FRAMES[area].get_rotation()),Vector3(at.x,0,at.y))
  var defenses=frontier.CityForts.obstacles().map(func(box):return frame*box)
  for cell in Parts.GATE_ROTATIONS[area]:
   var b={"cell":cell,"rotation":Parts.GATE_ROTATIONS[area][cell],"falan_gate_area":area}
   var spec=Parts.gate_spec(b)
   var pose=Transform3D(Basis(Vector3.UP,b.rotation*PI*.5),Vector3(3,6,cell.y*6))*spec[1]
   var span:AABB=pose*Parts.prepare(spec[0]).get_aabb()
   var owner=Transform3D(Basis(Vector3.UP,b.rotation*PI*.5),Vector3(3,6,cell.y*6))
   var joints=Parts.gate_supports(b).map(func(box):return owner*box)
   if not joints.all(func(box):return box.intersects(span)) or defenses.filter(func(box):return box.intersects(span) or joints.any(func(joint):return joint.intersects(box))).size()<2:failures+=1;printerr("FORT_GATE_JOIN_FAIL ",area," ",cell," span=",span," joints=",joints)
 print("FALAN_FORT_PREVIEW count=",report.size()," failures=",failures);quit(1 if failures else 0)

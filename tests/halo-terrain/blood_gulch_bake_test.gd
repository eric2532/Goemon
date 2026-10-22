extends SceneTree
var failures=0
var checks=0
func check(value:bool,label:String):
 checks+=1
 if not value:failures+=1;printerr("FAIL ",label)
func _initialize():
 var mesh=load("res://assets/maps/blood_gulch/terrain.res") as ArrayMesh
 var collision=load("res://assets/maps/blood_gulch/collision.res") as ConcavePolygonShape3D
 var field=load("res://assets/maps/blood_gulch/surface.res")
 check(mesh!=null and collision!=null and field!=null,"resources load")
 if mesh==null or collision==null or field==null:quit(1);return
 var heights=field.get_meta("heights") as PackedFloat32Array
 var covered=field.get_meta("covered") as PackedByteArray
 check(field.get_meta("width")==161 and is_equal_approx(field.get_meta("spacing"),3.),"grid contract")
 check(heights.size()==25921 and covered.size()==25921,"grid arrays")
 var points=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
 var physical=collision.get_faces()
 var expected_cells=0
 for iz in 160:
  for ix in 160:
   var at=iz*161+ix
   if covered[at]!=0 and covered[at+1]!=0 and covered[at+161]!=0 and covered[at+162]!=0:expected_cells+=1
 check(mesh.get_surface_count()==2,"exact native boundary cap surface exists")
 check(points.size()==expected_cells*6,"only fully covered cells produce rendered and physical ground")
 var cap_points=mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX] as PackedVector3Array if mesh.get_surface_count()>1 else PackedVector3Array()
 check(cap_points.size()>0,"native boundary gaps have physical support triangles")
 check(physical.size()==points.size()+cap_points.size(),"collision includes visible ground and exact boundary caps")
 var mismatch=0;var winding_error=0;var outside_coverage=0;var max_physical_delta=0.;var max_field_delta=0.
 for i in points.size():
  max_physical_delta=maxf(max_physical_delta,points[i].distance_to(physical[i]))
  # Godot ConcavePolygonShape3D rounds stored face components by <=0.05mm.
  if points[i].distance_to(physical[i])>.0001:mismatch+=1
  var ix=roundi((points[i].x+240)/3);var iz=roundi((points[i].z+240)/3)
  max_field_delta=maxf(max_field_delta,absf(points[i].y-heights[iz*161+ix]))
  if absf(points[i].y-heights[iz*161+ix])>.0001:mismatch+=1
  if covered[iz*161+ix]==0:outside_coverage+=1
 for i in range(0,points.size(),3):
  if (points[i+1]-points[i]).cross(points[i+2]-points[i]).y>=0:winding_error+=1
 print("GROUND_DELTA physical=",max_physical_delta," field=",max_field_delta," mismatches=",mismatch)
 check(mismatch==0,"every visible and physical ground vertex equals navigation height")
 check(winding_error==0,"clockwise ground faces upward")
 check(outside_coverage==0,"no triangle uses uncovered exterior vertices")
 var cliffs=load("res://assets/maps/blood_gulch/cliffs.res") as ArrayMesh
 check(cliffs!=null and cliffs.get_surface_count()>0,"native cliffs retained")
 var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/blood_gulch/provenance.json"))
 check(provenance.battle_adaptations.removed_scifi_base_triangles==1688,"original scifi buildings removed")
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/blood_gulch/source.json"))
 var original_ground_faces=0;var original_ground_groups=0
 for group in source.groups:
  if group.role=="ground":original_ground_groups+=1;original_ground_faces+=group.faces.size()
 check(provenance.source.native_ground_materials==original_ground_groups and provenance.source.rasterized_native_ground_triangles==original_ground_faces,"every native ground material group rasterized")
 var adaptation=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/blood_gulch/adaptation.json"))
 var cap_uv=mesh.surface_get_arrays(1)[Mesh.ARRAY_TEX_UV] as PackedVector2Array if mesh.get_surface_count()>1 else PackedVector2Array()
 var source_ground_faces=[]
 var center_native=provenance.coordinate_transform.center_halo_xy
 for group in source.groups:
  if group.role!="ground":continue
  for face in group.faces:
   var triangle=[]
   for index in face:
    var v=group.vertices[int(index)]
    triangle.append([Vector2((v.p[0]-center_native[0])*3.048,-(v.p[1]-center_native[1])*3.048),Vector2(v.uv[0],v.uv[1])])
   source_ground_faces.append(triangle)
 check(adaptation.get("boundary_cap_source_triangles",[]).size()==cap_points.size()/3,"every cap triangle records its native source face")
 var bad_cap=0
 for ti in cap_points.size()/3:
  var source_face=source_ground_faces[int(adaptation.boundary_cap_source_triangles[ti])]
  var a=source_face[0][0];var b=source_face[1][0];var c=source_face[2][0]
  var det=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
  for j in 3:
   var at=ti*3+j;var p=cap_points[at]
   var u=((b.y-c.y)*(p.x-c.x)+(c.x-b.x)*(p.z-c.y))/det
   var v=((c.y-a.y)*(p.x-c.x)+(a.x-c.x)*(p.z-c.y))/det
   if minf(u,minf(v,1-u-v))<-.0005:bad_cap+=1
   var expected_uv=source_face[0][1]*u+source_face[1][1]*v+source_face[2][1]*(1-u-v)
   if expected_uv.distance_to(cap_uv[at])>.00001:bad_cap+=1
   if p.distance_to(physical[points.size()+at])>.0001:bad_cap+=1
 check(bad_cap==0,"caps stay inside exact native faces with original UV and matching collision")

 var boundary_vertices={};var boundary_points=PackedVector3Array()
 for surface in cliffs.get_surface_count():
  for vertex in cliffs.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
   boundary_vertices[vertex.snapped(Vector3(.001,.001,.001))]=true;boundary_points.append(vertex)
 var cap_heights={}
 for vertex in cap_points:cap_heights[Vector2(vertex.x,vertex.z).snapped(Vector2(.001,.001))]=vertex.y
 var contact_checks=0;var contact_failures=0;var max_contact_gap=0.
 var contact_center=provenance.coordinate_transform.center_halo_xy
 var contact_baseline=provenance.coordinate_transform.floor_baseline_meters
 for group in source.groups:
  if group.role!="ground":continue
  for v in group.vertices:
   var native=Vector3((v.p[0]-contact_center[0])*3.048,v.p[2]*3.048-contact_baseline,-(v.p[1]-contact_center[1])*3.048)
   var key=Vector2(native.x,native.z).snapped(Vector2(.001,.001))
   if not cap_heights.has(key) or not boundary_vertices.has(native.snapped(Vector3(.001,.001,.001))):continue
   contact_checks+=1
   var gap=absf(float(cap_heights[key])-native.y);max_contact_gap=maxf(max_contact_gap,gap)
   if gap>.001:contact_failures+=1
 print("NATIVE_CLIFF_CONTACTS ",contact_checks," max_gap_m ",max_contact_gap)
 check(contact_checks>10 and contact_failures==0,"actual retained native cliff-foot vertices join boundary floor without shoulder gaps")
 var lost_upper_vertices=0
 var center=provenance.coordinate_transform.center_halo_xy
 var baseline=provenance.coordinate_transform.floor_baseline_meters
 for group in source.groups:
  if group.role!="cliff" and group.role!="boulder":continue
  for face in group.faces:
   for index in face:
    var p=group.vertices[int(index)].p
    var native=Vector3((p[0]-center[0])*3.048,p[2]*3.048-baseline,-(p[1]-center[1])*3.048)
    if native.y>12.001 and not boundary_vertices.has(native.snapped(Vector3(.001,.001,.001))):
     var nearest=INF
     for vertex in boundary_points:nearest=minf(nearest,vertex.distance_to(native))
     if nearest>.001 and lost_upper_vertices<3:print("UPPER_MISSING ",native," nearest ",nearest)
     if nearest>.001:lost_upper_vertices+=1
 check(lost_upper_vertices==0,"all native upper wall silhouette vertices survive adaptation")

 for v in field.get_meta("bridges"):check(v==0,"cliff roofs excluded from bridge navigation")
 print("BLOOD_GULCH_BAKE_CHECKS ",checks," failures ",failures)
 quit(1 if failures else 0)

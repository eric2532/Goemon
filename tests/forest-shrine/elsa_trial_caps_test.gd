extends "res://tests/forest-shrine/original_maps_test.gd"
const Scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")

func run():
 var props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/props/data.json"))
 var groups=[];var maps={};var placements=0
 for token in props.groups:
  var row:Dictionary=props.groups[token]
  if not row.has("native_floor_cap"):continue
  groups.append(token)
  var texture:Texture2D=load("res://assets/maps/falan/elsa/props/atlas-%d.png"%int(row.page))
  var solid:Texture2D=load("res://assets/maps/falan/elsa/props/solid-%d.png"%int(row.page))
  var g={"rect":row.rect,"origin":row.origin,"cut":[row.master]}
  var mesh:Mesh=Scenery.Fit.transformed(Scenery.small_props(g,[texture,solid],row),Scenery.Fit.native_coastal_frame())
  var arrays=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  var flat=true
  for point in vertices:flat=flat and point.y>0. and point.y<.1
  check(vertices.size()==6 and flat,"Native brown top paint lies on one ground quad instead of standing vertically")
  check(mesh.get_surface_count()==(2 if row.has("floor_paint") else 1),"The two embedded native pillars retain separate solid geometry")
  if row.has("floor_paint"):check(mesh.get_aabb().end.y>10. and row.columns.size()==2,"Mixed crop lifts both original pillars above the cap")
  var correct=true
  for i in vertices.size():
   var pixel=uv[i]*(Vector2(row.size[0],row.size[1]) if row.has("floor_paint") else texture.get_size())-(Vector2.ZERO if row.has("floor_paint") else Vector2(row.rect[0],row.rect[1]))+Vector2(row.origin[0],row.origin[1])
   var actual=Vector2((vertices[i].x+vertices[i].z)*32./3.,(vertices[i].z-vertices[i].x)*8.)
   correct=correct and actual.distance_to(pixel)<.001
  check(correct,"Every cap corner retains the original native XZ placement and surface art")
 for id in props.maps:
  for placement in props.maps[id]:
   if placement.group in groups:placements+=1;maps[id]=true
 check(groups.size()==4 and placements==168 and maps.size()==56,"All 168 repeated placements across 56 scoped trial maps share the four corrected caps")
 # The actual blue arches belong to separate crops and must remain upright.
 for token in ["562","563"]:check(not props.groups[token].has("native_floor_cap"),"The neighboring original blue cliff/arch is not flattened")
 var arch:Dictionary=props.groups["562"];var spec=JSON.parse_string(FileAccess.get_file_as_string(arch.source_surface.path))
 var paint:Texture2D=load("res://assets/maps/falan/elsa/props/atlas-%d.png"%int(arch.page))
 var arch_mesh:Mesh=Scenery.source_surface({"rect":arch.rect,"origin":arch.origin},paint,spec)
 check(arch_mesh.get_surface_count()==1 and arch_mesh.get_faces().size()/3==1152,"Original arch paint shares the existing BG cliff tessellation")
 var entrance_spec=Scenery.TrialEntrance.data()
 var top=(float(entrance_spec.foot_v)-float(entrance_spec.anchor[1])-float(arch.origin[1]))/Scenery.Fit.VERTICAL
 var bottom=top-float(arch.rect[3])/Scenery.Fit.VERTICAL
 check(absf(arch_mesh.get_aabb().position.y-bottom)<.05 and absf(arch_mesh.get_aabb().end.y-top)<.05,"The fitted arch retains its original full source span around the documented walking-height foot")
 var arch_arrays=arch_mesh.surface_get_arrays(0);var arch_vertices:PackedVector3Array=arch_arrays[Mesh.ARRAY_VERTEX];var arch_uv:PackedVector2Array=arch_arrays[Mesh.ARRAY_TEX_UV]
 var max_error=0.
 for i in arch_vertices.size():
  var expected=arch_uv[i]*paint.get_size()-Vector2(arch.rect[0],arch.rect[1])+Vector2(arch.origin[0],arch.origin[1])
  max_error=maxf(max_error,Scenery.Fit.project(Basis(Vector3.UP,PI*.5)*arch_vertices[i]).distance_to(expected))
 check(max_error<.7,"Source camera projection retains original paint scale within the 3 cm overlay offset")
 print("ELSA_TRIAL_ARCH triangles=",arch_mesh.get_faces().size()/3," source_pixel_error=",max_error)
 var first=Scenery.source_surface_spec(arch.source_surface.path,59609)
 var second=Scenery.source_surface_spec(arch.source_surface.path,59603)
 check(first.background_template!=second.background_template,"Two original BG fits select distinct shared arch depth variants")
 check(Scenery.source_surface_spec(arch.source_surface.path,59602).background_template==first.background_template,"Maps with identical BG depth share one prepared arch fit")
 var different=0
 for i in first.quads.size():
  if first.quads[i]!=second.quads[i]:different+=1
 check(different==137,"The alternate map's137 different BG patches do not reuse59609 depth")
 var second_mesh=Scenery.source_surface({"rect":arch.rect,"origin":arch.origin},paint,second)
 var second_arrays=second_mesh.surface_get_arrays(0);var second_vertices:PackedVector3Array=second_arrays[Mesh.ARRAY_VERTEX];var second_uv:PackedVector2Array=second_arrays[Mesh.ARRAY_TEX_UV]
 max_error=0.
 for i in second_vertices.size():
  var expected=second_uv[i]*paint.get_size()-Vector2(arch.rect[0],arch.rect[1])+Vector2(arch.origin[0],arch.origin[1])
  max_error=maxf(max_error,Scenery.Fit.project(Basis(Vector3.UP,PI*.5)*second_vertices[i]).distance_to(expected))
 check(max_error<.7,"Both BG depth variants preserve the same original source-camera paint projection")
 var entrance=Scenery.TrialEntrance
 check(entrance.data().map_source_proofs.size()==56 and not entrance.owns(59530),"Entrance fit covers exactly its56 source-proven trial maps")
 var fixed_floor=true;var projection_error=0.
 for u in range(4384,4577,32):
  for v in range(928,1281,32):
   var floor_point=Vector3(u*3./64.-v/16.,.012,u*3./64.+v/16.)
   fixed_floor=fixed_floor and entrance.fitted(floor_point,Vector2.ZERO)==floor_point
   var wall=floor_point-Vector3.UP*12.;var fitted:Vector3=entrance.fitted(wall,Vector2.ZERO)
   projection_error=maxf(projection_error,Scenery.Fit.project(Basis(Vector3.UP,PI*.5)*wall).distance_to(Scenery.Fit.project(Basis(Vector3.UP,PI*.5)*fitted)))
 check(fixed_floor and projection_error<.001,"CPU entrance fitting fixes every floor sample and retains the source wall projection")
 var root_=Node3D.new();entrance.build(root_,59603,Vector2(-297,-297))
 check(root_.get_child_count()==1 and root_.get_child(0) is MeshInstance3D and root_.get_child(0).get_child_count()==0,"Shared recess adds one visual mesh and no interaction or collision owner")
 check(root_.get_child(0).mesh.get_surface_count()==2 and root_.get_child(0).get_meta("inferred_floor_thickness")==.5,"Source recess paint and dark inner edges keep distinct shared surfaces and declared inferred thickness")
 root_.free()
 print("ELSA_TRIAL_CAPS_RESULT groups=",groups.size()," placements=",placements," maps=",maps.size()," checks=",checks," failures=",failures)
 await finish()

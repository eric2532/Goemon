extends RefCounted
## Private10074study: source-sized whole canopy lobes, no full-front leaf plane.
const Native=preload("res://scripts/forest/forest_east_native_trees.gd")
const Base=Native.Base
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Cluster Candidate/"
static var result:Mesh
static func projected(p:Vector3)->Vector2:return Vector2((p.x+p.z)*Base.Fit.HORIZONTAL,(p.z-p.x)*Base.Fit.FLOOR-p.y*Base.Fit.VERTICAL)
static func lobe_fit(points:Array[Vector3],target:Rect2)->Transform3D:
 var bounds=Rect2(projected(points[0]),Vector2.ZERO)
 for p:Vector3 in points:bounds=bounds.expand(projected(p))
 var u=Vector3(1,0,1).normalized();var v=Vector3(-Base.Fit.FLOOR,-Base.Fit.VERTICAL,Base.Fit.FLOOR).normalized();var depth=u.cross(v).normalized()
 var su=target.size.x/bounds.size.x;var sv=target.size.y/bounds.size.y;var sd=sqrt(su*sv)
 var axes=[]
 for axis:Vector3 in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:axes.append(u*axis.dot(u)*su+v*axis.dot(v)*sv+depth*axis.dot(depth)*sd)
 var shift=target.get_center()-bounds.get_center()*Vector2(su,sv)
 return Transform3D(Basis(axes[0],axes[1],axes[2]),u*shift.x/(sqrt(2.)*Base.Fit.HORIZONTAL)+v*shift.y/sqrt(2.*Base.Fit.FLOOR*Base.Fit.FLOOR+Base.Fit.VERTICAL*Base.Fit.VERTICAL))
static func mesh(serial:int)->Mesh:
 assert(serial==10074,"Review one source/side/rear cluster prototype first")
 if result!=null:return result
 Base.Art.load_east();var g:Dictionary=Base.Art.data().graphics[str(serial)];var spec:Dictionary=Native.data().graphics[str(serial)];var parts=[]
 for part:Dictionary in Base.Meadow.source(spec.asset):
  if part.name=="Canopy":parts.append(Base.transformed_existing(part.mesh,part.transform,part.material))
 var master:Mesh=Base.combine(parts);var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO);var master_points:Array[Vector3]=[]
 for arrays:Array in master.get_meta("east_cpu_arrays"):
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:master_points.append(turn*p)
 var lobes=[[50,0,180,112],[0,75,225,184],[48,150,210,228]];var clouds=[];var front=Base.native_skin(g.duplicate(true),ImageTexture.create_from_image(Image.load_from_file(ROOT+"10074-leaves.png")));front.graphic[0]=Rect2(0,0,g.rect[2],g.rect[3]);var front_triangles=0;var eye=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized();var diagnostic=[]
 for box:Array in lobes:
  var target=Rect2(Vector2(g.origin[0]+box[0],g.origin[1]+box[1]),Vector2(box[2]-box[0],box[3]-box[1]));var fit=lobe_fit(master_points,target)*turn;var cloud:Mesh=Base.transformed_existing(master,fit)
  var dots=Vector2(INF,-INF);var triangle_count=0
  for slot in cloud.get_surface_count():
   var material:Material=cloud.surface_get_material(slot)
   if material is StandardMaterial3D:
    var leaves=ShaderMaterial.new();leaves.shader=Base.Meadow.WIND;leaves.set_shader_parameter("tree",true);leaves.set_shader_parameter("canopy",true);leaves.set_shader_parameter("strength",.025);leaves.set_shader_parameter("use_source_paint",true);leaves.set_shader_parameter("source_paint",material.albedo_texture);leaves.set_shader_parameter("source_cutout",true);leaves.set_shader_parameter("foliage_tint",Vector3(spec.foliage_tint[0],spec.foliage_tint[1],spec.foliage_tint[2]));cloud.surface_set_material(slot,leaves)
   var arrays:Array=cloud.get_meta("east_cpu_arrays")[slot];var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var count=indices.size()if indices is PackedInt32Array and not indices.is_empty()else vertices.size()
   for at in range(0,count,3):
    var a=vertices[indices[at]if indices is PackedInt32Array and not indices.is_empty()else at];var b=vertices[indices[at+1]if indices is PackedInt32Array and not indices.is_empty()else at+1];var c=vertices[indices[at+2]if indices is PackedInt32Array and not indices.is_empty()else at+2];var normal=(c-a).cross(b-a).normalized()
    var facing=normal.dot(eye);dots.x=minf(dots.x,facing);dots.y=maxf(dots.y,facing);triangle_count+=1
    if absf(facing)<.12:continue
    var observed=[a,b,c]
    if facing<0:normal=-normal;observed=[a,c,b]
    for point:Vector3 in observed:front.projected_vertex(point+normal*.012,normal,point)
    front_triangles+=1
  diagnostic.append({"bounds":var_to_str(cloud.get_aabb()),"fit":var_to_str(fit),"normal_dot_range":var_to_str(dots),"triangles":triangle_count});clouds.append(cloud)
 print("CLUSTER_DIAGNOSTIC ",JSON.stringify(diagnostic)," painted=",front_triangles)
 if front_triangles==0:push_error("Private canopy has no observed-facing triangles; no empty source surface was committed");return null
 result=Base.owner_frame(Base.combine([Native.Traced.native_branches(g,spec)]+clouds+[front.finish()]));result.set_meta("private_source_tree_cluster",serial);result.set_meta("source_lobe_rectangles",lobes);result.set_meta("leaf_only_bottom",228);result.set_meta("native_front_triangles",front_triangles);result.set_meta("inferred_lobe_partition",true);result.set_meta("natural_master_depth_retained",true);result.set_meta("lobe_geometry",diagnostic);return result

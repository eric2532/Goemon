extends RefCounted
## Private single closed crown; native front and wood, independently tiled reverse.
const Native=preload("res://scripts/forest/forest_east_native_trees.gd")
const Base=Native.Base
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Closed Crown Candidate/"
static var result:Mesh
static func mesh(serial:int)->Mesh:
 assert(serial==10074)
 if result!=null:return result
 Base.Art.load_east()
 var g:Dictionary=Base.Art.data().graphics[str(serial)];var spec:Dictionary=Native.data().graphics[str(serial)]
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json"))
 var pixels:Array=data.vertices;var front_points:PackedVector3Array=[];var back_points:PackedVector3Array=[]
 var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 for i in pixels.size():
  var p=Base.projected(Base.v(pixels[i]),g,0.,float(spec.ground_offset));var depth=float(data.depths[i])
  front_points.append(p+ray*depth);back_points.append(p-ray*depth)
 var row:Dictionary=g.duplicate(true);row.rect=[0,0,g.rect[2],g.rect[3]]
 var source=ImageTexture.create_from_image(Image.load_from_file(ROOT+"10074-native.png"))
 var front=Base.native_skin(row,source);var back=SurfaceTool.new();back.begin(Mesh.PRIMITIVE_TRIANGLES)
 var sums:PackedVector3Array=[];sums.resize(pixels.size());var reverse_sums:PackedVector3Array=[];reverse_sums.resize(pixels.size())
 for tri in data.front_triangles:
  var a=int(tri[0]);var b=int(tri[1]);var c=int(tri[2])
  var normal=(front_points[c]-front_points[a]).cross(front_points[b]-front_points[a]).normalized()
  if normal.dot(ray)<0.:normal=-normal
  var reverse_normal=(back_points[c]-back_points[a]).cross(back_points[b]-back_points[a]).normalized()
  if reverse_normal.dot(ray)>0.:reverse_normal=-reverse_normal
  for index in tri:sums[int(index)]+=normal;reverse_sums[int(index)]+=reverse_normal
 for i in sums.size():sums[i]=sums[i].normalized();reverse_sums[i]=reverse_sums[i].normalized()
 for tri in data.front_triangles:
  var ids=[int(tri[0]),int(tri[1]),int(tri[2])]
  if (front_points[ids[2]]-front_points[ids[0]]).cross(front_points[ids[1]]-front_points[ids[0]]).dot(ray)<0.:ids.reverse()
  for id in ids:
   var reference=Base.projected(Base.v(pixels[id]),g,0.,float(spec.ground_offset))
   front.projected_vertex(front_points[id],sums[id],reference)
  ids.reverse()
  for id in ids:back.set_normal(reverse_sums[id]);back.add_vertex(back_points[id])
 for edge in data.boundary_edges:
  var a=int(edge[0]);var b=int(edge[1]);var points=[front_points[a],front_points[b],back_points[b],back_points[a]]
  var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for id in [0,1,2,0,2,3]:back.set_normal(normal);back.add_vertex(points[id])
 var arrays=back.commit_to_arrays();var reverse=ArrayMesh.new();reverse.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);reverse.set_meta("east_cpu_arrays",[arrays])
 var material=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(ROOT+"leaf-grain.png"));material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*float(data.rear_texture_repeats_per_world_unit);material.roughness=1.;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 reverse.surface_set_material(0,material)
 result=Base.owner_frame(Base.combine([Native.Traced.native_branches(g,spec),front.finish(),reverse]));result.set_meta("private_closed_crown",serial);result.set_meta("closed_rim_edges",data.boundary_edges.size());result.set_meta("source_points",pixels.size());result.set_meta("max_inferred_half_depth",data.depths.max());return result

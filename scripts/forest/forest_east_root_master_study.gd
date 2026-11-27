extends RefCounted
## Private silhouette study: existing whole Meadow bole/root master, not live art.
const Old=preload("res://scripts/forest/forest_east_root_compounds.gd")
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
static var prepared:Mesh
static func mesh()->Mesh:
 if prepared!=null:return prepared
 var g=Old.body_graphic();var core=Base.point(Vector2(364,327),0.,g);var top=Base.point(Vector2(385,0),327./Base.Fit.VERTICAL,g);top.y*=Base.OWNER_Y_SCALE
 var shape=Base.PreparedSkin.new([],load(Old.ROOT+"bark-grain.png"),.045);shape.tiles={"bark":Vector2.ZERO};shape.part="bark"
 for part in Base.Meadow.source("crossgate_flora/cg_woodland"):
  if part.name!="Body":continue
  var reference:Mesh=Base.transformed_existing(part.mesh,part.transform);var root_box=AABB();var first=true
  for arrays:Array in reference.get_meta("east_cpu_arrays"):
   for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    if p.y<.6:root_box=AABB(p,Vector3.ZERO) if first else root_box.expand(p);first=false
  var scale_=Vector3(34./root_box.size.x,top.y/3.2,34./root_box.size.z);var center=root_box.get_center();var normal_scale=Basis.IDENTITY.scaled(scale_).inverse().transposed()
  for arrays:Array in reference.get_meta("east_cpu_arrays"):
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty();var count=indices.size() if indexed else vertices.size()
   for start in range(0,count,3):
    var source=[];var normals=[];var uv=[]
    for corner in 3:
     var i=indices[start+corner] if indexed else start+corner;source.append(vertices[i]);normals.append(arrays[Mesh.ARRAY_NORMAL][i]);uv.append(arrays[Mesh.ARRAY_TEX_UV][i])
    if source.any(func(p:Vector3):return p.y>3.2):continue
    for corner in 3:
     var p:Vector3=source[corner];var fraction=clampf(p.y/3.2,0.,1.);var at=core+Vector3((p.x-center.x)*scale_.x,maxf(0.,p.y)*scale_.y,(p.z-center.z)*scale_.z)+(top-Vector3(core.x,top.y,core.z))*fraction
     shape.surface.set_normal((normal_scale*normals[corner]).normalized());shape.surface.set_uv(uv[corner]*4.);shape.surface.set_uv2(Vector2.ZERO);shape.surface.add_vertex(at)
 var parts=[Base.bark_finish(shape)];var old=Old.mesh();var arrays:Array=old.get_meta("east_cpu_arrays")
 for slot in[5,6,7,8,9]:
  var piece=ArrayMesh.new();piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays[slot]);piece.surface_set_material(0,old.surface_get_material(slot));piece.set_meta("east_cpu_arrays",[arrays[slot]]);parts.append(piece)
 prepared=Base.combine(parts);return prepared

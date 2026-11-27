extends "res://scripts/forest/forest_freyja_terrain.gd"
## Private prototype only. The source field resource and covered bytes stay shared/unchanged.
var private_bed=PackedFloat32Array()
var private_geometry:Dictionary={}
var private_mesh:ArrayMesh

func mesh_heights()->PackedFloat32Array:return private_bed if not private_bed.is_empty() else super.mesh_heights()
func geometry_entry()->Dictionary:return private_geometry

func mesh()->ArrayMesh:
 if private_bed.is_empty():return super.mesh()
 if private_mesh!=null:return private_mesh
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var indices=PackedInt32Array()
 vertices.resize(width*width);normals.resize(width*width)
 var origin=-coordinate(0,0)*spacing;var columns=mask_image().get_width() if variant=="east_gate" else width;var rows=mask_image().get_height() if variant=="east_gate" else width
 indices.resize((columns-1)*(rows-1)*6)
 for z in width:
  for x in width:
   var i=z*width+x;vertices[i]=Vector3(origin.x+x*spacing,private_bed[i],origin.y+z*spacing)
   var dx=private_bed[z*width+mini(x+1,width-1)]-private_bed[z*width+maxi(0,x-1)]
   var dz=private_bed[mini(z+1,width-1)*width+x]-private_bed[maxi(z-1,0)*width+x]
   normals[i]=Vector3(-dx,spacing*2,-dz).normalized()
   if x>=columns-1 or z>=rows-1:continue
   var at=(z*(columns-1)+x)*6
   for pair in [[0,i],[1,i+1],[2,i+width],[3,i+1],[4,i+width+1],[5,i+width]]:indices[at+pair[0]]=pair[1]
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 private_mesh=ArrayMesh.new();private_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);private_mesh.set_meta("source_surface_arrays",arrays)
 return private_mesh

func apply_grade(data:Dictionary,frame:Transform2D=Transform2D.IDENTITY)->Array:
 assert(variant in ["il_village","east_gate"],"The private grade belongs only to source Il")
 heights=heights.duplicate();private_bed=super.mesh_heights().duplicate();var changes=[]
 for row:Dictionary in data.height_changes:
  if row.has("only_terrain_variant") and row.only_terrain_variant!=variant:continue
  var point=frame*Vector2(row.anchor[0],row.anchor[1]);var grid=coordinate(point.x,point.y);var cell=Vector2i(grid.round())
  assert(grid.distance_to(Vector2(cell))<.0001,"Each inferred grade vertex must match the existing terrain grid")
  var index=cell.y*width+cell.x
  assert(covered[index]!=0 and absf(heights[index]-float(row.before_height_expected))<.025,"Only recorded original-open dry6m source vertices are regraded")
  changes.append({"source_cell":row.source_cell,"terrain_vertex":cell,"terrain_index":index,"before_covered":covered[index],"after_covered":covered[index],"before_height":heights[index],"before_bed":private_bed[index],"after_height":row.after_height})
  heights[index]=row.after_height;private_bed[index]=row.after_height
 flat_corridor_cache.clear();disk_region_cache.clear();cliff_cache.clear();building_ground_cache.clear()
 return changes

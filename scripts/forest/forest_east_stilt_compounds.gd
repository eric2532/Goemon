extends RefCounted
## Private measured cottage candidate; source map/underlay ownership is still separate.
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Tiles=preload("res://assets/maps/original_crossgate/building-surfaces.gd")
const TimberAtlas=preload("res://assets/maps/original_crossgate/building-surfaces.png")
const ROOT="res://assets/maps/falan/east_region/stilt_compounds/"
static var catalog:Dictionary={}
static var meshes:Dictionary={}

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func prototype_owns(serial:int)->bool:return data().graphics.has(str(serial))

static func retarget_paint(reference:Mesh,g:Dictionary,paint:Texture2D)->Mesh:
 var result=ArrayMesh.new();var retained=[];var old_texture=East.texture(g)
 for slot in reference.get_surface_count():
  var arrays:Array=reference.get_meta("east_cpu_arrays")[slot].duplicate(true)
  var material:ShaderMaterial=reference.surface_get_material(slot)
  if material.get_shader_parameter("base_texture")==old_texture:
   var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   for index in uv.size():uv[index]=uv[index]*old_texture.get_size()/paint.get_size()
   arrays[Mesh.ARRAY_TEX_UV]=uv;material=Source.material(paint)
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(slot,material);retained.append(arrays)
 result.set_meta("east_cpu_arrays",retained);return result

static func closed_stairs(g:Dictionary,spec:Dictionary)->Mesh:
 var base=Source.new([],TimberAtlas,1./East.Fit.VERTICAL);base.tiles={"wood":Tiles.TILES.tina_fence_wood};base.part="wood"
 var a=East.point(East.v(spec.near[0]),0,g);var b=East.point(East.v(spec.near[1]),0,g)
 var high=float(spec.height_pixels)/East.Fit.VERTICAL;var c=East.point(East.v(spec.far[0]),high,g);var d=East.point(East.v(spec.far[1]),high,g)
 for step in int(spec.steps):
  var t=float(step)/float(spec.steps);var u=float(step+1)/float(spec.steps)
  var p=a.lerp(c,t);var q=b.lerp(d,t);var r=b.lerp(d,u);var s=a.lerp(c,u)
  var floor_=[Vector3(p.x,0,p.z),Vector3(q.x,0,q.z),Vector3(r.x,0,r.z),Vector3(s.x,0,s.z)]
  var top=[Vector3(p.x,u*high-.012,p.z),Vector3(q.x,u*high-.012,q.z),Vector3(r.x,u*high-.012,r.z),Vector3(s.x,u*high-.012,s.z)]
  base.quad(top[0],top[1],top[2],top[3]);base.quad(floor_[3],floor_[2],floor_[1],floor_[0])
  for side in 4:
   var next=(side+1)%4;base.quad(floor_[side],floor_[next],top[next],top[side])
 var result=base.finish(true);result.set_meta("east_cpu_arrays",[result.get_meta("source_surface_arrays")]);return result

static func finial(g:Dictionary,spec:Dictionary,paint:Texture2D)->Mesh:
 var across=Vector3(1,0,1).normalized();var normal=Vector3(-1,0,1).normalized()
 var center=East.point(East.v(spec.floor_center_pixel),0,g);var ground=(center.z-center.x)*8.
 var outline=PackedVector2Array()
 for row:Array in spec.finial_outline:
  var point=East.projected(East.v(row),g,0.,ground);outline.append(Vector2(point.dot(across),point.y))
 var shape=Shapes.extrude(outline,.22);var arrays=shape.surface_get_arrays(0)
 var front=East.native_skin(g,paint);var back=East.structure();back.part="leaf_roof_green"
 var depth_at=center.dot(normal)
 for index in arrays[Mesh.ARRAY_VERTEX].size():
  var old:Vector3=arrays[Mesh.ARRAY_VERTEX][index];var old_normal:Vector3=arrays[Mesh.ARRAY_NORMAL][index]
  var p=across*old.x+Vector3.UP*old.y+normal*(old.z+depth_at)
  var n=(across*old_normal.x+Vector3.UP*old_normal.y+normal*old_normal.z).normalized()
  back.surface.set_normal(n);back.surface.set_uv2(back.tiles.leaf_roof_green);back.surface.set_uv(Vector2(p.dot(across),-p.y)/1.2);back.surface.add_vertex(p)
  if n.dot(normal)>.9:front.projected_vertex(p+normal*.008,n,p)
 return East.combine([back.finish(),front.finish()])

static func mesh(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 assert(prototype_owns(serial),"Only the measured private cottage prototype is prepared")
 Art.load_east();var row:Dictionary=data().graphics[str(serial)]
 var g:Dictionary=Art.data().graphics["1233262"].duplicate(true)
 g.rect=[0,0,row.size[0],row.size[1]];g.origin=row.origin
 var paint:Texture2D=load(ROOT+str(serial)+"-front.png");var parts=[]
 for spec:Dictionary in [row.body,row.roof]:parts.append(retarget_paint(East.round_body(g,spec),g,paint))
 for pixel:Array in row.pilings:
  var spec={"base":pixel,"height_pixels":row.floor_level_pixels,"diameter":19,"material":"timber","sides":16,"profile":[[0,.75],[.08,1],[.18,1],[.25,.64],[.8,.52],[.88,.8],[1,.8]]}
  parts.append(retarget_paint(East.round_body(g,spec),g,paint))
 # The unseen fourth piling follows the same measured ring; it creates no route.
 var center=East.point(East.v(row.floor_center_pixel),0,g);var native=East.point(East.v(row.pilings[0]),0,g)
 var hidden=center*2.-native;var hidden_pixel=Vector2((hidden.x+hidden.z)*32./3.,(hidden.z-hidden.x)*8.)-Vector2(g.origin[0],g.origin[1])
 parts.append(retarget_paint(East.round_body(g,{"base":[hidden_pixel.x,hidden_pixel.y],"height_pixels":row.floor_level_pixels,"diameter":19,"material":"timber","sides":16,"tiled_front":true,"profile":[[0,.75],[.08,1],[.18,1],[.25,.64],[.8,.52],[.88,.8],[1,.8]]}),g,paint))
 parts.append(retarget_paint(East.stairs(g,row.stairs),g,paint));parts.append(closed_stairs(g,row.stairs));parts.append(finial(g,row,paint))
 var result=East.owner_frame(East.combine(parts));var retained:Array=result.get_meta("east_cpu_arrays")
 var rebuilt=ArrayMesh.new();var final_arrays=[]
 for slot in result.get_surface_count():
  var arrays:Array=retained[slot].duplicate(true);var material:ShaderMaterial=result.surface_get_material(slot)
  if material.get_shader_parameter("atlas_tile_pixels")==128.:
   var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var tiles:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
   for index in uv.size():
    if tiles[index] not in [East.Surfaces.TILES.timber,East.Surfaces.TILES.leaf_roof_gold,East.Surfaces.TILES.leaf_roof_green,Tiles.TILES.tina_fence_wood]:continue
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];var n:Vector3=arrays[Mesh.ARRAY_NORMAL][index]
    var tangent=n.cross(Vector3.UP).normalized();uv[index]=Vector2(p.x,p.z)/1.5 if absf(n.y)>.8 else Vector2(p.dot(tangent),-p.y)/1.5
   arrays[Mesh.ARRAY_TEX_UV]=uv
  rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);rebuilt.surface_set_material(slot,material);final_arrays.append(arrays)
 rebuilt.set_meta("east_cpu_arrays",final_arrays);rebuilt.set_meta("source_graphic",serial);rebuilt.set_meta("source_cell",Vector2i(row.source_cell[0],row.source_cell[1]));rebuilt.set_meta("owner_y_conversions",1)
 rebuilt.set_meta("native_floor_changes",false);rebuilt.set_meta("native_layered_compound",true)
 meshes[serial]=rebuilt;return rebuilt

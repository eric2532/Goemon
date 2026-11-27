extends RefCounted
## Native object-layer floor art can be larger than its one-cell logical footprint.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_region/ground_motifs/"
const IDS=[11063,11064,11067,11166,11168,11212,11213,11214,11219,11220,11221,11222,11223,11224,11225,11226,11227,11228,11709,11723,11734,11735,11736,11737,11738,11739,11740,11741,11742,11799,11803,16347,16535,16546,16547,16638,16639,16640,16641,16642]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 assert(g.rgba_sha256==data().graphics[str(serial)].source_rgba_sha256,"Recheck native flat motif classification")
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var size_=Vector2(g.rect[2],g.rect[3]);var atlas:Texture2D=load(Art.ROOT+Art.data().pages[int(g.page)])
 var pixels=[Vector2.ZERO,Vector2(size_.x,0),size_,Vector2(0,size_.y)]
 for index in [0,1,2,0,2,3]:
  var native=pixels[index]+Vector2(g.origin[0],g.origin[1]);tool.set_normal(Vector3.UP)
  tool.set_uv((Vector2(g.rect[0],g.rect[1])+pixels[index].clamp(Vector2.ONE*.5,size_-Vector2.ONE*.5))/atlas.get_size())
  tool.add_vertex(Vector3(native.x*3./64.-native.y/16.,.025,native.x*3./64.+native.y/16.))
 var result=tool.commit();result.surface_set_material(0,Source.material(atlas));result.set_meta("east_full_extent_ground_motif",serial);result.set_meta("source_rgba_sha256",g.rgba_sha256)
 meshes[serial]=result;return result

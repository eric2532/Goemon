extends RefCounted
## Six native treads; unseen surfaces continue their own measured stone paint.
const IDS=[17964,17966,17972,17984,17996]
const Stairs=preload("res://scripts/forest/forest_habaru_stairs.gd")
const Parts=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Stone=preload("res://scripts/forest/forest_stone_fort.gd")
static var meshes={}
static var paint={}

static func mesh(serial:int)->Mesh:
 assert(serial in IDS)
 if meshes.has(serial):return meshes[serial]
 if paint.is_empty():paint=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/native_stairs/provenance.json")).graphics
 var stage=Node3D.new()
 Stairs.build(stage,0,Vector2i.ZERO,Vector2.ZERO,serial,StandardMaterial3D.new(),null,6)
 var tops=Parts.tool();var risers=Parts.tool()
 for part:MeshInstance3D in stage.find_children("*","MeshInstance3D",true,false):
  var arrays=part.mesh.surface_get_arrays(0)
  for i in arrays[Mesh.ARRAY_INDEX]:
   var p:Vector3=part.transform*arrays[Mesh.ARRAY_VERTEX][i]
   var n:Vector3=part.basis*arrays[Mesh.ARRAY_NORMAL][i]
   var uv=Vector2(p.x,p.z) if absf(n.y)>.5 else Vector2(p.z,-p.y) if absf(n.x)>.5 else Vector2(p.x,-p.y)
   var surface=tops if n.y>.5 else risers
   surface.set_normal(n);surface.set_uv(uv/1.5);surface.add_vertex(p)
 stage.free()
 var pigment:Array=paint[str(serial)].stone_color
 var color=Color(pigment[0],pigment[1],pigment[2])
 var result=Parts.finish([tops,risers],[Stone.material(color,false),Stone.material(color*.60,false)])
 result.set_meta("source_stair_treads",6)
 meshes[serial]=result
 return result

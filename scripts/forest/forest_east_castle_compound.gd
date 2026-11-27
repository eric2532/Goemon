extends RefCounted
## Exact native71-piece repetition of the existing complete Beast Castle owner.
const Castle=preload("res://scripts/forest/forest_beast_castle.gd")
const Roof=preload("res://scripts/forest/forest_east_castle_roof.gd")
const PATH="res://assets/maps/falan/east_region/classic_architecture/castle_compound/data.json"
static var catalog:Dictionary={}
static var pieces:Dictionary={}

static func data()->Dictionary:
 if catalog.is_empty():
  catalog=JSON.parse_string(FileAccess.get_file_as_string(PATH))
  for row:Array in catalog.pieces:pieces[Vector3i(row[0],row[1],row[2])]=int(row[3])
 return catalog

static func mesh()->Mesh:return Roof.mesh()

static func owns(source:int)->bool:return source==31954

static func skip(source:int,layer:int,cell:Vector2i,serial:int)->bool:
 if not owns(source):return false
 data();return int(pieces.get(Vector3i(layer,cell.x,cell.y),-1))==serial

static func build(root:Node3D,source:int,state:Dictionary)->int:
 if not owns(source):return 0
 var spec=data()
 assert(state.size==Vector2i(spec.size[0],spec.size[1]),"Native castle compound must retain its original source frame")
 var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(state.raw)
 assert(hash_.finish().hex_encode()==spec.source_raw_sha256,"Regenerate changed native castle compound before composing source pieces")
 var anchor=Vector2(state.origin)+Vector2(spec.anchor[0],spec.anchor[1])*3.
 Castle.build(root,Vector3(anchor.x,0,anchor.y))
 var node=root.get_child(root.get_child_count()-1)
 node.mesh=mesh()
 node.name="NativeEastBeastCastleCompound";node.set_meta("east_native_castle_compound",true)
 node.set_meta("source_anchor",Vector2i(spec.anchor[0],spec.anchor[1]));node.set_meta("native_constituents",int(spec.piece_count))
 return int(spec.piece_count)

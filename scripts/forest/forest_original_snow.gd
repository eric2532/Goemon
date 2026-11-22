extends RefCounted
## New connected layouts; the 408 client snapshots remain reference material.

const PATH="generated:snow"
const TITLE="積雪的山路"
const GROUND=[8175,8175,8175,8175,8175,8175,8175,8175,8168,8169,8170,8171,8172,8173,8174,8176]
const TREES=[0,0,0,11622,11623,11624]
static var prepared:Dictionary={}

static func make(id:int,seed_:int)->Dictionary:
 var Winter=load("res://scripts/forest/forest_frostpass.gd")
 if prepared.has(id) and prepared[id].seed==seed_:return prepared[id]
 var maze=Winter.snow_maze(id,seed_)
 var size_=Winter.SIZE
 var raw=PackedByteArray();raw.resize(20+size_.x*size_.y*6)
 raw[0]=77;raw[1]=65;raw[2]=80;raw[3]=1
 raw.encode_u32(12,size_.x);raw.encode_u32(16,size_.y)
 var rng=Winter.Maze.rng_for(id,seed_)
 var ground_bag:Array=[];var tree_bag:Array=[]
 for z in size_.y:
  for x in size_.x:
   var cell=Vector2i(x,z)
   var opened=open(maze.bits,cell)
   var edge=false
   if not opened:
    for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     if open(maze.bits,cell+step):edge=true;break
   var i=z*size_.x+x
   var tree=0
   if edge:
    if tree_bag.is_empty():tree_bag=Winter.Maze.shuffled(TREES,rng)
    tree=tree_bag.pop_back()
    raw.encode_u16(20+(size_.x*size_.y+i)*2,tree)
   if opened or tree!=0:
    if ground_bag.is_empty():ground_bag=Winter.Maze.shuffled(GROUND,rng)
    raw.encode_u16(20+i*2,ground_bag.pop_back())
   raw.encode_u16(20+(2*size_.x*size_.y+i)*2,49152)
 for index in Winter.DOORS[id].size():
  var cell:Vector2i=Winter.DOORS[id][index]
  raw.encode_u16(20+(size_.x*size_.y+cell.y*size_.x+cell.x)*2,17956+index)
 prepared[id]={"seed":seed_,"raw":raw,"bits":maze.bits,"size":size_,"origin":Winter.ORIGIN}
 return prepared[id]

static func open(bits:PackedByteArray,cell:Vector2i)->bool:
 if not Rect2i(Vector2i.ZERO,Vector2i(33,27)).has_point(cell):return false
 var i=cell.y*33+cell.x
 return (bits[i>>3]&(1<<(i&7)))!=0

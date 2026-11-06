extends RefCounted
## Shared fitted bounds for map validation, picking, physics and native navigation.
const MIN_SCALE=.5
const MAX_SCALE=2.0
const TURN=15
const MAX_HEIGHT=256.0
const GROUPS=["trees","rocks","props"]
const CEDAR="res://assets/models/cedar_pass/"
const MEADOW="res://assets/models/environments/wind_meadow/"
const CATALOG={
	"shrub":{"label":"Leafy Bush","short":"Bush","asset":MEADOW+"leafy_shrub.glb","box":AABB(Vector3(-1.59,0,-1.56),Vector3(3.05,1.97,3.03)),"size":1.5,"material":"leaves","wind":true},
	"cedar":{"label":"Cedar Tree","short":"Cedar","asset":MEADOW+"cedar_tree.glb","box":AABB(Vector3(-.4,0,-.4),Vector3(1,7.1,.8)),"size":1.5,"material":"wood","wind":true},
	"pine":{"label":"Cloud Pine","short":"Pine","asset":MEADOW+"pine_tree.glb","box":AABB(Vector3(-.4,0,-.4),Vector3(1,5.6,.8)),"size":1.5,"material":"wood","wind":true},
	"sakura":{"label":"Sakura Tree","short":"Sakura","asset":MEADOW+"sakura_tree.glb","box":AABB(Vector3(-.4,0,-.4),Vector3(1,5.6,.8)),"size":1.5,"material":"wood","wind":true},
	"bamboo":{"label":"Bamboo Cluster","short":"Bamboo","asset":MEADOW+"bamboo_cluster.glb","box":AABB(Vector3(-.9,0,-.6),Vector3(2.1,6.31,1.3)),"size":1.0,"material":"wood","wind":true},
	"river_rock":{"label":"River Rock","short":"River","asset":CEDAR+"river_rock.glb","box":AABB(Vector3(-1.241,0,-.931),Vector3(2.658,1.3,1.805)),"size":1.5,"material":"stone"},
	"moss_rock":{"label":"Moss Boulder","short":"Moss","asset":CEDAR+"moss_boulder.glb","box":AABB(Vector3(-1.311,0,-1.137),Vector3(2.879,2.401,2.303)),"size":1.5,"material":"stone"},
	"stone_block":{"label":"Stone Block","short":"Block","asset":MEADOW+"buildings/stone_block.glb","box":AABB(Vector3(-3,0,-3),Vector3(6,6,6)),"size":1.0,"material":"stone"},
	"wall_cap":{"label":"Wall Cap","short":"Cap","asset":MEADOW+"buildings/wall_cap.glb","box":AABB(Vector3(-3,0,-3),Vector3(6,.7,6)),"size":1.0,"material":"stone"},
	"wall_corner":{"label":"Wall Corner","short":"Corner","asset":MEADOW+"buildings/wall_corner.glb","box":AABB(Vector3(-3,0,-3),Vector3(6,16,6)),"size":1.0,"material":"stone"},
	"wall_piece":{"label":"Wall Piece","short":"Wall","asset":MEADOW+"buildings/wall_section.glb","box":AABB(Vector3(-3,0,-3),Vector3(6,16,6)),"size":1.0,"material":"stone"},
	"wall_ruins":{"label":"Wall Ruins","short":"Rubble","asset":MEADOW+"buildings/wall_ruins.glb","box":AABB(Vector3(-4.443,0,-6.428),Vector3(7.698,4.384,10.439)),"size":1.0,"material":"stone"},
 "fence":{"label":"Timber Fence","short":"Fence","asset":CEDAR+"fence.glb","box":AABB(Vector3(-1.6,0,-.09),Vector3(3.2,1.6,.18)),"size":1.875,"material":"wood"},
 "boulder_pair":{"label":"Meadow Boulder Pair","short":"Pair","asset":MEADOW+"modular/boulder_pair.tscn","box":AABB(Vector3(-2.507321,0,-1.727563),Vector3(4.762747,1.32,3.252003)),"size":1.0,"material":"stone"},
 "river_cluster":{"label":"River Stone Cluster","short":"Stones","asset":MEADOW+"modular/river_cluster.tscn","box":AABB(Vector3(-2.240346,0,-.930839),Vector3(4.137549,1.3,2.232235)),"size":1.0,"material":"stone"},
 "fence_corner":{"label":"Timber Fence Corner","short":"Fence L","asset":MEADOW+"modular/fence_corner.tscn","box":AABB(Vector3(-3,0,-3),Vector3(6,3,6)),"size":1.0,"material":"wood"}
}
static func is_piece(kind:String)->bool:return kind in ["tree","rock"] or CATALOG.has(kind)
static func anchor(item:Dictionary):
	var height=float(item.get("height",0))
	return Vector2i(item.x,item.z) if is_zero_approx(height) else Vector3i(item.x,item.z,roundi(height*10000))
static func cell(anchor_)->Vector2i:return Vector2i(anchor_.x,anchor_.y)
static func is_tree(kind:String)->bool:return kind in ["tree","cedar","pine","sakura","bamboo"]
static func asset(kind:String)->String:return CATALOG[kind].asset if CATALOG.has(kind) else MEADOW+("broadleaf_tree" if kind=="tree" else "mossy_boulder")+".glb"
static func visual_scale(kind:String)->float:return CATALOG[kind].size if CATALOG.has(kind) else (2.0 if kind=="tree" else 1.0)
static func material(kind:String)->String:return CATALOG[kind].material if CATALOG.has(kind) else ("wood" if kind=="tree" else "stone")
static func wind(kind:String)->bool:return bool(CATALOG[kind].get("wind",false)) if CATALOG.has(kind) else kind=="tree"
const TREE=AABB(Vector3(-1.25,0,-1.25),Vector3(2.5,8,2.5))
# Fitted to the existing mossy_boulder.glb, including its off-center origin.
const ROCK=AABB(Vector3(-1.822,0,-1.847),Vector3(3.748,1.65,3.638))
static func bounds(kind:String,scale_:float,rotation:float=-1)->AABB:
	# Old maps retain their original fixed trunk collision until explicitly edited.
	if kind=="tree" and rotation<0:return TREE
	var box:AABB=CATALOG[kind].box if CATALOG.has(kind) else (TREE if kind=="tree" else ROCK)
	var factor=scale_*(visual_scale(kind) if CATALOG.has(kind) else 1.0)
	return Transform3D(Basis(Vector3.UP,deg_to_rad(maxf(0,rotation))).scaled(Vector3.ONE*factor),Vector3.ZERO)*box
static func footprint(cell:Vector2i,box:AABB)->Array:
	var result=[]
	# Quarter turns introduce tiny float errors at shared six-metre module edges.
	var first=Vector2i(floori((box.position.x+3+.0001)/6),floori((box.position.z+3+.0001)/6))
	var end=Vector2i(ceili((box.end.x+3-.0001)/6),ceili((box.end.z+3-.0001)/6))
	for x in range(first.x,end.x):
		for z in range(first.y,end.y):result.append(cell+Vector2i(x,z))
	return result

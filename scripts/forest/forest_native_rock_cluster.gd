extends RefCounted
## Native12115 has three overlapping rounded stones, not a single box or boulder.
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
static var result:Mesh

static func mesh(g:Dictionary)->Mesh:
 if result!=null:return result
 assert(g.rgba_sha256=="d434deb52f832df1a4ca6cf96ddd8bbfa3fe5b4dd14b077ee35919fef0eb031f","Recheck native12115 palette after source changes")
 var stage=Node3D.new()
 var stone=Forms.Fort.material(Color("777a79"),false)
 var parts:Array=Meadow.source("res://assets/models/environments/wind_meadow/mossy_boulder.glb")
 # Source confirms the tall rear stone, low left stone and smaller right stone.
 # Their hidden volume is inferred; all three reuse the same editable master.
 for rock in [[Vector3(-.23,0,-.38),Vector3(.45,.63,.43),.3],
              [Vector3(-.56,0,.06),Vector3(.43,.40,.42),1.2],
              [Vector3(.47,0,.32),Vector3(.38,.36,.35),2.1]]:
  var pose=Transform3D(Basis(Vector3.UP,rock[2]).scaled(rock[1]),rock[0])
  for part in parts:
   var node=MeshInstance3D.new();node.mesh=part.mesh;node.transform=pose*part.transform
   node.material_override=stone
   stage.add_child(node)
 result=Forms.append_fitted(null,stage,3.,3.,1.,Vector3.ZERO,g)
 result.set_meta("native_stone_count",3)
 return result

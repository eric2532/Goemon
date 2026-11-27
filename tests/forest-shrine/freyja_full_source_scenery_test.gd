extends SceneTree
## Staged scenery uses the existing owner; no terrain or source map is activated.
const Scenery=preload("res://scripts/forest/forest_venoa_southwest_scenery.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source scenery/"
class Terrain:
 const WATER_HEIGHT=preload("res://scripts/forest/forest_freyja_terrain.gd").WATER_HEIGHT
 func mask_bounds()->Rect2:return Rect2(-582,-480,1065,963)
class Model:
 var terrain=Terrain.new()
 func surface_height(x:float,z:float)->float:
  assert(terrain.mask_bounds().has_point(Vector2(x,z)),"Water props must never sample/invent out-of-owner terrain")
  return 6.
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FULL_FREYJA_SCENERY_FAIL "+label)
func read(path:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func snapshot(node:Node3D)->Dictionary:
 var result={}
 for part in node.find_children("*","MultiMeshInstance3D",true,false):
  var mm:MultiMesh=part.multimesh;var material:Material=part.material_override
  if material==null:material=mm.mesh.surface_get_material(0)
  var tint=material.get_shader_parameter("foliage_tint") if material is ShaderMaterial else null
  var cells=part.get_meta("venoa_southwest_cells",[part.get_meta("source_cell",[])])
  var serial=part.get_meta("venoa_southwest_serial",part.get_meta("source_serial",0))
  for i in cells.size():
   var key="%s:%s:%s"%[serial,cells[i],part.get_meta("crossgate_tree_part","detail")]
   result[key]=[str(mm.get_instance_transform(i)),mm.mesh.get_rid().get_id(),material.get_rid().get_id() if material!=null else 0,str(tint)]
 return result
func run():
 var model=Model.new();var legacy=read(OUT+"Before source/scenery.json")
 var parent=Node3D.new();root.add_child(parent)
 Scenery.data=legacy;Scenery.build(parent,model)
 var before=snapshot(parent)
 check(parent.get_child(0).get_meta("venoa_southwest_anchors").size()==80,"Original80 source anchors establish baseline")
 var report={"active":false,"cases":[],"qualification":"Pure owner/geometry/source preservation; current-source field support and fixed gameplay-camera review remain separate."}
 for mode in ["Prepared preview","Prepared","Prepared"]:
  var candidate=read(OUT+mode+"/scenery.json")
  check(candidate.placements.slice(0,80)==legacy.placements and candidate.offshore_placements.slice(0,5)==legacy.offshore_placements,"Both original station prefixes remain exact")
  var view=Node3D.new();root.add_child(view);Scenery.data=candidate;Scenery.build(view,model)
  var actual=snapshot(view)
  check(before.keys().all(func(key):return actual.has(key) and actual[key]==before[key]),"Original source instances retain exact mesh/material/tint/transforms")
  var built=view.get_child(0);var water=built.find_child("OriginalWaterFlowers",false,false)
  check(built.get_meta("venoa_southwest_anchors").size()==132,"Every staged headland station is instantiated")
  check(water.get_meta("source_anchors").size()==candidate.offshore_placements.size(),"Every source-water prop is instantiated")
  check(view.find_children("*","CollisionObject3D",true,false).is_empty(),"Scenery meshes add no independent terrain/physics owner")
  var boxes=Scenery.tree_blocks(model)
  check(boxes.size()==27 and boxes.all(func(row):return row[2].size.x<=3 and row[2].size.z<=3),"Only27 land-tree trunks reuse bounded source-cell obstacles")
  check(boxes.all(func(row):return candidate.placements.any(func(p):return p.family=="tree" and p.cell==row[3] and not p.native_open)),"Water props never become native obstacles or land")
  check(actual.values().all(func(row):return not row[0].contains("nan") and not row[0].contains("inf")),"All reused/fitted geometry has finite transforms")
  report.cases.append({"mode":mode,"land_anchors":132,"water_anchors":candidate.offshore_placements.size(),"meshes":Scenery.meshes.size(),"owned_tree_materials":Scenery.tree_materials.size(),"instances":actual.size()})
  view.queue_free();await process_frame
 check(report.cases[1].meshes==report.cases[2].meshes and report.cases[1].owned_tree_materials==report.cases[2].owned_tree_materials,"Repeated full selection reuses owned mesh/material caches")
 for path in legacy.reused_source_sha256:
  check(FileAccess.get_sha256("res://"+path)==legacy.reused_source_sha256[path],"Protected original source remains exact: "+path)
 Scenery.data=legacy;parent.queue_free();await process_frame
 report.checks=checks;report.failures=failures
 var file=FileAccess.open(OUT+"owner-preservation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("FULL_FREYJA_SCENERY_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

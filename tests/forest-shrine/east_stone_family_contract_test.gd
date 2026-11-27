extends SceneTree
## Private source-family candidates only; no map/terrain/quest enrollment or native bank setup.
const Stone=preload("res://scripts/forest/forest_east_stone_families.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Stone Family Candidate/"
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check_(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 var data:Dictionary=Stone.data(FOLDER);var counts={};var missing_support=[];var generated=0
 for token in data.graphics:
  var id=int(token);var spec:Dictionary=data.graphics[token];var kind:String=spec.kind
  counts[kind]=int(counts.get(kind,0))+1
  var mesh:Mesh=Stone.mesh(id,{},FOLDER)
  check_(mesh!=null and mesh.get_surface_count()>0,"Source candidate mesh "+token)
  check_(mesh.get_meta("east_source_footprint")==spec.source_graphic.footprint,"Original source footprint metadata "+token)
  check_(mesh.get_meta("east_source_kind")==kind,"Separate source wall/cap/rock frame "+token)
  if kind=="sealed_carved_door_crag":check_(mesh.get_meta("east_sealed_source_tablet",false) and mesh.get_meta("east_source_gate","").contains("1102513"),"Closed carved tablet retains the original guardian/victory gate, with no free doorway")
  if kind=="sparse_cave_cap_or_edge":
   if not spec.has("inferred_support_graphic"):missing_support.append(id)
   check_(mesh.get_meta("east_native_cap_height",0.)>0.,"Native cap retains original elevated plane "+token)
  generated+=1
  if generated%40==0:await process_frame
 var report={"checks":checks,"failures":failures,"generated_candidates":generated,"source_families":counts,"caps_without_compatible_support":missing_support,"scope":"Private source/profile/material candidates only. No map enrollment or visual acceptance. Sealed tablet1260054 reuses its crag and preserves the original guard gate; typed lower banks are separate."}
 var file=FileAccess.open(FOLDER+"contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EAST_STONE_FAMILY_CONTRACTS checks=",checks," failures=",failures.size()," candidates=",generated," caps_without_support=",missing_support.size())
 quit(1 if not failures.is_empty() else 0)

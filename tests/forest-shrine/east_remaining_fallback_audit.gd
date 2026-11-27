extends SceneTree
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/"
var dispatch:Dictionary
func runtime_owner(serial:int,context:Dictionary)->String:
 if context.get("legacy_owner",false):return ""
 if not context.get("generated_dependency",false) and not int(context.get("map",-1)) in Maps.EastIndex.FIXED:return ""
 var profile_checked=false
 for group in dispatch.groups:
  if not profile_checked and group.order>dispatch.profile_dispatch_line:
   profile_checked=true
   if East.owns(0,serial):return "existing-east-profile"
  if not serial in group.ids or group.conservative_unresolved_context:continue
  if context.get("generated_dependency",false):
   if group.fixed_only or not group.maps.is_empty():continue
  elif not group.maps.is_empty() and not int(context.get("map",-1)) in group.maps:continue
  return "OriginalMaps-group"+str(int(group.group))
 if not profile_checked and East.owns(0,serial):return "existing-east-profile"
 return ""
func _initialize():call_deferred("run")
func run():
 East.Art.load_east();var profile_hash=FileAccess.get_sha256(East.ROOT+"profiles.json")
 var probe=load(ROOT+"forms_probe.gd");var contexts=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"object-contexts.json"))
 dispatch=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"committed-dispatch.json"))
 for group:Dictionary in dispatch.groups:
  group.ids=group.ids.map(func(value):return int(value));group.maps=group.maps.map(func(value):return int(value))
 var rows=[];var existing=[];var delegated=[];var legacy_contexts=[];var families={};var errors=[];var markers=0;var ground_only=0;var legacy_only=0
 for test in[[1235141,{"map":43757},"OriginalMaps-group7"],[1233256,{"map":43000},"OriginalMaps-group8"],[1233255,{"map":43000},"OriginalMaps-group19"],[1233255,{"map":34000},"existing-east-profile"],[1230127,{"map":33608},"OriginalMaps-group23"],[1230128,{"map":33608},""],[1230127,{"generated_dependency":true},""],[1233256,{"map":2000,"legacy_owner":true},""]]:
  if runtime_owner(test[0],test[1])!=test[2]:errors.append("Dispatch scope self-check failed "+str(test))
 for name in dispatch.source_hashes:
  if FileAccess.get_sha256("res://"+name)!=dispatch.source_hashes[name]:errors.append("Stale committed dispatch: "+name)
 if FileAccess.get_sha256(ROOT+"forms_probe.gd")!=dispatch.probe_sha256:errors.append("Stale final-box instrumented probe")
 if not errors.is_empty():
  for error in errors:push_error(error)
  quit(1);return
 for token in contexts.graphics:
  var serial=int(token)
  if serial<1000:markers+=1;continue
  if contexts.graphics[token].get("generated_ground_only",false):ground_only+=1;continue
  if not East.Art.data().graphics.has(token):errors.append("Missing native dependency "+token);continue
  var g:Dictionary=East.Art.data().graphics[token];var family=Forms.kind(serial,false,g)
  if serial in [11108,11112,11126,11271,12155] and contexts.graphics[token].contexts.all(func(item):return item.get("legacy_owner",false)):
   legacy_only+=1;continue # Explicit current Il/Alyut props/village-building mesh owners verified by source audit.
  var remaining=[];var owners=[]
  for context:Dictionary in contexts.graphics[token].contexts:
   if context.get("legacy_owner",false):
    legacy_contexts.append({"graphic":serial,"context":context,"scope":"Separate legacy scenery owner; not the OriginalMaps final-box path. Requires its own visual/source audit."});continue
   var owner=runtime_owner(serial,context)
   if owner.is_empty():remaining.append(context)
   else:owners.append({"context":context,"runtime_owner":owner})
  if not owners.is_empty():delegated.append({"graphic":serial,"resolved_runtime_contexts":owners,"remaining_contexts":remaining,"visual_acceptance":false})
  if remaining.is_empty():continue
  families[family]=int(families.get(family,0))+1
  if family!="prop":continue
  var mesh:Mesh=probe.mesh(serial,family,g,East.texture(g),false,Forms.east_fallback_owned(serial) or East.minor_prop_allowed(serial,g))
  var row:Dictionary=contexts.graphics[token].duplicate(true)
  row.contexts=remaining;row.resolved_runtime_contexts=owners
  row["pixels"]=[g.rect[2],g.rect[3]];row["footprint"]=g.footprint;row["native_family"]=g.family;row["source_height"]=Forms.source_height(g)
  row["only_legacy_contexts"]=row.contexts.all(func(item):return item.get("legacy_owner",false))
  if mesh.has_meta("east_unmeasured_final_box"):rows.append(row)
  else:existing.append(row)
 var f=FileAccess.open(ROOT+"final-boxes.json",FileAccess.WRITE)
 for name in dispatch.source_hashes:
  if FileAccess.get_sha256("res://"+name)!=dispatch.source_hashes[name]:errors.append("Dispatch changed during audit: "+name)
 f.store_string(JSON.stringify({"fixed_maps":contexts.fixed_maps,"profile_snapshot_sha256":profile_hash,"production_forms_sha256":FileAccess.get_sha256("res://scripts/forest/forest_original_map_solids.gd"),"dispatch_source_hashes":dispatch.source_hashes,"source_hashes":dispatch.source_hashes,"dispatch_scope_self_checks":8,"final_box_graphics":rows,"existing_prop_delegates":existing,"runtime_dispatch_delegates":delegated,"legacy_contexts_requiring_separate_audit":legacy_contexts,"other_existing_families":families,"source_markers":markers,"generated_ground_only_excluded":ground_only,"verified_legacy_only_excluded":legacy_only,"failures":errors,"scope":"Current production final-box branch instrumented in excluded copy. Actual committed groups6–23resolved per fixed/generated context, with exact scoped-map conditions and conservative tree exclusions. Legacy contexts use separate scenery owners and remain explicitly listed for separate audit. This counts remaining generic boxes, not unaccepted geometry or visual completion. Private unhooked helpers never exclude a gap."},"  "));f.close()
 print("EAST_REMAINING_FALLBACK_AUDIT final_boxes=",rows.size()," exact_prop_delegates=",existing.size()," errors=",errors.size())
 for error in errors:push_error(error)
 quit(0 if errors.is_empty() else 1)

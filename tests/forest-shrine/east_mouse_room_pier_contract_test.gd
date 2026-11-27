extends SceneTree
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Piers=preload("res://scripts/forest/forest_east_mouse_room_piers.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Publication/"
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():run.call_deferred()
func run():
 var hashes=Sources.snapshot([get_script().resource_path,"scripts/forest/forest_original_maps.gd","scripts/forest/forest_original_map_solids.gd","scripts/forest/forest_east_mouse_room_piers.gd",Piers.ROOT+"data.json","assets/textures/edo/rock.png","assets/maps/original_crossgate/east/catalog.json","assets/maps/falan/east_region/routes.json","assets/maps/falan/east_region/population.json"])
 Maps.Art.load_east();var id=Maps.runtime_id(33608);var row:Dictionary=Maps.state(id);var raw=row.raw.duplicate();var bits=row.bits.duplicate();var links=JSON.stringify(Maps.links(id))
 var scene=Node3D.new();root.add_child(scene);var barriers=Maps.build(scene,id)
 var count_=0;var other_counts={};var expected_others={};var cells:int=row.size.x*row.size.y
 var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(id)].get("graphic_aliases",{})
 for index in cells:
  var native=row.raw.decode_u16(20+(cells+index)*2);var serial=int(aliases.get(str(native),native))
  if str(serial)in Piers.data().graphics and serial!=1230127:expected_others[str(serial)]=int(expected_others.get(str(serial),0))+1
 for batch:MultiMeshInstance3D in scene.find_children("*","MultiMeshInstance3D",true,false):
  var serial=int(batch.get_meta("source_graphic",-1))
  if serial==1230127:
   count_+=batch.multimesh.instance_count
   check(batch.multimesh.mesh==Piers.mesh(serial,Maps.Art.data().graphics[str(serial)]),"Canonical group23uses immutable reviewed mesh")
  elif str(serial)in Piers.data().graphics:other_counts[str(serial)]=int(other_counts.get(str(serial),0))+batch.multimesh.instance_count
 check(count_==625,"All625original source placements retained")
 check(other_counts==expected_others and other_counts.size()==10,"All other10source forms retain original owners/placement counts")
 var original=Node3D.new();root.add_child(original);var expected=Maps.boundaries(original,row.bits,row.size,row.origin,row.raw)
 check(barriers==expected,"Complete source player/native collision barriers remain exact")
 check(row.raw==raw and row.bits==bits and JSON.stringify(Maps.links(id))==links,"Original planes, walking and connections unchanged")
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Canonical sources remain current")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));var file=FileAccess.open(OUT+"contract.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":hashes,"source_changed_during_run":changed,"canonical_placements":count_,"other_original_forms":other_counts,"scope":"Exact canonical33608mesh ownership/counts and original full player/native barrier arrays. Other10forms retain owners; their visual quality is unfinished. Paired actual camera review separate."},"  "));file.close()
 print("EAST_MOUSE_PIER_CONTRACT checks=",checks," failures=",failures);scene.queue_free();original.queue_free();await process_frame;quit(failures)

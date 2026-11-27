extends SceneTree
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Props=preload("res://scripts/forest/forest_east_prop_camera.gd")
const Camera=preload("res://scripts/forest/forest_original_water_camera.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():run.call_deferred()
func run():
 var hashes=Sources.snapshot([get_script().resource_path,"scripts/forest/forest_original_maps.gd","scripts/forest/forest_east_prop_camera.gd","scripts/forest/forest_original_water_camera.gd","scripts/forest/forest_art.gd","assets/maps/original_crossgate/east/catalog.json"])
 var id=31900;var row:Dictionary=Maps.state(id);var raw=row.raw.duplicate();var bits=row.bits.duplicate();var links=JSON.stringify(Maps.links(id))
 var scene=Node3D.new();root.add_child(scene);var barriers=Maps.build(scene,id)
 check(scene.has_meta(Props.APPLIED),"Live31900builder installs only the measured low-prop refinement")
 if not scene.has_meta(Props.APPLIED):printerr(scene.get_meta("source_low_prop_camera_blocker","missing owner"));quit(1);return
 var data:Dictionary=scene.get_meta(Props.APPLIED)
 check(data.original_barrier.position.is_equal_approx(data.full_player_collision_union.position) and data.original_barrier.size.is_equal_approx(data.full_player_collision_union.size),"Complete player barrier union retains original extent")
 check(barriers[59]==data.original_barrier,"Native receives its unchanged original full-height obstacle")
 check(data.visible_height>0. and data.split<8.5,"Camera split follows actual visible furniture height")
 var low=scene.find_child("RecoveredShalenaBoundary_59",true,false) as CollisionObject3D
 var high=scene.find_child("SourceLowPropUpperBarrier",true,false) as CollisionObject3D
 check(low!=null and high!=null and low.collision_layer==1 and high.collision_layer==1,"Both original player barrier portions retain collision layer1")
 check(not high.get_meta(Camera.WATER_BOUNDARY,false),"Furniture camera metadata never claims a source water boundary")
 var before=scene.get_child_count();check(Props.apply(scene,id,row) and scene.get_child_count()==before,"Setup is idempotent without extra bodies")
 var camera=Camera.new();check(camera.sync(scene),"Existing camera owner initializes this map cache")
 check(data.upper_camera_rid in camera.probe.exclude and data.lower_player_rid not in camera.probe.exclude,"Only upper invisible navigation portion is excluded from camera")
 check(not camera.sync(scene),"Unchanged map camera cache does no repeated setup")
 for frame in 3:await physics_frame
 var at=Maps.point(id,Vector2i(24,4));var from_=Maps.point(id,Vector2i(23,4));var state=scene.get_world_3d().direct_space_state
 for height_ in[1.,float(data.split)+.4]:
  var query=PhysicsRayQueryParameters3D.create(Vector3(from_.x,height_,from_.y),Vector3(at.x,height_,at.y),1)
  check(not state.intersect_ray(query).is_empty(),"Full player collision stays closed at height "+str(height_))
  query.exclude=camera.probe.exclude
  var hit=state.intersect_ray(query)
  check(hit.is_empty() if height_>data.split else not hit.is_empty(),"Camera still respects actual furniture, with no invisible extension "+str(height_))
 check(row.raw==raw and row.bits==bits and JSON.stringify(Maps.links(id))==links,"Original map planes, walking and quest connections remain unchanged")
 var other=Node3D.new();root.add_child(other)
 check(not Props.apply(other,31901,row) and other.get_child_count()==0,"Other source maps receive no refinement")
 var changed_row=row.duplicate(true);changed_row.bits=row.bits.duplicate();var index=4*row.size.x+24;changed_row.bits[index>>3]|=1<<(index&7)
 check(not Props.apply(other,id,changed_row) and other.get_child_count()==0,"Changed source walk contract cannot activate the refinement")
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded camera refinement sources remain current")
 var path="res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/Low Prop Camera/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
 var file=FileAccess.open(path+"contract.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":hashes,"source_changed_during_run":changed,"visible_height":data.visible_height,"camera_split":data.split,"scope":"Source31900only. Complete original player/native barrier, exact source walking/links, camera lower-prop occlusion, upper-only exclusion and setup cache proved. No actual gameplay view approval."},"  "));file.close()
 print("EAST_PROP_CAMERA_CONTRACT checks=",checks," failures=",failures);scene.queue_free();other.queue_free();await process_frame;quit(failures)

extends "res://tests/forest-shrine/east_region_review.gd"
## Direct source spawns, two walkable gameplay viewpoints, and a calibrated native-axis overview.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Landmarks=preload("res://scripts/forest/forest_east_region_art.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
const ART_REVIEW="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Rendered/"
const SITES=[
 [33200,1230062,Vector2i(116,136),"akelufa-living-house"],
 [33200,1230040,Vector2i(178,100),"akelufa-tree-shrine"],
 [43100,1233000,Vector2i(129,47),"goral-curved-house"],
 [43100,1233020,Vector2i(167,219),"goral-palace"],
 [43100,1233018,Vector2i(61,106),"goral-open-gate"],
 [40000,1238094,Vector2i(49,48),"harbor-boarding-stair"],
 [41000,1230059,Vector2i(46,22),"ship-mast"],
]
var metrics=[]
var camera_component:Dictionary={}
var camera_component_map=-1
var camera_canopies:Array[AABB]=[]
func sites()->Array:return SITES
func review_path()->String:return ART_REVIEW
func ordinary_pitch()->float:return .32
func site_owned(source:int,serial:int)->bool:return Landmarks.owns(source,serial)
func site_mesh(source:int,serial:int,g:Dictionary)->Mesh:return Landmarks.mesh(source,serial,g)
func site_visible(serial:int,g:Dictionary)->Array:return Landmarks.data().graphics.get(str(serial),{}).get("visible",[0,0,g.rect[2],g.rect[3]])
func native_pixel_height(serial:int)->float:return float(Landmarks.data().graphics.get(str(serial),{}).get("profile",{}).get("pixel_height",.045))
func review_source_paths()->Array:
 return [get_script().resource_path,"tests/forest-shrine/east_landmark_review.gd","scripts/forest/forest_original_maps.gd","scripts/forest/forest_original_map_solids.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_east_tree_families.gd","scripts/forest/forest_east_ruin_sections.gd","scripts/forest/forest_east_room_columns.gd","scripts/forest/forest_east_lektal_annexes.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/falan/east_region/landmarks/profiles.json","assets/maps/original_crossgate/east/catalog.json"]

func run():
 var source_hashes=Sources.snapshot(review_source_paths())
 root.size=Vector2i(1440,900);root.title="Cross Gate · East Landmark Review"
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-landmarks-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review_path()))
 for site_row in sites():await landmark(site_row)
 var changed=Sources.changed(source_hashes)
 check(changed.is_empty(),"Loaded review sources remain current through the capture")
 var file=FileAccess.open(review_path()+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"metrics":metrics,"source_hashes":source_hashes,"source_changed_during_run":changed,"profiles_sha256":source_hashes["assets/maps/falan/east_region/landmarks/profiles.json"],"module_sha256":source_hashes["scripts/forest/forest_east_region_art.gd"],"scope":"Native source landmarks; gameplay viewpoints chosen on original walk mask. Captures require separate visual judgment. Short frame samples include active world/rendering and are not a full-army or long-session claim."},"  "));file.close()
 print("EAST_LANDMARK_REVIEW_RESULT checks=",checks," failures=",errors," captures=",captures.size())
 await finish()

func walk_cell(id:int,wanted:Vector2i)->Vector2i:
 var state:Dictionary=Maps.state(id)
 var links:Array=Maps.links(id)
 var region=load("res://scripts/forest/forest_east_region.gd")
 var source=Maps.source_id(id)
 var triggers:Array=region.data().automatic.filter(func(actor):return int(actor.source)==source and actor.has("bounds"))
 for radius in 12:
  for dz in range(-radius,radius+1):
   for dx in range(-radius,radius+1):
    var cell=wanted+Vector2i(dx,dz)
    if not Maps.open(state.bits,state.size,cell):continue
    if camera_component_map==id and not camera_component.has(cell):continue
    var at=Maps.point(id,cell)
    if links.any(func(link):return at.distance_squared_to(link.at)<20.25):continue
    if triggers.any(func(actor):
     var b:Array=actor.bounds
     return Rect2i(b[0],b[1],b[2]-b[0]+1,b[3]-b[1]+1).grow(1).has_point(cell)):
     continue
    return cell
 return Maps.safe_cell(id,wanted)

func use_camera_component(id:int,start:Vector2i):
 camera_component_map=id;camera_component={start:true}
 var state:Dictionary=Maps.state(id);var queue=[start];var index=0
 while index<queue.size():
  var at:Vector2i=queue[index];index+=1
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next:Vector2i=at+direction
   if camera_component.has(next) or not Maps.open(state.bits,state.size,next):continue
   camera_component[next]=true;queue.append(next)

func collect_camera_canopies(target_serial:int):
 camera_canopies.clear()
 for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
  var serial=int(node.get_meta("source_graphic",-1))
  if serial==target_serial:continue
  var kind:String=Landmarks.data().graphics.get(str(serial),{}).get("kind","")
  var nature_kind:String=node.multimesh.mesh.get_meta("east_nature_kind","")
  if node.get_meta("crossgate_tree_part","")!="Canopy" and not node.get_meta("wind_meadow_canopy",false) and not node.multimesh.mesh.get_meta("east_native_tree_fit",false) and kind not in ["tree","seasonal_tree","native_canopy_tree","native_foliage"] and nature_kind not in ["source_canopy_tree","seasonal_tree","basin_tree"]:continue
  var mesh_bounds:AABB=node.multimesh.mesh.get_aabb()
  for index in node.multimesh.instance_count:
   camera_canopies.append((node.global_transform*node.multimesh.get_instance_transform(index))*mesh_bounds)

func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 # Room fixtures need source-valid nearby stands as well as broad outdoor
 # offsets. Jumping directly8tiles misses most of a small room's usable floor.
 var choices=[Vector2i.ZERO,Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2),Vector2i(-2,2),Vector2i(2,-2),Vector2i(-4,0),Vector2i(4,0),Vector2i(0,-4),Vector2i(0,4),Vector2i(-4,4),Vector2i(4,-4),Vector2i(-8,0),Vector2i(0,8),Vector2i(8,0),Vector2i(0,-8),Vector2i(-8,8),Vector2i(8,8),Vector2i(-12,-4),Vector2i(12,4),Vector2i(-24,0),Vector2i(0,24),Vector2i(24,0),Vector2i(0,-24)]
 var result={};var best=-INF
 var attempts=[]
 for shift in choices:
  for candidate_pitch in ([.14,.65,1.1] if second else [ordinary_pitch()]):attempts.append([shift,candidate_pitch])
 for attempt in attempts:
  var shift:Vector2i=attempt[0];var candidate_pitch:float=attempt[1]
  var stand=walk_cell(id,wanted+shift);var at=Maps.point(id,stand);await position_at(at)
  if game.model.falan_floor!=id:
   check(false,"Camera candidate unexpectedly changed source map "+str(Maps.source_id(id)))
   Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,walk_cell(id,wanted)),"yaw":0.,"velocity":Vector3.ZERO})
   for i in 4:await physics_frame
   continue
  if not camera_component.has(stand) or not game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55):continue
  var toward=(center-at).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y);game.camera_rig.pitch=candidate_pitch;game.camera_rig.reset_follow()
  for i in 18:await physics_frame;game.camera_rig.update_camera(1./60.)
  var camera:Camera3D=game.camera_rig.camera;var target=game.model.world_point(center,height)
  if target_bounds.grow(.35).has_point(camera.global_position):continue
  if camera_canopies.any(func(box:AABB):return box.grow(2.5).has_point(camera.global_position)):continue
  if second:camera.look_at(target);camera.reset_physics_interpolation()
  var ray=PhysicsRayQueryParameters3D.create(camera.global_position,target,1);ray.exclude=game.camera_rig.water_camera.probe.exclude
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
  var clear=hit.is_empty() or target_bounds.grow(.25).has_point(hit.position)
  clear=clear and not camera_canopies.any(func(box:AABB):return box.intersects_segment(camera.global_position,target))
  var desired_distance=game.camera_rig.unobstructed_distance
  var distance_ok=game.camera_rig.current_distance>desired_distance*.8
  var score=game.camera_rig.current_distance+(20. if clear else 0.)+(10. if camera.is_position_in_frustum(target) else 0.)
  if score>best:
   best=score;result={"cell":stand,"at":at,"pitch":candidate_pitch,"clear":clear,"framed":camera.is_position_in_frustum(target),"distance_ok":distance_ok,"desired_camera_distance":desired_distance,"ray_hit":{} if hit.is_empty() else {"position":var_to_str(hit.position),"collider":str(hit.collider.get_path())},"target_bounds":var_to_str(target_bounds)}
  if clear and camera.is_position_in_frustum(target) and distance_ok:return result
 if result.is_empty():return {}
 var stand:Vector2i=result.cell;var at:Vector2=result.at;await position_at(at)
 var toward=(center-at).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y);game.camera_rig.pitch=result.pitch;game.camera_rig.reset_follow()
 for i in 18:await physics_frame;game.camera_rig.update_camera(1./60.)
 if second:game.camera_rig.camera.look_at(game.model.world_point(center,height));game.camera_rig.camera.reset_physics_interpolation()
 return result

func landmark(site_row:Array):
 var source=int(site_row[0]);var serial=int(site_row[1]);var cell:Vector2i=site_row[2];var label:String=site_row[3];var id=Maps.runtime_id(source)
 camera_component_map=-1;camera_component.clear()
 var initial=walk_cell(id,site_row[4] if site_row.size()>5 else cell+Vector2i(-15,15));var arrival=Maps.point(id,initial)
 use_camera_component(id,initial)
 var reused=game.model.falan_floor==id;var begin=Time.get_ticks_usec()
 if not reused:Tour.travel(game,Tour.Indoor.layout(id),{"arrival":arrival,"yaw":-PI*.25,"velocity":Vector3.ZERO})
 else:await position_at(arrival)
 var build_ms=float(Time.get_ticks_usec()-begin)/1000.
 for i in 30:await process_frame
 var frames=[]
 for i in 120:
  var before=Time.get_ticks_usec();await process_frame;frames.append(float(Time.get_ticks_usec()-before)/1000.)
 frames.sort()
 var metric={"source":source,"landmark":label,"reused_map":reused,"setup_ms":build_ms,"frame_sample_count":frames.size(),"frame_median_ms":frames[60],"frame_p95_ms":frames[114],"frame_max_ms":frames[-1],"video_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),"nodes":get_node_count()}
 metrics.append(metric);print("EAST_LANDMARK_METRIC ",JSON.stringify(metric))
 collect_camera_canopies(serial)
 check(game.model.falan_floor==id,"Direct spawn retains source map "+str(source))
 check(site_owned(source,serial),"Measured landmark owner "+label)
 var graphic:Dictionary=Maps.Art.data().graphics[str(serial)];var bounds: AABB=site_mesh(source,serial,graphic).get_aabb();var anchor=Maps.point(id,cell);var center=anchor+Vector2(bounds.get_center().x,bounds.get_center().z)
 var world_bounds=AABB(game.model.world_point(anchor)+bounds.position*game.model.falan_scale,bounds.size*game.model.falan_scale)
 for angle in 2:
  var wanted=site_row[4+angle] if site_row.size()>5 else cell+Vector2i(-15,15) if angle==0 else cell+Vector2i(int(graphic.footprint[0])+13,13)
  var view:Dictionary=await camera_view(id,wanted,center,(bounds.position.y+bounds.size.y*(.65 if angle==1 else .5))*game.model.falan_scale,angle==1,world_bounds)
  check(not view.is_empty(),"Found an intended-map camera candidate "+label+" "+str(angle))
  if view.is_empty():return
  var stand:Vector2i=view.cell;var at:Vector2=view.at
  check(game.model.falan_floor==id,"Camera retains intended source map "+label+" "+str(angle))
  check(game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55),"Reachable gameplay camera "+label+" "+str(angle))
  check(camera_component.has(stand),"Second view shares the original walk component "+label+" "+str(angle))
  check(view.clear and view.framed,"Landmark camera has a clear framed sightline "+label+" "+str(angle))
  check(view.distance_ok,"Landmark camera retains at least80percent of ordinary distance "+label+" "+str(angle))
  observations.append({"viewpoint":label,"angle":angle,"source_cell":[stand.x,stand.y],"source_walk_component_cells":camera_component.size(),"physics_sightline_clear":view.clear,"landmark_midpoint_in_frustum":view.framed,"normal_camera_distance":game.camera_rig.current_distance,"desired_camera_distance":view.desired_camera_distance,"camera_distance_ok":view.distance_ok,"orbit_pitch":game.camera_rig.pitch,"canopy_bounds_count":camera_canopies.size(),"ray_hit":view.ray_hit,"target_bounds":view.target_bounds})
  await capture(label+("-normal" if angle==0 else "-second"),source,stand,"normal gameplay camera at walkable original source cell" if angle==0 else "same reachable gameplay eye, aimed toward the upper landmark to inspect reverse faces")
 await capture_native_axis(site_row,initial)

func capture_native_axis(site_row:Array,initial:Vector2i):
 var source=int(site_row[0]);var serial=int(site_row[1]);var cell:Vector2i=site_row[2];var label:String=site_row[3];var id=Maps.runtime_id(source)
 var graphic:Dictionary=Maps.Art.data().graphics[str(serial)]
 var visible:Array=site_visible(serial,graphic);var native=(Vector2(visible[0],visible[1])+Vector2(visible[2],visible[3]))*.5+Vector2(graphic.origin[0],graphic.origin[1]);var target=Maps.point(id,cell)+Vector2(native.x*3./64.-native.y/16.,native.x*3./64.+native.y/16.)
 var camera:Camera3D=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 var pixel_height=native_pixel_height(serial)
 camera.size=float(visible[3]-visible[1])/sqrt(128.+1./pow(pixel_height,2))*game.model.falan_scale*1.18
 var center3=game.model.world_point(target);var ray=Vector3(-1./16.,pixel_height,1./16.).normalized()
 camera.global_position=center3+ray*maxf(120.,camera.size*4.);camera.look_at(center3);camera.reset_physics_interpolation()
 var ceiling=game.world.map_features.find_child("SolidCaveCeiling",true,false) as Node3D
 var ceiling_visible=ceiling.visible if ceiling!=null else false
 if ceiling!=null:ceiling.visible=false
 await capture(label+"-native-axis",source,initial,"fixed physical owner-axis diagnostic; synthetic room ceiling hidden only for this capture" if ceiling!=null else "fixed physical owner-axis diagnostic; vertical gameplay compression changes source pixel aspect, not an exact pixel overlay")
 if ceiling!=null:
  ceiling.visible=ceiling_visible
  check(ceiling.visible==ceiling_visible,"Diagnostic restores original room ceiling visibility "+label)
  observations.append({"native_axis_cutaway":label,"only_synthetic_room_ceiling_hidden":true,"ceiling_visibility_restored":true,"gameplay_view":false})
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE

func capture(label:String,source:int,stand:Vector2i,method:String):
 if DisplayServer.get_name()=="headless":return
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting();game.ui.hide();game.set_process(false);root.grab_focus()
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(review_path()+label+".png")==OK,"Rendered "+label)
 captures.append({"name":label,"source":source,"cell":[stand.x,stand.y],"method":method,"camera":var_to_str(game.camera_rig.camera.global_transform),"projection":game.camera_rig.camera.projection})
 game.set_process(true);game.ui.show();print("EAST_LANDMARK_CAPTURE ",label)

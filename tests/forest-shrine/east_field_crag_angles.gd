extends "res://tests/forest-shrine/east_field_cliffs_review.gd"
## Tight original-field views of the repaired536,218crag cluster, not the distant Earth Cave road.
const Metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
var cliff_performance=[]
func run():
 root.size=Vector2i(1440,900);phase="FieldCrag"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-field-crag-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("east_gate")
 await field_view("east-crag-normal",Vector2(542,220),Vector2(536,218))
 await field_view("east-crag-second",Vector2(538,222),Vector2(536,218))
 await field_view("east-crag-source-face",Vector2(530,222),Vector2(536,218))
 check(not game.world.find_children("EastNativeCliff_*","MultiMeshInstance3D",true,false).is_empty(),"The original East field native crag owner is mounted")
 var substrate_cells=0;var valid=true
 for node in game.world.find_children("EastNativeCliffSubstrate_*","MeshInstance3D",true,false):
  for cell:Vector2i in node.get_meta("source_blocked_nonwater_cells",[]):
   substrate_cells+=1
   if not FieldCliffs.field_bit("blocked_land",cell) or not FieldCliffs.field_bit("land",cell) or FieldCliffs.field_bit("walk",cell):valid=false
 check(valid and substrate_cells>0,"Closed field substrates cover only source-confirmed blocked non-water cliff footprint cells")
 var extra_cells=0;var extension_ok=true
 for node in game.world.find_children("*","Node3D",true,false):
  if not node.has_meta("east_cliff_original_footprint"):continue
  var footprint={}
  for cell:Vector2i in node.get_meta("east_cliff_original_footprint",[]):footprint[cell]=true
  var area:String=node.get_meta("east_cliff_substrate_area")
  for cell:Vector2i in node.get_meta("east_cliff_inferred_substrate_cells",[]):
   var adjacent=false;extra_cells+=1
   for z in range(-1,2):
    for x in range(-1,2):
     if footprint.has(cell+Vector2i(x,z)):adjacent=true
   if not adjacent or not FieldCliffs.owned_field_cell(area,cell) or FieldCliffs.field_portal(cell) or not FieldCliffs.field_bit("hidden_land",cell):extension_ok=false
 check(extension_ok and extra_cells>0,"Inferred hidden substrate extends at most one native tile onto blocked ground100inside the same owned window, preserving real water, source0and portals")
 var out=FileAccess.open(PROP_OUT+"Cliff Audit/field-angle-review.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"substrate_cells":substrate_cells,"inferred_one_tile_cells":extra_cells,"source_field_bits":FieldCliffs.data().field.sha256,"source_field_sha256":FieldCliffs.data().field.source_sha256,"relief_data_sha256":FileAccess.get_sha256(FieldCliffs.StoneRelief.ROOT+"data.json"),"source_basis":var_to_str(FieldCliffs.source_basis("east_gate")),"source_target":{"map":100,"center":[536,218],"graphic":12538,"original_footprint":[3,3]},"scope":"Normal gameplay and second source-open field angle of the recovered native crag cluster; closed non-water cliff substrate and bounded one-tile hidden ground100extension without terrain/navigation mutation."},"  "));out.close()
 print("EAST_FIELD_CRAG_ANGLES_RESULT checks=",checks," failures=",errors," captures=",captures.size());await finish()

func gameplay_capture(label:String,method:String,yaw:float):
 await super.gameplay_capture(label,method,yaw)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 for i in 30:await process_frame
 var wall=[];var cpu=[];var render_cpu=[];var render_gpu=[];var primitives=[];var draws=[];var focused=0;var previous=Time.get_ticks_usec()
 for i in 90:
  await process_frame
  var now=Time.get_ticks_usec();wall.append((now-previous)*.001);previous=now
  cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
  render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
  render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
  primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  if DisplayServer.window_is_focused():focused+=1
 var camera:Camera3D=game.camera_rig.camera;var families={};var owners={};var chunk_candidates=0;var instance_candidates=0;var mounted=0
 for node:MultiMeshInstance3D in game.world.find_children("EastNativeCliff_*","MultiMeshInstance3D",true,false):
  var id=int(node.get_meta("source_graphic",0));var key=str(id)
  if not families.has(key):families[key]={"mounted_instances":0,"frustum_instances":0,"frustum_chunk_submitted_instances":0,"chunks":0,"source_buffer_payload_bytes":mesh_payload(node.multimesh.mesh)}
  var count_=node.multimesh.instance_count if node.multimesh.visible_instance_count<0 else node.multimesh.visible_instance_count
  var owner=String(node.get_meta("east_cliff_area","unknown"));var source_map=int(node.get_meta("east_cliff_source_map",0))
  if not owners.has(owner):owners[owner]={"source_map":source_map,"mounted_instances":0,"anchors":[]}
  owners[owner].mounted_instances+=count_
  var anchors:Array=node.get_meta("east_cliff_source_anchors",[])
  for anchor in anchors:owners[owner].anchors.append([id,anchor[0],anchor[1]])
  families[key].mounted_instances+=count_;families[key].chunks+=1;mounted+=count_
  if not node.is_visible_in_tree() or (node.layers&camera.cull_mask)==0:continue
  if intersects_camera(camera,node.global_transform*node.multimesh.get_aabb()):families[key].frustum_chunk_submitted_instances+=count_;chunk_candidates+=count_
  for i in count_:
   var pose=node.global_transform*node.multimesh.get_instance_transform(i)
   if intersects_camera(camera,pose*node.multimesh.mesh.get_aabb()):families[key].frustum_instances+=1;instance_candidates+=1
 var row={"capture":label,"frames":wall,"frame_times":Metrics.summary(wall),"engine_process_ms":Metrics.summary(cpu),"render_cpu_ms":Metrics.summary(render_cpu),"render_gpu_ms":Metrics.summary(render_gpu),"gpu_timing_available":render_gpu.any(func(value):return value>0.),"global_draw_calls":draws,"global_primitives":primitives,"mounted_cliff_instances":mounted,"individual_frustum_candidates":instance_candidates,"chunk_frustum_submitted_instances":chunk_candidates,"families":families,"global_gpu_buffer_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),"global_gpu_video_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),"foreground_fraction":float(focused)/90.,"device":RenderingServer.get_video_adapter_name(),"native_enemies":game.model.enemies.size(),"native_handles":game.army_runtime.handles.size(),"camera":var_to_str(camera.global_transform),"relief_data_sha256":FileAccess.get_sha256(FieldCliffs.StoneRelief.ROOT+"data.json"),"scope":"Steady actual gameplay-camera samples; no quality or source-count reductions. Individual frustum tests estimate geometric visibility, not GPU occlusion; MultiMesh chunks submit all their instances when the chunk intersects the frustum. Global renderer counters include the entire scene."}
 row["rendered_artifact"]=rendered_cliff_artifact()
 row["relief_data_sha256"]=row.rendered_artifact.sha256
 cliff_performance.append(row)
 row["source_owners"]=owners
 var out=FileAccess.open(PROP_OUT+"Cliff Audit/field-angle-performance.json",FileAccess.WRITE);out.store_string(JSON.stringify(cliff_performance,"  "));out.close()

func rendered_cliff_artifact()->Dictionary:
 return {"folder":FieldCliffs.StoneRelief.ROOT,"sha256":FileAccess.get_sha256(FieldCliffs.StoneRelief.ROOT+"data.json"),"private_injection":false}

func intersects_camera(camera:Camera3D,box:AABB)->bool:
 var inside=camera.global_position-camera.global_basis.z*10.
 for plane:Plane in camera.get_frustum():
  var sign_=1. if plane.distance_to(inside)>=0. else -1.;var all_outside=true
  for corner in 8:
   if plane.distance_to(box.get_endpoint(corner))*sign_>=0.:all_outside=false;break
  if all_outside:return false
 return true

func mesh_payload(mesh:Mesh)->Dictionary:
 var bytes=0;var triangles=0;var formats=[]
 for arrays_:Array in mesh.get_meta("east_cpu_arrays",[]):
  for value in arrays_:
   if value is PackedVector3Array:bytes+=value.size()*12
   elif value is PackedVector2Array:bytes+=value.size()*8
   elif value is PackedColorArray:bytes+=value.size()*16
   elif value is PackedInt32Array or value is PackedFloat32Array:bytes+=value.size()*4
  triangles+=arrays_[Mesh.ARRAY_INDEX].size()/3 if arrays_[Mesh.ARRAY_INDEX]!=null and not arrays_[Mesh.ARRAY_INDEX].is_empty() else arrays_[Mesh.ARRAY_VERTEX].size()/3
 for surface in mesh.get_surface_count():formats.append(mesh.surface_get_format(surface))
 return {"retained_cpu_attribute_index_bytes":bytes,"gpu_upload_attribute_index_bytes":bytes,"triangles":triangles,"surface_formats":formats,"limit":"Exact retained source arrays/upload payload; driver packing, alignment and object overhead are separate. Global actual GPU buffer/video memory is recorded per camera."}

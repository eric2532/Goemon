extends "res://tests/forest-shrine/east_landmark_review.gd"
## Native family comparisons plus the two actual maps where generic cubes were rejected.
const Families=preload("res://scripts/forest/forest_east_fallback_families.gd")
const FAMILY_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Fallback Families/"
var mesh_audit=[]

func review_path()->String:return FAMILY_OUT

func sites()->Array:
 if "--fence-only" in OS.get_cmdline_user_args():return [[51002,10475,Vector2i(121,84),"palace-iron-fence",Vector2i(120,87),Vector2i(118,82)]]
 return [[43600,1233268,Vector2i(95,101),"observatory-repaired-families",Vector2i(75,77),Vector2i(90,74)],
  [51002,1235166,Vector2i(133,90),"palace-repaired-families",Vector2i(133,98),Vector2i(143,103)],
  [51002,10475,Vector2i(121,84),"palace-iron-fence",Vector2i(120,87),Vector2i(118,82)]]

func landmark(site_row:Array):
 if Families.owns(int(site_row[1])):await family_views(site_row)
 else:await super.landmark(site_row)
 var source=int(site_row[0]);var id=Maps.runtime_id(source)
 var state:Dictionary=Maps.state(id);var cells:int=state.size.x*state.size.y
 var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(id)].get("graphic_aliases",{})
 var expected={};var actual={};var used=[]
 for i in cells:
  var serial=int(aliases.get(str(state.raw.decode_u16(20+(cells+i)*2)),state.raw.decode_u16(20+(cells+i)*2)))
  if Families.owns(serial):expected[serial]=expected.get(serial,0)+1
 for batch in game.world.find_children("RecoveredShalenaSolid_*","MultiMeshInstance3D",true,false):
  var serial=int(batch.get_meta("source_graphic",0))
  if not Families.owns(serial):continue
  actual[serial]=actual.get(serial,0)+batch.multimesh.instance_count
  check(batch.multimesh.mesh==Families.mesh(serial),"Actual source batch uses cached repaired family %d / %d"%[source,serial])
  if serial not in used:used.append(serial)
 check(expected==actual,"Actual family instances retain every original object-layer placement "+str(source))
 observations.append({"source":source,"expected_original_family_counts":expected,"actual_family_counts":actual,"actual_repaired_graphics":used})

func family_views(row:Array):
 var source=int(row[0]);var serial=int(row[1]);var id=Maps.runtime_id(source);var label:String=row[3]
 camera_component_map=-1;camera_component.clear()
 var initial=walk_cell(id,row[4]);use_camera_component(id,initial)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,initial),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 30:await process_frame
 check(game.model.falan_floor==id,"Direct spawn retains family source map "+str(source))
 var state:Dictionary=Maps.state(id);var native_index:int=row[2].y*state.size.x+row[2].x
 var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(id)].get("graphic_aliases",{})
 var native_serial:int=state.raw.decode_u16(20+(state.size.x*state.size.y+native_index)*2)
 check(int(aliases.get(str(native_serial),native_serial))==serial,"Camera target is an actual original family placement "+str(serial))
 var bounds=Families.mesh(serial).get_aabb();var anchor=Maps.point(id,row[2]);var center=anchor+Vector2(bounds.get_center().x,bounds.get_center().z)
 var world_bounds=AABB(game.model.world_point(anchor)+bounds.position*game.model.falan_scale,bounds.size*game.model.falan_scale)
 for angle in 2:
  var view=await camera_view(id,row[4+angle],center,bounds.get_center().y*game.model.falan_scale,angle==1,world_bounds)
  check(not view.is_empty(),"Found a repaired-family camera "+str(angle))
  if view.is_empty():continue
  check(game.model.falan_floor==id and camera_component.has(view.cell),"Family views retain one original walk component "+str(angle))
  check(game.model.terrain.disk_clear(Vector3(view.at.x,0,view.at.y),.55),"Family camera has actual terrain clearance "+str(angle))
  check(view.clear and view.framed,"Repaired family has clear framed sightline "+str(angle))
  observations.append({"viewpoint":label,"angle":angle,"source_cell":[view.cell.x,view.cell.y],"source_walk_component_cells":camera_component.size(),"physics_sightline_clear":view.clear,"family_midpoint_in_frustum":view.framed,"normal_camera_distance":game.camera_rig.current_distance})
  await capture(label+("-normal" if angle==0 else "-second"),source,view.cell,"Actual repaired wall family from normal gameplay eye on one original walk component; second eye aims at the wall capital")
 var camera:Camera3D=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 var target=game.model.world_point(center,bounds.get_center().y*game.model.falan_scale)
 camera.size=Families.data().graphics[str(serial)].size[1]/(sqrt(2.)*32./3.)*game.model.falan_scale*1.35
 camera.global_position=target+Vector3(-1,1.603567,1).normalized()*120.;camera.look_at(target);camera.reset_physics_interpolation()
 await capture(label+"-native-axis",source,initial,"Calibrated native-axis detail of repaired wall/capital in its actual source placement")
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE

func run():
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FAMILY_OUT))
 await source_views()
 if "--source-only" in OS.get_cmdline_user_args():
  await finish();return
 await super.run()

func finish():
 save_audit()
 print("EAST_FALLBACK_FAMILIES_RESULT checks=",checks," failures=",errors," meshes=",mesh_audit.size())
 if game==null:quit(1 if errors else 0);return
 await super.finish()

func source_views():
 var viewport=SubViewport.new();viewport.size=Vector2i(640,640);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage)
 var environment=WorldEnvironment.new();var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("27313a")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.85
 environment.environment=settings;stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=.65;stage.add_child(light)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
 for serial in ([10474,10475] if "--fence-only" in OS.get_cmdline_user_args() else Families.IDS):
  var g:Dictionary=Families.data().graphics[str(serial)]
  var mesh:Mesh=Families.mesh(serial)
  check(Families.mesh(serial)==mesh,"Immutable family mesh cached "+str(serial))
  var triangles=0
  for slot in mesh.get_surface_count():
   var a=mesh.surface_get_arrays(slot);var indices=a[Mesh.ARRAY_INDEX]
   triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
  var size_=mesh.get_aabb().size
  check(size_.y>1 and minf(size_.x,size_.z)>(.03 if serial in [10474,10475] else .3),"Complete physical volume "+str(serial))
  if serial in [10474,10475]:
   check(mesh.get_meta("native_iron_bars")==5 and mesh.get_meta("native_iron_caps")==5 and mesh.get_meta("native_iron_rails")==2,"Native five bars/caps and two open rails "+str(serial))
   check((size_.z>size_.x*8 if serial==10474 else size_.x>size_.z*8),"Native fence axis and thin physical depth "+str(serial))
   check(triangles==144,"Reused ironwork has12 closed cuboids; no sprite plane "+str(serial))
  var base=mesh.surface_get_arrays(0);var normals:Array=Array(base[Mesh.ARRAY_NORMAL])
  if serial>12000:
   check(normals.any(func(n):return n.x>.5) and normals.any(func(n):return n.z<-.5) and normals.any(func(n):return n.y>.5) and normals.any(func(n):return n.y<-.5),"Palace form closes reverse/top/bottom "+str(serial))
   check(triangles<260,"Repeated palace family remains bounded "+str(serial))
  else:
   var projected=Families.Fit.projected_bounds(Families.Fit.mesh_points(mesh,Families.owner_frame().affine_inverse()),Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO))
   var target=Families.native_target(g)
   check(projected.position.distance_to(target.position)<.05 and projected.size.distance_to(target.size)<.05,"Whole reused form retains measured source bounds "+str(serial))
  mesh_audit.append({"graphic":serial,"source_rgba_sha256":g.source_rgba_sha256,"triangles":triangles,"surfaces":mesh.get_surface_count(),"runtime_bounds":var_to_str(mesh.get_aabb())})
  var node=MeshInstance3D.new();node.mesh=mesh;node.scale.y=1./(.045*Families.Fit.VERTICAL);stage.add_child(node)
  camera.size=g.size[1]/(sqrt(2.)*32./3.)*1.14
  var target=Vector3(0,(-g.origin[1]-g.size[1]*.5)/Families.Fit.VERTICAL,0)
  for angle in 2:
   camera.position=target+(Vector3(-1,1.603567,1) if angle==0 else Vector3(1,1.15,-1)).normalized()*100.
   camera.look_at(target);camera.current=true
   if DisplayServer.get_name()!="headless":
    for i in 6:await process_frame
    await RenderingServer.frame_post_draw
    check(viewport.get_texture().get_image().save_png(FAMILY_OUT+str(serial)+("-source-axis.png" if angle==0 else "-reverse.png"))==OK,"Captured family model "+str(serial)+" "+str(angle))
  node.queue_free();await process_frame
 viewport.queue_free();await process_frame

func save_audit():
 var file=FileAccess.open(FAMILY_OUT+"family-audit.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"mesh_audit":mesh_audit,"captures":captures,"observations":observations,
  "source_hashes":{"helper":FileAccess.get_sha256("res://scripts/forest/forest_east_fallback_families.gd"),"solids":FileAccess.get_sha256("res://scripts/forest/forest_original_map_solids.gd"),"maps":FileAccess.get_sha256("res://scripts/forest/forest_original_maps.gd"),"native_data":FileAccess.get_sha256(Families.ROOT+"data.json")},
  "inferred_visuals":Families.data().inferred+["Native iron bar color and measured structural bounds on the existing Court five-bar/five-cap/two-rail kit; cap depth and hidden bar faces are reconstructed solids."],"scope":"32 exact East object-layer forms:2 iron fences,2 dry trees,21 native palm profiles and7 palace wall/post forms. Whole reused plant masters. Native observed palace faces plus closed reconstructed hidden sections. Same original walk-component camera review; direct spawns do not verify routes or a whole-region walkthrough."},"  "));file.close()

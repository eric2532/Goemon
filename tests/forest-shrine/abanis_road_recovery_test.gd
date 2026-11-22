extends "res://tests/forest-shrine/original_maps_test.gd"
## Follow the original western cave crossing in the existing exploration.
const REVIEW="res://build/Other Files/Asset Toolkit/Abanis Road Recovery/"
const ROAD=[51001,51002,51003,Original.SHALENA_SOUTH,14000,14001,14002,Original.SHALENA_NORTH,51011]
var captures=[]

func run():
 if "--cliff-models" in OS.get_cmdline_user_args():await cliff_models();await finish();return
 entrance_checks()
 joined_cliff_checks()
 for id in [14000,14001,14002]:
  check(Original.state(id).raw==Original.Art.raw_map(Original.path_for(id)),"Western cave keeps all three original map planes "+str(id))
  var gates=Original.links(id)
  check(gates.size()==2,"Western cave has its two original exits "+str(id))
  check(connected(id,gates[0].at,gates[1].at),"Original corridors connect both exits "+str(id))
 for id in [Original.SHALENA_SOUTH,Original.SHALENA_NORTH]:
  check(not Original.links(id).any(func(l):return l.get("floor")==51011) if id==Original.SHALENA_SOUTH else Original.links(id).any(func(l):return l.get("floor")==51011),"Abanis is reached from the snowfield after the western cave")
 if "--data-only" in OS.get_cmdline_user_args():await finish();return
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-abanis-road-test.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false
 game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true
 if "--cliffs-only" in OS.get_cmdline_user_args():
  for id in [Original.SHALENA_SOUTH,14000,14001,14002,Original.SHALENA_NORTH]:
   var previous:int={14000:Original.SHALENA_SOUTH,14001:14000,14002:14001}.get(id,-1)
   var choices=Original.links(id).filter(func(l):return l.get("floor")==previous) if previous>0 else Original.links(id)
   var gate=choices[0]
   Tour.travel(game,Original.layout(id),{"arrival":gate.at,"yaw":0.0,"velocity":Vector3.ZERO})
   for i in 6:await physics_frame
   if id==Original.SHALENA_SOUTH:await gate_capture(14000,"western-cave-south")
   elif id==Original.SHALENA_NORTH:await gate_capture(14002,"western-cave-north")
   else:await road_capture("arrival-"+str(id))
  var capture_file=FileAccess.open(REVIEW+"camera-captures.json",FileAccess.WRITE)
  capture_file.store_string(JSON.stringify(captures," "))
  await finish();return
 var edge:float=Tour.Frontier.OUTER_EDGE.freyja
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge+1)))
 await position_at(Vector2(-39,419));await position_at(Vector2(-39,421))
 check(Tour.area(game.model)=="west_lakes","Falan west gate reaches the western road")
 for target in ROAD:
  if Original.owns(game.model.falan_floor):
   var gates=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("floor")==target)
   if not gates.is_empty():check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(gates[0].at,.15),.5),"Native route reaches the next original entrance "+str(target))
  if not await cross(target):await finish();return
  if target in [14000,14001,14002,Original.SHALENA_NORTH,51011]:await road_capture("arrival-"+str(target))
  if target==Original.SHALENA_SOUTH:await gate_capture(14000,"western-cave-south")
  if target==Original.SHALENA_NORTH:await gate_capture(14002,"western-cave-north")
 for target in [Original.SHALENA_NORTH,14002,14001,14000,Original.SHALENA_SOUTH]:
  var gate=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("floor")==target)[0]
  check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(gate.at,.15),.5),"Return route reaches original entrance "+str(target))
  if not await cross(target):await finish();return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
 var file=FileAccess.open(REVIEW+"camera-captures.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(captures," "))
 await finish()

func gate_capture(target:int,label:String):
 var gate=Original.links(game.model.falan_floor).filter(func(l):return l.get("floor")==target)[0]
 var id:int=game.model.falan_floor;var state=Original.state(id)
 var cell=Vector2i(((gate.at-state.origin)/3).round())
 var near=Original.safe_cell(id,cell+(Vector2i(-3,1) if target==14000 else Vector2i(0,3)))
 check(connected(id,gate.at,Original.point(id,near)),"Entrance camera stays on the source path "+label)
 await position_at(Original.point(id,near))
 await road_capture(label,-PI*.5 if target==14000 else 0.0)
 await road_capture(label+"-turn",-PI/3 if target==14000 else PI/6)
 var far=Original.safe_cell(id,cell+(Vector2i(-5,1) if target==14000 else Vector2i(-2,6)))
 check(connected(id,gate.at,Original.point(id,far)),"Farther normal-camera approach stays on the original road "+label)
 await position_at(Original.point(id,far))
 await road_capture(label+"-roadside",-PI*.5 if target==14000 else 0.0)

func road_capture(label:String,yaw:float=0.0):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance()
 for i in 30:await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
 root.get_texture().get_image().save_png(REVIEW+label+".png")
 var camera:Camera3D=game.camera_rig.camera
 check(camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Normal perspective camera "+label)
 check(is_equal_approx(game.camera_rig.pitch,game.COMBAT_CAMERA_PITCH) and is_equal_approx(game.camera_rig.distance,game.ViewPreferences.CAMERA_DEFAULT),"Default game camera pitch and distance "+label)
 var terrain=game.world.map_features.find_children("RecoveredShalenaSolid_*","MultiMeshInstance3D",true,false)
 check(not terrain.is_empty(),"Native scenery uses shared solid meshes "+label)
 if Original.source_id(game.model.falan_floor) in Original.Forms.Cliffs.MAPS:
  check(game.world.map_features.get_meta("recovered_cliff_chunks",0)>0,"Native cliff sections form joined spatial batches "+label)
 captures.append({"image":label+".png","floor":game.model.falan_floor,"player":str(game.player.position),"camera":str(camera.global_position),"pitch":game.camera_rig.pitch,"distance":game.camera_rig.distance,"collision_distance":game.camera_rig.current_distance,"fov":camera.fov})

func joined_cliff_checks():
 var cliffs=Original.Forms.Cliffs
 var cells={Vector2i(0,0):[11.43,12775],Vector2i(1,0):[11.43,12775]};var cache={}
 var mesh=cliffs.section_mesh(cells,cells.keys(),Vector3.ZERO,cache)
 var vertices=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 check(vertices.size()/3==100,"Joined cells omit the internal cliff wall")
 var internal=0;var finite=true
 for i in range(0,vertices.size(),3):
  if is_equal_approx(vertices[i].x,1.5) and is_equal_approx(vertices[i+1].x,1.5) and is_equal_approx(vertices[i+2].x,1.5):internal+=1
  for j in 3:finite=finite and vertices[i+j].is_finite()
 check(internal==0 and finite,"A native cliff seam has no doubled wall or invalid vertices")
 check(is_equal_approx(cliffs.corner(Vector2i(1,1),cells,cache)[1].y,11.43),"Adjacent sections meet at the same native cap height")
 for id in [Original.SHALENA_SOUTH,Original.SHALENA_NORTH,14000,14001,14002]:
  var row=Original.state(id);var count_:int=row.size.x*row.size.y;var placements=[]
  for i in count_:
   var serial:int=row.raw.decode_u16(20+(count_+i)*2)
   if not cliffs.continuous(serial) and serial not in [12834,12839]:continue
   placements.append([0,0,Vector2.ZERO,serial,count_+i,Vector2i(i%row.size.x,i/row.size.x)])
  var joined=cliffs.collect(placements,row.size,row.bits);var clear=true;var entrances=true
  for cell:Vector2i in joined:clear=clear and not Original.open(row.bits,row.size,cell)
  for p in placements:
   if p[3] not in [12834,12839]:continue
   for z in 3:
    for x in 3:entrances=entrances and not joined.has(p[5]+Vector2i(x,-z))
  check(not joined.is_empty() and clear,"Joined cliffs preserve every original open road/corridor cell "+str(id))
  check(entrances,"Joined rock leaves the original entrance footprints open "+str(id))

func entrance_checks():
 var meshes=[]
 for serial in [13270,13271]:
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  check(Original.Forms.kind(serial,false,g)=="stairs","Original moss stair is not a rock mound "+str(serial))
 for serial in Original.Forms.Cliffs.data():
  var g:Dictionary=Original.Art.data().graphics[serial]
  var mesh=Original.Forms.mesh(int(serial),"rock",g,Original.Art.surface_texture(int(g.surfaces[0])))
  check(mesh.get_meta("native_cliff_profile",0)==int(serial),"Cliff uses its measured native contour "+serial)
  check(mesh.surface_get_material(0).get_shader_parameter("base_texture")==Original.Forms.Cliffs.paint,"Cliff uses its original full paint with bounded edge extension "+serial)
  var arrays=mesh.surface_get_arrays(0)
  meshes.append({"serial":int(serial),"triangles":arrays[Mesh.ARRAY_VERTEX].size()/3,"surfaces":mesh.get_surface_count(),"height":mesh.get_aabb().size.y})
  check(arrays[Mesh.ARRAY_VERTEX].size()/3<=224,"Native cliff stays within its prepared mesh budget "+serial)
  check(mesh==Original.Forms.mesh(int(serial),"rock",g,Original.Art.surface_texture(int(g.surfaces[0]))),"Repeated cliffs share one mesh "+serial)
 for serial in Original.Forms.CaveEntrance.IDS:
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var mesh=Original.Forms.mesh(serial,"rock",g,Original.Art.surface_texture(int(g.surfaces[0])))
  check(mesh.get_meta("native_cave_mouth",0)==serial,"Original cave graphic has an open 3D mouth "+str(serial))
  var triangles=0
  for slot in mesh.get_surface_count():triangles+=mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX].size()/3
  meshes.append({"serial":serial,"triangles":triangles,"surfaces":mesh.get_surface_count(),"height":mesh.get_aabb().size.y})
  var mouth:Vector2=mesh.get_meta("native_mouth_size")
  check(is_equal_approx(mouth.x,6.1875 if serial==12834 else 4.40625),"Entrance width follows its native rim anchors "+str(serial))
  check(mouth.y>6.5 and mouth.y<6.8 if serial==12834 else mouth.y>4.8 and mouth.y<5.1,"Snow and stone mouths retain their distinct native heights "+str(serial))
  var profile:Array=mesh.get_meta("native_mouth_profile")
  check(profile[4].x< -4.0 if serial==12834 else profile[4].x< -2.6,"Native rim flare is recovered from its own source contour "+str(serial))
  check(is_equal_approx(mesh.get_meta("native_mouth_recess"),1.734375 if serial==12834 else 3.375),"Original upper-rim offset supplies the cave recession "+str(serial))
  var pose=Transform3D(Basis(Vector3.UP,PI if serial==12834 else PI*.5),Vector3(3,0,1.5) if serial==12834 else Vector3(-1.5,0,-3))
  for point in [Vector3(0,1,0),Vector3(0,4,0),Vector3(-1,2,0)]:
   var nearest=INF
   for slot in mesh.get_surface_count():
    var points=mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]
    for i in range(0,points.size(),3):
     var hit=Geometry3D.segment_intersects_triangle(pose*(point+Vector3.FORWARD*2),pose*(point+Vector3.BACK*6),points[i],points[i+1],points[i+2])
     if hit!=null:nearest=minf(nearest,(pose.affine_inverse()*hit).z)
   check(nearest>3.5 and nearest<5,"Opening reaches the recessed tunnel instead of a solid rock face "+str(serial))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+"Cliff Refinement"))
 var report=FileAccess.open(REVIEW+"Cliff Refinement/procedural-meshes.json",FileAccess.WRITE)
 report.store_string(JSON.stringify(meshes," "))

func cliff_models():
 root.size=Vector2i(960,720)
 var stage=Node3D.new();root.add_child(stage)
 var environment=WorldEnvironment.new();stage.add_child(environment);environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("36424b")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
 var light=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-45,-30,0)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=63
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+"Cliff Refinement/Models"))
 for serial in [12775,12780,13360,13367,12839,12834]:
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var node=MeshInstance3D.new();stage.add_child(node)
  node.mesh=Original.Forms.mesh(serial,"rock",g,Original.Art.surface_texture(int(g.surfaces[0])))
  var box=node.mesh.get_aabb();var center=box.get_center()
  for direction in 2:
   camera.position=center+Vector3(-1,.65,1 if direction==0 else -.15).normalized()*box.size.length()*1.25;camera.look_at(center)
   for i in 4:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(REVIEW+"Cliff Refinement/Models/%d-%d.png"%[serial,direction])
  node.queue_free();await process_frame
 stage.queue_free()

extends "res://tests/forest-shrine/elsa_map_review.gd"
## Bounded discovery of reachable normal-camera stands; selected images need visual review.
const Temple=preload("res://scripts/forest/forest_elsa_temple.gd")
const REPORT="res://build/Other Files/Asset Toolkit/Elsa Island/"
const SCOUT=REPORT+"Temple Bays/Scout/"

func run():
 await setup_review_game()
 var candidates:Array=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"temple-bay-view-candidates.json")).candidates
 check(not candidates.is_empty() and candidates.size()<=32,"Camera discovery is bounded to32 source-walkable stands")
 if candidates.is_empty():await finish();return
 Tour.travel(game,Original.layout(59520),{"arrival":Original.source_point(59520,Vector2i(candidates[0].cell[0],candidates[0].cell[1])),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 var body:MeshInstance3D=game.find_child("ElsaOriginalTempleVolumes",true,false)
 var targets=bay_targets(body)
 check(targets.size()==2,"Both reference points resolve onto the actual source-painted bay mesh")
 if targets.size()!=2:await finish();return
 var centre:Vector3=(targets[0]+targets[1])*.5
 var blockers=[]
 for node in game.find_children("*","GeometryInstance3D",true,false):
  if node==body or not node.is_visible_in_tree() or node.get_world_3d()!=game.camera_rig.camera.get_world_3d():continue
  if node is MeshInstance3D and node.mesh!=null:
   var box:AABB=node.global_transform*node.mesh.get_aabb()
   if box.end.y>3.:blockers.append({"box":box,"name":str(node.name)})
  elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
   for i in node.multimesh.instance_count:
    var box:AABB=node.global_transform*node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb()
    if box.end.y>3.:blockers.append({"box":box,"name":str(node.name)})
 var rows=[]
 for candidate in candidates:
  var cell=Vector2i(candidate.cell[0],candidate.cell[1])
  var at=Original.source_point(59520,cell)
  if game.model.get_meta("falan_links",[]).any(func(link):return at.distance_to(link.at)<4.5):continue
  check(Elsa.owned_cell(59520,cell) and Original.open(Original.state(59520).bits,Original.state(59520).size,cell),"Scout stands on original island-owned walking ground")
  var row:Dictionary=await measure_view(cell,centre,targets,blockers)
  check(game.model.falan_floor==59520,"View discovery does not activate a crossing")
  if game.model.falan_floor!=59520:await finish();return
  row.walk_clearance=candidate.walk_clearance;rows.append(row)
 var eligible=rows.filter(func(row):return row.framed and row.actual_distance>=18. and row.front_dot>.15)
 eligible.sort_custom(func(a,b):return a.score>b.score)
 check(not eligible.is_empty(),"At least one normal camera keeps both bays framed without collapsing")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCOUT))
 var selected=[]
 for row in eligible:
  if not selected.is_empty() and selected.any(func(other):return Vector2(row.cell[0],row.cell[1]).distance_to(Vector2(other.cell[0],other.cell[1]))<8.):continue
  selected.append(row)
  if selected.size()==4:break
 for i in selected.size():
  var row:Dictionary=await measure_view(Vector2i(selected[i].cell[0],selected[i].cell[1]),centre,targets,blockers)
  root.get_texture().get_image().save_png(SCOUT+"candidate-%d.png"%i)
  selected[i]=row
 var file=FileAccess.open(SCOUT+"observations.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"targets":targets.map(func(p):return [p.x,p.y,p.z]),"candidates":rows,"selected":selected,"limits":["Normal rig on source walking cells; player placements are art fixtures, not journey evidence.","AABB overlaps rank possible occlusion conservatively; selected captures require human visual inspection.","No scenery, navigation or camera runtime settings are changed."]}," "));file.close()
 print("ELSA_TEMPLE_SCOUT candidates=",rows.size()," framed=",eligible.size()," selected=",selected.size()," checks=",checks," failures=",failures)
 await finish()

func bay_targets(body:MeshInstance3D)->Array[Vector3]:
 var arrays=body.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
 var texture:Texture2D=body.mesh.surface_get_material(0).get_shader_parameter("base_texture")
 var part:Dictionary=Temple.data().parts.filter(func(p):return p.has("bays"))[0];var result:Array[Vector3]=[]
 for span in part.bays.spans:
  var wanted=Vector2((float(span[0])+float(span[1]))*.5,(Temple.bounds().position.y+float(part.bays.full_before))*.5)
  for i in range(0,indices.size() if not indices.is_empty() else vertices.size(),3):
   var a_index=indices[i] if not indices.is_empty() else i;var b_index=indices[i+1] if not indices.is_empty() else i+1;var c_index=indices[i+2] if not indices.is_empty() else i+2
   var a=uv[a_index]*texture.get_size()+Temple.bounds().position;var ab=(uv[b_index]-uv[a_index])*texture.get_size();var ac=(uv[c_index]-uv[a_index])*texture.get_size();var delta=wanted-a
   var determinant_=ab.cross(ac)
   if absf(determinant_)<.0001:continue
   var beta=delta.cross(ac)/determinant_;var gamma=ab.cross(delta)/determinant_
   if beta>=-.0001 and gamma>=-.0001 and beta+gamma<=1.0001:
    result.append(body.global_transform*(vertices[a_index]+(vertices[b_index]-vertices[a_index])*beta+(vertices[c_index]-vertices[a_index])*gamma));break
 return result

func measure_view(cell:Vector2i,centre:Vector3,targets:Array[Vector3],blockers:Array)->Dictionary:
 game.camera_rig.set_process(true)
 game.player.position=game.model.world_point(Original.source_point(59520,cell),.15);game.player.velocity=Vector3.ZERO;game.falan_crossing_position=Vector2.INF
 game.player.reset_physics_interpolation();game.camera_rig.reset_follow()
 var yaw=atan2(game.player.global_position.x-centre.x,game.player.global_position.z-centre.z)
 var across=Vector2(game.player.global_position.x-centre.x,game.player.global_position.z-centre.z).length()
 var pitch=clampf(-atan2((centre.y-game.player.global_position.y)*.65,across+24.),-.65,1.15)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=pitch;game.camera_rig.distance=18.;game.camera_rig.current_distance=game.camera_rig.combat_distance()
 for i in 6:await process_frame
 game.camera_rig.set_process(false);game.camera_rig.camera.reset_physics_interpolation()
 for i in 2:await RenderingServer.frame_post_draw
 var camera:Camera3D=game.camera_rig.camera;var pixels=[];var framed=true;var occluders=[]
 for target in targets:
  var pixel=camera.unproject_position(target);pixels.append([pixel.x,pixel.y])
  framed=framed and not camera.is_position_behind(target) and Rect2(440,100,960,650).has_point(pixel)
  for blocker in blockers:
   if blocker.box.intersects_segment(camera.get_camera_transform().origin,target)!=null:occluders.append(blocker.name)
 var horizontal=camera.get_camera_transform().origin-centre;horizontal.y=0.
 var front=body_front_direction();var facing=horizontal.normalized().dot(front)
 var separation=Vector2(pixels[0][0],pixels[0][1]).distance_to(Vector2(pixels[1][0],pixels[1][1]))
 var result={"cell":[cell.x,cell.y],"yaw":yaw,"pitch":pitch,"distance":18.,"actual_distance":game.camera_rig.current_distance,"pixels":pixels,"framed":framed,"front_dot":facing,"possible_occluders":occluders,"score":separation-occluders.size()*80.+game.camera_rig.current_distance}
 print("ELSA_TEMPLE_SCOUT_VIEW ",result)
 return result

func body_front_direction()->Vector3:
 var body:MeshInstance3D=game.find_child("ElsaOriginalTempleVolumes",true,false)
 var direction=body.global_basis*Vector3(-1,0,1);direction.y=0.;return direction.normalized()

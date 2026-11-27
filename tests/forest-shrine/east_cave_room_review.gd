extends "res://tests/forest-shrine/east_ground_motif_review.gd"
## Private assembled native-wall/roof study; no shared map or camera owner mutation.
const Candidate=preload("res://scripts/forest/forest_east_cave_room_candidates.gd")
var wall_audit=[]
var roof_audit=[]
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Cave Room Rendered/"
func review_source_paths()->Array:
 return super.review_source_paths()+["scripts/forest/forest_east_cave_room_candidates.gd","scripts/forest/forest_original_map_details.gd","scripts/forest/habaru_ceiling.gdshader","scripts/forest/forest_east_cliff_volume.gdshader",String(Candidate.ROOT+"data.json").trim_prefix("res://")]
func landmark(row:Array):
 var source=int(row[0]);var id=Maps.runtime_id(source);var start=walk_cell(id,row[4]);var arrival=Maps.point(id,start)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":arrival,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 var before=[];var after=[];var replacements=[];var retired=[]
 for batch:MultiMeshInstance3D in game.world.map_features.find_children("RecoveredShalenaSolid_*","MultiMeshInstance3D",true,false):
  var serial=int(batch.get_meta("source_graphic",-1))
  if not Candidate.owns(serial):continue
  var count_=batch.multimesh.instance_count;before.append([serial,count_]);var chunks={}
  for index in count_:
   var pose=batch.multimesh.get_instance_transform(index);var key=Vector2i(floori(pose.origin.x/48.),floori(pose.origin.z/48.))
   if not chunks.has(key):chunks[key]=[]
   chunks[key].append(pose)
  for key:Vector2i in chunks:
   var node=MultiMeshInstance3D.new();node.name="PrivateNativeWall_%d_%d_%d"%[serial,key.x,key.y];node.transform=batch.transform
   node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=Candidate.mesh(serial);node.multimesh.instance_count=chunks[key].size()
   var bounds=AABB();var first=true
   for index in chunks[key].size():
    var pose:Transform3D=chunks[key][index];node.multimesh.set_instance_transform(index,pose)
    var box: AABB=pose*node.multimesh.mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
   node.multimesh.custom_aabb=bounds;node.set_meta("source_graphic",serial);batch.get_parent().add_child(node);after.append([serial,chunks[key].size()])
  replacements.append({"graphic":serial,"source_instances":count_,"spatial_chunks":chunks.size(),"mesh_bounds":var_to_str(Candidate.mesh(serial).get_aabb())});retired.append(batch)
 for batch:Node in retired:batch.get_parent().remove_child(batch);batch.queue_free()
 var expected={};var actual={}
 for record:Array in before:expected[record[0]]=int(expected.get(record[0],0))+int(record[1])
 for record:Array in after:actual[record[0]]=int(actual.get(record[0],0))+int(record[1])
 check(actual==expected,"Private spatial batches retain every original source wall placement "+str(source))
 var mass={}
 if source in [11037,34018]:mass=Candidate.build_mass(game.world.map_features,source,Maps.state(id))
 var roofs=[]
 for roof:MeshInstance3D in game.world.map_features.find_children("*Ceiling","MeshInstance3D",true,false):
  var material=roof.get_active_material(0)
  if not material is ShaderMaterial or material.shader.resource_path!="res://scripts/forest/habaru_ceiling.gdshader":continue
  var owned:ShaderMaterial=material.duplicate();owned.set_shader_parameter("roof_camera_cutaway_margin",1.5);roof.material_override=owned;roofs.append(str(roof.get_path()))
 check(not roofs.is_empty(),"Only the existing East visual roof receives opt-in cutaway "+str(source))
 wall_audit.append({"source":source,"placements_before":expected,"placements_after":actual,"batches":replacements,"inferred_closed_mass":mass})
 roof_audit.append({"source":source,"visual_roofs":roofs,"collision_and_camera_rays_unchanged":true,"inferred":"Existing cave roof material and1.5world-metre near-camera visual cutaway; original2Ddoes not record this roof/back. Low/upward view must still show it."})
 await super.landmark(row)
 var at=map_position();var eye=game.model.world_point(at,1.4);var target=eye+Vector3(2,4,1)
 await fixed_capture("room-%d-manual-upward"%source,eye,target,"Fixed upward view from standing eye at the same original walkable source cell; roof collision/player/native heights and wall camera rays remain unchanged")
 var file=FileAccess.open(review_path()+"wall-roof-context.json",FileAccess.WRITE);file.store_string(JSON.stringify({"walls":wall_audit,"roofs":roof_audit,"scope":"Private assembled room study. Normal landmark camera80percent guards are unchanged; technical source checks do not certify image quality or clear room views."}," "));file.close()

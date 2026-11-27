extends "res://tests/forest-shrine/original_maps_test.gd"
## Source100 cliff preparation and exact legacy visual-owner diagnosis; no source activation.
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source cliffs/"
const Ruby=preload("res://scripts/forest/forest_ruby_region_art.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const West=preload("res://scripts/forest/forest_west_route_scenery.gd")
const Cliffs=preload("res://scripts/forest/forest_original_cliffs.gd")
const FULL="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source outdoors/Prepared full/"
class StudyTerrain extends Terrain:
 var snapshot:Image
 func mask_image()->Image:return snapshot
 func mask_texture()->Texture2D:return ImageTexture.create_from_image(snapshot)
class StudyModel:
 var terrain
 var falan_area="south_lakes"
 func surface_height(x:float,z:float)->float:return terrain.height(x,z)
func _initialize():
 create_timer(420).timeout.connect(func():printerr("FREYJA_CLIFF_TIMEOUT");quit(1))
 run.call_deferred()
func write(path:String,value):
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value,"  ",true,true)+"\n");file.close()
func prepare_masses(calibrated:bool=false):
 var started_checks=checks;var started_failures=failures;var stage=REVIEW+("Prepared calibrated/"if calibrated else"Prepared study/")
 var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"Prepared/source-cliffs.json"));var protected={}
 packet.preserve_profile_height=not calibrated
 for path in ["res://assets/maps/falan/freyja_source/100.dat","res://assets/maps/falan/freyja_residual/full/data.gd","res://assets/maps/original_crossgate/cliff-profiles.json","res://assets/maps/original_crossgate/cliff-paint.png"]:protected[path]=FileAccess.get_sha256(path)
 var study=Rect2i(336,345,38,42);var row:Dictionary=packet.maps.south_lakes
 row.cliffs=row.cliffs.filter(func(item):return study.has_point(Vector2i(item[0],item[1])))
 var size_=Vector2i(packet.size[0],packet.size[1]);var bits:PackedByteArray=row.walk.hex_decode();var original_bits=bits.duplicate()
 for y in size_.y:
  for x in size_.x:
   if not study.has_point(Vector2i(x,y)):
    var i=y*size_.x+x;bits[i>>3]|=1<<(i&7)
 row.walk=bits.hex_encode();packet.maps={"south_lakes":row};packet.study_bounds=[study.position.x,study.position.y,study.size.x,study.size.y]
 var placements=[];var count_=size_.x*size_.y;var reserved={}
 for item in row.cliffs+row.entrances:
  var cell=Vector2i(item[0],item[1]);placements.append([0,0,Vector2.ZERO,int(item[2]),count_+cell.y*size_.x+cell.x,cell])
  if int(item[2])in Cliffs.ENTRANCES:
   var span:Array=packet.graphics[str(int(item[2]))].footprint
   for z in int(span[1]):
    for x in int(span[0]):reserved[cell+Vector2i(x,-z)]=true
 var controls={}
 for span in packet.blocked_control_spans:
  for x in range(maxi(int(span[1]),study.position.x),mini(int(span[2])+1,study.end.x)):
   var cell=Vector2i(x,span[0]);var i=cell.y*size_.x+cell.x
   if study.has_point(cell)and not reserved.has(cell)and (bits[i>>3]&(1<<(i&7)))==0:controls[cell]=true
 var owners=Cliffs.collect(placements,size_,bits,true,packet);var footprint_cells=owners.keys();var queue=footprint_cells.duplicate();var cursor=0
 while cursor<queue.size():
  var cell:Vector2i=queue[cursor];cursor+=1
  for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next:Vector2i=cell+step
   if owners.has(next)or not controls.has(next):continue
   owners[next]=owners[cell];queue.append(next)
 var fill=[]
 for cell:Vector2i in owners:
  if cell in footprint_cells:continue
  var record:Array=owners[cell];fill.append([cell.x,cell.y,int(record[1]),record[2].x,record[2].y])
 packet.source_cliff_fill=fill;packet.tile_unseen_faces=true;packet.cap_paint.cave=packet.cap_paint.freyja;packet.minimum_crown_fraction=.7
 check(fill.all(func(item):return controls.has(Vector2i(item[0],item[1]))),"Inferred closure uses only bounded connected blocked100 cells and excludes original mouths")
 var t=Terrain.new();t.variant="south_lakes";t.horizontal_scale=2.;t.expansion=1.5;Terrain.fields.erase("south_lakes");t.configure([])
 var model=StudyModel.new();model.terrain=t
 var station_keys={}
 for item in row.cliffs:station_keys[Vector3i(item[0],item[1],item[2])]=true
 check(not West.source_cliff_owned(model,12549,Vector2i(353,366))and not West.source_house_owned(model,5007),"Ordinary callers leave staged cliff/house ownership disabled")
 model.set_meta("source_cliff_study",{"area":"south_lakes","stations":station_keys,"house_sites":{5007:true}})
 check(West.source_cliff_owned(model,12549,Vector2i(353,366))and West.source_house_owned(model,5007)and not West.source_house_owned(model,1155),"Only exact staged cliff stations/house sites transfer visual ownership")
 model.falan_area="north_coast"
 check(not West.source_cliff_owned(model,12549,Vector2i(353,366))and not West.source_house_owned(model,5007),"Travel to another area cannot retain staged cliff/house visual ownership")
 model.falan_area="south_lakes";model.remove_meta("source_cliff_study")
 var native_before=var_to_bytes(t.terrain_field().get_meta("heights"))+var_to_bytes(t.terrain_field().get_meta("covered"))
 var parent=Node3D.new();root.add_child(parent);var field=West.build_source_cliffs(parent,"south_lakes",model,packet)
 var cells:Array=field.get_meta("recovered_cliff_cells");var valid=true
 for cell:Vector2i in cells:
  var i=cell.y*size_.x+cell.x
  valid=valid and study.has_point(cell)and (original_bits[i>>3]&(1<<(i&7)))==0
 check(valid,"Every continuous mass cell lies on the staged blocked source footprint inside the study")
 check(not cells.is_empty(),"Original source profiles produce continuous mass cells")
 check(field.find_children("*","CollisionObject3D",true,false).is_empty(),"Source cliff recovery adds no physics owner")
 check(native_before==var_to_bytes(t.terrain_field().get_meta("heights"))+var_to_bytes(t.terrain_field().get_meta("covered")),"Cliff presentation leaves terrain height and native coverage bytes exact")
 var chunks=[];var triangles=0;var vertices=0
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stage+"meshes/"))
 for node:MeshInstance3D in field.get_children():
  var path=stage+"meshes/"+node.name+".res"
  check(ResourceSaver.save(node.mesh,path)==OK,"Prepared continuous source chunk "+str(node.name))
  for surface in node.mesh.get_surface_count():
   var arrays=node.mesh.surface_get_arrays(surface);vertices+=arrays[Mesh.ARRAY_VERTEX].size();triangles+=arrays[Mesh.ARRAY_VERTEX].size()/3
  chunks.append({"name":str(node.name),"position":[node.position.x,node.position.y,node.position.z],"mesh":path,"sha256":FileAccess.get_sha256(path)})
 row.prepared_chunks=chunks;row.prepared_cells=cells.map(func(cell):return [cell.x,cell.y])
 packet.prepared_owner_sha256=FileAccess.get_sha256("res://scripts/forest/forest_west_route_scenery.gd")
 packet.prepared_cliff_owner_sha256=FileAccess.get_sha256("res://scripts/forest/forest_original_cliffs.gd")
 packet.prepared_source_sha256=FileAccess.get_sha256(REVIEW+"Prepared/source-cliffs.json")
 for path in protected:check(FileAccess.get_sha256(path)==protected[path],"Canonical source/profile/paint remains exact "+path)
 write(stage+"source-cliffs.json",packet)
 write(REVIEW+("mass-preparation-calibrated.json"if calibrated else"mass-preparation.json"),{"checks":checks-started_checks,"failures":failures-started_failures,"height_case":"existing coastal frame"if calibrated else"raw authoring profile","source_anchors":row.cliffs.size(),"footprint_cells":footprint_cells.size(),"inferred_control_closure":fill.size(),"cells":cells.size(),"chunks":chunks.size(),"triangles":triangles,"vertices":vertices,"bounds":packet.study_bounds,"protected":protected,"active":false,"limits":"Controlled source-derived height scale study; neither is an original elevation plane. Exact source X/Z and native physics remain. Bounded blocked100 closure and unseen faces are inferred. Source/house and normal-camera visual comparison required."})
 parent.queue_free();await process_frame
func default_regression():
 var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"Before connected mass correction/Prepared study/source-cliffs.json"));var row:Dictionary=packet.maps.south_lakes
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"Prepared/source-cliffs.json"))
 packet.profiles=source.profiles;packet.graphics=source.graphics;packet.cap_paint=source.cap_paint
 var old_chunks:Array=row.prepared_chunks;row.erase("prepared_chunks");row.erase("prepared_cells")
 var terrain=Terrain.new();terrain.variant="south_lakes";terrain.horizontal_scale=2.;terrain.expansion=1.5;terrain.configure([])
 var model=StudyModel.new();model.terrain=terrain;var parent=Node3D.new();root.add_child(parent)
 var field=West.build_source_cliffs(parent,"south_lakes",model,packet)
 check(field.get_child_count()==old_chunks.size(),"Default continuous builder keeps the protected footprint chunk count")
 for chunk in old_chunks:
  var old:Mesh=load(chunk.mesh.replace("Prepared study/","Before connected mass correction/Prepared study/"));var actual:Mesh=field.get_node(NodePath(chunk.name)).mesh
  var exact=old.get_surface_count()==actual.get_surface_count()
  for surface in actual.get_surface_count():exact=exact and var_to_bytes(old.surface_get_arrays(surface))==var_to_bytes(actual.surface_get_arrays(surface))
  check(exact,"Default context keeps every protected geometry/normal/UV/index byte "+str(chunk.name))
 write(REVIEW+"default-regression.json",{"checks":checks,"failures":failures,"chunks":old_chunks.size(),"limits":"Empty new fill context compared with the protected pre-extension footprint resources. This verifies the shared builder default geometry, not the staged appearance."})
 parent.queue_free();await process_frame
func height_calibration():
 var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"Prepared/source-cliffs.json"));packet.texture=load(packet.texture);packet.erase("source_cliff_fill")
 var results=[];var size_=Vector2i(5,5);var bits=PackedByteArray();bits.resize(4)
 for key in packet.profiles:
  var serial=int(key);var contexts=[packet.duplicate(false),packet.duplicate(false)];contexts[0].preserve_profile_height=false;contexts[1].preserve_profile_height=true
  var bounds=[];var projected=[]
  for context in contexts:
   var field=Node3D.new();root.add_child(field);field.set_meta("western_route_area","south_lakes")
   Cliffs.build(field,[[0,0,Vector2.ZERO,serial,37,Vector2i(2,2)]],size_,bits,Vector2.ZERO,100,Vector2i.ZERO,context)
   var mesh:Mesh=field.get_child(0).mesh;var box:AABB=mesh.get_aabb();bounds.append(box)
   var fit=load("res://scripts/forest/forest_falan_proportions.gd");var points:Array[Vector3]=fit.mesh_points(mesh)
   for i in points.size():points[i]-=Vector3(6,0,6)
   projected.append(str(fit.projected_bounds(points,Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO))));field.queue_free()
  var height=float(packet.profiles[key].height)
  check(bounds[1].end.y<=height*1.12+.001,"Native profile crown remains in its measured units "+key)
  check(bounds[0].position.x==bounds[1].position.x and bounds[0].position.z==bounds[1].position.z and bounds[0].size.x==bounds[1].size.x and bounds[0].size.z==bounds[1].size.z,"Height correction keeps native footprint/axis exact "+key)
  var g:Dictionary=packet.graphics[key]
  results.append({"serial":serial,"source_profile_height":height,"legacy_continuous_peak":bounds[0].end.y,"native_continuous_peak":bounds[1].end.y,"footprint":g.footprint,"source_visible_top":float(g.origin[1])+float(packet.profiles[key].contour_top.min()),"projected_coastal_frame":projected[0],"projected_raw_profile":projected[1]})
 var house:Mesh=load("res://scripts/forest/forest_coastal_buildings.gd").shape(11279)
 write(REVIEW+"height-calibration.json",{"checks":checks,"failures":failures,"profiles":results,"reference_house11279_bounds":str(house.get_aabb()),"coastal_y_frame":1./(.045*load("res://scripts/forest/forest_falan_proportions.gd").VERTICAL),"limits":"The staged study retains source-derived profile authoring heights without another source100 camera conversion. These inferred profile heights are not an original elevation plane. Existing coastal buildings apply their separate native_coastal_frame; source-relative scale requires image comparison. No native terrain/collider or source-station change. Shared default geometry remains protected. Crown interpolation up to12% above profile.height is existing inferred-cap behavior."})
 await process_frame
func prepare_house_roof():
 var original:Mesh=load(REVIEW+"Prepared comparison/house11279.res");var repaired:Mesh=original.duplicate();var arrays=[];var materials=[]
 for surface in original.get_surface_count():arrays.append(var_to_bytes(original.surface_get_arrays(surface)));materials.append(original.surface_get_material(surface))
 var data=load("res://assets/maps/falan/venoa_buildings.gd");var r:Array=data.FORMS[11279].rect
 var roof=SurfaceTool.new();roof.begin(Mesh.PRIMITIVE_TRIANGLES);var triangles=0
 for quad in original.get_meta("native_roof_quads"):
  var normal:Vector3=(quad[2]-quad[0]).cross(quad[1]-quad[0]).normalized();var tangent:Vector3=(quad[3]-quad[0]).normalized();var along=normal.cross(tangent).normalized()
  check(normal.y>0.,"Existing measured roof panel faces outward/up")
  for i in [0,1,2,0,2,3]:
   var p:Vector3=quad[i]-Vector3.UP*.02
   roof.set_normal(normal);roof.set_uv(Vector2(p.dot(tangent),p.dot(along))/3.);roof.set_uv2(Vector2(r[0]+200-8.,r[1]+140-8.));roof.add_vertex(p)
  triangles+=2
 var part=roof.commit();repaired.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0))
 var material:ShaderMaterial=load("res://scripts/forest/forest_coastal_mesh.gd").material(data.ATLAS,true).duplicate();material.set_shader_parameter("atlas_tile_pixels",48.)
 repaired.surface_set_material(repaired.get_surface_count()-1,material)
 for surface in original.get_surface_count():
  check(var_to_bytes(repaired.surface_get_arrays(surface))==arrays[surface],"Every original house vertex/normal/UV/index byte remains exact "+str(surface))
  check(repaired.surface_get_material(surface)==materials[surface],"Every original house material remains shared/unchanged "+str(surface))
 check(repaired.get_aabb()==original.get_aabb(),"Unseen inward roof support preserves the original model bounds")
 var path=REVIEW+"Prepared comparison/house11279-roof-supported.res"
 check(ResourceSaver.save(repaired,path)==OK,"Staged existing roof-plane support prepared without a new texture/master")
 write(REVIEW+"house-roof-preparation.json",{"checks":checks,"failures":failures,"source_graphic":11279,"added_triangles":triangles,"original_surfaces":original.get_surface_count(),"source_roof_patch":[200,140,32,32],"source_atlas":"res://assets/maps/falan/venoa_buildings.png","prepared_mesh":path,"prepared_sha256":FileAccess.get_sha256(path),"limits":"Private comparison derivative only. Original surfaces/materials/geometry remain exact; existing measured roof quads supply inward unseen panels beneath the original2Dprojected chimney/dormer cutouts. Original roof-only paint supplies infill; no new texture, source/master, physics or route change. Rendered acceptance required."})
func trace_legacy():
 var terrain=Terrain.new();terrain.variant="south_lakes";terrain.horizontal_scale=2.;terrain.expansion=1.5;terrain.configure([])
 var model=StudyModel.new();model.terrain=terrain
 var owner=Node3D.new();root.add_child(owner);Ruby.build_cave_walls(owner,100,model)
 var review:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja source encounters/wasp-camera-review.json"))
 var frame=Regions.frame("south_lakes").inverse();var turn=Basis(Vector3(frame.x.x,0,frame.x.y),Vector3.UP,Vector3(frame.y.x,0,frame.y.y))
 var nodes={};var records=[];var indices={};var target=Vector3(-132.6,8.366313,-374.4)
 for node:MultiMeshInstance3D in owner.get_children():nodes[int(node.name.get_slice("_",1))]=node
 for row in Ruby.caves.maps["100"]:
  var serial=int(row[2]);var graphic:Dictionary=Ruby.caves.graphics[str(serial)]
  if graphic.get("void_only",false):continue
  var index=int(indices.get(serial,0));indices[serial]=index+1
  var at=frame*(Vector2(row[0],row[1])*3.)
  var pose=Transform3D(turn,Vector3(at.x,model.surface_height(at.x,at.y),at.y))
  pose=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.3),Vector3.ZERO)*pose
  var mesh:Mesh=nodes[serial].multimesh.mesh
  var world_bounds=pose*mesh.get_aabb();var hits=[]
  for camera in review.cameras:
   var eye:Vector3=str_to_var("Vector3"+camera.eye);var direction=(target-eye).normalized()
   if not world_bounds.intersects_segment(eye,target):continue
   var inverse=pose.affine_inverse();var local_eye=inverse*eye;var local_direction=inverse.basis*direction;var closest=INF;var triangle=-1
   for surface in mesh.get_surface_count():
    var arrays=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
    for n in range(0,ids.size()if not ids.is_empty()else vertices.size(),3):
     var a=vertices[ids[n]if not ids.is_empty()else n];var b=vertices[ids[n+1]if not ids.is_empty()else n+1];var c=vertices[ids[n+2]if not ids.is_empty()else n+2]
     var hit=Geometry3D.ray_intersects_triangle(local_eye,local_direction,a,b,c)
     if hit!=null:
      var distance=(pose*hit).distance_to(eye)
      if distance<eye.distance_to(target)and distance<closest:closest=distance;triangle=n/3
   if triangle>=0:hits.append({"camera":camera.image,"distance":closest,"triangle":triangle})
  if not hits.is_empty():records.append({"owner":"forest_ruby_region_art.gd::build_cave_walls/cave_mesh","node":str(nodes[serial].name),"instance":index,"source_cell":[row[0],row[1]],"serial":serial,"source_rgba_sha256":graphic.rgba_sha256,"source_origin":graphic.origin,"source_bounds":graphic.bounds,"source_profile_height":graphic.profile.height,"mesh_bounds":str(mesh.get_aabb()),"world_bounds":str(world_bounds),"root":[pose.origin.x,pose.origin.y,pose.origin.z],"hits":hits})
 check(not records.is_empty(),"Actual Ruby source mesh triangles intersect the failed camera-to-hero rays")
 check(owner.find_children("*","CollisionObject3D",true,false).is_empty(),"Ruby native cliff presentation owns no physics rays")
 write(REVIEW+"legacy-wasp-owner-trace.json",{"checks":checks,"failures":failures,"source_cell":[353,367],"target":[target.x,target.y,target.z],"trace":records,"limits":"Exact production mesh triangles and source-row transforms, evaluated on the CPU. Dummy MultiMesh transform readback is deliberately unused. This identifies real visual intersections, not visual acceptance or a native-physics change."})
 owner.queue_free();await process_frame
func collision_snapshot(parent:Node3D)->Array:
 var result=[]
 for node:CollisionShape3D in parent.find_children("*","CollisionShape3D",true,false):
  var shape:Shape3D=node.shape;var details=shape.size if shape is BoxShape3D else [shape.radius,shape.height]if shape is CapsuleShape3D or shape is CylinderShape3D else shape.radius if shape is SphereShape3D else hash(shape.get_faces())if shape is ConcavePolygonShape3D else str(shape.get_class())
  result.append([node.global_transform,str(shape.get_class()),details,node.disabled])
 result.sort_custom(func(a,b):return JSON.stringify(a)<JSON.stringify(b))
 return result
func scene_trace(study:bool=false,calibrated:bool=false,comparison:bool=false):
 root.size=Vector2i(1280,800);game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-cliff-trace-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 Tour.travel(game,Regions.layout("south_lakes"),{"arrival":Regions.frame("south_lakes").inverse()*Vector2(353,367)*3.,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.player.position=game.model.world_point(Regions.frame("south_lakes").inverse()*(Vector2(353,367)*3.),.15);game.model.hero_position=game.player.position
 game.world.sync(0.);game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 var review:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja source encounters/wasp-camera-review.json"))
 var study_report={}
 if study:
  var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+("Prepared calibrated/"if calibrated else"Prepared study/")+"source-cliffs.json"));var row:Dictionary=packet.maps.south_lakes
  check(packet.prepared_owner_sha256==FileAccess.get_sha256("res://scripts/forest/forest_west_route_scenery.gd"),"Prepared continuous resources match the existing owner")
  check(packet.prepared_cliff_owner_sha256==FileAccess.get_sha256("res://scripts/forest/forest_original_cliffs.gd"),"Prepared continuous resources match the original cliff producer")
  check(packet.prepared_source_sha256==FileAccess.get_sha256(REVIEW+"Prepared/source-cliffs.json"),"Prepared continuous resources match full-source station/clip metadata")
  var stations={}
  for item in row.cliffs:stations[Vector3i(item[0],item[1],item[2])]=true
  var house_trace={}
  if comparison:
   var old=game.world.map_features.find_children("*","Node3D",true,false).filter(func(node):return node.get_meta("source_site",0)==5007)
   check(old.size()==1,"Exactly one existing Forest Cottage facade owner is identified")
   if old.size()==1:
    var parts=[]
    for node:MultiMeshInstance3D in old[0].find_children("*","MultiMeshInstance3D",true,false):
     for instance in node.multimesh.instance_count:
      var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(instance)
      parts.append({"node":str(node.get_path()),"instance":instance,"root":str(pose.origin),"bounds":str(pose*node.multimesh.mesh.get_aabb())})
    house_trace={"site":5007,"asset":"res://assets/models/environments/wind_meadow/falan/falan_townhouse.glb","owner":"DestinationArt.build site facade","old_root":str(old[0].global_transform),"parts":parts,"source_graphic":11279,"source_cell":[347,377],"source_footprint":[5,4]}
  var obstacles=JSON.stringify(game.model.scenery_obstacles);var physics=collision_snapshot(game.world.map_features)
  var field=game.model.terrain.terrain_field();var native_bytes=var_to_bytes(field.get_meta("heights"))+var_to_bytes(field.get_meta("covered"))
  game.model.set_meta("source_cliff_study",{"area":"south_lakes","stations":stations,"house_sites":{5007:true}if comparison else{}});game.world.reload_map()
  var mass=West.build_source_cliffs(game.world.map_features,"south_lakes",game.model,packet)
  if comparison:
   check(game.world.map_features.find_children("*","Node3D",true,false).all(func(node):return node.get_meta("source_site",0)!=5007),"Only the identified generic site5007facade is replaced")
   check(game.world.map_features.find_children("BlueCGVillageBuilding_11279","MeshInstance3D",true,false).is_empty(),"Source house has no existing renderer to duplicate")
   var house_cell=Vector2(347,377);var house_centre=house_cell+Vector2(2,-1.5);var at=Regions.frame("south_lakes").inverse()*(house_centre*3.)
   var coastal=load("res://scripts/forest/forest_coastal_buildings.gd")
   coastal.meshes[[coastal.Atlas,11279]]=load(REVIEW+"Prepared comparison/"+("house11279-roof-supported.res"if "--roof-study"in OS.get_cmdline_user_args()else"house11279.res"))
   coastal.build(game.world.map_features,Vector3(at.x,game.model.surface_height(at.x,at.y),at.y),11279)
  for i in 4:await process_frame
  check(obstacles==JSON.stringify(game.model.scenery_obstacles),"Native scenery obstacle rows remain unchanged")
  check(physics==collision_snapshot(game.world.map_features),"Every original collider shape/transform remains unchanged")
  check(native_bytes==var_to_bytes(field.get_meta("heights"))+var_to_bytes(field.get_meta("covered")),"Native terrain heights/coverage remain byte exact")
  check(mass.find_children("*","CollisionObject3D",true,false).is_empty(),"Continuous mass is presentation in the existing owner")
  var remaining=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("RubyRegionNativeCaveWall_*","MultiMeshInstance3D",true,false):remaining+=node.multimesh.instance_count
  var expected=Ruby.caves.maps["100"].filter(func(item):return not Ruby.caves.graphics[str(int(item[2]))].get("void_only",false)and not stations.has(Vector3i(item[0],item[1],item[2]))).size()
  check(remaining==expected,"Exactly owned Ruby stations are replaced; other native columns remain")
  game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
  var Population=load("res://scripts/forest/forest_south_kili_population.gd");var zone:Dictionary=Population.zone_at(100,Vector2i(353,367))
  check(int(zone.id)==1055 and zone.groups.any(func(g):return g[0]=="1031"),"Direct wasp party remains tied to its original source zone")
  var party:Array=review.groups[0].party
  for enemy in game.model.enemies.values().duplicate():
   if game.army_runtime.handles.has(enemy.id):game.army_runtime.despawn(game.army_runtime.handles[enemy.id])
   game.model.enemies.erase(enemy.id)
  game.model.waves.snow_pending=[];game.model.waves.snow_group_ids.clear()
  game.paused=false;game.transitioning=false;game.ordinary_pause=false;game.tuning.invincible=true
  game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_pending=party.duplicate(true);game.model.waves.spawn_clock=0
  game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
  check(game.model.enemies.size()==party.size(),"Representative exact source wasp party uses native placement/import")
  check(game.model.enemies.values().all(func(enemy):return enemy.get("source_group","")=="1031"and enemy.get("source_enemy","")in["1029","1030"]and game.army_runtime.handles.has(enemy.id)),"All four rendered wasps retain distinct source identities and native handles")
  game.crowd.present_army(game.army_runtime.render_snapshot(),[])
  study_report={"source_anchors":row.cliffs.size(),"continuous_cells":row.prepared_cells.size(),"chunks":row.prepared_chunks.size(),"remaining_legacy_columns":remaining,"party":party,"native_actors":game.model.enemies.size(),"source_zone":zone.id,"house_owner_trace":house_trace}
 var camera:Camera3D=game.camera_rig.camera;var before:Dictionary=review.cameras[0]
 camera.global_position=str_to_var("Vector3"+before.eye);camera.global_rotation=str_to_var("Vector3"+before.rotation);camera.fov=63.;camera.reset_physics_interpolation()
 for i in 5:await process_frame
 var rays=[]
 for pixel in [Vector2(640,400),Vector2(200,200),Vector2(640,100),Vector2(1100,200),Vector2(100,500),Vector2(1100,650)]:rays.append({"pixel":[pixel.x,pixel.y],"direction":camera.project_ray_normal(pixel)})
 var meshes={};var records=[];var owners:Array[Node]=game.world.map_features.find_children("*","GeometryInstance3D",true,false)
 for node in owners:
  if not node.is_visible_in_tree():continue
  var mesh:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
  if mesh==null:continue
  for instance in (node.multimesh.instance_count if node is MultiMeshInstance3D else 1):
   var pose:Transform3D=node.global_transform*(node.multimesh.get_instance_transform(instance)if node is MultiMeshInstance3D else Transform3D.IDENTITY)
   var bounds=pose*mesh.get_aabb();var matches=rays.filter(func(ray):return bounds.intersects_segment(camera.global_position,camera.global_position+ray.direction*250.))
   if matches.is_empty():continue
   if not meshes.has(mesh):
    var surfaces=[]
    for part in mesh.get_surface_count():surfaces.append(mesh.get_meta("source_surface_arrays")if part==0 and mesh.has_meta("source_surface_arrays")else mesh.surface_get_arrays(part))
    meshes[mesh]=surfaces
   var hits=[];var inverse=pose.affine_inverse();var eye=inverse*camera.global_position
   for ray in matches:
    var direction=inverse.basis*ray.direction;var closest=INF;var triangle=-1;var slot=-1
    for part in meshes[mesh].size():
     var arrays:Array=meshes[mesh][part];var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
     for n in range(0,ids.size()if not ids.is_empty()else vertices.size(),3):
      var hit=Geometry3D.ray_intersects_triangle(eye,direction,vertices[ids[n]if not ids.is_empty()else n],vertices[ids[n+1]if not ids.is_empty()else n+1],vertices[ids[n+2]if not ids.is_empty()else n+2])
      if hit!=null:
       var distance=(pose*hit).distance_to(camera.global_position)
       if distance<closest:closest=distance;triangle=n/3;slot=part
    if triangle>=0:hits.append({"pixel":ray.pixel,"distance":closest,"triangle":triangle,"surface":slot})
   if not hits.is_empty():
    var record={"node":str(node.get_path()),"instance":instance if node is MultiMeshInstance3D else -1,"mesh_bounds":str(mesh.get_aabb()),"world_bounds":str(bounds),"root":[pose.origin.x,pose.origin.y,pose.origin.z],"hits":hits}
    if str(node.name).begins_with("RubyRegionNativeCaveWall_"):
     var serial=int(node.name.get_slice("_",1));var sources=Ruby.caves.maps["100"].filter(func(item):return int(item[2])==serial and not West.source_cliff_owned(game.model,serial,Vector2i(item[0],item[1])))
     record["source_row"]=sources[instance];record["source_graphic"]=Ruby.caves.graphics[str(serial)].duplicate(false);record.source_graphic.erase("profile")
    records.append(record)
 check(not records.is_empty(),"Actual rendered scenery triangles traced at the exact failed camera")
 var label=("scale-calibrated-"if calibrated else"scale-raw-")if comparison else""
 RenderingServer.force_draw();check(root.get_texture().get_image().save_png(REVIEW+(label+"exact.png"if comparison else"wasp-exact-study-after.png"if study else "wasp-exact-owner-before.png"))==OK,"Exact source station/camera diagnostic saved")
 if study:
  var cell=Vector2(359,373);var at=Regions.frame("south_lakes").inverse()*(cell*3.);var destination=game.model.world_point(at,.15)
  check(game.army_runtime.native.can_reach(game.player.position,destination,.5),"Context source station is reachable through unchanged native navigation")
  game.player.position=destination;game.model.hero_position=destination;game.world.sync(0.)
  game.camera_rig.yaw=PI;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.character_screen_offset=0;game.camera_rig.combat_camera_angle=0;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
  for i in 5:await process_frame
  RenderingServer.force_draw();check(root.get_texture().get_image().save_png(REVIEW+(label+"context.png"if comparison else"wasp-source-reachable-context.png"))==OK,"Normal gameplay source-reachable context saved")
  study_report["context"]={"cell":[cell.x,cell.y],"eye":str(camera.global_position),"rotation":str(camera.global_rotation),"fov":camera.fov}
  if comparison:
   cell=Vector2(347,379);at=Regions.frame("south_lakes").inverse()*(cell*3.);destination=game.model.world_point(at,.15)
   check(game.army_runtime.native.can_reach(game.player.position,destination,.5),"House scale context uses an original reachable dry station")
   game.player.position=destination;game.model.hero_position=destination;game.world.sync(0.)
   game.camera_rig.yaw=0.;game.camera_rig.pitch=.14;game.camera_rig.distance=game.ViewPreferences.CAMERA_MAX;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
   for i in 5:await process_frame
   RenderingServer.force_draw();check(root.get_texture().get_image().save_png(REVIEW+label+"house-context.png")==OK,"Fixed normal63house/cliff scale context saved")
   study_report["house_context"]={"cell":[cell.x,cell.y],"eye":str(camera.global_position),"rotation":str(camera.global_rotation),"fov":camera.fov,"house_source_cell":[347,377],"house_source_footprint":[5,4],"height_case":"existing coastal frame"if calibrated else"raw authoring profile"}
 write(REVIEW+(label+"rendered.json"if comparison else"study-rendered.json"if study else "rendered-owner-trace.json"),{"checks":checks,"failures":failures,"camera":before,"player":str(game.player.position),"falan_scale":game.model.falan_scale,"trace":records,"study":study_report,"limits":"Actual scene transforms/meshes and exact failed eye/rotation/FOV. Study is explicitly staged only; native/source/collider preservation is separate from visual acceptance. Hidden caps/depth inferred. Saved views and full engine log require review."})
 game.queue_free();await process_frame
func run():
 if "--prepare-roof"in OS.get_cmdline_user_args():prepare_house_roof()
 elif "--prepare-comparison"in OS.get_cmdline_user_args():
  await prepare_masses();await prepare_masses(true)
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+"Prepared comparison/"))
  check(ResourceSaver.save(load("res://scripts/forest/forest_coastal_buildings.gd").shape(11279),REVIEW+"Prepared comparison/house11279.res")==OK,"Existing whole source house prepared offline without a new model/texture")
 elif "--scale-comparison"in OS.get_cmdline_user_args():await scene_trace(true,false,true);await scene_trace(true,true,true)
 elif "--prepare-mass"in OS.get_cmdline_user_args():await prepare_masses()
 elif "--height-calibration"in OS.get_cmdline_user_args():await height_calibration()
 elif "--default-regression"in OS.get_cmdline_user_args():await default_regression()
 elif "--study"in OS.get_cmdline_user_args():await scene_trace(true)
 elif "--scene-trace"in OS.get_cmdline_user_args():await scene_trace()
 else:await trace_legacy()
 print("FREYJA_CLIFF_TRACE ",checks," checks ",failures," failures")
 quit(1 if failures else 0)

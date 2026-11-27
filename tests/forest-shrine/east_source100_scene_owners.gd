extends "res://tests/forest-shrine/east_region_review.gd"
## Current scene census only. Private native-ground swap adds no scenery/physics.
const AUDIT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Completeness/report.json"
const CANDIDATE="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Candidate/"
const DEST="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Scene Owners/"
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const StreetRuntime=preload("res://scripts/forest/forest_falan_streets.gd")
const Frontier=preload("res://scripts/forest/forest_falan_frontier.gd")
var anchor_cache={}
var all_nodes=[]
var ridge_vertices={}
func input_paths()->Array:return [AUDIT,CANDIDATE+"100.dat",CANDIDATE+"freyja_ground_index.png","res://scripts/forest/forest_falan_frontier.gd","res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_east_road.gd","res://assets/maps/falan/east_region/field-scenery.json","res://assets/maps/falan/freyja_ground_index.png","res://assets/maps/falan/freyja_ground_atlas.png"]
func source_local(cell:Array)->Vector2:return Tour.Regions.frame("east_gate").inverse()*(Vector2(cell[0],cell[1])*3.)
func source_anchor_count(container:Node3D,asset:String,wanted:Vector2)->int:
 var key=str(container.get_instance_id())+asset
 if not anchor_cache.has(key):
  var parts=Assets.source(asset);var anchors=[]
  if not parts.is_empty():
   var part:Dictionary=parts[0]
   for child in container.find_children("*","MultiMeshInstance3D",true,false):
    if child.multimesh.mesh!=part.mesh:continue
    for i in child.multimesh.instance_count:
     var pose:Transform3D=container.global_transform.affine_inverse()*child.global_transform*child.multimesh.get_instance_transform(i)*part.transform.affine_inverse();anchors.append(Vector2(pose.origin.x,pose.origin.z))
  anchor_cache[key]=anchors
 var count=0
 for at:Vector2 in anchor_cache[key]:
  if at.distance_to(wanted)<.025:count+=1
 return count
func generic_ridge_present(road:Node3D,row:Array)->Dictionary:
 var at:Vector2=row[0];var y:float=game.model.surface_height(at.x,at.y)
 if not row[4]:y=maxf(y,game.model.terrain.WATER_HEIGHT-.35)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);Entrances.ridge(tool,Vector3(at.x,y,at.y),row[2],row[3],row[1],row[4]);var arrays=tool.commit_to_arrays();var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var matched=0
 for p:Vector3 in points:
  if ridge_vertices.has((road.global_transform*p).snapped(Vector3.ONE*.001)):matched+=1
 return {"expected_vertices":points.size(),"matched_vertices":matched,"present":not points.is_empty()and matched==points.size()}
func run():
 var hashes={}
 for path in input_paths():hashes[path]=FileAccess.get_sha256(path)
 var captures_only="--captures-only" in OS.get_cmdline_user_args()
 var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(AUDIT));phase="Source100 Scene Owners";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-source100-owners-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID);game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("east_gate")
 for i in 12:await process_frame
 var road:Node3D=game.world.find_child("FreyjaOuterRoads",true,false);var plants:Node3D=game.world.find_child("ArchivedEastGatePlants",true,false);check(road!=null and plants!=null,"Current East world mounts road and detail render owners")
 all_nodes=game.world.find_children("*","Node3D",true,false)
 for node in ([]if captures_only else all_nodes):
  if node is MeshInstance3D and str(node.name)=="ArchivedGateRidges":
   for slot in node.mesh.get_surface_count():
    var arrays=node.mesh.surface_get_arrays(slot)
    for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:ridge_vertices[(node.global_transform*p).snapped(Vector3.ONE*.001)]=true
 var prepared=[];var older=[]
 if captures_only:
  var previous:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEST+"first-scene-census-capture-path-failure.json"));prepared=previous.prepared219;older=previous.older73
  for path in previous.source_hashes:check(FileAccess.get_sha256(path)==previous.source_hashes[path],"Retained scene census source unchanged: "+path)
 var field:Dictionary=Tour.Regions.field_source().east_gate;var mask:Image=game.model.terrain.mask_image();var protected:Array[Vector2]=[]
 for link in game.model.get_meta("falan_links",[]):protected.append(link.at)
 for record:Dictionary in ([]if captures_only else audit.areas.east_gate.missing_raw_pg1):
  var cell:Array=record.cell;var serial=int(record.native_graphic);var at=source_local(cell);var row=record.duplicate(true);var category:Variant=record.prepared_pinned_field_owner
  if category=="trees":
   row.actual_anchor_instances=source_anchor_count(road,Tour.Regions.field_tree_visual(Vector2(cell[0],cell[1]),"tree"),at);row.actual_owner="Current whole-tree batch (visual source fit is separate)";row.present=row.actual_anchor_instances>0;prepared.append(row)
  elif category=="details":
   var source_row:Array=[]
   for d:Array in field.details:
    if int(d[0])==int(cell[0])and int(d[1])==int(cell[1])and int(d[2])==serial:source_row=d;break
   var p=Vector3(at.x,game.model.surface_height(at.x,at.y),at.y);row.scatter_clear=Frontier.east_scatter_clear(mask,game.model.terrain.mask_origin(),at);row.fits=StreetRuntime.fits(game.model,p,1.25,protected);row.actual_anchor_instances=source_anchor_count(plants,str(source_row[3]),at);row.actual_owner="Current generic detail batch; semantic model reuse is not native-art fidelity";row.present=row.actual_anchor_instances>0;prepared.append(row)
  elif category=="ridges":
   var anchor_found=false
   for child in all_nodes:
    if int(child.get_meta("source_graphic",-1))!=serial:continue
    for c:Array in child.get_meta("east_cliff_source_anchors",[]):
     if int(c[0])==int(cell[0])and int(c[1])==int(cell[1]):anchor_found=true;row.actual_owner=str(child.get_path());break
   if anchor_found:row.present=true;row.evidence="Native cliff source-anchor metadata in actual draw batch"
   else:
    var found:Array=[]
    for ridge:Array in Tour.Regions.field_ridges("east_gate"):
     if int(ridge[1])!=serial:continue
     var source=Tour.Regions.frame("east_gate")*ridge[0]/3.-Vector2((ridge[2].y/3.-1.)*.5,-(ridge[2].x/3.-1.)*.5)
     if source.distance_to(Vector2(cell[0],cell[1]))<.025:found=ridge;break
    if not found.is_empty():row.geometry=generic_ridge_present(road,found);row.present=row.geometry.present;row.actual_owner="Actual merged ArchivedGateRidges vertex subset"
    else:row.present=false;row.actual_owner="Unresolved current ridge handoff"
   prepared.append(row)
  else:
   var exact=[];var desired:Vector3=game.model.world_point(at)
   for child in all_nodes:
    var native_id=-1
    for tag in["source_graphic","original_graphic","falan_flower_urn","falan_lamp_graphic","falan_fort_graphic","east_source_graphic"]:
     if child.has_meta(tag):native_id=int(child.get_meta(tag));break
    if native_id!=serial:continue
    if child is MultiMeshInstance3D:
     for index in child.multimesh.instance_count:
      var p:Vector3=(child.global_transform*child.multimesh.get_instance_transform(index)).origin
      if Vector2(p.x,p.z).distance_to(Vector2(desired.x,desired.z))<.035:exact.append({"node":str(child.get_path()),"world":var_to_str(p)})
    elif Vector2(child.global_position.x,child.global_position.z).distance_to(Vector2(desired.x,desired.z))<.035:exact.append({"node":str(child.get_path()),"world":var_to_str(child.global_position)})
   row.exact_native_owner_instances=exact;row.expected_world=var_to_str(desired);row.status="Exact current native-tagged owner found"if not exact.is_empty()else"No exact native-tagged world anchor found; inspect legacy compound/context before enrolling";older.append(row)
 check(prepared.size()==219 and older.size()==73,"Current scene census accounts for219prepared and73older-owner rows without duplicate additions")
 for row:Dictionary in prepared:
  if row.prepared_pinned_field_owner=="trees"and not row.present:
   var at=source_local(row.cell);var p=Vector3(at.x,game.model.surface_height(at.x,at.y),at.y);row.current_disk_clear=game.model.terrain.disk_clear(p,1.2);row.current_plan_anchor=false
   for plan:Array in game.model.falan_frontier_plan:
    if plan[0]is String and Frontier.Scenery.is_tree(plan[0])and Vector2(plan[1].origin.x,plan[1].origin.z).distance_to(at)<.025:row.current_plan_anchor=true
 # Current before/candidate-ground-only images do not add the missing flora.
 for version in["current","private-native-ground-only"]:
  if version!="current":
   var image=Image.load_from_file(ProjectSettings.globalize_path(CANDIDATE+"freyja_ground_index.png"));var texture=ImageTexture.create_from_image(image);var seen={}
   for node in game.world.find_children("*","MeshInstance3D",true,false):
    var mat:Material=node.material_override
    if not mat is ShaderMaterial or mat.get_shader_parameter("use_freyja_surface")!=true:continue
    if mat.get_shader_parameter("freyja_ground_index")!=load("res://assets/maps/falan/freyja_ground_index.png"):continue
    if not seen.has(mat):var clone=mat.duplicate();clone.set_shader_parameter("freyja_ground_index",texture);seen[mat]=clone
    node.material_override=seen[mat]
  for stand:Array in[[636,164],[642,164]]:
   var at=source_local(stand);await position_at(at);var target=source_local([639,160]);var facing=(target-at).normalized();await gameplay_capture("fairy-grove-"+version+"-"+str(stand[0]),"Default.32camera; current versus PRIVATE native-ground only. Missing flora not added; no context/route acceptance.",atan2(-facing.x,-facing.y))
 var changed=[]
 for path in hashes:
  if FileAccess.get_sha256(path)!=hashes[path]:changed.append(path)
 check(changed.is_empty(),"Current field scene owner inputs remain source-current")
 var file=FileAccess.open(DEST+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors,"prepared219":prepared,"older73":older,"captures":captures,"source_hashes":hashes,"source_changed":changed,"scope":"Actual current East scene render-owner census; private ground-index swap only. Presence does not certify appearance, route behavior, allNativecollisions or original sourcefit. No scenery/terrain/quest/productionfiles changed."},"  "));file.close();print("EAST100_SCENE_OWNERS checks=",checks," failures=",errors);await finish()

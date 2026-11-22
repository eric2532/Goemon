extends "res://tests/forest-shrine/falan_city_recovery_test.gd"
const LANDMARK_REVIEW="res://build/Other Files/Asset Toolkit/Falan Landmarks/"
const Details=preload("res://scripts/forest/forest_falan_landmark_details.gd")
const Benches=preload("res://scripts/forest/forest_falan_benches.gd")
const Streets=preload("res://scripts/forest/forest_falan_streets.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const LANDMARKS=[1091,1092,1101,1111,1112,1121]

func review_folder()->String:return LANDMARK_REVIEW

func position_at(p:Vector2):
 await super.position_at(p)
 for i in 4:await physics_frame

func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 if DisplayServer.get_name()=="headless":return
 var stage="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review_folder()+stage))
 game.ui.hide();game.set_process(false);root.grab_focus()
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(review_folder()+stage+"/"+name_+".png")==OK,"Captured "+name_)
 game.set_process(true);game.ui.show()

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var before="--baseline" in OS.get_cmdline_user_args()
 var signature=preload("res://tests/forest-shrine/falan_buildings_props_test.gd").model_signature(game.model)
 if before:
  var file=FileAccess.open(review_folder()+"colliders-before.txt",FileAccess.WRITE);file.store_string(signature)
 else:check(signature==FileAccess.get_file_as_string(review_folder()+"colliders-before.txt"),"Unrelated scenery matches the historical collider baseline")
 var cache=Details.materials.duplicate()
 var benches=Benches.meshes.duplicate()
 if not before:check_details()
 var nodes={}
 for id in LANDMARKS:
  var facade=game.world.find_child("FalanCivicFacade_%d"%id,true,false)
  check(facade!=null,"The original landmark is present: "+str(id))
  if facade==null:continue
  if not before:
   var source:Array=Details.Data.FACADES[id]
   check(facade.get_meta("original_graphic",0)==source[0],"Unique facade retains its original building graphic: "+str(id))
   var panes=facade.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.get_meta("falan_source_feature","")==source[1])
   check(panes.size()>0,"Native leaded windows replace prototype panes: "+str(id))
   for pane in panes:check(pane.material_override==Details.material(source[1]) or pane.material_override.get_shader_parameter("falan_source_projection")==true,"Windows retain native paint under the source-aligned facade material")
  nodes[id]=facade.find_children("*","MeshInstance3D",true,false).size()
  var eye=Vector3(22,17,38) if id==1121 else Vector3(18,13,30)
  await shot("facade-"+str(id),facade.to_global(eye),facade.to_global(Vector3(0,7.5,2)),56)
 print("FALAN_LANDMARK_MESH_NODES ",nodes)
 if not before and DisplayServer.get_name()!="headless":
  var study=Node3D.new();game.world.add_child(study)
  var scale_:float=game.model.falan_scale
  study.position=Vector3(2000,0,2000)*scale_;study.scale=Vector3.ONE*scale_
  var floor_=PlaneMesh.new();floor_.size=Vector2(14,8)
  Geo.mesh(study,floor_,Vector3(0,-.02,0),Geo.mat("81967c"))
  var serials=[10405,10406,10407,10448,10449,10451]
  for i in serials.size():
   var p=Vector3((i%3-1)*3.5,0,(i/3)*3.0-1.5)
   Benches.batch(study,serials[i],[Transform3D(Basis(Vector3.UP,Benches.yaw(serials[i])),p)])
  await shot("bench-study",study.to_global(Vector3(7,7,11)),study.to_global(Vector3(0,.7,0)),50)
  study.queue_free()
  for i in 2:await process_frame
 await super.check_east_il_road()
 if not before:
  for feature in cache:check(is_same(Details.materials[feature],cache[feature]),"Gate returns reuse facade materials")
  for key in benches:check(is_same(Benches.meshes[key],benches[key]),"Gate returns reuse solid bench meshes")
 print("FALAN_LANDMARK_RESULT checks=",checks," failures=",errors)

func check_details():
 var count_=0;var styles={}
 var protected:Array[Vector2]=[]
 for link in game.model.get_meta("falan_links",[]):protected.append(link.at)
 for npc in Tour.NPCS.AREAS.city:protected.append(npc[0])
 var expected=0
 for row in Streets.Data.BENCHES:
  var p=Streets.ground(game.model,row[0])
  if Streets.fits(game.model,p,.85 if Benches.short_seat(row[1]) else 1.47,protected):expected+=1
 for batch in game.world.find_children("*","MultiMeshInstance3D",true,false):
  if not batch.has_meta("falan_bench_graphic"):continue
  var serial:int=batch.get_meta("falan_bench_graphic");styles[serial]=true
  count_+=batch.multimesh.instance_count
  var mesh:Mesh=batch.multimesh.mesh
  check(is_same(mesh,Benches.meshes[Benches.short_seat(serial)]),"Identical benches reuse one solid mesh")
  var bounds=mesh.get_aabb()
  var width=1.37 if Benches.short_seat(serial) else 2.75
  check(bounds.position.x>=-width*.5-.001 and bounds.end.x<=width*.5+.001 and bounds.size.z<=.84 and bounds.end.y<=1.70,"Slats, arms and finials stay in the old bench footprint")
  if DisplayServer.get_name()!="headless":
   for i in batch.multimesh.instance_count:
    var pose:Transform3D=batch.multimesh.get_instance_transform(i)
    check(Streets.Data.BENCHES.any(func(row):return row[1]==serial and row[0].is_equal_approx(Vector2(pose.origin.x,pose.origin.z))),"Every bench keeps its exact original source station")
    check(pose.basis.is_equal_approx(Basis(Vector3.UP,Benches.yaw(serial))),"Bench back follows its original facing family")
 check(count_==expected and count_>20,"All filtered source benches remain: "+str(count_))
 for anchor in Civic.SHELLS:
  var spec:Array=Civic.SHELLS[anchor]
  if spec[0] not in LANDMARKS:continue
  var item:Dictionary=game.model.props[anchor].duplicate()
  item.rotation+=1
  check(Civic.shell(anchor,item).is_empty(),"User-rotated civic markers retain their custom appearance")
  item=game.model.props[anchor].duplicate();item.scale+=.01
  check(Civic.shell(anchor,item).is_empty(),"User-scaled civic markers retain their custom appearance")
 for link in game.model.get_meta("falan_links",[]):
  if link.get("floor",0) not in LANDMARKS:continue
  var at:Vector2=link.at
  var p=Streets.ground(game.model,at)
  check(game.model.terrain.disk_clear(p,.55),"Recovered landmark door remains walkable: "+str(link.floor))
  check(not game.model.scenery_obstacles.values().any(func(box):return box.grow(.55).has_point(p+Vector3.UP*.4)),"Recovered facade leaves the original door aperture clear")
 var metrics={"bench_stations":count_,"bench_styles":styles.keys(),"bench_meshes":{}}
 for key in Benches.meshes:
  var mesh:Mesh=Benches.meshes[key]
  metrics.bench_meshes[str(key)]={"triangles":mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3,"surfaces":mesh.get_surface_count(),"bounds":str(mesh.get_aabb())}
 var file=FileAccess.open(review_folder()+"procedural-meshes.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(metrics,"  "))
 print("FALAN_BENCHES ",count_," styles=",styles.size())

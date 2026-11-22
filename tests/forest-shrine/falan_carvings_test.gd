extends "res://tests/forest-shrine/falan_building_shapes_test.gd"
const Carvings=preload("res://scripts/forest/forest_falan_carvings.gd")
const CARVING_REVIEW="res://build/Other Files/Asset Toolkit/Falan Carvings/"
func review_folder()->String:return CARVING_REVIEW

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var mansion=game.world.find_child("FalanCivicFacade_1301",true,false)
 check(mansion!=null,"The source mansion still owns its city marker")
 if mansion!=null:
  await shot("mansion",mansion.to_global(Vector3(22,19,34)),mansion.to_global(Vector3(0,8.5,0)),57)
  if "--baseline" not in OS.get_cmdline_user_args():await shot("mansion-lantern",mansion.to_global(Vector3(3,19,6)),mansion.to_global(Vector3(0,17.3,0)),45)
 if "--baseline" not in OS.get_cmdline_user_args():
  for row in [[1091,Vector3(14,10,17),Vector3(8.5,7.6,4.8),"office-mask"],[1092,Vector3(14,10,17),Vector3(7.74,6.7,5.3),"guild-relief"]]:
   var facade=game.world.find_child("FalanCivicFacade_%d"%row[0],true,false)
   await shot(row[3],facade.to_global(row[1]),facade.to_global(row[2]),42)
 var mesh_cache=Carvings.meshes.duplicate();var lantern=Carvings.lantern;var valance=Carvings.valance
 await super.check_east_il_road()
 if "--baseline" not in OS.get_cmdline_user_args():
  for key in mesh_cache:check(is_same(Carvings.meshes[key],mesh_cache[key]),"City returns reuse original carving meshes")
  check(is_same(Carvings.lantern,lantern) and is_same(Carvings.valance,valance),"City returns reuse mansion lantern and valance geometry")
 print("FALAN_CARVINGS_RESULT checks=",checks," failures=",errors)

func check_details():
 super.check_details()
 var expected={"office_mask":2,"guild_relief":2,"bank_frieze":4,"mansion_frieze":17,"mansion_window":37,"mansion_portal":2}
 var counts={};var metrics={}
 var lanterns=0;var valances=0
 for node in game.world.find_children("*","MeshInstance3D",true,false):
  if node.has_meta("falan_carving"):
   var feature:String=node.get_meta("falan_carving")
   counts[feature]=counts.get(feature,0)+1
   check(is_same(node.mesh,Carvings.meshes[feature]),"Repeated original carving panels share prepared geometry")
   check(node.material_override==(Carvings.glazing if feature=="mansion_window" else Carvings.paint) or node.material_override.get_shader_parameter("falan_source_projection")==true,"Stone relief and glazing retain native paint under the source-aligned material")
  if node.has_meta("falan_mansion_lantern"):lanterns+=1
  if node.has_meta("falan_mansion_valance"):valances+=1
 check(counts==expected,"Original masks, friezes and mansion glazing replace all selected prototype surfaces")
 check(lanterns==2 and valances==13,"The main mansion has a solid lantern and thirteen scalloped valances")
 check(Carvings.lantern.get_aabb().end.y<=1.121,"The lantern keeps the original saved mansion height")
 for feature in Carvings.meshes:
  var mesh:Mesh=Carvings.meshes[feature]
  var bounds=mesh.get_aabb();var row:Array=Carvings.Data.FEATURES[feature]
  check(bounds.position.z>=-.00001 and bounds.end.z<=float(row[1])+.00001,"Shallow carvings retain their bounded source relief")
  check(bounds.size.x<=1.001 and bounds.size.y<=1.001,"Carving surface remains inside its physical frame")
  if row[1]>0:check(bounds.end.z>.001,"Source carved strokes are real raised geometry")
  var arrays=mesh.surface_get_arrays(0);var valid=true
  for normal:Vector3 in arrays[Mesh.ARRAY_NORMAL]:
   if not normal.is_finite() or normal.z<=0:valid=false
  check(valid,"Carving triangles face outward")
  for uv:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
   if not Rect2(Vector2(row[0].position)/Carvings.Data.ATLAS.get_size(),Vector2(row[0].size)/Carvings.Data.ATLAS.get_size()).has_point(uv):valid=false
  check(valid,"Every carving samples only its own original source patch")
  metrics[feature]={"triangles":mesh.get_faces().size()/3,"surfaces":mesh.get_surface_count(),"bounds":str(bounds),"instances":counts.get(feature,0)}
 var mansion=game.world.find_child("FalanCivicFacade_1301",true,false)
 check(Vector2(mansion.global_position.x,mansion.global_position.z).is_equal_approx(Civic.Mansion.CITY_CENTER*game.model.falan_scale),"Mansion recovery preserves its saved city anchor")
 var links=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("floor",0)==1301)
 check(not links.is_empty(),"The mansion retains its original entry link")
 for link in links:
  var p=Streets.ground(game.model,link.at)
  check(game.model.terrain.disk_clear(p,.55) and not game.model.scenery_obstacles.values().any(func(box):return box.grow(.55).has_point(p+Vector3.UP*.4)),"Mansion carved portico leaves the original threshold clear")
 metrics["lantern_triangles"]=Carvings.lantern.get_faces().size()/3;metrics["valance_triangles"]=Carvings.valance.get_faces().size()/3
 var file=FileAccess.open(CARVING_REVIEW+"carving-meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "))
 print("FALAN_CARVING_MESHES ",JSON.stringify(metrics))

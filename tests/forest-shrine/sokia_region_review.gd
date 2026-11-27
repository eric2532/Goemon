extends "res://tests/forest-shrine/ruby_region_review.gd"
## Use the existing direct-load source comparison harness; no traversal/gameplay edits.
func _initialize():
 review_root="res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/"
 freeze_physics=true
 create_timer(1800).timeout.connect(func():printerr("SOKIA_REGION_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()

func local_point(cell:Vector2)->Vector2:
 if stage.area=="ghana":return Tour.Regions.Sites.VILLAGES.ghana[2]+cell*3.
 return super.local_point(cell)

func source_vector(vector:Vector2)->Vector2:
 return vector if stage.area=="ghana" else super.source_vector(vector)

func isometric(name_:String,cell:Vector2,_span:float):
 await super.isometric(name_,cell,100.)

func landmark_sections()->Array:
 if "--plans-only" in OS.get_cmdline_user_args():return []
 return route.get("approaches",{}).get(stage.key,[])
func gameplay(section:Dictionary):
 if "--landmarks" in OS.get_cmdline_user_args():await isometric(section.key,Vector2(section.at[0],section.at[1]),100.)
 await super.gameplay(section)

func validate_visual_supports():
 super.validate_visual_supports()
 if phase!="Before" and Tour.Regions.Sokia.owns(stage.area):
  var sokia=Tour.Regions.Sokia
  var mouths=sokia.mouths(stage.area,Tour.Regions.frame(stage.area).inverse())
  var expected=mouths.keys().filter(func(c):return not sokia.source_mouth_profile(c).is_empty())
  var nodes=game.world.find_children("UnderseaMouth_*","Node3D",true,false).filter(func(n):return n.get_meta("sokia_native_aperture",false))
  check(nodes.size()==expected.size(),"Every visible source cave aperture is present in this crop")
  for node in nodes:
   check(node.get_meta("archive_cell") in expected,"Native aperture retains its original crossing cell")
   check(node.find_children("*","CollisionObject3D",true,false).is_empty(),"Native recess has no new collision owner")
  check(load("res://assets/materials/forest_stone.gdshader").code.contains("entrance_cuts[3]"),"Shared stone shader remains unchanged")
  var cliffs=game.world.find_child("ArchivedCliffForms",true,false) as MeshInstance3D
  check(cliffs!=null and cliffs.material_override is ShaderMaterial,"Existing solid crag owner remains")
  if cliffs!=null:
   var paint=cliffs.get_active_material(0) as ShaderMaterial
   check(paint.get_shader_parameter("use_cliff_face")==true and paint.get_shader_parameter("cliff_crags")==false,"Local cut shader preserves the existing solid crag paint parameters")
   check(paint.shader.code.contains("entrance_cuts[8]") if mouths.size()>3 else paint.shader==load("res://assets/materials/forest_stone.gdshader"),"Only crops exceeding the old three-mouth capacity use the local shader derivative")
 if "--cliff-sample" in OS.get_cmdline_user_args() and stage.area=="sokia_coast":
  stage.sections=stage.sections.filter(func(s):return s.key in ["10-coast-expanded-001","10-coast-expanded-012","10-coast-expanded-017","10-coast-expanded-020","10-coast-expanded-032","10-coast-expanded-047","10-coast-expanded-055","10-coast-expanded-084"])
 if phase!="Before" and int(stage.floor)==13001:
  check(game.world.map_features.get_meta("ruby_region_native_cave_walls",0)>0,"Great Wind uses the native cliff placements")
  var before=JSON.parse_string(FileAccess.get_file_as_string(review_root+"Before/02-great-wind-geometry.json"))
  var info=Tour.Indoor.floor_info(13001);var bits=Tour.Indoor.walk_mask(13001,info[0],info[2].hex_decode(),game.model.seed_value)
  check(bits.hex_encode().sha256_text()==before.mask_sha256,"Great Wind's existing walking grid is preserved")
  check(game.world.map_features.find_children("*","CollisionShape3D",true,false).size()==before.collision_shapes,"Great Wind's existing collision owners are preserved")
 if phase=="Before" or stage.area!="sokia_coast":return
 var crags=game.world.find_child("ArchivedCliffForms",true,false)
 check(crags!=null,"Native coast anchors reuse the complete solid crag kit")
 check(game.world.find_child("NativeSokiaCliffMass",true,false)==null,"Rejected cliff silhouette extrusions are absent")
 var water_ground=game.world.find_child("WaterWalkingGround",true,false)
 var bounds:Rect2=game.model.terrain.mask_bounds()
 check(water_ground!=null,"The existing water-walking slab remains present")
 if water_ground!=null:
  var shape=water_ground.find_child("*",true,false) as CollisionShape3D
  check(shape!=null and shape.position.is_equal_approx(Vector3(bounds.get_center().x,game.model.terrain.WATER_HEIGHT-.10,bounds.get_center().y)),"Full source water paint preserves the existing water-walking slab position")
  check(shape!=null and shape.shape.size.is_equal_approx(Vector3(bounds.size.x,.20,bounds.size.y)),"Full source water paint preserves the existing water-walking slab dimensions")
 var houses=game.world.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.get_meta("sokia_source_solid",false))
 var expected_houses=Tour.Regions.Sokia.Data.SCENERY[stage.area].filter(func(row):return Tour.Regions.Sokia.solid_building(stage.area,int(row[1]),row[0]))
 check(houses.size()==expected_houses.size(),"Every source coast house uses its existing solid native building owner")
 for cell in [Vector2i(149,201),Vector2i(350,263)]:
  var found=houses.filter(func(n):return n.get_meta("source_cell")==cell)
  check(found.size()==1 and found[0].get_meta("source_graphic")==11289,"One original house at "+str(cell))
  if found.is_empty():continue
  var at=Tour.Regions.frame(stage.area).inverse()*((Vector2(cell)+Vector2(1.5,-2))*3.)
  check(Vector2(found[0].position.x,found[0].position.z).distance_to(at)<.01,"Original house footprint center retained")
  check(found[0].find_children("*","CollisionShape3D",true,false).is_empty(),"Visual house reuse preserves existing source collision")

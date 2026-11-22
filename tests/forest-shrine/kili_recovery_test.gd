extends "res://tests/forest-shrine/falan_landmarks_test.gd"
const KILI_REVIEW="res://build/Other Files/Asset Toolkit/Kili Village Recovery/"
func review_folder()->String:return KILI_REVIEW
func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 await super.shot(name_.replace("/","-"),eye,target,fov,refresh_army)

func collision_signature(added_surface:Node=null)->String:
 var rows=[]
 for body in game.world.map_features.find_children("*","StaticBody3D",true,false):
  if added_surface!=null and added_surface.is_ancestor_of(body):continue
  for node in body.find_children("*","CollisionShape3D",true,false):
   if node.shape!=null:rows.append(var_to_str([body.collision_layer,body.collision_mask,node.global_transform,node.shape.get_class(),node.shape.get_debug_mesh().get_aabb()]))
 rows.sort()
 # The new Falken doorway is tested separately; compare all pre-existing links to their baseline.
 var links=game.model.get_meta("falan_links",[]).filter(func(link):return not link.get("falken_route",false))
 return var_to_str([rows,game.model.scenery_obstacles,game.model.falan_frontier_plan,links]).sha256_text()

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var before="--baseline" in OS.get_cmdline_user_args()
 var saved=JSON.stringify(get_meta("falan_venture"))
 var signatures={}
 await open_area("sokia_coast")
 signatures.coast=collision_signature()
 if not before:check_surroundings()
 await check_kili_coast_road()
 if errors:return
 await open_area("kili")
 signatures.kili=collision_signature()
 if not before:check_surroundings()
 var metrics=[]
 for row in Entrances.Villages.SOURCE.BUILDINGS.kili:
  var node=game.world.find_child("BlueCGVillageBuilding_"+str(row[4]),true,false)
  check(node is MeshInstance3D,"Original Kili building remains: "+str(row[4]))
  if not node is MeshInstance3D:continue
  var bounds:AABB=node.mesh.get_aabb()
  var center=node.to_global(bounds.get_center())
  var span=maxf(bounds.size.x,bounds.size.z)*game.model.falan_scale
  await shot("building-"+str(row[4]),center+Vector3(-1,1.0,1)*span,center,48)
  if not before:
   check_building(node,row[4])
   metrics.append({"serial":row[4],"bounds":str(bounds),"triangles":node.mesh.get_faces().size()/3,"surfaces":node.mesh.get_surface_count()})
 var gate=game.model.world_point(Tour.Regions.KILI_GATE)
 await shot("west-gate-detail",gate+Vector3(-12,12,17),gate+Vector3.UP*2.4,48)
 var arcade=game.world.find_child("BlueCGVillageBuilding_11297",true,false)
 check(arcade is MeshInstance3D,"Original equipment arcade remains open")
 if arcade is MeshInstance3D:
  await shot("shop-arcade",arcade.global_position+Vector3(-17,16,20)*game.model.falan_scale,arcade.global_position+Vector3.UP*3*game.model.falan_scale,48)
  if not before:check_building(arcade,11297)
 if before:
  var file=FileAccess.open(KILI_REVIEW+"collision-before.json",FileAccess.WRITE);file.store_string(JSON.stringify(signatures,"  "))
 else:
  var previous=JSON.parse_string(FileAccess.get_file_as_string(KILI_REVIEW+"collision-before.json"))
  check(signatures.kili==previous.kili,"Village retains original plans, links, collision and walk space")
  var file=FileAccess.open(KILI_REVIEW+"procedural-meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "))
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Kili scenery preserves the saved adventure")
 print("KILI_RECOVERY_RESULT checks=",checks," failures=",errors)

func check_building(node:MeshInstance3D,serial:int):
 check(node.get_meta("source_graphic",0)==serial,"Building retains its archived graphic identity")
 var valid=true
 for surface in node.mesh.get_surface_count():
  var arrays=node.mesh.surface_get_arrays(surface)
  for normal:Vector3 in arrays[Mesh.ARRAY_NORMAL]:
   if not normal.is_finite() or normal.length_squared()<.5:valid=false
 check(valid,"Building surfaces have finite normals")

 check(node.mesh.get_surface_count()==2,"Solid roof details retain a separate original facade surface")
 check(node.mesh.surface_get_material(0)==Entrances.Villages.Buildings.SourceMesh.material(Entrances.Villages.Buildings.Atlas),"Existing original facade paint is preserved")
 var material=node.mesh.surface_get_material(1)
 check(material.get_shader_parameter("base_texture")==Entrances.Villages.Buildings.KiliAtlas and material.get_shader_parameter("atlas_tile_pixels")==128.0,"Roof props use isolated native surface tiles")
 var arrays=node.mesh.surface_get_arrays(1)
 var tiles:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var known=true;var cloth=0;var upward=true
 for i in vertices.size():
  if not tiles[i] in Entrances.Villages.Buildings.KiliSurfaces.TILES.values():known=false
  if tiles[i]==Entrances.Villages.Buildings.KiliSurfaces.TILES.canopy:
   cloth+=1
   if normals[i].y<.8:upward=false
 check(known and tiles.size()==vertices.size(),"Every rooftop surface stays in a known source-paint slot")
 if serial in [11289,11290]:check(cloth>0 and upward,"Canopy cloth faces upward and is visible from the gameplay camera")

func check_surroundings():
 var cliff=game.world.find_child("ArchivedCliffForms",true,false)
 if Tour.area(game.model)=="sokia_coast":
  check(cliff is MeshInstance3D and not cliff.material_override.get_shader_parameter("cliff_crags"),"Sokia approach cliffs use source sandstone rather than Venoa moss")
  check(game.model.falan_frontier_plan.filter(func(row):return row[0]=="sokia_source_collision").size()==Entrances.Sokia.Data.BLOCKS.sokia_coast.size(),"Coast navigation uses the recovered original blocked rectangles")
 elif cliff!=null:check(cliff.material_override.get_shader_parameter("cliff_crags")==true,"Any village cliff keeps the shared source paint")
 var canopies=game.world.find_children("*","MultiMeshInstance3D",true,false).filter(func(node):return node.get_meta("crossgate_tree_part","")=="Canopy")
 check(not canopies.is_empty(),"Original tree families replace generic meadow tree appearances")
 for node in canopies:check(node.material_override.get_shader_parameter("use_source_paint")==true,"Recovered trees retain the shared wind and original leaf paint")
 var walls=game.world.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.has_meta("kili_wall_graphic"))
 check(not walls.is_empty(),"Original gate columns and approach walls use the recovered shared kit")
 for node in walls:
  check(is_same(node.mesh,Entrances.Villages.recovered_walls[node.get_meta("kili_wall_key")]),"Repeated source wall/column shapes reuse one prepared mesh")

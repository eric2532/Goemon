extends "res://tests/forest-shrine/falan_landmarks_test.gd"
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const SHAPE_REVIEW="res://build/Other Files/Asset Toolkit/Falan Building Shapes/"

func review_folder()->String:return SHAPE_REVIEW

func check_east_il_road():
 var bank=game.world.find_child("FalanCivicFacade_1121",true,false)
 if bank!=null:await shot("bank-end",bank.to_global(Vector3(35,19,23)),bank.to_global(Vector3(2,10,0)),51)
 if "--baseline" not in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
  var study=Node3D.new();game.world.add_child(study)
  study.position=Vector3(2000,0,2000)*game.model.falan_scale;study.scale=Vector3.ONE*game.model.falan_scale
  var plane=PlaneMesh.new();plane.size=Vector2(5,4)
  Geo.mesh(study,plane,Vector3(0,-.01,0),Geo.mat("81967c"))
  for i in 3:Geo.mesh(study,Shapes.urn_mesh(),Vector3(i-1,0,0),Civic.Fort.material(Color("a4b4a6"),false))
  await shot("urn-study",study.to_global(Vector3(2.3,1.8,3.8)),study.to_global(Vector3(0,.35,0)),48)
  study.queue_free()
  for i in 2:await process_frame
 var crown=Shapes.bank_wall;var urn=Shapes.urn
 await super.check_east_il_road()
 if "--baseline" not in OS.get_cmdline_user_args():
  check(is_same(Shapes.bank_wall,crown) and is_same(Shapes.urn,urn),"Gate returns reuse the prepared crown and urn meshes")
 print("FALAN_BUILDING_SHAPES_RESULT checks=",checks," failures=",errors)

func check_details():
 super.check_details()
 var metrics={}
 for id in [1091,1101,1121]:
  var facade=game.world.find_child("FalanCivicFacade_%d"%id,true,false)
  var roofs=0
  for node in facade.find_children("*","MeshInstance3D",true,false):
   if not node.has_meta("falan_roof_profile"):continue
   var profile:Array=node.get_meta("falan_roof_profile")
   if profile not in [Shapes.BARREL,Shapes.INN_ROOF]:continue
   roofs+=1
   var arrays=node.mesh.surface_get_arrays(0)
   var valid=true
   for normal:Vector3 in arrays[Mesh.ARRAY_NORMAL]:
    if not normal.is_finite() or normal.y<-.001:valid=false
   check(valid,"Recovered curved roof slopes face outward: "+str(id))
  check(roofs>0,"Original rounded roof family reaches landmark "+str(id))
 var bank=game.world.find_child("FalanCivicFacade_1121",true,false)
 var solids=bank.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.has_meta("falan_solid_detail"))
 check(solids.size()==8,"Both bank ends use solid crowns, moulding and circular galleries")
 for node in solids:
  var name_:String=node.get_meta("falan_solid_detail")
  if not metrics.has(name_):metrics[name_]=mesh_metrics(node.mesh)
  if name_=="scroll_wall":check(is_same(node.mesh,Shapes.bank_wall),"Both bank ends share the same prepared solid")
 check(Shapes.bank_gallery.get_aabb().end.z+10.24<=11.75,"Gallery columns remain inside the saved bank footprint")
 var faces:PackedVector3Array=Shapes.bank_wall.get_faces()
 var volume=0.0
 for i in range(0,faces.size(),3):volume-=faces[i].dot(faces[i+1].cross(faces[i+2]))/6.0
 var outline=[Vector2(-7.35,0)]+Shapes.CROWN+[Vector2(7.35,0)]
 var area=0.0
 for i in outline.size():area+=outline[i].cross(outline[(i+1)%outline.size()])*.5
 check(is_equal_approx(volume,absf(area)*1.01),"Curved crown is closed solid geometry with outward triangle winding")
 var urns=0
 for node in game.world.find_children("*","MeshInstance3D",true,false):
  if not node.has_meta("falan_flower_urn"):continue
  urns+=1
  check(is_same(node.mesh,Shapes.urn_mesh()),"Flower urns share a single prepared fluted mesh")
  var serial:int=node.get_meta("falan_flower_urn")
  check(Streets.Data.FLOWERS.any(func(row):return row[1]==serial and row[0].is_equal_approx(Vector2(node.position.x,node.position.z))),"Flower urn retains its exact source station")
 check(urns>0,"Native urn geometry replaces the city's plain cylinder pots")
 var bounds=Shapes.urn.get_aabb()
 check(bounds.position.y>=0 and bounds.end.y<=.741 and bounds.size.x<=.981 and bounds.size.z<=.981,"Carved urn retains the previous pot height and footprint")
 var urn_faces:PackedVector3Array=Shapes.urn.get_faces()
 var outward=true
 for i in range(0,urn_faces.size(),3):
  var center=(urn_faces[i]+urn_faces[i+1]+urn_faces[i+2])/3.0
  var normal=(urn_faces[i+2]-urn_faces[i]).cross(urn_faces[i+1]-urn_faces[i])
  if center.y>.27 and center.y<.61 and normal.dot(Vector3(center.x,0,center.z))<=0:outward=false
 check(outward,"Fluted bowl sides face outward")
 metrics["urn"]=mesh_metrics(Shapes.urn);metrics["urn_stations"]=urns
 var file=FileAccess.open(SHAPE_REVIEW+"building-meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "))
 print("FALAN_BUILDING_MESHES ",JSON.stringify(metrics))

func mesh_metrics(mesh:Mesh)->Dictionary:
 return {"triangles":mesh.get_faces().size()/3,"surfaces":mesh.get_surface_count(),"bounds":str(mesh.get_aabb())}

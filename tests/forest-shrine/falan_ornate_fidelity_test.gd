extends "res://tests/forest-shrine/falan_fidelity_test.gd"

func review_folder()->String:return "res://build/Other Files/Asset Toolkit/Falan Ornate Fidelity/"

func capture(model:Node3D,key:String,points:Array[Vector3]):
 if key.begins_with("house_"):
  var profile=Architecture.HouseParts.source_roof_profile(4.8,6.0,5)
  check(profile.size()>=12,"Roof keeps the recovered curved gable controls")
  var left=(profile[1]-profile[0]).normalized();var middle=(profile[5]-profile[4]).normalized()
  check(absf(left.cross(middle))>.4,"Roof has curved eaves and a steep crown rather than straight A slopes")
  var material:ShaderMaterial=model.mesh.surface_get_material(0)
  check(material.get_shader_parameter("architecture_facade")==true,"Only prepared building facades receive stone joints")
  var arrays=model.mesh.surface_get_arrays(0);var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR];var tiles:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
  var valid=true
  for i in colors.size():
   if tiles[i] in [Architecture.HouseParts.Data.TILES["10003_window"],Architecture.HouseParts.Data.TILES.shop_medallion,Architecture.HouseParts.Data.TILES.shop_shield] and colors[i].a>.5:valid=false
  check(valid,"Masonry cannot cover original windows and ornaments")
  var skin=Architecture.HouseParts.SourceMesh.new([],Architecture.Atlas,.045);skin.tiles=Architecture.HouseParts.Data.TILES
  Architecture.HouseParts.source_10003_beam(skin,0,profile,"10006_roof")
  var cap:Mesh=skin.finish();var normals:PackedVector3Array=cap.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
  var tops=0
  for normal in normals:
   if normal.y>.7:tops+=1
  check(tops>60 and cap.get_aabb().size.z>=1.2,"Rounded roof caps have visible upward faces and solid width")
 if key=="civic_1121":
  var frames=model.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.has_meta("falan_bank_moulding"))
  check(frames.size()>=10,"Bank windows and portal have actual raised stone mouldings")
  check(is_same(Civic.Shapes.bank_frame(1.56,3.27),Civic.Shapes.bank_frame(1.56,3.27)),"Repeated bank mouldings share their prepared mesh")
  check(Civic.Carvings.Data.FEATURES.bank_frieze[1]>=.15,"Original frieze has visible sculpted depth")
  check(Civic.Carvings.meshes.bank_frieze.get_faces().size()/3>=7000,"Bank frieze retains its native pixel relief samples")
  var target=Fit.Data.FITS["civic_1121"]*Vector3(10.6,14.8,0)
  camera.size=16;camera.position=target+Vector3(28,10,12);camera.look_at(target)
  await shot("bank-stonework-close")
 await super.capture(model,key,points)

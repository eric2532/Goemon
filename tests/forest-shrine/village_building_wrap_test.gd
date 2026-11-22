extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
const Surfaces=preload("res://assets/maps/falan/village_building_surfaces.gd")

func check_il_habaru_alyut():
 game.tuning.invincible=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"Building Wrap"))
 for row in [["east_coast",2000,"il_village",8,6],["north_coast",2400,"alyut",5,5]]:
  await open_area(row[0])
  await site(row[1],row[2])
  village_entries(row[4])
  var houses=game.world.find_children("BlueCGVillageBuilding_*","MeshInstance3D",true,false)
  check(houses.size()==row[3],"Every original village building remains present")
  var seen={}
  for house in houses:
   check(house.scale==Vector3.ONE,"Fitting is baked before texture coordinates are measured")
   check_uvs(house)
   var serial:int=house.get_meta("source_graphic")
   if seen.has(serial):continue
   seen[serial]=true
   if DisplayServer.get_name()=="headless":continue
   var size_:Vector3=house.mesh.get_aabb().size*game.model.falan_scale
   var radius=maxf(maxf(size_.x,size_.z),size_.y)*1.12+8
   var target:Vector3=house.global_position+Vector3.UP*size_.y*.47
   for i in 4:
    var angle=PI*.25+i*PI*.5
    var eye=target+Vector3(sin(angle)*radius,radius*.47,cos(angle)*radius)
    await shot("Building Wrap/"+row[2]+"-"+str(serial)+"-"+str(i),eye,target,60)
  for id in ([2001,2002,2010,2012,2013,2014] if row[2]=="il_village" else [2401,2420,2410,2421,2412]):
   await room(id)
   await room(row[1])
 print("VILLAGE_BUILDING_WRAP_RESULT failures=",errors)

func check_uvs(house:MeshInstance3D):
 var mesh:Mesh=house.mesh
 check(mesh.surface_get_material(0).get_shader_parameter("atlas_tile_pixels")==128.0,"Buildings use isolated rectified paint tiles")
 var arrays:Array=mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var tiles:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 check(tiles.size()==vertices.size(),"Every surface identifies its own paint patch")
 var repeats=0
 var features=0
 for i in range(0,vertices.size(),3):
  if (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length_squared()<.000001:continue
  check(tiles[i]==tiles[i+1] and tiles[i]==tiles[i+2],"A face cannot interpolate into adjacent atlas paint")
  var name_:String=Surfaces.TILES.find_key(tiles[i])
  if name_=="blue_roof":check(normals[i].y>0,"The blue roof terrace faces upward")
  if name_=="round_window":
   var center=(vertices[i]+vertices[i+1]+vertices[i+2])/3.0
   check(Vector2(center.x,center.z).dot(Vector2(normals[i].x,normals[i].z))>0,"Round-house windows face outward on every side")
  if name_ in ["window","door","round_window","church_window","medallion","canopy"]:
   if uvs[i].is_equal_approx(Vector2(.0001,.9999)) and uvs[i+1].is_equal_approx(Vector2(.0001,.0001)):
    var height=vertices[i].distance_to(vertices[i+1])
    var width=vertices[i+1].distance_to(vertices[i+2])
    if name_!="canopy":check(absf(height-width)<.003,"Recovered windows and doors preserve aspect after fitting")
    features+=1
   continue
  var pitch={"plaster":.45,"timber":2.0,"trim":.35,"stone":.9,"thatch":2.0,"round_thatch":2.0,"blue_roof":2.0,"dormer_cap":.75}.get(name_,1.5)
  for edge in [[0,1],[1,2]]:
   var length_:float=vertices[i+edge[0]].distance_to(vertices[i+edge[1]])
   var uv_length:float=uvs[i+edge[0]].distance_to(uvs[i+edge[1]])
   check(absf(length_-uv_length*pitch)<.003,"Wall and roof texel density stays constant in every direction")
  repeats+=1
 check(repeats>20 and features>4,"The solid walls and roofs have independent paint and fitted architectural details")

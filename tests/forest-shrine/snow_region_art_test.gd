extends SceneTree
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Art=preload("res://scripts/forest/forest_abanis_village_art.gd")
const Route=preload("res://scripts/forest/forest_university_route_art.gd")
var checks=0
var failures=0

func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("SNOW_ART_FAIL ",label_)

func _initialize():
 var review="res://build/Other Files/Asset Toolkit/Snow Region Cleanup/" if "--cleanup" in OS.get_cmdline_user_args() else "res://build/Other Files/Asset Toolkit/Snow Region/"
 var inventory=[]
 for serial in Art.IDS:
  var mesh=Art.mesh(serial,Original.Art.data().graphics[str(serial)])
  check(mesh==Art.mesh(serial,Original.Art.data().graphics[str(serial)]),"Repeated house uses cached mesh")
  check(mesh.get_surface_count()>2 and mesh.get_aabb().size.y>4,"Solid house and snow depth "+str(serial))
  for slot in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(slot)
   check(arrays[Mesh.ARRAY_VERTEX].size()%3==0,"Complete triangles")
   check(Array(arrays[Mesh.ARRAY_VERTEX]).all(func(v):return v.is_finite()),"Finite prepared vertices")
   check(mesh.surface_get_material(slot)!=null,"Prepared material")
  check(not Art.owns(4000,serial) and not Art.owns(4200,serial),"Other town palettes are isolated")
  var triangles=0
  for slot in mesh.get_surface_count():triangles+=mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX].size()/3
  inventory.append({"graphic":serial,"surfaces":mesh.get_surface_count(),"triangles":triangles,"bounds":str(mesh.get_aabb()),"use":"Explore snow-town scenery only; shared prepared mesh"})
 for source in [4000,400,402,4300,4400,15522]:
  for row in Route.catalog().maps[str(source)].placements:
   var cell=Vector2i(row[0],row[1]);var serial=int(row[2])
   check(Route.contains(source,cell),"Every prepared anchor belongs to its bounded scope")
   if not Route.owns(source,serial,cell) or serial==10604 or source==4000 and Original.Forms.Cliffs.continuous(serial):continue
   var mesh=Route.mesh(source,serial,Original.Art.data().graphics[str(serial)])
   check(mesh!=null and mesh.get_aabb().size.length()>0,"Source-backed scenery remains solid "+str(serial))
 for key in JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/snow_region/surfaces.json")).floors:
  var serial=int(key);var g:Dictionary=Original.Art.data().graphics[key]
  check(Art.floor_owns(14000,serial,Vector2i.ZERO,false),"Prepared floor is reusable")
  var mesh=Art.floor_mesh(serial,g,load(Original.Art.ROOT+Original.Art.data().pages[int(g.page)]))
  check(mesh==Art.floor_mesh(serial,g,load(Original.Art.ROOT+Original.Art.data().pages[int(g.page)])),"Prepared ground mesh cached")
  var rectangle:Array=Art.surfaces.floors[key].rect
  var rect=Rect2(rectangle[0]-.01,rectangle[1]-.01,rectangle[2]+.02,rectangle[3]+.02)
  check(Array(mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]).all(func(uv):return rect.has_point(uv*Art.GROUND.get_size())),"Native floor UVs stay in their own prepared tile")
 for serial in [11411,11412,11415]:
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var w=float(g.footprint[0])*3*.84;var d=float(g.footprint[1])*3*.82
  var c=Vector3((float(g.footprint[0])*3-3)*.5,0,(3-float(g.footprint[1])*3)*.5)
  var normal=Vector3.BACK if serial==11411 else Vector3.LEFT
  var doorway=c+normal*((d if normal==Vector3.BACK else w)*.5+.05)
  if serial==11411:doorway.x=3.0
  elif serial==11415:doorway.z=minf(2.0,c.z+d*.5-1.3)
  var windows=Art.facade_windows(c,w,d,doorway,normal)
  check(windows.size()>=3,"House retains readable windows")
  for item in windows:
   var tangent=Vector3.UP.cross(item[1]);var half=(d if absf(item[1].x)>.5 else w)*.5
   check(absf((item[0]-c).dot(tangent))+.87<half,"Window frame is supported by its wall")
   if item[1]==normal:check(absf((item[0]-doorway).dot(tangent))>=2,"Window clears the entrance arch")
 for serial in [11622,11623,11624]:
  var native=Original.WestScenery.sapling(serial);var calm=Original.WestScenery.sapling(serial,true)
  var parts=[]
  for slot in calm.get_surface_count():
   var points=PackedVector3Array()
   var arrays=calm.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX]
   if indices!=null and not indices.is_empty():
    for index in indices:points.append(arrays[Mesh.ARRAY_VERTEX][index])
   else:points.append_array(arrays[Mesh.ARRAY_VERTEX])
   parts.append(points)
  var original:PackedVector3Array=native.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var branch_count=original.size()-parts[1].size()
  check(parts[0].slice(0,branch_count)==original.slice(0,branch_count),"Original sapling branches preserved")
  check(parts[1]==original.slice(branch_count),"Every snow clump retains its original outline and placement")
  check(calm.get_meta("snow_twig_connections",0)>0,"Detached snow clumps have connecting twigs")
  check(calm==Original.WestScenery.sapling(serial,true),"Clean sapling is shared")
 var poses=JSON.parse_string(FileAccess.get_file_as_string(review+"Before/cameras.json"))
 var seen={}
 for pose in poses:
  var id=int(pose.floor)
  if seen.has(id):continue
  seen[id]=true
  var state=Original.state(id,341)
  check(state.raw.hex_encode().sha256_text()==pose.raw,"All source planes preserved "+str(id))
  check(state.bits.hex_encode().sha256_text()==pose.bits,"Walk mask preserved "+str(id))
 check(seen.size()==11,"Every in-scope map checked")
 var file=FileAccess.open(review+"procedural-art-inventory.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(inventory,"  "));file.close()
 print("SNOW_ART_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

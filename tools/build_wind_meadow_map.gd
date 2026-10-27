extends SceneTree
const Layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
var SCALE=3.0 if "--large" in OS.get_cmdline_user_args() else 2.0
var EXTENT=240.0*SCALE
var DIR="res://assets/maps/wind_meadow/castles_large/" if SCALE==3.0 else "res://assets/maps/wind_meadow/castles/"
func _initialize():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
 var heights=PackedFloat32Array();var covered=PackedByteArray();var bridges=PackedByteArray()
 var width=int(160*SCALE)+1;var spacing=3.0
 for z in width:
  for x in width:heights.append(Layout.surface(x*spacing-EXTENT,z*spacing-EXTENT,SCALE));covered.append(1);bridges.append(0)
 var field=Resource.new();field.set_meta("width",width);field.set_meta("spacing",spacing);field.set_meta("heights",heights);field.set_meta("covered",covered);field.set_meta("bridges",bridges)
 assert(ResourceSaver.save(field,DIR+"surface.res")==OK)
 var vertices=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
 for z in width:
  for x in width:vertices.append(Vector3(x*spacing-EXTENT,heights[z*width+x],z*spacing-EXTENT));uv.append(Vector2(x,z)/(width-1))
 for z in width-1:
  for x in width-1:
   var i=z*width+x;indices.append_array(PackedInt32Array([i,i+1,i+width,i+1,i+width+1,i+width]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var raw=ArrayMesh.new();raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var st=SurfaceTool.new();st.create_from(raw,0);st.generate_normals();var mesh=st.commit()
 assert(ResourceSaver.save(mesh.create_trimesh_shape(),DIR+"collision.res")==OK)
 # A coarse render-only apron hides the square field edge beyond the cliff rim.
 var apron=SurfaceTool.new();apron.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in range(int(-EXTENT*1.5),int(EXTENT*1.5),12):
  for x in range(int(-EXTENT*1.5),int(EXTENT*1.5),12):
   if x>=-EXTENT and x<EXTENT and z>=-EXTENT and z<EXTENT:continue
   for p in [Vector2(x,z),Vector2(x+12,z),Vector2(x,z+12),Vector2(x+12,z),Vector2(x+12,z+12),Vector2(x,z+12)]:
    var h=lerpf(Layout.surface(p.x,p.y,SCALE),-22,smoothstep(EXTENT,EXTENT*1.5,maxf(absf(p.x),absf(p.y))))
    apron.add_vertex(Vector3(p.x,h,p.y))
 apron.generate_normals();apron.commit(mesh)
 assert(ResourceSaver.save(mesh,DIR+"terrain.res")==OK)
 var mask=Image.create(512,512,false,Image.FORMAT_RGB8)
 for z in 512:
  for x in 512:
   var p=Vector2(x,z)/511.0*EXTENT*2-Vector2.ONE*EXTENT
   var road=1-smoothstep(6,12,Layout.road_distance(p,SCALE))
   # The square courtyard and all four gate approaches share the same worn earth.
   road=maxf(road,(1-smoothstep(48,57,absf(p.x)))*(1-smoothstep(48,57,absf(p.y))))
   for i in 4:
    var camp:Vector3=Layout.clearings(SCALE)[i];var delta=p-Vector2(camp.x,camp.z)
    if i%2:delta=Vector2(delta.y,delta.x)
    road=maxf(road,(1-smoothstep(42,49,absf(delta.x)))*(1-smoothstep(30,37,absf(delta.y))))
   mask.set_pixel(x,z,Color(road,0,0))
 assert(mask.save_png(ProjectSettings.globalize_path(DIR+"roads.png"))==OK)
 var map=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow.json"))
 map.title="Large Wind Meadow Valley" if SCALE==3.0 else "Wind Meadow Valley";map.terrain_scale=SCALE;map.terrain_source="wind_meadow";map.ramparts=[];map.trees=[];map.roads=[];map.portals=[]
 for i in 4:
  var p:Vector3=Layout.clearings(SCALE)[i];map.portals.append({"x":int(p.x/6),"z":int(p.z/6),"rotation":[2,3,0,1][i]})
 for z in range(int(-35*SCALE),int(35*SCALE)+1):
  for x in range(int(-35*SCALE),int(35*SCALE)+1):
   var p=Vector2(x*6,z*6)
   if Layout.road_distance(p,SCALE)<15:map.roads.append({"x":x,"z":z})
 var rng=RandomNumberGenerator.new();rng.seed=71023
 for z in range(int(-32*SCALE),int(32*SCALE)+1,2):
  for x in range(int(-32*SCALE),int(32*SCALE)+1,2):
   var p=Vector2(x*6,z*6)
   if p.length()<90 or p.length()>188*SCALE or Layout.road_distance(p,SCALE)<24:continue
   var clear=true
   for camp in Layout.clearings(SCALE):
    if p.distance_to(Vector2(camp.x,camp.z))<85:clear=false
   var h=Layout.surface(p.x,p.y,SCALE)
   for delta in [Vector2(-3,-3),Vector2(3,-3),Vector2(-3,3),Vector2(3,3)]:
    if absf(Layout.surface(p.x+delta.x,p.y+delta.y,SCALE)-h)>.6:clear=false
   if clear and rng.randf()<.38:map.trees.append({"x":x,"z":z,"scale":rng.randf_range(.85,1.25)})
 # A single larger tree on the inner northwest shoulder is visible across lawns.
 map.trees.append({"x":Layout.LANDMARK.x,"z":Layout.LANDMARK.y,"scale":2.0})
 var file=FileAccess.open("res://assets/maps/forest_wind_meadow_large.json" if SCALE==3.0 else "res://assets/maps/forest_wind_meadow.json",FileAccess.WRITE);file.store_string(JSON.stringify(map,"  "));file.close()
 print("WIND_MEADOW_BAKED field=",heights.size()," triangles=",indices.size()/3," trees=",map.trees.size()," road_cells=",map.roads.size())
 quit()

extends SceneTree
## Every recovered fixed room and native graphic, without character/combat setup.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const OUT="res://build/Other Files/Asset Toolkit/Shalena Recovery/Completeness/"
var checks=0
var failures=0

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("NATIVE_ASSET_FAIL ",message)

func _initialize():
 create_timer(420).timeout.connect(func():printerr("NATIVE_ASSET_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 var catalog=Original.Art.data();var graphics={};var maps=[];var families={};var geometry={}
 var stage=Node3D.new();var material=StandardMaterial3D.new()
 Geo.box(stage,Vector3.ZERO,Vector3.ONE,material)
 var triangle=SurfaceTool.new();triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
 for p in [Vector3.ZERO,Vector3.UP,Vector3.RIGHT]:triangle.set_normal(Vector3.BACK);triangle.add_vertex(p)
 Geo.mesh(stage,triangle.commit(),Vector3.RIGHT*2,material)
 var joined=Original.Forms.append_fitted(null,stage,3,1,1,Vector3.ZERO)
 var joined_arrays=joined.surface_get_arrays(0)
 var joined_indices=joined_arrays[Mesh.ARRAY_INDEX]
 check((joined_indices.size() if joined_indices is PackedInt32Array and not joined_indices.is_empty() else joined_arrays[Mesh.ARRAY_VERTEX].size())==39,"Furnishing merge keeps both an indexed box and raw profile triangle sharing one material")
 var expected_families={11456:"detail_snow_boards",11457:"detail_snow_boards",11458:"detail_snow_boards",11459:"detail_snow_boards",11454:"detail_snow_log_deck",11465:"detail_snowman",11482:"detail_open_trough",11483:"detail_open_trough",11486:"detail_snow_bench",11487:"detail_snow_bench",16277:"detail_cards",16278:"detail_tea",17632:"detail_armor_stand"}
 for serial in expected_families:
  check(Original.Forms.kind(serial,false,catalog.graphics[str(serial)])==expected_families[serial],"Recovered source silhouette keeps its identified object type "+str(serial))
 for path in catalog.maps:
  var source:Dictionary=catalog.maps[path]
  if source.id>=700000:continue
  maps.append(int(source.id))
  var count_=int(source.size[0])*int(source.size[1]);var raw=Original.Art.raw_map(path)
  for i in count_:
   var serial=raw.decode_u16(20+(count_+i)*2)
   if serial<1000:continue
   var g:Dictionary=catalog.graphics[str(serial)]
   var family=Original.Forms.kind(serial,false,g)
   families[family]=families.get(family,0)+1
   if graphics.has(serial):continue
   graphics[serial]=family
   check(family!="prop","Native graphic has an identified family "+str(serial))
   if family in ["void","tree","flowers"] or serial==10604:continue
   var texture:Texture2D=load(Original.Art.ROOT+catalog.pages[int(g.page)]) if family in ["floor","water","detail_flat_panel"] else Original.Art.solid_texture(int(g.page))
   if family=="rock" or family=="wall" and serial in Original.Forms.WALLS:texture=Original.Art.surface_texture(int(g.surfaces[0]))
   var mesh=Original.Forms.mesh(serial,family,g,texture)
   check(mesh!=null and mesh.get_surface_count()>0,"Native mesh contains surfaces "+str(serial))
   var valid=true;var triangles=0
   for slot in mesh.get_surface_count():
    var arrays=mesh.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX]
    triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
    for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:valid=valid and p.is_finite()
   geometry[serial]={"family":family,"surfaces":mesh.get_surface_count(),"triangles":triangles,"bounds":str(mesh.get_aabb())}
   if serial in [11454,11455,11456,11457,11458,11459,11465,11482,11483,11486,11487,16277,16278,17045,17632,16515,16516,17506]:
    var low=Vector2.INF;var high=-low
    for slot in mesh.get_surface_count():
     for p:Vector3 in mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]:
      var pixel=Vector2((p.x+p.z)*32.0/3.0,(p.z-p.x)*8.0-p.y/Original.Forms.HEIGHT_PER_PIXEL)
      low=low.min(pixel);high=high.max(pixel)
    check(absf(low.x-float(g.origin[0]))<.01 and absf(high.x-float(g.origin[0]+g.rect[2]))<.01,"Fitted solid preserves the native horizontal silhouette and anchor "+str(serial))
    if serial==11465:check(mesh.get_aabb().size.y>mesh.get_aabb().size.z,"Snowman retains rounded body volume instead of flattened sprite proportions")
    else:check(absf(low.y-float(g.origin[1]))<.01,"Fitted solid retains the original silhouette's highest point "+str(serial))
   if serial in [11457,11458,11482,11483,11486,11487]:
    var size_=mesh.get_aabb().size
    check(maxf(size_.x,size_.z)>minf(size_.x,size_.z)*3,"Elongated plank/trough/bench does not stretch across a square collision cell "+str(serial))
    if serial in [11457,11458]:check((size_.z>size_.x)==(serial==11457),"Opposite snowy plank facings retain their source axes "+str(serial))
    if serial in [11482,11483,11486,11487]:check((size_.z>size_.x)==(serial in [11482,11487]),"Trough and bench facings follow their original long axes "+str(serial))
   if serial==17683:check(mesh.get_aabb().size.x>9 and absf(mesh.get_aabb().get_center().x-3)<.1,"Three-cell passage arch keeps its original span and middle-cell centre")
   if serial in [11496,11497]:
    var vertices:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var low=INF;var high=-INF
    for p:Vector3 in vertices:low=minf(low,p.y);high=maxf(high,p.y)
    check(high-low<40*Original.Forms.Details.Harbor.PIXEL_HEIGHT,"Native arrow board retains its source-height pixel budget independently of the post "+str(serial))
   check(valid,"Native mesh vertices are finite "+str(serial))
 check(Original.Forms.kind(17526,false,catalog.graphics["17526"])=="civic_pew","Auditorium seats remain seats, separate from music-room pianos")
 var built=[]
 for id in maps+[51009,51010]:
  print("NATIVE_BUILD_ROOM ",id)
  var state=Original.state(id,341);var bytes:PackedByteArray=state.raw.duplicate();var bits:PackedByteArray=state.bits.duplicate()
  var scene=Node3D.new();root.add_child(scene)
  Original.build(scene,id,341)
  check(scene.get_meta("recovered_source_map")==Original.source_id(id),"Correct source room built "+str(id))
  check(scene.get_meta("recovered_solid_placements",0)>0,"Recovered room has solid scenery "+str(id))
  check(scene.find_children("*","Sprite3D",true,false).is_empty(),"Recovered room uses 3D geometry "+str(id))
  check(state.raw==bytes and state.bits==bits,"Art build preserves source cells and walking mask "+str(id))
  var gpu_transforms=DisplayServer.get_name()!="headless"
  var openings:Array=scene.get_meta("recovered_floor_openings",[])
  var placed={};var shared={};var stable=true;var actual_counts={};var expected_counts={};var expected_positions={}
  var cells=state.size.x*state.size.y
  for layer in 2:
   for i in cells:
    if layer==0 and Vector2i(i%state.size.x,i/state.size.x) in openings:continue
    var serial=state.raw.decode_u16(20+(layer*cells+i)*2)
    if serial<1000 or serial==10604:continue
    var family=Original.Forms.kind(serial,layer==0,catalog.graphics[str(serial)])
    if family in ["void","tree","flowers","floor","water","detail_flat_panel"]:continue
    expected_counts[serial]=expected_counts.get(serial,0)+1
    var key=Vector3i(i%state.size.x,i/state.size.x,serial)
    expected_positions[key]=expected_positions.get(key,0)+1
  for batch:MultiMeshInstance3D in scene.find_children("RecoveredShalenaSolid_*","MultiMeshInstance3D",false,false):
   var serial:int=batch.get_meta("source_graphic")
   if shared.has(serial):stable=stable and shared[serial]==batch.multimesh.mesh
   shared[serial]=batch.multimesh.mesh
   actual_counts[serial]=actual_counts.get(serial,0)+batch.multimesh.instance_count
   # Dummy rendering discards instance transforms; desktop verification reads them.
   if not gpu_transforms:continue
   for i in batch.multimesh.instance_count:
    var p:Vector3=batch.position+batch.multimesh.get_instance_transform(i).origin
    var tile=(Vector2(p.x,p.z)-state.origin)/3
    stable=stable and tile.distance_to(tile.round())<.0001
    var cell=Vector2i(tile.round());var source_serial=state.raw.decode_u16(20+(state.size.x*state.size.y+cell.y*state.size.x+cell.x)*2)
    stable=stable and source_serial==serial
    placed[Vector3i(cell.x,cell.y,serial)]=placed.get(Vector3i(cell.x,cell.y,serial),0)+1
  check(stable,"Spatial batches share meshes and preserve native anchors where transform readback is available "+str(id))
  check(actual_counts==expected_counts,"Spatial splitting retains every source prop exactly once per layer "+str(id))
  if gpu_transforms:check(placed==expected_positions,"Rendered batch transforms match all original source cells "+str(id))
  var covered=false
  if not openings.is_empty():
   for ground:MeshInstance3D in scene.find_children("RecoveredShalenaGround","MeshInstance3D",false,false):
    var vertices:PackedVector3Array=ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for i in range(0,vertices.size(),3):
     if not is_equal_approx(vertices[i].y,.012):continue
     var mid=(vertices[i]+vertices[i+1]+vertices[i+2])/3
     var cell=Vector2i(((Vector2(mid.x,mid.z)-state.origin)/3).round())
     if cell in openings:covered=true;break
  check(not covered,"Descending stairs and pits are not covered by floor triangles "+str(id))
  var bed=scene.get_node_or_null("RecoveredSnowBed")
  var snow_covers=false
  if bed!=null and gpu_transforms:
   for batch:MultiMeshInstance3D in bed.find_children("*","MultiMeshInstance3D",true,false):
    for i in batch.multimesh.instance_count:
     var bounds=batch.multimesh.get_instance_transform(i)*batch.multimesh.mesh.get_aabb();bounds.position+=batch.position
     for cell:Vector2i in openings:
      var p=state.origin+Vector2(cell)*3
      snow_covers=snow_covers or bounds.has_point(Vector3(p.x,-.13,p.y))
  check(not snow_covers,"Snow backing also leaves descending steps visible "+str(id))
  built.append({"id":id,"source":Original.source_id(id),"openings":openings.size()})
  scene.free()
  await process_frame
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var file=FileAccess.open(OUT+"all-rooms.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"graphics":graphics.size(),"geometry":geometry,"families":families,"rooms":built,"gpu_transform_checks":DisplayServer.get_name()!="headless","checks":checks,"failures":failures},"  "));file.close()
 print("NATIVE_ASSET_RESULT graphics=",graphics.size()," rooms=",built.size()," checks=",checks," failures=",failures)
 quit(1 if failures else 0)

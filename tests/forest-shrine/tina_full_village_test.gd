extends SceneTree
## Focused scenery contracts; rendered appearance is reviewed separately.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Scenery=Original.TinaScenery
const Ground=Original.TinaGround
var checks=0
var failures=0

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("TINA_FULL_FAIL ",message)

func _initialize():
 run.call_deferred()

func run():
 var catalog=Original.Art.data()
 for serial in Scenery.BUILDINGS+Scenery.BOATS+Scenery.LOGS+[11363,11364,11365,11379]:
  for other in [400,402,4000,4300,4400,32181,4208]:check(not Scenery.owns(other,serial),"Exterior variant stays local to Tina "+str(serial))
  var g:Dictionary=catalog.graphics[str(serial)]
  var mesh=Scenery.mesh(serial,g)
  check(mesh==Scenery.mesh(serial,g),"Repeated scenery uses the existing mesh cache")
  var low=Vector2.INF;var high=-Vector2.INF;var finite=true
  for slot in mesh.get_surface_count():
   for p:Vector3 in mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]:
    finite=finite and p.is_finite()
    var projected=Vector2((p.x+p.z)*32/3,(p.z-p.x)*8-p.y*10)
    low=low.min(projected);high=high.max(projected)
  check(finite,"Finite complete scenery mesh "+str(serial))
  if serial in Scenery.BUILDINGS+Scenery.LOGS:
   var bounds:Array=Scenery.building_fits[str(serial)].source_outline_bounds
   if serial==11407:
    # Roof eaves now follow measured landmarks; the old whole-mesh bbox fit alone hid their drift.
    var envelope=Rect2(Vector2(bounds[0],bounds[1]),Vector2(bounds[2]-bounds[0],bounds[3]-bounds[1])).grow(4)
    check(envelope.has_point(low) and envelope.has_point(high),"Calibrated green roof stays inside its native silhouette envelope")
   else:
    check(low.distance_to(Vector2(bounds[0],bounds[1]))<.01 and high.distance_to(Vector2(bounds[2],bounds[3]))<.01,"Complete scenery keeps the native painted bounds "+str(serial))
   if serial in Scenery.LOGS:
    check(mesh.has_meta("native_tina_logs"),"Tina logs use their own snow/bark/cut-end source paint")
    var shared=Original.Forms.mesh(serial,"logs",g,Original.Art.solid_texture(int(g.page)))
    check(not shared.has_meta("native_tina_logs"),"Other maps retain their existing log mesh")
   if serial==11407:
    var eaves:Array=mesh.get_meta("native_green_roof_eaves",[])
    check(eaves.size()==3,"Green roof retains all three reference eaves")
    for i in eaves.size():
     var p:Vector3=eaves[i]
     var projected=Vector2((p.x+p.z)*32/3,(p.z-p.x)*8-p.y*10)-Vector2(g.origin[0],g.origin[1])
     check(projected.distance_to(Scenery.Tina.ROOFS[11407][i+1])<.01,"Green main-roof eaves match their native coordinates")
  elif serial not in Scenery.BOATS:
   check(absf(mesh.get_aabb().end.y+float(g.origin[1])*.1)<.1,"Fence post and snow cap retain the original source-view height "+str(serial))
 var serials={}
 for id in [51005,4201]:
  var row=Original.state(id)
  var raw:PackedByteArray=row.raw.duplicate();var bits:PackedByteArray=row.bits.duplicate();var links=Original.links(id)
  for i in 10000:
   var serial=row.raw.decode_u16(20+i*2)
   if serial>=1000:serials[serial]=true
  var world=Node3D.new();root.add_child(world)
  var walls=Original.build(world,id)
  check(row.raw==raw and row.bits==bits,"All three source planes and walkability remain byte-identical")
  check(Original.links(id)==links,"Every existing entrance and transition is unchanged")
  check(not walls.is_empty() and world.get_node_or_null("TinaShoreWaterBacking")!=null,"Existing collision owner and scenery-only water backing remain separate")
  world.free()
 for serial in serials:
  var g:Dictionary=catalog.graphics[str(serial)]
  var mesh=Ground.floor_mesh(serial,g)
  check(mesh==Ground.floor_mesh(serial,g),"Native floor variants are cached "+str(serial))
  var r:Array=Ground.records[str(serial)].rect;var rect=Rect2(r[0],r[1],r[2],r[3])
  var valid=true
  for uv:Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:valid=valid and rect.has_point(uv*Ground.texture.get_size())
  check(valid,"Floor samples only its own original tile and gutter "+str(serial))
 var shore_ids={}
 for id in [51005,4201]:
  var art=Original.Art.new();art.load_map(Original.path_for(id))
  for placement in art.placements:
   if Ground.shore(placement[3]):shore_ids[placement[3]]=true
 for serial in shore_ids:
  var g:Dictionary=catalog.graphics[str(serial)];var mesh=Ground.bank_mesh(serial,g);var arrays=mesh.surface_get_arrays(0)
  var valid=true
  var texture:Texture2D=mesh.surface_get_material(0).get_shader_parameter("base_texture")
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
   var projected=Vector2((p.x+p.z)*32/3,(p.z-p.x)*8-p.y*10)-Vector2(g.origin[0],g.origin[1])
   var pixel=arrays[Mesh.ARRAY_TEX_UV][i]*texture.get_size()-Vector2(g.rect[0],g.rect[1])
   valid=valid and projected.distance_to(pixel)<.72 and p.y>=-2.101 and p.y<=.001
  check(valid,"Shoreline retains native contours with real cap/bank/water depth "+str(serial))
  check(arrays[Mesh.ARRAY_VERTEX].size()<=36,"Shore detail remains painted on three simple depth bands")
 print("TINA_FULL_RESULT checks=",checks," failures=",failures,"; visual judgment is separate")
 quit(1 if failures else 0)

extends SceneTree
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Village=Original.JenovaVillageArt
var checks=0
func check(value:bool,message:String):
 checks+=1
 assert(value,message)
func _initialize():
 var row=Original.state(51004)
 Village.prepare_scope()
 check(row.raw.hex_encode().sha256_text()==Original.Art.raw_map(Original.path_for(51004)).hex_encode().sha256_text(),"Visual variants leave all three original map planes unchanged")
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(row.raw)
 check(hash.finish().hex_encode()==Village.scope.map_sha256,"Reachable scope belongs to the unchanged source map")
 check(Village.reachable.size()==2874,"All original reachable outdoor cells retain their scope")
 var report=[]
 for serial in Village.SITES:
  var cell:Vector2i=Village.SITES[serial];var g:Dictionary=Original.Art.data().graphics[str(serial)]
  check(Village.owns(4000,serial,cell),"Every original house type has its own local variant")
  check(not Village.owns(4000,serial,cell+Vector2i.ONE),"Variants do not replace other placements")
  for source in [400,402,4001,4002,4200,4201,4300,4400]:check(not Village.owns(source,serial,cell),"Interiors and other maps retain their existing mesh")
  var before=Original.Forms.mesh(serial,"building",g,Original.Art.solid_texture(int(g.page)))
  var variant=Village.mesh(serial,g);var bounds=variant.get_aabb();var triangles=0
  check(variant!=before and variant==Village.mesh(serial,g),"One immutable cached variant per house")
  check(before==Original.Forms.mesh(serial,"building",g,Original.Art.solid_texture(int(g.page))),"Shared source model remains untouched")
  check(bounds.position.y>=-.25 and bounds.end.y<12.6,"Street proportions replace the tall stretched walls")
  var roof_materials=[]
  for slot in variant.get_surface_count():
   if variant.surface_get_material(slot).get_shader_parameter("architecture_roof"):roof_materials.append(variant.surface_get_material(slot))
   var arrays=variant.surface_get_arrays(slot)
   triangles+=arrays[Mesh.ARRAY_VERTEX].size()/3
   check(variant.surface_get_material(slot)!=null,"Every surface uses an owned material")
   for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:check(point.is_finite(),"Prepared geometry is finite")
  check(roof_materials.has(Village.paint("green" if serial==11403 else "orange")),"Original roof color identity is preserved")
  check(not roof_materials.has(Village.paint("orange" if serial==11403 else "green")),"Unused materials cannot overwrite a roof surface")
  report.append({"serial":serial,"aabb":str(bounds),"triangles":triangles,"surfaces":variant.get_surface_count()})
 for index in Village.reachable:
  var cell=Vector2i(index%100,index/100)
  check(Original.open(row.bits,row.size,cell),"Floor treatment stays on the original reachable cells")
  check(Village.floor_owns(4000,cell) and not Village.floor_owns(4001,cell),"Floor ownership is local")
 check(not Village.floor_owns(4000,Vector2i(99,99)),"Unreachable ground remains unchanged")
 Village.floor_mesh(3940,Original.Art.data().graphics["3940"])
 check(Village.floor_material()==Village.floor_material(),"Repeated visits reuse the owned ground material")
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/Jenova Village Art/mesh-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("JENOVA_ART_RESULT checks=",checks," failures=0 houses=",report.size()," reachable_cells=",Village.reachable.size())
 quit()

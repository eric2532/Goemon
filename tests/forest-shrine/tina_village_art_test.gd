extends SceneTree
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Art=Original.TinaVillageArt
var checks=0
var failures=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("TINA_ART_FAIL ",message)
func _initialize():run.call_deferred()
func run():
 for serial in Art.ACTIVE:
  var cell:Vector2i=Art.SITES[serial]
  check(Art.owns(4200,serial,cell) and Art.owns(4201,serial,cell),"Village models are active in both phases")
  for other in [400,402,4000,4208,4210,4300]:check(not Art.owns(other,serial,cell),"Other maps/interiors retain their own art")
  var mesh=Art.mesh(serial,Original.Art.data().graphics[str(serial)])
  check(mesh==Art.mesh(serial,Original.Art.data().graphics[str(serial)]),"Repeated placements share cached geometry")
  check(mesh.get_aabb().size.y>4 and mesh.get_aabb().size.y<11,"New houses keep their authored player-scale height")
  var finite=true
  for slot in mesh.get_surface_count():
   for p:Vector3 in mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]:finite=finite and p.is_finite()
  check(finite,"Every house has finite prepared geometry")
 check(Art.owns(4201,11407,Vector2i(30,60)),"Night mayor house uses its actual shifted source anchor")
 check(not Art.owns(4200,11409,Vector2i(47,3)),"Northern approach house remains unchanged")
 check(not Art.owns(4200,11363,Vector2i(28,20)),"Approach fences remain unchanged")
 check(not Art.inside(Vector2i(47,9)),"Northern approach ground is outside the visual pass")
 for serial in [11363,11314,10017,10032,10033,10055,11660,11693,12471]:
  check(Art.owns(4200,serial,Vector2i(40,45)) and not Art.owns(400,serial,Vector2i(40,45)),"Street variants stay in the village")
  var prop=Art.mesh(serial,Original.Art.data().graphics[str(serial)])
  check(prop.get_aabb().position.y>=-.01 and prop.get_aabb().size.y<=5.6,"Street props are grounded and bounded at player scale")
 var roof=Art.mesh(11451,Original.Art.data().graphics["11451"])
 var top=false
 for slot in roof.get_surface_count():
  if roof.surface_get_material(slot)!=Art.paint("brown"):continue
  for normal:Vector3 in roof.surface_get_arrays(slot)[Mesh.ARRAY_NORMAL]:top=top or normal.y>.5
 check(top,"Storage roof faces upward")
 for id in [51005,4201]:
  var row=Original.state(id);var raw:PackedByteArray=row.raw.duplicate();var bits:PackedByteArray=row.bits.duplicate();var links=Original.links(id)
  var world=Node3D.new();root.add_child(world);var walls=Original.build(world,id)
  check(row.raw==raw and row.bits==bits and Original.links(id)==links,"Art activation preserves map planes, collision data and door links")
  check(not walls.is_empty(),"The existing collision owner is retained")
  var counts={}
  for child in world.get_children():
   if not child is MultiMeshInstance3D or not child.multimesh.mesh.has_meta("tina_street_art"):continue
   var serial=int(child.get_meta("source_graphic"));counts[serial]=counts.get(serial,0)+child.multimesh.instance_count
  var houses=0
  for serial in Art.ACTIVE:houses+=counts.get(serial,0)
  check(houses==(5 if id==51005 else 6),"Built scene contains every redesigned day/night house")
  world.free()
 print("TINA_ART_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

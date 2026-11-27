extends SceneTree
## Nonvisual scenery/isolation checks. No travel, game input or captures.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Scenery=preload("res://scripts/forest/forest_tina_scenery.gd")
var failures=0
var checks=0

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("TINA_APPEARANCE_FAIL ",message)

func _initialize():
 create_timer(120).timeout.connect(func():printerr("TINA_APPEARANCE_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 var ids=[11015]
 for key in Scenery.Profiles.GRAPHICS:ids.append(int(key))
 for id in Scenery.ROOMS:
  var art=Original.Art.new();art.load_map(Original.path_for(id))
  for placement in art.placements:
   if Scenery.owns(id,placement[3]) and placement[3] not in ids:ids.append(placement[3])
 for serial in ids:
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var exterior=serial==11015 or serial<13000 and Scenery.Profiles.GRAPHICS.has(str(serial))
  check(Scenery.owns(4200,serial) and Scenery.owns(4201,serial) if exterior else Scenery.owns(4208,serial),"Only the intended Tina scenery group uses its variant")
  for other in [400,402,4000,4300,4400,1000,0]:check(not Scenery.owns(other,serial),"Other areas retain shared scenery")
  var mesh=Scenery.mesh(serial,g)
  check(mesh==Scenery.mesh(serial,g),"Repeated source props reuse the same prepared mesh")
  check(mesh.get_aabb().size.y>.02,"Scenery has finite nonzero height "+str(serial))
  check(mesh.get_aabb().position.y>=-.10,"Plants and shelter stay above the original ground "+str(serial))
  var finite=true;var native_uvs=true
  for slot in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(slot)
   for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:finite=finite and point.is_finite()
   var material:Material=mesh.surface_get_material(slot)
   if material is ShaderMaterial:
    var texture=material.get_shader_parameter("source_paint" if material.shader==Scenery.Meadow.WIND else "base_texture")
    if texture==Scenery.Harbor.BuildingAtlas or not exterior:continue
    var rect=Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]).grow(.01)
    for uv:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:native_uvs=native_uvs and rect.has_point(uv*texture.get_size())
  check(finite,"No invalid scenery vertices "+str(serial))
  check(native_uvs,"Native paint remains inside its original graphic "+str(serial))
  if serial in Scenery.TREES:
   var template=Scenery.Meadow.source(Scenery.Meadow.crossgate_tree(10088))
   for slot in 2:
    check(mesh.surface_get_arrays(slot)[Mesh.ARRAY_INDEX]==template[slot].mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX],"Tree keeps existing trunk/leaf topology")
  if serial in Scenery.TABLES or serial==16500:
   check(mesh.get_surface_count()==1 and mesh.has_meta("native_plain_table"),"Table parts and plank bench contain no borrowed desk/books/cushions")
  if not exterior and serial not in Scenery.TABLES+Scenery.POTTED+[16500]:
   var original=Original.Forms.mesh(serial,Original.Forms.kind(serial,false,g),g,Original.Art.solid_texture(int(g.page)))
   var before=PackedVector3Array();var after=PackedVector3Array()
   for slot in original.get_surface_count():
    var source=SurfaceTool.new();source.create_from(original,slot);source.deindex()
    before.append_array(source.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
   for slot in mesh.get_surface_count():
    var source=SurfaceTool.new();source.create_from(mesh,slot);source.deindex()
    after.append_array(source.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
   var a=[];var b=[]
   for p in before:a.append(str(p))
   for p in after:b.append(str(p))
   a.sort();b.sort()
   check(a==b,"Room paint preserves the existing complete furniture geometry "+str(serial))
 for id in [51005,4201]+Scenery.ROOMS:
  var state=Original.state(id);var raw:PackedByteArray=state.raw.duplicate();var bits:PackedByteArray=state.bits.duplicate()
  var links=Original.links(id);var world=Node3D.new();root.add_child(world)
  var walls=Original.build(world,id)
  check(state.raw==raw and state.bits==bits,"Scenery setup preserves all source and collision planes")
  check(Original.links(id)==links,"All existing doors and transitions stay identical")
  var expected=[];var actual=[];var art=Original.Art.new()
  art.load_map(Original.path_for(id),state.raw,state.size)
  for placement in art.placements:
   if Scenery.owns(Original.source_id(id),placement[3]) or Original.TinaVillageArt.owns(Original.source_id(id),placement[3],placement[5]):expected.append(int(placement[3]))
  for child in world.get_children():
   if child is MultiMeshInstance3D and child.multimesh.mesh.has_meta("tina_only_scenery"):
    for i in child.multimesh.instance_count:
     actual.append(int(child.get_meta("source_graphic")))
  actual.sort();expected.sort()
  check(actual==expected,"Every source graphic retains its exact placement count")
  check(not walls.is_empty(),"Original map boundary owner remains active")
  world.free()
 print("TINA_APPEARANCE_RESULT checks=",checks," failures=",failures," (nonvisual only)")
 quit(1 if failures else 0)

extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit/"
var checks=0
var failures=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("VENOA_SOUTHWEST_FIELD_FAIL ",message)
func _initialize():run.call_deferred()
func old_field(terrain)->Dictionary:
 var field=terrain.terrain_field();var width:int=field.get_meta("width")
 var result={"heights":PackedFloat32Array(),"bed":PackedFloat32Array(),"covered":PackedByteArray(),"bridges":PackedByteArray()}
 for y in 321:
  for x in 321:
   var at=terrain.coordinate(x*3.0-480,y*3.0-480)
   var index=roundi(at.y)*width+roundi(at.x)
   for key in result:result[key].append(field.get_meta(key)[index])
 return result
func run():
 var baseline="--baseline" in OS.get_cmdline_user_args()
 var layout=Regions.layout("south_lakes")
 var model=Model.new();model.reset(41829558,{},layout,false)
 var terrain=model.terrain
 var current=old_field(terrain)
 if baseline:
  check(terrain.width==321 and model.map_expansion==1.0,"Baseline is the unchanged321field")
  var file=FileAccess.open(OUT+"southwest-field-before.bin",FileAccess.WRITE)
  file.store_var(current);file.close()
 else:
  var file=FileAccess.open(OUT+"southwest-field-before.bin",FileAccess.READ)
  check(file!=null,"Before snapshot exists")
  if file==null:quit(1);return
  var before:Dictionary=file.get_var();file.close()
  check(float(layout.get("map_expansion",1.0))==1.5,"Fresh layout publishes the same expansion as the native field")
  for key in before:
   var a:PackedByteArray=current[key].to_byte_array() if current[key] is PackedFloat32Array else current[key]
   var b:PackedByteArray=before[key].to_byte_array() if before[key] is PackedFloat32Array else before[key]
   check(a==b,"Every old321×321 "+key+" sample is byte-identical")
  check(terrain.width==481 and model.map_expansion==1.5,"Existing expansion convention fits the recovered columns")
  check(terrain.mask_texture().get_size()==Vector2(347,321),"Only26columns were appended")
  check(terrain.mask_origin()==Vector2(-558,-480),"Original source frame remains fixed")
  var field=terrain.terrain_field();var width:int=field.get_meta("width");var outside_covered=0;var outside_bridges=0
  for y in width:
   for x in width:
    var at=Vector2(x*3.0-720,y*3.0-720)
    if terrain.mask_bounds().has_point(at):continue
    var index=y*width+x
    outside_covered+=int(field.get_meta("covered")[index])
    outside_bridges+=int(field.get_meta("bridges")[index])
  check(outside_covered==0,"Expanded cells outside the native rectangle have no native coverage")
  check(outside_bridges==0,"Expanded cells outside the native rectangle have no inherited bridge support")
  for source in [Vector2(201,410),Vector2(201,443),Vector2(226,410),Vector2(226,443)]:
   var at:Vector2=Regions.frame("south_lakes").inverse()*(source*3.)
   check(terrain.mask_bounds().has_point(at) and model.world_bounds().has_point(at),"Recovered source bounds fit existing world/navigation: "+str(source))
   check(is_finite(terrain.height(at.x,at.y)),"Recovered source coordinate has a finite terrain height")
  var old_layout=layout.duplicate(true);old_layout.erase("map_expansion")
  var restored=Model.new();restored.reset(41829558,{},old_layout,false)
  check(restored.map_expansion==1.5 and restored.terrain.width==481,"Legacy saved SouthernLakes layout gains coverage without coordinate migration")
 print("VENOA_SOUTHWEST_FIELD_RESULT baseline=",baseline," checks=",checks," failures=",failures)
 quit(1 if failures else 0)

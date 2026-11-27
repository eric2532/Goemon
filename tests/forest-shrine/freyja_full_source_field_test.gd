extends SceneTree
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source outdoors/"
class SnapshotTerrain extends Terrain:
 var snapshot:Image
 var texture:ImageTexture
 var snapshot_origin:Vector2
 func mask_image()->Image:return snapshot
 func mask_texture()->Texture2D:
  if texture==null:texture=ImageTexture.create_from_image(snapshot)
  return texture
 func mask_origin()->Vector2:return snapshot_origin
 func terrain_field()->Resource:
  if variant=="east_gate":
   if not fields.has(variant):fields[variant]=EastRoad.build_field(snapshot)
   return fields[variant]
  return super.terrain_field()
var checks=0
var failures=0
var preview=false
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 preview="--preview-source"in OS.get_cmdline_user_args()
 create_timer(120).timeout.connect(func():printerr("FREYJA_FULL_SOURCE_FIELD_TIMEOUT");quit(1))
 run.call_deferred()
func prepare(area:String,image:Image,origin:Vector2,scale_:float,expansion_:float)->SnapshotTerrain:
 Terrain.fields.erase(area)
 var t=SnapshotTerrain.new();t.variant=area;t.snapshot=image;t.snapshot_origin=origin;t.horizontal_scale=scale_;t.expansion=expansion_;t.configure([])
 return t
func run():
 var contracts=JSON.parse_string(FileAccess.get_file_as_string(OUT+"Before assets/owner-contracts.json"))
 var folder="Prepared preview/"if preview else"Prepared full/"
 var metadata=JSON.parse_string(FileAccess.get_file_as_string(OUT+folder+"provenance.json"));var results={}
 for row in contracts.areas:
  var area:String=row.area;var m:Dictionary=metadata.areas[area]
  var before=Image.load_from_file(ProjectSettings.globalize_path(OUT+"Before assets/"+area+"-surface.png"))
  var after:Image=load(OUT+folder+"cpu-masks/"+area+".res")
  var old=prepare(area,before,Vector2(row.origin[0],row.origin[1]),row.scale,row.expansion)
  var a=old.terrain_field();var saved:Resource=load(OUT+"Before assets/"+area+"-field.res")
  var current=prepare(area,after,Vector2(m.origin[0],m.origin[1]),row.scale,row.expansion)
  var b=current.terrain_field();var changed={};var mask_changes=0
  for y in after.get_height():
   for x in after.get_width():
    var old_at=Vector2i(x-int(m.old_pixel_offset[0]),y-int(m.old_pixel_offset[1]))
    var old_pixel=before.get_pixelv(old_at)if Rect2i(Vector2i.ZERO,before.get_size()).has_point(old_at)else Color(1,0,0,1)
    if after.get_pixel(x,y)==old_pixel:continue
    mask_changes+=1
    var point=current.mask_origin()+Vector2(x,y)*3.;var at=Vector2i(current.coordinate(point.x,point.y).round());changed[at.y*current.width+at.x]=true
  var exact=true;var outside={};var counts={}
  for key in ["heights","bed","covered","bridges"]:
   var aa=a.get_meta(key);var bb=b.get_meta(key);var ss=saved.get_meta(key)
   check(aa==ss,"Fresh original production math matches protected native baseline "+area+" "+key)
   var differences=0;var other=0
   for i in aa.size():
    if aa[i]!=bb[i]:differences+=1;other+=int(not changed.has(i))
   outside[key]=other;counts[key]=differences;exact=exact and other==0
  check(current.width==old.width and current.spacing==old.spacing,"Native owner dimensions and spacing stay exact "+area)
  check(exact,"No native sample changes outside actual source mask additions "+area)
  check(b.get_meta("bridges")==a.get_meta("bridges"),"Original bridge cells stay byte-exact "+area)
  var water_clear=true;var covered:PackedByteArray=b.get_meta("covered");var bridges:PackedByteArray=b.get_meta("bridges")
  for y in after.get_height():
   for x in after.get_width():
    if after.get_pixel(x,y).r<.5 or after.get_pixel(x,y).a<.5:continue
    var point=current.mask_origin()+Vector2(x,y)*3.;var at=Vector2i(current.coordinate(point.x,point.y).round());var index=at.y*current.width+at.x
    water_clear=water_clear and (covered[index]==0 or bridges[index]!=0)
  check(water_clear,"Source-water samples add no terrain support beyond preserved bridges "+area)
  results[area]={"width":current.width,"spacing":current.spacing,"expansion":current.expansion,"changed_mask_pixels":mask_changes,"changed_native_samples":counts,"outside_mask_changes":outside}
 var file=FileAccess.open(OUT+("preview-"if preview else"")+"field-verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"active":false,"areas":results,"limits":"Same production field math, old/new CPU masks and protected pre-activation fields. No new resource has been activated or visually accepted; collider/route/scenery setup remains separate."},"  ")+"\n");file.close()
 print("FREYJA_FULL_SOURCE_FIELDS ",checks," checks ",failures," failures; active=false")
 quit(1 if failures else 0)

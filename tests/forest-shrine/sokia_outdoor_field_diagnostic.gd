extends SceneTree
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Sokia full-source outdoors/"
class SnapshotTerrain extends Terrain:
 var snapshot:Image
 func mask_image()->Image:return snapshot if snapshot!=null else super.mask_image()

func _initialize():run.call_deferred()

func field(area:String,image:Image)->Resource:
 Terrain.fields.erase(area)
 var terrain=SnapshotTerrain.new();terrain.variant=area;terrain.horizontal_scale=Terrain.Regions.layout(area).terrain_scale
 terrain.expansion=Terrain.Sokia.expansion(area);terrain.snapshot=image
 terrain.configure([])
 return terrain.terrain_field()

func run():
 var report={};var failures=0
 for area in ["sokia_coast","sokia_desert","ghana_road","ghana_north_road"]:
  var old_mask=Image.load_from_file(ProjectSettings.globalize_path(REVIEW+"before-mask-"+area+".png"))
  var current_mask:Image=Terrain.Sokia.MASKS[area].get_image()
  var old=field(area,old_mask);var current=field(area,current_mask)
  var saved:Resource=load(REVIEW+"before-field-"+area+".res")
  var width:int=old.get_meta("width");var origin=-(Vector2(old_mask.get_size())-Vector2.ONE)*1.5
  var pad=Vector2.ONE*240.*2.*Terrain.Sokia.expansion(area)
  var start=Vector2i((origin+pad)/3.)
  var changed={};var examples=[];var baseline_counts={};var source_counts={};var outside_counts={}
  for y in old_mask.get_height():
   for x in old_mask.get_width():
    if old_mask.get_pixel(x,y)!=current_mask.get_pixel(x,y):changed[(start.y+y)*width+start.x+x]=true
  for key in ["heights","bed","covered","bridges"]:
   var a=old.get_meta(key);var b=current.get_meta(key);var c=saved.get_meta(key)
   var baseline=0;var delta=0;var outside=0
   for i in a.size():
    if a[i]!=c[i]:
     baseline+=1
     if examples.size()<8:examples.append({"sample":[i%width,i/width],"fresh_before":a[i],"saved_before":c[i],"after":b[i]})
    if a[i]!=b[i]:delta+=1;outside+=int(not changed.has(i))
   baseline_counts[key]=baseline;source_counts[key]=delta;outside_counts[key]=outside
   failures+=int(outside>0)
  report[area]={"width":width,"scale":2.,"expansion":Terrain.Sokia.expansion(area),"changed_mask_pixels":changed.size(),"persisted_before_diff":baseline_counts,"fresh_before_after_diff":source_counts,"outside_source_additions_diff":outside_counts,"persisted_before_examples":examples}
 var out=FileAccess.open(REVIEW+"field-diagnostic.json",FileAccess.WRITE);out.store_string(JSON.stringify({"failures":failures,"areas":report},"  ")+"\n");out.close()
 print("SOKIA_FIELD_DIAGNOSTIC ",JSON.stringify({"failures":failures,"areas":report}))
 quit(1 if failures else 0)

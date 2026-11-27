extends SceneTree
## Offline owner/mask baseline for the map100 completion; never instantiates a world.
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Frontier=preload("res://scripts/forest/forest_falan_frontier.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source outdoors/Before assets/"
const AREAS=["freyja","east_gate","south_gate","west_lakes","north_coast","south_lakes","east_coast"]
func plain(v):
 if v is Vector2 or v is Vector2i:return [v.x,v.y]
 if v is Rect2:return [v.position.x,v.position.y,v.size.x,v.size.y]
 if v is Transform2D:return {"x":plain(v.x),"y":plain(v.y),"origin":plain(v.origin)}
 return v
func rgba_hash(image:Image)->String:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(image.get_data());return context.finish().hex_encode()
func _initialize():
 create_timer(60).timeout.connect(func():printerr("FREYJA_OWNER_CONTRACT_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 assert(not FileAccess.file_exists("res://assets/maps/falan/freyja_source/100.dat"),"Take the baseline before activation")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var rows=[]
 var city=Terrain.new();city.variant="city"
 for area in AREAS:
  var path=OUT+area+"-surface.png"
  assert(not FileAccess.file_exists(path),"Do not overwrite the protected pre-completion baseline")
  var t=Terrain.new();t.variant=area;t.horizontal_scale=2.;t.expansion=Terrain.Regions.layout(area).get("map_expansion",1.);t.configure([])
  var image=t.mask_image();assert(image!=null and image.get_format()==Image.FORMAT_RGBA8)
  assert(image.save_png(path)==OK)
  assert(ResourceSaver.save(t.terrain_field(),OUT+area+"-field.res")==OK)
  var info={"area":area,"canonical_area":Terrain.Regions.canonical_area(area),"frame":plain(Terrain.Regions.frame(area)),"origin":plain(t.mask_origin()),"size":plain(image.get_size()),"mask_rgba_sha256":rgba_hash(image),"expansion":t.expansion,"scale":t.horizontal_scale,"width":t.width,"spacing":t.spacing}
  if Frontier.FRAMES.has(area):info.city={"frame":plain(Frontier.FRAMES[area]),"bounds":plain(city.mask_bounds()),"mask_origin":plain(city.mask_origin()),"mask":"assets/maps/falan/city_surface.png","end":t.bridge_bounds().position.y-9.}
  if Terrain.Regions.CONNECTED_VILLAGES.has(area):
   var village:String=Terrain.Regions.CONNECTED_VILLAGES[area]
   info.joined_village={"name":village,"frame":plain(Terrain.Regions.village_transform(village).inverse()),"bounds":plain(Terrain.Regions.village_bounds(village))}
  rows.append(info)
 var file=FileAccess.open(OUT+"owner-contracts.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"areas":rows,"contract":"Current source owner frames and setup fields only; no world or collision mesh instantiated. Raw source outdoor support and synthetic city/village presentation are distinguished offline."},"  ")+"\n");file.close()
 print("FREYJA_SOURCE_OWNER_CONTRACTS ",rows.size()," exact CPU mask/field snapshots; worlds=0")
 quit()

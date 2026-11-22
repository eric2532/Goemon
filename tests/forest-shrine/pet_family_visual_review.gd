extends "res://tests/forest-shrine/falan_pet_catalog_review.gd"
const REVIEW_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Pet Expansion/Rendered/"
func run():
 if DisplayServer.get_name()=="headless":printerr("Rendered review requires the desktop launcher");quit(1);return
 DirAccess.make_dir_recursive_absolute(REVIEW_OUT)
 root.size=Vector2i(1280,800)
 var doc=Doc.new();doc.load_wind_meadow();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://pet-review-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.player.select_character(34);game.set_process(false);game.paused=true;paused=true
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var groups={}
 for skin in range(82,Pets.COUNT):
  var category_=Pets.category(skin)
  if not groups.has(category_):groups[category_]=[]
  groups[category_].append(skin)
 for category_ in groups:
  var skins:Array=groups[category_];var slug:String=category_.to_lower().replace(" ","-")
  for page in range(0,skins.size(),12):
   var rows=[]
   for start in range(page,mini(page+12,skins.size()),4):
    var entries=[]
    for skin in skins.slice(start,mini(start+4,skins.size())):entries.append({"source":Pets,"skin":skin,"name":Pets.title(skin),"clock":.35})
    rows.append({"title":category_,"entries":entries})
   await capture_sheet(REVIEW_OUT+slug+"-%02d.png"%page,rows)
  var examples=[skins[0],skins[-1]]
  var rows=[]
  for state_ in [80,81,82]:
   var entries=[]
   for skin in examples:
    var clock=float(Pets.attack_pattern(skin).contacts[0]) if state_==82 else .25
    entries.append({"source":Pets,"skin":skin,"name":Pets.title(skin),"state":state_,"clock":clock})
   rows.append({"title":category_+" · "+("Idle" if state_==80 else "Run" if state_==81 else "First contact"),"entries":entries})
  await capture_sheet(REVIEW_OUT+slug+"-motion.png",rows)
 var cfg=game.settings_path;game.queue_free();paused=false
 for i in 4:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_FAMILY_VISUAL_RESULT appearances=",reviewed," failures=",errors);quit(1 if errors else 0)

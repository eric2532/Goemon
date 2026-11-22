extends "res://tests/forest-shrine/falan_pet_catalog_review.gd"
func reward_category()->String:return "灰熊厲害"
func reward_count()->int:return 127
func review_output()->String:return "res://build/Other Files/Asset Toolkit/Bear Challenge Pets/A Rank Recheck/Rendered/"
func run():
 if DisplayServer.get_name()=="headless":printerr("Rendered review requires Play Goemon");quit(1);return
 DirAccess.make_dir_recursive_absolute(review_output())
 root.size=Vector2i(1280,800)
 var doc=Doc.new();doc.load_wind_meadow();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://bear-reward-review-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.player.select_character(34);game.set_process(false);game.paused=true;paused=true
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var skins=range(Pets.COUNT).filter(func(skin):return Pets.category(skin)==reward_category())
 check(skins.size()==reward_count(),"Every verified "+reward_category()+" reward appearance is prepared")
 for page in range(0,skins.size(),8):
  for state_ in [80,81,82,18]:
   var rows=[]
   for start in range(page,mini(page+8,skins.size()),4):
    var entries=[]
    for skin in skins.slice(start,mini(start+4,skins.size())):
     var clock=float(Pets.attack_pattern(skin).contacts[0]) if state_ in [82,18] else .25
     entries.append({"source":Pets,"skin":skin,"name":Pets.label(skin),"state":state_,"clock":clock})
    rows.append({"title":reward_category()+" rewards · "+str(state_),"entries":entries})
   await capture_sheet(review_output()+"%02d-%d.png"%[page,state_],rows)
 var cfg=game.settings_path;game.queue_free();paused=false
 for i in 4:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("REWARD_VISUAL_RESULT family=",reward_category()," appearances=",reviewed," failures=",errors);quit(1 if errors else 0)

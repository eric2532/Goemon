extends "res://tests/forest-shrine/falan_pet_catalog_review.gd"
const REVIEW_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Judas Family/Rendered/"
func run():
 if DisplayServer.get_name()=="headless":printerr("Rendered review requires the desktop launcher");quit(1);return
 DirAccess.make_dir_recursive_absolute(REVIEW_OUT)
 root.size=Vector2i(1280,800)
 var doc=Doc.new();doc.load_wind_meadow();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://judas-review-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.player.select_character(34);game.set_process(false);game.paused=true;paused=true
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var skins=range(Pets.COUNT).filter(func(skin):return Pets.category(skin)=="bosses" and Pets.listed(skin))
 check(skins.size()==24,"All 24 distinct boss looks are present")
 var archive_only="--archive-only" in OS.get_cmdline_user_args()
 if archive_only:skins=skins.slice(24)
 for state_ in [80,81,82]:
  for page in range(0,skins.size(),12):
   var rows=[]
   for start in range(page,mini(page+12,skins.size()),4):
    var entries=[]
    for skin in skins.slice(start,mini(start+4,skins.size())):
     var clock=float(Pets.attack_pattern(skin).contacts[0]) if state_==82 else .25
     entries.append({"source":Pets,"skin":skin,"name":Pets.label(skin),"state":state_,"clock":clock})
    rows.append({"title":"bosses · 猶大 · "+("Idle" if state_==80 else "Movement" if state_==81 else "Contact"),"entries":entries})
   await capture_sheet(REVIEW_OUT+"%d-%02d.png"%[state_,page+(24 if archive_only else 0)],rows)
 var cfg=game.settings_path;game.queue_free();paused=false
 for i in 4:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("JUDAS_VISUAL_RESULT appearances=",reviewed," failures=",errors);quit(1 if errors else 0)

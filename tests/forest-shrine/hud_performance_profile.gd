extends "res://tests/forest-shrine/portrait_xp_hud_test.gd"
## Compare unchanged HUD work across the current Cross Gate roster.
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var ui=game.forest_ui;ui.set_process(false)
 var rows=[]
 game.model.team_progression.cards_enabled=false;game.start_wave()
 for fighter in ui.Roster.CROSSGATE:
  game.player.select_character(fighter);ui.sync();await frames()
  var costs=[]
  for i in 200:
   var start=Time.get_ticks_usec();ui.sync();costs.append(Time.get_ticks_usec()-start)
  costs.sort();rows.append({"fighter":fighter,"hud_p50_us":costs[100],"hud_p95_us":costs[190]})
  check(ui.hero_name.text==ui.Roster.name_for(fighter),"HUD keeps current fighter identity")
 var label_="latest"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label_=arg.trim_prefix("--label=")
 assert(label_.is_valid_filename())
 var out="res://build/Other Files/Asset Toolkit/Performance Review 2026-11-14/"+label_+"-hud.json"
 FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("HUD_PROFILE ",JSON.stringify(rows))
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

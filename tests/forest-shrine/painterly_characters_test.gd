extends "res://tests/forest-shrine/painterly_environment_test.gd"
var game
var config_path="user://painterly-characters-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: Painterly character test timeout");quit(1))
 run.call_deferred()
func run():
 set_meta("forest_painterly_preview",false)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var tuning=game.tuning.duplicate(true);var character_tuning=game.character_tuning.duplicate(true)
 for id in range(1,13):
  game.player.select_character(id)
  var items=snapshot(geometry(game.player));var shared=[]
  var combat=game.player.active_ability
  if id>=3 and combat!=null and is_instance_valid(combat.visual_actor) and not game.player.is_ancestor_of(combat.visual_actor):items.append_array(snapshot(geometry(combat.visual_actor)))
  for item in items:
   for mat in item.active:
    if mat is StandardMaterial3D:shared.append([mat,mat.albedo_color,mat.albedo_texture])
  var stats=[game.player.hp,game.player.max_hp,game.player.position,game.player.character_id]
  game.toggle_painterly_preview()
  var unchanged=restored(items) and stats==[game.player.hp,game.player.max_hp,game.player.position,game.player.character_id]
  for entry in shared:unchanged=unchanged and entry[0].albedo_color==entry[1] and entry[0].albedo_texture==entry[2]
  check(unchanged,"Fighter %d retains every model/material and health/position during environment toggle"%id)
  game.toggle_painterly_preview()
 check(game.tuning==tuning and game.character_tuning==character_tuning,"Combat and character balance settings remain unchanged")
 game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop();voice.stream=null
 game.queue_free();paused=false
 for i in 4:await process_frame
 await create_timer(.3).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("PAINTERLY_CHARACTERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

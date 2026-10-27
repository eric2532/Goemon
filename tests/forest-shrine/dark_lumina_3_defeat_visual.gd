extends "res://tests/forest-shrine/dark_lumina_3_visual.gd"
func run():
 await setup_fixture()
 root.title="Goemon · Dark Lumina 3 defeat verification"
 root.set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.paused=false;game.ordinary_pause=false;game.settings_open=false;game.rogue_roster_open=false;paused=false
 var p=game.player;p.select_character(30);fresh();p.position=STAGE
 game.training_dummy.hide();game.ui.hide()
 game.camera_rig.camera.position=STAGE+Vector3(7,5,10)*Finale.SCALE;game.camera_rig.camera.look_at(STAGE+Vector3.UP*Finale.SCALE)
 var presentation=game.crowd.army.presentation
 var nodes=presentation.counts().nodes
 for repeat in 3:
  p.active_ability.die()
  for tick in 180:
   presentation.tick(1.0/60);presentation.draw_effects();await physics_frame
   if repeat==0 and tick==45:await capture("core-defeat")
  check(not presentation.effects.any(func(f):return f.kind.begins_with("finale-")),"Defeat effects expire after sequence %d"%repeat)
 check(presentation.counts().nodes==nodes,"Repeated defeat keeps the prepared presentation")
 var material:BaseMaterial3D=Finale.meshes.ending.surface_get_material(0)
 check(material.blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Ending uses the source actor's additive flag")
 print("DARK_LUMINA_3_DEFEAT_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

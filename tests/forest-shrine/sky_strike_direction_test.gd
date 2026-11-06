extends "res://tests/forest-shrine/modular_spells_test.gd"
class ContactTarget extends Ninja:
 func _ready():set_physics_process(false)
 func combat_contact_point(_from:Vector3)->Vector3:return global_position+Vector3.UP
class ClearSky extends SkyStrike:
 var selected:Ninja
 func choose_target()->Ninja:return selected
 func path_clear(_height:float)->bool:return true
func run():
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_wind_meadow();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var p=game.player;p.select_character(1);p.set_auto_attack(false)
 var origin=Vector3(0,game.model.surface_height(0,60)+.12,60);p.position=origin
 var target=ContactTarget.new();target.game=game;game.add_child(target)
 var sky=ClearSky.new(p);sky.selected=target
 for offset in [Vector3(12,0,-8),Vector3.ZERO]:
  for prior_facing in [Vector3.RIGHT,Vector3.ZERO]:
   for repeat in 3:
    p.position=origin;p.facing=prior_facing;target.position=origin+offset
    check(sky.begin(),"Cast starts at separated or overlapping horizontal contact")
    var expected=offset.normalized() if not offset.is_zero_approx() else (prior_facing if not prior_facing.is_zero_approx() else Vector3.FORWARD)
    check(p.facing.is_equal_approx(expected),"Sky Strike keeps a valid facing, including overlapping targets and zero previous facing")
    var landing=target.position+Vector3.UP-expected*(target.body_radius+.65);landing.y=game.world.surface_height_at(landing)+.1
    check(sky.landing.is_equal_approx(landing),"Landing retains the original contact offset and terrain height")
    sky.tick(.03)
    check(p.facing.length_squared()>.99,"Wind beam receives a nonzero direction during travel")
    sky.cancel();check(p.position.is_equal_approx(origin),"Repeated cancellation returns to the exact cast origin")
 check(SkyStrike.OUT_TIME==.24 and SkyStrike.BACK_TIME==.19 and SkyStrike.BLAST_RADIUS==5,"Leap timing and blast radius stay unchanged")
 sky=null
 target.queue_free();game.player.cancel_charge(false)
 game.sound_library.cancel();game.music.stop();game.queue_free()
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKY_STRIKE_DIRECTION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

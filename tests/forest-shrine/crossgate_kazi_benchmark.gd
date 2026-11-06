extends "res://tests/forest-shrine/large_army_benchmark.gd"
## Same standard army workload; compare the selected player only.
var player_ready=false
func spawn_enemy():
 if not player_ready:
  game.player.select_character(int(options.get("fighter","34")))
  game.player.smoke_mode=true;game.player.set_auto_attack(true)
  player_ready=true
  for path in ["scripts/crossgate_model.gd","scripts/crossgate_combat.gd","assets/characters/crossgate/kazi_hd/motions.json"]:
   fingerprints[path]=FileAccess.get_sha256("res://"+path)
 super.spawn_enemy()
func _process(delta:float)->bool:
 if phase=="measuring":
  var elapsed=(Time.get_ticks_usec()-started)/1000000.0
  game.player.smoke_move=Vector2(sin(elapsed),cos(elapsed))
 return super._process(delta)

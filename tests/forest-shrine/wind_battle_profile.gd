extends "res://tests/forest-shrine/large_army_benchmark.gd"
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Wind=preload("res://scripts/dark_lumina_3_projectile.gd")
var casts=0
var shots=0
var next_cast=0.0
var casting_ready=false
var cast_frames=[]
func spawn_enemy():
 if not casting_ready:
  game.player.select_character(30);game.player.set_auto_attack(false)
  var shrine=game.model.buildings.values().filter(func(b):return b.kind=="shrine")[0]
  var center=game.model.center(shrine)+Vector3(0,0,100)
  game.player.position=Vector3(center.x,game.model.surface_height(center.x,center.z)+.15,center.z)
  game.player.facing=Vector3.FORWARD
  Pool.service(game).launched.connect(func(shot):
   if shot.get_script()==Wind and shot.kind==1:shots+=1)
  for path in ["scripts/dark_lumina_3_combat.gd","scripts/dark_lumina_3_projectile.gd","scripts/character_projectile_pool.gd","scripts/forest/forest_combat_warmup.gd"]:fingerprints[path]=FileAccess.get_sha256("res://"+path)
  casting_ready=true
 super.spawn_enemy()
func _process(delta:float)->bool:
 if casting_ready and phase=="measuring":
  var elapsed=(Time.get_ticks_usec()-started)/1000000.0
  if elapsed>=next_cast and not game.player.active_ability.is_attacking():
   game.player.active_ability.start_move(1);casts+=1;next_cast=elapsed+4.5
  if game.player.active_ability.is_attacking():cast_frames.append((Time.get_ticks_usec()-previous)/1000.0)
 return super._process(delta)
func finish():
 var pool=Pool.service(game)
 var summary={"casts":casts,"wind_shots":shots,"cast_frame_times":Metrics.summary(cast_frames) if not cast_frames.is_empty() else {},"pool":pool.created,"misses":pool.misses}
 DirAccess.make_dir_recursive_absolute(out)
 FileAccess.open(out+"/wind-casts.json",FileAccess.WRITE).store_string(JSON.stringify(summary,"  "))
 print("WIND_BATTLE_CASTS ",JSON.stringify(summary))
 if casts<2 or shots<176:stopped=true;printerr("FAIL: Full battle must execute repeated complete Wind barrages")
 super.finish()

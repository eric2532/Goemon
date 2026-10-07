extends "res://scripts/fire_siege_controls_tests.gd"
func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 for i in range(10):
  await fresh_class(i)
  var actor=game.player.active_ability.visual_actor
  actor.reset_motion();actor.animate_pose({},0,0,0)
  var resting_neck: float = actor.joints.Head.node.rotation.z
  for side in [-1.0,1.0]:
   actor.reset_motion()
   for frame in range(45):
    actor.animate_pose({"isPlayer":true,"grounded":true,"motionSpeed":10.2,"localMotion":Vector3(side*10.2,0,0)},1.0/60,frame/60.0,1)
   check(actor.joints.Body.node.rotation.z*side<-.10,"%s shoulders lean into side %s" %[CLASS_IDS[i],side])
   check((actor.joints.Head.node.rotation.z-resting_neck)*side<-.015,"%s neck adds a small directional tilt" % CLASS_IDS[i])
   for frame in range(40):actor.animate_pose({"isPlayer":true,"grounded":true,"motionSpeed":0,"localMotion":Vector3.ZERO},1.0/60,1+frame/60.0,0)
   check(absf(actor.joints.Body.node.rotation.z)<.01 and absf(actor.joints.Head.node.rotation.z-resting_neck)<.01,"%s settles upright after releasing strafe" % CLASS_IDS[i])
 await fresh_class(6)
 var a=game.player.active_ability
 a.sound.last_events.clear()
 tap("light_attack");await frames(6)
 check(a.player.attack != null and not a.player.attack.hit and a.sound.last_events.has("claymore-sweep") and a.sound.cache.has("claymore-sweep-0"),"Claymore sweep starts before damage contact")
 check(quiet_voice(a.sound, "claymore-sweep-0.wav", .8),"Claymore sweep plays below its previous full-volume mix")
 await frames(35)
 check(not a.sound.last_events.has("claymore-impact"),"A completed missed swing never makes a cutting impact")
 await fresh_class(6);a=game.player.active_ability;a.sound.last_events.clear()
 var victim=fixture(Vector3(2.2,0,0));tap("light_attack");await frames(15)
 check(victim.hp<10000 and a.sound.last_events.has("claymore-impact") and a.sound.cache.has("claymore-impact-light"),"Claymore contact plays the dedicated cutting impact")
 check(quiet_voice(a.sound, "claymore-impact-light.wav", .65),"Cutting contact sits beneath the swing instead of dominating it")
 check(not a.sound.last_events.has("hit") and not a.sound.last_events.has("heavy"),"Claymore contact does not layer the generic hammer impact")
 await fresh_class(6);a=game.player.active_ability;a.sound.last_events.clear()
 victim=fixture(Vector3(3,0,0));tap("heavy_attack")
 check(a.sound.cache.has("claymore-wave") and a.sound.last_events.has("claymore-wave") and not a.sound.last_events.has("cast"),"Energy wave loads its dedicated release sound without the old cast layer")
 await frames(25)
 check(victim.hp<10000 and a.sound.last_events.has("claymore-impact") and a.sound.cache.has("claymore-impact-heavy"),"Energy wave contact uses the same blade-cut character")
 await fresh_class(0);a=game.player.active_ability;a.sound.last_events.clear()
 fixture(Vector3(2.2,0,0));tap("light_attack");await frames(14)
 check(a.sound.last_events.has("hit") and not a.sound.last_events.has("claymore-impact"),"Pirate audio remains unchanged in this first character-specific sound pass")
 print("FIRE_SIEGE_LEAN_AUDIO_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)

func quiet_voice(sound, filename: String, max_gain: float) -> bool:
 for v in sound.voices:
  if v.stream != null and v.stream.resource_path.ends_with(filename) and db_to_linear(v.volume_db) < sound.volume*max_gain:
   return true
 return false

extends RefCounted
## One immutable atlas per changed kit, never a player controller per fighter.
static func prepare(game:Node)->Dictionary:
 var profiles:Dictionary=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles").duplicate(true)
 var poses={};var cache:Dictionary=game.get_meta("army_tuning_cache",{})
 if not is_instance_valid(game.explorer_helpers):return {"profiles":profiles,"poses":poses}
 for kind in [11,5,7,8,10]:
  var speed=game.balance_value(kind,"walk_speed");var reach=game.balance_value(kind,"melee_reach") if kind!=10 else 1.0
  if absf(reach-1)<.000001 and absf(speed-float(profiles[kind].speed))<.00001:continue
  var signature=Vector2(speed,reach)
  if not cache.has(kind) or cache[kind].signature!=signature:
   var unit=load("res://scripts/forest/explorer_helper_unit.gd").new()
   unit.game=game;unit.director=game.explorer_helpers;unit.kit_id=kind;unit.slot=game.explorer_helpers.KITS.find(kind);unit.gate_id=-999999
   game.add_child(unit);unit.set_physics_process(false);unit.position=Vector3.ZERO;unit.facing=Vector3.BACK;unit.model.rotation.y=PI;unit.show()
   var row=profile(unit,profiles[kind]);var pose=preload("res://scripts/forest/crowd/army_pose_baker.gd").new().bake(unit,row)
   unit.free()
   cache[kind]={"signature":signature,"profile":row,"pose":pose}
  profiles[kind]=cache[kind].profile;poses[kind]=cache[kind].pose
 game.set_meta("army_tuning_cache",cache)
 return {"profiles":profiles,"poses":poses}
static func profile(unit,baseline:Dictionary)->Dictionary:
 var row=baseline.duplicate(true);var c=unit.active_ability;c.active=true;c.reset_run();var attacks=[]
 c.aim=Vector3.BACK*10
 for sample in 6:
  if unit.kit_id==10:c.player.rangerShots=sample
  c.Actions.begin_attack(c,c.Actions.primary_config(c,sample%3),sample%3)
  var a:Dictionary=c.player.attack;var attack={}
  for field in ["duration","contact","damage","reach","arc","stop","weaponContact","swingSide","style"]:
   if a.has(field):attack[field]=a[field]
  if unit.kit_id==10:
   var muzzles=PackedVector3Array();c.player.shot=.2
   for frame in 33:
    a.time=a.duration*frame/32.0;c._animate(0,0);muzzles.append(unit.model.hand_position("R")-unit.global_position)
   attack.muzzles=muzzles;attack.power=a.get("power",false)
  attacks.append(attack)
  if unit.kit_id==11:c.player.bladeSide*=-1
 row.primary=attacks;row.speed=unit.combat_tuning("walk_speed")*unit.movement_multiplier();row.melee_reach_scale=c.melee_reach_scale()
 return row

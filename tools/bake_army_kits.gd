extends SceneTree
## Export original kit tuning and fitted weapon reach once, outside the game loop.
const OUTPUT="res://assets/crowd/army_kit_profiles.tres"
func _initialize():run.call_deferred()
func run():
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture);var game=await fixture.make_game("original")
 var rows={}
 for unit in game.explorer_helpers.pool:
  if rows.has(unit.kit_id):continue
  var c=unit.active_ability;c.active=true;c.reset_run();var attacks=[]
  if c.class_id=="ranger":c.aim=c.player.pos+Vector3.BACK*10;unit.facing=Vector3.BACK;unit.model.rotation.y=PI
  for sample in 6:
   var index=sample%3
   if c.class_id=="ranger":c.player.rangerShots=sample
   var config:Dictionary=c.Actions.primary_config(c,index)
   c.Actions.begin_attack(c,config,index)
   var a:Dictionary=c.player.attack;var row={}
   for field in ["duration","contact","damage","reach","arc","stop","weaponContact","swingSide","style"]:
    if a.has(field):row[field]=a[field]
   if c.class_id=="ranger":
    var muzzles=PackedVector3Array();c.player.shot=.2
    for frame in 33:
     a.time=a.duration*frame/32.0;c._animate(0,0)
     muzzles.append(unit.model.hand_position("R")-unit.global_position)
    row.muzzles=muzzles;row.power=a.get("power",false)
   attacks.append(row)
   if c.class_id=="explorer":c.player.bladeSide*=-1
  var body={}
  for shape in unit.find_children("*","CollisionShape3D",true,false):
   if shape.shape is CapsuleShape3D:body={"radius":shape.shape.radius,"height":shape.shape.height,"center":shape.position.y};break
  rows[unit.kit_id]={"class":c.class_id,"hp":unit.max_hp,"speed":unit.combat_tuning("walk_speed")*unit.movement_multiplier(),"damage_multiplier":unit.damage_multiplier(),"attack_rate":unit.base_attack_speed_multiplier(),"critical_chance":unit.combat_tuning("critical_chance"),"primary":attacks,"cooldowns":c.class_data().cooldowns,"range_scale":c.range_scale(),"melee_reach_scale":c.melee_reach_scale(),"body":body,"jump_speed":unit.combat_tuning("jump_speed")*unit.progression.jump_velocity_multiplier(),"growth_scale":unit.growth_multiplier()}
 var resource=Resource.new();resource.set_meta("profiles",rows)
 var hashes={}
 for path in ["assets/rogue/scripts/class_actions.gd","scripts/rogue_roster_combat.gd","scripts/rogue_hero_model.gd","assets/rogue/scripts/actor.gd","scripts/melee_responsiveness.gd","assets/rogue/scripts/ranger_arrow_flight.gd"]:
  if FileAccess.file_exists("res://"+path):hashes[path]=FileAccess.get_sha256("res://"+path)
 resource.set_meta("source_hashes",hashes)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/crowd"));var error=ResourceSaver.save(resource,OUTPUT)
 print("ARMY_KIT_BAKE_RESULT profiles=",rows.size()," error=",error)
 await fixture.close();fixture.queue_free();await process_frame;quit(0 if error==OK and rows.size()==5 else 1)

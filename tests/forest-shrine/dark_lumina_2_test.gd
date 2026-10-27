extends "res://tests/forest-shrine/recovered_monsters_test.gd"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const Balance=preload("res://scripts/forest/core_balance.gd")
func run():
 var hero=Hero.new();var combat=preload("res://scripts/recovered_enemy_combat.gd").new();var owner=Node.new()
 combat.hero=hero;combat.role=Dark.ROLE;combat.spell_owner=owner;combat.jump_started=true
 hero.velocity=Vector3(260,120,80);combat.cancel()
 check(hero.velocity==Vector3.ZERO,"Cancelled borrowed leap clears boss ascent and horizontal momentum")
 combat.jump_started=true;hero.velocity=Vector3(260,-100,80);combat.cancel()
 check(hero.velocity==Vector3(0,-100,0),"Cancelling a descending borrowed leap preserves falling momentum")
 hero.character_id=Dark.PLAYER;combat.jump_started=true;hero.velocity=Vector3(260,120,80);combat.cancel()
 check(hero.velocity==Vector3(260,120,80),"The native-size playable fighter retains its own jump controls")
 combat.free();owner.free();hero.free()
 var tuning=preload("res://scripts/character_balance.gd")
 check(tuning.value({"max_hp":120},{},29,"max_hp")==5000,"DL2 default health is 5000 independent of the legacy baseline")
 check(tuning.value({"max_hp":120},{},1,"max_hp")==120 and tuning.value({"max_hp":120},{},2,"max_hp")==120,"DL2 health leaves Goemon and Edo baseline values intact")
 check(tuning.value({}, {tuning.key_for(29):{"max_hp":3000}},29,"max_hp")==3000,"An explicit saved DL2 health override remains authoritative")
 check(tuning.sanitized({"max_hp":5000},29).max_hp==5000,"The existing balance editor accepts 5000 HP")
 var resource=Visual.data(Dark.ROLE)
 check(resource.get_meta("part_count")==19,"DL2 retains all nineteen source body parts")
 var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_monsters/dark_lumina_2_motion.json"))
 var clips:Dictionary=resource.get_meta("clips");var poses:Array=resource.get_meta("poses")
 check(clips.size()==21,"All twenty-one recovered motion streams survive Blender and bake")
 check(resource.get_meta("source_sha256")==FileAccess.get_sha256(resource.get_meta("source_path")),"Authored manifest matches the pose bake")
 check(resource.get_meta("visual_sha256")==FileAccess.get_sha256(resource.get_meta("visual_path")),"Authored mesh matches the pose bake")
 var error=0.0;var samples=0
 for clip in original.clips:
  for frame in clip.frames:
   var row:int=clips[clip.name].rows[mini(int(frame.tick),clips[clip.name].rows.size()-1)]
   for index in 19:
    var expected=expected_pose(original.poses[frame.pose][index]);var actual:Transform3D=poses[row*19+index]
    error=maxf(error,expected.origin.distance_to(actual.origin))
    for axis in 3:error=maxf(error,(expected.basis[axis]-actual.basis[axis]).length())
    samples+=1
 check(error<.0001,"Every original part pose matches after editable export: %s"%error)
 var old=[3,5,7,11,13,17,19,2]
 var upgraded:Dictionary=Balance.from_saved({"population_version":1,"waves":[old]})
 check(upgraded.waves[0].slice(0,8)==old and upgraded.waves[0][Balance.TYPES.find(Dark.ROLE)]==0,"Older saves keep every enemy count and add zero DL2")
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 var data=load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 check(is_equal_approx(Visual.hurt_bounds(Dark.ROLE).size.y,15.552) and is_equal_approx(Roles.footprint_radius(Dark.ROLE),12.096),"Both body bounds and navigation footprint are exactly triple size")
 check(is_equal_approx(Dark.FIRE_SPEED*Dark.FIRE_LIFE,181.44) and is_equal_approx(Dark.FIRE_RADIUS,5.85),"Shared fire travels twice farther again with triple current collision radius")
 check(runtime.native.configure_kits(data),"Shared native kit accepts DL2 alongside every existing enemy")
 for delta in [1.0/20,1.0/30,1.0/60]:
  runtime.clear();runtime.set_navigation(20,{"width":0})
  var handle=runtime.spawn(1,0,Dark.ROLE,Vector3.ZERO,Dark.HEALTH,Roles.footprint_radius(Dark.ROLE))
  runtime.spawn(2,1,12,Vector3(0,0,-12),100000,.4)
  var cues={};var high=0.0;var shot_peak=0
  for i in ceili(20/delta):
   runtime.step(delta,{})
   var state=runtime.unit_state(handle);high=maxf(high,state.position.y)
   for event in runtime.take_events():
    if event.kind=="status" and event.unit_kind==Dark.ROLE:cues[event.action_index]=int(cues.get(event.action_index,0))+1
   shot_peak=maxi(shot_peak,runtime.snapshot().projectile_ids.size())
  print("DARK_CUES ",delta," ",cues," peak=",shot_peak," height=",high)
  check(cues.get(207,0)>=3 and cues.has(208) and cues.has(209) and cues.has(203),"Native boss cycles paired fire, both shockwaves and grab at %s"%delta)
  check(high>30 and high<45 and shot_peak>=2,"Boss jumps and uses existing native projectiles")
  runtime.apply_hit(handle,{"amount":100000.0})
  check(not runtime.valid(handle),"Native HP/death owns boss removal")
 runtime.clear();runtime.free()
 print("DARK_LUMINA_2_RESULT checks=",checks," failures=",failures," poses=",samples," max_error=",error)
 quit(1 if failures else 0)

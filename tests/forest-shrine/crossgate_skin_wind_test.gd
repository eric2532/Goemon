extends "res://tests/forest-shrine/crossgate_melee_wind_test.gd"
const SKIN_OUT=WIND_OUT+"Alternate Skins/"

func run():
 await setup_wind()
 var fists_only="--fists-only" in OS.get_cmdline_user_args()
 var destination=WIND_OUT+"Punch Gust/" if fists_only else SKIN_OUT
 DirAccess.make_dir_recursive_absolute(destination)
 var inventory_only="--inventory" in OS.get_cmdline_user_args()
 var rendered={}
 var appearances=0
 var combinations=0
 var p=game.player
 var expected_appearances=0;var expected_weapons=0;var expected_melee=0;var expected_fists=0
 for skins in Gear.catalog().values():
  expected_appearances+=skins.size()
  for routes in skins.values():
   expected_weapons+=routes.size()
   expected_melee+=routes.keys().filter(func(weapon):return weapon not in ["bow","kunai"]).size()
   if routes.has("unarmed"):expected_fists+=1
 for character in Gear.Roster.CROSSGATE:
  var reuse_skin=-1
  p.ai_controlled=false;p.select_character(character)
  game.update_character_tuning(character,"critical_chance",0)
  for skin in Gear.catalog()[str(character)]:
   p.ai_controlled=false;choose_skin(character,int(skin));appearances+=1
   for weapon in Gear.allowed(character,game.settings):
    if fists_only and weapon!="unarmed":continue
    p.ai_controlled=false;equip_weapon(character,weapon);combinations+=1
    if weapon in ["bow","kunai"]:
     if not inventory_only:
      for direction in 8:contact_case(character,weapon,6,direction)
     continue
    record_motion(character,weapon)
    var row:Dictionary=motion_inventory.back();row.skin=int(skin)
    if inventory_only:continue
    for multiplier in [1.0,2.0,6.0]:
     for direction in 8:contact_case(character,weapon,multiplier,direction)
    width_growth_case();damage_case()
    var source:String="%d:%s"%[character,skin] if fists_only else row.clips[3].wind_source
    if fists_only or (weapon!="unarmed" and not rendered.has(source)):
     capture_label=("Punch Gust/" if fists_only else "Alternate Skins/")+"%s-"%skin
     await wind_picture(character,weapon,1)
     rendered[source]={"character":character,"skin":int(skin),"weapon":weapon,"label":capture_label}
     if fists_only and reuse_skin<0:reuse_skin=int(skin)
   await frames(1)
  print("SKIN_WIND_CHARACTER id=%d appearances=%d combinations=%d failures=%d"%[character,appearances,combinations,failures])
  if fists_only and reuse_skin>=0:
   p.ai_controlled=false;choose_skin(character,reuse_skin);equip_weapon(character,"unarmed")
   await native_reuse()
   capture_label="Punch Gust/%d-"%reuse_skin
   for multiplier in [1.0,3.0,6.0]:await wind_picture(character,"unarmed",multiplier)
 if not fists_only and not inventory_only:
  for entry in [[34,100028,"sword"],[35,0,"sword"],[35,0,"staff"],[37,100050,"axe"],[37,100050,"polearm"],[40,100625,"staff"],[42,100774,"polearm"],[43,106125,"staff"],[44,106450,"sword"],[46,100350,"sword"],[48,120386,"sword"],[49,106708,"sword"],[50,115258,"sword"]]:
   var character:int=entry[0];var skin:int=entry[1];var weapon:String=entry[2]
   p.ai_controlled=false;p.select_character(character);choose_skin(character,skin)
   if weapon not in Gear.allowed(character,game.settings):continue
   equip_weapon(character,weapon);capture_label="Alternate Skins/reach-%d-"%skin
   await native_reuse()
   for multiplier in [1.0,3.0,6.0]:await wind_picture(character,weapon,multiplier)
  check(appearances==expected_appearances and combinations==expected_weapons and motion_inventory.size()==expected_melee,"All current Cross Gate skins and weapon choices are covered")
 if fists_only:check(appearances==expected_appearances and combinations==expected_fists,"Every currently supported Cross Gate fist appearance is covered")
 var report={"appearances":appearances,"combinations":combinations,"melee_setups":motion_inventory.size(),"checks":checks,"failures":failures,"contacts":wind_rows,"rendered":rendered,"renderer":DisplayServer.get_name()}
 var metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
 report.isolated_five_copy_step_ms=metrics.summary(wind_samples)
 report.isolated_five_copy_without_wind_ms=metrics.summary(wind_baseline_samples)
 FileAccess.open(destination+"inventory.json",FileAccess.WRITE).store_string(JSON.stringify(motion_inventory))
 FileAccess.open(destination+("inventory" if inventory_only else "headless" if DisplayServer.get_name()=="headless" else "desktop")+"-result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKIN_WIND_RESULT appearances=%d combinations=%d melee=%d checks=%d failures=%d"%[appearances,combinations,motion_inventory.size(),checks,failures])
 quit(1 if failures else 0)

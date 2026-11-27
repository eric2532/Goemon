extends "res://tests/forest-shrine/dragon_summit_review.gd"
## Process-only source roster overlay on an existing fixed-map fixture.
## This does not register the missing inquiry maps or171generated floors.
const ALTAR_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Altar Approaches/"
func _initialize():
 create_timer(1200).timeout.connect(func():printerr("ALTAR_PARTY_TIMEOUT");quit(1));run.call_deferred()
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 await super.take_view(label_,cell,yaw,screen_offset)
 if DisplayServer.get_name()=="headless":return
 var old:String=server_report.captures[-1].image
 var target=ALTAR_OUT+old.get_file()
 check(DirAccess.rename_absolute(ProjectSettings.globalize_path(old),ProjectSettings.globalize_path(target))==OK,"Altar fixture capture saved")
 server_report.captures[-1].image=target
func run():
 root.size=Vector2i(1280,800);review_hp=1000000000.
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-altar-review-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=20261127;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));var items:Dictionary=get_meta(Events.ITEMS,{}).duplicate(true)
 var roster:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ALTAR_OUT+"Staged/encounters.json"))
 var data:Dictionary=East.data();var original_species=data.species.size()
 check(roster.species.slice(0,original_species)==data.species,"Private roster preserves established species prefix")
 data.species.append_array(roster.species.slice(original_species))
 for key in roster.groups:
  check(not data.groups.has(key),"Private source group has no other owner")
  data.groups[key]=roster.groups[key].duplicate(true)
  for detail in data.groups[key].details:
   detail.level=[int(detail.raw_enemy[4]),int(detail.raw_enemy[5])]
   detail.count=[int(detail.raw_enemy[6]),int(detail.raw_enemy[7])];detail.exp_override=int(detail.raw_enemy[9])
 Original.Art.load_sokia_dragon_summit()
 var row:Dictionary=Original.Art.data().maps[Original.path_for(15572)];var old_gate=row.sokia_visual_only
 check(old_gate,"Source fixture map remains gated in production");row.sokia_visual_only=false
 for config in [408,410,414,420]:
  var branch:Dictionary=roster.generated_branches.filter(func(b):return int(b.config)==config)[0]
  await fixture_pool(15572,branch.pool,"altar-config-"+str(config))
 check(trial_report.groups.size()==4,"All three pools and all four config level intervals exercised directly")
 row.sokia_visual_only=old_gate
 for key in roster.groups:data.groups.erase(key)
 data.species.resize(original_species)
 check(data.species.size()==258 and not data.groups.has("altar:16023"),"Private source roster overlay removed")
 check(JSON.stringify(get_meta("falan_venture"))==saved and get_meta(Events.ITEMS,{})==items,"Adventure and items preserved")
 dragon_report.checks=checks;dragon_report.failures=errors;dragon_report.groups=trial_report.groups;dragon_report.captures=server_report.captures
 dragon_report.source_sha256={}
 for path in [ALTAR_OUT+"Staged/encounters.json","res://assets/characters/crossgate/guard_pets/motions.json","res://scripts/forest/forest_waves.gd"]:dragon_report.source_sha256[path]=FileAccess.get_sha256(path)
 dragon_report.qualification="Direct native contacts and pooled reuse for the staged original eight-enemy group at all four config intervals. Private roster and ambient overlays on existing fixed15572only; no actual inquiry/generated map, natural probability, self-follow-on execution, original AI, scenery or performance certification. Hero recordingHP enlarged; enemy counts and native combat timing retained."
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered";var f=FileAccess.open(ALTAR_OUT+"native-parties-"+mode+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify(dragon_report,"  "));f.close();print("ALTAR_PARTY_RESULT checks=",checks," failures=",errors)
 game.army_runtime.finish_integration();game.queue_free()
 for i in 4:await process_frame
 quit(1 if errors else 0)

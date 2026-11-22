extends "res://tests/forest-shrine/tina_explorer_review.gd"
var npcs
const Conversations=preload("res://assets/maps/falan/npc_dialogue.gd")
const DIALOGUE_OUT="res://build/Other Files/Asset Toolkit/Falan NPC Dialogue/"

func run():
 var count=0;var appearances={}
 for area in Tour.NPCS.AREAS:
  for npc in Tour.NPCS.AREAS[area]:
   count+=1;appearances[npc[1]]=true
   check(Conversations.REMARKS.has(npc[1]),"Appearance coverage "+npc[2])
   var lines=Conversations.lines_for(npc)
   check(lines.size()>=2 and lines.all(func(line):return line is String and not line.strip_edges().is_empty() and line.length()<=96),"Readable varied dialogue "+npc[2])
   check(lines[0]!=lines[1],"Distinct bag entries "+npc[2])
 check(count==373 and appearances.size()==127,"Every preserved Falan placement and appearance is covered")
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-falan-dialogue-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.explorer_clock.load_hour(12)
 npcs=game.explorer_npcs
 var venture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/web_adventure.json"))
 for area in ["city","castle","1011","1071","1402","1511","1522"]:
  var layout:Dictionary=venture.falan_areas[area] if area in ["city","castle"] else Tour.Indoor.layout(int(area))
  Tour.travel(game,layout,{"arrival":Vector2.ZERO,"yaw":0.0})
  for i in 4:await physics_frame
  npcs.prepare()
  var citizens=game.world.map_features.find_child("OriginalFalanNPCs",true,false)
  check(citizens.get_child_count()==Tour.NPCS.AREAS[area].size(),"Original art and placement counts unchanged "+area)
  check(npcs.actors.size()==Tour.NPCS.AREAS[area].size(),"Existing owner registers every local citizen "+area)
  var nodes=game.world.map_features.get_child_count()
  for i in 3:npcs.prepare()
  check(game.world.map_features.get_child_count()==nodes,"Repeated setup reuses original sprites without accumulating prompts "+area)
  check(npcs.actors[0].record.portrait==citizens.get_child(0).texture,"Portrait reuses speaker's exact atlas texture "+area)
  # Use the existing proximity/path check and real F input, with an open approach to the speaker.
  var actor=npcs.actors[0]
  game.player.position=actor.node.global_position;game.player.position.y=game.model.world_height(game.player.position.x,game.player.position.z)+.15
  game.player.velocity=Vector3.ZERO;npcs.update_left=0;npcs._process(.2)
  check(not npcs.nearest.is_empty(),"Local discovery offers a talk prompt "+area)
  var expected=npcs.nearest.get("record",actor.record)
  var before=game.settings.explorer_quests.duplicate(true)
  var gold=game.model.gold
  var key=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true;game._input(key)
  check(is_instance_valid(game.dialogue) and game.paused,"F opens shared paused conversation "+area)
  if is_instance_valid(game.dialogue):
   check(game.dialogue.speaker==expected.name and game.dialogue.portrait.texture==expected.portrait,"Speaker and original appearance match "+area)
   var badge=game.dialogue.canvas.get_children().filter(func(child):return child is Panel and child!=game.dialogue.panel)[0]
   var label=game.dialogue.canvas.get_children().filter(func(child):return child is Label and child.text==expected.name)[0]
   check(badge.get_rect().encloses(label.get_rect()),"Nameplate fits the complete speaker name "+area)
   if DisplayServer.get_name()!="headless":
    await reveal()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIALOGUE_OUT))
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(DIALOGUE_OUT+area+"-dialogue.png")
   await drain()
  check(not game.paused and not is_instance_valid(game.dialogue),"Space release resumes gameplay "+area)
  var after=game.settings.explorer_quests.duplicate(true)
  check(after==before and game.model.gold==gold,"Casual dialogue leaves inventory and gold intact "+area)
  var seen={};var messages=actor.record.messages
  npcs.talk_bags.erase(actor.record.id)
  for i in messages.size():
   npcs.nearest=actor;check(npcs.interact(),"Repeated talk opens "+area)
   if is_instance_valid(game.dialogue):seen[game.dialogue.body.text]=true
   await drain()
  check(seen.size()==messages.size(),"Shuffle bag exhausts every remark before repeating "+area)
  npcs.nearest=actor;check(npcs.interact(),"Exhausted dialogue bag refills "+area);await drain()
 game.player.position=game.model.world_point(Vector2(-9999,-9999),.15);npcs.update_left=0;npcs._process(.2)
 check(npcs.nearest.is_empty() and not npcs.interact(),"F remains available to other commands outside conversation range")
 DirAccess.remove_absolute(game.settings_path)
 print("FALAN_NPC_DIALOGUE_RESULT checks=%d failures=%d"%[checks,failures])
 finish()

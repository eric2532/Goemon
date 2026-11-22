extends "res://tests/forest-shrine/tina_npcs_quests_test.gd"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const SHOPS="res://build/Other Files/Asset Toolkit/Tina Recovery/Shops/"
func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await reveal();await process_frame
 DisplayServer.window_move_to_foreground();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(SHOPS+stem+".png")==OK,"Captured "+stem)
func train(tech:int,key:String,slot:int):
 npcs.choose("petshop:tech:%d"%tech);npcs.choose("petshop:pet:"+key);npcs.choose("petshop:slot:%d"%slot)
func run():
 root.size=Vector2i(1440,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOPS))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-tina-shops-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.set_process(false);game.tuning.invincible=true;game.explorer_clock.load_hour(12)
 npcs=game.explorer_npcs;npcs.load_state({});game.model.gold=100000
 await visit_source(4208,Vector2i(17,12))
 check(npcs.data.unresolved_items.is_empty() and npcs.data.merchant_stock.is_empty(),"Merchant dialogue IDs are messages, with no fabricated item stock")
 await speak(1050)
 check(game.dialogue.pages.back().options.any(func(c):return c[0]=="shop:sell") and not game.dialogue.pages.back().options.any(func(c):return c[0]=="shop:buy"),"Source mode 2 offers buyback only")
 await picture("merchant-greeting")
 npcs.give_item(12800,2);npcs.give_item(10400);npcs.give_item(9600);npcs.give_item(41178)
 npcs.choose("shop:sell")
 check(npcs.service_choices.any(func(c):return c[0]=="sell:12800") and npcs.service_choices.any(func(c):return c[0]=="sell:9600") and not npcs.service_choices.any(func(c):return c[0]=="sell:41178"),"Merchant accepts source herb/cloth categories and refuses zero-price quest goods")
 await picture("merchant-buyback")
 var gold=game.model.gold;npcs.choose("sell:12800");check(game.model.gold==gold,"Selecting goods waits for an explicit sale quantity");await picture("merchant-quantity");npcs.choose("sell:12800:1")
 check(npcs.count_item(12800)==1 and game.model.gold==gold+22,"Buyback uses truncated 80 percent source price")
 var before=npcs.state.duplicate(true);gold=game.model.gold
 for answer in ["buy:9600","sell:41178","sell:-1","sell:NaN","sell:999999","sell:12800:-1","sell:12800:999","sell:12800:NaN"]:npcs.choose(answer)
 check(npcs.state==before and game.model.gold==gold,"Forged, disallowed and retail choices cannot change inventory or gold")
 npcs.choose("cancel")
 var a=Pets.key(0);var b=Pets.key(21)
 check(game.save_pet_loadout([a,b],{}),"Test party uses the existing native pet loadout")
 await speak(8608)
 check(not is_instance_valid(game.pet_loadout_panel) and npcs.service_choices.size()==10,"Source pet shop opens ten tier-III teaching choices")
 for i in npcs.data.pet_shops["8608"].techniques.size():
  var tech=npcs.data.pet_shops["8608"].techniques[i];var id="pet/%d"%int(tech.id)
  check(Pets.SKILLS[id]==tech.name and Pets.mana_cost(id)==int(tech.mp) and Pets.skill_codes([id])[0]==12+i,"Catalog and native wire preserve source technique "+str(tech.id))
 await picture("pet-techniques")
 root.size=Vector2i(960,640);await process_frame
 await picture("pet-techniques-small")
 check(game.dialogue.options.get_children().all(func(button):return root.get_visible_rect().encloses(button.get_global_rect())),"Teaching choices fit the smaller Explorer window")
 root.size=Vector2i(1440,900);await process_frame
 npcs.choose("page:1");await picture("pet-techniques-page2")
 npcs.choose("page:2");await picture("pet-techniques-page3")
 npcs.choose("petshop:tech:34");gold=game.model.gold;npcs.choose("petshop:pet:"+a)
 check(game.model.gold==gold and not game.settings.forest_pet_skills.has(a),"Under-level pet cannot learn or spend gold")
 var experience=game.model.team_progression.Experience.new();experience.level=30;game.model.team_progression.pet_experience[a]=experience
 var other=game.model.team_progression.Experience.new();other.level=30;game.model.team_progression.pet_experience[b]=other
 npcs.choose("petshop:tech:34");await picture("pet-selection")
 npcs.choose("petshop:pet:"+a);await picture("pet-skill-slots")
 npcs.choose("petshop:slot:0");await picture("pet-confirm")
 check(game.model.gold==gold and not game.settings.forest_pet_skills.has(a),"Choosing a slot waits for confirmation")
 npcs.choose("petshop:confirm:1")
 check(game.model.gold==gold,"An unconfirmed slot cannot spend gold")
 game.model.gold=0;npcs.choose("petshop:confirm:0")
 check(not game.settings.forest_pet_skills.has(a) and game.model.gold==0,"Insufficient gold preserves the old loadout")
 game.model.gold=100000;gold=game.model.gold
 var path=game.settings_path;game.settings_path="/dev/null/tina.cfg"
 var old_training=npcs.state.duplicate(true);var old_skills=game.settings.forest_pet_skills.duplicate(true)
 npcs.choose("petshop:confirm:0");game.settings_path=path
 check(game.model.gold==gold and npcs.state==old_training and game.settings.forest_pet_skills==old_skills,"Failed preference write rolls back fee, training and skill slots together")
 await reveal()
 var button=game.dialogue.options.get_child(0)
 root.gui_disable_input=false
 var event=InputEventMouseButton.new();event.device=104;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=button.get_global_rect().get_center();root.push_input(event,true)
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;root.gui_disable_input=true
 check(game.settings.forest_pet_skills[a]==["pet/34","",""] and game.model.gold==gold-4000,"Actual confirmation click teaches selected pet at source fee")
 gold=game.model.gold;npcs.choose("petshop:confirm:0")
 check(game.model.gold==gold,"Repeated confirmation cannot charge twice")
 for tech in npcs.data.pet_shops["8608"].techniques:
  if int(tech.id)==34:continue
  train(int(tech.id),b,1);gold=game.model.gold;npcs.choose("petshop:confirm:1")
  check(game.settings.forest_pet_skills[b][1]=="pet/%d"%int(tech.id) and game.model.gold==gold-int(tech.fee),"Source technique teaches through the same slots and fee: "+str(tech.name))
  check(game.settings.forest_pet_skills[a]==["pet/34","",""],"Teaching another pet preserves the first pet's skill")
 npcs.choose("petshop:tech:1234");npcs.choose("petshop:pet:"+b);gold=game.model.gold;npcs.choose("petshop:slot:0")
 check(game.model.gold==gold and game.settings.forest_pet_skills[b][0]=="","Already-equipped technique cannot be duplicated or charged")
 npcs.choose("cancel")
 var stored=npcs.state.duplicate(true);var skills=game.settings.forest_pet_skills.duplicate(true)
 check(npcs.persist(),"Training and buyback save through the existing atomic preference boundary")
 npcs.load_state({});game.load_settings()
 check(npcs.state.pet_training==stored.pet_training and npcs.state.items==stored.items and game.settings.forest_pet_skills==skills,"Training, loadout and retained inventory survive reload")
 var sanitized=stored.duplicate(true);sanitized.pet_training["invalid:pet"]=[34];sanitized.pet_training[a]=[34,34,-1,"bad",999]
 npcs.load_state(sanitized)
 check(not npcs.state.pet_training.has("invalid:pet") and npcs.state.pet_training[a]==[34],"Malformed saved teaching records are bounded and validated")
 await visit_source(4200,Vector2i(38,46));game.explorer_clock.load_hour(0)
 await visit_source(4230,Vector2i(18,13))
 check(not npcs.actors.any(func(e):return int(e.record.id) in [1050,8608]),"Daytime vendors do not leak into the night pub")
 if "--combat-review" in OS.get_cmdline_user_args():await combat_review()
 finish()

func combat_review():
 game.explorer_clock.load_hour(0);await visit_source(4201,Vector2i(60,51))
 game.forest_ui.message="";game.forest_ui.message_left=0
 var army=game.army_runtime
 army.set_process(false);army.set_physics_process(false);game.player.set_physics_process(false)
 game.camera_rig.set_process(false)
 var pack=[Pets.key(0),Pets.key(61)]
 for key in pack:
  var xp=game.model.team_progression.Experience.new();xp.level=30;game.model.team_progression.pet_experience[key]=xp
  game.model.team_progression.pet_stat_ranks[key]={"mana":3}
 check(game.save_pet_loadout(pack,{pack[0]:["pet/34","",""],pack[1]:["pet/1234","",""]}),"Explorer combat uses the taught native skill slots")
 army.refresh_kits();army.queue_hounds();army.record_events=true
 for tick in 180:
  army.integration_tick(1.0/60)
  if army.pending_hounds.is_empty():break
 check(army.pending_hounds.is_empty(),"Explorer summons the selected pets through the existing native lifecycle")
 var fighter:int=army.handles.get(army.HOUND_ID,0);var healer:int=army.handles.get(army.HOUND_ID-61,0)
 if fighter==0 or healer==0:check(false,"Both native test pets exist");return
 var origin:Vector3=army.unit_state(fighter).position
 var position=origin+Vector3.FORWARD*2.5
 for offset in [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]:
  var candidate=origin+offset*2.5;candidate.y=game.model.surface_height(candidate.x,candidate.z)
  if army.native.can_reach(origin,candidate,.5):position=candidate;break
 var enemy=game.model.waves.spawn_enemy(game.EnemyRoles.SLIME,position,-1,13)
 enemy.hp=1000000;enemy.max_hp=1000000
 army.import_arrivals();army.sync_targets()
 var maximum=float(army.unit_state(healer).max_hp)
 army.apply_hit(healer,{"amount":maximum*.5,"source_id":enemy.id})
 var old_hp=float(army.unit_state(healer).hp)
 game.camera_rig.camera.global_position=position+Vector3(-10,12,14);game.camera_rig.camera.look_at(position+Vector3.UP*1.5)
 army.event_log.clear();var attack=false;var heal=false;var captured=false
 for tick in 480:
  army.integration_tick(1.0/60);army.flush_presentation()
  for event in army.event_log:
   if event.kind=="pet_skill_started" and event.action_index==12:attack=true
   if event.kind=="pet_skill_started" and event.action_index==21:heal=true
  if tick==90 or (attack and heal and not captured and float(army.unit_state(healer).hp)>old_hp):
   captured=true
   if DisplayServer.get_name()!="headless":
    game.forest_ui.sync();DisplayServer.window_move_to_foreground();await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(SHOPS+"explorer-trained-pets.png")
  if attack and heal and float(army.unit_state(healer).hp)>old_hp:break
  await process_frame
 check(attack and heal,"Both purchased techniques start through the native Explorer attack clock")
 check(float(army.unit_state(healer).hp)>old_hp,"Native 明镜止水 heals the summoned Explorer pet")
 check(game.model.enemies[enemy.id].hp<1000000,"Native 连击 damages the real Explorer enemy")

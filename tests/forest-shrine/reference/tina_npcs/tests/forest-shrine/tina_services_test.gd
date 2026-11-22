extends "res://tests/forest-shrine/tina_npcs_quests_test.gd"

func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-tina-services-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.set_process(false);game.tuning.invincible=true;game.explorer_clock.load_hour(12)
 npcs=game.explorer_npcs;npcs.load_state({});game.model.gold=100000
 await visit_source(4210,Vector2i(12,8));game.player.hp=100;game.player.mana=10
 await speak(7511);var gold=game.model.gold;npcs.choose("heal:hp")
 check(game.player.hp==game.player.max_hp and game.player.mana==10 and game.model.gold==gold,"Nurse restores HP for free without spending mana")
 await speak(7511);var fee=ceili(game.player.max_mana-10);npcs.choose("heal:mp")
 check(game.player.mana==game.player.max_mana and game.model.gold==gold-fee,"MP restoration charges the actual missing amount once")
 await speak(7511);game.player.mana=0;game.model.gold=0;npcs.choose("heal:mp")
 check(game.player.mana==0 and game.model.gold==0,"Insufficient funds cannot restore MP or produce negative gold");npcs.choose("cancel")
 game.model.gold=100000
 await visit_source(4208,Vector2i(16,5));await speak(1050);npcs.choose("shop:buy")
 check(npcs.data.merchant_stock.is_empty(),"Buyback merchant has no invented retail stock")
 npcs.choose("cancel");await speak(1050);npcs.give_item(12800,2);npcs.choose("shop:sell")
 var id=12800;var price=int(int(npcs.data.items[str(id)].price)*.8);gold=game.model.gold
 npcs.choose("sell:"+str(id)+":1")
 check(npcs.count_item(id)==1 and game.model.gold==gold+price,"Merchant buys accepted source goods at the recorded buyback rate")
 var before=npcs.state.duplicate(true);gold=game.model.gold;npcs.choose("buy:9600");npcs.choose("sell:41178")
 check(npcs.state==before and game.model.gold==gold,"Buyback merchant rejects retail and quest-reward requests");npcs.choose("cancel")
 for record in npcs.data.npcs:
  if record.type!="Skillmaster":continue
  var skill=record.args.split("|")[0];await visit_source(int(record.floor),Vector2i(record.cell[0],record.cell[1]+1));await speak(int(record.id))
  gold=game.model.gold;npcs.choose("learn:"+skill)
  check(npcs.state.learned.has(skill) and game.model.gold==gold-int(npcs.data.skills[skill].fee),"Teacher learns the exact source skill and fee "+skill)
  gold=game.model.gold;npcs.choose("learn:"+skill);check(game.model.gold==gold,"Learning twice never charges again "+skill)
  npcs.choose("cancel")
 check(npcs.state.learned.size()==7,"All seven source teachers have functioning learning services")
 await visit_source(51005,Vector2i(38,44));await speak(8244);npcs.choose("board:write")
 check(game.dialogue.entry.visible,"The source board opens actual text input")
 game.dialogue.entry.text="蒂娜村的冒險留言";game.dialogue.entry.text_submitted.emit(game.dialogue.entry.text)
 check(npcs.state.board==["蒂娜村的冒險留言"],"Unicode messages post through the actual text-submission signal")
 if DisplayServer.get_name()!="headless":await reveal();await snap("services-board")
 npcs.choose("cancel")
 await speak(770966);npcs.choose("house:rent")
 check(npcs.state.house.get("id")=="4803","The original housing notice creates a saved lease")
 gold=game.model.gold;npcs.choose("house:enter")
 for i in 8:await physics_frame
 check(game.model.falan_floor==1850 and game.model.gold==gold,"Rented housing enters the original apartment template without another charge")
 if DisplayServer.get_name()!="headless":await snap("services-house")
 var house=npcs.data.houses["4803"];game.player.position=game.model.world_point(Original.source_point(1850,Vector2i(house.exit[0],house.exit[1])))
 npcs.house_door()
 for i in 8:await physics_frame
 check(Original.source_id(game.model.falan_floor)==4200,"Walking through the apartment exit returns to Tina")
 npcs.item_bag();npcs.choose("skills");game.player.mana=50;npcs.choose("cast:59")
 check(npcs.ward==59 and game.player.mana==30,"Learned physical ward can be used from Explorer inventory")
 check(npcs.incoming_damage(90,true)==90 and npcs.ward==59,"Physical ward ignores magic without consuming its charge")
 check(npcs.incoming_damage(90,false)==0 and npcs.ward==0,"Physical ward blocks exactly one physical hit")
 npcs.item_bag();npcs.choose("skills");game.player.mana=50;npcs.choose("cast:52")
 game.player.spell_loadout.casting_id="kazi/fire";var damage=game.player.magic_spell_damage(100);npcs.prayer_left=0
 check(is_equal_approx(damage,game.player.magic_spell_damage(100)*1.2),"Fire prayer modifies matching damage through the shared player damage calculation")
 game.player.spell_loadout.casting_id=""
 npcs.item_bag();npcs.choose("skills");game.player.mana=50;npcs.choose("cast:54")
 check(npcs.prayer_left==0 and game.player.mana==50,"Attribute reversal cannot spend mana without an active prayer");npcs.choose("cancel")
 npcs.prayer=52;npcs.prayer_left=20;npcs.item_bag();npcs.choose("skills");npcs.choose("cast:54")
 check(npcs.prayer==51 and game.player.mana==30,"Attribute reversal changes the active Explorer prayer")
 npcs.item_bag();npcs.choose("skills");game.player.mana=50;npcs.choose("cast:60")
 game.tuning.invincible=false;game.player.invuln=0;game.player.hp=game.player.max_hp;var hp=game.player.hp
 game.player.take_hit_from(20,Vector3.BACK,false,0,false,false,true)
 check(game.player.hp==hp and npcs.ward==0,"The actual magic-hit path consumes its ward without hurting the player")
 game.tuning.invincible=true
 var old_area=game.model.falan_area;var old_detail=game.model.terrain_detail
 game.model.falan_area="";game.model.terrain_detail="";npcs.ward=59;npcs.ward_left=20;npcs.prayer=52;npcs.prayer_left=20
 game.player.spell_loadout.casting_id="kazi/fire"
 check(npcs.incoming_damage(90,false)==90 and npcs.ward==59 and npcs.magic_multiplier(game.player)==1.0,"Explorer effects cannot alter Arena combat")
 game.model.falan_area=old_area;game.model.terrain_detail=old_detail;game.player.spell_loadout.casting_id=""
 var stored=npcs.state.duplicate(true);check(npcs.persist(),"Services save atomically")
 npcs.load_state({});game.load_settings()
 check(npcs.state.board==stored.board and npcs.state.learned==stored.learned and npcs.state.house==stored.house,"Messages, learned skills and rental survive preference reload")
 await visit_source(14036,Vector2i(21,11));await speak(20540);npcs.choose("forget:54")
 check(not npcs.state.learned.has("54"),"The teacher forgets a learned skill without deleting other progress");npcs.choose("cancel")
 finish()

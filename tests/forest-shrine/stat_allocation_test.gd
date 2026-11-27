extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Progression=preload("res://scripts/forest/team_progression.gd")
const OUT="res://build/Other Files/Stat Allocation/Critical Chance/"
var timings:Array[int]=[]

func toggle_status_fixture():
 if is_instance_valid(game.status_panel):game.close_status_panel()
 else:game.show_status_panel()

func click(control:Control):
 var event=InputEventMouseButton.new();event.device=104;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=control.get_global_rect().get_center()
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func unit_checks():
 var state=Progression.new();state.cards_enabled=false
 check(state.stat_points==0 and not state.spend_stat("vitality"),"Level one has no points to spend")
 state.award_kills(48)
 check(state.level==3 and state.stat_points==2 and state.pending()==0 and state.offer.is_empty(),"Batched levels grant points with cards disabled")
 check(state.stat_health_bonus()==40,"Every gained level grants 20 HP")
 check(is_equal_approx(state.stat_damage_multiplier(),1.06) and is_equal_approx(state.stat_attack_multiplier(),1.0) and state.stat_critical_chance_bonus()==0 and state.stat_defense()==4 and state.stat_ranks.values().all(func(value):return value==0),"Two levels improve damage and defense while speed and critical chance require points")
 check(not state.spend_stat("crit") and not state.spend_stat("dodge") and not state.spend_stat("hit_rate") and state.stat_points==2,"Unknown stats cannot consume points")
 check(state.spend_stat("vitality") and state.stat_health_bonus()==140 and is_equal_approx(state.stat_regeneration(),1.0),"Vitality grants HP and regeneration")
 check(state.spend_stat("attack") and is_equal_approx(state.stat_damage_multiplier(),1.21) and not state.spend_stat("defense"),"Points cannot be overspent")
 state.reset();state.award_kills(1000000)
 check(state.level==99 and state.stat_points==98,"Maximum level has exactly 98 earned points")
 for i in 98:check(state.spend_stat("defense"),"Spend earned defense point")
 check(state.stat_incoming_multiplier()>0 and is_equal_approx(state.stat_incoming_multiplier(),100.0/1276),"Defense diminishes without immunity")
 state.award_enemy(1000);check(state.stat_points==0,"XP beyond the cap grants no points")
 state.reset();check(state.stat_points==0 and state.stat_health_bonus()==0 and state.stat_ranks.values().all(func(value):return value==0),"New runs clear stat allocations")
 check(state.stat_damage_multiplier()==1 and state.stat_attack_multiplier()==1 and state.stat_defense()==0 and state.stat_magic_defense()==0,"Level one has no automatic combat bonuses after reset")

func run():
 create_timer(180).timeout.connect(func():quit(1));DirAccess.make_dir_recursive_absolute(OUT)
 unit_checks();root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.settings.forest_pet_loadout=[]
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;var state=game.model.team_progression
 p.select_character(p.RogueRoster.KAZI_ID);p.refresh_max_health();p.hp=p.max_hp
 fresh();p.set_auto_attack(false);game.tuning.invincible=false;game.tuning.enemy_damage=1.0
 game.settings.forest_level_up_cards=false;state.cards_enabled=false
 var baseline_hp=p.max_hp;var baseline_damage=p.damage_multiplier();var baseline_rate=p.base_attack_speed_multiplier()
 var source_tuning=game.character_tuning.duplicate(true);var settings=game.settings.duplicate(true)
 var saved_before=FileAccess.get_sha256(game.settings_path)
 toggle_status_fixture();await frames()
 check(is_instance_valid(game.status_panel) and game.paused and paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"The stat fixture pauses gameplay and releases the pointer")
 check(game.status_panel.name_label.text==p.RogueRoster.name_for(p.character_id),"The panel resolves the controlled fighter name")
 check(game.status_panel.buttons.size()==Progression.STAT_NAMES.size() and game.status_panel.buttons.values().all(func(button):return button.disabled),"All stat buttons appear and zero points disables all")
 check(not game.spend_level_stat("attack"),"The game rejects spending without points")
 toggle_status_fixture();await frames()
 check(not is_instance_valid(game.status_panel) and not game.paused and not paused,"Closing the stat fixture resumes the wave")
 game.award_team_kill(480)
 check(state.level==3 and state.stat_points==2 and p.max_hp==baseline_hp+40 and p.hp==p.max_hp,"Real XP grants both automatic HP and all earned points")
 check(is_equal_approx(p.damage_multiplier(),baseline_damage*1.06) and is_equal_approx(p.base_attack_speed_multiplier(),baseline_rate) and state.stat_defense()==4 and state.stat_points==2,"Live player gains damage and defense without automatic speed or spent points")
 check(state.pending()==0 and not is_instance_valid(game.team_upgrade_picker),"Level-up points never open the disabled card picker")
 toggle_status_fixture();await frames()
 var panel=game.status_panel
 await click(panel.buttons.vitality)
 check(state.stat_points==1 and state.stat_ranks.vitality==1 and p.max_hp==baseline_hp+140,"A real pointer click spends exactly one Vitality point and refreshes HP")
 panel.buttons.attack.pressed.emit()
 check(state.stat_points==0 and is_equal_approx(p.damage_multiplier(),baseline_damage*1.21),"The real Attack button increases live damage")
 panel.buttons.attack.pressed.emit()
 check(state.stat_ranks.attack==1 and panel.buttons.values().all(func(button):return button.disabled),"Stale clicks cannot overspend")
 var before=p.hp;p.hp-=10;var injured=p.hp;p._physics_process(1)
 check(p.hp==injured,"Regeneration is paused while Stats is open")
 game.close_status_panel();await frames()
 for rate in [20,30,60]:
  p.hp=p.max_hp-10
  for i in rate:p._physics_process(1.0/rate)
  check(is_equal_approx(p.hp,p.max_hp-9.0),"Regeneration is frame-rate independent at %d Hz"%rate)
 p.hp=p.max_hp;p._physics_process(1);check(p.hp==p.max_hp,"Regeneration cannot exceed maximum HP")
 p.hp=0;p._physics_process(1);check(p.hp==0,"Regeneration cannot revive a defeated player");p.hp=p.max_hp
 game.award_team_kill(1120);game.show_status_panel();await frames()
 panel=game.status_panel;panel.buttons.attack_speed.pressed.emit();panel.buttons.defense.pressed.emit()
 check(state.stat_ranks.attack_speed==1 and state.stat_ranks.defense==1 and is_equal_approx(p.base_attack_speed_multiplier(),baseline_rate*1.10),"Attack Speed and Defense buttons consume their own points")
 check(is_equal_approx(state.stat_incoming_multiplier(),100.0/118),"Defense applies its live reduction")
 var committed=p.attack_chain.make_ticket("coin")
 game.close_status_panel();await frames()
 game.award_team_kill(state.kills_required()*10);game.show_status_panel();await frames();panel=game.status_panel
 await click(panel.buttons.critical_chance)
 check(state.stat_ranks.critical_chance==1 and state.stat_points==0 and p.combat_tuning("critical_chance")==1,"A pointer click spends one point for one percentage point of critical chance")
 check(committed.critical_chance==0 and p.attack_chain.make_ticket("coin").critical_chance==1 and panel.values[7].text=="1.0%","New attacks and Stats use allocated chance while released attacks retain their snapshot")
 await capture("Stats in game")
 root.size=Vector2i(960,640);await frames();await capture("Stats small")
 check(root.get_visible_rect().encloses(panel.panel.get_global_rect()),"The complete panel fits the smaller window")
 for id in panel.buttons:check(panel.panel.get_global_rect().encloses(panel.buttons[id].get_global_rect()),"The plus button fits: "+id)
 check(game.forest_ui.find_child("CharacterStatsButton",true,false)==null,"Stats uses its hotkey without restoring the bottom HUD button")
 root.size=Vector2i(1280,800)
 game.close_status_panel();await frames();p.invuln=0;p.hp=p.max_hp
 before=p.hp;p.take_hit(100,Vector3.RIGHT,true)
 check(is_equal_approx(before-p.hp,100*state.stat_incoming_multiplier()),"A physical projectile is reduced once by Defense")
 p.invuln=0;p.hp=p.max_hp;before=p.hp;p.take_hit_from(100,Vector3.RIGHT,true,0,false,false,true)
 var magic_before:float=before-p.hp
 check(is_equal_approx(magic_before,10000.0/(100.0+state.stat_magic_defense())) and magic_before>100*state.stat_incoming_multiplier(),"A magic projectile uses Magic defense independently of the physical upgrade")
 state.stat_points=1;check(state.spend_stat("magic_defense"),"Spend one shared point on Magic defense")
 p.invuln=0;p.hp=p.max_hp;before=p.hp;p.take_hit_from(100,Vector3.RIGHT,false,0,false,false,true)
 check(is_equal_approx(before-p.hp,10000.0/(100.0+state.stat_magic_defense())) and before-p.hp<magic_before,"Magic defense reduces spell damage even without a projectile")
 p.cancel_charge(true);p.invuln=0;p.hp=p.max_hp
 var allocated=state.stat_ranks.duplicate();var point_count=state.stat_points
 for id in p.RogueRoster.CROSSGATE:
  p.select_character(id);p.refresh_max_health()
  check(state.stat_ranks==allocated and state.stat_points==point_count and is_equal_approx(p.max_hp,p.combat_tuning("max_hp")+state.stat_health_bonus()),"Switching fighter retains points above that fighter's baseline")
  check(p.combat_tuning("critical_chance")==game.hero_tuning("critical_chance")+1,"Critical allocation follows the controlled fighter")
 p.select_character(34);fresh();p.hp=p.max_hp
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:check(mirrors.reinforce(p.character_id,p.global_position+Vector3(i*3,0,5)),"Allied fighter uses the native army")
 for body in mirrors.bodies:
  check(not body.uses_level_stats() and is_equal_approx(body.max_hp,p.max_hp-p.level_health_bonus()),"Player HP allocation does not leak into allied bodies")
  check(is_equal_approx(body.damage_multiplier(),p.damage_multiplier()/state.stat_damage_multiplier()),"Allied damage keeps its own baseline")
  check(is_equal_approx(body.base_attack_speed_multiplier(),p.base_attack_speed_multiplier()/state.stat_attack_multiplier()),"Allied speed excludes allocated player bonuses")
  check(body.combat_tuning("critical_chance")==game.balance_value(body.character_id,"critical_chance"),"Allied copies retain baseline critical chance")
 mirrors.dispose();await frames(5)
 game.show_status_panel();await frames();game.close_status_panel();await frames(5)
 var node_count=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for cycle in 12:
  var started=Time.get_ticks_usec();game.show_status_panel();timings.append(Time.get_ticks_usec()-started)
  await frames();game.close_status_panel();await frames(3)
 print("STAT_PANEL_REUSE nodes=",node_count," -> ",get_node_count()," resources=",resources," -> ",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 check(get_node_count()<=node_count and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated panel use retains no nodes or resources")
 check(game.settings==settings and game.character_tuning==source_tuning and FileAccess.get_sha256(game.settings_path)==saved_before,"Allocation leaves saved baseline settings untouched")
 check(not game.spend_level_stat("attack"),"Spending through a closed panel is rejected")
 game.preview_forest_map(doc.data,false,false,true);await frames()
 check(game.model.team_progression==state and state.stat_ranks==allocated and p.level_health_bonus()>0,"Area changes retain this runner and its stat allocations")
 game.start_wave();game.award_team_kill(10000000);game.show_status_panel();await frames()
 panel=game.status_panel
 var baseline_chance=game.tuning.critical_chance
 game.tuning.critical_chance=99;panel.refresh()
 var points_before=state.stat_points
 check(p.combat_tuning("critical_chance")==100 and panel.buttons.critical_chance.disabled and not game.spend_level_stat("critical_chance") and state.stat_points==points_before,"Baseline plus allocated chance clamps to 100 and cannot waste another point")
 game.tuning.critical_chance=baseline_chance;panel.refresh()
 state.stat_points=100
 for i in 99:panel.buttons.critical_chance.pressed.emit()
 points_before=state.stat_points
 check(state.stat_ranks.critical_chance==100 and p.combat_tuning("critical_chance")==100 and panel.buttons.critical_chance.disabled,"Repeated allocations reach guaranteed critical hits and disable the capped stat")
 check(not state.spend_stat("critical_chance") and not game.spend_level_stat("critical_chance") and state.stat_points==points_before,"Capped and stale requests preserve unspent points")
 var victim=Ninja.new();victim.game=game;victim.training_dummy=true;victim.practice=true;game.add_child(victim);victim.set_physics_process(false);victim.hp=1000;victim.max_hp=1000
 p.attack_chain.reset();victim.take_hit(10,Vector3.FORWARD,false,p.attack_chain.make_ticket("critical-test"))
 check(is_equal_approx(victim.hp,980),"Allocated 100 percent chance deals actual double critical damage")
 victim.queue_free();game.close_status_panel();await frames()
 game.preview_forest_map(doc.data,false);await frames()
 state=game.model.team_progression
 check(state.stat_points==0 and p.level_health_bonus()==0 and p.hp==p.max_hp and is_equal_approx(p.max_hp,p.combat_tuning("max_hp")),"A real new map/run clears bonuses and restores full baseline HP")
 check(state.stat_ranks.critical_chance==0 and p.combat_tuning("critical_chance")==game.hero_tuning("critical_chance"),"New runs clear critical chance allocation")
 game.show_status_panel();await frames()
 var event=InputEventAction.new();event.action="pause";event.pressed=true;game._input(event);await frames()
 check(not is_instance_valid(game.status_panel) and game.paused and paused and not game.ordinary_pause,"Esc closes Stats in preparation while retaining preparation pause")
 timings.sort();print("STAT_PANEL_OPEN_US p95=",timings[floori((timings.size()-1)*.95)]," max=",timings.back())
 print("STAT_ALLOCATION_RESULT ",checks," checks, ",failures," failures")
 paused=false;game.queue_free();await frames(5)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

extends Node

var game: Node
var checks=0
var failures=0

func check(ok: bool, label: String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+label)
 else:print("PASS: ",label)

func frames(count: int):
 for i in range(count):await get_tree().physics_frame

func press(action: String, held: bool):
 var event=InputEventAction.new();event.action=action;event.pressed=held
 Input.parse_input_event(event);Input.flush_buffered_events()

func run():
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense")
 await frames(3)
 var run=game.encounters
 check(run.get("redesign_mode")==true,"Fire Siege selects the redesigned director")
 if run.get("redesign_mode")!=true:
  finish();return
 check(run.money==10 and run.phase=="setup" and not game.paused,"Fresh run opens with 10 gold and unlimited setup")
 check(run.cannons.is_empty() and game.world.cannon_sites.size()==12 and not run.mine_built,"Twelve sites and mine start empty")
 check(run.card_offer.is_empty() and run.upgrade_level("supply_cache")==0,"Retired card state cannot affect the new run")
 check(not run.try_purchase() and run.money==10,"Legacy F purchase cannot bypass construction")
 run.set_physics_process(false)
 var site=game.world.cannon_sites[0]
 game.reset_player_at(site.build_position);game.player.facing=(site.position-game.player.position).normalized()
 game.player.select_character(3)
 press("light_attack",true);press("siege_build",true)
 game.player._physics_process(.016)
 check(not game.player.active_ability.primary_held,"Building cancels a previously held primary attack")
 press("light_attack",false);press("siege_build",false);game.player.select_character(1)
 run.update_build_input(0,false);run.update_build_input(1.5,true)
 check(is_equal_approx(run.site_states[0].progress,.5) and run.money==10,"Partial construction costs nothing")
 run.update_build_input(1,false)
 check(is_equal_approx(run.site_states[0].progress,.25),"Released construction decays visibly")
 run.update_build_input(2.25,true)
 check(run.site_states[0].level==1 and run.money==5 and run.cannons.size()==1,"Reheld construction resumes and pays once")
 run.update_build_input(3,true)
 check(run.money==5 and run.cannons.size()==1,"Holding B after completion cannot buy again")
 var moving_site=game.world.cannon_sites[4]
 game.reset_player_at(moving_site.build_position);game.player.facing=(moving_site.position-game.player.position).normalized()
 run.update_build_input(0,false);run.update_build_input(1,true)
 game.player.position.x+=1;game.player.velocity=Vector3(3,0,0)
 run.update_build_input(1,true)
 check(run.site_states[4].progress<1.0/3.0 and not run.building,"Movement within the pad interrupts construction and decays progress")
 game.player.velocity=Vector3.ZERO
 run.update_build_input(3,true)
 check(run.site_states[4].level==0 and run.money==5,"Interrupted construction requires releasing B before resuming")
 run.update_build_input(0,false);run.update_build_input(3,true)
 check(run.site_states[4].level==1 and run.money==0,"Stationary release and rehold rearms construction")
 game.restart_area();await frames(3);run=game.encounters;run.set_physics_process(false)
 game.reset_player_at(game.world.mine_build_position);game.player.facing=(game.world.mine_position-game.player.position).normalized()
 run.update_build_input(0,false);run.update_build_input(4,true)
 check(run.mine_built and run.money==0,"Mine purchase completes after four seconds and charges ten")
 run.tick(20)
 check(run.money==0,"Built mine earns nothing in setup")
 game.restart_area();await frames(3);run=game.encounters
 check(InputMap.has_action("siege_build") and InputMap.has_action("siege_start"),"B and Y actions exist")
 run.set_physics_process(false)
 run.tick(90)
 check(run.phase=="setup" and run.wave==0 and run.money==10,"Waiting in setup neither launches nor earns")
 run.update_start_input(0,false)
 run.update_start_input(1.5,true)
 check(is_equal_approx(run.start_progress,.5),"Half of a Y hold shows half confirmation")
 run.update_start_input(.6,false)
 check(run.start_progress>0 and run.start_progress<.5,"Released Y decays and retains partial progress")
 run.update_start_input(3,true)
 check(run.phase=="spawning" and run.wave==1,"Three-second confirmation starts exactly one wave")
 run.tick(.2)
 check(run.total_spawned==1 and run.alive_count==1,"One scheduled actor spawns at 0.2 seconds")
 var enemy=game.enemies.filter(func(e):return is_instance_valid(e) and not e.dead)[0]
 check(enemy.hp==100 and enemy.defense_role.is_empty(),"Normal actors have 100 HP without role armor")
 var before_gold=run.money;var before_kills=game.kills;var before_xp=game.player.progression.total_kills
 game.player.hp=game.player.max_hp-20
 enemy.take_hit(10000,Vector3.FORWARD,true)
 check(run.money==before_gold and game.kills==before_kills+1,"Hero kill grants credit and zero gold")
 check(game.player.progression.total_kills==before_xp+1 and game.player.hp>game.player.max_hp-20,"Hero kill preserves progression and direct healing")
 game.drop_powerup(Vector3.ZERO)
 check(get_tree().get_nodes_in_group("energy_pickups").is_empty(),"Fire Siege has no collectible drops")
 game.player.invuln=0;game.tuning.invincible=false
 game.player.take_hit(100000,Vector3.FORWARD)
 check(game.player.hp==0 and run.hero_dead and game.playing and not game.paused,"Original hero death leaves the siege running")
 check(game.kennel.running() and game.barracks.running(),"Allies remain active during temporary hero death")
 var camera_yaw=game.camera_rig.yaw
 var orbit=InputEventMouseMotion.new();orbit.relative=Vector2(100,0)
 game.camera_rig._unhandled_input(orbit)
 check(game.camera_rig.yaw==camera_yaw,"Downed cursor can reach the revive button without orbiting")
 orbit.button_mask=MOUSE_BUTTON_MASK_RIGHT
 game.camera_rig._unhandled_input(orbit)
 check(game.camera_rig.yaw!=camera_yaw,"Right-drag orbits the camera while the hero is down")
 var at_death=run.total_spawned
 run.tick(1)
 check(run.total_spawned>at_death and run.revive_left>0,"Spawning and revival clock continue during death")
 var raider=game.enemies.filter(func(e):return is_instance_valid(e) and not e.dead)[0]
 raider.position=game.player.position+Vector3(0,0,-3);raider.state="chase";raider.stun=0
 game.tuning.freeze_ai=false;raider._physics_process(.05);game.tuning.freeze_ai=true
 check(raider.state=="march" and raider.velocity.length()>0,"Nearby enemies march past a dead hero instead of stalling")
 game.show_pause()
 var time_left=run.revive_left;run.tick(2)
 check(run.revive_left==time_left,"Pause freezes revival and combat clocks")
 game.resume()
 check(not game.paused,"Dead hero can resume a paused siege")
 check(run.revive_now() and game.player.hp==game.player.max_hp,"Beta Revive Now restores the hero")
 check(not run.revive_now(),"Duplicate revive is rejected")
 game.player.select_character(6)
 game.player.invuln=0;game.player.take_hit(100000,Vector3.FORWARD)
 check(run.hero_dead and not game.paused,"Native hero death uses temporary revival")
 run.tick(5)
 check(not run.hero_dead and game.player.hp>0,"Native hero automatically revives after five seconds")
 game.restart_area();await frames(3);run=game.encounters;run.set_physics_process(false)
 check(run.wave==0 and run.money==10 and not run.hero_dead and run.cannons.is_empty(),"Retry resets wave, wallet, purchases and death")
 run.wave=10;run.phase="clearance";run.pending=0;run.alive_count=0
 for actor in game.enemies:
  if is_instance_valid(actor):actor.queue_free()
 run.wave_actors.clear();game.enemies.clear();run.money=20
 game.player.hp=0;run.hero_died();run.tick(0)
 check(game.won and run.money==120,"Final reward is paid before victory even while hero is dead")
 check(game.menu!=null,"Victory presents a result screen")
 game.show_main_menu();await frames(2)
 finish()

func finish():
 print("FIRE_SIEGE_MVP_RESULT checks=",checks," failures=",failures)
 game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 # Match quit_clean: allow the audio mixer to release WAV playback at exit.
 var audio_deadline=Time.get_ticks_msec()+300
 while Time.get_ticks_msec()<audio_deadline:await get_tree().process_frame
 get_tree().quit(1 if failures else 0)

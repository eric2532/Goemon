extends RefCounted

var hero: Hero
var coins_enabled=false
var coin_clock=0.0
var coin_pending:Dictionary={}
const Original=preload("res://scripts/recovered_goemon_combat_profile.gd")
const COIN_INTERVAL=.42
const MIN_COIN_INTERVAL=.12
var active=false
var action=0
var return_slot=1
var pending: Array[int]=[]

func _init(player: Hero):hero=player

func toggle_coins():
	coins_enabled=not coins_enabled
	coin_clock=0
	if coins_enabled:tick_coins(0)
	else:stop_coins()
	hero.game.toast("AUTO COINS ON · %d per volley · 2 to stop" % hero.progression.coin_count() if coins_enabled else "AUTO COINS OFF")

func stop_coins():
	coins_enabled=false;coin_clock=0;coin_pending.clear()
	if is_instance_valid(hero.model) and hero.model.has_method("cancel_original_coin"):hero.model.call("cancel_original_coin")

func tick_coins(delta: float):
	if not coins_enabled or hero.character_id!=1:return
	coin_clock=maxf(0,coin_clock-delta)
	if hero.dodge_time>0 or hero.forward_dash.active or hero.sky_strike.active:
		coin_pending.clear()
		if hero.model.has_method("cancel_original_coin"):hero.model.call("cancel_original_coin")
		return
	if not coin_pending.is_empty():
		coin_pending.elapsed+=delta*float(coin_pending.rate)
		if float(coin_pending.elapsed)>=float(coin_pending.release):
			var cast=coin_pending;coin_pending={}
			hero.game.throw_coin(cast.powered,cast.powered,1.0,cast.ticket,true)
	if coin_clock>0 or not coin_pending.is_empty():return
	# Background coins own their cast without replacing a manual swing's ticket.
	var ticket=hero.attack_chain.make_ticket("coin")
	var powered=hero.surge_left>0
	var key="giant_toss" if powered else "coin"
	ticket["move_audio"]=hero.game.move_audio.begin(hero,"coin",key)
	ticket["original_goemon_coin_entry"]=true
	var native_action=Original.coin_action(hero.is_on_floor(),Vector2(hero.velocity.x,hero.velocity.z).length()>.25)+(3 if powered else 0)
	var rate=hero.attack_speed_multiplier()
	coin_pending={"ticket":ticket,"powered":powered,"elapsed":0.0,"release":Original.cue_time(native_action,Original.COIN_RELEASE_FRAME),"rate":rate}
	hero.play_sound("move_"+key+"_weapon",.4,ticket)
	if hero.model.has_method("begin_original_coin"):hero.model.call("begin_original_coin",native_action,rate)
	# No catch-up bursts after a long frame or unbounded casts at high tempo.
	coin_clock=maxf(MIN_COIN_INTERVAL,COIN_INTERVAL/rate)

func request(number: int):
	if hero.character_id!=1 or (hero.dodge_time>0 and not (hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode)):return
	if (hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode):
		hero.chain_pipe_combat.cancel();hero.attack_left=0
		if active:restore()
		pending.clear()
	# Busy presses are discarded. This list only dispatches an action immediately;
	# it never banks attacks to run after the current animation.
	if hero.attack_left>0 or hero.chain_pipe_combat.active:return
	pending.clear();pending.append(number)
	tick()
	if (hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode) and active:restore()

func request_mouse(heavy: bool):
	request(5 if heavy else 4)

func tick():
	if hero.weapon_controls.charging:return
	if hero.attack_left>0 or hero.chain_pipe_combat.active:return
	# Native pipe contacts/next-stage dispatch happen after the final model pose.
	if active and hero.uses_original_goemon_attack() and not hero.attack_heavy and hero.combo<3 and (not hero.game.rogue_battle_mode or action==1):return
	if active:restore()
	if pending.is_empty() or hero.character_id!=1:return
	action=pending.pop_front();return_slot=hero.weapon_slot;active=true
	hero.weapon_slot=action if action<=3 else return_slot;hero.set_weapon_visual(hero.weapon_slot)
	hero.heavy_buffer=0;hero.queued=false
	hero.facing=hero.combat_attack_direction()
	match action:
		1:
			hero.start_attack(false,1)
		2:hero.start_attack(false,1)
		3:hero.chain_pipe_combat.start("throw")
		_:
			if hero.weapon_slot==3:hero.chain_pipe_combat.start("sweep" if action==5 else "throw")
			elif action==4 and hero.weapon_slot==1:
				# One primary click always starts the authored three-hit pipe sequence.
				hero.start_attack(false,1)
			else:hero.start_attack(action==5 or hero.surge_left>0,1,action==4 and hero.surge_left>0)

func charged_coin(previous_slot:int,full:bool):
	return_slot=previous_slot;active=true;action=2
	hero.weapon_slot=2;hero.set_weapon_visual(2)
	hero.start_attack(full,1,full,1.0)

func restore():
	hero.weapon_slot=return_slot;hero.set_weapon_visual(return_slot)
	hero.wide_swing=false;active=false;action=0

func cancel():
	pending.clear()
	if active:restore()

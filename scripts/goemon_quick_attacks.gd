extends RefCounted

const MAX_PENDING=8
var hero: Hero
var coins_enabled=false
var coin_clock=0.0
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
	hero.game.toast("AUTO COINS ON · %d per volley · 2 to stop" % hero.progression.coin_count() if coins_enabled else "AUTO COINS OFF")

func stop_coins():
	coins_enabled=false;coin_clock=0

func tick_coins(delta: float):
	if not coins_enabled or hero.character_id!=1:return
	coin_clock=maxf(0,coin_clock-delta)
	if hero.dodge_time>0 or hero.forward_dash.active or hero.sky_strike.active:return
	if coin_clock>0:return
	# A background cast owns its ticket, so it cannot overwrite a manual swing
	# that is still winding up or turn its bonus into a different attack.
	var ticket=hero.attack_chain.make_ticket("coin")
	hero.game.throw_coin(hero.surge_left>0,hero.surge_left>0,1.0,ticket,true)
	# Never catch up with a burst after a long frame or emit unbounded casts at 100.
	coin_clock=maxf(MIN_COIN_INTERVAL,COIN_INTERVAL/hero.attack_speed_multiplier())

func request(number: int):
	if number==2 and hero.character_id==1:
		toggle_coins();return
	if hero.character_id!=1 or (hero.dodge_time>0 and not (hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode)):return
	if (hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode):
		hero.chain_pipe_combat.cancel();hero.attack_left=0
		if active:restore()
		pending.clear()
	if pending.size()<MAX_PENDING:pending.append(number)
	tick()
	if (hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode) and active:restore()

func request_mouse(heavy: bool):
	# Extra LMB taps inside the existing automatic triplet keep its choreography.
	if not (hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode) and not heavy and active and action==4 and pending.is_empty() and hero.weapon_slot==1 and not hero.attack_heavy and hero.combo<3:
		if 1.0-hero.attack_left/hero.attack_duration>=.1:hero.queued=true
		return
	request(5 if heavy else 4)

func tick():
	if hero.attack_left>0 or hero.chain_pipe_combat.active:return
	if active:restore()
	if pending.is_empty() or hero.character_id!=1:return
	action=pending.pop_front();return_slot=hero.weapon_slot;active=true
	hero.weapon_slot=action if action<=3 else return_slot;hero.set_weapon_visual(hero.weapon_slot)
	hero.heavy_buffer=0;hero.queued=false
	hero.facing=hero.game.attack_direction()
	match action:
		1:
			hero.start_attack(true,1,true,1.0,"spin")
		2:hero.start_attack(hero.surge_left>0,1,hero.surge_left>0)
		3:hero.chain_pipe_combat.start("sweep",11.0)
		_:
			if hero.weapon_slot==3:hero.chain_pipe_combat.start("sweep" if action==5 else "throw")
			elif (hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode) and action==4 and hero.weapon_slot==1 and hero.surge_left<=0:
				for stage in range(1,4):hero.start_attack(false,stage)
			else:hero.start_attack(action==5 or hero.surge_left>0,1,action==4 and hero.surge_left>0)

func restore():
	hero.weapon_slot=return_slot;hero.set_weapon_visual(return_slot)
	hero.wide_swing=false;active=false;action=0

func cancel():
	pending.clear()
	if active:restore()

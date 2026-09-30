extends RefCounted

const MAX_PENDING=8
var hero: Hero
var active=false
var action=0
var return_slot=1
var pending: Array[int]=[]

func _init(player: Hero):hero=player

func request(number: int):
	if hero.character_id!=1 or hero.dodge_time>0:return
	if pending.size()<MAX_PENDING:pending.append(number)
	tick()

func tick():
	if hero.attack_left>0 or hero.chain_pipe_combat.active:return
	if active:restore()
	if pending.is_empty() or hero.character_id!=1:return
	action=pending.pop_front();return_slot=hero.weapon_slot;active=true
	hero.weapon_slot=action;hero.set_weapon_visual(action)
	hero.heavy_buffer=0;hero.queued=false
	hero.facing=Vector3.FORWARD.rotated(Vector3.UP,hero.game.camera_rig.yaw)
	match action:
		1:
			hero.start_attack(true,2)
			hero.wide_swing=true
		2:hero.start_attack(hero.surge_left>0,1,hero.surge_left>0)
		3:hero.chain_pipe_combat.start("sweep",11.0)

func restore():
	hero.weapon_slot=return_slot;hero.set_weapon_visual(return_slot)
	hero.wide_swing=false;active=false;action=0

func cancel():
	pending.clear()
	if active:restore()

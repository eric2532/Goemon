extends RefCounted

# Deterministic clocks and transactions shared by the scene director and tests.
# All times are active gameplay time; the director stops calls while paused.
var generation=0
var start_progress=0.0
var start_armed=false
var start_permit=false
var wave_elapsed=0.0
var scheduled=0
var hero_dead=false
var revive_left=0.0
var terminal=false
var settled: Dictionary={}

func _init():reset()

func reset():
	generation+=1;start_progress=0;start_armed=false;start_permit=false
	wave_elapsed=0;scheduled=0;hero_dead=false;revive_left=0;terminal=false
	settled.clear()

func interrupt_inputs():
	start_progress=0;start_armed=false;start_permit=false

func update_start(delta: float,held: bool,eligible: bool)->bool:
	if terminal:return false
	if not held:
		start_armed=true
		start_progress=maxf(0,start_progress-maxf(0,delta)/3.0)
		return false
	if not eligible or not start_armed:return false
	start_progress=minf(1,start_progress+maxf(0,delta)/3.0)
	if start_progress<1.0-0.000000001:return false
	interrupt_inputs()
	start_permit=true
	return true

func start_wave():
	wave_elapsed=0;scheduled=0;interrupt_inputs()

func advance_wave(delta: float)->Dictionary:
	if terminal:return {"due":0,"spawning_seconds":0.0}
	var before=wave_elapsed
	wave_elapsed=minf(60,wave_elapsed+maxf(0,delta))
	var target=mini(300,int(floor((wave_elapsed+0.000000001)*5.0)))
	var due=maxi(0,target-scheduled)
	scheduled=target
	return {"due":due,"spawning_seconds":wave_elapsed-before}

func economy(balance: float,delta: float,income_seconds: float,towers: int,mine: bool)->Dictionary:
	var duration=maxf(0,delta)
	var available=maxf(0,balance)+(2.0*maxf(0,income_seconds) if mine else 0.0)
	var rate=maxi(0,towers)*.1
	var powered_delta=duration if rate<=0 else minf(duration,available/rate)
	var result=maxf(0,available-rate*powered_delta)
	if result<0.000000001:result=0
	return {"money":result,"powered_delta":powered_delta}

func build_step(progress: float,delta: float,held: bool,affordable: bool,duration: float)->Dictionary:
	if progress>=1:return {"progress":1.0,"completed":false}
	var amount=maxf(0,delta)
	var result=minf(1,progress+amount/duration) if held and affordable else maxf(0,progress-.25*amount)
	var completed=held and affordable and result>=1.0-0.000000001
	return {"progress":1.0 if completed else result,"completed":completed}

func settle(wave: int,base_hp: int,alive: int,pending: int,clearance: bool)->int:
	if terminal or base_hp<=0 or alive>0 or pending>0 or not clearance or wave<1 or wave>10 or settled.has(wave):return 0
	settled[wave]=true
	return wave*10

func hero_died()->bool:
	if terminal or hero_dead:return false
	hero_dead=true;revive_left=5;interrupt_inputs()
	return true

func advance_revive(delta: float)->bool:
	if terminal or not hero_dead:return false
	revive_left=maxf(0,revive_left-maxf(0,delta))
	return revive_now() if revive_left<=0.000000001 else false

func revive_now()->bool:
	if terminal or not hero_dead:return false
	hero_dead=false;revive_left=0
	return true

func terminate():
	terminal=true;revive_left=0;interrupt_inputs()

extends RefCounted
const Bank=preload("res://scripts/character_audio_bank.gd")
const Model=preload("res://scripts/warcraft_model.gd")
# Both fighters inherit Goemon's shared footstep instead of Warcraft step variants.
const FILES={
	31:{"wc_wind":"WindWalk","wc_mirror":"MirrorImage","wc_mirror_end":"MirrorImageDeath","wc_attack_1":"HeroBlademasterAttack1","wc_attack_2":"HeroBlademasterAttack2","wc_slam":"CriticalStrike","wc_spin":"BladeMasterWhirlwind","death":"HeroBladeMasterDeath","wc_ready":"HeroBlademasterReady1"},
	32:{"wc_immolation":"ImmolationTarget1","wc_immolation_end":"ImmolationDecay1","wc_attack_1":"HeroDemonHunterAttack1","wc_attack_2":"HeroDemonHunterAttack2","wc_morph":"DemonHunterMorph1","wc_missile":["HeroDemonMissileLaunch1","HeroDemonMissileLaunch2"],"wc_missile_hit":["DemonHunterMissileHit1","DemonHunterMissileHit2","DemonHunterMissileHit3"],"death":"HeroDemonHunterDeath1","wc_demon_death":"DemonHunterDeathAlternate1","wc_ready":"HeroDemonHunterReady1"}}
static func stream_for(id:int,slot:String)->AudioStream:
	if slot in ["hit","heavy_hit"]:return Bank.event(Model.ROOT+Model.key(id)+"/audio/",{"impact":["MetalHeavySliceFlesh1","MetalHeavySliceFlesh2","MetalHeavySliceFlesh3"]},"impact")
	if id==32 and slot in ["coin_hit","coin_heavy_hit"]:slot="wc_missile_hit"
	return Bank.event(Model.ROOT+Model.key(id)+"/audio/",FILES[id],slot)
static func slot_labels(id:int)->Dictionary:
	var result={}
	for slot in FILES[id]:result[slot]=slot.trim_prefix("wc_").replace("_"," ").capitalize()
	return result

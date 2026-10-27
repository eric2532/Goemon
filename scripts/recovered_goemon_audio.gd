extends RefCounted
## ROM event audio, rendered with the original sequencer's pitch and envelopes.
## These are dry renders; provenance describes the remaining DSP differences.
## Gold Pipe actions 68/69/6A use the same verified events as basic 58/59/5A.
const ROOT="res://assets/audio/recovered_goemon/"
const FILES={
	"jump":["jump_a","jump_b","jump_b"],
	"swing":["pipe_1"], "heavy_swing":["pipe_3"],
	"hit":["contact_hit"], "heavy_hit":["contact_hit"],
	"coin_hit":["contact_hit"], "coin_heavy_hit":["contact_hit"], "chain_hit":["contact_hit"],
	"throw":["coin_ready"], "chain_throw":["chain_release"],
	"goemon_transform":["golden_complete"],
	"move_primary_1_weapon":["pipe_1"],
	"move_primary_1_voice":["chain_voice_a","chain_voice_b","chain_voice_c"],
	"move_primary_2_weapon":["pipe_2"],
	"move_primary_3_weapon":["pipe_3"],
	"move_primary_3_voice":["coin_voice_a","coin_voice_b","coin_voice_c"],
	"move_heavy_voice":["coin_voice_a","coin_voice_b","coin_voice_c"],
	"move_heavy_weapon":["pipe_3"],
	"move_giant_toss_weapon":["coin_ready"],
	"goemon_coin_charge":["coin_charge"],
	"goemon_coin_charge_a":["coin_charge_a"], "goemon_coin_charge_b":["coin_charge_b"],
	"goemon_coin_charged_burst":["charged_coin_burst"],
	"move_coin_charged_weapon":["triple_coin"],
	"move_coin_charged_voice":["coin_voice_a","coin_voice_b","coin_voice_c"],
	"move_coin_weapon":["coin_ready"], "move_coin_heavy_weapon":["coin_ready"],
	"move_coin_voice":["coin_voice_a","coin_voice_b","coin_voice_c"],
	"move_coin_heavy_voice":["coin_voice_a","coin_voice_b","coin_voice_c"],
	"move_chain_throw_weapon":["chain_release"],
	"move_chain_throw_voice":["chain_voice_a","chain_voice_b","chain_voice_c"],
	"move_chain_sweep_weapon":["chain_release"], "move_chain_fire_weapon":["chain_release"],
	"move_chain_sweep_voice":["chain_voice_a","chain_voice_b","chain_voice_c"],
	"move_chain_fire_voice":["chain_voice_a","chain_voice_b","chain_voice_c"],
	"move_surge_weapon":["golden_weapon"], "move_surge_voice":["golden_voice"]
}
static func stream_for(slot:String)->AudioStream:
	return preload("res://scripts/character_audio_bank.gd").event(ROOT,FILES,slot)

static func charged_coin_contact(coin: Node):
	if not coin.get_meta("original_goemon_coin",false) or not coin.get_meta("original_goemon_charged_coin",false):return
	if coin.get_meta("original_goemon_charged_burst_played",false):return
	coin.set_meta("original_goemon_charged_burst_played",true)
	var game=coin.get("game")
	if is_instance_valid(game):game.sound("goemon_coin_charged_burst",.7,false,{},1)

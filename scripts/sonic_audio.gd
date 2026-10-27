extends RefCounted
## Retail GCAX samples at their source note pitch; no replacement sound synthesis.
const ROOT="res://assets/audio/recovered_sonic/"
const FILES={
	"jump":["jump"],"hurt":["damage_effect"],"land":["land"],"step":["step"],
	"hit":["hit"],"heavy_hit":["hit"],"sonic_brake":["brake"],
	"sonic_homing":["homing"],"sonic_charge":["charge"],"sonic_dash":["dash"],
	"sonic_wall_hit":["wall_voice"],
	"move_homing_weapon":["homing"],"move_homing_voice":[],
	"move_spin_dash_weapon":["dash"],"move_spin_dash_voice":[],
	"move_jump_weapon":["jump"],"move_jump_voice":["jump_voice_1","jump_voice_2"],
	"dash":[],"environment_hit":[]
}
static func stream_for(slot:String)->AudioStream:
	var bank=preload("res://scripts/character_audio_bank.gd")
	if slot=="hurt":
		var key=ROOT+"hurt_pair"
		if not bank.streams.has(key):
			# One synchronized event keeps both layers under the existing hurt mute/gain/recording.
			var pair=AudioStreamSynchronized.new();pair.stream_count=2
			pair.set_sync_stream(0,bank.event(ROOT,FILES,"hurt"))
			pair.set_sync_stream(1,bank.sample(ROOT+"damage_voice.wav"))
			bank.streams[key]=pair
		return bank.streams[key]
	return bank.event(ROOT,FILES,slot)
static func slot_labels()->Dictionary:
	var labels={}
	for slot in FILES:labels[slot]="Sonic · "+slot.trim_prefix("sonic_").trim_prefix("move_").replace("_"," ").capitalize()
	return labels

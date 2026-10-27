extends RefCounted
## Disc-derived dry samples at retail playback rates. Voice trigger reuse and
## original target/material distinctions are documented with the assets.
const ROOT="res://assets/audio/recovered_musashi/"
const FILES={
	"musashi_dkick_hit":"dkick_impact",
	"musashi_fence":"fence_launch", "musashi_fence_hit":"fence_impact",
	"musashi_homing":"homing_launch", "musashi_homing_hit":"homing_impact",
	"musashi_grenade":"grenade_throw", "musashi_grenade_hit":"grenade_explode",
	"musashi_three_way":"three_way_fire",
	"swing":"fusion_swing", "heavy_swing":"lumina_swing",
	"hit":"sword_hit", "heavy_hit":"sword_hit", "fusion_finisher_hit":"fusion_finisher_hit",
	"environment_hit":"sword_environment_hit", "hurt":"voice_hurt", "jump":"", "land":"foot_contact",
	"musashi_step_0":"foot_contact", "musashi_step_1":"foot_contact", "ground_stop":"land",
	"musashi_rotation":"lumina_rotation", "musashi_spin":"lumina_spin", "musashi_guard_spark":"guard_spark",
	"fusion_air_swing":"fusion_air_swing", "fusion_fourth_hit":"lumina_rotation",
	"move_primary_1_weapon":"fusion_swing", "move_primary_2_weapon":"fusion_swing_2", "move_primary_3_weapon":"fusion_swing",
	"move_heavy_weapon":"lumina_swing",
	"move_primary_1_voice":"", "move_primary_2_voice":"", "move_primary_3_voice":"",
	"move_primary_4_weapon":"fusion_air_swing", "move_primary_4_voice":"voice_exertion",
	"move_heavy_voice":"", "move_rotation_weapon":"lumina_spin", "move_rotation_voice":""
}
static func stream_for(slot:String)->AudioStream:
	return preload("res://scripts/character_audio_bank.gd").event(ROOT,FILES,slot)

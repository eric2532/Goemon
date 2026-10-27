extends RefCounted
const ROOT="res://assets/characters/recovered_kojiro/audio/"
const SWORD_CUT=preload("res://assets/audio/recovered_musashi/fusion_swing.wav")
const FILES={"kojiro_homing_voice":"homing_voice","kojiro_homing_release":"homing_release",
	"kojiro_wave_voice":"wave_voice","kojiro_wave_release":"wave_release",
	"kojiro_wind_voice":"wind_voice","kojiro_wind_release":"wind_release",
	"kojiro_air_cut_voice":"air_cut_voice","kojiro_air_spin_voice":"air_spin_voice",
	"hurt":["hurt_1","hurt_2"],"death":"defeat",
	"kojiro_unused_a83":"unused_voice_a83","kojiro_unused_a84":"unused_voice_a84",
	"swing":"","heavy_swing":"","jump":"","land":"","step":"","dash":"","enemy_reaction":"","coin_hit":"","coin_heavy_hit":""}
static func stream_for(slot:String)->AudioStream:
	# The USA duel disables its sword event; reuse the shared prepared cut.
	if slot=="kojiro_sword_cut":return SWORD_CUT
	return preload("res://scripts/character_audio_bank.gd").event(ROOT,FILES,slot)
static func prepare():
	for slot in FILES:stream_for(slot)
static func slot_labels()->Dictionary:
	var result={}
	for slot in FILES:
		if slot.begins_with("kojiro_"):result[slot]=slot.trim_prefix("kojiro_").replace("_"," ").capitalize()
	result.death="Defeat voice"
	result.kojiro_sword_cut="Sword cut · shared Musashi effect"
	return result

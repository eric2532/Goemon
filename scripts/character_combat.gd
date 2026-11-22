extends Node
## Shared ownership, selection and focus lifecycle for every character kit.
var spell_owner:Node
var hero:Hero
var game:Node
var active=false:
	set(value):
		var was_active=active
		active=value
		if was_active and not value and is_inside_tree():cancel()
		elif value and not was_active and is_inside_tree():
			if is_instance_valid(game) and game.get("sound_library") is SoundLibrary:game.sound_library.prepare_character(source_id())
			prepare_projectiles()

func _notification(what:int):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and active and is_instance_valid(hero):cancel(true)

func cast_model():
	return spell_owner.source_model if spell_owner!=null else hero.model

func source_id()->int:
	return spell_owner.source_id if spell_owner!=null else hero.character_id

func cancel(_preserve_power:bool=false):pass
func prepare_projectiles():pass
func clear_cooldowns():pass

func skill_factor(key:String,ticket:Dictionary={})->float:
	return preload("res://scripts/spells/skill_balance.gd").factor(ticket if not ticket.is_empty() else hero.attack_ticket,key)

func skill_count(original:int,ticket:Dictionary)->int:
	return preload("res://scripts/spells/skill_balance.gd").count(ticket,original)

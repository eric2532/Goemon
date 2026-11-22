extends "res://scripts/level_progression.gd"

var xp_remainder=0

func reset(_direct_levels:bool=false):
	super.reset(false)
	xp_remainder=0

static func xp_required(level:int)->int:return 0 if level>=MAX_LEVEL else 16*level
func kills_required()->int:return xp_required(level)

func award_kills(amount:int=1)->int:
	var gained=super.award_kills(amount)
	if level>=MAX_LEVEL:xp_remainder=0
	return gained

func award_enemy(reward_tenths:int=10)->int:
	if reward_tenths<=0 or level>=MAX_LEVEL:return 0
	var total=xp_remainder+reward_tenths
	xp_remainder=total%10
	return award_kills(total/10)

func experience()->float:return kills_into_level+xp_remainder/10.0
func progress()->float:return 1.0 if level>=MAX_LEVEL else experience()/kills_required()

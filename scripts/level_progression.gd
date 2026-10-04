extends RefCounted

const MAX_LEVEL=99
const MAX_ATTACK_BONUS=0.75
const MAX_MOVEMENT_BONUS=0.40
const MAX_JUMP_HEIGHT_BONUS=0.60
const MAX_HEALTH_BONUS=3.0
var level=1
var kills_into_level=0
var total_kills=0
var per_enemy_level=false

func reset(direct_levels: bool=false):
	per_enemy_level=direct_levels
	level=1;kills_into_level=0;total_kills=0

func kills_required()->int:
	return 0 if level>=MAX_LEVEL else (1 if per_enemy_level else 5+floori(float(level-1)/5.0))

func award_kills(amount: int=1)->int:
	if amount<=0:return 0
	total_kills+=amount
	if level>=MAX_LEVEL:return 0
	var before=level
	kills_into_level+=amount
	while level<MAX_LEVEL and kills_into_level>=kills_required():
		kills_into_level-=kills_required()
		level+=1
	if level==MAX_LEVEL:kills_into_level=0
	return level-before

func progress()->float:
	return 1.0 if level>=MAX_LEVEL else float(kills_into_level)/kills_required()

func growth()->float:
	return float(level-1)/float(MAX_LEVEL-1)

func coin_count()->int:return clampi(level,1,MAX_LEVEL)

func health_multiplier()->float:return 1.0+MAX_HEALTH_BONUS*growth()

func attack_multiplier()->float:return 1.0+MAX_ATTACK_BONUS*growth()
func movement_multiplier()->float:return 1.0+MAX_MOVEMENT_BONUS*growth()
func jump_height_multiplier()->float:return 1.0+MAX_JUMP_HEIGHT_BONUS*growth()

func jump_velocity_multiplier()->float:
	# Height is proportional to launch velocity squared at constant gravity.
	return sqrt(jump_height_multiplier())

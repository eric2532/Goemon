extends RefCounted

const DEFAULT=102488
const MAZE=100528
const CATALOG={
	DEFAULT:["Original",preload("res://assets/characters/crossgate/kazi/portrait-front.png"),Vector2(-44,-76)],
	109890:["Blond / Rose",preload("res://assets/characters/crossgate/kazi/skins/109890/portrait.png"),Vector2(-21,-76)],
	109891:["Blond / Rose Aura",preload("res://assets/characters/crossgate/kazi/skins/109891/portrait.png"),Vector2(-53,-84)],
	109146:["Yellow / Red Sparks",preload("res://assets/characters/crossgate/kazi/skins/109146/portrait.png"),Vector2(-22,-74)],
	MAZE:["Maze",preload("res://assets/characters/crossgate/maze/portrait.png"),Vector2(-21,-76)],
	100028:["Classic · Brown / Teal",preload("res://assets/characters/crossgate/kazi/skins/100028/portrait.png"),Vector2(-21,-76)],
	100034:["Classic · Teal / Yellow and Red",preload("res://assets/characters/crossgate/kazi/skins/100034/portrait.png"),Vector2(-21,-76)],
	100040:["Classic · Red / Navy",preload("res://assets/characters/crossgate/kazi/skins/100040/portrait.png"),Vector2(-21,-76)],
	100046:["Classic · Black / White and Red",preload("res://assets/characters/crossgate/kazi/skins/100046/portrait.png"),Vector2(-21,-76)],
	100049:["Classic · Red / Silver",preload("res://assets/characters/crossgate/kazi/skins/100049/portrait.png"),Vector2(-21,-76)],
	100891:["Black Hair / Black",preload("res://assets/characters/crossgate/kazi/skins/100891/portrait.png"),Vector2(-21,-76)],
	100918:["Blond / Black",preload("res://assets/characters/crossgate/kazi/skins/100918/portrait.png"),Vector2(-21,-76)],
	100969:["Black Hair / Red",preload("res://assets/characters/crossgate/kazi/skins/100969/portrait.png"),Vector2(-21,-76)],
	105564:["Black Hair / White",preload("res://assets/characters/crossgate/kazi/skins/105564/portrait.png"),Vector2(-21,-76)],
	105570:["Black Hair / Blue and White",preload("res://assets/characters/crossgate/kazi/skins/105570/portrait.png"),Vector2(-21,-76)],
	105608:["Red Hair / Black",preload("res://assets/characters/crossgate/kazi/skins/105608/portrait.png"),Vector2(-21,-76)],
}

static func valid_id(value:Variant)->int:
	return int(value) if value is int and CATALOG.has(value) else DEFAULT

static func model_skin(value:int)->int:
	# Maze keeps its prepared model, weapons and saved identity behind Kaz's skin choice.
	return DEFAULT if value==MAZE else value

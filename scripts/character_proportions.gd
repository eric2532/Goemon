extends RefCounted
## Standing mesh heights in metres, including normal hair and excluding weapons.
## Goemon is the unchanged reference; source body heights are Ben1.8 / Edo3.3.
const GOEMON_HEIGHT=3.2206185
const ED_HEIGHT=GOEMON_HEIGHT
const BEN_HEIGHT=GOEMON_HEIGHT*2.0
const EDO_HEIGHT=GOEMON_HEIGHT*.8
const BEN_MODEL_SCALE=BEN_HEIGHT/1.8
const EDO_MODEL_SCALE=EDO_HEIGHT/3.3

const KAZ_BODY_PIXELS=83.0
const CROSSGATE_FEET_PIXELS=7.0
const CROSSGATE_ROSTER=preload("res://scripts/rogue_roster.gd")
# Archived front-pose body heights exclude weapons, shadows and auras.
const SHIN_BODY_PIXELS={
	100450:86,100978:86,105610:86,105616:86,105622:86,105628:86,105634:86,
	106707:85,109140:85,111624:85,111625:85,118986:85,118987:86,118993:86,108313:86,120440:86,
}

static func crossgate_body_pixels(character:int,skin:int=0)->float:
	var entry:Array=CROSSGATE_ROSTER.skin_catalog(character).get(skin,[])
	if CROSSGATE_ROSTER.is_shin(character):
		return float(entry[2]) if entry.size()>2 else SHIN_BODY_PIXELS.get(skin,87)
	if character==CROSSGATE_ROSTER.RUBY_ID or (character==CROSSGATE_ROSTER.KAZI_ID and skin==109146):return 81.0
	if entry.size()>2 and (entry[2] is int or entry[2] is float):return float(entry[2])
	return float(CROSSGATE_ROSTER.crossgate_profile(character).get("body_pixels",KAZ_BODY_PIXELS))

# Host presentation request; source pose timings and fixed-point values stay original.
const MUSASHI_SIZE=2.04
const KOJIRO_SIZE=.9

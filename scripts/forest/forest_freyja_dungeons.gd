extends RefCounted
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
## Keep archived multi-floor routes; adapted chambers retain their existing entrances.
const Sites=preload("res://assets/maps/falan/freyja_destinations_data.gd")
const GRAVE=47017
const UNDERSEA_FLOORS=[15003,15004,15005,15592,15593,15594,16516,16517,16518,16519]
const HABARU_FLOORS=[11003,11004,11005,11028]
const VENOA_FLOORS=[11000,11001,11002,11022]
const ENTRANCES={
 15592:[15593,Vector2(135,12)],15594:[15593,Vector2(-129,-36)],
 410:[15505,Vector2(45,-57)],
 16501:[16503,Vector2(27,48)],16502:[16503,Vector2(-12,51)],
 47010:[47017,Vector2(-54,111)],
}
const EXITS={
 15593:[[15592,Vector2(135,12)],[15594,Vector2(-129,-36)]],
 15505:[[410,Vector2(45,-57)],[15505,Vector2(-12,6)]],
 16503:[[16501,Vector2(27,48)]],
 47017:[[47010,Vector2(-54,111)],[47017,Vector2(15,-12)]],
}
const TITLES={
 11004:"Habaru Cave · 熊弟",15003:"Sokia Undersea Cave",
 15593:"Venoa Undersea Cave",15505:"Zombie Cave · Arubas's Laboratory",
 16503:"Alyut West Cave · Wolf Captain's Hall",47017:"Imur Forest · Graveyard",
}
const NPCS={
 15505:{410:[Vector2(51,-60)]},
 16503:{16501:[Vector2(21,51)]},
 47017:{47010:[Vector2(-57,111)]},
}
const ZOMBIE_PATROLS=[
 [Vector2(33,-57),1],[Vector2(51,-48),2],[Vector2(-57,-48),1],
 [Vector2(-39,-57),2],[Vector2(-30,-48),1],[Vector2(-12,-39),2],
 [Vector2(33,-30),3],[Vector2(42,-12),3],[Vector2(-57,-21),3],
]
const EXTRA_ROOFS=[11013,11020,11021,11023,11024,11029,11033,15542,15595,21051]

static func roofed(id:int)->bool:
 var recovery=load("res://scripts/forest/forest_original_maps.gd")
 if recovery.owns(id):return recovery.cave(id)
 return id==16509 or Prayer.owns(id) or Sites.ENCLOSED_CAVES.has(id) or id in EXTRA_ROOFS

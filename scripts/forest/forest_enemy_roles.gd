extends RefCounted
## Simulation roles use the exported world dimensions, independent of wave number.
const PATHS=["res://assets/characters/thirstquencher/soldier_1.glb","res://assets/characters/thirstquencher/soldier_2.glb","","res://assets/characters/thirstquencher/soldier_3.glb"]
const BOSS=4
const COUNT=5
const VAMBEE=6
const HAYA_WOLF=9
const VAMBEE_TORSO=14
const VAMBEE_LEGS=15
const SLOW_GUY=16
const DARK_LUMINA_2=17
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const DARK_LUMINA_3=18
const DARK_LUMINA_3_SCALE=3.0
const GATEKEEPER_HOUND=19
const CAVE_BEAR=21
const SLIME=20
const SLIME_COLORS=29
const MAP_ENEMY_SCALE=1.15*1.20
const SLIME_SCALE=3.0
const SLIME_HEIGHT=1.8*SLIME_SCALE
const SLIME_RADIUS=1.3*SLIME_SCALE
const HOUND_PIXEL_SIZE=.0375
# The blue hound's front-diagonal standing sprite is 78 pixels from the ground to the top.
const HOUND_SCALE=1.4*preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT/(78.0*HOUND_PIXEL_SIZE)
const HOUND_COLORS=21
const WAVE_TYPES=[0,1,3,VAMBEE,HAYA_WOLF,SLOW_GUY]
const RIGID_TYPES=[0,1,3,VAMBEE,HAYA_WOLF,VAMBEE_TORSO,SLOW_GUY,DARK_LUMINA_2,DARK_LUMINA_3]
const NATIVE_TYPES=[0,1,3,VAMBEE,HAYA_WOLF,VAMBEE_TORSO,SLOW_GUY,DARK_LUMINA_2,DARK_LUMINA_3,GATEKEEPER_HOUND,CAVE_BEAR]
const WAVE_FAMILIES={0:[0,VAMBEE,SLOW_GUY],1:[1],3:[3,HAYA_WOLF]}
# The historical haya_wolf master is Slow Guy; karate_wolf is the verified wolf.
const RECOVERED={VAMBEE:"vambee",HAYA_WOLF:"karate_wolf",VAMBEE_TORSO:"vambee_torso",VAMBEE_LEGS:"vambee_legs",SLOW_GUY:"haya_wolf",DARK_LUMINA_2:"dark_lumina_2",DARK_LUMINA_3:"dark_lumina_3"}
const ATTACKS={
 DARK_LUMINA_3:{"clip":"attack","contact":28,"radius":.7,"from":Vector3(0,-64,-24),"to":Vector3(0,-80,-224),"travel":0.0,"next_form":-1},
 DARK_LUMINA_2:{"clip":"attack","contact":13,"radius":.8,"from":Vector3(0,-96,-48),"to":Vector3(0,-160,-272),"travel":0.0,"next_form":-1},
 VAMBEE:{"clip":"grab","contact":13,"from":Vector3(0,-32,-16),"to":Vector3(0,-64,-80),"travel":0.0,"next_form":VAMBEE_TORSO},
 HAYA_WOLF:{"clip":"attack","contact":15,"from":Vector3(0,-48,0),"to":Vector3(0,-80,-80),"travel":1.8,"next_form":-1},
 SLOW_GUY:{"clip":"attack","contact":15,"contact_end":21,"from":Vector3(0,-16,-72),"to":Vector3(0,-96,-104),"travel":0.0,"next_form":-1},
 VAMBEE_TORSO:{"clip":"attack","contact":13,"from":Vector3(0,-32,-16),"to":Vector3(0,-64,-80),"travel":0.0,"next_form":-1}}
const MONSTERS={
 CAVE_BEAR:{"hp":30000.0,"speed":12.0,"damage":3000.0,"windup":.34,"recovery":.66,"range":3.2,"turn_speed":8.0,"stride":2.7},
 SLIME:{"hp":700.0,"speed":3.0,"damage":20.0,"windup":.30,"recovery":.50,"range":2.5*SLIME_SCALE,"turn_speed":6.0,"stride":2.0*SLIME_SCALE},
 GATEKEEPER_HOUND:{"hp":3000.0,"speed":4.5,"damage":60.0,"windup":.34,"recovery":.66,"range":3.2*HOUND_SCALE,"turn_speed":8.0,"stride":2.7},
 DARK_LUMINA_3:{"hp":18000.0,"speed":8.64,"damage":65.0,"windup":28.0/30,"recovery":1.0,"range":24.0*DARK_LUMINA_3_SCALE,"turn_speed":5.0,"stride":2.88},
 DARK_LUMINA_2:{"hp":Dark.HEALTH,"speed":3.6*Dark.MOVE_SPEED,"damage":400.0,"windup":13.0/30/Dark.CLAW_TEMPO,"recovery":32.0/30/Dark.CLAW_TEMPO,"range":7.0*Dark.SCALE*Dark.ATTACK_RANGE,"turn_speed":2.8,"stride":5.76*Dark.SCALE},
 VAMBEE:{"hp":160.0,"speed":1.08,"damage":18.0,"windup":13.0/30,"recovery":32.0/30,"range":2.3,"turn_speed":3.0,"stride":1.44},
 HAYA_WOLF:{"hp":640.0,"speed":4.32,"damage":24.0,"windup":15.0/30,"recovery":25.0/30,"range":3.0,"turn_speed":5.0,"stride":2.304},
 SLOW_GUY:{"hp":640.0,"speed":4.32,"damage":18.0,"windup":15.0/30,"recovery":25.0/30,"range":3.0,"turn_speed":5.0,"stride":2.304},
 VAMBEE_TORSO:{"hp":160.0,"speed":.54,"damage":18.0,"windup":13.0/30,"recovery":19.0/30,"range":2.3,"turn_speed":3.0,"stride":1.44}}
const BOSS_MOVE_SPEED=5.0
const BOSS_SCALE=5.0
const BOSS_SIZE=Vector3(6,5,8)*BOSS_SCALE
const HEIGHTS=[2.016,2.016,23.10,2.016,25.0]
const RADII=[1.3,1.3,8.5,1.3,18.0]
const DATA=[
 {"hp":64.0,"speed":4.32,"damage":11.0,"windup":13.0/30,"recovery":7.0/30,"range":2.5,"turn_speed":5.0,"stride":2.304},
 {"hp":80.0,"speed":2.16,"damage":25.0,"windup":18.0/30,"recovery":12.0/30,"range":24.0,"turn_speed":4.0,"stride":1.44},
 {"hp":3000.0,"speed":.75,"damage":120.0,"windup":1.5,"recovery":3.5,"range":10.0,"turn_speed":.45,"stride":3.0},
 {"hp":72.0,"speed":4.32,"damage":11.0,"windup":13.0/30,"recovery":7.0/30,"range":2.5,"turn_speed":7.0,"stride":2.304},
 {"hp":30000.0,"speed":1.5*BOSS_MOVE_SPEED,"damage":90.0,"windup":1.2,"recovery":2.0,"range":7.0,"turn_speed":1.5,"stride":2.0}]
static func stats(variant: int)->Dictionary:return MONSTERS[variant].duplicate() if MONSTERS.has(variant) else DATA[clampi(variant,0,COUNT-1)].duplicate()
static func level_xp_tenths(level:int)->int:return 10*level
static func asset_path(variant: int)->String:
 if variant in [GATEKEEPER_HOUND,SLIME,CAVE_BEAR]:return ""
 if RECOVERED.has(variant):
  var authored="res://assets/models/enemies/recovered_monsters/"+RECOVERED[variant]+".glb"
  return authored if FileAccess.file_exists(authored) else "res://assets/characters/recovered_monsters/"+RECOVERED[variant]+".glb"
 return "" if variant in [2,BOSS] else GameAssets.model_path(PATHS[clampi(variant,0,3)])
static func size_multiplier(variant:int,shared:float)->float:
 if variant==SLIME:return MAP_ENEMY_SCALE
 return shared if variant in RIGID_TYPES else 1.0
static func height(variant: int,size:float=1.0)->float:
 if variant==BOSS:return BOSS_SIZE.y*MAP_ENEMY_SCALE
 if variant==CAVE_BEAR:return 3.35
 if variant==GATEKEEPER_HOUND:return 2.7*HOUND_SCALE
 if variant==SLIME:return SLIME_HEIGHT*MAP_ENEMY_SCALE
 return (2.5*DARK_LUMINA_3_SCALE if variant==DARK_LUMINA_3 else 5.184*Dark.SCALE if variant==DARK_LUMINA_2 else 2.88 if variant==HAYA_WOLF else 2.304)*size if RECOVERED.has(variant) else HEIGHTS[clampi(variant,0,COUNT-1)]*(size if variant in RIGID_TYPES else 1.0)
static func footprint_radius(variant: int,size:float=1.0)->float:
 if variant==BOSS:return RADII[BOSS]*MAP_ENEMY_SCALE
 if variant==CAVE_BEAR:return 1.1
 if variant==GATEKEEPER_HOUND:return 1.35*HOUND_SCALE
 if variant==SLIME:return SLIME_RADIUS
 return (1.3*DARK_LUMINA_3_SCALE if variant==DARK_LUMINA_3 else 4.032*Dark.SCALE if variant==DARK_LUMINA_2 else 1.5 if variant in [HAYA_WOLF,SLOW_GUY] else 1.3)*size if RECOVERED.has(variant) else RADII[clampi(variant,0,COUNT-1)]*(size if variant in RIGID_TYPES else 1.0)
static func wave_variant(slot:int,sequence:int)->int:
 var family:Array=WAVE_FAMILIES[slot]
 return family[posmod(sequence/3,family.size())]
static func hurt_point(enemy: Dictionary,from: Vector3)->Vector3:
 return load("res://scripts/forest/forest_enemy_contact.gd").contact(enemy,from)

static func visibility_radius(variant: int,size:float=1.0)->float:return 14.0 if variant==2 else footprint_radius(variant,size)

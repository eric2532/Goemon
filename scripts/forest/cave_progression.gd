extends RefCounted
## Encounter levels/provenance: docs/cave-monster-progression.md.
## Rows: display name, level, HP per level, boss.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const HABARU=[
 ["熊弟 · 殺熊者歐茲那克",25,1200,true],
 ["穴熊",20,500,false],
 ["史萊姆",12,300,false],
 ["巨穴熊",25,1200,true],
 ["穴熊",20,500,false],
]
const UNDERSEA=[
 ["熊哥 · 熱砂的歐茲尼克",40,1200,true],
 ["水龍蜥",20,450,false],
 ["蜥蜴戰士",20,400,false],
]
const ZOMBIE=[
 ["改造殭屍",35,1200,true],
 ["殭屍",24,450,false],
 ["腐屍",23,400,false],
 ["地獄看門犬",20,350,false],
]
const CAPTAIN=[
 ["海賊船長",20,1200,true],
 ["海蝙蝠",15,300,false],
 ["海盜",15,400,false],
]
const GRAVE=[
 ["帕魯凱斯的亡靈",80,1200,true],
 ["士兵的亡靈",70,500,false],
 ["帕魯凱斯",90,1200,true],
 ["反抗軍的亡靈",60,300,false],
]
const RUBY=[
 ["露比",50,1200,true],
 ["血腥之刃",30,400,false],
 ["鬼靈",30,300,false],
]

static func apply(enemy:Dictionary,profile:Array,base:Dictionary,level:int=0):
 enemy.enemy_name=profile[0]
 enemy.level=profile[1] if level==0 else level
 enemy.hp=float(profile[2]*enemy.level);enemy.max_hp=enemy.hp
 enemy.health_scale=enemy.hp/base.hp
 var damage:float=8.0*enemy.level if profile[3] else 30.0+3.0*(enemy.level-1)
 enemy.damage_scale=damage/base.damage
 enemy.xp_reward_tenths=Roles.level_xp_tenths(enemy.level)*(5 if profile[3] else 1)

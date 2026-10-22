extends RefCounted
## Shared presentation and combat definitions for Chief's loadout.
const ROOT="res://assets/characters/master_chief/"
const SLOTS={
	1:{"key":"rocket_launcher","label":"ROCKET LAUNCHER","interval":.95,"range":160.0,"damage":720.0,"recoil":.018,"kick":.075},
	2:{"key":"pistol","label":"PISTOL","interval":1.0/3.5,"range":140.0,"damage":168.0,"recoil":.006,"kick":.038},
	3:{"key":"shotgun","label":"SHOTGUN","interval":1.0,"range":32.0,"damage":54.0,"recoil":.014,"kick":.065},
	4:{"key":"assault_rifle","label":"ASSAULT RIFLE","interval":1.0/15.0,"range":160.0,"damage":84.0,"recoil":.0035,"kick":.032},
	5:{"key":"energy_sword","label":"ENERGY SWORD","interval":.7,"range":3.6,"damage":151.0,"recoil":.002,"kick":.012,"melee":true},
}
static func data(slot:int)->Dictionary:return SLOTS.get(slot,SLOTS[1])
static func model_path(slot:int)->String:return ROOT+data(slot).key+"_fp.glb"
static func sound_path(slot:int)->String:return ROOT+data(slot).key+("_swing.wav" if data(slot).get("melee",false) else "_shot.wav")
static func icon_path(slot:int)->String:return ROOT+data(slot).key+"_icon.svg"

static func audio_key(slot:int)->String:return "rifle" if slot==4 else data(slot).key

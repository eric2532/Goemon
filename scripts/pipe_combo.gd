class_name PipeCombo
extends RefCounted
# Shared choreography and timing. No mesh/rest-rig edits: runtime pose layer only.
const DURATIONS=[0.28,0.34,0.56]
const CONTACT=[0.34,0.38,0.48]
const ACTIVE=[0.16,0.17,0.15]
const Strike=preload("res://scripts/goemon_reference_strike.gd")
const IDLE={"hip":Vector3.ZERO,"chest":Vector3.ZERO,"offset":Vector3.ZERO,"wrist":Vector3(0.55,0.78,-0.12),"guard":Vector3.ZERO,"roll":0.0,"aim":Vector3(0,0,-1)}
const HIGH={"hip":Vector3(-0.04,-0.22,-0.04),"chest":Vector3(0.04,-0.18,-0.08),"offset":Vector3(0.025,-0.035,0.015),"wrist":Vector3(0.66,1.68,0.12),"guard":Vector3(0.25,0,-0.3),"roll":-0.3,"aim":Vector3(0.30,0.75,0.45)}
const DIAGONAL_END={"hip":Vector3(0.11,-0.34,0.05),"chest":Vector3(0.16,-0.21,0.06),"offset":Vector3(0.04,-0.07,-0.035),"wrist":Vector3(0.61,0.99,-0.53),"guard":Vector3(0.5,0,-0.4),"roll":0.2,"aim":Vector3(0.40,-0.40,-0.85)}
const LEFT_END={"hip":Vector3(0.03,0.50,-0.05),"chest":Vector3(0.08,0.44,-0.08),"offset":Vector3(-0.045,-0.06,-0.02),"wrist":Vector3(-0.46,1.30,-0.42),"guard":Vector3(0.5,0.3,-0.5),"roll":-0.2,"aim":Vector3(-0.95,0.10,-0.25)}
const FINISH_LOAD={"hip":Vector3(-0.08,0.60,-0.08),"chest":Vector3(-0.10,0.48,-0.10),"offset":Vector3(-0.04,-0.12,0.015),"wrist":Vector3(-0.43,1.48,-0.27),"guard":Vector3(0.65,0.2,-0.5),"roll":-0.4,"aim":Vector3(-0.90,0.38,0.10)}
const RIGHT_END={"hip":Vector3(0.17,-0.64,0.08),"chest":Vector3(0.19,-0.52,0.12),"offset":Vector3(0.05,-0.085,-0.07),"wrist":Vector3(0.76,1.14,-0.10),"guard":Vector3(0.35,-0.25,-0.55),"roll":0.45,"aim":Vector3(0.98,0.05,-0.18)}

static func interpolate(a: Dictionary,b: Dictionary,u: float)->Dictionary:
	var result={}
	for key in a:result[key]=lerp(a[key],b[key],smoothstep(0,1,u))
	return result

static func with_wrist(p: Dictionary,wrist: Vector3,aim: Vector3=Vector3.ZERO)->Dictionary:
	var result=p.duplicate();result.wrist=wrist
	if aim.length_squared()>0:result.aim=aim
	return result

static func raw(stage: int,t: float)->Dictionary:
	var keys: Array
	match stage:
		1: keys=[[0.0,IDLE],[0.21,HIGH],[0.48,with_wrist(DIAGONAL_END,Vector3(0.50,1.10,-0.62))],[1.0,DIAGONAL_END]]
		2: keys=[[0.0,DIAGONAL_END],[0.38,with_wrist(interpolate(DIAGONAL_END,LEFT_END,0.5),Vector3(0.0,1.24,-0.70),Vector3(0,0,-1))],[0.62,LEFT_END],[1.0,FINISH_LOAD]]
		_: keys=[[0.0,FINISH_LOAD],[0.30,with_wrist(FINISH_LOAD,Vector3(-0.49,1.53,-0.22))],[0.48,with_wrist(interpolate(FINISH_LOAD,RIGHT_END,0.5),Vector3(0.12,1.19,-0.72),Vector3(0.15,-0.05,-1))],[0.66,RIGHT_END],[0.76,RIGHT_END],[1.0,IDLE]]
	for i in range(keys.size()-1):
		if t<=keys[i+1][0]:return interpolate(keys[i][1],keys[i+1][1],inverse_lerp(keys[i][0],keys[i+1][0],t))
	return keys[-1][1].duplicate()

static func sample(stage: int,t: float,contact_override: float=-1.0)->Dictionary:
	return Strike.sample(stage,t,contact_override if contact_override>=0 else CONTACT[clampi(stage-1,0,2)])

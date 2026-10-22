extends "res://scripts/recovered_leader_model.gd"
## Restore Ed's own recovered ground poses, retaining the shared playable controls.
func _init():character_id=14
func _ready():
 super._ready()
 # Source01 is Ed's native sixteen-pose gait. Neither the authored Derived_Run
 # nor Musashi's retargeted locomotion belongs to this original sequence.
 for key in ["Walk","Run","Sprint"]:clips[key]=motion("source_01")
func gait_nominal_speed(_key: String)->float:
 # A single clip keeps a continuous cadence across the walk/run threshold.
 return 7.0

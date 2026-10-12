extends "res://assets/characters/musashi/animations/relaxed_idle_v05.gd"
## Visual choreography only. Combat keeps its own release times and hit volumes.
func casting_pose(c) -> Variant:
	if c.state==c.State.FIREBALL:
		var t=c.progress()
		var wind=smoothstep(0,.12,t)
		# Full extension coincides with the unchanged 27% projectile release.
		var drive=smoothstep(.12,.27,t)
		var recover=smoothstep(.52,1,t)
		var weight=1.0-recover
		var large=1.0 if c.large_cast else 0.0
		var twist=lerpf(.66*wind,-.76-large*.16,drive)*weight
		set_rot("Hips",Vector3(lerpf(.07,-.14,drive)*weight,twist*.55,lerpf(-.045,.06,drive)*weight))
		set_rot("Chest",Vector3(lerpf(.13,-.22-large*.06,drive)*weight,twist,lerpf(-.10,.10,drive)*weight))
		set_rot("Head",Vector3(.07*weight,-twist*.68,-.035*weight))
		set_rot("Arm_R",Vector3(lerpf(-.50*wind,-1.57-large*.10,drive)*weight,lerpf(-.70*wind,.26,drive)*weight,lerpf(-.46*wind,-.08,drive)*weight))
		set_rot("Forearm_R",Vector3(lerpf(-1.40*wind,-.10,drive)*weight,0,lerpf(-.12,.08,drive)*weight))
		set_rot("Hand_R",Vector3(lerpf(-.38,.25,drive)*weight,.14*weight,0))
		# The support arm opens on a giant cast and counterbalances the throw.
		set_rot("Arm_L",Vector3(lerpf(-.64,-.82-large*.35,drive)*weight,lerpf(.32,-.28,drive)*weight,.28*weight))
		set_rot("Forearm_L",Vector3(lerpf(-1.0,-.50-large*.12,drive)*weight,0,0))
		set_rot("Hand_L",Vector3(-.18*weight,0,.12*weight))
		if grounded and speed<1.0:
			set_rot("Leg_L",Vector3(lerpf(-.22,.06,drive)*weight,twist*-.16,.035*weight))
			set_rot("Shin_L",Vector3(lerpf(.38,.18,drive)*weight,0,0))
			set_rot("Foot_L",Vector3(-.13*weight,-twist*.12,0))
			set_rot("Leg_R",Vector3(lerpf(.12,-.24,drive)*weight,twist*-.12,-.035*weight))
			set_rot("Shin_R",Vector3(lerpf(.12,.42,drive)*weight,0,0))
			set_rot("Foot_R",Vector3(-.12*drive*weight,twist*.16,0))
		return -.055*sin(t*PI)*weight
	if c.state==c.State.BEAM:
		var tremor=sin(c.elapsed*24)*.025
		set_rot("Hips",Vector3(-.10,.14,0));set_rot("Chest",Vector3(-.18+tremor,-.20,0))
		set_rot("Head",Vector3(.10,.10,0))
		set_rot("Arm_R",Vector3(-1.48+tremor,.12,-.12));set_rot("Forearm_R",Vector3(-.13,0,0));set_rot("Hand_R",Vector3(.18,0,0))
		set_rot("Arm_L",Vector3(-1.28,-.15,.25));set_rot("Forearm_L",Vector3(-.55,0,0));set_rot("Hand_L",Vector3(.14,0,0))
		if grounded and speed<1.0:
			set_rot("Leg_L",Vector3(-.20,0,.04));set_rot("Shin_L",Vector3(.30,0,0))
			set_rot("Leg_R",Vector3(.10,0,-.04));set_rot("Shin_R",Vector3(.15,0,0))
		return -.04
	return null

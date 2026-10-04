class_name DefenseCards
extends RefCounted
## Run-local choices. Mechanics live in the director, towers, and enemy traits.

static func definitions()->Array[Dictionary]:
	return [
		{"id":"ice_shells","title":"Frost Battery","tag":"CANNON ELEMENT","icon":"ice","color":"85dbff","max_stacks":1,"description":"All cannons fire ice shells. Hits slow enemies by 40% for 2 seconds. Bosses resist part of the chill."},
		{"id":"deep_freeze","title":"Deep Winter","tag":"ICE UPGRADE","icon":"ice","color":"b3edff","max_stacks":2,"requires":"ice_shells","description":"Ice slows by another 10 percentage points and lasts 0.5 seconds longer. Stacks twice."},
		{"id":"shatter","title":"Shatter","tag":"ELEMENT COMBO","icon":"shatter","color":"bbbdff","max_stacks":1,"requires":"ice_shells","description":"Cannon and flame damage increases by 40% against chilled enemies. Pair fire with your ice battery."},
		{"id":"rapid_reload","title":"Rapid Reload","tag":"ALL DEFENSES","icon":"tempo","color":"8ae2c0","max_stacks":3,"description":"Reduce all defense reload times by 15% per pick, up to 45%. More shots, more flame bursts."},
		{"id":"cannon_power","title":"Heavy Ordnance","tag":"CANNON DAMAGE","icon":"shell","color":"efd083","max_stacks":3,"description":"Cannons deal 25% more damage per pick. Applies to ordinary shells and ice shells."},
		{"id":"hot_flames","title":"Dragon's Breath","tag":"FIRE DAMAGE","icon":"fire","color":"ff9862","max_stacks":3,"description":"Flame towers deal 25% more damage per pick. Your animated fire jets burn through the swarm faster."},
		{"id":"long_sights","title":"Eagle Watch","tag":"ALL DEFENSES","icon":"sight","color":"badd8a","max_stacks":2,"description":"All defenses gain 15% range per pick. Start firing farther up the approach."},
		{"id":"siege_payload","title":"Siege Shells","tag":"CANNON PATH · CHOOSE ONE","icon":"blast","color":"edbb71","max_stacks":1,"path":"cannon","value":"siege","description":"50% wider cannon explosions and 15% more damage. Locks out Armor Piercer this run; works with ice."},
		{"id":"piercing_rounds","title":"Armor Piercer","tag":"CANNON PATH · CHOOSE ONE","icon":"pierce","color":"b1c9ec","max_stacks":1,"path":"cannon","value":"piercing","description":"40% more cannon damage; ignores armor and shields. Half the splash radius. Locks out Siege Shells; works with ice."},
		{"id":"wide_flames","title":"Wildfire Fan","tag":"FIRE PATH · CHOOSE ONE","icon":"fire","color":"ffa878","max_stacks":1,"path":"fire","value":"wide","description":"Flame cones spread 60% wider, with 10% less reach. Catch more runners. Locks out Burning Ground this run."},
		{"id":"burning_ground","title":"Burning Ground","tag":"FIRE PATH · CHOOSE ONE","icon":"pool","color":"f78059","max_stacks":1,"path":"fire","value":"pool","description":"Fire bursts leave a 4-metre burning pool: 50 damage/sec for 3 seconds. 20% less reach; locks out Wildfire Fan."},
		{"id":"supply_cache","title":"War Chest","tag":"BUILD & UPGRADE","icon":"gold","color":"f3d883","max_stacks":0,"description":"Gain 1,000 gold immediately. Spend it at wall pads to build defenses or buy their next level."},
		{"id":"shrine_repair","title":"Second Wind","tag":"RECOVERY","icon":"heart","color":"98e2ac","max_stacks":0,"description":"Restore 30 shrine integrity and 40 hero health, up to their maximums. Get ready for the next push."},
		{"id":"fortified_shrine","title":"Stone Sanctuary","tag":"SHRINE DEFENSE","icon":"shield","color":"a5cfdf","max_stacks":3,"description":"Increase maximum shrine integrity by 25 and restore 25 integrity. Stacks up to three times."},
		{"id":"bounty_hunters","title":"Bounty Charter","tag":"KILL REWARDS","icon":"gold","color":"f0c57c","max_stacks":3,"description":"Every enemy kill grants 4 extra gold per pick, whether you or a tower lands the final blow."},
	]

static func get_card(id: String)->Dictionary:
	for card in definitions():
		if card.id==id:return card
	return {}

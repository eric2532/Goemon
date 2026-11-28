extends Node3D
## Native deaths supply food; optional chests are prepared on reachable ground at area entry.
const CHESTS=[preload("res://assets/items/crossgate/chest.png"),preload("res://assets/items/crossgate/black-chest.png"),preload("res://assets/items/crossgate/white-chest.png")]
const Nutrition=preload("res://scripts/forest/chest_food.gd")
const CHEST_SOUND=preload("res://assets/audio/crossgate/cgsys02.wav")
const FOOD_SOUND=preload("res://assets/audio/crossgate/cgsys03.wav")
const Gear=preload("res://scripts/forest/equipment.gd")
const FOODS=[preload("res://assets/items/crossgate/bread.png"),preload("res://assets/items/crossgate/roast-chicken.png"),preload("res://assets/items/crossgate/bento.png"),preload("res://assets/items/crossgate/hot-pot.png"),preload("res://assets/items/crossgate/stew.png"),preload("res://assets/items/crossgate/noodles.png"),preload("res://assets/items/crossgate/fruit-salad.png"),preload("res://assets/items/crossgate/dumplings.png"),preload("res://assets/items/crossgate/oyakodon.png"),preload("res://assets/items/crossgate/melon-bread.png"),preload("res://assets/items/crossgate/red-jelly.png"),preload("res://assets/items/crossgate/blue-jelly.png"),preload("res://assets/items/crossgate/green-jelly.png")]
const FOOD_NAMES=["Bread","Roast chicken","Bento","Hot pot","Hearty stew","Noodles","Fruit salad","Dumplings","親子丼","哈密瓜麵包","Red jello","Blue jello","Green jello"]
const HEAL=[.25,.5,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
const BUFFS=["","","","damage_mult","max_hp","attack_speed","movement_speed","defense","","","jelly_damage","jelly_magic","jelly_speed"]
const EFFECTS=["","","","Damage +30% · 10 min","Max HP +30% · 10 min","Attack speed +20% · 10 min","Movement speed +20% · 10 min","Defense +20 · 10 min","Skill size & hit radius +5% · Rest of run","Invites all enemies on this map","Damage +50% · 5 min","Magic damage +50% · 5 min","Attack speed +50% · 5 min"]
const OYAKODON=8
const MELON_BREAD=9
const EXPLORE_MELON_BREAD_EXTRA_TICKETS=7
const RED_JELLY=10
const BLUE_JELLY=11
const GREEN_JELLY=12
const BUFF_FOODS=[3,4,5,6,7,8,RED_JELLY,BLUE_JELLY,GREEN_JELLY]
const CONSUME_TIME=.65
const CAPACITY=64
const OPEN_DISTANCE=4.0
const PICKUP_DISTANCE=2.4
const MAGNET_DISTANCE=7.5
const MAGNET_SPEED=24.0
const FOOD_LIFETIME=120.0
var game:Node
var rng=RandomNumberGenerator.new()
var slots:Array[Dictionary]=[]
var batches:Array[MultiMeshInstance3D]=[]
var opened_chests:Dictionary={}
var boss_contents:Dictionary={}
var sword_bag:Array=[]
var reward_bag:Array=[]
var boss_bonus_bag:Array=[]
var elite_chance_bag:Array=[]
var elite_gear_bag:Array=[]
var drop_bag:Array=[]
var explore_drop_bag:Array=[]
var prepared_model:WeakRef
var buff_tiles:Array[Control]=[]
var buff_counts:Array[Label]=[]
var receipt:PanelContainer
var food_icon:TextureRect
var food_text:Label
var receipt_left=0.0
var refresh_left=0.0

func _ready():
	name="ExplorationLoot";process_mode=Node.PROCESS_MODE_ALWAYS;rng.randomize()
	for texture in CHESTS+FOODS+Nutrition.ICONS.values():
		var material=StandardMaterial3D.new()
		material.albedo_texture=texture;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var mesh=QuadMesh.new();mesh.size=texture.get_size()*(.06375 if batches.size()<CHESTS.size() else .032);mesh.material=material
		var batch=MultiMeshInstance3D.new();batch.name="LootBatch%d"%batches.size()
		batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=mesh;batch.multimesh.instance_count=CAPACITY;batch.multimesh.visible_instance_count=0
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch);batches.append(batch)
	for i in CAPACITY:slots.append({"active":false})
	for kind in BUFF_FOODS:
		var tile=Control.new();tile.name=FOOD_NAMES[kind].replace(" ","");tile.custom_minimum_size=Vector2(72,36)
		tile.mouse_filter=Control.MOUSE_FILTER_PASS;game.forest_ui.food_effects.add_child(tile);buff_tiles.append(tile)
		game.forest_ui.dock_icon(tile,FOODS[kind],Vector2.ZERO,Vector2(36,36))
		var count:Label=game.forest_ui.dock_label(tile,"",Vector2(37,8),16)
		count.add_theme_color_override("font_shadow_color",Color.BLACK);count.add_theme_constant_override("shadow_outline_size",4)
		buff_counts.append(count);tile.hide()
	receipt=PanelContainer.new();receipt.name="FoodReceipt";receipt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var backdrop=StyleBoxFlat.new();backdrop.bg_color=Color(.055,.075,.085,.94)
	backdrop.border_color=Color("d8bd80");backdrop.set_border_width_all(1);backdrop.set_corner_radius_all(6)
	backdrop.content_margin_left=12;backdrop.content_margin_right=12;backdrop.content_margin_top=8;backdrop.content_margin_bottom=8
	receipt.add_theme_stylebox_override("panel",backdrop)
	game.forest_ui.add_child(receipt);receipt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	receipt.offset_left=-260;receipt.offset_right=260;receipt.offset_top=-245;receipt.offset_bottom=-177
	var row=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_theme_constant_override("separation",12);receipt.add_child(row)
	food_icon=TextureRect.new();food_icon.custom_minimum_size=Vector2(48,48)
	food_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;food_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	food_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(food_icon)
	food_text=Label.new();food_text.mouse_filter=Control.MOUSE_FILTER_IGNORE;food_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	food_text.add_theme_font_size_override("font_size",17);food_text.add_theme_color_override("font_color",Color("f0e5cc"))
	food_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(food_text);receipt.hide()
	game.army_runtime.unit_died.connect(enemy_died)

static func chest_kind(roll:float)->int:
	if roll<.05:return 1
	if roll<.10:return 2
	return 0

func exploring()->bool:
	return not game.model.falan_area.is_empty() or game.model.terrain_detail==game.model.FreyjaTerrain.ID

func available()->bool:
	return game.playing and game.model.phase=="wave" and not game.paused and not game.get_tree().paused and not game.ordinary_pause and not game.transitioning and not game.settings_open and not game.rogue_roster_open and game.player.hp>0 and not game.map_editor.active

func prepare_world():
	if not exploring() or (prepared_model!=null and prepared_model.get_ref()==game.model):return
	prepared_model=weakref(game.model)
	var model=game.model;var area:String=game.FalanTour.area(model)
	var source_context=game.FalanTour.Regions.private_source_context
	if source_context!=null and source_context.suppress_entry_chests(model):return
	# These fixed source areas have no generic entry-chest record; explicit rewards retain their owner.
	if model.falan_area=="interior":
		var originals=game.FalanTour.Indoor.Original
		if model.falan_floor in [15526,16509,3354,5011] or model.falan_floor in originals.Art.SOKIA_CAPE_ACCESS_IDS or originals.owns(model.falan_floor) and originals.Art.data().maps.get(originals.path_for(model.falan_floor),{}).get("group","")=="elsa":return
	var placement=RandomNumberGenerator.new();placement.seed=hash([model.seed_value,area,model.falan_floor])
	var origin:Vector3=game.FalanTour.spawn(model,game.PLAYER_SPAWN_CELL)
	var start:Vector2i=model.nearest_open(model.cell_of(origin/model.falan_scale))
	var winter=game.FalanTour.Winter
	var snow_floor:bool=model.falan_area=="interior" and model.falan_floor in winter.SNOW_FLOORS
	var decree:bool=model.falan_area=="interior" and winter.Decree.owns(model.falan_floor)
	var recovered:bool=model.falan_area=="interior" and winter.Recovered.owns(model.falan_floor)
	var prayer:bool=model.falan_area=="interior" and model.falan_floor in game.FalanTour.Indoor.Prayer.FLOORS
	var highland:bool=model.falan_area=="interior" and model.falan_floor in [winter.ABANIS,winter.UNIVERSITY,winter.ABANIS_HALL,
		winter.STUDY_HALL,winter.COAST_ROAD,winter.WORKSHOP,winter.GLASSHOUSE,winter.ABANIS_HOSPITAL,winter.AUDITORIUM,winter.ROOF_GARDEN]
	var floor_view:Array=game.FalanTour.Indoor.floor_info(model.falan_floor,model.seed_value) if highland or decree or recovered or prayer else []
	var walk:PackedByteArray=floor_view[2].hex_decode() if not floor_view.is_empty() else PackedByteArray()
	if prayer:walk=game.FalanTour.Indoor.Prayer.walk_mask(model.falan_floor,model.seed_value)
	var exits:Array=model.get_meta("falan_links",[]) if decree or recovered or prayer else []
	var decree_corridor=decree and winter.Decree.floor_number(model.falan_floor)>0 and model.falan_floor not in winter.Decree.GUARDIAN_FLOORS
	var snow_cells:Array=[]
	if snow_floor:
		var maze:Dictionary=winter.snow_maze(model.falan_floor,model.seed_value)
		var candidates:Array=winter.patrol_cells(model.falan_floor,maze.bits,1).filter(func(tile):return tile not in maze.posts)
		snow_cells=winter.Maze.shuffled(candidates,placement)
	var placed:Array[Vector3]=[]
	var target=1 if decree_corridor else 3 if model.falan_area=="interior" else 12
	var generated=game.FalanTour.Winter.Recovered.generated()
	if generated.owns(model.falan_floor) and generated.SPECS[generated.branch(model.falan_floor)].has("box_amount"):
		target=generated.box_count(model.falan_floor,model.seed_value)
	elif prayer:target=game.FalanTour.Indoor.Prayer.box_count(model.falan_floor,model.seed_value)
	var attempts:int=snow_cells.size() if snow_floor else 512
	for attempt in attempts:
		if placed.size()>=target:break
		var cell:Vector2i
		var point:Vector3
		if snow_floor:
			cell=snow_cells[attempt]
			point=model.world_point(winter.point(cell))
		else:
			cell=Vector2i(placement.randi_range(model.navigation_region.position.x,model.navigation_region.end.x-1),placement.randi_range(model.navigation_region.position.y,model.navigation_region.end.y-1))
			if model.allied_grid.is_point_solid(cell):continue
			point=model.point(cell)*model.falan_scale
			if highland or decree or recovered or prayer:
				var local=Vector2(cell)*model.CELL
				var tile=Vector2i(((local-floor_view[1])/3.0).round())
				if not game.FalanTour.Indoor.open_cell(walk,floor_view[0],tile.x,tile.y):continue
				if model.falan_floor==winter.ROOF_GARDEN and winter.ROOF_LANDINGS.values().any(func(at):return local.distance_squared_to(at)<36.0):continue
				if exits.any(func(link):return local.distance_squared_to(link.at)<36.0):continue
		if point.distance_squared_to(origin)<144 or placed.any(func(other):return other.distance_squared_to(point)<144):continue
		if not model.waves.navigation.move_clear(point/model.falan_scale,.8):continue
		if not snow_floor and model.route(start,cell).is_empty():continue
		placed.append(point)
		var kind=chest_kind(placement.randf())
		var key="%s:%d:%d:%d"%[area,model.falan_floor,cell.x,cell.y]
		if not opened_chests.has(key):spawn_chest(kind,point,key)

func enemy_died(event:Dictionary):
	if event.team!=0 or game.model.phase!="wave":return
	var explore=exploring()
	if not explore and int(event.get("unit_kind",-1))!=game.EnemyRoles.SLIME:return
	if game.model.enemies.get(event.target_id,{}).get("elite",false):spawn_chest(0,event.position,"",false,true)
	var kind=draw_food_drop(explore)
	if kind>=0:spawn_food(kind,event.position)

func draw_food_drop(explore:bool)->int:
	var bag=explore_drop_bag if explore else drop_bag
	if bag.is_empty():
		# Extra melon bread takes only miss tickets so the other foods keep their odds.
		var extra=EXPLORE_MELON_BREAD_EXTRA_TICKETS if explore else 0
		bag.assign(range(FOODS.size()))
		for i in extra:bag.append(MELON_BREAD)
		for i in FOODS.size()*4-extra:bag.append(-1)
		shuffle_bag(bag)
	return bag.pop_back()

func spawn_chest(kind:int,point:Vector3,key:String="",boss:bool=false,elite:bool=false)->bool:
	return _spawn(kind,point,true,key,boss,elite)

func spawn_boss_chest(point:Vector3,key:String)->bool:
	if key.is_empty() or opened_chests.has(key) or slots.any(func(slot):return slot.active and slot.get("key","")==key):return false
	if not boss_contents.has(key):boss_contents[key]={"sword":draw_sword()}
	if not spawn_chest(1,point,key,true):return false
	for slot in slots:
		if slot.active and slot.key==key:
			slot.reward="weapon";slot.merge(boss_contents[key]);return true
	return false

func spawn_food(kind:int,point:Vector3)->bool:
	return _spawn(kind,point,false,"")

func _spawn(kind:int,point:Vector3,chest:bool,key:String,boss:bool=false,elite:bool=false)->bool:
	if kind<0 or kind>=(3 if chest else FOODS.size()) or not point.is_finite():return false
	# Required chest rewards cannot be lost to a full food/chest pool.
	if chest and slots.all(func(slot):return slot.active):slots.append({"active":false})
	for slot in slots:
		if slot.active:continue
		point.y=game.model.world_height(point.x,point.z)+.05
		slot.assign({"active":true,"chest":chest,"boss":boss,"elite":elite,"kind":kind,"pos":point,"left":FOOD_LIFETIME,"key":key})
		for node in batches:
			if node.multimesh.instance_count<slots.size():node.multimesh.instance_count=nearest_po2(slots.size())
		_sync_batches();return true
	return false

func _sync_batches():
	var counts=PackedInt32Array();counts.resize(batches.size())
	for slot in slots:
		if not slot.active:continue
		var index:int=slot.get("batch",slot.kind+(0 if slot.chest else 3))
		var size=lerpf(1.0,.15,pow(slot.get("flight",0.0)/CONSUME_TIME,3))
		var point:Vector3=slot.pos+Vector3.UP*batches[index].multimesh.mesh.size.y*.5*size
		batches[index].multimesh.set_instance_transform(counts[index],Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),point));counts[index]+=1
	for index in batches.size():batches[index].multimesh.visible_instance_count=counts[index]

func nearby(slot:Dictionary,distance:float)->bool:
	return game.player.position.distance_squared_to(slot.pos)<=distance*distance and game._ryo_clear_path(game.player.position+Vector3.UP,slot.pos+Vector3.UP)

func nearest()->int:
	if not available():return -1
	var found=-1;var distance=OPEN_DISTANCE
	for i in slots.size():
		var slot:Dictionary=slots[i]
		if not slot.active or not slot.chest or slot.get("flying",false) or not nearby(slot,distance):continue
		distance=game.player.position.distance_to(slot.pos);found=i
	return found

func eat(kind:int,feedback:bool=true)->bool:
	if not available() or kind<0 or kind>=FOODS.size():return false
	var before:float=game.player.hp
	if kind==MELON_BREAD:
		game.model.waves.invite_map_enemies()
		food_text.text=FOOD_NAMES[kind]+" · "+EFFECTS[kind]
	elif kind==OYAKODON:
		game.model.team_progression.skill_food_stacks+=1
		food_text.text=FOOD_NAMES[kind]+" · "+EFFECTS[kind]
	elif BUFFS[kind].is_empty():
		game.player.hp=minf(game.player.max_hp,before+game.player.max_hp*HEAL[kind])
		food_text.text="%s · +%d HP"%[FOOD_NAMES[kind],ceili(game.player.hp-before)] if game.player.hp>before else FOOD_NAMES[kind]+" · HP full"
	else:
		game.player.apply_food_buff(BUFFS[kind]);food_text.text="%s · %s"%[FOOD_NAMES[kind],EFFECTS[kind]]
	food_icon.texture=FOODS[kind];receipt_left=3.0;receipt.show()
	if feedback:pickup_feedback()
	return true

func pickup_feedback(chest:bool=false):
	game.sound("pickup",.8 if chest else .6,false,{},0,CHEST_SOUND if chest else FOOD_SOUND);game.forest_ui.sync();sync_buffs()

func open_nearest()->bool:
	var index=nearest()
	if index<0:return false
	var slot:Dictionary=slots[index]
	if not slot.boss and not slot.elite:
		var reward:String=slot.get("reward","")
		if reward=="weapon" or is_accessory(reward) or slot.has("sword"):
			slot.erase("reward");slot.erase("sword")
	# Keep contents stable until the reward is saved, including after a failed write.
	if not slot.has("reward"):
		if slot.boss:
			slot.reward="weapon"
		else:
			var gear=draw_elite_gear() if slot.elite else ""
			if gear in Gear.CHEST_WEAPONS:
				slot.reward="weapon";slot.sword=gear
			else:
				slot.reward=draw_reward() if gear.is_empty() else gear
	if is_accessory(slot.reward):return claim_accessory(slot)
	if slot.reward!="weapon":
		if not Nutrition.eligible(game,slot.reward):
			game.toast("This food needs an eligible character or a selected pet below its cap.")
			return true
		begin_consuming(slot)
		game.sound("pickup",.8,false,{},0,CHEST_SOUND)
		return true
	if not slot.has("sword"):slot.sword=draw_sword()
	var bonus=""
	if slot.boss:
		if not slot.has("bonus") or not slot.bonus.is_empty() and not reward_eligible(slot.bonus):
			slot.bonus=draw_reward(true)
			if boss_contents.has(slot.key):boss_contents[slot.key].bonus=slot.bonus
		bonus=slot.bonus
	var previous:Array=game.settings.chest_swords
	var previous_upgrades:Dictionary=game.settings.sword_upgrades
	var previous_accessories:Dictionary=game.settings.accessory_drops
	var duplicate:bool=slot.sword in previous
	if duplicate:
		game.settings.sword_upgrades=previous_upgrades.duplicate()
		game.settings.sword_upgrades[slot.sword]=int(previous_upgrades.get(slot.sword,0))+1
	else:
		game.settings.chest_swords=Gear.sanitized_swords(previous+[slot.sword])
	if is_accessory(bonus):
		game.settings.accessory_drops=previous_accessories.duplicate();game.settings.accessory_drops[bonus]=int(previous_accessories.get(bonus,0))+1
	if game.save_settings()!=OK:
		game.settings.chest_swords=previous;game.settings.sword_upgrades=previous_upgrades;game.settings.accessory_drops=previous_accessories
		game.toast("Could not save weapon. Open this chest again to retry.")
		return true
	if duplicate:Gear.apply(game.player)
	var item:Dictionary=Gear.item_data(slot.sword,game.settings)
	food_icon.texture=item.icon
	food_text.text=item.name+(" · Upgraded · ATK +%d"%roundi(item.effects.attack) if duplicate else " · Added to Equipment")
	if Nutrition.ITEMS.has(bonus) and Nutrition.reward(game,bonus):food_text.text+="\n+ "+Nutrition.ITEMS[bonus].name+" · "+Nutrition.ITEMS[bonus].effect
	elif is_accessory(bonus):food_text.text+="\n+ "+Gear.ITEMS[bonus].name
	consume_chest(slot);return true

func claim_accessory(slot:Dictionary)->bool:
	var previous:Dictionary=game.settings.accessory_drops
	game.settings.accessory_drops=previous.duplicate();game.settings.accessory_drops[slot.reward]=int(previous.get(slot.reward,0))+1
	if game.save_settings()!=OK:
		game.settings.accessory_drops=previous;game.toast("Could not save accessory. Open this chest again to retry.");return true
	var item:Dictionary=Gear.item_data(slot.reward,game.settings)
	food_icon.texture=item.icon;food_text.text=item.name+" · Collected ×%d"%game.settings.accessory_drops[slot.reward]
	consume_chest(slot);return true

func is_accessory(id:String)->bool:
	return Gear.ITEMS.get(id,{}).get("category","")=="accessories"

func reward_eligible(id:String)->bool:
	return is_accessory(id) or Nutrition.eligible(game,id)

func begin_consuming(slot:Dictionary):
	slot.flying=true;slot.flight=0.0;slot.ground=slot.pos
	if slot.chest:slot.batch=CHESTS.size()+FOODS.size()+Nutrition.ICONS.keys().find(slot.reward)
	slot.offset=slot.pos-game.player.position
	if slot.offset.length()<.5:slot.offset=Vector3.RIGHT*1.4

func finish_nutrition(slot:Dictionary)->bool:
	var before_level:int=game.model.team_progression.level
	if not Nutrition.reward(game,slot.reward):
		slot.pos=slot.ground
		for key in ["flying","flight","offset","ground","batch"]:slot.erase(key)
		return false
	var food:Dictionary=Nutrition.ITEMS[slot.reward]
	food_icon.texture=Nutrition.ICONS[slot.reward]
	var effect:String=("+%d character levels"%(game.model.team_progression.level-before_level)) if food.has("levels") else food.effect
	food_text.text=food.name+" · "+effect+" · Rest of run"
	receipt_left=6.0;receipt.show()
	if not slot.key.is_empty():opened_chests[slot.key]=true
	slot.active=false
	return true

func consume_chest(slot:Dictionary):
	receipt_left=6.0;receipt.show();pickup_feedback(true)
	if not slot.key.is_empty():opened_chests[slot.key]=true
	if slot.get("boss",false):game.explore_access.invalidate()
	slot.active=false;_sync_batches()

func draw_reward(include_accessories:bool=false)->String:
	var rewards=Nutrition.ITEMS.keys()
	if include_accessories:rewards+=Gear.ITEMS.keys().filter(is_accessory)
	if not rewards.any(reward_eligible):return ""
	var bag=boss_bonus_bag if include_accessories else reward_bag
	while true:
		if bag.is_empty():
			bag.assign(rewards)
			shuffle_bag(bag)
		var id:String=bag.pop_back()
		if id in rewards and reward_eligible(id):return id
	return ""

func draw_elite_gear()->String:
	if elite_chance_bag.is_empty():
		elite_chance_bag.resize(100)
		elite_chance_bag.fill(false)
		elite_chance_bag[0]=true
		shuffle_bag(elite_chance_bag)
	if not elite_chance_bag.pop_back():return ""
	if elite_gear_bag.is_empty():
		elite_gear_bag.assign(Gear.CHEST_WEAPONS+Gear.ITEMS.keys().filter(is_accessory))
		shuffle_bag(elite_gear_bag)
	return elite_gear_bag.pop_back()

func draw_sword()->String:
	if sword_bag.is_empty():
		sword_bag.assign(Gear.CHEST_WEAPONS)
		shuffle_bag(sword_bag)
	return sword_bag.pop_back()

func shuffle_bag(bag:Array):
	for i in range(bag.size()-1,0,-1):
		var j=rng.randi_range(0,i)
		var ticket=bag[i];bag[i]=bag[j];bag[j]=ticket

func sync_buffs():
	var any_active=false;var layout_changed=false
	for kind in BUFF_FOODS:
		var permanent=kind==OYAKODON
		var left:float=0.0 if permanent else game.player.food_buffs[BUFFS[kind]]
		var stacks:int=game.model.team_progression.skill_food_stacks if permanent else game.player.food_buff_stacks[BUFFS[kind]]
		var row=BUFF_FOODS.find(kind)
		var tile=buff_tiles[row];var active=(permanent or left>0) and stacks>0
		layout_changed=layout_changed or tile.visible!=active;tile.visible=active
		if not tile.visible:continue
		any_active=true
		var seconds=ceili(left)
		buff_counts[row].text="×%d"%stacks if stacks>1 else ""
		var width=maxf(72,37+buff_counts[row].get_combined_minimum_size().x)
		layout_changed=layout_changed or tile.custom_minimum_size.x!=width;tile.custom_minimum_size.x=width
		if permanent:tile.tooltip_text="親子丼 ×%d\nSkill size & hit radius +%d%%\nRest of run"%[stacks,roundi(game.model.team_progression.SKILL_FOOD_STEP*100*stacks)]
		else:
			var label:String={3:"Damage",4:"Max HP",5:"Attack speed",6:"Movement speed",7:"Defense",RED_JELLY:"Damage",BLUE_JELLY:"Magic damage",GREEN_JELLY:"Attack speed"}[kind]
			var bonus=stacks*(50 if kind>=RED_JELLY else 20 if kind>=5 else 30)
			tile.tooltip_text="%s ×%d\n%s +%d%s\n%d:%02d remaining"%[FOOD_NAMES[kind],stacks,label,bonus,"" if kind==7 else "%",seconds/60,seconds%60]
	var show_row=any_active and game.playing and game.model.phase=="wave" and game.player.hp>0 and not game.settings_open and not game.rogue_roster_open and not game.transitioning
	layout_changed=layout_changed or game.forest_ui.food_effects.visible!=show_row
	game.forest_ui.food_effects.visible=show_row
	if layout_changed:game.forest_ui.sync_hound_health();game.forest_ui.sync_hud_layout(game.model.phase=="preparing")

func _process(delta:float):
	if not available():
		receipt.hide();refresh_left-=delta
		if refresh_left<=0:refresh_left=.1;sync_buffs()
		return
	receipt_left=maxf(0,receipt_left-delta);receipt.visible=receipt_left>0
	var changed=false;var ate=false
	for slot in slots:
		if not slot.active:continue
		if slot.get("flying",false):
			if not game._ryo_clear_path(game.player.position+Vector3.UP,slot.pos+Vector3.UP):continue
			slot.flight=minf(CONSUME_TIME,slot.flight+delta)
			var t:float=slot.flight/CONSUME_TIME
			slot.pos=game.player.position+slot.offset.rotated(Vector3.UP,TAU*t*.85)*(1.0-t)+Vector3.UP*(sin(PI*t)*1.5+2.2*t)
			changed=true
			if slot.flight>=CONSUME_TIME:
				if slot.chest:
					ate=finish_nutrition(slot) or ate
				elif eat(slot.kind,false):slot.active=false;ate=true
			continue
		if slot.chest:continue
		slot.left-=delta
		if slot.left<=0:slot.active=false;changed=true
		elif nearby(slot,MAGNET_DISTANCE):
			slot.pos=slot.pos.move_toward(game.player.position,MAGNET_SPEED*delta);changed=true
			if slot.pos.distance_squared_to(game.player.position)<=PICKUP_DISTANCE*PICKUP_DISTANCE:
				begin_consuming(slot)
	if ate:pickup_feedback()
	refresh_left-=delta
	if refresh_left<=0:
		refresh_left=.1
		sync_buffs()
	if changed:_sync_batches()

func clear():
	for slot in slots:slot.assign({"active":false})
	for batch in batches:batch.multimesh.visible_instance_count=0
	prepared_model=null;receipt_left=0;refresh_left=0
	if receipt!=null:receipt.hide();game.forest_ui.food_effects.hide()

extends Node3D
## Native deaths supply food; optional chests are prepared on reachable ground at area entry.
const CHESTS=[preload("res://assets/items/crossgate/chest.png"),preload("res://assets/items/crossgate/black-chest.png"),preload("res://assets/items/crossgate/white-chest.png")]
const Gear=preload("res://scripts/forest/equipment.gd")
const FOODS=[preload("res://assets/items/crossgate/bread.png"),preload("res://assets/items/crossgate/roast-chicken.png"),preload("res://assets/items/crossgate/bento.png"),preload("res://assets/items/crossgate/hot-pot.png"),preload("res://assets/items/crossgate/stew.png"),preload("res://assets/items/crossgate/noodles.png"),preload("res://assets/items/crossgate/fruit-salad.png"),preload("res://assets/items/crossgate/dumplings.png"),preload("res://assets/items/crossgate/oyakodon.png")]
const FOOD_NAMES=["Bread","Roast chicken","Bento","Hot pot","Hearty stew","Noodles","Fruit salad","Dumplings","親子丼"]
const HEAL=[.25,.5,1.0,0.0,0.0,0.0,0.0,0.0,0.0]
const BUFFS=["","","","damage_mult","max_hp","attack_speed","movement_speed","defense",""]
const EFFECTS=["","","","Damage +30% · 10 min","Max HP +30% · 10 min","Attack speed +20% · 10 min","Movement speed +20% · 10 min","Defense +20 · 10 min","Skill size & hit radius +5% · Rest of run"]
const OYAKODON=8
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
var sword_bag:Array=[]
var prepared_model:WeakRef
var buff_tiles:Array[Control]=[]
var buff_counts:Array[Label]=[]
var receipt:HBoxContainer
var food_icon:TextureRect
var food_text:Label
var receipt_left=0.0
var refresh_left=0.0

func _ready():
	name="ExplorationLoot";process_mode=Node.PROCESS_MODE_ALWAYS;rng.randomize()
	for texture in CHESTS+FOODS:
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
	for kind in range(3,FOODS.size()):
		var tile=Control.new();tile.name=FOOD_NAMES[kind].replace(" ","");tile.custom_minimum_size=Vector2(72,36)
		tile.mouse_filter=Control.MOUSE_FILTER_PASS;game.forest_ui.food_effects.add_child(tile);buff_tiles.append(tile)
		game.forest_ui.dock_icon(tile,FOODS[kind],Vector2.ZERO,Vector2(36,36))
		var count:Label=game.forest_ui.dock_label(tile,"",Vector2(37,8),16)
		count.add_theme_color_override("font_shadow_color",Color.BLACK);count.add_theme_constant_override("shadow_outline_size",4)
		buff_counts.append(count);tile.hide()
	receipt=HBoxContainer.new();receipt.name="FoodReceipt";receipt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.forest_ui.add_child(receipt);receipt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	receipt.offset_left=-220;receipt.offset_right=220;receipt.offset_top=-245;receipt.offset_bottom=-201
	food_icon=TextureRect.new();food_icon.custom_minimum_size=Vector2(44,44)
	food_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;food_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	food_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;receipt.add_child(food_icon)
	food_text=Label.new();receipt.add_child(food_text);receipt.hide()
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
	var placement=RandomNumberGenerator.new();placement.seed=hash([model.seed_value,area,model.falan_floor])
	var origin:Vector3=game.FalanTour.spawn(model,game.PLAYER_SPAWN_CELL)
	var start:Vector2i=model.nearest_open(model.cell_of(origin/model.falan_scale))
	var winter=game.FalanTour.Winter
	var snow_floor:bool=model.falan_area=="interior" and model.falan_floor in winter.SNOW_FLOORS
	var decree:bool=model.falan_area=="interior" and winter.Decree.owns(model.falan_floor)
	var recovered:bool=model.falan_area=="interior" and winter.Recovered.owns(model.falan_floor)
	var highland:bool=model.falan_area=="interior" and model.falan_floor in [winter.ABANIS,winter.UNIVERSITY,winter.ABANIS_HALL,
		winter.STUDY_HALL,winter.COAST_ROAD,winter.WORKSHOP,winter.GLASSHOUSE,winter.ABANIS_HOSPITAL,winter.AUDITORIUM,winter.ROOF_GARDEN]
	var floor_view:Array=game.FalanTour.Indoor.floor_info(model.falan_floor,model.seed_value) if highland or decree or recovered else []
	var walk:PackedByteArray=floor_view[2].hex_decode() if not floor_view.is_empty() else PackedByteArray()
	var exits:Array=model.get_meta("falan_links",[]) if decree or recovered else []
	var decree_corridor=decree and winter.Decree.floor_number(model.falan_floor)>0 and model.falan_floor not in winter.Decree.GUARDIAN_FLOORS
	var snow_cells:Array=[]
	if snow_floor:
		var maze:Dictionary=winter.snow_maze(model.falan_floor,model.seed_value)
		var candidates:Array=winter.patrol_cells(model.falan_floor,maze.bits,1).filter(func(tile):return tile not in maze.posts)
		snow_cells=winter.Maze.shuffled(candidates,placement)
	var placed:Array[Vector3]=[]
	var target=1 if decree_corridor else 3 if model.falan_area=="interior" else 12
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
			if highland or decree or recovered:
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
	if not exploring() and int(event.get("unit_kind",-1))!=game.EnemyRoles.SLIME:return
	if game.model.enemies.get(event.target_id,{}).get("elite",false):spawn_chest(0,event.position)
	if rng.randf()<.20:spawn_food(rng.randi_range(0,FOODS.size()-1),event.position)

func spawn_chest(kind:int,point:Vector3,key:String="")->bool:
	return _spawn(kind,point,true,key)

func spawn_food(kind:int,point:Vector3)->bool:
	return _spawn(kind,point,false,"")

func _spawn(kind:int,point:Vector3,chest:bool,key:String)->bool:
	if kind<0 or kind>=(3 if chest else FOODS.size()) or not point.is_finite():return false
	# Required chest rewards cannot be lost to a full food/chest pool.
	if chest and slots.all(func(slot):return slot.active):slots.append({"active":false})
	for slot in slots:
		if slot.active:continue
		point.y=game.model.world_height(point.x,point.z)+.05
		slot.assign({"active":true,"chest":chest,"kind":kind,"pos":point,"left":FOOD_LIFETIME,"key":key})
		var batch=batches[kind+(0 if chest else 3)].multimesh
		if batch.instance_count<slots.size():batch.instance_count=nearest_po2(slots.size())
		_sync_batches();return true
	return false

func _sync_batches():
	var counts=PackedInt32Array();counts.resize(batches.size())
	for slot in slots:
		if not slot.active:continue
		var index:int=slot.kind+(0 if slot.chest else 3)
		var point:Vector3=slot.pos+Vector3.UP*batches[index].multimesh.mesh.size.y*.5
		batches[index].multimesh.set_instance_transform(counts[index],Transform3D(Basis.IDENTITY,point));counts[index]+=1
	for index in batches.size():batches[index].multimesh.visible_instance_count=counts[index]

func nearby(slot:Dictionary,distance:float)->bool:
	return game.player.position.distance_squared_to(slot.pos)<=distance*distance and game._ryo_clear_path(game.player.position+Vector3.UP,slot.pos+Vector3.UP)

func nearest()->int:
	if not available():return -1
	var found=-1;var distance=OPEN_DISTANCE
	for i in slots.size():
		var slot:Dictionary=slots[i]
		if not slot.active or not slot.chest or not nearby(slot,distance):continue
		distance=game.player.position.distance_to(slot.pos);found=i
	return found

func eat(kind:int,feedback:bool=true)->bool:
	if not available() or kind<0 or kind>=FOODS.size():return false
	var before:float=game.player.hp
	if kind==OYAKODON:
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

func pickup_feedback():
	game.sound("pickup",.6);game.forest_ui.sync();sync_buffs()

func open_nearest()->bool:
	var index=nearest()
	if index<0:return false
	var slot:Dictionary=slots[index]
	# Keep contents stable until the chest is consumed.
	if not slot.has("sword"):slot.sword=draw_sword()
	var previous:Array=game.settings.chest_swords
	var previous_upgrades:Dictionary=game.settings.sword_upgrades
	var duplicate:bool=slot.sword in previous
	if duplicate:
		game.settings.sword_upgrades=previous_upgrades.duplicate()
		game.settings.sword_upgrades[slot.sword]=int(previous_upgrades.get(slot.sword,0))+1
	else:
		game.settings.chest_swords=Gear.sanitized_swords(previous+[slot.sword])
	if game.save_settings()!=OK:
		game.settings.chest_swords=previous;game.settings.sword_upgrades=previous_upgrades
		game.toast("Could not save sword. Open this chest again to retry.")
		return true
	if duplicate:Gear.apply(game.player)
	var item:Dictionary=Gear.item_data(slot.sword,game.settings)
	food_icon.texture=item.icon
	food_text.text=item.name+(" · Upgraded · ATK +%d"%roundi(item.effects.attack) if duplicate else " · Added to Equipment")
	receipt_left=4.0;receipt.show();pickup_feedback()
	if not slot.key.is_empty():opened_chests[slot.key]=true
	slot.active=false;_sync_batches();return true

func draw_sword()->String:
	if sword_bag.is_empty():
		sword_bag=Gear.CHEST_SWORDS.duplicate()
		for i in range(sword_bag.size()-1,0,-1):
			var other=rng.randi_range(0,i)
			var id=sword_bag[i];sword_bag[i]=sword_bag[other];sword_bag[other]=id
	return sword_bag.pop_back()

func sync_buffs():
	var any_active=false;var layout_changed=false
	for kind in range(3,FOODS.size()):
		var permanent=kind==OYAKODON
		var left:float=0.0 if permanent else game.player.food_buffs[BUFFS[kind]]
		var stacks:int=game.model.team_progression.skill_food_stacks if permanent else game.player.food_buff_stacks[BUFFS[kind]]
		var tile=buff_tiles[kind-3];var active=(permanent or left>0) and stacks>0
		layout_changed=layout_changed or tile.visible!=active;tile.visible=active
		if not tile.visible:continue
		any_active=true
		var seconds=ceili(left)
		buff_counts[kind-3].text="×%d"%stacks if stacks>1 else ""
		var width=maxf(72,37+buff_counts[kind-3].get_combined_minimum_size().x)
		layout_changed=layout_changed or tile.custom_minimum_size.x!=width;tile.custom_minimum_size.x=width
		if permanent:tile.tooltip_text="親子丼 ×%d\nSkill size & hit radius +%d%%\nRest of run"%[stacks,roundi(game.model.team_progression.SKILL_FOOD_STEP*100*stacks)]
		else:tile.tooltip_text="%s ×%d\n%s +%d%s\n%d:%02d remaining"%[FOOD_NAMES[kind],stacks,{3:"Damage",4:"Max HP",5:"Attack speed",6:"Movement speed",7:"Defense"}[kind],stacks*(20 if kind>=5 else 30),"" if kind==7 else "%",seconds/60,seconds%60]
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
		if not slot.active or slot.chest:continue
		slot.left-=delta
		if slot.left<=0:slot.active=false;changed=true
		elif nearby(slot,MAGNET_DISTANCE):
			slot.pos=slot.pos.move_toward(game.player.position,MAGNET_SPEED*delta);changed=true
			if slot.pos.distance_squared_to(game.player.position)<=PICKUP_DISTANCE*PICKUP_DISTANCE and eat(slot.kind,false):
				slot.active=false;ate=true
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

extends "res://scripts/forest/core_balance_ui.gd"
const EnemyBalance=preload("res://scripts/forest/enemy_balance.gd")
var enemy_type=0
func _ready():
 if enemy_type not in Balance.TYPES:enemy_type=Balance.TYPES[0]
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 game.label_at(self,"ENEMY BALANCE",Vector2(64,56),38)
 game.label_at(self,"AI enemies save separately from playable fighters. Changes apply from the next wave.",Vector2(67,110),18,Color("dfc384"))
 game.label_at(self,"Editing",Vector2(67,176),20)
 var picker=OptionButton.new();picker.name="BalanceEnemy";picker.position=Vector2(168,160);picker.size=Vector2(340,52)
 for i in Balance.TYPES.size():picker.add_item(Balance.ENEMIES[i],Balance.TYPES[i])
 picker.select(picker.get_item_index(enemy_type));add_child(picker)
 picker.item_selected.connect(func(index):game.show_enemy_balance(from_pause,picker.get_item_id(index)))
 var individual=column(Vector2(64,245),Vector2(620,480),"HEALTH, COMBAT & MOVEMENT")
 var stats=EnemyBalance.base_stats(game.core_balance,enemy_type)
 for row in EnemyBalance.ROWS:
  var spin=number_row(individual,row[1],"Enemy_"+row[0],row[2],row[3],row[4],stats[row[0]],true)
  spin.value_changed.connect(func(value):game.update_enemy_tuning(enemy_type,row[0],value))
 var note=Label.new();note.text="Base values before shared enemy multipliers.\nDamage scales this enemy's existing attacks and skills.\nJump, flight and attack patterns keep their native rules.";note.add_theme_font_size_override("font_size",17);individual.add_child(note)
 var shared=column(Vector2(747,245),Vector2(620,480),"SHARED ENEMY MULTIPLIERS")
 for row in Balance.ROWS:
  if not row[0].begins_with("enemy_"):continue
  var spin=number_row(shared,row[1],"Enemy_"+row[0],row[2],row[3],row[4],game.core_balance[row[0]],true)
  spin.value_changed.connect(func(value):game.update_core_balance(row[0],value))
 var hint=Label.new();hint.text="Health × excludes Skullpion. Size × uses existing\nrigid enemy scaling. Movement and damage × include all.\nWave counts and economy are in Core Game Balance.";hint.add_theme_font_size_override("font_size",17);shared.add_child(hint)
 var waves=Button.new();waves.text="Wave counts & core balance";waves.name="EnemyWaveBalance";waves.custom_minimum_size.y=44;shared.add_child(waves)
 waves.pressed.connect(func():game.show_core_balance(from_pause))
 game.label_at(self,"Saved automatically. Reset restores this enemy's baseline; shared multipliers stay as set.",Vector2(67,763),17,Color("dfc384"))
 game.button_at(self,"Back to Settings",Vector2(64,808),func():game.show_settings(from_pause),300).name="EnemyBalanceBack"
 game.button_at(self,"Reset "+Balance.ENEMIES[Balance.TYPES.find(enemy_type)]+" balance",Vector2(746,808),func():game.reset_enemy_tuning(enemy_type);game.show_enemy_balance(from_pause,enemy_type),620).name="EnemyBalanceReset"

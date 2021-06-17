extends Control

enum Medal { Gold, Silver, Bronze }

onready var drawing_grid = $VBoxContainer/HBoxContainer/DrawingGrid
onready var submit_button = $VBoxContainer/ButtonCenter/SubmitButton
onready var gold = $VBoxContainer/HBoxContainer/MedalsCenter/MedalsVBox/Gold
onready var silver = $VBoxContainer/HBoxContainer/MedalsCenter/MedalsVBox/Silver
onready var bronze = $VBoxContainer/HBoxContainer/MedalsCenter/MedalsVBox/Bronze
var dragging = false
var drag_node
var drag_reset_pos
var drag_offset
var drag_medal
var gold_id
var silver_id
var bronze_id
var is_ready = false

func _ready():
	for drawing in Global.drawings:
		var drawing_picker = load(Global.drawing_picker_scene).instance()
		drawing_picker.player_id = drawing['id']
		drawing_picker.texture = drawing['texture']
		drawing_grid.add_child(drawing_picker)
	
	submit_button.hide()
	if Global.players[Global.prompter_index]['client_id'] != get_tree().get_network_unique_id():
		set_process_input(false)
	
	is_ready = true

func _process(delta):
	var medals_assigned = 0
	if gold_id != null:
		medals_assigned += 1
	if silver_id != null:
		medals_assigned += 1
	if bronze_id != null:
		medals_assigned += 1
	var medals_needed = min(len(Global.drawings), 3)
	
	var prompter_id = Global.players[Global.prompter_index]['client_id']
	if medals_assigned >= medals_needed && prompter_id == get_tree().get_network_unique_id():
		submit_button.show()
	else:
		submit_button.hide()
	
	# Remove all references to id if they have been removed
	if Network.update_grade_id > 0:
		drawing_grid.remove_child(get_drawing_picker_by_id(Network.update_grade_id))
		if gold_id == Network.update_grade_id:
			gold_id = null
		if silver_id == Network.update_grade_id:
			silver_id = null
		if bronze_id == Network.update_grade_id:
			bronze_id = null
		Network.update_grade_id = 0
	
	# Randomize drawing picker order once the seed comes in
	if Network.update_grade_order == true && is_ready:
		for i in range(len(Global.drawing_order)):
			var picker = get_drawing_picker_by_id(Global.drawing_order[i])
			drawing_grid.move_child(picker, i)
		Network.update_grade_order = false

func _input(event):
	if(event.is_class("InputEventMouse")):
		var pos = event.position
		if dragging:
			if event.button_mask & BUTTON_MASK_LEFT == BUTTON_MASK_LEFT:
				drag_node.rect_global_position = pos + drag_offset
				rpc('set_medal_pos', drag_medal, pos + drag_offset)
			else:
				# Reset medal position
				drag_node.rect_global_position = drag_reset_pos
				rpc('set_medal_pos', drag_medal, drag_reset_pos)
				dragging = false
				for drawing_picker in Global.get_children_in_group(self, "drawing_picker"):
					if drawing_picker.pos_within(pos):
						if drag_medal == Medal.Gold:
							rpc('set_gold_id', drawing_picker.player_id)
						elif drag_medal == Medal.Silver:
							rpc('set_silver_id', drawing_picker.player_id)
						elif drag_medal == Medal.Bronze:
							rpc('set_bronze_id', drawing_picker.player_id)
		
		else:
			if event.button_mask & BUTTON_MASK_LEFT == BUTTON_MASK_LEFT:
				var gold_top_left = gold.rect_global_position
				var silver_top_left = silver.rect_global_position
				var bronze_top_left = bronze.rect_global_position
				var gold_bot_right = gold.rect_global_position + gold.rect_size
				var silver_bot_right = silver.rect_global_position + silver.rect_size
				var bronze_bot_right = bronze.rect_global_position + bronze.rect_size
				# Check if mouse is in Gold
				if pos.x >= gold_top_left.x && pos.y >= gold_top_left.y && pos.x < gold_bot_right.x && pos.y < gold_bot_right.y:
					dragging = true
					drag_node = gold
					drag_reset_pos = gold.rect_global_position
					drag_offset = gold.rect_global_position - pos
					drag_medal = Medal.Gold
				# Check if mouse is in Silver
				if pos.x >= silver_top_left.x && pos.y >= silver_top_left.y && pos.x < silver_bot_right.x && pos.y < silver_bot_right.y:
					dragging = true
					drag_node = silver
					drag_reset_pos = silver.rect_global_position
					drag_offset = silver.rect_global_position - pos
					drag_medal = Medal.Silver
				# Check if mouse is in Bronze
				if pos.x >= bronze_top_left.x && pos.y >= bronze_top_left.y && pos.x < bronze_bot_right.x && pos.y < bronze_bot_right.y:
					dragging = true
					drag_node = bronze
					drag_reset_pos = bronze.rect_global_position
					drag_offset = bronze.rect_global_position - pos
					drag_medal = Medal.Bronze

sync func set_gold_id(id):
	reset_ids(id)
	var gold_picker = get_drawing_picker_by_id(gold_id)
	if gold_picker != null:
		gold_picker.hide_medals()
	gold_id = id
	get_drawing_picker_by_id(id).show_gold()

sync func set_silver_id(id):
	reset_ids(id)
	var silver_picker = get_drawing_picker_by_id(silver_id)
	if silver_picker != null:
		silver_picker.hide_medals()
	silver_id = id
	get_drawing_picker_by_id(id).show_silver()

sync func set_bronze_id(id):
	reset_ids(id)
	var bronze_picker = get_drawing_picker_by_id(bronze_id)
	if bronze_picker != null:
		bronze_picker.hide_medals()
	bronze_id = id
	get_drawing_picker_by_id(id).show_bronze()

func reset_ids(id):
	if gold_id == id:
		gold_id = null
	if silver_id == id:
		silver_id = null
	if bronze_id == id:
		bronze_id = null

func get_drawing_picker_by_id(id):
	for drawing_picker in Global.get_children_in_group(self, "drawing_picker"):
		if drawing_picker.player_id == id:
			return drawing_picker
	return null

remote func set_medal_pos(medal, pos):
	if medal == Medal.Gold:
		gold.rect_global_position = pos
	elif medal == Medal.Silver:
		silver.rect_global_position = pos
	elif medal == Medal.Bronze:
		bronze.rect_global_position = pos

func submit_grade():
	Network.grade(gold_id, silver_id, bronze_id)

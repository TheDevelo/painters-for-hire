extends Control

const player_bg_color1 = Color("#bad5ed")
const player_bg_color2 = Color("#94c0dd")
const round_label_format = "Round #{round}"
const left_lobby_label_format = "{lobby} (Locked:"

onready var round_label = $VBoxContainer/HeaderCenter/HeaderMargin/VBoxContainer/RoundLabel
onready var left_lobby_label = $VBoxContainer/HeaderCenter/HeaderMargin/VBoxContainer/LobbyHBox/LeftLabel
onready var sidebar_vbox = $VBoxContainer
onready var locked_checkbox = $VBoxContainer/HeaderCenter/HeaderMargin/VBoxContainer/LobbyHBox/CheckBox

func _ready():
	round_label.set_text(round_label_format.format({'round': Global.round_num}))
	left_lobby_label.set_text(left_lobby_label_format.format({'lobby': Global.lobby}))
	locked_checkbox.pressed = Global.locked
	if get_tree().get_network_unique_id() == Network.host_id:
		locked_checkbox.disabled = false
	update_players(Global.players)

func update_players(player_dict):
	# Clear all current entries
	for entry in Global.get_children_in_group(self, "sidebar_player"):
		sidebar_vbox.remove_child(entry)
	
	player_dict.sort_custom(Global, "player_rank_comp")
	var player_rank = {}
	for i in range(len(player_dict)):
		player_rank[player_dict[i]['client_id']] = i + 1
	
	var bg_alternated = false
	player_dict.sort_custom(Global, "player_id_comp")
	for i in range(len(player_dict)):
		var player = player_dict[i]
		var player_entry = load(Global.sidebar_player_scene).instance()
		player_entry.set_player_name(player['name'])
		player_entry.set_points(player['points'])
		player_entry.set_rank(player_rank[player['client_id']])
		if bg_alternated == true:
			player_entry.set_bg_color(player_bg_color2)
		else:
			player_entry.set_bg_color(player_bg_color1)
		bg_alternated = !bg_alternated
		sidebar_vbox.add_child(player_entry)

func locked_option_changed(pressed):
	Network.submit_lobby_lock(pressed)

sync func update_lock_checkbox(pressed):
	locked_checkbox.pressed = pressed

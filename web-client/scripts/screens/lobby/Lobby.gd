extends Control

const lobby_title_format = "{host}'s Lobby\nLobby ID: {id}"

onready var title_label = $CenterContainer/VBoxContainer/TitleCenter/LobbyTitle
onready var lobby_vbox = $CenterContainer/VBoxContainer
onready var button_hbox = $CenterContainer/VBoxContainer/ButtonCenter/ButtonMargin/ButtonHBox
onready var start_button = $CenterContainer/VBoxContainer/ButtonCenter/ButtonMargin/ButtonHBox/Start
onready var rounds_line_edit = $CenterContainer/VBoxContainer/RoundsHSplit/LineEdit
onready var draw_time_line_edit = $CenterContainer/VBoxContainer/DrawTimeHSplit/LineEdit
onready var locked_checkbox = $CenterContainer/VBoxContainer/LockedHSplit/CheckBox
var player_num = 0
var digits_regex = RegEx.new()
var rounds_old_text
var draw_time_old_text

func _ready():
	update_players()
	title_label.set_text(lobby_title_format.format({
		"host": Global.get_player_by_id(Network.host_id)['name'], 
		"id": Global.lobby
	}))
	start_button.hide()
	rounds_line_edit.text = String(Global.max_rounds)
	draw_time_line_edit.text = String(Global.draw_time)
	rounds_old_text = rounds_line_edit.text
	draw_time_old_text = draw_time_line_edit.text
	digits_regex.compile("^[0-9]*$")
	if get_tree().get_network_unique_id() == Network.host_id:
		show_host_controls()

func _process(delta):
	if Network.update_lobby_players == true:
		update_players()
		title_label.set_text(lobby_title_format.format({
			"host": Global.get_player_by_id(Network.host_id)['name'], 
			"id": Global.lobby
		}))
		if get_tree().get_network_unique_id() == Network.host_id:
			show_host_controls()
		Network.update_lobby_players = false
	
	if Network.update_lobby_lock == true:
		locked_checkbox.pressed = Global.locked
		Network.update_lobby_lock = false

func show_host_controls():
	rounds_line_edit.editable = true
	draw_time_line_edit.editable = true
	locked_checkbox.disabled = false
	if len(Global.players) >= 3:
		start_button.show()

func update_players():
	for player_center in Global.get_children_in_group(self, "lobby_player"):
		lobby_vbox.remove_child(player_center)
	player_num = 0
	for player in Global.players:
		var lobby_player = load(Global.lobby_player_scene).instance()
		lobby_player.get_node("PlayerName").set_text(player['name'])
		lobby_vbox.add_child_below_node(lobby_vbox.get_child(player_num+1), lobby_player)
		player_num += 1

func _on_Leave_pressed():
	Global.reset_globals()
	Signaling.quit()
	Global.change_scene(Global.Scenes.MainMenu)

func start_game():
	Network.start_game()

func rounds_option_changed(new_text):
	if digits_regex.search(new_text) == null:
		var cursor_pos = rounds_line_edit.caret_position - 1
		rounds_line_edit.text = rounds_old_text
		rounds_line_edit.caret_position = cursor_pos
	else:
		Global.max_rounds = int(new_text)
		rpc('update_rounds', new_text)
		rounds_old_text = new_text

remote func update_rounds(text):
	Global.max_rounds = int(text)
	rounds_line_edit.text = text

func draw_time_option_changed(new_text):
	if digits_regex.search(new_text) == null:
		var cursor_pos = draw_time_line_edit.caret_position - 1
		draw_time_line_edit.text = draw_time_old_text
		draw_time_line_edit.caret_position = cursor_pos
	else:
		Global.draw_time = int(new_text)
		rpc('update_draw_time', new_text)
		draw_time_old_text = new_text

remote func update_draw_time(text):
	Global.draw_time = int(text)
	draw_time_line_edit.text = text


func locked_option_changed(pressed):
	Network.submit_lobby_lock(pressed)

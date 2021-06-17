extends Control

onready var wait_message = $CenterContainer/VBoxContainer/WaitingMessage
onready var message_vbox = $CenterContainer/VBoxContainer
# Just have it initialized to 1 so that it doesn't immediately send me to Grade
var players_waiting_for = 1
var first_players_waiting_for

func _ready():
	update_player_list()

func _process(delta):
	if players_waiting_for == 0:
		Global.change_scene(Global.Scenes.Grade)
		if Global.players[Global.prompter_index]['client_id'] != get_tree().get_network_unique_id():
			randomize()
			Global.drawings.shuffle()
			var order = []
			for drawing in Global.drawings:
				order.append(drawing['id'])
			Network.submit_drawing_order(order)
		if first_players_waiting_for == 0:
			self.hide()
		# Set players_waiting_for to 1 since _process still runs during the scene change
		players_waiting_for = 1
	if Network.update_draw_wait == true:
		update_player_list()
		Network.update_draw_wait = false

func update_player_list():
	players_waiting_for = 0
	for player_label in Global.get_children_in_group(self, "lobby_player"):
		message_vbox.remove_child(player_label)
	
	var drawn_ids = [Global.players[Global.prompter_index]['client_id']]
	for drawing in Global.drawings:
		drawn_ids.append(drawing['id'])
	
	for player in Global.players:
		if !drawn_ids.has(player['client_id']):
			players_waiting_for += 1
			var player_label = load(Global.lobby_player_scene).instance()
			player_label.get_node("PlayerName").set_text(player['name'])
			message_vbox.add_child_below_node(wait_message, player_label)
	
	if first_players_waiting_for == null:
		first_players_waiting_for = players_waiting_for

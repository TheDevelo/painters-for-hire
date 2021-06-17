extends Control

onready var sidebar = $Sidebar
onready var ranks_hbox = $CenterContainer/VBoxContainer/RanksCenter/RanksHBox
onready var gold_vbox = $CenterContainer/VBoxContainer/RanksCenter/RanksHBox/GoldVBox
onready var gold_name = $CenterContainer/VBoxContainer/RanksCenter/RanksHBox/GoldVBox/Name
onready var silver_vbox = $CenterContainer/VBoxContainer/RanksCenter/RanksHBox/SilverVBox
onready var silver_name = $CenterContainer/VBoxContainer/RanksCenter/RanksHBox/SilverVBox/Name
onready var bronze_vbox = $CenterContainer/VBoxContainer/RanksCenter/RanksHBox/BronzeVBox
onready var bronze_name = $CenterContainer/VBoxContainer/RanksCenter/RanksHBox/BronzeVBox/Name
onready var restart_button = $CenterContainer/VBoxContainer/ButtonCenter/ButtonMargin/ButtonHBox/RestartButton

func _ready():
	sidebar.set_header("Final Standings")
	
	if get_tree().get_network_unique_id() != Network.host_id:
		restart_button.hide()
	
	Global.players.sort_custom(Global, "player_rank_comp")
	if len(Global.players) >= 1:
		gold_name.set_text(Global.players[0]['name'])
	else:
		ranks_hbox.remove_child(gold_vbox)
	if len(Global.players) >= 2:
		silver_name.set_text(Global.players[1]['name'])
	else:
		ranks_hbox.remove_child(silver_vbox)
	if len(Global.players) >= 3:
		bronze_name.set_text(Global.players[2]['name'])
	else:
		ranks_hbox.remove_child(bronze_vbox)

func _on_LeaveButton_pressed():
	Global.reset_globals()
	Signaling.quit()
	Global.change_scene(Global.Scenes.MainMenu)

func restart_game():
	Network.start_game()

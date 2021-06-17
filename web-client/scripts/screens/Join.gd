extends Control

onready var name_textbox = $CenterContainer/VBoxContainer/NameHSplit/LineEdit
onready var lobby_textbox = $CenterContainer/VBoxContainer/LobbyHSplit/LineEdit
onready var button_hsplit = $CenterContainer/VBoxContainer/ButtonMargin/ButtonHSplit
onready var cancel_button = $CenterContainer/VBoxContainer/ButtonMargin/ButtonHSplit/CancelButton
onready var join_button = $CenterContainer/VBoxContainer/ButtonMargin/ButtonHSplit/JoinButton

func _ready():
	button_hsplit.split_offset = (join_button.rect_size.x - cancel_button.rect_size.x) / 2
	if OS.get_name() == 'HTML5':
		var data = JavaScript.eval("getLobby()")
		if typeof(data) == TYPE_STRING:
			lobby_textbox.text = data

func join_lobby():
	Signaling.join_lobby(name_textbox.text, lobby_textbox.text)

func _on_CancelButton_pressed():
	if OS.get_name() == 'HTML5':
		var data = JavaScript.eval("updateLobby('')")
	Global.change_scene(Global.Scenes.MainMenu)

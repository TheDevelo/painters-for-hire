extends Control

onready var settings_line_edit = $CenterContainer/VBoxContainer/SignalingCenter/SignalingHBox/LineEdit

func _ready():
	settings_line_edit.text = Signaling.signaling_server_url

func cancel_pressed():
	Global.change_scene(Global.Scenes.MainMenu)

func save_pressed():
	Signaling.signaling_server_url = settings_line_edit.text
	Global.change_scene(Global.Scenes.MainMenu)

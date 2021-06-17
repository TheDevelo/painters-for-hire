extends Control

onready var name_textbox = $CenterContainer/VBoxContainer/NameHSplit/LineEdit
onready var button_hsplit = $CenterContainer/VBoxContainer/ButtonMargin/ButtonHSplit
onready var cancel_button = $CenterContainer/VBoxContainer/ButtonMargin/ButtonHSplit/CancelButton
onready var host_button = $CenterContainer/VBoxContainer/ButtonMargin/ButtonHSplit/HostButton

func _ready():
	button_hsplit.split_offset = (host_button.rect_size.x - cancel_button.rect_size.x) / 2

func host_lobby():
	Signaling.host_lobby(name_textbox.text)

func _on_CancelButton_pressed():
	Global.change_scene(Global.Scenes.MainMenu)

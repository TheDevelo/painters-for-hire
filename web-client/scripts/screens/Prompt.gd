extends Control

onready var input_textarea = $CenterContainer/MarginContainer/VBoxContainer/LineEdit

func _on_Button_pressed():
	Network.submit_prompt(input_textarea.text)

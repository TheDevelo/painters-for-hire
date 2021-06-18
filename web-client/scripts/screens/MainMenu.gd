extends Control

func _ready():
	if OS.get_name() == 'HTML5':
		var data = JavaScript.eval("window.parent.getLobby()")
		if typeof(data) == TYPE_STRING:
			get_tree().change_scene(Global.join_scene) 

func _on_HostButton_pressed():
	Global.change_scene(Global.Scenes.Host)

func _on_JoinButton_pressed():
	Global.change_scene(Global.Scenes.Join)


func _on_SettingsButton_pressed():
	Global.change_scene(Global.Scenes.Settings)

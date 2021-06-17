extends Control

const wait_message_format = "Waiting for {name} to submit their prompt..."

onready var waiting_message = $CenterContainer/WaitingMessage

func _ready():
	waiting_message.set_text(wait_message_format.format({'name': Global.players[Global.prompter_index]['name']}))

tool
extends Control

export(int) var palette_index setget _update_color 
var drawable_canvas
var is_ready = false
onready var color_rect = $ColorRect

# Use a copy of Global.palette in tool mode because AutoLoads can't be used in tool mode???
var palette_copy = [Color("#ffffff"), Color("#000000"),
                    Color("#c2c3c7"), Color("#5f574f"),
                    Color("#ff77a8"), Color("#ff004d"),
                    Color("#ffa300"), Color("#ffec27"),
                    Color("#00e436"), Color("#008751"),
                    Color("#29adff"), Color("#1d2b53"),
                    Color("#83769c"), Color("#442255"),
                    Color("#ffccaa"), Color("#ab5236")]

func _ready():
	is_ready = true
	if Engine.is_editor_hint():
		color_rect.color = palette_copy[palette_index]
	else:
		color_rect.color = Global.palette[palette_index]

# Use _input instead of _gui_input because _gui_input doesn't work for some reason???
func _input(event):
	if(event.is_class("InputEventMouseButton")) && !Engine.is_editor_hint():
		var pos = event.get_position() - rect_global_position
		if pos.x < 0 || pos.y < 0 || pos.x >= 70 || pos.y >= 70:
			return
		if event.button_index == BUTTON_LEFT && event.pressed:
			drawable_canvas.fg_color = Global.palette[palette_index]
		elif event.button_index == BUTTON_RIGHT && event.pressed:
			drawable_canvas.bg_color = Global.palette[palette_index]

func _update_color(new_palette_index):
	palette_index = new_palette_index
	if is_ready:
		color_rect.color = palette_copy[palette_index]

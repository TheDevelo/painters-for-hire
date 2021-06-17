extends Control

onready var prompt_label = $HBoxContainer/CanvasCenter/VBoxContainer/Prompt
onready var drawable_canvas = $HBoxContainer/CanvasCenter/VBoxContainer/DrawableCanvas
onready var timer_label = $HBoxContainer/TimerMargin/ColorRect/TimerLabel
onready var timer = $Timer
onready var canvas_cursor = $CanvasCursor

func _ready():
	prompt_label.set_text(Global.prompt)
	timer.wait_time = Global.draw_time
	timer.start()
	for color_picker in Global.get_children_in_group(self, "color_picker"):
		color_picker.drawable_canvas = drawable_canvas
	canvas_cursor.drawable_canvas = drawable_canvas

func _process(delta):
	timer_label.set_text(String(ceil(timer.time_left)))

func submit_drawing():
	# Use a downsample factor of 3 to keep sending drawings speedy
	Network.submit_drawing(null,
	                       get_tree().get_network_unique_id(), 
	                       Global.get_data_from_image(drawable_canvas.image, drawable_canvas.image_size, 3),
	                       drawable_canvas.image_size / 3,
	                       drawable_canvas.image_format)
	Global.change_scene(Global.Scenes.DrawWait)

func clear_canvas():
	drawable_canvas.clear()

extends Node2D

const circle_color = Color(0.5, 0.5, 0.5, 0.5)

var radius = 7.1
var drawable_canvas

func _process(delta):
	position = get_viewport().get_mouse_position()
	if radius != drawable_canvas.brush_size + 0.1:
		radius = drawable_canvas.brush_size + 0.1
		update()

func _draw():
	draw_circle(Vector2(0, 0), radius, circle_color)
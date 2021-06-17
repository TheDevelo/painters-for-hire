extends Control

const image_size = Vector2(600, 600)
const image_format = Image.FORMAT_RGB8
const max_brush_size = 51
const min_brush_size = 3
const brush_step_size = 2

var image
var image_texture
var brush_size = 7
var fg_color = Global.palette[1]
var bg_color = Global.palette[0]
var prev_pos

func _ready():
	image = Image.new()
	image.create(image_size.x, image_size.y, false, image_format)
	image.fill(bg_color)
	image_texture = ImageTexture.new()
	image_texture.create(image_size.x,image_size.y, image_format, 0)    
	image_texture.set_data(image)
	$TextureRect.set_texture(image_texture)

func _input(event):
	if(event.is_class("InputEventMouse")):
		var pos = event.get_position() - rect_global_position
		var color = fg_color
		var reset_prev_pos = false
		var draw = false
		if event.get_button_mask() & BUTTON_MASK_LEFT == BUTTON_MASK_LEFT:
			color = fg_color
			draw = true
		elif event.get_button_mask() & BUTTON_MASK_RIGHT == BUTTON_MASK_RIGHT:
			color = bg_color
			draw = true
		elif event.get_button_mask() & BUTTON_MASK_MIDDLE == BUTTON_MASK_MIDDLE && !out_of_bounds(pos, -0.5):
			flood_fill(pos, fg_color)
			draw = false
			reset_prev_pos = true
		else:
			draw = false
			reset_prev_pos = true
		if (prev_pos == null || prev_pos == pos) && draw:
			if !out_of_bounds(pos, brush_size):
				draw_circle_image(pos, color, brush_size)
		elif draw:
			draw_capsule_image(pos, prev_pos, color, brush_size)
		image_texture.set_data(image)
		if reset_prev_pos == true:
			prev_pos = null
		else:
			prev_pos = pos
	if(event.is_class("InputEventMouseButton")):
		if event.button_index == BUTTON_WHEEL_UP:
			brush_size = min(max_brush_size, brush_size + brush_step_size)
		elif event.button_index == BUTTON_WHEEL_DOWN:
			brush_size = max(min_brush_size, brush_size - brush_step_size)

func draw_circle_image(point, color, brush_size):
	image.lock()
	var diameter = 2 * brush_size + 1
	for x in range(diameter):
		for y in range(diameter):
			var adj_x = x - brush_size
			var adj_y = y - brush_size
			if sqrt(adj_x*adj_x + adj_y*adj_y) <= brush_size + 0.1 && !out_of_bounds(Vector2(point.x + adj_x, point.y + adj_y), -0.5):
				image.set_pixel(point.x + adj_x, point.y + adj_y, color)

func draw_capsule_image(point1, point2, color, brush_size):
	image.lock()
	# Draw circles at point1 and point2
	if !out_of_bounds(point1, brush_size):
		draw_circle_image(point1, color, brush_size)
	if !out_of_bounds(point2, brush_size):
		draw_circle_image(point2, color, brush_size)
	
	if out_of_bounds(point1, brush_size) && out_of_bounds(point2, brush_size):
		return
	
	# Draw a line with width brush_size from point1 to point2
	var x_len = abs(point2.x - point1.x) + 2 * brush_size
	var y_len = abs(point2.y - point1.y) + 2 * brush_size
	var min_x = min(point1.x, point2.x) - brush_size
	var min_y = min(point1.y, point2.y) - brush_size
	for x in range(x_len):
		for y in range(y_len):
			# Calculate distance of point using https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
			# Also make sure point lies between perpendiculars of line at point1 and point2
			var a = point2.y - point1.y
			var b = point2.x - point1.x
			var c = point2.x * point1.y - point2.y * point1.x
			var adj_x = min_x + x
			var adj_y = min_y + y
			var dist = abs(a*adj_x - b*adj_y + c) / sqrt(a*a + b*b)
			var point1_side
			var point2_side
			if a == 0:
				point1_side = adj_x < point1.x
				point2_side = adj_x < point2.x
			else:
				point1_side = adj_y - point1.y < -b/a * (adj_x - point1.x)
				point2_side = adj_y - point2.y < -b/a * (adj_x - point2.x)
			if dist <= brush_size + 0.1 && point1_side != point2_side && !out_of_bounds(Vector2(adj_x, adj_y), -0.5):
				image.set_pixel(adj_x, adj_y, color)

func flood_fill(initial_pos, replacement_color):
	image.lock()
	var initial_color = image.get_pixel(initial_pos.x, initial_pos.y)
	if initial_color == replacement_color:
		return
	var queue = [initial_pos]
	var visited = []
	visited.resize(image_size.x * image_size.y)
	while len(queue) > 0:
		var pos = queue.pop_front()
		var visited_index = pos.x * image_size.y + pos.y
		if image.get_pixel(pos.x, pos.y) == initial_color:
			image.set_pixel(pos.x, pos.y, replacement_color)
			visited[visited_index] = true
			var adj_pos
			var adj_visited_index
			# North
			adj_pos = pos + Vector2(0, -1)
			adj_visited_index = adj_pos.x * image_size.y + adj_pos.y
			if !out_of_bounds(adj_pos, -0.5) && visited[adj_visited_index] != true:
				queue.append(adj_pos)
			# South
			adj_pos = pos + Vector2(0, 1)
			adj_visited_index = adj_pos.x * image_size.y + adj_pos.y
			if !out_of_bounds(adj_pos, -0.5) && visited[adj_visited_index] != true:
				queue.append(adj_pos)
			# East
			adj_pos = pos + Vector2(1, 0)
			adj_visited_index = adj_pos.x * image_size.y + adj_pos.y
			if !out_of_bounds(adj_pos, -0.5) && visited[adj_visited_index] != true:
				queue.append(adj_pos)
			# West
			adj_pos = pos + Vector2(-1, 0)
			adj_visited_index = adj_pos.x * image_size.y + adj_pos.y
			if !out_of_bounds(adj_pos, -0.5) && visited[adj_visited_index] != true:
				queue.append(adj_pos)

# Checks if a brush of size brush_size centered at pos is fully out of bounds
# Note: using brush_size of -0.5 just checks if pos itself is out of bounds
func out_of_bounds(pos, brush_size):
	var diameter = 2 * brush_size + 1
	return pos.x < -diameter || pos.y < -diameter || pos.x >= image_size.x + diameter || pos.y >= image_size.y + diameter

func clear():
	image.fill(bg_color)
	image_texture.set_data(image)

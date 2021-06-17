extends MarginContainer

const drawing_size = Vector2(200, 200)

onready var drawing = $Drawing
onready var gold = $Gold
onready var silver = $Silver
onready var bronze = $Bronze
var player_id
var texture

func _ready():
	drawing.set_texture(texture)
	drawing.stretch_mode = TextureRect.STRETCH_SCALE
	drawing.expand = true
	drawing.rect_size = drawing_size
	hide_medals()

func pos_within(pos):
	var top_left = drawing.rect_global_position
	var bot_right = drawing.rect_global_position + drawing.rect_size
	return pos.x >= top_left.x && pos.y >= top_left.y && pos.x < bot_right.x && pos.y < bot_right.y

func show_gold():
	hide_medals()
	gold.show()

func show_silver():
	hide_medals()
	silver.show()

func show_bronze():
	hide_medals()
	bronze.show()

func hide_medals():
	gold.hide()
	silver.hide()
	bronze.hide()
extends MarginContainer

const rank_format = "#{rank}"
const points_format = "{points} Points"

onready var background_node = $Background
onready var player_name_node = $CenterContainer/MarginContainer/VBoxContainer/PlayerName
onready var rank_node = $CenterContainer/MarginContainer/VBoxContainer/CenterContainer/HSplitContainer/Rank
onready var points_node = $CenterContainer/MarginContainer/VBoxContainer/CenterContainer/HSplitContainer/Points
var bg_color = Color("#dddddd")
var player_name = "Placeholder"
var rank = 10
var points = 1520
var is_ready = false

func _ready():
	is_ready = true
	set_bg_color(bg_color)
	set_player_name(player_name)
	set_rank(rank)
	set_points(points)

func set_bg_color(new_color):
	bg_color = new_color
	if is_ready:
		background_node.color = new_color

func set_player_name(new_name):
	player_name = new_name
	if is_ready:
		player_name_node.set_text(new_name)

func set_rank(new_rank):
	rank = new_rank
	if is_ready:
		rank_node.set_text(rank_format.format({'rank': new_rank}))

func set_points(new_points):
	points = new_points
	if is_ready:
		points_node.set_text(points_format.format({'points': new_points}))

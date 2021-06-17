extends Node

enum Scenes { MainMenu, Settings, Host, Join, Lobby, Prompt, PromptWait, Draw, DrawWait, Grade, GameEnd }

# Scene Consts so that changing the path of a scene is much less work
# Screen scenes (as opposed to instanced partials)
const main_menu_scene = "res://scenes/screens/MainMenu.tscn"
const settings_scene = "res://scenes/screens/Settings.tscn"
const host_scene = "res://scenes/screens/Host.tscn"
const join_scene = "res://scenes/screens/Join.tscn"
const lobby_scene = "res://scenes/screens/lobby/Lobby.tscn"
const prompt_scene = "res://scenes/screens/Prompt.tscn"
const prompt_wait_scene = "res://scenes/screens/PromptWait.tscn"
const draw_scene = "res://scenes/screens/draw/Draw.tscn"
const draw_wait_scene = "res://scenes/screens/DrawWait.tscn"
const grade_scene = "res://scenes/screens/grade/Grade.tscn"
const game_end_scene = "res://scenes/screens/GameEnd.tscn"

# Partial scenes
const background_scene = "res://scenes/ui/Background.tscn"
const sidebar_scene = "res://scenes/ui/Sidebar.tscn"
const sidebar_player_scene = "res://scenes/ui/SidebarPlayer.tscn"
const lobby_player_scene = "res://scenes/screens/lobby/LobbyPlayer.tscn"
const drawable_canvas_scene = "res://scenes/screens/draw/DrawableCanvas.tscn"
const color_picker_scene = "res://scenes/screens/draw/ColorPicker.tscn"
const drawing_picker_scene = "res://scenes/screens/grade/DrawingPicker.tscn"

const scene_trans_time = 0.3
const scene_trans_type = Tween.TRANS_CUBIC
const scene_trans_ease = Tween.EASE_IN_OUT

var current_scene = Scenes.MainMenu

func change_scene(scene_enum):
	var old_scene = get_tree().current_scene
	var new_scene = load(scene_path(scene_enum)).instance()
	get_tree().get_root().add_child(new_scene)
	# Reverse the order of new_scene and old_scene so that it goes on top of statics
	get_tree().get_root().move_child(new_scene, old_scene.get_index())
	get_tree().current_scene = new_scene
	current_scene = scene_enum
	
	# Assuming the tween is called SceneTransitionTween as a child of root
	var old_tween = old_scene.get_node("SceneTransitionTween")
	var new_tween = new_scene.get_node("SceneTransitionTween")
	old_tween.interpolate_property(old_scene, "rect_global_position:y", 0, -720,
								   scene_trans_time, scene_trans_type, scene_trans_ease)
	new_tween.interpolate_property(new_scene, "rect_global_position:y", 720, 0,
								   scene_trans_time, scene_trans_type, scene_trans_ease)
	old_tween.connect("tween_completed", self, "free_scene")
	
	var old_static_names = []
	var new_static_names = []
	var old_statics = get_children_in_group(old_scene, "static")
	var new_statics = get_children_in_group(new_scene, "static")
	
	for new_static in new_statics:
		new_static_names.append(new_static.name)
	
	for old_static in old_statics:
		old_static_names.append(old_static.name)
		if new_static_names.find(old_static.name) != -1:
			old_static.hide()
	
	var moved_new_statics = []
	for new_static in new_statics:
		if old_static_names.find(new_static.name) != -1:
			new_tween.interpolate_property(new_static, "rect_global_position:y", null, new_static.rect_global_position.y,
										   scene_trans_time, scene_trans_type, scene_trans_ease)
			moved_new_statics.append(new_static)
	
	# Set new_scene's y to be 720 so that it doesn't twitch going directly from Draw to Grade
	new_scene.rect_global_position.y = 720
	# Reverse it for the moved new_statics for the exact same reason
	for new_static in moved_new_statics:
		new_static.rect_global_position.y -= 720
	
	old_tween.start()
	new_tween.start()

func scene_path(scene_enum):
	if scene_enum == Scenes.MainMenu:
		return main_menu_scene
	elif scene_enum == Scenes.Settings:
		return settings_scene
	elif scene_enum == Scenes.Host:
		return host_scene
	elif scene_enum == Scenes.Join:
		return join_scene
	elif scene_enum == Scenes.Lobby:
		return lobby_scene
	elif scene_enum == Scenes.Prompt:
		return prompt_scene
	elif scene_enum == Scenes.PromptWait:
		return prompt_wait_scene
	elif scene_enum == Scenes.Draw:
		return draw_scene
	elif scene_enum == Scenes.DrawWait:
		return draw_wait_scene
	elif scene_enum == Scenes.Grade:
		return grade_scene
	elif scene_enum == Scenes.GameEnd:
		return game_end_scene

func get_children_in_group(node, group):
	var children = []
	for child in node.get_children():
		children += get_children_in_group(child, group)
	
	if node.is_in_group(group):
		children.append(node)
	
	return children

func free_scene(scene, key):
	scene.free()

# Players contains dict with entries:
# name: String (Player name, max of 20 characters)
# points: int (Amount of points they have)
# client_id: int (The id assigned to the player)
var players = []

func get_player_by_id(id):
	for player in players:
		if player['client_id'] == id:
			return player

func player_rank_comp(player_a, player_b):
	return player_a['points'] > player_b['points']

func player_id_comp(player_a, player_b):
	return player_a['client_id'] < player_b['client_id']

# Drawings contains dict with entries:
# id: Id of drawer
# texture: ImageTexture of drawing
# image: Image of drawing
# size: Vec2 of size of drawing
# format: Image.Format of image format
var drawings = []

func get_data_from_image(image, image_size, downsample_factor):
	image.lock()
	var array = []
	for x in range(image_size.x / downsample_factor):
		for y in range(image_size.y / downsample_factor):
			array.append(Global.palette_lut[image.get_pixel(x * downsample_factor, y * downsample_factor)])
	return PoolByteArray(array)

func get_drawing_by_id(id):
	for drawing in drawings:
		if drawing['id'] == id:
			return drawing

var palette = [Color("#ffffff"), Color("#000000"),
			   Color("#c2c3c7"), Color("#5f574f"),
			   Color("#ff77a8"), Color("#ff004d"),
			   Color("#ffa300"), Color("#ffec27"),
			   Color("#00e436"), Color("#008751"),
			   Color("#29adff"), Color("#1d2b53"),
			   Color("#83769c"), Color("#442255"),
			   Color("#ffccaa"), Color("#ab5236")]
var palette_lut = {}

var prompt = ""
var prompter_index = 0

var round_num = 1
var max_rounds = 5

var draw_time = 100

var drawing_order = []

var lobby = ""

var locked = false

func _ready():
	# Fill palette_lut so that converting from Color to index is fast
	for i in range(len(palette)):
		palette_lut[palette[i]] = i

func _notification(notification):
	if notification == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		Signaling.quit()
		get_tree().quit()

func reset_globals():
	players = []
	drawings = []
	prompt = ""
	prompter_index = 0
	round_num = 1
	max_rounds = 5
	draw_time = 100
	drawing_order = []
	lobby = ""
	locked = false

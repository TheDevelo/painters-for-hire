extends Node

# Should be 4kb of data in a chunk, do this as WebRTC drops data in large packets
const drawing_chunking_size = 1024

signal player_registered(id)

var update_lobby_players = false
var update_lobby_lock = false
var update_draw_wait = false
var update_grade_id = 0
var update_grade_order = false
var host_id

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

func _player_connected(id):
	rpc_id(id, "send_player_info", Global.get_player_by_id(get_tree().get_network_unique_id()))

func _player_disconnected(id):
	var player = Global.get_player_by_id(id)
	var player_index = Global.players.find(player)
	Global.players.erase(Global.get_player_by_id(id))
	
	var scene_changed = false
	
	if (Global.current_scene == Global.Scenes.Prompt || 
		Global.current_scene == Global.Scenes.PromptWait ||
		Global.current_scene == Global.Scenes.Draw ||
		Global.current_scene == Global.Scenes.DrawWait ||
		Global.current_scene == Global.Scenes.Grade):
		if Global.prompter_index == player_index:
				# Pass prompting duties to another player and head back to prompting stage
				Global.drawings = []
				Global.prompt = ""
				if Global.prompter_index == len(Global.players):
					Global.round_num += 1
					Global.prompter_index = 0
				
				if Global.round_num > Global.max_rounds:
					Global.change_scene(Global.Scenes.GameEnd)
					scene_changed = true
				elif Global.players[Global.prompter_index]['client_id'] == get_tree().get_network_unique_id():
					Global.change_scene(Global.Scenes.Prompt)
					scene_changed = true
				else:
					Global.change_scene(Global.Scenes.PromptWait)
					scene_changed = true
		elif Global.prompter_index > player_index:
			Global.prompter_index -= 1
	
	if (id == Network.host_id):
		Global.players.sort_custom(Global, "player_id_comp")
		Network.host_id = Global.players[0]['client_id']
	
	update_scene(id, false)

func _server_disconnected():
	Global.reset_globals()
	Global.change_scene(Global.Scenes.MainMenu)

# Updates the current scene so that the info about players is correctly displayed
# Added tells whether a player has been added or removed (true is added)
func update_scene(id, added):
	# Update Sidebar if it exists
	for sidebar in get_tree().get_nodes_in_group("sidebar"):
		sidebar.update_players(Global.players)
	
	if Global.current_scene == Global.Scenes.Lobby:
		update_lobby_players = true
	
	if (Global.current_scene == Global.Scenes.Draw || 
		Global.current_scene == Global.Scenes.DrawWait || 
		Global.current_scene == Global.Scenes.Grade) && added == false:
		# Remove drawing from drawing list if it exists
		var removed_drawing
		for drawing in Global.drawings:
			if drawing['id'] == id:
				removed_drawing = drawing
		
		if removed_drawing != null:
			Global.drawings.erase(removed_drawing)
			if Global.current_scene == Global.Scenes.Grade:
				update_grade_id = id
	
	if Global.current_scene == Global.Scenes.DrawWait:
		update_draw_wait = true

remote func send_player_info(player_info):
	var id = player_info['client_id']
	Global.players.append(player_info)
	Global.players.sort_custom(Global, "player_id_comp")
	
	update_scene(id, true)
	if get_tree().get_network_unique_id() == Network.host_id:
		for drawing in Global.drawings:
			submit_drawing(id,
						   drawing['id'],
						   Global.get_data_from_image(drawing['image'], drawing['size'], 1),
						   drawing['size'],
						   drawing['format'])
		rpc_id(id, "send_misc_globals", Global.prompt, Global.prompter_index,
										Global.round_num, Global.max_rounds,
										Global.draw_time, Global.drawing_order,
										Network.host_id)
		rpc_id(id, "enter_game", Global.current_scene)
		
		if Global.players.find(player_info) <= Global.prompter_index:
			rpc("sync_prompter_index", Global.prompter_index + 1)
	
	emit_signal("player_registered", id)

sync func sync_prompter_index(prompter_index):
	Global.prompter_index = prompter_index

# Dont sync lobby as that's something handled by Signaling
# Also don't sync locked as you can't join when it's true, so it's always false
remote func send_misc_globals(prompt, prompter_index, round_num, max_rounds, draw_time, drawing_order, host_id):
	Global.prompt = prompt
	Global.prompter_index = prompter_index
	Global.round_num = round_num
	Global.max_rounds = max_rounds
	Global.draw_time = draw_time
	Global.drawing_order = drawing_order
	Network.host_id = host_id

remote func enter_game(scene):
	# Only do once fully connected, so do check and set up signal in case host was connected before other players
	print(Signaling.fully_connected())
	if !Signaling.fully_connected():
		Signaling.connect("fully_connected", self, "enter_game", [scene])
		return
		
	if Signaling.is_connected("fully_connected", self, "enter_game"):
		Signaling.disconnect("fully_connected", self, "enter_game")
	
	Signaling.reset_prompt()
	
	if scene == Global.Scenes.Lobby:
		Global.change_scene(Global.Scenes.Lobby)
	elif scene == Global.Scenes.Prompt || scene == Global.Scenes.PromptWait:
		Global.change_scene(Global.Scenes.PromptWait)
	elif scene == Global.Scenes.Draw || scene == Global.Scenes.DrawWait:
		Global.change_scene(Global.Scenes.Draw)
	elif scene == Global.Scenes.Grade:
		Global.change_scene(Global.Scenes.Grade)
		update_grade_order = true
	elif scene == Global.Scenes.GameEnd:
		Global.change_scene(Global.Scenes.GameEnd)

func start_game():
	rpc('start_game_rpc')

sync func start_game_rpc():
	Global.players.sort_custom(Global, "player_id_comp")
	Global.drawings = []
	Global.prompt = ""
	Global.prompter_index = 0
	Global.round_num = 1
	Global.drawing_order = []
	for player in Global.players:
		player['points'] = 0
	
	if Global.players[Global.prompter_index]['client_id'] == get_tree().get_network_unique_id():
		Global.change_scene(Global.Scenes.Prompt)
	else:
		Global.change_scene(Global.Scenes.PromptWait)

func submit_prompt(prompt):
	rpc('submit_prompt_rpc', prompt)
	Global.change_scene(Global.Scenes.DrawWait)

remote func submit_prompt_rpc(prompt):
	Global.prompt = prompt
	Global.change_scene(Global.Scenes.Draw)

func submit_drawing(dest_id, creator_id, texture_data, image_size, image_format):
	if dest_id == null:
		rpc('submit_drawing_metadata', creator_id, image_size, image_format)
		
		for chunk_num in range(floor(len(texture_data) / drawing_chunking_size)):
			var chunk = []
#			yield(get_tree().create_timer(0.05), "timeout")
			for i in range(chunk_num * drawing_chunking_size, (chunk_num + 1) * drawing_chunking_size):
				chunk.append(texture_data[i])
			
			rpc('submit_drawing_chunk', creator_id, chunk, chunk_num)
		
		# Send any final data that doesn't fit neatly into the chunk size
		var chunk = []
		for i in range(floor(len(texture_data) / drawing_chunking_size) * drawing_chunking_size, len(texture_data)):
			chunk.append(texture_data[i])
		
		rpc('submit_drawing_chunk', creator_id, chunk, floor(len(texture_data) / drawing_chunking_size))
	else:
		rpc_id(dest_id, 'submit_drawing_metadata', creator_id, image_size, image_format)
		
		for chunk_num in range(floor(len(texture_data) / drawing_chunking_size)):
			var chunk = []
			for i in range(chunk_num * drawing_chunking_size, (chunk_num + 1) * drawing_chunking_size):
				chunk.append(texture_data[i])
			
			rpc_id(dest_id, 'submit_drawing_chunk', creator_id, chunk, chunk_num)
		
		# Send any final data that doesn't fit neatly into the chunk size
		var chunk = []
		for i in range(floor(len(texture_data) / drawing_chunking_size) * drawing_chunking_size, len(texture_data)):
			chunk.append(texture_data[i])
		
		rpc_id(dest_id, 'submit_drawing_chunk', creator_id, chunk, floor(len(texture_data) / drawing_chunking_size))

sync func submit_drawing_metadata(id, image_size, image_format):
	var image = Image.new()
	image.create(image_size.x, image_size.y, false, image_format)
	
	var texture = ImageTexture.new()
	texture.create(image_size.x, image_size.y, image_format, 0)    
	texture.set_data(image)
	
	var drawing = { 'id': id, 'texture': texture, 'image': image, 'size': image_size, 'format': image_format }
	Global.drawings.append(drawing)
	
	if Global.current_scene == Global.Scenes.DrawWait:
		update_draw_wait = true

sync func submit_drawing_chunk(id, chunk, chunk_num):
	var drawing = Global.get_drawing_by_id(id)
	var texture = drawing['texture']
	var image = drawing['image']
	var image_size = drawing['size']
	
	image.lock()
	for pixel_index in range(len(chunk)):
		var pixel = Global.palette[chunk[pixel_index]]
		var full_pixel_index = pixel_index + chunk_num * drawing_chunking_size
		var x = floor(full_pixel_index / image_size.y)
		var y = int(full_pixel_index) % int(image_size.y)
		image.set_pixel(x, y, pixel)
	
	texture.set_data(image)

func submit_drawing_order(drawing_order):
	rpc("submit_drawing_order_rpc", drawing_order)

sync func submit_drawing_order_rpc(drawing_order):
	Global.drawing_order = drawing_order
	update_grade_order = true

func grade(gold_id, silver_id, bronze_id):
	rpc("grade_rpc", gold_id, silver_id, bronze_id)

sync func grade_rpc(gold_id, silver_id, bronze_id):
	if gold_id != null:
		Global.get_player_by_id(gold_id)['points'] += 3
	if silver_id != null:
		Global.get_player_by_id(silver_id)['points'] += 2
	if bronze_id != null:
		Global.get_player_by_id(bronze_id)['points'] += 1
	
	Global.drawings = []
	Global.prompt = ""
	Global.prompter_index = (Global.prompter_index + 1) % len(Global.players)
	if Global.prompter_index == 0:
		Global.round_num += 1
	
	if Global.round_num > Global.max_rounds:
		Global.change_scene(Global.Scenes.GameEnd)
	elif Global.players[Global.prompter_index]['client_id'] == get_tree().get_network_unique_id():
		Global.change_scene(Global.Scenes.Prompt)
	else:
		Global.change_scene(Global.Scenes.PromptWait)

func submit_lobby_lock(locked):
	if get_tree().get_network_unique_id() == host_id:
		Signaling.lock_lobby(locked)
		rpc("submit_lobby_lock_rpc", locked)

sync func submit_lobby_lock_rpc(locked):
	Global.locked = locked
	if Global.current_scene == Global.Scenes.Lobby:
		update_lobby_lock = true
	
	for sidebar in get_tree().get_nodes_in_group("sidebar"):
		sidebar.update_lock_checkbox(locked)

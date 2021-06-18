extends Node

signal fully_connected

onready var failure_check_timer = $FailureCheckTimer
onready var prompt_animation = $PromptAnimation
onready var prompt_center = $CanvasLayer/PromptCenter
onready var prompt_label = $CanvasLayer/PromptCenter/MarginContainer/CenterContainer/MarginContainer/VBoxContainer/Text

var signaling_server_url = "ws://localhost:7777"

var ws_client = WebSocketClient.new()
var webrtc_mp = WebRTCMultiplayer.new()
var hosting
var id
var player_name
# Used to determine if a player is joining you or you're joining
var player_statuses = {}
var players_registered = 0

func host_lobby(name_str):
	player_name = name_str
	hosting = true
	quit()
	ws_client.connect_to_url(signaling_server_url, [])
	ws_client.connect("data_received", self, "ws_message_received")
	ws_client.connect("connection_established", self, "ws_connection_established", [""])
	fade_in("Connecting to signaling server...")

func join_lobby(name_str, lobby):
	player_name = name_str
	hosting = false
	quit()
	ws_client.connect_to_url(signaling_server_url, [])
	ws_client.connect("data_received", self, "ws_message_received")
	ws_client.connect("connection_established", self, "ws_connection_established", [lobby])
	fade_in("Connecting to signaling server...")

func quit():
	Global.reset_globals()
	player_statuses = {}
	players_registered = 0
	webrtc_mp.close()
	ws_client.disconnect_from_host()
	if ws_client.is_connected("data_received", self, "ws_message_received"):
		ws_client.disconnect("data_received", self, "ws_message_received")
	if ws_client.is_connected("connection_established", self, "ws_connection_established"):
		ws_client.disconnect("connection_established", self, "ws_connection_established")
	if failure_check_timer.is_connected("timeout", self, "failure_check"):
		failure_check_timer.disconnect("timeout", self, "failure_check")
	if OS.get_name() == 'HTML5':
		JavaScript.eval("window.parent.updateLobby('')")

func ws_connection_established(protocol, lobby_str):
	var server = ws_client.get_peer(1)
	server.set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	if hosting:
		server.put_packet("H".to_utf8())
		set_prompt_text("Hosting lobby...")
	else:
		server.put_packet("J:{lobby}".format({"lobby": lobby_str}).to_utf8())
		set_prompt_text("Joining lobby {lobby}...".format({"lobby": lobby_str}))

func ws_message_received():
	var packet_str = ws_client.get_peer(1).get_packet().get_string_from_utf8()
	
	if packet_str[0] == "I":
		failure_check_timer.connect("timeout", self, "failure_check")
		id = int(packet_str.substr(2))
		if hosting:
			Network.host_id = id
	
	if packet_str[0] == "E":
		Global.lobby = packet_str.substr(2)
		webrtc_mp.initialize(id)
		get_tree().set_network_peer(webrtc_mp)
		var player_info = {'client_id': id, 'points': 0, 'name': player_name}
		Global.players.append(player_info)
		if hosting:
			Global.change_scene(Global.Scenes.Lobby)
			reset_prompt()
		if OS.get_name() == 'HTML5':
			JavaScript.eval("window.parent.updateLobby('{lobby}')".format({'lobby': Global.lobby}))
	
	if packet_str[0] == "D":
		quit()
		set_prompt_text("Failed to connect\nReason: {reason}".format({'reason': packet_str.substr(2)}))
	
	if packet_str[0] == "N":
		var connecting
		if packet_str[2] == "C":
			connecting = true
		elif packet_str[2] == "E":
			connecting = false
		create_peer(int(packet_str.substr(4)), connecting)
		set_prompt_text("Connecting to peers...")
	
	var split_packet = packet_str.split("\n", true, 1)
	var peer_id = int(split_packet[0].substr(2))
	if packet_str[0] == "O":
		if webrtc_mp.has_peer(peer_id):
			webrtc_mp.get_peer(peer_id).connection.set_remote_description("offer", split_packet[1])
	
	if packet_str[0] == "A":
		if webrtc_mp.has_peer(peer_id):
			webrtc_mp.get_peer(peer_id).connection.set_remote_description("answer", split_packet[1])
	
	if packet_str[0] == "C":
		var split_payload = split_packet[1].split("\n", false)
		if webrtc_mp.has_peer(peer_id):
			if len(split_payload) == 3:
				webrtc_mp.get_peer(peer_id).connection.add_ice_candidate(split_payload[0], int(split_payload[1]), split_payload[2])

func create_peer(peer_id, connecting):
	var peer = WebRTCPeerConnection.new()
	# Get my own STUN and TURN server in the future if possible
	peer.initialize({ "iceServers": [{ "urls": ["stun:stun.l.google.com:19302"] }] })
	peer.connect("session_description_created", self, "peer_offer_created", [peer_id])
	peer.connect("ice_candidate_created", self, "peer_candidate_created", [peer_id])
	webrtc_mp.add_peer(peer, peer_id)
	player_statuses[peer_id] = connecting
	if connecting:
		peer.create_offer()

func peer_offer_created(type, data, peer_id):
	if not webrtc_mp.has_peer(peer_id):
		return
	webrtc_mp.get_peer(peer_id).connection.set_local_description(type, data)
	var server = ws_client.get_peer(1)
	if type == "offer":
		server.put_packet("O:{id}\n{data}".format({"id": peer_id, "data": data}).to_utf8())
	else:
		server.put_packet("A:{id}\n{data}".format({"id": peer_id, "data": data}).to_utf8())

func peer_candidate_created(mid, index, sdp, peer_id):
	var server = ws_client.get_peer(1)
	var format_str = "C:{id}\n{mid}\n{index}\n{sdp}"
	var format_data = {"id": peer_id, "mid": mid, "index": index, "sdp": sdp}
	server.put_packet(format_str.format(format_data).to_utf8())

func _ready():
	Network.connect("player_registered", self, "player_registered")
	get_tree().connect("network_peer_disconnected", self, "player_disconnected")

func failure_check():
	for peer_id in webrtc_mp.get_peers():
		var peer = webrtc_mp.get_peer(peer_id)
		if !peer.connected && peer.connection.get_connection_state() == WebRTCPeerConnection.STATE_FAILED:
			# Just drop the connection if the peer is connecting
			if player_statuses[peer_id] == true:
				webrtc_mp.remove_peer(peer_id)
			# Quit connecting if you are the one connecting
			else:
				quit()
				set_prompt_text("Failed to connect to at least one peer.")
				failure_check_timer.disconnect("timeout", self, "failure_check")

func player_registered(id):
	players_registered += 1
	if fully_connected():
		emit_signal("fully_connected")

func player_disconnected(id):
	players_registered -= 1

func fully_connected():
	return players_registered == len(webrtc_mp.get_peers())

func lock_lobby(lock):
	var server = ws_client.get_peer(1)
	var lock_letter
	if lock == true:
		lock_letter = "L"
	else:
		lock_letter = "U"
	server.put_packet("L:{letter}".format({'letter': lock_letter}).to_utf8())

# Prompt Functions
func fade_in(message):
	prompt_label.text = message
	prompt_animation.play("fade")

func set_prompt_text(message):
	prompt_label.text = message

func fade_out():
	prompt_animation.play_backwards("fade")

func prompt_disconnect_pressed():
	quit()
	fade_out()

func reset_prompt():
	if prompt_animation.is_playing():
		prompt_animation.stop()
	prompt_center.rect_global_position.y = 720
